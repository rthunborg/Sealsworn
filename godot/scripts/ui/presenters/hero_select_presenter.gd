extends Control

# Story 11.3 (AC1) — the HERO-SELECT presenter (the class picker). It READS the HeroSelectViewModel (the Epic-5
# roster projection — selectable/locked + unlock hints in ClassRepository order) and SUBMITS a confirmed class_id
# to the run start via the RunFlowController (RunOrchestrator.start — the AUTHORITATIVE fail-closed gate; a locked
# class CANNOT start a run). It OWNS no domain truth: it renders the projection, grays out locked classes (the UX
# layer on top of the fail-closed command gate), and on confirm hands off to the route-map stage. It NEVER mutates
# domain state — the RunFlowController/RunOrchestrator owns the run.
#
# Testability (the 11.3 reality): this Control is verified BY CONSTRUCTION (it reads pinned VM keys, submits
# through the orchestrator start seam, honors the region plan) — the scene-free harness runs no SceneTree. The
# TESTABLE logic (the roster projection, the fail-closed start gate) lives in HeroSelectViewModel / RunOrchestrator
# / RunFlowController, all unit-tested. This presenter is thin glue.

const HeroSelectViewModel = preload("res://scripts/ui/view_models/hero_select_view_model.gd")
const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# The default run seed when the launch flow configured none (a deterministic fallback; a manual-seed entry is a
# later concern). Kept as a named const so a later seed-entry surface can supply one.
const DEFAULT_RUN_SEED: int = 4242

var _view_model: HeroSelectViewModel = null
var _selected_class_id: StringName = &""
var _roster_container: VBoxContainer = null
var _confirm_button: Button = null
var _class_buttons: Dictionary = {}

func _ready() -> void:
	_view_model = HeroSelectViewModel.new()
	_build_layout()
	_render_roster()
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"hero_select_ready", {"class_count": _view_model.classes().size()})


# Build the scene's semantic layout: the board region is not present here (this is a menu), but the primary
# action (confirm) honors the >=44x44 reachability the TacticalLayoutProfile guarantees. Geometry is built from
# the injected viewport, never hardcoded pixel positions.
func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	add_child(root)

	var title: Label = Label.new()
	title.text = "Choose Your Hero"
	root.add_child(title)

	_roster_container = VBoxContainer.new()
	_roster_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_roster_container)

	_confirm_button = Button.new()
	_confirm_button.text = "Begin Descent"
	_confirm_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	root.add_child(_confirm_button)


# Render one selectable/locked row per class from the projection (the exact ENTRY_KEYS: class_id, display_name,
# selectable, unlock_hint). A locked class's button is disabled + shows its unlock hint (the grey-out is UX on top
# of the fail-closed command gate).
func _render_roster() -> void:
	for entry_value: Variant in _view_model.classes():
		var entry: Dictionary = entry_value
		var class_id: StringName = StringName(String(entry.get("class_id", "")))
		var button: Button = Button.new()
		button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
		var selectable: bool = bool(entry.get("selectable", false))
		if selectable:
			button.text = String(entry.get("display_name", ""))
		else:
			button.text = "%s (locked: %s)" % [String(entry.get("display_name", "")), String(entry.get("unlock_hint", ""))]
		button.disabled = not selectable
		if selectable:
			button.pressed.connect(_on_class_selected.bind(class_id))
		_roster_container.add_child(button)
		_class_buttons[class_id] = button


func _on_class_selected(class_id: StringName) -> void:
	# The UI gate is HeroSelectViewModel.is_class_selectable; the AUTHORITATIVE gate is the run-start command.
	if not _view_model.is_class_selectable(class_id):
		return
	_selected_class_id = class_id
	_confirm_button.disabled = false
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"hero_select_class_chosen", {"class_id": String(class_id)})


# Confirm: start a fresh run through the RunFlowController (the AUTHORITATIVE fail-closed start), stash the live
# controller on GameSession (so it outlives this scene), then navigate to the route-map stage. A rejected start
# (a mis-enabled confirm on a locked class) surfaces the command error and does NOT navigate — the fail-closed gate.
func _on_confirm_pressed() -> void:
	if _selected_class_id == &"":
		return
	var seed_value: int = _resolve_seed()
	var controller: RunFlowController = RunFlowController.new()
	var start: Dictionary = controller.start(seed_value, false, _selected_class_id)
	if not bool(start.get("started", false)):
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"ui", &"hero_select_start_rejected", {
				"class_id": String(_selected_class_id),
				"error_code": String(start.get("error_code", ""))
			})
		return

	if has_node("/root/GameSession"):
		GameSession.set_run_flow(controller)
	if has_node("/root/SceneManager"):
		SceneManager.go_to_stage("route_map")


# Resolve the run seed: the launch-configured GameSession seed if set, else the deterministic default.
func _resolve_seed() -> int:
	if has_node("/root/GameSession"):
		var configured: int = GameSession.get_root_seed()
		if configured != 0:
			return configured
	return DEFAULT_RUN_SEED
