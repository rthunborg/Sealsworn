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
const RunState = preload("res://scripts/run/run_state.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")

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
	var vm: Dictionary = TacticalBoardViewModel.from_domain(_board, _turn_state, {
		"commit_flow": _commit_flow.to_dictionary(),
		"layout": _layout_profile().to_dictionary(),
		"accessibility": accessibility
	}).to_dictionary()

	_set_region_text("board", "Board %dx%d — %d occupants" % [
		int(vm.get("width", 0)), int(vm.get("height", 0)), (vm.get("occupants", []) as Array).size()
	])
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
