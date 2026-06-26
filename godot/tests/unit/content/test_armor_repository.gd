extends "res://tests/unit/test_case.gd"

# Story 6.1 AC1/AC2/AC6 — ArmorRepository (the fail-closed armor content repository). Pins: the baseline
# registers by stable id; get_armor resolves each baseline + returns null on a miss (fail-closed); has_armor;
# armor_ids order; the generic ContentRepository boundary; register_armor(null/invalid) fails structured;
# create_repository_from_definitions fails closed on a bad def (and does not mutate a provided content
# repository); a duplicate armor id fails loud (duplicate_armor) leaving armor_ids()/get_armor consistent.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const ArmorDefinition = preload("res://scripts/content/definitions/armor_definition.gd")
const ArmorRepository = preload("res://scripts/content/repositories/armor_repository.gd")
const ItemRollModel = preload("res://scripts/content/definitions/item_roll_model.gd")

const EXPECTED_ARMOR_IDS: Array[StringName] = [
	&"padded_vest",
	&"chain_hauberk",
	&"warded_plate"
]

func run() -> Dictionary:
	_baseline_armor_registered_by_stable_id()
	_baseline_armor_validates()
	_get_armor_returns_null_on_a_miss()
	_repository_keeps_generic_content_registration_intact()
	_register_armor_rejects_null_definition()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_repository_rejects_duplicate_id_fail_loud()
	return result()


func _baseline_armor_registered_by_stable_id() -> void:
	var repository: ArmorRepository = ArmorRepository.create_baseline_repository()
	assert_equal(repository.armor_ids(), EXPECTED_ARMOR_IDS, "Baseline armor ids should be stable and ordered.")
	for armor_id: StringName in EXPECTED_ARMOR_IDS:
		assert_true(repository.get_armor(armor_id) != null, "Baseline armor %s should be available through the repository." % String(armor_id))
		assert_true(repository.has_armor(armor_id), "Repository should report having baseline armor %s." % String(armor_id))


func _baseline_armor_validates() -> void:
	var repository: ArmorRepository = ArmorRepository.create_baseline_repository()
	for armor_id: StringName in EXPECTED_ARMOR_IDS:
		var definition: ArmorDefinition = repository.get_armor(armor_id)
		assert_true(definition.validate().succeeded, "Baseline armor %s should validate." % String(armor_id))
		assert_equal(definition.armor_id, armor_id, "Armor ids should use lower snake StringName values.")
	# AC4: at least one baseline is equippable from the start (no level gate) and at least one carries a gate.
	assert_false(repository.get_armor(&"padded_vest").requires_character_level(), "padded_vest should have no level gate (the none sentinel).")
	assert_true(repository.get_armor(&"warded_plate").requires_character_level(), "warded_plate should carry a character-level gate.")


func _get_armor_returns_null_on_a_miss() -> void:
	var repository: ArmorRepository = ArmorRepository.create_baseline_repository()
	assert_true(repository.get_armor(&"does_not_exist") == null, "get_armor must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_armor(&"") == null, "get_armor must return null on an empty id (fail-closed).")
	assert_false(repository.has_armor(&"does_not_exist"), "has_armor should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: ArmorRepository = ArmorRepository.create_baseline_repository(content_repository)
	for armor_id: StringName in EXPECTED_ARMOR_IDS:
		assert_true(
			content_repository.has_definition(ArmorDefinition.DEFINITION_TYPE, armor_id),
			"Armor %s should be registered through the generic content repository boundary." % String(armor_id)
		)
		assert_equal(
			content_repository.get_definition(ArmorDefinition.DEFINITION_TYPE, armor_id),
			repository.get_armor(armor_id),
			"Armor %s should not require direct gameplay file access." % String(armor_id)
		)
	assert_equal(repository.content_repository(), content_repository, "Repository should expose the shared content repository boundary.")


func _register_armor_rejects_null_definition() -> void:
	var repository: ArmorRepository = ArmorRepository.new()
	var result_value: ActionResult = repository.register_armor(null)
	assert_true(result_value.is_error(), "Registering a null armor should fail.")
	assert_equal(result_value.error_code, &"invalid_armor_repository", "Null armor registration should use the stable repository error code.")
	assert_true(repository.armor_ids().is_empty(), "A failed registration should not add an armor id.")


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: ArmorDefinition = ArmorDefinition.new()
	var repository: ArmorRepository = ArmorRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered armor content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: ArmorDefinition = ArmorDefinition.new(&"padded_vest", 1, 0, ItemRollModel.new(0, 1), "Light padding.")
	var partial_repository: ArmorRepository = ArmorRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition], shared_content_repository
	)
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(ArmorDefinition.DEFINITION_TYPE, &"padded_vest"),
		"A failed armor repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: ArmorRepository = ArmorRepository.create_baseline_repository()
	assert_equal(ArmorRepository.BASELINE_ARMOR_IDS, repository.armor_ids(), "The BASELINE_ARMOR_IDS constant should match the actually-registered ids.")


func _repository_rejects_duplicate_id_fail_loud() -> void:
	var first: ArmorDefinition = ArmorDefinition.new(&"padded_vest", 1, 0, ItemRollModel.new(0, 1), "First.")
	var duplicate: ArmorDefinition = ArmorDefinition.new(&"padded_vest", 9, 0, ItemRollModel.new(0, 1), "Distinct duplicate.")
	var repository: ArmorRepository = ArmorRepository.new()
	assert_true(repository.register_armor(first).succeeded, "The first armor registration should succeed.")
	var duplicate_result: ActionResult = repository.register_armor(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same armor id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_armor", "A duplicate id should use the stable duplicate_armor code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "padded_vest", "The duplicate error should carry the offending id.")
	assert_equal(repository.armor_ids(), [&"padded_vest"] as Array[StringName], "armor_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_armor(&"padded_vest").armor_value, 1, "get_armor must still resolve the FIRST definition (no silent shadow).")
	assert_equal(ArmorRepository.create_repository_from_definitions([first, duplicate]), null, "A definitions batch carrying a duplicate id must fail closed (null).")
