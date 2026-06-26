extends "res://tests/unit/test_case.gd"

# Story 6.1 AC2 / FR52 — PickupDefinition (an immediate-effect pickup). Pins: a valid definition validates; every
# validate() branch has a dedicated negative; the granted effect is referenced by a lower_snake id (shape only,
# not resolved); pickups carry NO equip gate.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const PickupDefinition = preload("res://scripts/content/definitions/pickup_definition.gd")

func run() -> Dictionary:
	_valid_pickup_validates()
	_pickup_id_must_be_lower_snake()
	_effect_id_must_be_lower_snake()
	_empty_tactical_identity_rejected()
	_no_equip_gate_field_exists()
	return result()


func _valid_pickup() -> PickupDefinition:
	return PickupDefinition.new(&"health_morsel", &"restore_small_health", "A small health morsel.")


func _valid_pickup_validates() -> void:
	assert_true(_valid_pickup().validate().succeeded, "A well-formed pickup definition should validate.")


func _pickup_id_must_be_lower_snake() -> void:
	var bad: PickupDefinition = PickupDefinition.new(&"HealthMorsel", &"restore_small_health", "Bad id.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake pickup id must be rejected.")
	assert_equal(validation.error_code, &"invalid_pickup_definition", "Use the stable pickup-definition error code.")
	assert_equal(String(validation.metadata.get("field")), "pickup_id", "The error should name pickup_id.")


func _effect_id_must_be_lower_snake() -> void:
	var bad: PickupDefinition = PickupDefinition.new(&"health_morsel", &"Restore-Health", "Bad effect id.")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "A non-lower_snake effect id must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "effect_id", "The error should name effect_id.")
	assert_true(PickupDefinition.new(&"health_morsel", &"", "Empty effect.").validate().is_error(), "An empty effect id must be rejected.")


func _empty_tactical_identity_rejected() -> void:
	var bad: PickupDefinition = PickupDefinition.new(&"health_morsel", &"restore_small_health", "")
	var validation: ActionResult = bad.validate()
	assert_true(validation.is_error(), "An empty tactical identity must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "tactical_identity", "The error should name tactical_identity.")


func _no_equip_gate_field_exists() -> void:
	var definition: PickupDefinition = _valid_pickup()
	var property_names: Array[String] = []
	for property_info: Dictionary in definition.get_property_list():
		property_names.append(String(property_info.get("name")))
	assert_false(property_names.has("character_level_requirement"), "Pickups should not carry an equip gate.")
	assert_false(property_names.has("min_run_depth"), "Pickups should not carry a run-depth gate.")
