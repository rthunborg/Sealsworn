class_name AiAction
extends RefCounted

var action_id: StringName = &"wait"
var score: int = 0
var reasons: Array[String] = []
var metadata: Dictionary = {}

func _init(
	new_action_id: StringName = &"wait",
	new_score: int = 0,
	new_reasons: Array[String] = [],
	new_metadata: Dictionary = {}
) -> void:
	action_id = new_action_id
	score = new_score
	reasons = new_reasons.duplicate()
	metadata = new_metadata.duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"action_id": String(action_id),
		"score": score,
		"reasons": reasons.duplicate(),
		"metadata": metadata.duplicate(true)
	}
