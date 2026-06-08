class_name TacticalBoardViewModel
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const TacticalActionAvailability = preload("res://scripts/ui/view_models/tactical_action_availability.gd")
const TacticalCellView = preload("res://scripts/ui/view_models/tactical_cell_view.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalOccupantView = preload("res://scripts/ui/view_models/tactical_occupant_view.gd")
const TacticalSelectionState = preload("res://scripts/ui/view_models/tactical_selection_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")

var _width: int = 0
var _height: int = 0
var _cells: Array[Dictionary] = []
var _occupants: Array[Dictionary] = []
var _selected_cell: Variant = null
var _selected_entity_id: String = ""
var _preview: Dictionary = {}
var _action_availability: Dictionary = {}
var _turn: Dictionary = {}
var _outcome: Dictionary = {}
var _event_log_summary: Array[Dictionary] = []

func to_dictionary() -> Dictionary:
	return {
		"width": _width,
		"height": _height,
		"cells": _cells.duplicate(true),
		"occupants": _occupants.duplicate(true),
		"selected_cell": null if _selected_cell == null else (_selected_cell as Dictionary).duplicate(true),
		"selected_entity_id": _selected_entity_id,
		"preview": _preview.duplicate(true),
		"action_availability": _action_availability.duplicate(true),
		"turn": _turn.duplicate(true),
		"outcome": _outcome.duplicate(true),
		"event_log_summary": _event_log_summary.duplicate(true)
	}


static func from_domain(
	board: BoardState,
	turn_state: TacticalTurnState = null,
	options: Dictionary = {}
) -> TacticalBoardViewModel:
	var view_model: TacticalBoardViewModel = load("res://scripts/ui/view_models/tactical_board_view_model.gd").new()
	if board == null:
		return view_model

	view_model._width = board.width
	view_model._height = board.height
	view_model._cells = _build_cell_views(board)
	view_model._occupants = _build_occupant_views(board)

	var selection: TacticalSelectionState = TacticalSelectionState.from_options(options)
	var selection_data: Dictionary = selection.to_dictionary()
	view_model._selected_cell = selection_data.get("selected_cell")
	view_model._selected_entity_id = String(selection_data.get("selected_entity_id", ""))

	view_model._preview = _preview_from_options(options)
	view_model._action_availability = _action_availability_from_options(options, view_model._preview)
	view_model._turn = turn_state.to_dictionary() if turn_state != null else {}
	view_model._outcome = _outcome_from_options(options)
	view_model._event_log_summary = _dictionary_array_from_options(options, &"event_log_summary")
	return view_model


static func _build_cell_views(board: BoardState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var query: TacticalVisibilityQuery = TacticalVisibilityQuery.new()
	for board_cell: BoardCell in board.cells():
		var fact_result: ActionResult = query.visible_facts_for_cell(board, board_cell.position)
		var fact: Dictionary = {}
		if fact_result.succeeded and fact_result.metadata.get("fact", {}) is Dictionary:
			fact = fact_result.metadata.get("fact", {})
		else:
			fact = {
				"position": _cell_metadata(board_cell.position),
				"visibility_state": "hidden"
			}
		var cell_view: TacticalCellView = TacticalCellView.from_visibility_fact(fact)
		result.append(cell_view.to_dictionary())
	result.sort_custom(_sort_cell_views_by_position)
	return result


static func _build_occupant_views(board: BoardState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entity: TacticalEntityState in board.entities():
		var board_cell: BoardCell = board.get_cell(entity.position)
		if board_cell == null:
			continue
		if not board_cell.visible:
			continue
		if board_cell.occupant_id != entity.entity_id:
			continue
		var occupant_view: TacticalOccupantView = TacticalOccupantView.from_entity(entity)
		result.append(occupant_view.to_dictionary())
	result.sort_custom(_sort_occupants_by_id)
	return result


static func _preview_from_options(options: Dictionary) -> Dictionary:
	var preview_value: Variant = _field(options, &"preview") if _has_field(options, &"preview") else {}
	var preview_data: Dictionary = preview_value if preview_value is Dictionary else {}
	if preview_data.is_empty():
		return {}
	var kind: String = String(_field(preview_data, &"kind") if _has_field(preview_data, &"kind") else "")
	if kind.is_empty():
		return {}
	var available: bool = bool(_field(preview_data, &"available") if _has_field(preview_data, &"available") else false)
	var reason: String = String(_field(preview_data, &"reason") if _has_field(preview_data, &"reason") else "none")
	var commit_available: bool = bool(_field(preview_data, &"commit_available") if _has_field(preview_data, &"commit_available") else available)
	var commit_reason: String = String(_field(preview_data, &"commit_reason") if _has_field(preview_data, &"commit_reason") else reason)
	var normalized: Dictionary = {
		"kind": kind,
		"available": available,
		"reason": reason,
		"actor_id": String(_field(preview_data, &"actor_id") if _has_field(preview_data, &"actor_id") else ""),
		"target_cell": _safe_value(_field(preview_data, &"target_cell") if _has_field(preview_data, &"target_cell") else null),
		"target_valid": bool(_field(preview_data, &"target_valid") if _has_field(preview_data, &"target_valid") else available),
		"commit_available": commit_available,
		"commit_reason": commit_reason,
		"cue_ids": _safe_array_copy(_field(preview_data, &"cue_ids") if _has_field(preview_data, &"cue_ids") else []),
		"metadata": _dictionary_copy(_field(preview_data, &"metadata") if _has_field(preview_data, &"metadata") else {})
	}
	if kind == "attack" or _has_field(preview_data, &"target_entity_id"):
		normalized["target_entity_id"] = String(_field(preview_data, &"target_entity_id") if _has_field(preview_data, &"target_entity_id") else "")
	return normalized


static func _action_availability_from_options(options: Dictionary, preview_data: Dictionary) -> Dictionary:
	var availability: TacticalActionAvailability = TacticalActionAvailability.from_preview(preview_data)
	var normalized: Dictionary = availability.to_dictionary()
	var availability_value: Variant = _field(options, &"action_availability") if _has_field(options, &"action_availability") else {}
	if not availability_value is Dictionary:
		return normalized

	var availability_data: Dictionary = availability_value
	for action_id: StringName in [&"move", &"attack", &"inspect", &"confirm", &"cancel"]:
		if not _has_field(availability_data, action_id):
			continue
		var entry_value: Variant = _field(availability_data, action_id)
		if entry_value is Dictionary:
			normalized[String(action_id)] = _availability_entry(entry_value, normalized.get(String(action_id), {}))
	return normalized


static func _dictionary_from_options(options: Dictionary, key: StringName) -> Dictionary:
	return _dictionary_copy(_field(options, key) if _has_field(options, key) else {})


static func _outcome_from_options(options: Dictionary) -> Dictionary:
	var outcome_state_value: Variant = _field(options, &"outcome_state") if _has_field(options, &"outcome_state") else null
	if outcome_state_value is CombatOutcomeState:
		var outcome_state: CombatOutcomeState = outcome_state_value as CombatOutcomeState
		return outcome_state.to_dictionary()
	return _dictionary_from_options(options, &"outcome")


static func _dictionary_array_from_options(options: Dictionary, key: StringName) -> Array[Dictionary]:
	var value: Variant = _field(options, key) if _has_field(options, key) else []
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for item: Variant in value:
		if item is Dictionary:
			result.append(_dictionary_copy(item))
	return result


static func _dictionary_copy(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	return _safe_dictionary_copy(value)


static func _availability_entry(value: Dictionary, fallback: Dictionary) -> Dictionary:
	return {
		"enabled": bool(_field(value, &"enabled") if _has_field(value, &"enabled") else fallback.get("enabled", false)),
		"reason": String(_field(value, &"reason") if _has_field(value, &"reason") else fallback.get("reason", "unavailable"))
	}


static func _safe_dictionary_copy(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source.keys():
		if not (key is String or key is StringName):
			continue
		result[String(key)] = _safe_value(source[key])
	return result


static func _safe_array_copy(source: Array) -> Array:
	var result: Array = []
	for item: Variant in source:
		result.append(_safe_value(item))
	return result


static func _safe_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return value
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return null
			return numeric_value
		TYPE_STRING:
			return String(value)
		TYPE_STRING_NAME:
			return String(value)
		TYPE_VECTOR2I:
			var cell: Vector2i = value
			return _cell_metadata(cell)
		TYPE_ARRAY:
			return _safe_array_copy(value)
		TYPE_DICTIONARY:
			return _safe_dictionary_copy(value)
		_:
			return null


static func _cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


static func _sort_cell_views_by_position(first: Dictionary, second: Dictionary) -> bool:
	var first_position: Dictionary = first.get("position", {})
	var second_position: Dictionary = second.get("position", {})
	if int(first_position.get("y", 0)) == int(second_position.get("y", 0)):
		return int(first_position.get("x", 0)) < int(second_position.get("x", 0))
	return int(first_position.get("y", 0)) < int(second_position.get("y", 0))


static func _sort_occupants_by_id(first: Dictionary, second: Dictionary) -> bool:
	return String(first.get("entity_id", "")) < String(second.get("entity_id", ""))
