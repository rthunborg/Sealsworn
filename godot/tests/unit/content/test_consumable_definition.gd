extends "res://tests/unit/test_case.gd"

# Story 6.1 AC2 / FR53 — ConsumableDefinition. Pins: a valid definition validates; every validate() branch has a
# dedicated negative; rarity is allowlist-validated (the scarcity-as-data tier); value is a positive worth-using
# measure; consumables carry NO equip gate (not equipped).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ConsumableDefinition = preload("res://scripts/content/definitions/consumable_definition.gd")

const ConsumableRepository = preload("res://scripts/content/repositories/consumable_repository.gd")

func run() -> Dictionary:
	_valid_consumable_validates()
	_consumable_id_must_be_lower_snake()
	_rarity_must_be_in_allowlist()
	_non_positive_value_rejected()
	_empty_tactical_identity_rejected()
	_no_equip_gate_field_exists()
	_is_valid_rarity_helper()
	# Story 6.7: the additive outcome_effect/explanation fields.
	_outcome_effect_and_explanation_validate_and_round_trip()
	_blank_outcome_effect_rejected()
	_blank_explanation_rejected()
	_baseline_consumables_carry_non_empty_effect_and_explanation()
	return result()


func _valid_consumable() -> ConsumableDefinition:
	# Story 6.7: a valid consumable now carries the additive outcome_effect + explanation.
	return ConsumableDefinition.new(
		&"warding_salve",
		ConsumableDefinition.RARITY_UNCOMMON,
		25,
		"A semi-rare salve.",
		"apply_protective_ward",
		"Using the salve braces the hero against the next bout of harm."
	)


func _valid_consumable_validates() -> void:
	assert_true(_valid_consumable().validate().succeeded, "A well-formed consumable definition should validate.")
	for rarity: StringName in [ConsumableDefinition.RARITY_COMMON, ConsumableDefinition.RARITY_UNCOMMON, ConsumableDefinition.RARITY_RARE]:
		assert_true(ConsumableDefinition.new(&"draught", rarity, 5, "A draught.", "restore_health", "Restores health.").validate().succeeded, "Rarity %s should validate." % String(rarity))


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


# ---- Story 6.7: the additive outcome_effect / explanation fields ---------------------------------

func _outcome_effect_and_explanation_validate_and_round_trip() -> void:
	# The additive fields are stored verbatim and a well-formed definition with them validates.
	var definition: ConsumableDefinition = _valid_consumable()
	assert_equal(definition.outcome_effect, "apply_protective_ward", "The outcome_effect is stored verbatim.")
	assert_equal(definition.explanation, "Using the salve braces the hero against the next bout of harm.", "The explanation is stored verbatim.")
	assert_true(definition.validate().succeeded, "A definition with non-empty outcome_effect + explanation validates.")
	# The two new fields are real exported properties on the resource.
	var property_names: Array[String] = []
	for property_info: Dictionary in definition.get_property_list():
		property_names.append(String(property_info.get("name")))
	assert_true(property_names.has("outcome_effect"), "The definition exports outcome_effect.")
	assert_true(property_names.has("explanation"), "The definition exports explanation.")


func _blank_outcome_effect_rejected() -> void:
	# A blank outcome_effect rejects per-field (the value/tactical_identity fields are valid, so the rejection is
	# attributable to outcome_effect).
	var blank: ConsumableDefinition = ConsumableDefinition.new(&"warding_salve", ConsumableDefinition.RARITY_UNCOMMON, 25, "A salve.", "", "Known result.")
	var validation: ActionResult = blank.validate()
	assert_true(validation.is_error(), "A blank outcome_effect must be rejected.")
	assert_equal(validation.error_code, &"invalid_consumable_definition", "Use the stable consumable-definition error code.")
	assert_equal(String(validation.metadata.get("field")), "outcome_effect", "The error should name outcome_effect.")
	# Whitespace-only is also blank.
	assert_true(ConsumableDefinition.new(&"warding_salve", ConsumableDefinition.RARITY_UNCOMMON, 25, "A salve.", "   ", "Known result.").validate().is_error(), "A whitespace-only outcome_effect must be rejected.")


func _blank_explanation_rejected() -> void:
	# A blank explanation rejects per-field (outcome_effect is valid, so the rejection is attributable to explanation).
	var blank: ConsumableDefinition = ConsumableDefinition.new(&"warding_salve", ConsumableDefinition.RARITY_UNCOMMON, 25, "A salve.", "apply_ward", "")
	var validation: ActionResult = blank.validate()
	assert_true(validation.is_error(), "A blank explanation must be rejected.")
	assert_equal(String(validation.metadata.get("field")), "explanation", "The error should name explanation.")
	assert_true(ConsumableDefinition.new(&"warding_salve", ConsumableDefinition.RARITY_UNCOMMON, 25, "A salve.", "apply_ward", "   ").validate().is_error(), "A whitespace-only explanation must be rejected.")


func _baseline_consumables_carry_non_empty_effect_and_explanation() -> void:
	# The 6.4 lesson: a tightened validate() requires the new field; the three baselines must be extended or the
	# baseline repository returns null. Assert the baseline repo builds AND every baseline carries non-empty fields.
	var repository: ConsumableRepository = ConsumableRepository.create_baseline_repository()
	assert_true(repository != null, "The baseline consumable repository must build with the extended baselines (not null).")
	for consumable_id: StringName in ConsumableRepository.BASELINE_CONSUMABLE_IDS:
		var definition: ConsumableDefinition = repository.get_consumable(consumable_id)
		assert_true(definition != null, "Baseline consumable '%s' must resolve." % String(consumable_id))
		assert_true(definition.validate().succeeded, "Baseline consumable '%s' must validate (carries the new fields)." % String(consumable_id))
		assert_false(definition.outcome_effect.strip_edges().is_empty(), "Baseline consumable '%s' must carry a non-empty outcome_effect." % String(consumable_id))
		assert_false(definition.explanation.strip_edges().is_empty(), "Baseline consumable '%s' must carry a non-empty explanation." % String(consumable_id))
