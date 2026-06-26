extends "res://tests/unit/test_case.gd"

# Story 6.1 AC2/AC4/AC5 — JewelryDefinition (an EQUIPPABLE accessory). Pins: a valid definition validates; every
# validate() branch has a dedicated negative; the slot is allowlist-validated; the equip gate is a character-
# level requirement OR LEVEL_REQUIREMENT_NONE (0), a negative requirement is rejected, and there is NO run-depth
# gate; the roll model is embedded + validated.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const JewelryDefinition = preload("res://scripts/content/definitions/jewelry_definition.gd")
const ItemRollModel = preload("res://scripts/content/definitions/item_roll_model.gd")

func run() -> Dictionary:
	_valid_jewelry_validates()
	_level_requirement_none_sentinel_resolves()
	_jewelry_id_must_be_lower_snake()
	_slot_must_be_in_allowlist()
	_negative_bonus_value_rejected()
	_negative_level_requirement_rejected()
	_null_roll_model_rejected()
	_invalid_roll_model_rejected()
	_empty_tactical_identity_rejected()
	_no_run_depth_gate_field_exists()
	return result()


func _valid_jewelry() -> JewelryDefinition:
	return JewelryDefinition.new(&"jasper_amulet", JewelryDefinition.SLOT_AMULET, 2, 2, ItemRollModel.new(1, 2), "A jasper amulet.")


func _valid_jewelry_validates() -> void:
	assert_true(_valid_jewelry().validate().succeeded, "A well-formed jewelry definition should validate.")
	# Both slots are accepted.
	assert_true(JewelryDefinition.new(&"copper_band", JewelryDefinition.SLOT_RING, 1, 0, ItemRollModel.new(0, 1), "A ring.").validate().succeeded, "A ring-slot jewelry should validate.")


func _level_requirement_none_sentinel_resolves() -> void:
	var no_gate: JewelryDefinition = JewelryDefinition.new(
		&"copper_band", JewelryDefinition.SLOT_RING, 1, JewelryDefinition.LEVEL_REQUIREMENT_NONE, ItemRollModel.new(0, 1), "Plain ring."
	)
	assert_true(no_gate.validate().succeeded, "A jewelry with the LEVEL_REQUIREMENT_NONE sentinel must validate (no gate).")
	assert_false(no_gate.requires_character_level(), "LEVEL_REQUIREMENT_NONE means no character-level gate.")


func _jewelry_id_must_be_lower_snake() -> void:
	var bad: JewelryDefinition = JewelryDefinition.new(&"JasperAmulet", JewelryDefinition.SLOT_AMULET, 2, 2, ItemRollModel.new(1, 2), "Bad id.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake jewelry id must be rejected.")
	assert_equal(validation.error_code, &"invalid_jewelry_definition", "Use the stable jewelry-definition error code.")
	assert_equal(String(validation.metadata.get("field")), "jewelry_id", "The error should name jewelry_id.")


func _slot_must_be_in_allowlist() -> void:
	var bad: JewelryDefinition = JewelryDefinition.new(&"jasper_amulet", &"crown", 2, 2, ItemRollModel.new(1, 2), "Bad slot.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An out-of-allowlist jewelry slot must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "jewelry_slot", "The error should name jewelry_slot.")
	assert_true(JewelryDefinition.new(&"jasper_amulet", &"", 2, 2, ItemRollModel.new(1, 2), "Empty slot.").validate().is_error(), "An empty slot must be rejected.")


func _negative_bonus_value_rejected() -> void:
	var bad: JewelryDefinition = JewelryDefinition.new(&"jasper_amulet", JewelryDefinition.SLOT_AMULET, -1, 2, ItemRollModel.new(1, 2), "Negative bonus.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A negative bonus_value must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "bonus_value", "The error should name bonus_value.")


func _negative_level_requirement_rejected() -> void:
	var bad: JewelryDefinition = JewelryDefinition.new(&"jasper_amulet", JewelryDefinition.SLOT_AMULET, 2, -1, ItemRollModel.new(1, 2), "Negative gate.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A negative character_level_requirement must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "character_level_requirement", "The error should name character_level_requirement.")


func _null_roll_model_rejected() -> void:
	var bad: JewelryDefinition = JewelryDefinition.new(&"jasper_amulet", JewelryDefinition.SLOT_AMULET, 2, 2, null, "No roll model.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A null roll model must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "roll_model", "The error should name roll_model.")


func _invalid_roll_model_rejected() -> void:
	var bad: JewelryDefinition = JewelryDefinition.new(&"jasper_amulet", JewelryDefinition.SLOT_AMULET, 2, 2, ItemRollModel.new(5, 2), "Bad roll band.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A jewelry with an invalid embedded roll model must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "roll_model", "An invalid embedded roll model should name roll_model.")


func _empty_tactical_identity_rejected() -> void:
	var bad: JewelryDefinition = JewelryDefinition.new(&"jasper_amulet", JewelryDefinition.SLOT_AMULET, 2, 2, ItemRollModel.new(1, 2), "")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An empty tactical identity must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "tactical_identity", "The error should name tactical_identity.")


func _no_run_depth_gate_field_exists() -> void:
	var definition: JewelryDefinition = _valid_jewelry()
	var property_names: Array[String] = []
	for property_info: Dictionary in definition.get_property_list():
		property_names.append(String(property_info.get("name")))
	assert_false(property_names.has("min_run_depth"), "Jewelry must NOT carry a min_run_depth gate (AC4).")
	assert_false(property_names.has("min_node_depth"), "Jewelry must NOT carry a min_node_depth gate (AC4).")
