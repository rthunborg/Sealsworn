class_name WeaponDefinition
extends Resource

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"weapon"

const TARGETING_ADJACENT_CARDINAL := &"adjacent_cardinal"
const TARGETING_STRAIGHT_LINE := &"straight_line"

const VISIBILITY_VISIBLE_TARGET := &"visible_target"

const BLOCKER_STANDARD := &"standard"
const BLOCKER_IGNORE_TERRAIN_AND_ENTITIES := &"ignore_terrain_and_entities"

const ADJACENCY_NONE := &""
const ADJACENCY_RANGED_70 := &"adjacent_ranged_70"
const ADJACENCY_HALF := &"adjacent_half"

const WARNING_ADJACENT_RANGED_PENALTY := &"adjacent_ranged_penalty"

@export var weapon_id: StringName = &""
@export var attack_range: int = 0
@export var base_damage: int = 0
@export var targeting_shape: StringName = &""
@export var tactical_identity: String = ""
@export var visibility_requirement: StringName = VISIBILITY_VISIBLE_TARGET
@export var blocker_behavior: StringName = BLOCKER_STANDARD
@export var adjacency_modifier_id: StringName = ADJACENCY_NONE
@export var adjacency_damage_multiplier: float = 1.0
@export var adjacency_warning_id: StringName = &""
@export var preview_effect_ids: Array[StringName] = []
@export var blocker_override_explanation: String = ""

func _init(
	new_weapon_id: StringName = &"",
	new_attack_range: int = 0,
	new_base_damage: int = 0,
	new_targeting_shape: StringName = &"",
	new_tactical_identity: String = "",
	new_visibility_requirement: StringName = VISIBILITY_VISIBLE_TARGET,
	new_blocker_behavior: StringName = BLOCKER_STANDARD,
	new_adjacency_modifier_id: StringName = ADJACENCY_NONE,
	new_adjacency_damage_multiplier: float = 1.0,
	new_adjacency_warning_id: StringName = &"",
	new_preview_effect_ids: Array = [],
	new_blocker_override_explanation: String = ""
) -> void:
	weapon_id = new_weapon_id
	attack_range = new_attack_range
	base_damage = new_base_damage
	targeting_shape = new_targeting_shape
	tactical_identity = new_tactical_identity
	visibility_requirement = new_visibility_requirement
	blocker_behavior = new_blocker_behavior
	adjacency_modifier_id = new_adjacency_modifier_id
	adjacency_damage_multiplier = new_adjacency_damage_multiplier
	adjacency_warning_id = new_adjacency_warning_id
	preview_effect_ids = _copy_effect_ids(new_preview_effect_ids)
	blocker_override_explanation = new_blocker_override_explanation


func validate() -> ActionResult:
	if not _is_lower_snake_id(weapon_id):
		return _invalid(&"weapon_id")
	if attack_range <= 0:
		return _invalid(&"attack_range")
	if base_damage <= 0:
		return _invalid(&"base_damage")
	if not _is_valid_targeting_shape(targeting_shape):
		return _invalid(&"targeting_shape")
	if tactical_identity.strip_edges().is_empty():
		return _invalid(&"tactical_identity")
	if visibility_requirement != VISIBILITY_VISIBLE_TARGET:
		return _invalid(&"visibility_requirement")
	if not _is_valid_blocker_behavior(blocker_behavior):
		return _invalid(&"blocker_behavior")
	if not _is_valid_adjacency_modifier(adjacency_modifier_id):
		return _invalid(&"adjacency_modifier_id")
	if adjacency_damage_multiplier <= 0.0:
		return _invalid(&"adjacency_damage_multiplier")
	if adjacency_modifier_id == ADJACENCY_NONE and not is_equal_approx(adjacency_damage_multiplier, 1.0):
		return _invalid(&"adjacency_damage_multiplier")
	if adjacency_modifier_id == ADJACENCY_RANGED_70 and not is_equal_approx(adjacency_damage_multiplier, 0.7):
		return _invalid(&"adjacency_damage_multiplier")
	if adjacency_modifier_id == ADJACENCY_HALF and not is_equal_approx(adjacency_damage_multiplier, 0.5):
		return _invalid(&"adjacency_damage_multiplier")
	if adjacency_modifier_id != ADJACENCY_NONE and adjacency_warning_id == &"":
		return _invalid(&"adjacency_warning_id")
	if adjacency_warning_id != &"" and not _is_lower_snake_id(adjacency_warning_id):
		return _invalid(&"adjacency_warning_id")
	for effect_id: StringName in preview_effect_ids:
		if not _is_lower_snake_id(effect_id):
			return _invalid(&"preview_effect_ids")
	if blocker_behavior == BLOCKER_IGNORE_TERRAIN_AND_ENTITIES and blocker_override_explanation.strip_edges().is_empty():
		return _invalid(&"blocker_override_explanation")
	if blocker_behavior != BLOCKER_IGNORE_TERRAIN_AND_ENTITIES and not blocker_override_explanation.strip_edges().is_empty():
		return _invalid(&"blocker_override_explanation")
	return ActionResult.ok()


func ignores_blockers() -> bool:
	return blocker_behavior == BLOCKER_IGNORE_TERRAIN_AND_ENTITIES


func has_adjacency_modifier() -> bool:
	return adjacency_modifier_id != ADJACENCY_NONE


static func _copy_effect_ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(str(value)))
	return result


static func _is_valid_targeting_shape(value: StringName) -> bool:
	return value == TARGETING_ADJACENT_CARDINAL or value == TARGETING_STRAIGHT_LINE


static func _is_valid_blocker_behavior(value: StringName) -> bool:
	return value == BLOCKER_STANDARD or value == BLOCKER_IGNORE_TERRAIN_AND_ENTITIES


static func _is_valid_adjacency_modifier(value: StringName) -> bool:
	return value == ADJACENCY_NONE or value == ADJACENCY_RANGED_70 or value == ADJACENCY_HALF


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
	return ActionResult.error(&"invalid_weapon_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
