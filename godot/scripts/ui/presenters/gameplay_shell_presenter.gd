extends Control

# Story 11.3 (AC1/AC2) — the GAMEPLAY-SHELL presenter. It hosts the tactical board + the in-run HUD and DRIVES
# the live run flow via the RunFlowController (which SEQUENCES the RunOrchestrator's live methods — the composed
# live-pre-boss + boss-auto-play seam 11.2 left un-composed, 11.3's crux). On entry it resolves the parked node
# LIVE (a combat/elite node -> resolve_current_node_live; the boss terminus -> the boss fight) and renders the
# board + HUD through the EXISTING VM contracts, then ADVANCES the flow: a live victory returns to the route-map
# stage; a live run-END (hero death / boss victory) routes off RunEndOutcome.next_destination to the run-end
# stage. It OWNS no run/tactical truth — the orchestrator/commands own it; this shell sequences + renders.
#
# The on-screen player DRIVES the hero via taps through the board presenter's command-bridge seam (the human
# replaces 11.2's scripted focus-fire driver for live play). The shell's live-node resolution stands in for that
# tap loop headlessly (exactly as 11.2's live loop is driven by an explicit driver) so the flow reaches a terminal
# node/run outcome deterministically on a verified seed. Verified BY CONSTRUCTION; the TESTABLE logic (the flow
# controller, the live methods, the board VM, the G1 HUD) is unit-tested.

const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
# L1 (Round 1 decision): the board surface is the SCENE FILE, not an in-code TacticalBoardPresenter.new(). The
# shell INSTANCES tactical_board.tscn (whose Control root carries the TacticalBoardPresenter script + its full-rect
# anchors), so scenes/game/tactical_board.tscn is the single source of the board surface (no longer dead as a nav
# target — the compile guardrail still covers it). The instanced root exposes bind_live_state/render as before.
const TacticalBoardScene = preload("res://scenes/game/tactical_board.tscn")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")

# The combat/elite node types that play a live board here.
const LIVE_COMBAT_NODE_TYPES: Array[String] = ["combat", "elite_combat"]

var _board_presenter: Control = null

func _ready() -> void:
	_build_board_presenter()
	call_deferred("_drive_current_stage")
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"gameplay_shell_ready", {})


# L1: instance the board SCENE (its Control root already carries the presenter script + full-rect anchors) rather
# than TacticalBoardPresenter.new(). L2: this shell root is now a Control (full-rect), so the board Control's
# anchors resolve against a real Control ancestor on device (a bare Node2D parent gave no layout to size against).
func _build_board_presenter() -> void:
	_board_presenter = TacticalBoardScene.instantiate() as Control
	add_child(_board_presenter)


# Drive the live node the run is parked on, render it, then advance the flow. A boss terminus drives the boss
# fight; a combat/elite node drives the live fight; a non-combat node resolves in place. A run-END routes to the
# run-end stage.
func _drive_current_stage() -> void:
	var flow: RunFlowController = _flow()
	if flow == null or flow.run() == null:
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"gameplay_shell_no_run", {})
		return
	var orchestrator: RunOrchestrator = flow.orchestrator()
	var run: RunState = flow.run()

	# The boss terminus -> drive the live boss fight to a run-END (the composed seam).
	if orchestrator.boss_encounter_pending():
		var boss = orchestrator.auto_play_boss_fight(flow.hero_hp())
		# M1 fix: a boss-fight ERROR (the bounded round loop failed to progress — a real possibility the story
		# flags: "the scripted hero is deterministic but NOT universally-winning") leaves the run NON-terminal, so
		# run_end_outcome() yields has_ended == false / next_destination == "" and route_after_run_end("") no-ops
		# into a silent soft-lock. FAIL LOUD (mirroring the combat-node branch): log the error, then surface a
		# recoverable dead-end by routing to the run-end/recovery surface rather than stranding the player on the
		# shell with no navigation and no breadcrumb.
		if boss.is_error():
			if has_node("/root/Diagnostics"):
				Diagnostics.info(&"ui", &"gameplay_shell_boss_fight_failed", {"error_code": String(boss.error_code)})
			_render_between_levels(run)
			_route_to_dead_end(flow)
			return
		_render_between_levels(run)
		_route_to_run_end(flow)
		return

	if run.is_terminal():
		_route_to_run_end(flow)
		return

	var current: RouteNode = run.route.node_by_id(run.route.current_node_id)
	var node_type: String = String(current.type) if current != null else ""

	if LIVE_COMBAT_NODE_TYPES.has(node_type):
		# Drive the live combat node (the board outcome decides it). Capture the live board for the render.
		var resolved = orchestrator.resolve_combat_node_live(current, flow.hero_hp())
		if resolved.is_error():
			if has_node("/root/Diagnostics"):
				Diagnostics.info(&"ui", &"gameplay_shell_live_node_failed", {"error_code": String(resolved.error_code)})
			_render_between_levels(run)
			return
		var live_board = resolved.metadata.get("board")
		if live_board is BoardState:
			_render_live_board(live_board as BoardState, run)
		# A live DEFEAT ended the run (hero death) -> run-end; a live VICTORY advances forward -> route map.
		if run.is_terminal():
			_route_to_run_end(flow)
		else:
			_advance_to_route_map()
		return

	# A boss node not yet set up -> resolve it live (sets up the boss encounter), then re-drive (drives the fight).
	if node_type == "boss":
		var setup = orchestrator.resolve_current_node_live(flow.hero_hp())
		if setup.is_error():
			if has_node("/root/Diagnostics"):
				Diagnostics.info(&"ui", &"gameplay_shell_boss_setup_failed", {"error_code": String(setup.error_code)})
			return
		_drive_current_stage()
		return

	# A non-combat node resolves in place, then returns to the map.
	var placeholder = orchestrator.resolve_current_node_live(flow.hero_hp())
	if placeholder.is_error():
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"gameplay_shell_placeholder_failed", {"error_code": String(placeholder.error_code)})
		return
	_render_between_levels(run)
	_advance_to_route_map()


