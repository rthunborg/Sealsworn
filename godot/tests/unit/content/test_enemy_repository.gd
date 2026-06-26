extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const EnemyDefinition = preload("res://scripts/content/definitions/enemy_definition.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")

const EXPECTED_ENEMIES: Dictionary = {
	&"iron_cultist": {
		"max_hp": 10,
		"behavior_id": &"melee_pressure",
		"move_budget": 1,
		"melee_range": 1,
		"melee_damage": 3,
		"blocks_movement": true
	},
	&"gate_brute": {
		"max_hp": 12,
		"behavior_id": &"melee_pressure",
		"move_budget": 1,
		"melee_range": 1,
		"melee_damage": 3,
		"blocks_movement": true
	},
	&"ash_seer": {
		"max_hp": 8,
		"behavior_id": &"seer_mark",
		"mark_range": 5,
		"requires_line_of_sight": true,
		"detonation_damage": 4,
		"blocks_movement": true
	}
}

func run() -> Dictionary:
	_baseline_enemy_definitions_are_registered_by_stable_id()
	_enemy_definitions_validate_baseline_fields()
	_enemy_repository_keeps_generic_content_registration_intact()
	_enemy_repository_factory_fails_closed_on_invalid_definitions()
	_enemy_repository_rejects_duplicate_id_fail_loud()
	return result()


func _baseline_enemy_definitions_are_registered_by_stable_id() -> void:
	var repository: EnemyRepository = EnemyRepository.create_baseline_repository()
	var actual_ids: Array[StringName] = repository.enemy_ids()

	assert_equal(actual_ids, EXPECTED_ENEMIES.keys(), "Baseline enemy ids should be stable and ordered.")
	for enemy_id: StringName in EXPECTED_ENEMIES.keys():
		var definition: EnemyDefinition = repository.get_enemy(enemy_id)
		assert_true(definition != null, "Baseline enemy %s should be available through the repository." % String(enemy_id))


func _enemy_definitions_validate_baseline_fields() -> void:
	var repository: EnemyRepository = EnemyRepository.create_baseline_repository()

	for enemy_id: StringName in EXPECTED_ENEMIES.keys():
		var definition: EnemyDefinition = repository.get_enemy(enemy_id)
		var expected: Dictionary = EXPECTED_ENEMIES[enemy_id]
		var validation: ActionResult = definition.validate()

		assert_true(validation.succeeded, "Enemy %s should validate required fields." % String(enemy_id))
		assert_equal(definition.enemy_id, enemy_id, "Enemy ids should use lower snake StringName values.")
		assert_equal(definition.max_hp, expected.get("max_hp"), "Enemy %s should expose max HP." % String(enemy_id))
		assert_equal(definition.behavior_id, expected.get("behavior_id"), "Enemy %s should expose behavior id." % String(enemy_id))
		assert_equal(definition.blocks_movement, expected.get("blocks_movement"), "Enemy %s should expose blocking occupancy." % String(enemy_id))
		if enemy_id == &"ash_seer":
			assert_equal(definition.mark_range, expected.get("mark_range"), "Ash Seer should expose mark range.")
			assert_equal(definition.requires_line_of_sight, expected.get("requires_line_of_sight"), "Ash Seer should require line of sight.")
			assert_equal(definition.detonation_damage, expected.get("detonation_damage"), "Ash Seer should expose delayed detonation damage.")
		else:
			assert_equal(definition.move_budget, expected.get("move_budget"), "Melee enemy %s should expose one-step movement." % String(enemy_id))
			assert_equal(definition.melee_range, expected.get("melee_range"), "Melee enemy %s should expose cardinal melee range." % String(enemy_id))
			assert_equal(definition.melee_damage, expected.get("melee_damage"), "Melee enemy %s should expose physical melee damage." % String(enemy_id))


func _enemy_repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: EnemyRepository = EnemyRepository.create_baseline_repository(content_repository)

	for enemy_id: StringName in EXPECTED_ENEMIES.keys():
		assert_true(
			content_repository.has_definition(EnemyDefinition.DEFINITION_TYPE, enemy_id),
			"Enemy %s should be registered through the generic content repository boundary." % String(enemy_id)
		)
		assert_equal(
			content_repository.get_definition(EnemyDefinition.DEFINITION_TYPE, enemy_id),
			repository.get_enemy(enemy_id),
			"Enemy %s should not require direct gameplay file access." % String(enemy_id)
		)


func _enemy_repository_factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: EnemyDefinition = EnemyDefinition.new()
	var repository: EnemyRepository = EnemyRepository.create_repository_from_definitions([invalid_definition])
	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: EnemyDefinition = EnemyDefinition.new(
		&"iron_cultist",
		10,
		&"melee_pressure",
		true,
		1,
		1,
		3,
		&"physical",
		0,
		false,
		0,
		&"physical",
		"Advances toward the player and strikes adjacent targets."
	)
	var partial_repository: EnemyRepository = EnemyRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition],
		shared_content_repository
	)

	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered enemy content.")
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(EnemyDefinition.DEFINITION_TYPE, &"iron_cultist"),
		"Failed enemy repository creation must not mutate a provided content repository."
	)


# Story 6.1 AC6 — a SECOND registration under an already-present enemy id fails loud with a structured
# duplicate_enemy error, leaving enemy_ids() + get_enemy consistent. A duplicate in a batch fails closed.
func _enemy_repository_rejects_duplicate_id_fail_loud() -> void:
	var first: EnemyDefinition = EnemyDefinition.new(
		&"iron_cultist", 10, &"melee_pressure", true, 1, 1, 3, &"physical", 0, false, 0, &"physical", "First."
	)
	var duplicate: EnemyDefinition = EnemyDefinition.new(
		&"iron_cultist", 99, &"melee_pressure", true, 1, 1, 7, &"physical", 0, false, 0, &"physical", "Distinct duplicate."
	)
	var repository: EnemyRepository = EnemyRepository.new()
	assert_true(repository.register_enemy(first).succeeded, "The first enemy registration should succeed.")
	var duplicate_result: ActionResult = repository.register_enemy(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same enemy id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_enemy", "A duplicate id should use the stable duplicate_enemy code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "iron_cultist", "The duplicate error should carry the offending id.")
	assert_equal(repository.enemy_ids(), [&"iron_cultist"] as Array[StringName], "enemy_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_enemy(&"iron_cultist").max_hp, 10, "get_enemy must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: EnemyRepository = EnemyRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")
