extends "res://tests/unit/test_case.gd"

# Story 6.1 AC1/AC2/AC6 — ConsumableRepository (the fail-closed consumable content repository). Same pin set as
# the other new repos: stable-id baseline, fail-closed lookup, generic boundary, null/invalid reject, fail-closed
# factory, BASELINE_*_IDS constant, duplicate-id fail-loud.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const ConsumableDefinition = preload("res://scripts/content/definitions/consumable_definition.gd")
const ConsumableRepository = preload("res://scripts/content/repositories/consumable_repository.gd")

const EXPECTED_CONSUMABLE_IDS: Array[StringName] = [
	&"minor_healing_draught",
	&"warding_salve",
	&"ember_flask"
]

func run() -> Dictionary:
	_baseline_consumables_registered_by_stable_id()
	_baseline_consumables_validate_and_span_rarities()
	_get_consumable_returns_null_on_a_miss()
	_repository_keeps_generic_content_registration_intact()
	_register_consumable_rejects_null_definition()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_repository_rejects_duplicate_id_fail_loud()
	return result()


func _baseline_consumables_registered_by_stable_id() -> void:
	var repository: ConsumableRepository = ConsumableRepository.create_baseline_repository()
	assert_equal(repository.consumable_ids(), EXPECTED_CONSUMABLE_IDS, "Baseline consumable ids should be stable and ordered.")
	for consumable_id: StringName in EXPECTED_CONSUMABLE_IDS:
		assert_true(repository.get_consumable(consumable_id) != null, "Baseline consumable %s should be available through the repository." % String(consumable_id))
		assert_true(repository.has_consumable(consumable_id), "Repository should report having baseline consumable %s." % String(consumable_id))


func _baseline_consumables_validate_and_span_rarities() -> void:
	var repository: ConsumableRepository = ConsumableRepository.create_baseline_repository()
	var rarities: Array[StringName] = []
	for consumable_id: StringName in EXPECTED_CONSUMABLE_IDS:
		var definition: ConsumableDefinition = repository.get_consumable(consumable_id)
		assert_true(definition.validate().succeeded, "Baseline consumable %s should validate." % String(consumable_id))
		assert_true(definition.value > 0, "Baseline consumable %s should carry a positive worth-using value (FR53)." % String(consumable_id))
		rarities.append(definition.rarity)
	# FR53: consumables span a rarity spread (semi-rare worth-using items exist, not all common).
	assert_true(rarities.has(ConsumableDefinition.RARITY_UNCOMMON), "Baselines should include an uncommon (semi-rare) consumable.")
	assert_true(rarities.has(ConsumableDefinition.RARITY_RARE), "Baselines should include a rare consumable.")


func _get_consumable_returns_null_on_a_miss() -> void:
	var repository: ConsumableRepository = ConsumableRepository.create_baseline_repository()
	assert_true(repository.get_consumable(&"does_not_exist") == null, "get_consumable must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_consumable(&"") == null, "get_consumable must return null on an empty id (fail-closed).")
	assert_false(repository.has_consumable(&"does_not_exist"), "has_consumable should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: ConsumableRepository = ConsumableRepository.create_baseline_repository(content_repository)
	for consumable_id: StringName in EXPECTED_CONSUMABLE_IDS:
		assert_true(
			content_repository.has_definition(ConsumableDefinition.DEFINITION_TYPE, consumable_id),
			"Consumable %s should be registered through the generic content repository boundary." % String(consumable_id)
		)
		assert_equal(
			content_repository.get_definition(ConsumableDefinition.DEFINITION_TYPE, consumable_id),
			repository.get_consumable(consumable_id),
			"Consumable %s should not require direct gameplay file access." % String(consumable_id)
		)
	assert_equal(repository.content_repository(), content_repository, "Repository should expose the shared content repository boundary.")


func _register_consumable_rejects_null_definition() -> void:
	var repository: ConsumableRepository = ConsumableRepository.new()
	var result_value: ActionResult = repository.register_consumable(null)
	assert_true(result_value.is_error(), "Registering a null consumable should fail.")
	assert_equal(result_value.error_code, &"invalid_consumable_repository", "Null consumable registration should use the stable repository error code.")
	assert_true(repository.consumable_ids().is_empty(), "A failed registration should not add a consumable id.")


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: ConsumableDefinition = ConsumableDefinition.new()
	var repository: ConsumableRepository = ConsumableRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered consumable content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: ConsumableDefinition = ConsumableDefinition.new(&"minor_healing_draught", ConsumableDefinition.RARITY_COMMON, 10, "A draught.")
	var partial_repository: ConsumableRepository = ConsumableRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition], shared_content_repository
	)
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(ConsumableDefinition.DEFINITION_TYPE, &"minor_healing_draught"),
		"A failed consumable repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: ConsumableRepository = ConsumableRepository.create_baseline_repository()
	assert_equal(ConsumableRepository.BASELINE_CONSUMABLE_IDS, repository.consumable_ids(), "The BASELINE_CONSUMABLE_IDS constant should match the actually-registered ids.")


func _repository_rejects_duplicate_id_fail_loud() -> void:
	var first: ConsumableDefinition = ConsumableDefinition.new(&"minor_healing_draught", ConsumableDefinition.RARITY_COMMON, 10, "First.")
	var duplicate: ConsumableDefinition = ConsumableDefinition.new(&"minor_healing_draught", ConsumableDefinition.RARITY_RARE, 99, "Distinct duplicate.")
	var repository: ConsumableRepository = ConsumableRepository.new()
	assert_true(repository.register_consumable(first).succeeded, "The first consumable registration should succeed.")
	var duplicate_result: ActionResult = repository.register_consumable(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same consumable id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_consumable", "A duplicate id should use the stable duplicate_consumable code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "minor_healing_draught", "The duplicate error should carry the offending id.")
	assert_equal(repository.consumable_ids(), [&"minor_healing_draught"] as Array[StringName], "consumable_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_consumable(&"minor_healing_draught").value, 10, "get_consumable must still resolve the FIRST definition (no silent shadow).")
	assert_equal(ConsumableRepository.create_repository_from_definitions([first, duplicate]), null, "A definitions batch carrying a duplicate id must fail closed (null).")
