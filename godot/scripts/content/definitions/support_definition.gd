class_name SupportDefinition
extends Resource

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"support"

const SUPPORT_NONE := &"none"
const SUPPORT_TOME := &"tome"
const SUPPORT_SHIELD := &"shield"

@export var support_id: StringName = &""
@export var armor: int = 0
@export var block_chance: float = 0.0
@export var bonus_damage: int = 0
@export var bonus_weapon_ids: Array[StringName] = []
@export var tactical_identity: String = ""

func _init(
	new_support_id: StringName = &"",
	new_armor: int = 0,
	new_block_chance: float = 0.0,
	new_bonus_damage: int = 0,
	new_bonus_weapon_ids: Array = [],
	new_tactical_identity: String = ""
) -> void:
	support_id = new_support_id
	armor = new_armor
	block_chance = new_block_chance
	bonus_damage = new_bonus_damage
	bonus_weapon_ids = _copy_ids(new_bonus_weapon_ids)
	tactical_identity = new_tactical_identity


func validate() -> ActionResult:
	if not _is_lower_snake_id(support_id):
		return _invalid(&"support_id")
	if armor < 0:
		return _invalid(&"armor")
	if block_chance < 0.0 or block_chance > 1.0:
		return _invalid(&"block_chance")
	if bonus_damage < 0:
		return _invalid(&"bonus_damage")
	if tactical_identity.strip_edges().is_empty():
		return _invalid(&"tactical_identity")
	for weapon_id: StringName in bonus_weapon_ids:
		if not _is_lower_snake_id(weapon_id):
			return _invalid(&"bonus_weapon_ids")
	if bonus_damage == 0 and not bonus_weapon_ids.is_empty():
		return _invalid(&"bonus_weapon_ids")
	if bonus_damage > 0 and bonus_weapon_ids.is_empty():
		return _invalid(&"bonus_weapon_ids")
	return ActionResult.ok()


func supports_bonus_for_weapon(weapon_id: StringName) -> bool:
	return bonus_damage > 0 and bonus_weapon_ids.has(weapon_id)


static func _copy_ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(str(value)))
	return result


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


static func _invalid(field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_support_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
