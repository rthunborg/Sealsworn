class_name TacticalInspectView
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackPreview = preload("res://scripts/ui/view_models/tactical_attack_preview.gd")
const TacticalCellView = preload("res://scripts/ui/view_models/tactical_cell_view.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalMovementPreview = preload("res://scripts/ui/view_models/tactical_movement_preview.gd")
const TacticalOccupantView = preload("res://scripts/ui/view_models/tactical_occupant_view.gd")
const TacticalPreviewView = preload("res://scripts/ui/view_models/tactical_preview_view.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")

var _data: Dictionary = {}

func _init(new_data: Dictionary = {}) -> void:
	_data = TacticalPreviewView.safe_dictionary_copy(new_data)


func to_dictionary() -> Dictionary:
	return _data.duplicate(true)


static func from_context(
	context: TacticalActionContext,
	target_cell: Vector2i,
	options: Dictionary = {}
) -> TacticalInspectView:
	if context == null or context.board == null:
		return _inspect_data_for_invalid_context(target_cell)

	var board: BoardState = context.board
	var fact_result: ActionResult = TacticalVisibilityQuery.new().visible_facts_for_cell(board, target_cell)
	if fact_result.is_error():
		return _inspect_data_for_visibility_error(target_cell, fact_result)

	var fact: Dictionary = TacticalPreviewView.safe_dictionary_copy(fact_result.metadata.get("fact", {}))
	var visibility_state: String = String(fact.get("visibility_state", "hidden"))
	var reason: String = _reason_for_visibility_state(visibility_state)
	var available: bool = visibility_state != "hidden"
	var cell_data: Dictionary = TacticalCellView.from_visibility_fact(fact).to_dictionary()
	var occupant_data: Dictionary = _occupant_data(board, fact, visibility_state)
	var movement_data: Dictionary = _movement_data(board, target_cell, visibility_state, options)
	var attack_data: Dictionary = _attack_data(board, target_cell, visibility_state, options)
	var telegraphs: Array[Dictionary] = _telegraphs_for_cell(context, target_cell, visibility_state, options)
	var cue_ids: Array[String] = _cue_ids(visibility_state, telegraphs, _current_turn_number(context))
	var metadata: Dictionary = TacticalPreviewView.safe_dictionary_copy(TacticalPreviewView.field(options, &"metadata", {}))

	var data: Dictionary = {
		"kind": "inspect",
		"available": available,
		"reason": reason,
		"target_cell": TacticalPreviewView.cell_metadata(target_cell),
		"visibility_state": visibility_state,
		"authoritative": bool(fact.get("authoritative", visibility_state == "visible")),
		"cell": cell_data,
		"occupant": occupant_data,
		"movement": movement_data,
		"attack_preview": attack_data,
		"hazards": [],
		"telegraphs": telegraphs,
		"cue_ids": cue_ids,
		"metadata": metadata
	}
	return load("res://scripts/ui/view_models/tactical_inspect_view.gd").new(data)


static func _inspect_data_for_invalid_context(target_cell: Vector2i) -> TacticalInspectView:
	var data: Dictionary = _base_disabled_inspect(target_cell, "invalid_context", "hidden")
	return load("res://scripts/ui/view_models/tactical_inspect_view.gd").new(data)


static func _inspect_data_for_visibility_error(target_cell: Vector2i, fact_result: ActionResult) -> TacticalInspectView:
	var reason: String = String(fact_result.metadata.get("reason", fact_result.error_code))
	var visibility_state: String = "out_of_bounds" if reason == "out_of_bounds" else "hidden"
	var data: Dictionary = _base_disabled_inspect(target_cell, reason, visibility_state)
	return load("res://scripts/ui/view_models/tactical_inspect_view.gd").new(data)


static func _base_disabled_inspect(target_cell: Vector2i, reason: String, visibility_state: String) -> Dictionary:
	return {
		"kind": "inspect",
		"available": false,
		"reason": reason,
		"target_cell": TacticalPreviewView.cell_metadata(target_cell),
		"visibility_state": visibility_state,
		"authoritative": false,
		"cell": {
			"position": TacticalPreviewView.cell_metadata(target_cell),
			"visibility_state": visibility_state
		},
		"occupant": {},
		"movement": _disabled_preview("move", &"", target_cell, reason),
		"attack_preview": _disabled_preview("attack", &"", target_cell, reason),
		"hazards": [],
		"telegraphs": [],
		"cue_ids": ["inspect_%s" % reason],
		"metadata": {}
	}


static func _occupant_data(board: BoardState, fact: Dictionary, visibility_state: String) -> Dictionary:
	if visibility_state != "visible":
		return {}
	if not fact.has("occupant_id"):
		return {}
	var entity_id: StringName = StringName(String(fact.get("occupant_id", "")))
	if entity_id == &"":
		return {}
	var entity: TacticalEntityState = board.get_entity(entity_id)
	if entity == null:
		return {}
	return TacticalOccupantView.from_entity(entity).to_dictionary()


static func _movement_data(board: BoardState, target_cell: Vector2i, visibility_state: String, options: Dictionary) -> Dictionary:
	var actor_id: StringName = _actor_id_from_options(options)
	if actor_id == &"":
		return _disabled_preview("move", actor_id, target_cell, "missing_actor")
	if visibility_state == "hidden":
		return _disabled_preview("move", actor_id, target_cell, "not_visible")
	var movement_budget: int = _movement_budget_from_options(options)
	return TacticalMovementPreview.from_query(board, actor_id, target_cell, movement_budget).to_dictionary()


static func _attack_data(board: BoardState, target_cell: Vector2i, visibility_state: String, options: Dictionary) -> Dictionary:
	var actor_id: StringName = _actor_id_from_options(options)
	if actor_id == &"":
		return _disabled_preview("attack", actor_id, target_cell, "missing_actor")
	var weapon: WeaponDefinition = _weapon_from_options(options)
	if weapon == null:
		return _disabled_preview("attack", actor_id, target_cell, "missing_weapon")
	if visibility_state == "hidden":
		return _disabled_preview("attack", actor_id, target_cell, "not_visible")
	var preview: Dictionary = TacticalAttackPreview.from_query(board, actor_id, target_cell, weapon).to_dictionary()
	if visibility_state != "visible":
		preview.erase("target_entity_id")
		if preview.get("metadata", {}) is Dictionary:
			(preview.get("metadata", {}) as Dictionary).erase("target_entity_id")
	return preview


static func _disabled_preview(kind: String, actor_id: StringName, target_cell: Vector2i, reason: String) -> Dictionary:
	var cue_prefix: String = "attack_preview" if kind == "attack" else "move_preview"
	return {
		"kind": kind,
		"available": false,
		"reason": reason,
		"actor_id": String(actor_id),
		"target_cell": TacticalPreviewView.cell_metadata(target_cell),
		"target_valid": false,
		"commit_available": false,
		"commit_reason": reason,
		"cue_ids": ["%s_invalid" % cue_prefix, "commit_unavailable"],
		"metadata": {
			"blocked_reason": reason
		}
	}


static func _telegraphs_for_cell(
	context: TacticalActionContext,
	target_cell: Vector2i,
	visibility_state: String,
	options: Dictionary
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if visibility_state == "hidden":
		return result

	var source_value: Variant = TacticalPreviewView.field(options, &"pending_telegraphs", context.pending_telegraphs)
	if not source_value is Array:
		return result
	var pending_telegraphs: Array = source_value
	for telegraph_value: Variant in pending_telegraphs:
		if not telegraph_value is Dictionary:
			continue
		var telegraph: Dictionary = telegraph_value
		if not _marked_cell_matches(telegraph, target_cell):
			continue
		result.append(_copy_telegraph(telegraph))
	return result


static func _copy_telegraph(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: String in [
		"telegraph_id",
		"kind",
		"source_entity_id",
		"target_entity_id",
		"marked_cell",
		"created_turn_number",
		"due_turn_number",
		"damage",
		"damage_type",
		"status"
	]:
		if source.has(key):
			result[key] = TacticalPreviewView.safe_value(source.get(key))
		elif source.has(StringName(key)):
			result[key] = TacticalPreviewView.safe_value(source.get(StringName(key)))
	return result


static func _marked_cell_matches(telegraph: Dictionary, target_cell: Vector2i) -> bool:
	var marked_value: Variant = TacticalPreviewView.field(telegraph, &"marked_cell", {})
	if marked_value is Vector2i:
		return marked_value == target_cell
	if not marked_value is Dictionary:
		return false
	var marked_cell: Dictionary = marked_value
	return (
		int(TacticalPreviewView.field(marked_cell, &"x", -1)) == target_cell.x
		and int(TacticalPreviewView.field(marked_cell, &"y", -1)) == target_cell.y
	)


static func _cue_ids(visibility_state: String, telegraphs: Array[Dictionary], current_turn_number: int) -> Array[String]:
	var result: Array[String] = []
	match visibility_state:
		"visible":
			result.append("inspect_visible")
		"memory":
			result.append("inspect_memory")
		_:
			result.append("inspect_hidden_unexplored")
	for telegraph: Dictionary in telegraphs:
		var due_turn_number: int = int(telegraph.get("due_turn_number", 0))
		if due_turn_number > 0 and current_turn_number >= due_turn_number:
			if not result.has("telegraph_due"):
				result.append("telegraph_due")
		elif not result.has("telegraph_pending"):
			result.append("telegraph_pending")
		if int(telegraph.get("damage", 0)) > 0 and not result.has("danger_damage"):
			result.append("danger_damage")
	return result


static func _current_turn_number(context: TacticalActionContext) -> int:
	if context == null or context.turn_state == null:
		return 0
	return context.turn_state.turn_number


static func _reason_for_visibility_state(visibility_state: String) -> String:
	match visibility_state:
		"visible":
			return "visible"
		"memory":
			return "memory"
		_:
			return "hidden_unexplored"


static func _actor_id_from_options(options: Dictionary) -> StringName:
	var actor_value: Variant = TacticalPreviewView.field(options, &"actor_id", &"")
	return StringName(String(actor_value))


static func _movement_budget_from_options(options: Dictionary) -> int:
	var budget_value: Variant = TacticalPreviewView.field(options, &"movement_budget", 3)
	if not _is_integral_number(budget_value):
		return 3
	return int(budget_value)


static func _weapon_from_options(options: Dictionary) -> WeaponDefinition:
	var weapon_value: Variant = TacticalPreviewView.field(options, &"weapon", null)
	if weapon_value is WeaponDefinition:
		return weapon_value
	return null


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false
