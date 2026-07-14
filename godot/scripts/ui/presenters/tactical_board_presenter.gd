extends Control

# Story 11.3 (AC2/AC4) — the TACTICAL-BOARD presenter. It RENDERS the board from TacticalBoardViewModel.
# to_dictionary() (the pinned top-level keys) into the region -> slot map (appendix §1.2): board <- cells/
# occupants/zoom, preview <- preview, confirm_cancel <- commit_flow/action_availability, inspect <- inspect,
# status <- turn + the G1 RunHudViewModel, log_or_outcome <- event_log_summary/outcome. It SUBMITS player intent
# through TacticalCommandBridge.build_command(context, intent) (move/attack/inspect) with the two-step attack
# commit via TacticalAttackCommitFlow and the passive-reward modal via PassiveRewardModalViewModel +
# PassiveRewardCommitFlow — all the EXISTING Epic-2/6 contracts (NOT a parallel presentation path). It reads the
# VM's pinned keys ONLY; it NEVER mutates BoardState/RunState directly (the bridge/commands own mutation).
#
# The scene honors the semantic TacticalLayoutProfile region plan (injected viewport/safe-area -> the profile ->
# the region vocabulary), never hardcoded geometry (AC4); text respects the TacticalTextScale clamp. Changing the
# profile/scale NEVER alters board/RNG/turn/preview legality/outcome (the profile/scale guarantees — proven at the
# TESTABLE layer in test_tactical_layout_profiles.gd). This Control is verified BY CONSTRUCTION; the TESTABLE
# logic (the board VM, the bridge, the commit flow, the layout invariance, the G1 HUD) is all unit-tested.

