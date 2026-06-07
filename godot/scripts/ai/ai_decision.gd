class_name AiDecision
extends RefCounted

var enemy_id: StringName = &""
var enemy_definition_id: StringName = &""
var action_id: StringName = &"wait"
var score: int = 0
var reasons: Array[String] = []
var target_entity_id: StringName = &""
var from_cell: Vector2i = Vector2i(-1, -1)
var to_cell: Vector2i = Vector2i(-1, -1)
var target_cell: Vector2i = Vector2i(-1, -1)
var wait_reason: StringName = &""
var metadata: Dictionary = {}

func _init(
	new_enemy_id: StringName = &"",
	new_enemy_definition_id: StringName = &"",
	new_action_id: StringName = &"wait",
	new_score: int = 0,
	new_reasons: Array[String] = [],
	new_target_entity_id: StringName = &"",
	new_from_cell: Vector2i = Vector2i(-1, -1),
	new_to_cell: Vector2i = Vector2i(-1, -1),
	new_target_cell: Vector2i = Vector2i(-1, -1),
	new_wait_reason: StringName = &"",
	new_metadata: Dictionary = {}
) -> void:
	enemy_id = new_enemy_id
	enemy_definition_id = new_enemy_definition_id
	action_id = new_action_id
	score = new_score
	reasons = new_reasons.duplicate()
	target_entity_id = new_target_entity_id
	from_cell = new_from_cell
	to_cell = new_to_cell
	target_cell = new_target_cell
	wait_reason = new_wait_reason
	metadata = new_metadata.duplicate(true)


func to_dictionary() -> Dictionary:
	var result: Dictionary = {
		"enemy_id": String(enemy_id),
		"enemy_definition_id": String(enemy_definition_id),
		"action_id": String(action_id),
		"score": score,
		"reasons": reasons.duplicate(),
		"metadata": metadata.duplicate(true)
	}
	if target_entity_id != &"":
		result["target_entity_id"] = String(target_entity_id)
	if from_cell != Vector2i(-1, -1):
		result["from_cell"] = _cell_metadata(from_cell)
	if to_cell != Vector2i(-1, -1):
		result["to_cell"] = _cell_metadata(to_cell)
	if target_cell != Vector2i(-1, -1):
		result["target_cell"] = _cell_metadata(target_cell)
	if wait_reason != &"":
		result["wait_reason"] = String(wait_reason)
	return result


static func _cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}
