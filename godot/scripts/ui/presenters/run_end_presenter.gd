extends Control

# Story 11.3 (AC1) — the RUN-END presenter: the MINIMAL run-end landing the run-end return navigates to (a
# terminal RunEndOutcome.next_destination == outpost routes here via SceneManager.route_after_run_end). It READS
# the terminal RunEndOutcome from the live RunFlowController (phase + outcome/cause + meta eligibility) and shows
# a minimal "the run ended; here is how" summary + a "return to the outpost" affordance.
#
# ⭐ IT IS DELIBERATELY MINIMAL — NOT the polished OUTPOST scene (that is Story 11.5, bound to OutpostViewModel
# with the named-space tiles + the first-death/first-victory reveal beats). 11.3 only NAVIGATES to the outpost
# DESTINATION; a minimal placeholder landing is acceptable so long as it does not pre-empt or duplicate 11.5's
# OutpostViewModel-bound scene. It does NOT build the outpost dashboard, the reveal beats, or the meta-spend. It
# clears the live run-flow handle (a fresh descent starts clean) and, on "return", boots back to hero select.
# Verified BY CONSTRUCTION; the run-end fact is derived from the domain (RunEndOutcome), unit-tested via the
# RunFlowController.

const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunEndOutcome = preload("res://scripts/run/run_end_outcome.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

var _summary_label: Label = null

func _ready() -> void:
	_build_layout()
	_render_outcome()
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"run_end_ready", {})


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	add_child(root)

	var title: Label = Label.new()
	title.text = "The Descent Ends"
	root.add_child(title)

	_summary_label = Label.new()
	root.add_child(_summary_label)

	var return_button: Button = Button.new()
	return_button.text = "Return to the Outpost"
	return_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
	return_button.pressed.connect(_on_return_pressed)
	root.add_child(return_button)


func _render_outcome() -> void:
	var outcome: Dictionary = _run_end_outcome_dict()
	if not bool(outcome.get("has_ended", false)):
		_summary_label.text = "No completed run."
		return
	var phase: String = String(outcome.get("phase", ""))
	var cause: String = String(outcome.get("outcome_or_cause", ""))
	var eligible: bool = bool(outcome.get("meta_progression_eligible", false))
	var verdict: String = "Victory" if phase == "completed" else "Fallen"
	_summary_label.text = "%s — %s%s" % [
		verdict,
		cause,
		"  (meta-progression eligible)" if eligible else "  (practice run — not eligible)"
	]


func _run_end_outcome_dict() -> Dictionary:
	var flow: RunFlowController = _flow()
	if flow == null:
		return RunEndOutcome._empty().to_dictionary()
	return flow.run_end_outcome()


# Return to the outpost destination. 11.3 clears the run-flow handle (a fresh descent starts clean) and boots back
# to hero select (the minimal landing; the polished OutpostViewModel-bound outpost scene is 11.5's).
func _on_return_pressed() -> void:
	if has_node("/root/GameSession"):
		GameSession.clear_run_flow()
	if has_node("/root/SceneManager"):
		SceneManager.go_to_stage("hero_select")


func _flow() -> RunFlowController:
	if not has_node("/root/GameSession"):
		return null
	return GameSession.run_flow() as RunFlowController
