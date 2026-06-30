extends "res://tests/unit/test_case.gd"

# Story 7.2 — CursedRewardRepository (the fail-closed cursed-reward content repository). Mirrors
# test_passive_repository.gd: the baseline registers exactly the BASELINE_CURSED_REWARD_IDS in stable order;
# get_cursed_reward(id) resolves each baseline + returns null on a miss (fail-closed); has_cursed_reward; the
# registration goes through the generic ContentRepository boundary; create_repository_from_definitions fails closed on
# a bad def (and does not mutate a provided content repository); and the all-repos duplicate-id fail-loud guard
# (duplicate_cursed_reward).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const CursedRewardDefinition = preload("res://scripts/content/definitions/cursed_reward_definition.gd")
const CursedRewardRepository = preload("res://scripts/content/repositories/cursed_reward_repository.gd")

func run() -> Dictionary:
	_baseline_registers_exactly_the_expected_ids()
	_get_cursed_reward_resolves_each_baseline()
	_get_cursed_reward_returns_null_on_a_miss()
	_has_cursed_reward_reflects_registration()
	_repository_keeps_generic_content_registration_intact()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_rejects_duplicate_id_fail_loud()
	return result()


# A fully valid cursed reward (a genuine tradeoff) for fixtures that must PASS validate().
func _valid(cursed_reward_id: StringName) -> CursedRewardDefinition:
	return CursedRewardDefinition.new(
		cursed_reward_id,
		"Fixture Cursed Reward",
		"A clear upside.",
		"A clear downside.",
		10, 0, 1, 0, 0, 0,
		false,
		"A known consequence."
	)


func _baseline_registers_exactly_the_expected_ids() -> void:
	var repository: CursedRewardRepository = CursedRewardRepository.create_baseline_repository()
	assert_true(repository != null, "The baseline repository must build.")
	assert_equal(repository.cursed_reward_ids(), CursedRewardRepository.BASELINE_CURSED_REWARD_IDS, "The baseline should register EXACTLY the expected ids in stable order.")


func _get_cursed_reward_resolves_each_baseline() -> void:
	var repository: CursedRewardRepository = CursedRewardRepository.create_baseline_repository()
	for cursed_reward_id: StringName in CursedRewardRepository.BASELINE_CURSED_REWARD_IDS:
		var definition: CursedRewardDefinition = repository.get_cursed_reward(cursed_reward_id)
		assert_true(definition != null, "Baseline cursed reward %s should resolve." % String(cursed_reward_id))
		assert_equal(definition.cursed_reward_id, cursed_reward_id, "The resolved id should match the lookup id.")
		assert_true(definition.validate().succeeded, "Baseline cursed reward %s should validate." % String(cursed_reward_id))


func _get_cursed_reward_returns_null_on_a_miss() -> void:
	var repository: CursedRewardRepository = CursedRewardRepository.create_baseline_repository()
	assert_true(repository.get_cursed_reward(&"does_not_exist") == null, "get_cursed_reward must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_cursed_reward(&"") == null, "get_cursed_reward must return null on an empty id (fail-closed).")


func _has_cursed_reward_reflects_registration() -> void:
	var repository: CursedRewardRepository = CursedRewardRepository.create_baseline_repository()
	assert_true(repository.has_cursed_reward(CursedRewardRepository.BASELINE_CURSED_REWARD_IDS[0]), "has_cursed_reward should be true for a registered id.")
	assert_false(repository.has_cursed_reward(&"does_not_exist"), "has_cursed_reward should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: CursedRewardRepository = CursedRewardRepository.create_baseline_repository(content_repository)
	for cursed_reward_id: StringName in CursedRewardRepository.BASELINE_CURSED_REWARD_IDS:
		assert_true(
			content_repository.has_definition(CursedRewardDefinition.DEFINITION_TYPE, cursed_reward_id),
			"Cursed reward %s should be registered through the generic content repository boundary." % String(cursed_reward_id)
		)


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: CursedRewardDefinition = CursedRewardDefinition.new()
	var repository: CursedRewardRepository = CursedRewardRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "The factory should fail closed instead of returning partially registered content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var partial_repository: CursedRewardRepository = CursedRewardRepository.create_repository_from_definitions(
		[_valid(&"valid_one"), invalid_definition],
		shared_content_repository
	)
	assert_equal(partial_repository, null, "The factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(CursedRewardDefinition.DEFINITION_TYPE, &"valid_one"),
		"A failed repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: CursedRewardRepository = CursedRewardRepository.create_baseline_repository()
	assert_equal(CursedRewardRepository.BASELINE_CURSED_REWARD_IDS, repository.cursed_reward_ids(), "The BASELINE_CURSED_REWARD_IDS constant should match the actually-registered ids.")


func _rejects_duplicate_id_fail_loud() -> void:
	var first: CursedRewardDefinition = _valid(&"dup_id")
	var duplicate: CursedRewardDefinition = _valid(&"dup_id")
	duplicate.display_name = "Distinct Duplicate"
	var repository: CursedRewardRepository = CursedRewardRepository.new()
	assert_true(repository.register_cursed_reward(first).succeeded, "The first registration should succeed.")
	var duplicate_result: ActionResult = repository.register_cursed_reward(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_cursed_reward", "A duplicate id should use the stable duplicate_cursed_reward code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "dup_id", "The duplicate error should carry the offending id.")
	assert_equal(repository.cursed_reward_ids(), [&"dup_id"] as Array[StringName], "cursed_reward_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_cursed_reward(&"dup_id").display_name, "Fixture Cursed Reward", "get_cursed_reward must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: CursedRewardRepository = CursedRewardRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")
