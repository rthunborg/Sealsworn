extends Node2D

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
const TacticalBoardPresenter = preload("res://scripts/ui/presenters/tactical_board_presenter.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

# The combat/elite node types that play a live board here.
const LIVE_COMBAT_NODE_TYPES: Array[String] = ["combat", "elite_combat"]

var _board_presenter: Control = null

func _ready() -> void:
	_build_board_presenter()
	call_deferred("_drive_current_stage")
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"gameplay_shell_ready", {})


func _build_board_presenter() -> void:
	_board_presenter = TacticalBoardPresenter.new()
	_board_presenter.set_anchors_preset(Control.PRESET_FULL_RECT)
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


# The current text scale from SettingsManager (SettingsSnapshot.text_scale), clamped by TacticalTextScale.
func _text_scale() -> float:
	if has_node("/root/SettingsManager"):
		var settings = SettingsManager
		if settings.has_method("current_text_scale"):
			return float(settings.current_text_scale())
	return 1.0


func _flow() -> RunFlowController:
	if not has_node("/root/GameSession"):
		return null
	return GameSession.run_flow() as RunFlowController
