class_name GameCommand
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")

var command_id: StringName = &""

func validate(_state: Variant) -> ActionResult:
	return ActionResult.error(&"not_implemented")


func execute(_state: Variant) -> ActionResult:
	return ActionResult.error(&"not_implemented")
