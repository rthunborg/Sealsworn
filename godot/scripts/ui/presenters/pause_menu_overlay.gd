class_name PauseMenuOverlay
extends Control

# Story 15.4 (Review D1) — the ONE SHARED, REUSABLE pause surface. Both the live board (gameplay_shell_presenter)
# and the route map (route_map_presenter) instantiate THIS overlay so there is a SINGLE pause menu, not a second
# near-copy per screen. It is thin glue over the testable seams: PauseMenuViewModel (the entries + run-metrics
# projection), QuitRunBridge + SaveManager (Save & Exit), and SettingsOptionsViewModel + SettingsManager (Options).
#
# Menu contents (the human-chosen D1 shape): the run METRICS, Resume play, Save & Exit (the existing Quit-run
# behavior — compose the route position via QuitRunBridge.compose_quit_save -> SaveManager.autosave_route_position
# -> navigate to the `boot` surface; NOT the outpost), and Options (a minimal panel over the six EXISTING
# SettingsSnapshot preferences). Save & Exit is phase-gated by the view model (a terminal/null run offers none).
#
# ⭐ EPHEMERAL-FIGHT DISCARD: the board hosts an ephemeral InteractiveCombatSession; the route map does not. So the
# board passes an on_before_quit callback that nulls its live-fight handles before the quit composes (the current
# node stays un-cleared -> a clean route position). The route map passes none. The compose itself backs a mid-fight
# NODE_RESOLUTION run out to the ACTIVE_ROUTE resumable boundary ON A COPY (QuitRunBridge), so the save round-trips.
#
# Verified BY CONSTRUCTION (the compile guardrail loads the presenters that preload this); on-screen legibility at
# the 2.0x text scale + >=44px targets is OSG-1. The testable decisions live in the two view models (unit-tested).

const PauseMenuViewModel = preload("res://scripts/ui/view_models/pause_menu_view_model.gd")
const SettingsOptionsViewModel = preload("res://scripts/ui/view_models/settings_options_view_model.gd")
const SettingsSnapshot = preload("res://scripts/settings/settings_snapshot.gd")
const QuitRunBridge = preload("res://scripts/ui/flow/quit_run_bridge.gd")
const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# The boot/menu (Continue-offering) surface a Save & Exit returns to — NOT the outpost (the run-END destination).
const BOOT_STAGE := "boot"
const TITLE_FONT_SIZE := 28

var _flow: RunFlowController = null
var _on_dismiss: Callable = Callable()
var _on_before_quit: Callable = Callable()
var _panel: VBoxContainer = null

# Open the pause menu over the given run-flow handle. on_dismiss is invoked on Resume play (the host presenter frees
# this overlay + clears its reference). on_before_quit (optional) runs just before Save & Exit composes the save (the
# board discards its ephemeral fight here; the route map passes an empty Callable).
func open(flow: RunFlowController, on_dismiss: Callable, on_before_quit: Callable = Callable()) -> void:
	_flow = flow
	_on_dismiss = on_dismiss
	_on_before_quit = on_before_quit
	_build_scaffold()
	_show_main()


# The modal scaffold: a mouse-blocking full-rect backdrop so taps never fall through to the board/map, and a centered
# panel the two views (main / options) render into.
func _build_scaffold() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop: ColorRect = ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.7)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_panel = VBoxContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	add_child(_panel)


# The main pause view: title, run metrics, Resume play, Save & Exit (if offered), Options.
func _show_main() -> void:
	_clear_panel()
	var view: PauseMenuViewModel = PauseMenuViewModel.from_run(_run())

	_panel.add_child(_title_label("Paused"))
	for line: String in _metric_lines(view.metrics):
		_panel.add_child(_body_label(line))

	if view.offer_resume:
		_panel.add_child(_menu_button("Resume play", _on_resume_pressed))
	if view.offer_save_and_exit:
		_panel.add_child(_menu_button("Save & Exit", _on_save_and_exit_pressed))
	if view.offer_options:
		_panel.add_child(_menu_button("Options", _show_options))


# The Options sub-view: the minimal preference rows over the existing SettingsSnapshot seams + a Back affordance.
func _show_options() -> void:
	_clear_panel()
	_panel.add_child(_title_label("Options"))
	for row: Dictionary in SettingsOptionsViewModel.rows(_current_settings()):
		var option_id: String = String(row.get("id", ""))
		var button: Button = _menu_button("%s: %s" % [String(row.get("label", "")), String(row.get("value_display", ""))], Callable())
		button.pressed.connect(_on_option_pressed.bind(option_id))
		_panel.add_child(button)
	_panel.add_child(_menu_button("Back", _show_main))


# Advance one preference, persist + apply it through SettingsManager, then re-render the Options view (so the row
# reflects the new value). Persistence/apply rides the EXISTING autoload; a headless/absent autoload is a no-op.
func _on_option_pressed(option_id: String) -> void:
	var mutated: SettingsSnapshot = SettingsOptionsViewModel.apply(_current_settings(), option_id)
	if has_node("/root/SettingsManager"):
		SettingsManager.save_settings(mutated)
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"pause_menu_option_changed", {"option_id": option_id})
	_show_options()


# Resume play: hand back to the host presenter (which frees this overlay + clears its reference). The fight/position
# is untouched (no compose is invoked).
func _on_resume_pressed() -> void:
	if _on_dismiss.is_valid():
		_on_dismiss.call()


# Save & Exit (the existing Quit-run behavior, relabelled): discard the host's ephemeral fight (board only), SAVE
# the route position through the EXISTING seam (QuitRunBridge composes at the resumable boundary -> SaveManager
# persists), clear the run-flow handle, and return to the boot/menu (Continue-offering) surface — NOT the outpost.
func _on_save_and_exit_pressed() -> void:
	if _on_before_quit.is_valid():
		_on_before_quit.call()
	var orchestrator: RunOrchestrator = _flow.orchestrator() if _flow != null else null
	var snapshot: RunSnapshot = QuitRunBridge.compose_quit_save(orchestrator) if orchestrator != null else null
	if snapshot != null and has_node("/root/SaveManager"):
		SaveManager.autosave_route_position(snapshot)
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"pause_menu_save_and_exit", {"saved": snapshot != null})
	if has_node("/root/GameSession"):
		GameSession.clear_run_flow()
	if has_node("/root/SceneManager"):
		SceneManager.go_to_stage(BOOT_STAGE)


# The human-readable run-metrics lines from the projection (pure reads — selected class, depth, route progress,
# gold, corruption). Order is stable for OSG-1 legibility.
func _metric_lines(metrics: Dictionary) -> Array[String]:
	return [
		"Class: %s" % String(metrics.get("class_display", "—")),
		"Depth: %d" % int(metrics.get("depth", 0)),
		"Cleared: %d / %d" % [int(metrics.get("cleared_nodes", 0)), int(metrics.get("total_nodes", 0))],
		"Gold: %d" % int(metrics.get("gold", 0)),
		"Corruption: %d" % int(metrics.get("corruption", 0))
	]


func _clear_panel() -> void:
	for child: Node in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()


func _title_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	return label


func _body_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	return label


# A >=44px menu button. An empty on_pressed leaves the caller to wire pressed (the Options rows bind an argument).
func _menu_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
	if on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	return button


func _run() -> RunState:
	return _flow.run() if _flow != null else null


# The current settings snapshot (via the SettingsManager autoload), or defaults in a headless/absent context.
func _current_settings() -> SettingsSnapshot:
	if has_node("/root/SettingsManager"):
		var current: SettingsSnapshot = SettingsManager.current()
		if current != null:
			return current
	return SettingsSnapshot.defaults()
