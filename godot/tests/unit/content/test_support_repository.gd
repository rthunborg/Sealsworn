extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")

const EXPECTED_SUPPORTS: Dictionary = {
	&"none": {
		"armor": 0,
		"block_chance": 0.0,
		"bonus_damage": 0,
		"bonus_weapon_ids": []
	},
	&"tome": {
		"armor": 0,
		"block_chance": 0.0,
		"bonus_damage": 1,
		"bonus_weapon_ids": [&"staff", &"wand"]
	},
	&"shield": {
		"armor": 1,
		"block_chance": 0.5,
		"bonus_damage": 0,
		"bonus_weapon_ids": []
	}
}

func run() -> Dictionary:
	_baseline_support_definitions_are_registered_by_stable_id()
	_support_definitions_validate_baseline_fields()
	_support_repository_keeps_generic_content_registration_intact()
	_support_repository_factory_fails_closed_on_invalid_definitions()
	_support_repository_rejects_duplicate_id_fail_loud()
	return result()


func _baseline_support_definitions_are_registered_by_stable_id() -> void:
	var repository: SupportRepository = SupportRepository.create_baseline_repository()
	var actual_ids: Array[StringName] = repository.support_ids()

	assert_equal(actual_ids, EXPECTED_SUPPORTS.keys(), "Baseline support ids should be stable and ordered.")
	for support_id: StringName in EXPECTED_SUPPORTS.keys():
		var definition: SupportDefinition = repository.get_support(support_id)
		assert_true(definition != null, "Baseline support %s should be available through the repository." % String(support_id))


func _support_definitions_validate_baseline_fields() -> void:
	var repository: SupportRepository = SupportRepository.create_baseline_repository()

	for support_id: StringName in EXPECTED_SUPPORTS.keys():
		var definition: SupportDefinition = repository.get_support(support_id)
		var expected: Dictionary = EXPECTED_SUPPORTS[support_id]
		var validation: ActionResult = definition.validate()

		assert_true(validation.succeeded, "Support %s should validate required fields." % String(support_id))
		assert_equal(definition.support_id, support_id, "Support ids should use lower snake StringName values.")
		assert_equal(definition.armor, expected.get("armor"), "Support %s should expose armor." % String(support_id))
		assert_equal(definition.block_chance, expected.get("block_chance"), "Support %s should expose block chance." % String(support_id))
		assert_equal(definition.bonus_damage, expected.get("bonus_damage"), "Support %s should expose bonus damage." % String(support_id))
		assert_equal(definition.bonus_weapon_ids, expected.get("bonus_weapon_ids"), "Support %s should expose bonus weapon ids." % String(support_id))


func _support_repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: SupportRepository = SupportRepository.create_baseline_repository(content_repository)

	for support_id: StringName in EXPECTED_SUPPORTS.keys():
		assert_true(
			content_repository.has_definition(SupportDefinition.DEFINITION_TYPE, support_id),
			"Support %s should be registered through the generic content repository boundary." % String(support_id)
		)
		assert_equal(
			content_repository.get_definition(SupportDefinition.DEFINITION_TYPE, support_id),
			repository.get_support(support_id),
			"Support %s should not require direct gameplay file access." % String(support_id)
		)


func _support_repository_factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: SupportDefinition = SupportDefinition.new()
	var repository: SupportRepository = SupportRepository.create_repository_from_definitions([invalid_definition])
	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: SupportDefinition = SupportDefinition.new(
		SupportDefinition.SUPPORT_NONE,
		0,
		0.0,
		0,
		[],
		"No off-hand modifier."
	)
	var partial_repository: SupportRepository = SupportRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition],
		shared_content_repository
	)

	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered support content.")
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(SupportDefinition.DEFINITION_TYPE, SupportDefinition.SUPPORT_NONE),
		"Failed support repository creation must not mutate a provided content repository."
	)


# Story 6.1 AC6 — a SECOND registration under an already-present support id fails loud with a structured
# duplicate_support error, leaving support_ids() + get_support consistent. A duplicate in a batch fails closed.
func _support_repository_rejects_duplicate_id_fail_loud() -> void:
	var first: SupportDefinition = SupportDefinition.new(
		SupportDefinition.SUPPORT_SHIELD, 1, 0.5, 0, [], "First shield."
	)
	var duplicate: SupportDefinition = SupportDefinition.new(
		SupportDefinition.SUPPORT_SHIELD, 3, 0.9, 0, [], "Distinct duplicate shield."
	)
	var repository: SupportRepository = SupportRepository.new()
	assert_true(repository.register_support(first).succeeded, "The first support registration should succeed.")
	var duplicate_result: ActionResult = repository.register_support(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same support id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_support", "A duplicate id should use the stable duplicate_support code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "shield", "The duplicate error should carry the offending id.")
	assert_equal(repository.support_ids(), [&"shield"] as Array[StringName], "support_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_support(SupportDefinition.SUPPORT_SHIELD).armor, 1, "get_support must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: SupportRepository = SupportRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")
