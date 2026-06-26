class_name JewelryDefinition
extends Resource

# A typed, validated JEWELRY loot definition (Story 6.1) — an EQUIPPABLE accessory (ring / amulet). Mirrors
# ArmorDefinition / WeaponDefinition in shape and carries the SAME equip-gate + roll-model contract as every
# equippable category. It is content the inventory (Story 6.2) holds and a reward offer (Story 6.3) grants;
# 6.1 only DEFINES it.
#
# EQUIP GATE (AC4 / GDD FR75/FR76): identical to ArmorDefinition — a `character_level_requirement` (non-negative
# int, LEVEL_REQUIREMENT_NONE (0) = no gate), NO min_run_depth/min_node_depth field (run-depth is forbidden as
# the equip gate; omitting the field enforces it).
#
# ROLL MODEL (AC5): an embedded ItemRollModel (roll range live; affixes/enhancements/affinities shape-only-
# deferred). NO item_level field.
#
# SLOT: a small allowlist (ring / amulet) so a jewelry item declares which accessory slot it occupies — data
# identity only this story (the equipment-slot model is Story 6.2).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ItemRollModel = preload("res://scripts/content/definitions/item_roll_model.gd")

const DEFINITION_TYPE := &"jewelry"

const LEVEL_REQUIREMENT_NONE: int = 0

const SLOT_RING := &"ring"
const SLOT_AMULET := &"amulet"

const JEWELRY_SLOTS: Array[StringName] = [
	SLOT_RING,
	SLOT_AMULET
]

@export var jewelry_id: StringName = &""
@export var jewelry_slot: StringName = &""
@export var bonus_value: int = 0
@export var character_level_requirement: int = LEVEL_REQUIREMENT_NONE
@export var roll_model: ItemRollModel = null
@export var tactical_identity: String = ""

func _init(
	new_jewelry_id: StringName = &"",
	new_jewelry_slot: StringName = &"",
	new_bonus_value: int = 0,
	new_character_level_requirement: int = LEVEL_REQUIREMENT_NONE,
	new_roll_model: ItemRollModel = null,
	new_tactical_identity: String = ""
) -> void:
	jewelry_id = new_jewelry_id
	jewelry_slot = new_jewelry_slot
	bonus_value = new_bonus_value
	character_level_requirement = new_character_level_requirement
	roll_model = new_roll_model
	tactical_identity = new_tactical_identity


func validate() -> ActionResult:
	if not _is_lower_snake_id(jewelry_id):
		return _invalid(&"jewelry_id")
	if not JEWELRY_SLOTS.has(jewelry_slot):
		return _invalid(&"jewelry_slot")
	if bonus_value < 0:
		return _invalid(&"bonus_value")
	if character_level_requirement < 0:
		return _invalid(&"character_level_requirement")
	if roll_model == null:
		return _invalid(&"roll_model")
	var roll_validation: ActionResult = roll_model.validate()
	if roll_validation.is_error():
		return _invalid(&"roll_model")
	if tactical_identity.strip_edges().is_empty():
		return _invalid(&"tactical_identity")
	return ActionResult.ok()


func requires_character_level() -> bool:
	return character_level_requirement > LEVEL_REQUIREMENT_NONE


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
	return ActionResult.error(&"invalid_jewelry_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
