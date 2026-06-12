class_name TacticalMovementPreview
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalMovementQuery = preload("res://scripts/tactical/movement/tactical_movement_query.gd")
const TacticalPreviewView = preload("res://scripts/ui/view_models/tactical_preview_view.gd")

var _data: Dictionary = {}

func _init(new_data: Dictionary = {}) -> void:
	_data = TacticalPreviewView.safe_dictionary_copy(new_data)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


static func from_query(
	board: BoardState,
	actor_id: StringName,
	target_cell: Vector2i,
	movement_budget: int = TacticalMovementQuery.DEFAULT_MOVEMENT_BUDGET
) -> TacticalMovementPreview:
	var validation: ActionResult = TacticalMovementQuery.new().validate_target(board, actor_id, target_cell, movement_budget)
	var source_metadata: Dictionary = validation.metadata if validation.metadata is Dictionary else {}
	var reason: String = String(source_metadata.get("reason", "valid" if validation.succeeded else validation.error_code))
	var available: bool = validation.succeeded
	var movement_cost: int = int(source_metadata.get("movement_cost", 0))
	var resolved_budget: int = int(source_metadata.get("movement_budget", movement_budget))

	var metadata: Dictionary = {
		"path": TacticalPreviewView.safe_array_copy(source_metadata.get("path", [])) if available else [],
		"movement_cost": movement_cost,
		"movement_budget": resolved_budget,
		"blocked_reason": "" if available else reason
	}
	_copy_invalid_metadata(metadata, source_metadata)

	var data: Dictionary = {
		"kind": "move",
		"available": available,
		"reason": reason,
		"actor_id": String(actor_id),
		"target_cell": TacticalPreviewView.cell_metadata(target_cell),
		"target_valid": available,
		"commit_available": available,
		"commit_reason": reason,
		"cue_ids": _cue_ids(available),
		"metadata": metadata
	}
	return load("res://scripts/ui/view_models/tactical_movement_preview.gd").new(data)


static func _copy_invalid_metadata(target: Dictionary, source: Dictionary) -> void:
	for key: Variant in source.keys():
		var key_text: String = String(key)
		if ["reason", "path", "movement_cost", "movement_budget"].has(key_text):
			continue
		target[key_text] = TacticalPreviewView.safe_value(source[key])


static func _cue_ids(available: bool) -> Array[String]:
	if available:
		return ["move_preview_valid", "commit_available"]
	return ["move_preview_invalid", "commit_unavailable"]
