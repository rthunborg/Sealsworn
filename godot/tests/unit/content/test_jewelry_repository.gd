extends "res://tests/unit/test_case.gd"

# Story 6.1 AC1/AC2/AC6 — JewelryRepository (the fail-closed jewelry content repository). Same pin set as
# ArmorRepository: stable-id baseline, fail-closed lookup, generic boundary, null/invalid reject, fail-closed
# factory, BASELINE_*_IDS constant, duplicate-id fail-loud.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const JewelryDefinition = preload("res://scripts/content/definitions/jewelry_definition.gd")
const JewelryRepository = preload("res://scripts/content/repositories/jewelry_repository.gd")
const ItemRollModel = preload("res://scripts/content/definitions/item_roll_model.gd")

const EXPECTED_JEWELRY_IDS: Array[StringName] = [
	&"copper_band",
	&"jasper_amulet",
	&"sealbearers_signet"
]

func run() -> Dictionary:
	_baseline_jewelry_registered_by_stable_id()
	_baseline_jewelry_validates()
	_get_jewelry_returns_null_on_a_miss()
	_repository_keeps_generic_content_registration_intact()
	_register_jewelry_rejects_null_definition()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_repository_rejects_duplicate_id_fail_loud()
	return result()


func _baseline_jewelry_registered_by_stable_id() -> void:
	var repository: JewelryRepository = JewelryRepository.create_baseline_repository()
	assert_equal(repository.jewelry_ids(), EXPECTED_JEWELRY_IDS, "Baseline jewelry ids should be stable and ordered.")
	for jewelry_id: StringName in EXPECTED_JEWELRY_IDS:
		assert_true(repository.get_jewelry(jewelry_id) != null, "Baseline jewelry %s should be available through the repository." % String(jewelry_id))
		assert_true(repository.has_jewelry(jewelry_id), "Repository should report having baseline jewelry %s." % String(jewelry_id))


func _baseline_jewelry_validates() -> void:
	var repository: JewelryRepository = JewelryRepository.create_baseline_repository()
	for jewelry_id: StringName in EXPECTED_JEWELRY_IDS:
		var definition: JewelryDefinition = repository.get_jewelry(jewelry_id)
		assert_true(definition.validate().succeeded, "Baseline jewelry %s should validate." % String(jewelry_id))
		assert_equal(definition.jewelry_id, jewelry_id, "Jewelry ids should use lower snake StringName values.")
	assert_false(repository.get_jewelry(&"copper_band").requires_character_level(), "copper_band should have no level gate (the none sentinel).")
	assert_true(repository.get_jewelry(&"sealbearers_signet").requires_character_level(), "sealbearers_signet should carry a character-level gate.")


func _get_jewelry_returns_null_on_a_miss() -> void:
	var repository: JewelryRepository = JewelryRepository.create_baseline_repository()
	assert_true(repository.get_jewelry(&"does_not_exist") == null, "get_jewelry must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_jewelry(&"") == null, "get_jewelry must return null on an empty id (fail-closed).")
	assert_false(repository.has_jewelry(&"does_not_exist"), "has_jewelry should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: JewelryRepository = JewelryRepository.create_baseline_repository(content_repository)
	for jewelry_id: StringName in EXPECTED_JEWELRY_IDS:
		assert_true(
			content_repository.has_definition(JewelryDefinition.DEFINITION_TYPE, jewelry_id),
			"Jewelry %s should be registered through the generic content repository boundary." % String(jewelry_id)
		)
		assert_equal(
			content_repository.get_definition(JewelryDefinition.DEFINITION_TYPE, jewelry_id),
			repository.get_jewelry(jewelry_id),
			"Jewelry %s should not require direct gameplay file access." % String(jewelry_id)
		)
	assert_equal(repository.content_repository(), content_repository, "Repository should expose the shared content repository boundary.")


func _register_jewelry_rejects_null_definition() -> void:
	var repository: JewelryRepository = JewelryRepository.new()
	var result_value: ActionResult = repository.register_jewelry(null)
	assert_true(result_value.is_error(), "Registering a null jewelry should fail.")
	assert_equal(result_value.error_code, &"invalid_jewelry_repository", "Null jewelry registration should use the stable repository error code.")
	assert_true(repository.jewelry_ids().is_empty(), "A failed registration should not add a jewelry id.")


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: JewelryDefinition = JewelryDefinition.new()
	var repository: JewelryRepository = JewelryRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered jewelry content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: JewelryDefinition = JewelryDefinition.new(&"copper_band", JewelryDefinition.SLOT_RING, 1, 0, ItemRollModel.new(0, 1), "A ring.")
	var partial_repository: JewelryRepository = JewelryRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition], shared_content_repository
	)
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(JewelryDefinition.DEFINITION_TYPE, &"copper_band"),
		"A failed jewelry repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: JewelryRepository = JewelryRepository.create_baseline_repository()
	assert_equal(JewelryRepository.BASELINE_JEWELRY_IDS, repository.jewelry_ids(), "The BASELINE_JEWELRY_IDS constant should match the actually-registered ids.")


func _repository_rejects_duplicate_id_fail_loud() -> void:
	var first: JewelryDefinition = JewelryDefinition.new(&"copper_band", JewelryDefinition.SLOT_RING, 1, 0, ItemRollModel.new(0, 1), "First.")
	var duplicate: JewelryDefinition = JewelryDefinition.new(&"copper_band", JewelryDefinition.SLOT_AMULET, 9, 0, ItemRollModel.new(0, 1), "Distinct duplicate.")
	var repository: JewelryRepository = JewelryRepository.new()
	assert_true(repository.register_jewelry(first).succeeded, "The first jewelry registration should succeed.")
	var duplicate_result: ActionResult = repository.register_jewelry(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same jewelry id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_jewelry", "A duplicate id should use the stable duplicate_jewelry code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "copper_band", "The duplicate error should carry the offending id.")
	assert_equal(repository.jewelry_ids(), [&"copper_band"] as Array[StringName], "jewelry_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_jewelry(&"copper_band").jewelry_slot, JewelryDefinition.SLOT_RING, "get_jewelry must still resolve the FIRST definition (no silent shadow).")
	assert_equal(JewelryRepository.create_repository_from_definitions([first, duplicate]), null, "A definitions batch carrying a duplicate id must fail closed (null).")
