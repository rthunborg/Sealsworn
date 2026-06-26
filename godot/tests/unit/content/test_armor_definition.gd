extends "res://tests/unit/test_case.gd"

# Story 6.1 AC2/AC4/AC5 — ArmorDefinition (an EQUIPPABLE loot definition). Pins: a valid definition validates;
# every validate() branch has a dedicated negative (REJECT, never coerce); the equip gate is a character-level
# requirement OR the LEVEL_REQUIREMENT_NONE (0) sentinel (a real resolving "no gate" value), a negative
# requirement is rejected, and there is NO run-depth gate field (AC4 forbids it); the roll model is embedded +
# validated; there is no item_level field.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ArmorDefinition = preload("res://scripts/content/definitions/armor_definition.gd")
const ItemRollModel = preload("res://scripts/content/definitions/item_roll_model.gd")

func run() -> Dictionary:
	_valid_armor_validates()
	_level_requirement_none_sentinel_resolves()
	_armor_id_must_be_lower_snake()
	_negative_armor_value_rejected()
	_negative_level_requirement_rejected()
	_null_roll_model_rejected()
	_invalid_roll_model_rejected()
	_empty_tactical_identity_rejected()
	_no_run_depth_gate_field_exists()
	_requires_character_level_reflects_gate()
	return result()


func _valid_armor() -> ArmorDefinition:
	return ArmorDefinition.new(&"chain_hauberk", 2, 2, ItemRollModel.new(1, 3), "Interlocked rings.")


func _valid_armor_validates() -> void:
	assert_true(_valid_armor().validate().succeeded, "A well-formed armor definition should validate.")


func _level_requirement_none_sentinel_resolves() -> void:
	# LEVEL_REQUIREMENT_NONE (0) is a REAL resolving "no level gate" value, never "missing" — it must validate.
	var no_gate: ArmorDefinition = ArmorDefinition.new(
		&"padded_vest", 1, ArmorDefinition.LEVEL_REQUIREMENT_NONE, ItemRollModel.new(0, 1), "Light padding."
	)
	assert_true(no_gate.validate().succeeded, "An armor with the LEVEL_REQUIREMENT_NONE sentinel must validate (no gate).")
	assert_false(no_gate.requires_character_level(), "LEVEL_REQUIREMENT_NONE means no character-level gate.")
	assert_equal(ArmorDefinition.LEVEL_REQUIREMENT_NONE, 0, "The no-gate sentinel is 0 (a real resolving value).")


func _armor_id_must_be_lower_snake() -> void:
	var bad: ArmorDefinition = ArmorDefinition.new(&"ChainHauberk", 2, 2, ItemRollModel.new(1, 3), "Bad id.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake armor id must be rejected.")
	assert_equal(validation.error_code, &"invalid_armor_definition", "Use the stable armor-definition error code.")
	assert_equal(String(validation.metadata.get("field")), "armor_id", "The error should name armor_id.")
	assert_true(ArmorDefinition.new(&"", 2, 2, ItemRollModel.new(1, 3), "Empty id.").validate().is_error(), "An empty armor id must be rejected.")


func _negative_armor_value_rejected() -> void:
	var bad: ArmorDefinition = ArmorDefinition.new(&"chain_hauberk", -1, 2, ItemRollModel.new(1, 3), "Negative armor.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A negative armor_value must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "armor_value", "The error should name armor_value.")


func _negative_level_requirement_rejected() -> void:
	var bad: ArmorDefinition = ArmorDefinition.new(&"chain_hauberk", 2, -1, ItemRollModel.new(1, 3), "Negative gate.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A negative character_level_requirement must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "character_level_requirement", "The error should name character_level_requirement.")


func _null_roll_model_rejected() -> void:
	var bad: ArmorDefinition = ArmorDefinition.new(&"chain_hauberk", 2, 2, null, "No roll model.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A null roll model must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "roll_model", "The error should name roll_model.")


func _invalid_roll_model_rejected() -> void:
	# An embedded roll model that itself fails validation rolls up to a roll_model field rejection.
	var bad: ArmorDefinition = ArmorDefinition.new(&"chain_hauberk", 2, 2, ItemRollModel.new(5, 2), "Bad roll band.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An armor with an invalid embedded roll model must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "roll_model", "An invalid embedded roll model should name roll_model.")


func _empty_tactical_identity_rejected() -> void:
	var bad: ArmorDefinition = ArmorDefinition.new(&"chain_hauberk", 2, 2, ItemRollModel.new(1, 3), "   ")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An empty tactical identity must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "tactical_identity", "The error should name tactical_identity.")


func _no_run_depth_gate_field_exists() -> void:
	# AC4: run-depth must NOT be expressible as the equip gate. Assert the definition carries no run-depth field.
	var definition: ArmorDefinition = _valid_armor()
	var property_names: Array[String] = []
	for property_info: Dictionary in definition.get_property_list():
		property_names.append(String(property_info.get("name")))
	assert_false(property_names.has("min_run_depth"), "Armor must NOT carry a min_run_depth gate (AC4).")
	assert_false(property_names.has("min_node_depth"), "Armor must NOT carry a min_node_depth gate (AC4).")


func _requires_character_level_reflects_gate() -> void:
	assert_true(ArmorDefinition.new(&"warded_plate", 4, 4, ItemRollModel.new(2, 5), "Veteran plate.").requires_character_level(), "A positive requirement means a character-level gate.")
	assert_false(_valid_armor_with_no_gate().requires_character_level(), "A 0 requirement means no gate.")


func _valid_armor_with_no_gate() -> ArmorDefinition:
	return ArmorDefinition.new(&"padded_vest", 1, ArmorDefinition.LEVEL_REQUIREMENT_NONE, ItemRollModel.new(0, 1), "Light padding.")
