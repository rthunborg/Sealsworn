extends "res://tests/unit/test_case.gd"

# Story 6.1 AC1/AC2/AC6 — RewardTableRepository (the fail-closed reward-table content repository). Same pin set
# as the other new repos PLUS an AC1 cross-repository integration check: every baseline reward-table entry that
# references a category with an existing repository (weapon/support/armor/jewelry/consumable/pickup/gold) names a
# REAL baseline id in that category's repository, so the AC3 offer fixture draws a genuine offer. (The table
# itself shape-validates by-id only — this is a test-level safety net, not a validate() resolution.)

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")
const RewardTableRepository = preload("res://scripts/content/repositories/reward_table_repository.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const ArmorRepository = preload("res://scripts/content/repositories/armor_repository.gd")
const JewelryRepository = preload("res://scripts/content/repositories/jewelry_repository.gd")
const ConsumableRepository = preload("res://scripts/content/repositories/consumable_repository.gd")
const PickupRepository = preload("res://scripts/content/repositories/pickup_repository.gd")
const GoldRewardRepository = preload("res://scripts/content/repositories/gold_reward_repository.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")

const EXPECTED_TABLE_IDS: Array[StringName] = [
	&"standard_combat_reward",
	&"elite_combat_reward",
	# Story 6.3 AC4: the passive 3-choice reward table (references the six baseline passive ids by-id).
	&"passive_reward_choice"
]

func run() -> Dictionary:
	_baseline_tables_registered_by_stable_id()
	_baseline_tables_validate()
	_get_reward_table_returns_null_on_a_miss()
	_repository_keeps_generic_content_registration_intact()
	_register_reward_table_rejects_null_definition()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_repository_rejects_duplicate_id_fail_loud()
	_baseline_table_entries_reference_real_content_ids()
	return result()


func _baseline_tables_registered_by_stable_id() -> void:
	var repository: RewardTableRepository = RewardTableRepository.create_baseline_repository()
	assert_equal(repository.reward_table_ids(), EXPECTED_TABLE_IDS, "Baseline reward-table ids should be stable and ordered.")
	for table_id: StringName in EXPECTED_TABLE_IDS:
		assert_true(repository.get_reward_table(table_id) != null, "Baseline reward table %s should be available through the repository." % String(table_id))
		assert_true(repository.has_reward_table(table_id), "Repository should report having baseline reward table %s." % String(table_id))


func _baseline_tables_validate() -> void:
	var repository: RewardTableRepository = RewardTableRepository.create_baseline_repository()
	for table_id: StringName in EXPECTED_TABLE_IDS:
		var definition: RewardTableDefinition = repository.get_reward_table(table_id)
		assert_true(definition.validate().succeeded, "Baseline reward table %s should validate." % String(table_id))
		assert_true(definition.total_weight() > 0, "Baseline reward table %s should have positive total weight." % String(table_id))


func _get_reward_table_returns_null_on_a_miss() -> void:
	var repository: RewardTableRepository = RewardTableRepository.create_baseline_repository()
	assert_true(repository.get_reward_table(&"does_not_exist") == null, "get_reward_table must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_reward_table(&"") == null, "get_reward_table must return null on an empty id (fail-closed).")
	assert_false(repository.has_reward_table(&"does_not_exist"), "has_reward_table should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: RewardTableRepository = RewardTableRepository.create_baseline_repository(content_repository)
	for table_id: StringName in EXPECTED_TABLE_IDS:
		assert_true(
			content_repository.has_definition(RewardTableDefinition.DEFINITION_TYPE, table_id),
			"Reward table %s should be registered through the generic content repository boundary." % String(table_id)
		)
		assert_equal(
			content_repository.get_definition(RewardTableDefinition.DEFINITION_TYPE, table_id),
			repository.get_reward_table(table_id),
			"Reward table %s should not require direct gameplay file access." % String(table_id)
		)
	assert_equal(repository.content_repository(), content_repository, "Repository should expose the shared content repository boundary.")


func _register_reward_table_rejects_null_definition() -> void:
	var repository: RewardTableRepository = RewardTableRepository.new()
	var result_value: ActionResult = repository.register_reward_table(null)
	assert_true(result_value.is_error(), "Registering a null reward table should fail.")
	assert_equal(result_value.error_code, &"invalid_reward_table_repository", "Null reward-table registration should use the stable repository error code.")
	assert_true(repository.reward_table_ids().is_empty(), "A failed registration should not add a reward-table id.")


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: RewardTableDefinition = RewardTableDefinition.new()
	var repository: RewardTableRepository = RewardTableRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered reward-table content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: RewardTableDefinition = RewardTableDefinition.new(&"standard_combat_reward", [
		{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"small_gold_purse", "weight": 1}
	])
	var partial_repository: RewardTableRepository = RewardTableRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition], shared_content_repository
	)
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(RewardTableDefinition.DEFINITION_TYPE, &"standard_combat_reward"),
		"A failed reward-table repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: RewardTableRepository = RewardTableRepository.create_baseline_repository()
	assert_equal(RewardTableRepository.BASELINE_REWARD_TABLE_IDS, repository.reward_table_ids(), "The BASELINE_REWARD_TABLE_IDS constant should match the actually-registered ids.")


func _repository_rejects_duplicate_id_fail_loud() -> void:
	var first: RewardTableDefinition = RewardTableDefinition.new(&"standard_combat_reward", [
		{"category": RewardTableDefinition.CATEGORY_GOLD, "content_id": &"small_gold_purse", "weight": 1}
	])
	var duplicate: RewardTableDefinition = RewardTableDefinition.new(&"standard_combat_reward", [
		{"category": RewardTableDefinition.CATEGORY_WEAPON, "content_id": &"sword", "weight": 9}
	])
	var repository: RewardTableRepository = RewardTableRepository.new()
	assert_true(repository.register_reward_table(first).succeeded, "The first reward-table registration should succeed.")
	var duplicate_result: ActionResult = repository.register_reward_table(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same table id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_reward_table", "A duplicate id should use the stable duplicate_reward_table code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "standard_combat_reward", "The duplicate error should carry the offending id.")
	assert_equal(repository.reward_table_ids(), [&"standard_combat_reward"] as Array[StringName], "reward_table_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_reward_table(&"standard_combat_reward").total_weight(), 1, "get_reward_table must still resolve the FIRST definition (no silent shadow).")
	assert_equal(RewardTableRepository.create_repository_from_definitions([first, duplicate]), null, "A definitions batch carrying a duplicate id must fail closed (null).")


# AC1 integration safety net: each baseline reward-table entry references a REAL baseline id in the
# corresponding category's repository (so a reward marker / offer resolving an entry finds real content).
func _baseline_table_entries_reference_real_content_ids() -> void:
	var weapon_ids: Array[StringName] = WeaponRepository.BASELINE_WEAPON_IDS
	var support_ids: Array[StringName] = SupportRepository.BASELINE_SUPPORT_IDS
	var armor_ids: Array[StringName] = ArmorRepository.BASELINE_ARMOR_IDS
	var jewelry_ids: Array[StringName] = JewelryRepository.BASELINE_JEWELRY_IDS
	var consumable_ids: Array[StringName] = ConsumableRepository.BASELINE_CONSUMABLE_IDS
	var pickup_ids: Array[StringName] = PickupRepository.BASELINE_PICKUP_IDS
	var gold_ids: Array[StringName] = GoldRewardRepository.BASELINE_GOLD_REWARD_IDS
	var passive_ids: Array[StringName] = PassiveRepository.BASELINE_PASSIVE_IDS

	var repository: RewardTableRepository = RewardTableRepository.create_baseline_repository()
	for table_id: StringName in EXPECTED_TABLE_IDS:
		var definition: RewardTableDefinition = repository.get_reward_table(table_id)
		for entry_value: Variant in definition.reward_entries():
			var entry: Dictionary = entry_value
			var category: StringName = StringName(str(entry.get("category")))
			var content_id: StringName = StringName(str(entry.get("content_id")))
			match category:
				RewardTableDefinition.CATEGORY_WEAPON:
					assert_true(weapon_ids.has(content_id), "Table %s weapon entry %s should be a real weapon baseline id." % [String(table_id), String(content_id)])
				RewardTableDefinition.CATEGORY_SUPPORT:
					assert_true(support_ids.has(content_id), "Table %s support entry %s should be a real support baseline id." % [String(table_id), String(content_id)])
				RewardTableDefinition.CATEGORY_ARMOR:
					assert_true(armor_ids.has(content_id), "Table %s armor entry %s should be a real armor baseline id." % [String(table_id), String(content_id)])
				RewardTableDefinition.CATEGORY_JEWELRY:
					assert_true(jewelry_ids.has(content_id), "Table %s jewelry entry %s should be a real jewelry baseline id." % [String(table_id), String(content_id)])
				RewardTableDefinition.CATEGORY_CONSUMABLE:
					assert_true(consumable_ids.has(content_id), "Table %s consumable entry %s should be a real consumable baseline id." % [String(table_id), String(content_id)])
				RewardTableDefinition.CATEGORY_PICKUP:
					assert_true(pickup_ids.has(content_id), "Table %s pickup entry %s should be a real pickup baseline id." % [String(table_id), String(content_id)])
				RewardTableDefinition.CATEGORY_GOLD:
					assert_true(gold_ids.has(content_id), "Table %s gold entry %s should be a real gold-reward baseline id." % [String(table_id), String(content_id)])
				RewardTableDefinition.CATEGORY_PASSIVE:
					assert_true(passive_ids.has(content_id), "Table %s passive entry %s should be a real passive baseline id." % [String(table_id), String(content_id)])
