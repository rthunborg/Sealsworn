class_name ArmorDefinition
extends Resource

# A typed, validated ARMOR loot definition (Story 6.1) — an EQUIPPABLE body-slot item. Mirrors
# WeaponDefinition / SupportDefinition in shape (DEFINITION_TYPE const, @export typed fields, _init in
# field-declaration order, validate() -> ActionResult returning invalid_armor_definition on the FIRST bad
# field, the shared lower_snake helpers). It is content the inventory (Story 6.2) will hold and a reward offer
# (Story 6.3) can grant; 6.1 only DEFINES it + registers it through the repository boundary.
#
# EQUIP GATE (AC4 / GDD FR75/FR76): armor declares a `character_level_requirement` — a small non-negative int,
# with LEVEL_REQUIREMENT_NONE (0) as the resolving "no level gate" sentinel (a REAL value, never "missing",
# the SupportDefinition.SUPPORT_NONE idiom). validate() REJECTS a negative requirement. There is DELIBERATELY
# NO min_run_depth / min_node_depth field — AC4 forbids run-depth as the equip gate (character level is the
# ONLY equip gate). Omitting the field is the enforcement: a run-depth gate cannot be expressed, so it cannot
# be used.
#
# ROLL MODEL (AC5): instance variation rides on an embedded ItemRollModel (a roll range live; affix/
# enhancement ids + affinity tags shape-only-deferred with per-family markers). There is NO item_level field.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ItemRollModel = preload("res://scripts/content/definitions/item_roll_model.gd")

const DEFINITION_TYPE := &"armor"

# The resolving "no level gate" sentinel for the equip requirement (AC4). 0 means "equippable at any character
# level" — a REAL value, NEVER treated as missing.
const LEVEL_REQUIREMENT_NONE: int = 0

@export var armor_id: StringName = &""
@export var armor_value: int = 0
@export var character_level_requirement: int = LEVEL_REQUIREMENT_NONE
@export var roll_model: ItemRollModel = null
@export var tactical_identity: String = ""

func _init(
	new_armor_id: StringName = &"",
	new_armor_value: int = 0,
	new_character_level_requirement: int = LEVEL_REQUIREMENT_NONE,
	new_roll_model: ItemRollModel = null,
	new_tactical_identity: String = ""
) -> void:
	armor_id = new_armor_id
	armor_value = new_armor_value
	character_level_requirement = new_character_level_requirement
	roll_model = new_roll_model
	tactical_identity = new_tactical_identity


func validate() -> ActionResult:
	if not _is_lower_snake_id(armor_id):
		return _invalid(&"armor_id")
	if armor_value < 0:
		return _invalid(&"armor_value")
	# AC4: character-level requirement is a small non-negative int (0 == LEVEL_REQUIREMENT_NONE, "no gate").
	# A negative requirement is rejected. Run-depth cannot be a gate here — there is no run-depth field.
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
	return ActionResult.error(&"invalid_armor_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
