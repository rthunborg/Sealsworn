extends "res://tests/unit/test_case.gd"

# Story 6.1 AC1/AC2/AC6 — GoldRewardRepository (the fail-closed gold-reward content repository). Same pin set as
# the other new repos: stable-id baseline, fail-closed lookup, generic boundary, null/invalid reject, fail-closed
# factory, BASELINE_*_IDS constant, duplicate-id fail-loud.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const GoldRewardDefinition = preload("res://scripts/content/definitions/gold_reward_definition.gd")
const GoldRewardRepository = preload("res://scripts/content/repositories/gold_reward_repository.gd")

const EXPECTED_GOLD_REWARD_IDS: Array[StringName] = [
	&"small_gold_purse",
	&"large_gold_purse"
]

func run() -> Dictionary:
	_baseline_gold_rewards_registered_by_stable_id()
	_baseline_gold_rewards_validate()
	_get_gold_reward_returns_null_on_a_miss()
	_repository_keeps_generic_content_registration_intact()
	_register_gold_reward_rejects_null_definition()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_repository_rejects_duplicate_id_fail_loud()
	return result()


func _baseline_gold_rewards_registered_by_stable_id() -> void:
	var repository: GoldRewardRepository = GoldRewardRepository.create_baseline_repository()
	assert_equal(repository.gold_reward_ids(), EXPECTED_GOLD_REWARD_IDS, "Baseline gold-reward ids should be stable and ordered.")
	for gold_reward_id: StringName in EXPECTED_GOLD_REWARD_IDS:
		assert_true(repository.get_gold_reward(gold_reward_id) != null, "Baseline gold reward %s should be available through the repository." % String(gold_reward_id))
		assert_true(repository.has_gold_reward(gold_reward_id), "Repository should report having baseline gold reward %s." % String(gold_reward_id))


func _baseline_gold_rewards_validate() -> void:
	var repository: GoldRewardRepository = GoldRewardRepository.create_baseline_repository()
	for gold_reward_id: StringName in EXPECTED_GOLD_REWARD_IDS:
		var definition: GoldRewardDefinition = repository.get_gold_reward(gold_reward_id)
		assert_true(definition.validate().succeeded, "Baseline gold reward %s should validate." % String(gold_reward_id))
		assert_equal(definition.gold_reward_id, gold_reward_id, "Gold-reward ids should use lower snake StringName values.")
		assert_true(definition.gold_max >= definition.gold_min, "Gold reward %s band should be well-ordered." % String(gold_reward_id))


func _get_gold_reward_returns_null_on_a_miss() -> void:
	var repository: GoldRewardRepository = GoldRewardRepository.create_baseline_repository()
	assert_true(repository.get_gold_reward(&"does_not_exist") == null, "get_gold_reward must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_gold_reward(&"") == null, "get_gold_reward must return null on an empty id (fail-closed).")
	assert_false(repository.has_gold_reward(&"does_not_exist"), "has_gold_reward should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: GoldRewardRepository = GoldRewardRepository.create_baseline_repository(content_repository)
	for gold_reward_id: StringName in EXPECTED_GOLD_REWARD_IDS:
		assert_true(
			content_repository.has_definition(GoldRewardDefinition.DEFINITION_TYPE, gold_reward_id),
			"Gold reward %s should be registered through the generic content repository boundary." % String(gold_reward_id)
		)
		assert_equal(
			content_repository.get_definition(GoldRewardDefinition.DEFINITION_TYPE, gold_reward_id),
			repository.get_gold_reward(gold_reward_id),
			"Gold reward %s should not require direct gameplay file access." % String(gold_reward_id)
		)
	assert_equal(repository.content_repository(), content_repository, "Repository should expose the shared content repository boundary.")


func _register_gold_reward_rejects_null_definition() -> void:
	var repository: GoldRewardRepository = GoldRewardRepository.new()
	var result_value: ActionResult = repository.register_gold_reward(null)
	assert_true(result_value.is_error(), "Registering a null gold reward should fail.")
	assert_equal(result_value.error_code, &"invalid_gold_reward_repository", "Null gold-reward registration should use the stable repository error code.")
	assert_true(repository.gold_reward_ids().is_empty(), "A failed registration should not add a gold-reward id.")


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: GoldRewardDefinition = GoldRewardDefinition.new()
	var repository: GoldRewardRepository = GoldRewardRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered gold-reward content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: GoldRewardDefinition = GoldRewardDefinition.new(&"small_gold_purse", 5, 15, "A small purse.")
	var partial_repository: GoldRewardRepository = GoldRewardRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition], shared_content_repository
	)
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(GoldRewardDefinition.DEFINITION_TYPE, &"small_gold_purse"),
		"A failed gold-reward repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: GoldRewardRepository = GoldRewardRepository.create_baseline_repository()
	assert_equal(GoldRewardRepository.BASELINE_GOLD_REWARD_IDS, repository.gold_reward_ids(), "The BASELINE_GOLD_REWARD_IDS constant should match the actually-registered ids.")


func _repository_rejects_duplicate_id_fail_loud() -> void:
	var first: GoldRewardDefinition = GoldRewardDefinition.new(&"small_gold_purse", 5, 15, "First.")
	var duplicate: GoldRewardDefinition = GoldRewardDefinition.new(&"small_gold_purse", 100, 200, "Distinct duplicate.")
	var repository: GoldRewardRepository = GoldRewardRepository.new()
	assert_true(repository.register_gold_reward(first).succeeded, "The first gold-reward registration should succeed.")
	var duplicate_result: ActionResult = repository.register_gold_reward(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same gold-reward id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_gold_reward", "A duplicate id should use the stable duplicate_gold_reward code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "small_gold_purse", "The duplicate error should carry the offending id.")
	assert_equal(repository.gold_reward_ids(), [&"small_gold_purse"] as Array[StringName], "gold_reward_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_gold_reward(&"small_gold_purse").gold_max, 15, "get_gold_reward must still resolve the FIRST definition (no silent shadow).")
	assert_equal(GoldRewardRepository.create_repository_from_definitions([first, duplicate]), null, "A definitions batch carrying a duplicate id must fail closed (null).")
