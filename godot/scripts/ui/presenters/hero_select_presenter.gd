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
const HeroSelectRenderView = preload("res://scripts/ui/view_models/hero_select_render_view.gd")
const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunSeedSource = preload("res://scripts/ui/flow/run_seed_source.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# Story 14.8 (F13) — the rebuilt roster presentation constants. The portrait tile size + the row min-height (so a
# clickable row Button fits the portrait; the ≥44px touch reachability is honored via DEFAULT_MINIMUM_TOUCH_TARGET).
# The full Theme + semantic region plan across screens is Story 14.11 — 14.8 keeps this MINIMAL.
const PORTRAIT_SIZE := Vector2(96.0, 96.0)
const ROW_MIN_HEIGHT := 112.0
const TITLE_FONT_SIZE := 32
const CLASS_NAME_FONT_SIZE := 20
# The non-color selection channel (NFR9): a thick border stylebox on the selected row PLUS a text marker. Color is a
# cosmetic tint on the border SHAPE, never the sole signal.
const SELECTED_BORDER_COLOR := Color(0.95, 0.95, 1.0, 1.0)
const SELECTED_BG_COLOR := Color(0.16, 0.2, 0.28, 1.0)
const SELECTED_MARKER := "  ✓ Selected"
const LOCKED_MARKER := "  [Locked]"

# Story 14.4 (AC1): there is NO fixed run seed anymore. The default new-run seed comes from the pure RunSeedSource
# seam — a launch-configured explicit seed (manual: byte-deterministic, no meta) or, when unconfigured, a one-time
# OS-entropy seed (a NEW different room every boot — the F11 same-room fix). The old fixed DEFAULT_RUN_SEED = 4242
# is gone.

var _view_model: HeroSelectViewModel = null
var _selected_class_id: StringName = &""
var _roster_container: VBoxContainer = null
var _confirm_button: Button = null

func _ready() -> void:
	_view_model = HeroSelectViewModel.new()
	_build_layout()
	_render_roster()
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"hero_select_ready", {"class_count": _view_model.classes().size()})


# Build the scene's semantic layout: the board region is not present here (this is a menu), but the primary
# action (confirm) honors the >=44x44 reachability the TacticalLayoutProfile guarantees. Geometry is built from
# the injected viewport, never hardcoded pixel positions. Story 14.8 (F13) — a MINIMAL title treatment (a styled
# heading + subtitle; the full Theme is Story 14.11) sits above a SCROLLABLE roster (so the confirm affordance can
# never be pushed off-screen by the taller portrait rows) above the confirm button.
func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	add_child(root)

	# Minimal title treatment (F13 — replace the plain "Choose Your Hero" Label with a styled heading + subtitle).
	var title: Label = Label.new()
	title.text = "Choose Your Hero"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	root.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Select a class, then begin your descent."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)

	# The roster scrolls (5 portrait rows may exceed the viewport on a short screen) so the confirm button stays
	# reachable; horizontal scrolling is disabled (rows fill the width).
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_roster_container = VBoxContainer.new()
	_roster_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roster_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_roster_container.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMPACT_SPACING))
	scroll.add_child(_roster_container)

	_confirm_button = Button.new()
	_confirm_button.text = "Begin Descent"
	_confirm_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	root.add_child(_confirm_button)


# Story 14.8 (F13, AC1/AC2) — render one rich row per class from the scene-free HeroSelectRenderView seam: the
# portrait (loaded defensively -> a labeled placeholder if unresolved), the display name, the kit summary for a
# selectable class (weapon / support / passives), or the locked affordance (the unlock hint + numeric cost) for a
# locked class, plus the VISIBLE selection state (a border + a text marker — a non-color channel, NFR9). Re-rendered
# on every selection change so the previously-selected row loses its marker and the new one gains it. The grey-out is
# UX on top of the fail-closed command gate; the AUTHORITATIVE gate stays RunStartCommand (via _on_confirm_pressed).
func _render_roster() -> void:
	_clear_roster()
	var render_view: HeroSelectRenderView = HeroSelectRenderView.new(_view_model, _selected_class_id)
	for row_value: Variant in render_view.rows():
		_roster_container.add_child(_build_row(row_value))
	# The confirm pre-gate: enabled only when a SELECTABLE class is chosen (the UI grey-out on top of the fail-closed
	# RunStartCommand gate). A locked/unknown/empty selection keeps confirm disabled.
	_confirm_button.disabled = _selected_class_id == &"" or not _view_model.is_class_selectable(_selected_class_id)


# Free the current roster rows (an immediate detach so a re-render never briefly stacks the old + new rows in the
# container's layout, then queue_free to reap them).
func _clear_roster() -> void:
	if _roster_container == null:
		return
	for child: Node in _roster_container.get_children():
		_roster_container.remove_child(child)
		child.queue_free()


