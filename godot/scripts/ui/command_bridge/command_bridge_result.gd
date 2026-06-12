class_name CommandBridgeResult
extends RefCounted

var succeeded: bool = false
var disabled: bool = true
var error_code: StringName = &""
var reason: String = ""
var intent_id: StringName = &""
var command_id: StringName = &""
var command: Variant = null
var metadata: Dictionary = {}

func to_dictionary() -> Dictionary:
	return {
		"succeeded": succeeded,
		"disabled": disabled,
		"error_code": String(error_code),
		"reason": reason,
		"intent_id": String(intent_id),
		"command_id": String(command_id),
		"has_command": command != null,
		"metadata": metadata.duplicate(true)
	}


static func command_ready(
	new_intent_id: StringName,
	new_command_id: StringName,
	new_command: Variant,
	new_metadata: Dictionary = {},
	new_reason: String = "valid"
) -> CommandBridgeResult:
	var result: CommandBridgeResult = load("res://scripts/ui/command_bridge/command_bridge_result.gd").new()
	result.succeeded = true
	result.disabled = false
	result.intent_id = new_intent_id
	result.command_id = new_command_id
	result.command = new_command
	result.reason = new_reason
	result.metadata = new_metadata.duplicate(true)
	return result


static func metadata_only(
	new_intent_id: StringName,
	new_metadata: Dictionary = {},
	new_reason: String = "inspect"
) -> CommandBridgeResult:
	var result: CommandBridgeResult = load("res://scripts/ui/command_bridge/command_bridge_result.gd").new()
	result.succeeded = true
	result.disabled = false
	result.intent_id = new_intent_id
	result.command_id = &""
	result.command = null
	result.reason = new_reason
	result.metadata = new_metadata.duplicate(true)
	return result


static func disabled_result(
	new_intent_id: StringName,
	new_error_code: StringName,
	new_reason: String,
	new_metadata: Dictionary = {}
) -> CommandBridgeResult:
	var result: CommandBridgeResult = load("res://scripts/ui/command_bridge/command_bridge_result.gd").new()
	result.succeeded = false
	result.disabled = true
	result.intent_id = new_intent_id
	result.error_code = new_error_code
	result.reason = new_reason
	result.command_id = &""
	result.command = null
	result.metadata = new_metadata.duplicate(true)
	return result
