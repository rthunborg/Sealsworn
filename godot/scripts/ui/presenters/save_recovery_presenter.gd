extends Control

# Story 11.3 (AC3) — the SAVE/RESUME RECOVERY presenter. It drives the between-level resume path through real
# screens: SaveManager.resume_route_position(save_path) / resume_run(save_path) (the route delegators ->
# RunResumeService) resume from the persisted snapshot; the autosave entry points fire at the between-node/
# between-level boundary the flow already reaches. It reads the structured ActionResult CODE as truth (NOT stderr)
# and maps it via RunResumeRecoveryView to a clear on-screen message + a retry / start-fresh affordance (the seven
# §13.3 recovery codes).
#
# ⭐ THE RESUME INVARIANT (NFR13) the screen MUST respect: it presents a message + a retry/fresh-start CHOICE, but
# it NEVER itself perturbs the restored run (consumes no RNG, runs no command, advances no turn). The DOMAIN does
# the restore; the screen renders the ActionResult and offers the choice. On SUCCESS it seats the resumed run on a
# fresh RunFlowController (start_from) + continues the flow; on FAILURE NO partial state becomes active (the
# RunResumeService "no partial corrupt state" guarantee — the restore exposes zero restored objects).
#
# Verified BY CONSTRUCTION; the TESTABLE logic (the resume service + the recovery-code mapping) is unit-tested
# (RunResumeService + RunResumeRecoveryView + the extended resume-invariant coverage).

const RunResumeRecoveryView = preload("res://scripts/ui/view_models/run_resume_recovery_view.gd")
const RunFlowController = preload("res://scripts/ui/flow/run_flow_controller.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalLayoutProfile = preload("res://scripts/ui/view_models/tactical_layout_profile.gd")

var _message_label: Label = null
var _retry_button: Button = null
var _fresh_button: Button = null
var _save_path: String = ""

func _ready() -> void:
	_build_layout()
	_attempt_resume()
	if has_node("/root/Diagnostics"):
		Diagnostics.info(&"ui", &"save_recovery_ready", {})


# Set the save path to resume from (the run autosave path). Called before the scene enters, or defaults to the
# repository default.
func set_save_path(save_path: String) -> void:
	_save_path = save_path


func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", int(TacticalLayoutProfile.COMFORTABLE_SPACING))
	add_child(root)

	var title: Label = Label.new()
	title.text = "Resuming Your Descent"
	root.add_child(title)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)

	_retry_button = Button.new()
	_retry_button.text = "Try Again"
	_retry_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
	_retry_button.visible = false
	_retry_button.pressed.connect(_on_retry_pressed)
	root.add_child(_retry_button)

	_fresh_button = Button.new()
	_fresh_button.text = "Start a Fresh Descent"
	_fresh_button.custom_minimum_size = TacticalLayoutProfile.DEFAULT_MINIMUM_TOUCH_TARGET
	_fresh_button.visible = false
	_fresh_button.pressed.connect(_on_fresh_pressed)
	root.add_child(_fresh_button)


# Attempt the between-level route-position resume. The domain does the restore; this reads the structured result
# and renders the recovery surface (or continues the flow on success). It runs NO command / advances NO turn.
func _attempt_resume() -> void:
	if not has_node("/root/SaveManager"):
		_render_recovery(RunResumeRecoveryView.from_error_code(&"save_not_found"))
		return
	var resume_result
	if _save_path.is_empty():
		resume_result = SaveManager.resume_route_position()
	else:
		resume_result = SaveManager.resume_route_position(_save_path)

	# Read the STRUCTURED code as truth (NOT stderr). Map it to the recovery surface.
	var recovery: RunResumeRecoveryView = RunResumeRecoveryView.from_result(resume_result)
	if not recovery.has_recovery:
		_seat_resumed_run(resume_result)
		return
	_render_recovery(recovery)


# On a SUCCESSFUL resume, seat the restored run on a fresh RunFlowController (start_from — no RNG, no command, no
# turn) + continue the flow to the route map. The restore already happened in the domain; this only seats the
# handle.
func _seat_resumed_run(resume_result) -> void:
	var run: RunState = resume_result.metadata.get("run_state") as RunState
	var streams: RngStreamSet = resume_result.metadata.get("rng_streams") as RngStreamSet
	if run == null or streams == null:
		_render_recovery(RunResumeRecoveryView.from_error_code(&"invalid_tactical_snapshot"))
		return
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var seat = orchestrator.start_from(run, streams)
	if seat.is_error():
		_render_recovery(RunResumeRecoveryView.from_error_code(seat.error_code))
		return
	var controller: RunFlowController = RunFlowController.new(orchestrator)
	if has_node("/root/GameSession"):
		GameSession.set_run_flow(controller)
	if has_node("/root/SceneManager"):
		SceneManager.go_to_stage("route_map")


func _render_recovery(recovery: RunResumeRecoveryView) -> void:
	var data: Dictionary = recovery.to_dictionary()
	_message_label.text = String(data.get("message", ""))
	_retry_button.visible = bool(data.get("can_retry", false))
	_fresh_button.visible = bool(data.get("can_start_fresh", false))


# Retry re-runs the resume (a transient failure may recover). It runs NO command / advances NO turn — a fresh
# read of the save.
func _on_retry_pressed() -> void:
	_attempt_resume()


# Start fresh: clear the run-flow handle + boot to hero select (no partial corrupt state ever became active).
func _on_fresh_pressed() -> void:
	if has_node("/root/GameSession"):
		GameSession.clear_run_flow()
	if has_node("/root/SceneManager"):
		SceneManager.go_to_stage("hero_select")