# Build one class row (a clickable Button hosting the portrait + info). A selectable row wires selection; a locked row
# is disabled (the grey-out) and shows its unlock affordance. The selected row carries a border stylebox + a "✓
# Selected" marker (the NFR9 non-color channel). Children are mouse_filter IGNORE so the row Button receives the tap
# (the tactical_board_presenter precedent).
func _build_row(row: Dictionary) -> Control:
	var class_id: StringName = StringName(String(row.get("class_id", "")))
	var selectable: bool = bool(row.get("selectable", false))
	var is_selected: bool = bool(row.get("is_selected", false))

	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET.x, ROW_MIN_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = not selectable
	button.clip_contents = true
	if is_selected:
		_apply_selected_style(button)

	var content: HBoxContainer = HBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	button.add_child(content)

	content.add_child(_build_portrait(row))

	var info: VBoxContainer = VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(info)

	var name_label: Label = Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", CLASS_NAME_FONT_SIZE)
	var name_text: String = String(row.get("display_name", ""))
	if is_selected:
		name_text += SELECTED_MARKER
	elif not selectable:
		name_text += LOCKED_MARKER
	name_label.text = name_text
	info.add_child(name_label)

	if selectable:
		for line: String in _kit_summary_lines(row.get("kit", {})):
			info.add_child(_body_label(line))
	else:
		info.add_child(_body_label(String(row.get("locked_label", ""))))

	# Only a selectable row is wired for selection (a locked row has no selection handler — the disabled Button plus
	# the fail-closed pre-gate both block it).
	if selectable:
		button.pressed.connect(_on_class_selected.bind(class_id))
	return button


# The portrait node: a TextureRect when the approved art resolves, else a labeled placeholder Panel (AC1 — "degrading
# gracefully if a portrait texture is unresolved": a missing-import dev checkout shows a labeled placeholder, never a
# crash or a blank tile). The art is loaded DEFENSIVELY at runtime (never preload — the compile guardrail stays green
# on an un-imported checkout; the tactical_board_presenter discipline).
func _build_portrait(row: Dictionary) -> Control:
	var texture: Texture2D = _load_portrait(String(row.get("portrait_path", "")))
	if texture != null:
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.custom_minimum_size = PORTRAIT_SIZE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	# The labeled placeholder (never blank, never a crash): a bordered Panel carrying the class display name.
	var placeholder: Panel = Panel.new()
	placeholder.custom_minimum_size = PORTRAIT_SIZE
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label: Label = Label.new()
	label.text = String(row.get("display_name", "?"))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.add_child(label)
	return placeholder


# Load an approved portrait DEFENSIVELY (guarded by ResourceLoader.exists so an un-imported dev checkout returns null
# and the caller draws the labeled placeholder), never preload. Mirrors tactical_board_presenter._texture.
func _load_portrait(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var loaded: Resource = load(path)
	if loaded is Texture2D:
		return loaded
	return null


# The kit summary display lines for a selectable class's kit sub-dict (weapon / support / HP / passives). The
# support_id == "none" reality (Ranger's REAL baseline SUPPORT_NONE) renders honestly as "No support", NEVER as a
# missing/error item (project-context.md line 176). Weapon/support ids are prettified from snake_case (polished
# display-naming across screens is Story 14.10/14.11 — a snake_case-derived label is the acceptable minimal fallback).
func _kit_summary_lines(kit: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if kit.is_empty():
		return lines
	lines.append("Weapon: %s" % _pretty_id(String(kit.get("weapon_id", ""))))
	lines.append("Support: %s" % _support_display(String(kit.get("support_id", ""))))
	lines.append("HP: %d" % int(kit.get("baseline_hp", 0)))
	for passive_value: Variant in kit.get("passives", []) as Array:
		lines.append("• %s" % str(passive_value))
	return lines


# Render a support id honestly: the REAL &"none" baseline (Ranger's SUPPORT_NONE) reads "No support", never a
# missing/error item; any other id is prettified. An empty id also reads "No support" (defensive).
func _support_display(support_id: String) -> String:
	if support_id.is_empty() or support_id == "none":
		return "No support"
	return _pretty_id(support_id)


# Prettify a lower_snake id into a readable label (e.g. "blade_and_board" -> "Blade And Board"). Godot's
# String.capitalize() converts snake_case to Title Case. An empty id reads "—" (never a raw blank).
func _pretty_id(id: String) -> String:
	if id.is_empty():
		return "—"
	return id.capitalize()


# A wrapped body Label for the info column (kit lines / locked affordance). mouse_filter IGNORE so the row Button
# still receives the tap.
func _body_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


# The visible-selection channel (NFR9): a thick border stylebox on the selected row Button (a SHAPE channel — the
# color is a cosmetic tint, not the sole signal; the "✓ Selected" text marker is the accessible label). Overrides the
# button's state styleboxes so the border shows in normal/hover/pressed/focus.
func _apply_selected_style(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, _selected_stylebox())


func _selected_stylebox() -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = SELECTED_BG_COLOR
	box.set_border_width_all(3)
	box.border_color = SELECTED_BORDER_COLOR
	box.set_corner_radius_all(4)
	box.set_content_margin_all(6.0)
	return box


func _on_class_selected(class_id: StringName) -> void:
	# The UI gate is HeroSelectViewModel.is_class_selectable; the AUTHORITATIVE gate is the run-start command.
	if not _view_model.is_class_selectable(class_id):
		return
	_selected_class_id = class_id
	# Re-render so the selection marker + border move to the newly-selected row and confirm enables (the previously-
	# selected row loses its marker). The confirm/start path (_on_confirm_pressed) is UNCHANGED.
	_render_roster()
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
