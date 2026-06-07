class_name TacticalEntityState
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")

enum EntityType {
	UNKNOWN,
	PLAYER,
	ENEMY
}

const ENTITY_TYPE_UNKNOWN := &"unknown"
const ENTITY_TYPE_PLAYER := &"player"
const ENTITY_TYPE_ENEMY := &"enemy"

var entity_id: StringName = &""
var entity_type: int = EntityType.UNKNOWN
var faction: StringName = &""
var position: Vector2i = Vector2i.ZERO
var current_hp: int = 0
var max_hp: int = 0
var blocks_movement: bool = true
var definition_id: StringName = &""

func _init(
	new_entity_id: StringName = &"",
	new_entity_type: int = EntityType.UNKNOWN,
	new_faction: StringName = &"",
	new_position: Vector2i = Vector2i.ZERO,
	new_current_hp: int = 0,
	new_max_hp: int = 0,
	new_blocks_movement: bool = true,
	new_definition_id: StringName = &""
) -> void:
	entity_id = new_entity_id
	entity_type = new_entity_type
	faction = new_faction
	position = new_position
	current_hp = new_current_hp
	max_hp = new_max_hp
	blocks_movement = new_blocks_movement
	definition_id = new_definition_id


func is_alive() -> bool:
	return current_hp > 0


func is_dead() -> bool:
	return not is_alive()


func validate() -> ActionResult:
	if entity_id == &"":
		return _invalid_entity_data(&"entity_id")
	if not _is_supported_entity_type(entity_type):
		return _invalid_entity_data(&"entity_type")
	if faction == &"":
		return _invalid_entity_data(&"faction")
	if max_hp <= 0:
		return _invalid_entity_data(&"max_hp")
	if current_hp < 0 or current_hp > max_hp:
		return _invalid_entity_data(&"current_hp")
	if definition_id != &"" and not _is_lower_snake_id(definition_id):
		return _invalid_entity_data(&"definition_id")
	return ActionResult.ok()


func to_dictionary() -> Dictionary:
	return {
		"entity_id": String(entity_id),
		"entity_type": String(id_for_entity_type(entity_type)),
		"faction": String(faction),
		"position": {
			"x": position.x,
			"y": position.y
		},
		"current_hp": current_hp,
		"max_hp": max_hp,
		"blocks_movement": blocks_movement,
		"definition_id": String(definition_id)
	}


func copy() -> TacticalEntityState:
	return load("res://scripts/tactical/entities/tactical_entity_state.gd").new(
		entity_id,
		entity_type,
		faction,
		position,
		current_hp,
		max_hp,
		blocks_movement,
		definition_id
	)


static func try_from_dictionary(data: Dictionary) -> ActionResult:
	if not _has_string_like_field(data, &"entity_id"):
		return _invalid_entity_data(&"entity_id")
	if not _has_field(data, &"entity_type"):
		return _invalid_entity_data(&"entity_type")
	if not _has_string_like_field(data, &"faction"):
		return _invalid_entity_data(&"faction")
	if not _has_integral_field(data, &"current_hp"):
		return _invalid_entity_data(&"current_hp")
	if not _has_integral_field(data, &"max_hp"):
		return _invalid_entity_data(&"max_hp")
	if not _has_bool_field(data, &"blocks_movement"):
		return _invalid_entity_data(&"blocks_movement")
	if _has_field(data, &"definition_id") and not _has_string_like_field(data, &"definition_id"):
		return _invalid_entity_data(&"definition_id")

	var position_value: Variant = _field(data, &"position")
	if not position_value is Dictionary:
		return _invalid_entity_data(&"position")

	var position_data: Dictionary = position_value
	if not _has_integral_field(position_data, &"x") or not _has_integral_field(position_data, &"y"):
		return _invalid_entity_data(&"position")

	var parsed_entity_type: int = _entity_type_from_variant(_field(data, &"entity_type"))
	if not _is_supported_entity_type(parsed_entity_type):
		return _invalid_entity_data(&"entity_type")

	var entity: TacticalEntityState = load("res://scripts/tactical/entities/tactical_entity_state.gd").new(
		StringName(str(_field(data, &"entity_id"))),
		parsed_entity_type,
		StringName(str(_field(data, &"faction"))),
		Vector2i(
			int(_field(position_data, &"x")),
			int(_field(position_data, &"y"))
		),
		int(_field(data, &"current_hp")),
		int(_field(data, &"max_hp")),
		bool(_field(data, &"blocks_movement")),
		StringName(str(_field(data, &"definition_id"))) if _has_field(data, &"definition_id") else &""
	)

	var validation: ActionResult = entity.validate()
	if validation.is_error():
		return validation
	return ActionResult.ok([], {"entity": entity})


static func from_dictionary(data: Dictionary) -> TacticalEntityState:
	var result: ActionResult = try_from_dictionary(data)
	if result.is_error():
		push_error("TacticalEntityState snapshot parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("entity") as TacticalEntityState


static func id_for_entity_type(type_value: int) -> StringName:
	match type_value:
		EntityType.PLAYER:
			return ENTITY_TYPE_PLAYER
		EntityType.ENEMY:
			return ENTITY_TYPE_ENEMY
		_:
			return ENTITY_TYPE_UNKNOWN


static func entity_type_for_id(type_id: StringName) -> int:
	match type_id:
		ENTITY_TYPE_PLAYER:
			return EntityType.PLAYER
		ENTITY_TYPE_ENEMY:
			return EntityType.ENEMY
		_:
			return EntityType.UNKNOWN


static func _entity_type_from_variant(type_value: Variant) -> int:
	if _is_integral_number(type_value):
		return int(type_value)
	if not _is_string_like(type_value):
		return EntityType.UNKNOWN
	return entity_type_for_id(StringName(str(type_value)))


static func _is_supported_entity_type(type_value: int) -> bool:
	return type_value == EntityType.PLAYER or type_value == EntityType.ENEMY


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


static func _has_string_like_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _is_string_like(_field(data, field_name))


static func _has_integral_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and _is_integral_number(_field(data, field_name))


static func _has_bool_field(data: Dictionary, field_name: StringName) -> bool:
	return _has_field(data, field_name) and typeof(_field(data, field_name)) == TYPE_BOOL


static func _is_string_like(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false


static func _is_lower_snake_id(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty():
		return false
	if text != text.to_lower():
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false
	return true


static func _invalid_entity_data(field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_entity_data", {
		"field": String(field_name)
	})
