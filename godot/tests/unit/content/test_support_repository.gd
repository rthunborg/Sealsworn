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

	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered support content.")
