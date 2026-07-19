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
const RunSeedSource = preload("res://scripts/ui/flow/run_seed_source.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# Story 14.4 (AC1): there is NO fixed run seed anymore. The default new-run seed comes from the pure RunSeedSource
# seam — a launch-configured explicit seed (manual: byte-deterministic, no meta) or, when unconfigured, a one-time
# OS-entropy seed (a NEW different room every boot — the F11 same-room fix). The old fixed DEFAULT_RUN_SEED = 4242
# is gone.

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
	# Story 14.4 (AC1/AC2): resolve the run seed through the pure RunSeedSource seam — a launch-configured explicit
	# seed (manual: byte-deterministic, no meta) or, when unconfigured, a one-time OS-entropy seed (a NEW different
	# room every boot — the F11 fix). The seam decides (root_seed, is_manual_seed); the impure entropy read is the
	# one _new_run_entropy() line below. is_manual_seed is now THREADED from the seam (was hardcoded false — a latent
	# FR28 gap where a configured explicit seed would still have been meta-eligible).
	var configured_seed: int = 0
	if has_node("/root/GameSession"):
		configured_seed = GameSession.get_root_seed()
	var seed_decision: Dictionary = RunSeedSource.resolve(configured_seed, _new_run_entropy())
	var controller: RunFlowController = RunFlowController.new()
	var start: Dictionary = controller.start(
		int(seed_decision.get("root_seed", 0)),
		bool(seed_decision.get("is_manual_seed", false)),
		_selected_class_id
	)
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


# Story 14.4 (AC3): the ONE impure line — a one-time OS-entropy seed SOURCE for a normal (unconfigured) run. It is
# a LOCAL RandomNumberGenerator seeded from OS entropy, NOT a named gameplay RngStreamSet stream and NOT the global
# randi()/randf() (the seed source is chosen BEFORE any stream exists — streams derive FROM it, so drawing from one
# would be circular). randomize() reseeds from a high-resolution source each call, so a rapid re-boot picks a fresh
# seed (a fixed 1-second-resolution clock would collide and re-create the same-room bug). The PURE manual-vs-entropy
# decision + normalization lives in RunSeedSource (unit-tested with an injected fixed entropy).
func _new_run_entropy() -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi()