const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalCommandBridge = preload("res://scripts/ui/command_bridge/tactical_command_bridge.gd")
const TacticalAttackCommitFlow = preload("res://scripts/ui/view_models/tactical_attack_commit_flow.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")
const TacticalTextScale = preload("res://scripts/ui/view_models/tactical_text_scale.gd")
const TacticalAccessibilityModel = preload("res://scripts/ui/view_models/tactical_accessibility_model.gd")
const RunHudViewModel = preload("res://scripts/ui/view_models/run_hud_view_model.gd")
const LiveAffinityReadModel = preload("res://scripts/ui/view_models/live_affinity_read_model.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const PassiveRewardModalViewModel = preload("res://scripts/ui/view_models/passive_reward_modal_view_model.gd")
const PassiveRewardCommitFlow = preload("res://scripts/ui/view_models/passive_reward_commit_flow.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const InteractiveCombatSession = preload("res://scripts/run/interactive_combat_session.gd")
# Story 13.1 — the live tile-grid render + tap hit-test seams. The DRAW surface is a thin Control; the fit +
# hit-test + tap-routing DECISIONS live in tested RefCounted seams (the AC4 "assertable logic in RefCounted
# seams" rule). TacticalBoardZoomState carries class_name, so it is referenced directly for typing.
const TacticalBoardGrid = preload("res://scripts/ui/presenters/tactical_board_grid.gd")
const TacticalBoardGridFit = preload("res://scripts/ui/view_models/tactical_board_grid_fit.gd")
const TacticalBoardTapRouter = preload("res://scripts/ui/view_models/tactical_board_tap_router.gd")

# The approved board art (godot/assets/, all `approved` in the manifest). Loaded DEFENSIVELY at runtime (never
# preload) so the presenter SCRIPT compiles even where the machine-local import cache (.godot/, gitignored) is
# absent — the compile guardrail stays green on a fresh checkout. On any imported build the real art renders;
# an un-imported dev checkout degrades to a flat terrain-colored tile (never a crash, never a black board).
const TILE_TEXTURE_PATHS := {
	"floor": "res://assets/tiles/tile.floor.png",
	"wall": "res://assets/tiles/tile.wall.png",
	"hazard": "res://assets/tiles/tile.hazard.png",
	"entrance": "res://assets/tiles/tile.entrance.png",
	"exit": "res://assets/tiles/tile.exit.png"
}
# The affinity FLOOR variants (full-tile, not overlays — the manifest v0 posture), keyed by the level's
# affinity_id. Note the id `flooded_conductive` maps to the `affinity.flooded.png` art.
const AFFINITY_TEXTURE_PATHS := {
	"scorched": "res://assets/tiles/affinities/affinity.scorched.png",
	"flooded_conductive": "res://assets/tiles/affinities/affinity.flooded.png",
	"cursed": "res://assets/tiles/affinities/affinity.cursed.png",
	"darkness": "res://assets/tiles/affinities/affinity.darkness.png"
}
const CLASS_TEXTURE_PATHS := {
	"warrior": "res://assets/characters/char.warrior.png",
	"pyromancer": "res://assets/characters/char.pyromancer.png",
	"ranger": "res://assets/characters/char.ranger.png"
}
const ENEMY_TEXTURE_PATHS := {
	"iron_cultist": "res://assets/enemies/enemy.iron_cultist.png",
	"gate_brute": "res://assets/enemies/enemy.gate_brute.png",
	"ash_seer": "res://assets/enemies/enemy.ash_seer.png",
	"larval_avatar": "res://assets/enemies/boss.larval_avatar.png"
}

# Non-color draw channels (grayscale/silhouette-safe): fog is a featureless dark fill (no terrain leak), memory
# is a dimmed (brightness) modulate, hazards carry an outline pattern, the hero carries a distinct border, and
# every occupant carries an HP bar (a length/shape channel). Fallback tile colors are for the un-imported dev
# state only; the shipped non-color channel is the approved silhouette-distinct art.
const FOG_FILL_COLOR := Color(0.05, 0.05, 0.08, 1.0)
const MEMORY_MODULATE := Color(0.5, 0.5, 0.58, 1.0)
const GRID_LINE_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const HAZARD_OUTLINE_COLOR := Color(0.95, 0.75, 0.1, 1.0)
const HERO_MARKER_COLOR := Color(0.3, 0.85, 1.0, 1.0)
const ENEMY_MARKER_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const HP_BAR_BG_COLOR := Color(0.0, 0.0, 0.0, 0.75)
const HP_BAR_FILL_COLOR := Color(0.25, 0.85, 0.35, 1.0)
const TERRAIN_FALLBACK_COLORS := {
	BoardCell.Terrain.FLOOR: Color(0.22, 0.2, 0.25, 1.0),
	BoardCell.Terrain.WALL: Color(0.42, 0.42, 0.48, 1.0),
	BoardCell.Terrain.HAZARD: Color(0.5, 0.3, 0.12, 1.0),
	BoardCell.Terrain.ENTRANCE: Color(0.16, 0.34, 0.5, 1.0),
	BoardCell.Terrain.EXIT: Color(0.16, 0.5, 0.34, 1.0)
}
const HERO_FALLBACK_COLOR := Color(0.2, 0.55, 0.9, 1.0)
const ENEMY_FALLBACK_COLOR := Color(0.82, 0.26, 0.26, 1.0)

# The region -> slot vocabulary (the appendix §1.2 region plan; the TacticalLayoutProfile region names).
const REGION_NAMES: Array[String] = [
	"board",
	"preview",
	"confirm_cancel",
	"inspect",
	"status",
	"log_or_outcome"
]

# The two-step attack commit flow (arm -> confirm) — the EXISTING Epic-2 contract, not a re-implementation.
var _commit_flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()
# The command bridge — the tap-submission seam (validates before mutation).
var _command_bridge: TacticalCommandBridge = TacticalCommandBridge.new()
# The region -> control panel map (built from the semantic layout profile).
var _region_panels: Dictionary = {}

# The live rendering inputs (set by the shell presenter that hosts this board): the live BoardState, its turn
# state, the live RunState (for the G1 HUD), and the current text scale.
var _board: BoardState = null
var _turn_state = null
var _run: RunState = null
var _text_scale: float = TacticalTextScale.DEFAULT_TEXT_SCALE
# Story 11.4 (AC2) — the live level's assigned affinity id + the DarknessFairnessQuery verdict, set by the hosting
# shell. The presenter surfaces the affinity read (id/rule/affected cells/cues) via LiveAffinityReadModel — a SEPARATE
# read surface the status/log region composes (exactly like the G1 HUD), NOT a key on the board VM's pinned set.
var _affinity_id: StringName = AffinityDefinition.AFFINITY_NONE
var _affinity_fairness: Dictionary = {}

# Story 12.1 — the LIVE interactive-fight session (set by the hosting shell when a combat/elite node begins). When
# bound, the board's tap methods route each player action into the STEP-DRIVEN session (which owns the SAME command
# bridge + two-step commit flow), instead of the shell driving the atomic auto-resolver. The session owns the live
# board/turn/outcome; the presenter renders a read of it (no scene node owns tactical truth). `_on_action_committed`
# is the shell callback invoked after each COMMITTED action so the shell re-renders + routes on a terminal outcome.
var _session: InteractiveCombatSession = null
var _on_action_committed: Callable = Callable()

# Story 13.1 — the live tile-grid surface (built in _build_regions), the board Panel that hosts it, and the
# SHARED per-render geometry object used for BOTH the tile draw (cell_rect) and the tap hit-test
# (screen_to_cell) so a click can never land on the wrong cell. `_last_board_vm` is the exact VM snapshot the
# grid last drew (the tap router reads it, so the hit-test decides against what the player actually sees). The
# texture cache lazily resolves the approved art once per path.
var _board_grid: TacticalBoardGrid = null
var _board_panel: Panel = null
var _board_geometry: TacticalBoardZoomState = null
var _last_board_vm: Dictionary = {}
var _texture_cache: Dictionary = {}

func _ready() -> void:
	_build_regions()
	render()


# Build the semantic region panels from the injected viewport (never hardcoded geometry). Each region is a Panel
# positioned by the TacticalLayoutProfile plan; the board region stays the dominant region on every profile.
func _build_regions() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var profile: Dictionary = _layout_profile().to_dictionary()
	var regions: Dictionary = profile.get("regions", {})
	for region_name: String in REGION_NAMES:
		var rect: Dictionary = regions.get(region_name, {})
		var panel: Panel = Panel.new()
		panel.position = Vector2(float(rect.get("x", 0.0)), float(rect.get("y", 0.0)))
		panel.size = Vector2(float(rect.get("width", 0.0)), float(rect.get("height", 0.0)))
		add_child(panel)
		var label: Label = Label.new()
		label.name = "content"
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.add_child(label)
		_region_panels[region_name] = label
		# Story 13.1 — the dominant board region hosts the live tile-grid Control ON TOP of its (now empty)
		# text label. Added last so it draws over the label and receives the tap first; the label yields input.
		if region_name == "board":
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_board_panel = panel
			_board_grid = TacticalBoardGrid.new()
			_board_grid.name = "board_grid"
			_board_grid.position = Vector2.ZERO
			_board_grid.size = panel.size
			_board_grid.cell_tapped.connect(_on_board_grid_tapped)
			panel.add_child(_board_grid)


# Resolve the layout profile from the real viewport/safe-area (the presenter injects them; the profile is the
# semantic source of truth — the scene honors it, does not re-derive geometry).
func _layout_profile() -> TacticalLayoutProfile:
	var viewport_size: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1080.0, 1920.0)
	return TacticalLayoutProfile.from_viewport({
		"viewport_size": viewport_size,
		"content_scale": _text_scale
	})


# Set the live rendering inputs from the hosting shell (the live board/turn/run + text scale + the live level's assigned
# affinity id + the DarknessFairnessQuery verdict). Does NOT own the board — it renders a read of it. The affinity id +
# fairness verdict default to the neutral / empty read (the fail-closed "no affinity" render) for a caller that omits them.
func bind_live_state(
	board: BoardState,
	turn_state,
	run: RunState,
	text_scale: float = TacticalTextScale.DEFAULT_TEXT_SCALE,
	affinity_id: StringName = AffinityDefinition.AFFINITY_NONE,
	affinity_fairness: Dictionary = {}
) -> void:
	_board = board
	_turn_state = turn_state
	_run = run
	_text_scale = text_scale
	_affinity_id = affinity_id
	_affinity_fairness = affinity_fairness


# Render the board VM slots + the G1 HUD into the region panels. A null board renders the empty VM (from_domain
# (null) -> a zero-cell VM — an empty board, not a crash). The status region composes the VM's turn slot with the
# G1 run-context read (NEVER scene state).
func render() -> void:
	var text_scale: Dictionary = TacticalTextScale.from_value(_text_scale).to_dictionary()
	var accessibility: Dictionary = TacticalAccessibilityModel.from_state({
		"text_scale": _text_scale,
		"commit_flow": _commit_flow.to_dictionary()
	}).to_dictionary()
	var layout: Dictionary = _layout_profile().to_dictionary()
	var vm: Dictionary = TacticalBoardViewModel.from_domain(_board, _turn_state, {
		"commit_flow": _commit_flow.to_dictionary(),
		"layout": layout,
		"accessibility": accessibility
	}).to_dictionary()

	# Story 13.1 — the board region now renders a real tile grid (a pure projection of the VM) instead of the
	# summary text label. The other five regions render exactly as before.
	_render_board_grid(vm, layout)
	_set_region_text("preview", _preview_text(vm.get("preview", {})))
	_set_region_text("confirm_cancel", _confirm_cancel_text(vm.get("commit_flow", {}), vm.get("action_availability", {})))
	# Story 11.4 (AC2) — the affinity read (a SEPARATE read surface, NOT a board-VM key). Composed into the inspect +
	# status + log regions so the affinity + its rule read BEFORE + DURING play, and the affected cells surface on inspect.
	var affinity: Dictionary = LiveAffinityReadModel.new().project(_affinity_id, _board, _affinity_fairness)
	_set_region_text("inspect", _inspect_text(vm.get("inspect", {}), affinity))
	# The status region = the VM turn slot COMPOSED with the G1 run-context projection (the appendix §1.3 G1) + the
	# affinity badge (the affinity id/display-name/rule visible before + during play — FR55).
	_set_region_text("status", _status_text(vm.get("turn", {}), affinity))
	_set_region_text("log_or_outcome", _log_text(vm.get("event_log_summary", []), vm.get("outcome", {})))


# The G1 status region: hero HP + node progress + gold + inventory from the RunHudViewModel, composed with the
# tactical turn + the affinity badge (Story 11.4 — the affinity id/display-name visible before + during play, FR55).
# The projection reads the live board (hero HP source of truth during a level) + the run.
func _status_text(turn: Dictionary, affinity: Dictionary) -> String:
	var hud: Dictionary = RunHudViewModel.from_run(_run, _board).to_dictionary()
	var hp_text: String = "HP %d/%d" % [int(hud.get("hero_current_hp", 0)), int(hud.get("hero_max_hp", 0))] if bool(hud.get("has_hero_hp", false)) else "HP --"
	return "%s | Node %d/%d | Gold %d | Bag %d/%d | Turn %s | %s" % [
		hp_text,
		int(hud.get("cleared_node_count", 0)),
		int(hud.get("total_node_count", 0)),
		int(hud.get("gold", 0)),
		int(hud.get("inventory_count", 0)),
		int(hud.get("inventory_capacity", 0)),
		String(turn.get("phase", "")),
		_affinity_badge_text(affinity)
	]


# Story 11.4 (AC2) — the affinity BADGE: the affinity display-name + its rule count, visible before + during play. A
# neutral / no-affinity read shows "Affinity: none" (the fail-closed empty read, never a half-badge). A Darkness level
# surfaces the reduced-radius delta the DarknessReadView projects.
func _affinity_badge_text(affinity: Dictionary) -> String:
	if not bool(affinity.get("has_affinity", false)):
		return "Affinity: none"
	var display_name: String = String(affinity.get("display_name", ""))
	var rule_count: int = (affinity.get("tactical_rules", []) as Array).size()
	var badge: String = "Affinity: %s (%d rules)" % [display_name, rule_count]
	var darkness: Dictionary = affinity.get("darkness", {})
	if bool(darkness.get("has_darkness", false)):
		badge += " [sight %d->%d]" % [int(darkness.get("baseline_radius", 0)), int(darkness.get("reduced_radius", 0))]
	# The fairness verdict the DarknessFairnessQuery returned (reflected, not re-derived — AC3 single authority).
	var fairness: Dictionary = affinity.get("fairness", {})
	if bool(fairness.get("darkness_fairness_applicable", false)):
		badge += " [fair]"
	return badge


func _preview_text(preview: Dictionary) -> String:
	if preview.is_empty():
		return "Preview: none"
	return "Preview: %s (%s)" % [String(preview.get("kind", "")), String(preview.get("reason", ""))]


func _confirm_cancel_text(commit_flow: Dictionary, availability: Dictionary) -> String:
	var confirm: Dictionary = availability.get("confirm", {})
	var cancel: Dictionary = availability.get("cancel", {})
	return "Confirm:%s Cancel:%s (mode %s)" % [
		str(bool(confirm.get("enabled", false))),
		str(bool(cancel.get("enabled", false))),
		String(commit_flow.get("mode", "none"))
	]


# The inspect region: the tapped cell's visibility state + (Story 11.4, AC2/FR12/FR58) the affinity danger read — the
# affinity-affected-cell counts + the non-color cue ids surfaced through the EXISTING affinity preview / Darkness cue
# surfaces (the scene MAPS the cue_ids to visuals; it invents no new reason/cue). A neutral read appends nothing.
func _inspect_text(inspect: Dictionary, affinity: Dictionary) -> String:
	var base: String = "Inspect: tap a cell" if inspect.is_empty() else "Inspect: %s" % String(inspect.get("visibility_state", ""))
	if not bool(affinity.get("has_affinity", false)):
		return base
	var preview: Dictionary = affinity.get("preview", {})
	var hazard: int = (preview.get("hazard_cells", []) as Array).size()
	var conductive: int = (preview.get("conductive_danger_cells", []) as Array).size()
	var pathing: int = (preview.get("pathing_pressure_cells", []) as Array).size()
	var cue_ids: Array = affinity.get("cue_ids", [])
	return "%s | Danger: %d hazard / %d conductive / %d pathing | Cues: %s" % [
		base, hazard, conductive, pathing, ", ".join(PackedStringArray(cue_ids))
	]


func _log_text(log_summary: Array, outcome: Dictionary) -> String:
	if not outcome.is_empty() and not String(outcome.get("state_id", "")).is_empty():
		return "Outcome: %s" % String(outcome.get("state_id", ""))
	return "Log: %d events" % log_summary.size()


func _set_region_text(region_name: String, text: String) -> void:
	var label: Label = _region_panels.get(region_name, null)
	if label != null:
		label.text = text


# --- the tap seam (the EXISTING command-bridge / commit-flow contracts) ----------------------------------------

# Submit a MOVE intent through the command bridge (validate-before-mutation). The scene reads availability; the
# bridge/command owns mutation. Returns the ActionResult so a caller/test can read the outcome.
func submit_move(context: TacticalActionContext, actor_id: StringName, target_cell: Vector2i, movement_budget: int = -1):
	var intent: Dictionary = {
		"intent_id": "move",
		"actor_id": String(actor_id),
		"target_cell": target_cell
	}
	if movement_budget > 0:
		intent["movement_budget"] = movement_budget
	return _command_bridge.execute_intent(context, intent)


# Submit an ATTACK tap through the TWO-STEP commit flow: the first tap ARMS attack_preview; a second tap on the
# SAME target/weapon/actor CONFIRMS (executes through the bridge). The EXISTING Epic-2 contract — NOT a parallel path.
func tap_attack(context: TacticalActionContext, actor_id: StringName, target_cell: Vector2i, weapon, attacker_support = null, defender_support = null):
	var flow_result = _commit_flow.tap_attack_target(context, actor_id, target_cell, weapon, attacker_support, defender_support, _command_bridge)
	render()
	return flow_result


# Cancel the pending attack (zero mutation).
func cancel_attack():
	var result = _commit_flow.cancel()
	render()
	return result


# Submit an INSPECT intent (metadata-only through the bridge — no mutation).
func inspect_cell(context: TacticalActionContext, target_cell: Vector2i):
	return _command_bridge.build_command(context, {
		"intent_id": "inspect",
		"target_cell": target_cell
	})


# Project a passive-reward modal from the run's pending offer at `index` (the EXISTING Epic-6 contract). The scene
# renders the pinned MODAL_KEYS; the two-step consume/destroy is PassiveRewardCommitFlow. icon is an id STRING.
func passive_reward_modal(index: int) -> Dictionary:
	if _run == null:
		return PassiveRewardModalViewModel.new().project_offer(null, index)
	return PassiveRewardModalViewModel.new().project_offer(_run.pending_reward_offer, index)


# --- Story 12.1: the LIVE interactive tap seam (route each tap into the step-driven session) --------------------

# Bind the LIVE interactive-fight session hosted by the shell. When bound, the board renders the session's live
# (mutated-in-place) board + turn state and routes each tap into the session (which owns the SAME command bridge +
# two-step commit flow the non-live tap methods use — NOT a parallel path). `on_action_committed` is the shell
# callback invoked after each COMMITTED action (a move / a confirmed attack) so the shell re-renders + routes on a
# terminal outcome. Binds the render inputs (the live board/turn/run + affinity + fairness) from the session in one call.
func bind_interactive_session(
	session: InteractiveCombatSession,
	run: RunState,
	on_action_committed: Callable = Callable(),
	affinity_id: StringName = AffinityDefinition.AFFINITY_NONE,
	affinity_fairness: Dictionary = {}
) -> void:
	_session = session
	_on_action_committed = on_action_committed
	# The LIVE board + turn state (mutated-in-place by the session) drive the render — NOT a throwaway PLAYER_PLANNING
	# stub, so the HUD's turn slot + action_availability reflect the real turn (preview/commit/inspect gate correctly).
	if session != null:
		bind_live_state(session.board(), session.turn_state(), run, _text_scale, affinity_id, affinity_fairness)


# The current live interactive session (or null when the board is not hosting a live fight). A pure read.
func interactive_session() -> InteractiveCombatSession:
	return _session


# Route a MOVE tap into the live session (the human's move action). The session drives ONE MoveCommand through the
# command bridge + runs the enemy phase on a committed move. Re-renders the live board + notifies the shell (the
# terminal check + route). Returns the session's ActionResult. A no-op ok when no session is bound.
func interactive_submit_move(target_cell: Vector2i, movement_budget: int = -1):
	if _session == null:
		return null
	var result_value = _session.submit_move(target_cell, movement_budget)
	render()
	_notify_action_committed()
	return result_value


# Route an ATTACK tap into the live session (the two-step commit — first tap PREVIEWS/arms, second COMMITS). The
# session runs the enemy phase on a committed attack. Re-renders + notifies the shell. Returns the commit-flow result.
func interactive_tap_attack(target_cell: Vector2i, attacker_support = null, defender_support = null):
	if _session == null:
		return null
	var flow_result = _session.tap_attack(target_cell, attacker_support, defender_support)
	render()
	_notify_action_committed()
	return flow_result


# Route an INSPECT tap into the live session (metadata-only — no mutation, no turn advance). Returns the
# CommandBridgeResult. Does NOT notify the shell (inspect commits nothing).
func interactive_inspect(target_cell: Vector2i):
	if _session == null:
		return null
	return _session.inspect(target_cell)


# Notify the shell that a session action resolved (the shell re-renders the HUD + routes on a terminal outcome). Guards
# a null/invalid callback (a dead callback silently no-ops — but this is bound by the shell by construction, not probed).
func _notify_action_committed() -> void:
	if _on_action_committed.is_valid():
		_on_action_committed.call()


# --- Story 13.1: the live tile-grid render + tap hit-test ------------------------------------------------------

# Draw the board region as a real tile grid — a PURE projection of the VM (cells + occupants) + the level's
# affinity floor variant. Builds ONE shared TacticalBoardZoomState (via the RefCounted fit seam) sized to the
# board Panel and uses it for BOTH the tile draw and the tap hit-test. A null / empty board (the between-levels
# zero-cell VM) draws NOTHING (the correct-by-design empty state) — never a crash, never a divide-by-zero.
func _render_board_grid(vm: Dictionary, layout: Dictionary) -> void:
	_last_board_vm = vm
	_board_geometry = null
	_set_region_text("board", "")
	if _board_grid == null:
		return

	var region_size: Vector2 = _board_region_size(layout)
	_board_grid.position = Vector2.ZERO
	_board_grid.size = region_size

	var width: int = int(vm.get("width", 0))
	var height: int = int(vm.get("height", 0))
	var cells: Array = vm.get("cells", []) as Array
	if width <= 0 or height <= 0 or cells.is_empty():
		_board_grid.clear_ops()
		return

	var fit: TacticalBoardGridFit = TacticalBoardGridFit.from_region(width, height, {
		"x": 0.0,
		"y": 0.0,
		"width": region_size.x,
		"height": region_size.y
	})
	if not fit.available():
		_board_grid.clear_ops()
		return
	_board_geometry = fit.to_zoom_state(region_size)
	if _board_geometry == null:
		_board_grid.clear_ops()
		return
	_board_grid.set_ops(_build_board_draw_ops(vm))


# The board region rect comes from the semantic layout profile (never hardcoded geometry). The board Panel is
# the actual on-screen surface, so its size is the source of truth for the draw; fall back to the layout region
# only if the panel is unsized.
func _board_region_size(layout: Dictionary) -> Vector2:
	if _board_panel != null and _board_panel.size.x > 0.0 and _board_panel.size.y > 0.0:
		return _board_panel.size
	var regions: Dictionary = layout.get("regions", {})
	var region: Dictionary = regions.get("board", {})
	return Vector2(float(region.get("width", 0.0)), float(region.get("height", 0.0)))


# Compose the ordered draw-op list the grid replays: fog/terrain tiles first (each with a grid line + a hazard
# outline), then occupants (sprite + a friend/foe marker + an HP bar) on top. Draws ONLY what the VM gives —
# hidden cells expose NO terrain (the FR7 fog contract), occupants are already filtered to visible cells.
func _build_board_draw_ops(vm: Dictionary) -> Array:
	var ops: Array = []
	if _board_geometry == null:
		return ops

	for cell_value: Variant in vm.get("cells", []) as Array:
		if not cell_value is Dictionary:
			continue
		var cell: Dictionary = cell_value
		var rect: Rect2 = _cell_rect(cell.get("position", {}))
		if rect.size.x <= 0.0:
			continue
		var visibility: String = String(cell.get("visibility_state", "hidden"))
		if visibility == "hidden":
			# Fog: a featureless dark fill — NO terrain leak (a hidden cell exposes no terrain in the VM).
			ops.append(_fill_op(rect, FOG_FILL_COLOR))
			ops.append(_outline_op(rect, GRID_LINE_COLOR, 1.0))
			continue
		var terrain: int = int(cell.get("terrain", BoardCell.Terrain.FLOOR))
		var texture: Texture2D = _terrain_texture(terrain)
		if texture != null:
			var modulate: Color = MEMORY_MODULATE if visibility == "memory" else Color.WHITE
			ops.append(_texture_op(rect, texture, modulate))
		else:
			ops.append(_fill_op(rect, _terrain_fallback_color(terrain, visibility)))
		ops.append(_outline_op(rect, GRID_LINE_COLOR, 1.0))
		if terrain == BoardCell.Terrain.HAZARD:
			# Non-color hazard channel: a bright pattern outline on top of the silhouette-distinct hazard art.
			ops.append(_outline_op(rect.grow(-2.0), HAZARD_OUTLINE_COLOR, 3.0))

	for occupant_value: Variant in vm.get("occupants", []) as Array:
		if not occupant_value is Dictionary:
			continue
		var occupant: Dictionary = occupant_value
		var cell_rect: Rect2 = _cell_rect(occupant.get("position", {}))
		if cell_rect.size.x <= 0.0:
			continue
		var is_hero: bool = String(occupant.get("entity_type", "")) == "player"
		var sprite: Texture2D = _hero_texture() if is_hero else _enemy_texture(String(occupant.get("definition_id", "")))
		if sprite != null:
			ops.append(_texture_op(_sprite_rect(cell_rect, sprite), sprite, Color.WHITE))
		else:
			var fallback_color: Color = HERO_FALLBACK_COLOR if is_hero else ENEMY_FALLBACK_COLOR
			ops.append(_fill_op(cell_rect.grow(-cell_rect.size.x * 0.18), fallback_color))
		# Non-color friend/foe channel: the hero carries a distinct bright full border (the enemy a thin dark one).
		var marker_color: Color = HERO_MARKER_COLOR if is_hero else ENEMY_MARKER_COLOR
		var marker_width: float = 3.0 if is_hero else 2.0
		ops.append(_outline_op(cell_rect.grow(-1.0), marker_color, marker_width))
		# HP bar: a length/shape channel (grayscale-safe) so damage reads without color.
		for hp_op: Dictionary in _hp_bar_ops(cell_rect, occupant):
			ops.append(hp_op)

	return ops


# Route a tap PIXEL (local to the grid Control) into the EXISTING interactive_* seams. Reuses the tested
# TacticalBoardZoomState.screen_to_cell hit-test (never a second pixel->cell formula) and the RefCounted
# tap-routing DECISION seam. An unavailable mapping (out-of-bounds / invalid-geometry / NaN) is a safe no-op —
# never a fabricated cell. No session bound (or no geometry) -> ignore.
func _on_board_grid_tapped(local_position: Vector2) -> void:
	if _session == null or _board_geometry == null:
		return
	var mapping: Dictionary = _board_geometry.screen_to_cell(local_position)
	var decision: Dictionary = TacticalBoardTapRouter.decide(mapping, _last_board_vm, _armed_attack_cell())
	var cell: Vector2i = _cell_vector(decision.get("cell", {}))
	match String(decision.get("intent", TacticalBoardTapRouter.INTENT_NONE)):
		TacticalBoardTapRouter.INTENT_MOVE:
			interactive_submit_move(cell)
		TacticalBoardTapRouter.INTENT_ATTACK:
			interactive_tap_attack(cell)
		TacticalBoardTapRouter.INTENT_INSPECT:
			interactive_inspect(cell)
		_:
			# A safe no-op (out-of-bounds / invalid tap). Log via Diagnostics if present; fabricate nothing.
			if is_inside_tree() and has_node("/root/Diagnostics"):
				Diagnostics.info(&"ui", &"tactical_board_tap_ignored", {"reason": String(decision.get("reason", ""))})


# The currently-armed attack target (the session's two-step commit-flow preview) as a Vector2i, or null when no
# attack is armed — so a re-tap on the SAME enemy is recognized as the confirming commit by the router.
func _armed_attack_cell() -> Variant:
	if _session == null:
		return null
	var flow: Dictionary = _session.commit_flow_state()
	if String(flow.get("mode", "")) != "attack_preview":
		return null
	var target: Variant = flow.get("target_cell")
	if target is Dictionary:
		var data: Dictionary = target
		if (data.has("x") or data.has(&"x")) and (data.has("y") or data.has(&"y")):
			return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	return null


func _cell_rect(position: Variant) -> Rect2:
	if _board_geometry == null:
		return Rect2()
	var cell: Vector2i = _cell_vector(position)
	var rect_data: Dictionary = _board_geometry.cell_rect(cell)
	if not bool(rect_data.get("available", false)):
		return Rect2()
	var rect_position: Dictionary = rect_data.get("position", {})
	var rect_size: Dictionary = rect_data.get("size", {})
	return Rect2(
		float(rect_position.get("x", 0.0)),
		float(rect_position.get("y", 0.0)),
		float(rect_size.get("x", 0.0)),
		float(rect_size.get("y", 0.0))
	)


func _cell_vector(position: Variant) -> Vector2i:
	if position is Dictionary:
		var data: Dictionary = position
		return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	if position is Vector2i:
		return position
	return Vector2i.ZERO


# Fit a portrait occupant sprite into its cell, aspect-preserved + centered with a small inset (never stretched
# into a square). A null texture yields the plain inset rect (the fallback marker draws there).
func _sprite_rect(cell_rect: Rect2, texture: Texture2D) -> Rect2:
	var inset: Rect2 = cell_rect.grow(-cell_rect.size.x * 0.06)
	if texture == null:
		return inset
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return inset
	var scale: float = minf(inset.size.x / texture_size.x, inset.size.y / texture_size.y)
	var draw_size: Vector2 = texture_size * scale
	var draw_position: Vector2 = inset.position + (inset.size - draw_size) * 0.5
	return Rect2(draw_position, draw_size)


func _hp_bar_ops(cell_rect: Rect2, occupant: Dictionary) -> Array:
	var max_hp: int = int(occupant.get("max_hp", 0))
	if max_hp <= 0:
		return []
	var current_hp: int = clampi(int(occupant.get("current_hp", 0)), 0, max_hp)
	var bar_height: float = maxf(3.0, cell_rect.size.y * 0.09)
	var bar_margin: float = cell_rect.size.x * 0.1
	var bar_width: float = cell_rect.size.x - bar_margin * 2.0
	if bar_width <= 0.0:
		return []
	var bar_top: float = cell_rect.position.y + cell_rect.size.y - bar_height - 2.0
	var background: Rect2 = Rect2(cell_rect.position.x + bar_margin, bar_top, bar_width, bar_height)
	var fill_width: float = bar_width * (float(current_hp) / float(max_hp))
	var fill: Rect2 = Rect2(background.position, Vector2(fill_width, bar_height))
	return [
		_fill_op(background, HP_BAR_BG_COLOR),
		_fill_op(fill, HP_BAR_FILL_COLOR)
	]


func _terrain_texture(terrain: int) -> Texture2D:
	match terrain:
		BoardCell.Terrain.WALL:
			return _texture(TILE_TEXTURE_PATHS["wall"])
		BoardCell.Terrain.HAZARD:
			return _texture(TILE_TEXTURE_PATHS["hazard"])
		BoardCell.Terrain.ENTRANCE:
			return _texture(TILE_TEXTURE_PATHS["entrance"])
		BoardCell.Terrain.EXIT:
			return _texture(TILE_TEXTURE_PATHS["exit"])
		_:
			return _floor_texture()


# The floor tile IS the affinity treatment on an affinity level (a full-tile floor variant, not an overlay —
# the manifest v0 posture); a neutral / unknown affinity uses the plain floor. The affinity id is the SEPARATE
# LiveAffinityReadModel surface (_affinity_id), never a board-VM key.
func _floor_texture() -> Texture2D:
	var affinity_key: String = String(_affinity_id)
	if AFFINITY_TEXTURE_PATHS.has(affinity_key):
		var affinity_texture: Texture2D = _texture(AFFINITY_TEXTURE_PATHS[affinity_key])
		if affinity_texture != null:
			return affinity_texture
	return _texture(TILE_TEXTURE_PATHS["floor"])


func _hero_texture() -> Texture2D:
	var class_id: String = "" if _run == null else String(_run.selected_class_id)
	if CLASS_TEXTURE_PATHS.has(class_id):
		return _texture(CLASS_TEXTURE_PATHS[class_id])
	# An unknown / kit-less class still reads as the hero (the marker + HP bar carry the non-color channel).
	return _texture(CLASS_TEXTURE_PATHS["warrior"])


func _enemy_texture(definition_id: String) -> Texture2D:
	if ENEMY_TEXTURE_PATHS.has(definition_id):
		return _texture(ENEMY_TEXTURE_PATHS[definition_id])
	return null


func _terrain_fallback_color(terrain: int, visibility: String) -> Color:
	var color: Color = TERRAIN_FALLBACK_COLORS.get(terrain, TERRAIN_FALLBACK_COLORS[BoardCell.Terrain.FLOOR])
	if visibility == "memory":
		color = color * MEMORY_MODULATE
		color.a = 1.0
	return color


# Resolve an approved-art texture DEFENSIVELY: cached, guarded by ResourceLoader.exists so an un-imported dev
# checkout returns null (the caller draws a fallback) instead of erroring. Never called during the headless
# compile guardrail (render() needs a SceneTree), so it never touches the machine-local import cache in tests.
func _texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _texture_cache.get(path)
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			texture = loaded
	_texture_cache[path] = texture
	return texture


func _fill_op(rect: Rect2, color: Color) -> Dictionary:
	return {
		"kind": "fill",
		"rect": rect,
		"color": color
	}


func _texture_op(rect: Rect2, texture: Texture2D, modulate: Color) -> Dictionary:
	return {
		"kind": "texture",
		"rect": rect,
		"texture": texture,
		"modulate": modulate
	}


func _outline_op(rect: Rect2, color: Color, width: float) -> Dictionary:
	return {
		"kind": "outline",
		"rect": rect,
		"color": color,
		"width": width
	}
