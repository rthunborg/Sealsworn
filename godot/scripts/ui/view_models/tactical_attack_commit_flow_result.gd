class_name TacticalAttackCommitFlowResult
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const TacticalPreviewView = preload("res://scripts/ui/view_models/tactical_preview_view.gd")

var submitted: bool = false
var submitted_command_id: String = ""
var reason: String = "none"
var command_result: ActionResult = null
var _flow_state: Dictionary = {}

func _init(
	new_submitted: bool = false,
	new_submitted_command_id: String = "",
	new_reason: String = "none",
	new_command_result: ActionResult = null,
	new_flow_state: Dictionary = {}
) -> void:
	submitted = new_submitted
	submitted_command_id = new_submitted_command_id
	reason = new_reason
	command_result = new_command_result
	_flow_state = TacticalPreviewView.safe_dictionary_copy(new_flow_state)


func to_dictionary() -> Dictionary:
	return {
		"submitted": submitted,
		"submitted_command_id": submitted_command_id,
		"reason": reason,
		"command_result_summary": _command_result_summary(command_result),
		"flow": _flow_state.duplicate(true)
	}


static func from_flow(
	new_submitted: bool,
	new_submitted_command_id: String,
	new_reason: String,
	new_command_result: ActionResult,
	new_flow_state: Dictionary
) -> TacticalAttackCommitFlowResult:
	return load("res://scripts/ui/view_models/tactical_attack_commit_flow_result.gd").new(
		new_submitted,
		new_submitted_command_id,
		new_reason,
		new_command_result,
		new_flow_state
	)


static func _command_result_summary(result_value: ActionResult) -> Dictionary:
	if result_value == null:
		return {}
	return {
		"succeeded": result_value.succeeded,
		"error_code": String(result_value.error_code),
		"event_count": result_value.events.size(),
		"metadata": TacticalPreviewView.safe_dictionary_copy(result_value.metadata)
	}
