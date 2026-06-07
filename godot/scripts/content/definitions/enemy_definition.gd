class_name EnemyDefinition
extends Resource

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"enemy"
const BEHAVIOR_MELEE_PRESSURE := &"melee_pressure"
const BEHAVIOR_SEER_MARK := &"seer_mark"
const DAMAGE_TYPE_PHYSICAL := &"physical"

@export var enemy_id: StringName = &""
@export var max_hp: int = 0
@export var behavior_id: StringName = &""
@export var blocks_movement: bool = true
@export var move_budget: int = 0
@export var melee_range: int = 0
@export var melee_damage: int = 0
@export var melee_damage_type: StringName = DAMAGE_TYPE_PHYSICAL
@export var mark_range: int = 0
@export var requires_line_of_sight: bool = false
@export var detonation_damage: int = 0
@export var detonation_damage_type: StringName = DAMAGE_TYPE_PHYSICAL
@export var tactical_identity: String = ""

func _init(
	new_enemy_id: StringName = &"",
	new_max_hp: int = 0,
	new_behavior_id: StringName = &"",
	new_blocks_movement: bool = true,
	new_move_budget: int = 0,
	new_melee_range: int = 0,
	new_melee_damage: int = 0,
	new_melee_damage_type: StringName = DAMAGE_TYPE_PHYSICAL,
	new_mark_range: int = 0,
	new_requires_line_of_sight: bool = false,
	new_detonation_damage: int = 0,
	new_detonation_damage_type: StringName = DAMAGE_TYPE_PHYSICAL,
	new_tactical_identity: String = ""
) -> void:
	enemy_id = new_enemy_id
	max_hp = new_max_hp
	behavior_id = new_behavior_id
	blocks_movement = new_blocks_movement
	move_budget = new_move_budget
	melee_range = new_melee_range
	melee_damage = new_melee_damage
	melee_damage_type = new_melee_damage_type
	mark_range = new_mark_range
	requires_line_of_sight = new_requires_line_of_sight
	detonation_damage = new_detonation_damage
	detonation_damage_type = new_detonation_damage_type
	tactical_identity = new_tactical_identity


func validate() -> ActionResult:
	if not _is_lower_snake_id(enemy_id):
		return _invalid(&"enemy_id")
	if max_hp <= 0:
		return _invalid(&"max_hp")
	if not _is_valid_behavior(behavior_id):
		return _invalid(&"behavior_id")
	if tactical_identity.strip_edges().is_empty():
		return _invalid(&"tactical_identity")

	match behavior_id:
		BEHAVIOR_MELEE_PRESSURE:
			if move_budget <= 0:
				return _invalid(&"move_budget")
			if melee_range <= 0:
				return _invalid(&"melee_range")
			if melee_damage <= 0:
				return _invalid(&"melee_damage")
			if not _is_lower_snake_id(melee_damage_type):
				return _invalid(&"melee_damage_type")
			if mark_range != 0 or detonation_damage != 0:
				return _invalid(&"mark_fields")
		BEHAVIOR_SEER_MARK:
			if move_budget != 0 or melee_range != 0 or melee_damage != 0:
				return _invalid(&"melee_fields")
			if mark_range <= 0:
				return _invalid(&"mark_range")
			if not requires_line_of_sight:
				return _invalid(&"requires_line_of_sight")
			if detonation_damage <= 0:
				return _invalid(&"detonation_damage")
			if not _is_lower_snake_id(detonation_damage_type):
				return _invalid(&"detonation_damage_type")
	return ActionResult.ok()


func melee_source_id() -> StringName:
	return StringName("%s_melee" % String(enemy_id))


static func _is_valid_behavior(value: StringName) -> bool:
	return value == BEHAVIOR_MELEE_PRESSURE or value == BEHAVIOR_SEER_MARK


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
	return ActionResult.error(&"invalid_enemy_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