func _render_live_board(board: BoardState, run: RunState) -> void:
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	_board_presenter.bind_live_state(board, turn_state, run, _text_scale())
	_board_presenter.render()


func _render_between_levels(run: RunState) -> void:
	# Between levels there is no live board; the HUD still renders run context (HP baseline from StartingKit, gold,
	# node progress) via the G1 projection (board == null).
	_board_presenter.bind_live_state(null, null, run, _text_scale())
	_board_presenter.render()


func _advance_to_route_map() -> void:
	if has_node("/root/SceneManager"):
		SceneManager.go_to_stage("route_map")


func _route_to_run_end(flow: RunFlowController) -> void:
	var destination: String = String(flow.run_end_outcome().get("next_destination", ""))
	if has_node("/root/SceneManager"):
		SceneManager.route_after_run_end(StringName(destination))


# M1: the recoverable dead-end for a NON-TERMINAL run-progression failure (a boss fight that could not resolve).
# route_after_run_end would no-op here (next_destination == "" for a non-terminal run), stranding the player on
# the shell. Route DIRECTLY to the run-end stage instead: the run-end landing surfaces "no completed run" +
# a "Return to the Outpost" affordance (boots back to hero select with the run-flow handle cleared), so the
# player is never soft-locked. This is a fail-loud recovery, NOT a claim the run ended (the run did not).
func _route_to_dead_end(_flow: RunFlowController) -> void:
	if has_node("/root/SceneManager"):
		SceneManager.go_to_stage("run_end")


# The current text scale from SettingsManager (SettingsSnapshot.text_scale), clamped by TacticalTextScale.
# M2 fix (Round 2): the prior probe called SettingsManager.has_method("current_text_scale") — a method that
# exists NOWHERE (the guard was permanently false, so the HUD text scale was hardcoded to 1.0 and the player's
# saved SettingsSnapshot.text_scale never reached the run-flow HUD, defeating AC4/NFR8 scalable text on device).
# Read the real field: SettingsManager.current() -> SettingsSnapshot, .text_scale (a clamped float), and run it
# through the canonical TacticalTextScale.from_value(...) clamp (the same seam settings_snapshot._sanitize_text_scale
# uses — .scale is exposed via to_dictionary(), there is no public .scale property). The has_node guard + the 1.0
# fallback are kept.
func _text_scale() -> float:
	if has_node("/root/SettingsManager"):
		var snapshot = SettingsManager.current()
		if snapshot != null:
			return float(TacticalTextScale.from_value(snapshot.text_scale).to_dictionary().get("scale", 1.0))
	return 1.0


func _flow() -> RunFlowController:
	if not has_node("/root/GameSession"):
		return null
	return GameSession.run_flow() as RunFlowController
