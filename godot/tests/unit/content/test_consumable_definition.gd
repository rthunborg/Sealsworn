extends "res://tests/unit/test_case.gd"

# Story 6.1 AC2 / FR53 — ConsumableDefinition. Pins: a valid definition validates; every validate() branch has a
# dedicated negative; rarity is allowlist-validated (the scarcity-as-data tier); value is a positive worth-using
# measure; consumables carry NO equip gate (not equipped).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ConsumableDefinition = preload("res://scripts/content/definitions/consumable_definition.gd")

func run() -> Dictionary:
	_valid_consumable_validates()
	_consumable_id_must_be_lower_snake()
	_rarity_must_be_in_allowlist()
	_non_positive_value_rejected()
	_empty_tactical_identity_rejected()
	_no_equip_gate_field_exists()
	_is_valid_rarity_helper()
	return result()


func _valid_consumable() -> ConsumableDefinition:
	return ConsumableDefinition.new(&"warding_salve", ConsumableDefinition.RARITY_UNCOMMON, 25, "A semi-rare salve.")


func _valid_consumable_validates() -> void:
	assert_true(_valid_consumable().validate().succeeded, "A well-formed consumable definition should validate.")
	for rarity: StringName in [ConsumableDefinition.RARITY_COMMON, ConsumableDefinition.RARITY_UNCOMMON, ConsumableDefinition.RARITY_RARE]:
		assert_true(ConsumableDefinition.new(&"draught", rarity, 5, "A draught.").validate().succeeded, "Rarity %s should validate." % String(rarity))


func _consumable_id_must_be_lower_snake() -> void:
	var bad: ConsumableDefinition = ConsumableDefinition.new(&"WardingSalve", ConsumableDefinition.RARITY_UNCOMMON, 25, "Bad id.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake consumable id must be rejected.")
	assert_equal(validation.error_code, &"invalid_consumable_definition", "Use the stable consumable-definition error code.")
	assert_equal(String(validation.metadata.get("field")), "consumable_id", "The error should name consumable_id.")


func _rarity_must_be_in_allowlist() -> void:
	var bad: ConsumableDefinition = ConsumableDefinition.new(&"warding_salve", &"legendary", 25, "Bad rarity.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An out-of-allowlist rarity must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "rarity", "The error should name rarity.")
	assert_true(ConsumableDefinition.new(&"warding_salve", &"", 25, "Empty rarity.").validate().is_error(), "An empty rarity must be rejected.")


func _non_positive_value_rejected() -> void:
	var zero: ConsumableDefinition = ConsumableDefinition.new(&"warding_salve", ConsumableDefinition.RARITY_UNCOMMON, 0, "Zero value.")
	var validation: ActionResult = zero.validate()
	assert_true(validation.is_error(), "A zero value must be rejected (a worthless consumable).")
	assert_equal(String(validation.metadata.get("field")), "value", "The error should name value.")
	assert_true(ConsumableDefinition.new(&"warding_salve", ConsumableDefinition.RARITY_UNCOMMON, -5, "Negative value.").validate().is_error(), "A negative value must be rejected.")


func _empty_tactical_identity_rejected() -> void:
	var bad: ConsumableDefinition = ConsumableDefinition.new(&"warding_salve", ConsumableDefinition.RARITY_UNCOMMON, 25, "   ")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An empty tactical identity must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "tactical_identity", "The error should name tactical_identity.")


func _no_equip_gate_field_exists() -> void:
	# Consumables are not equipped, so they carry NO character_level_requirement and NO run-depth gate.
	var definition: ConsumableDefinition = _valid_consumable()
	var property_names: Array[String] = []
	for property_info: Dictionary in definition.get_property_list():
		property_names.append(String(property_info.get("name")))
	assert_false(property_names.has("character_level_requirement"), "Consumables should not carry an equip gate.")
	assert_false(property_names.has("min_run_depth"), "Consumables should not carry a run-depth gate.")


func _is_valid_rarity_helper() -> void:
	assert_true(ConsumableDefinition.is_valid_rarity(ConsumableDefinition.RARITY_RARE), "rare is a valid rarity.")
	assert_false(ConsumableDefinition.is_valid_rarity(&"mythic"), "mythic is not a valid rarity.")
