class_name BootController
extends Control

# The boot presenter (Story 2 baseline; Story 11.3 routes it into the run flow; Story 15.4 adds the Continue
# affordance). It boots the app, then EITHER offers Continue + New Run (when a saved run exists) OR enters the
# FIRST run-flow stage (hero select) directly (a cold start), via the SceneManager named-stage surface. It guards
# has_node("/root/SceneManager") + logs via Diagnostics (the reference presenter pattern every 11.3 presenter
# follows). It OWNS no run/tactical/save truth — it reads the scene-free BootMenuViewModel decision (projected
# from SaveManager.has_saved_run()) and only navigates.
#
# ⭐ Story 15.4 (AC2) — the boot-Continue branch. On boot it reads has-saved-run through the additive
# SaveManager.has_saved_run() probe (a file-existence check; NO schema change) and projects the affordances via
# BootMenuViewModel (fail-closed: a false/malformed probe -> no Continue). A saved run -> a menu with Continue
# (resume -> the reachable save_recovery landing -> seat -> route map, kit re-derived) + New Run (the class
# picker). No saved run -> today's byte-identical straight-to-hero-select boot. New Run is pure navigation: the
# overwrite confirm + save-clear rides the hero-select confirm (the actual new-run-start locus), so the saved run
# survives until a fresh descent is genuinely begun.

const BootMenuViewModel = preload("res://scripts/ui/view_models/boot_menu_view_model.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

# The first run-flow stage the boot chain enters (Story 11.3). The launch stage IS the boot chain; boot advances
# to hero select (the class picker) — the RunFlowRouter STAGES vocabulary's second stage.
const FIRST_FLOW_STAGE := "hero_select"
# Story 15.4: the Continue landing — the existing save_recovery presenter (resume -> seat -> route map), now made
# reachable as a named non-linear stage.
const CONTINUE_STAGE := "save_recovery"

const TITLE_FONT_SIZE := 32

func _ready() -> void:
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"app", &"boot_ready", {"scene": "boot"})
	# Story 15.4: project the boot affordances from has-saved-run (fail-closed). A saved run -> the Continue menu;
	# a cold start (or a failed/absent probe) -> today's straight-to-hero-select boot.
	var decision: BootMenuViewModel = BootMenuViewModel.from_has_saved_run(_has_saved_run())
	if decision.offer_continue:
		_build_boot_menu(decision)
		if has_node("/root/Diagnostics"):
			Diagnostics.info(&"app", &"boot_menu_offered", {"offer_continue": decision.offer_continue})
	else:
		# A cold start — boot straight into hero select (the Story-11.3 behavior, byte-identical).
		call_deferred("_enter_first_flow_stage")


# The has-saved-run probe (additive; a file-existence check through the SaveManager delegator). Fail-closed to
# false when the autoload is absent (a headless / no-save context never offers Continue).
func _has_saved_run() -> bool:
	if has_node("/root/SaveManager"):
		return SaveManager.has_saved_run()
	return false


# Build the boot menu (Continue + New Run). Both affordances are ≥44px touch targets legible at the 2.0x text
# scale (NFR9 — the render is verified by construction; on-screen legibility is OSG-1). Built in code (the
# reference presenter idiom — no scene fork; the .tscn stays the thin Control host).
func _build_boot_menu(decision: BootMenuViewModel) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	add_child(root)

	var title: Label = Label.new()
	title.text = "Sealsworn"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	root.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "A descent awaits — continue where you left off, or begin anew."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(subtitle)

	if decision.offer_continue:
		var continue_button: Button = Button.new()
		continue_button.text = "Continue"
		continue_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
		continue_button.pressed.connect(_on_continue_pressed)
		root.add_child(continue_button)

	if decision.offer_new_run:
		var new_run_button: Button = Button.new()
		new_run_button.text = "New Run"
		new_run_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
		new_run_button.pressed.connect(_on_new_run_pressed)
		root.add_child(new_run_button)


# Continue: route to the reachable save_recovery landing (it resumes -> seats via start_from [the kit is
# re-derived there] -> GameSession.set_run_flow -> route map; on a corrupt/unreadable save it renders the
# RunResumeRecoveryView recovery message + retry/fresh-start). The boot presenter does NOT resume itself — it
# reuses the shipped recovery presenter (no fork).
func _on_continue_pressed() -> void:
	if not has_node("/root/SceneManager"):
		return
	var result: Error = SceneManager.go_to_stage(CONTINUE_STAGE)
	if result != OK and has_node("/root/Diagnostics"):
		Diagnostics.info(&"app", &"boot_scene_change_failed", {
			"target_stage": CONTINUE_STAGE,
			"error": result
		})


# New Run: navigate to the class picker. This is pure navigation — the deliberate overwrite confirm + the stale
# save-clear happen at the hero-select confirm (the actual new-run-start locus), so a saved run is never silently
# overwritten and survives if the player backs out before beginning a fresh descent.
func _on_new_run_pressed() -> void:
	_enter_first_flow_stage()


func _enter_first_flow_stage() -> void:
	if not has_node("/root/SceneManager"):
		return

	var result: Error = SceneManager.go_to_stage(FIRST_FLOW_STAGE)
	if result != OK and has_node("/root/Diagnostics"):
		Diagnostics.info(&"app", &"boot_scene_change_failed", {
			"target_stage": FIRST_FLOW_STAGE,
			"error": result
		})
