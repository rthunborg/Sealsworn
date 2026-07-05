extends Control

# Story 11.3 (AC1/AC2) — the ROUTE-MAP presenter. It READS the RouteMapViewModel (the G2 projection — the
# reveal-gated eligible_choice_ids(), the current/cleared nodes, per-node type/reveal_state/depth/links/clues)
# and REPORTS the picked node to the flow: it submits the route-advance through the RunOrchestrator
# (RouteAdvanceCommand via advance_to) — the map owns NO route truth; the domain owns it. On picking a combat/
# elite node it navigates to the tactical-board stage (the live node plays there); a non-combat node resolves
# in place through the orchestrator's live resolver and re-renders the map. A run parked at the boss terminus
# navigates to the tactical board (the boss fight).
#
# Node TYPE is shown via an icon marker + label (not color-only); reveal state via a pattern/label prefix (the
# appendix §5.4 non-color channels) — the presenter MAPS the G2 fields to visuals, it invents no vocabulary.
# Verified BY CONSTRUCTION (it reads pinned G2 keys, submits through the orchestrator advance seam); the TESTABLE
# logic is in RouteMapViewModel + RunOrchestrator, both unit-tested.

const RouteMapViewModel = preload("res://scripts/ui/view_models/route_map_view_model.gd")
const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# The node types that play a LIVE tactical board (combat / elite) — picking one navigates to the board stage.
const LIVE_BOARD_NODE_TYPES: Array[String] = ["combat", "elite_combat", "boss"]

var _choices_container: VBoxContainer = null
var _status_label: Label = null

func _ready() -> void:
	_build_layout()
	_render_map()
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"route_map_ready", {})


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	add_child(root)

	var title: Label = Label.new()
	title.text = "The Descent — Choose Your Path"
	root.add_child(title)

	_status_label = Label.new()
	root.add_child(_status_label)

	_choices_container = VBoxContainer.new()
	_choices_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_choices_container)


func _render_map() -> void:
	for child: Node in _choices_container.get_children():
		child.queue_free()

	var flow: RunFlowController = _flow()
	if flow == null or flow.run() == null:
		_status_label.text = "No active run."
		return
	var run: RunState = flow.run()

	# If the run parked at the boss terminus, navigate to the board for the boss fight.
	if flow.orchestrator().boss_encounter_pending():
		_status_label.text = "The Larval Avatar awaits."
		if has_node("/root/SceneManager"):
			SceneManager.go_to_stage("tactical_board")
		return

	# A terminal run routes to the run-end return.
	if run.is_terminal():
		_route_to_run_end(flow)
		return

	var projection: Dictionary = RouteMapViewModel.from_route(run.route).to_dictionary()
	var eligible: Array = projection.get("eligible_choice_ids", [])
	_status_label.text = "Cleared %d / %d" % [
		(projection.get("cleared_node_ids", []) as Array).size(),
		(projection.get("nodes", []) as Array).size()
	]
	var nodes_by_id: Dictionary = {}
	for node: Variant in projection.get("nodes", []):
		nodes_by_id[String((node as Dictionary).get("id", ""))] = node

	for choice_id_value: Variant in eligible:
		var choice_id: String = String(choice_id_value)
		var node: Dictionary = nodes_by_id.get(choice_id, {})
		var button: Button = Button.new()
		button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
		button.text = _node_label(node)
		button.pressed.connect(_on_choice_picked.bind(choice_id))
		_choices_container.add_child(button)


# Node label: a TYPE icon glyph + name + reveal marker + clue chips (non-color channels — icon/label/pattern).
func _node_label(node: Dictionary) -> String:
	var node_type: String = String(node.get("type", ""))
	var icon: String = _type_icon(node_type)
	var reveal_marker: String = _reveal_marker(String(node.get("reveal_state", "")))
	var clues: Array = node.get("clues", [])
	var clue_text: String = "" if clues.is_empty() else "  [%s]" % ", ".join(PackedStringArray(clues))
	return "%s %s %s (depth %d)%s" % [icon, reveal_marker, node_type, int(node.get("depth", 0)), clue_text]


func _type_icon(node_type: String) -> String:
	match node_type:
		"combat": return "[⚔]"
		"elite_combat": return "[⚔⚔]"
		"boss": return "[☠]"
		"shop": return "[$]"
		"reforge": return "[⚒]"
		"gambling": return "[?]"
		"event": return "[!]"
		"secret": return "[✦]"
		_: return "[•]"


func _reveal_marker(reveal_state: String) -> String:
	match reveal_state:
		"revealed": return "◆"
		"cleared": return "✓"
		_: return "◇"


func _on_choice_picked(choice_id: String) -> void:
	var flow: RunFlowController = _flow()
	if flow == null or flow.run() == null:
		return
	var orchestrator: RunOrchestrator = flow.orchestrator()
	var advance = orchestrator.advance_to(choice_id)
	if advance.is_error():
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"route_map_advance_rejected", {
				"choice_id": choice_id,
				"error_code": String(advance.error_code)
			})
		return

	# Determine the picked node type: a live-board node -> the tactical board stage; else resolve in place.
	var picked: RouteNode = orchestrator.run.route.node_by_id(choice_id)
	var picked_type: String = String(picked.type) if picked != null else ""
	if LIVE_BOARD_NODE_TYPES.has(picked_type):
		if has_node("/root/SceneManager"):
			SceneManager.go_to_stage("tactical_board")
		return

	# A non-combat node resolves live in place (placeholder round-trip), then re-render the map.
	var resolved = orchestrator.resolve_current_node_live()
	if resolved.is_error():
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"route_map_resolve_rejected", {"error_code": String(resolved.error_code)})
		return
	_render_map()


func _route_to_run_end(flow: RunFlowController) -> void:
	var destination: String = String(flow.run_end_outcome().get("next_destination", ""))
	if has_node("/root/SceneManager"):
		SceneManager.route_after_run_end(StringName(destination))


func _flow() -> RunFlowController:
	if not has_node("/root/GameSession"):
		return null
	return GameSession.run_flow() as RunFlowController
