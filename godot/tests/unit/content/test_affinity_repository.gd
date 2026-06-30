extends "res://tests/unit/test_case.gd"

# Story 7.4 Task 2 — AffinityRepository (the fail-closed affinity content repository + the AC3 neutral query surface).
# Mirrors test_cursed_reward_repository.gd: the baseline registers exactly the BASELINE_AFFINITY_IDS in stable order;
# get_affinity(id) resolves each baseline + returns null on a miss (fail-closed); has_affinity; registration goes
# through the generic ContentRepository boundary; create_repository_from_definitions fails closed on a bad def (and does
# not mutate a provided content repository); the all-repos duplicate-id fail-loud guard (duplicate_affinity); AND the
# AC3 neutral query surface — tactical_rules_for(&"none") returns the EMPTY/NEUTRAL set, tactical_rules_for(<real>)
# returns its recorded rules, and tactical_rules_for(<unknown>) fail-SAFEs to the empty set.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")

func run() -> Dictionary:
	_baseline_registers_exactly_the_expected_ids()
	_get_affinity_resolves_each_baseline()
	_get_affinity_returns_null_on_a_miss()
	_has_affinity_reflects_registration()
	_repository_keeps_generic_content_registration_intact()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_rejects_duplicate_id_fail_loud()
	_tactical_rules_for_neutral_returns_the_empty_set()
	_tactical_rules_for_a_real_affinity_returns_its_rules()
	_tactical_rules_for_an_unknown_id_fail_safes_to_empty()
	_tactical_rules_for_is_a_pure_read()
	return result()


# A fully valid affinity for fixtures that must PASS validate().
func _valid(affinity_id: StringName) -> AffinityDefinition:
	return AffinityDefinition.new(
		affinity_id,
		"Fixture Affinity",
		[{"rule_id": "fixture_pressure", "description": "A fixture tactical pressure."}],
		[&"fixture"] as Array[StringName],
		"A fixture affinity explanation."
	)


func _baseline_registers_exactly_the_expected_ids() -> void:
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository()
	assert_true(repository != null, "The baseline repository must build.")
	assert_equal(repository.affinity_ids(), AffinityRepository.BASELINE_AFFINITY_IDS, "The baseline should register EXACTLY the expected ids in stable order.")


func _get_affinity_resolves_each_baseline() -> void:
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository()
	for affinity_id: StringName in AffinityRepository.BASELINE_AFFINITY_IDS:
		var definition: AffinityDefinition = repository.get_affinity(affinity_id)
		assert_true(definition != null, "Baseline affinity %s should resolve." % String(affinity_id))
		assert_equal(definition.affinity_id, affinity_id, "The resolved id should match the lookup id.")
		assert_true(definition.validate().succeeded, "Baseline affinity %s should validate." % String(affinity_id))


func _get_affinity_returns_null_on_a_miss() -> void:
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository()
	assert_true(repository.get_affinity(&"does_not_exist") == null, "get_affinity must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_affinity(&"") == null, "get_affinity must return null on an empty id (fail-closed).")


func _has_affinity_reflects_registration() -> void:
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository()
	assert_true(repository.has_affinity(AffinityRepository.BASELINE_AFFINITY_IDS[0]), "has_affinity should be true for a registered id.")
	assert_true(repository.has_affinity(&"none"), "has_affinity should be true for the registered neutral none.")
	assert_false(repository.has_affinity(&"does_not_exist"), "has_affinity should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository(content_repository)
	for affinity_id: StringName in AffinityRepository.BASELINE_AFFINITY_IDS:
		assert_true(
			content_repository.has_definition(AffinityDefinition.DEFINITION_TYPE, affinity_id),
			"Affinity %s should be registered through the generic content repository boundary." % String(affinity_id)
		)


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: AffinityDefinition = AffinityDefinition.new()
	var repository: AffinityRepository = AffinityRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "The factory should fail closed instead of returning partially registered content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var partial_repository: AffinityRepository = AffinityRepository.create_repository_from_definitions(
		[_valid(&"valid_one"), invalid_definition],
		shared_content_repository
	)
	assert_equal(partial_repository, null, "The factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(AffinityDefinition.DEFINITION_TYPE, &"valid_one"),
		"A failed repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository()
	assert_equal(AffinityRepository.BASELINE_AFFINITY_IDS, repository.affinity_ids(), "The BASELINE_AFFINITY_IDS constant should match the actually-registered ids.")


func _rejects_duplicate_id_fail_loud() -> void:
	var first: AffinityDefinition = _valid(&"dup_id")
	var duplicate: AffinityDefinition = _valid(&"dup_id")
	duplicate.display_name = "Distinct Duplicate"
	var repository: AffinityRepository = AffinityRepository.new()
	assert_true(repository.register_affinity(first).succeeded, "The first registration should succeed.")
	var duplicate_result: ActionResult = repository.register_affinity(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_affinity", "A duplicate id should use the stable duplicate_affinity code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "dup_id", "The duplicate error should carry the offending id.")
	assert_equal(repository.affinity_ids(), [&"dup_id"] as Array[StringName], "affinity_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_affinity(&"dup_id").display_name, "Fixture Affinity", "get_affinity must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: AffinityRepository = AffinityRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")


# ---- the AC3 neutral query surface ---------------------------------------------------------------

func _tactical_rules_for_neutral_returns_the_empty_set() -> void:
	# AC3: "When tactical systems query affinity rules Then they receive an empty or neutral rule set ... no affinity
	# side effects." The neutral none returns the EMPTY set.
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository()
	var rules: Array = repository.tactical_rules_for(&"none")
	assert_true(rules.is_empty(), "AC3: tactical_rules_for(&\"none\") must return an EMPTY rule set (no affinity side effects).")


func _tactical_rules_for_a_real_affinity_returns_its_rules() -> void:
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository()
	var scorched_rules: Array = repository.tactical_rules_for(&"scorched")
	assert_true(scorched_rules.size() >= 1, "tactical_rules_for(<real affinity>) must return its recorded rules.")
	# The recorded rule markers carry a lower_snake rule_id + a non-empty description (the RECORD-ONLY data contract).
	var first_rule: Dictionary = scorched_rules[0]
	assert_false(String(first_rule.get("rule_id")).is_empty(), "A recorded rule marker carries a rule_id.")
	assert_false(String(first_rule.get("description")).strip_edges().is_empty(), "A recorded rule marker carries a non-empty description.")


func _tactical_rules_for_an_unknown_id_fail_safes_to_empty() -> void:
	# AC3 demands the no-affinity case NOT crash. An unknown id fail-SAFEs to the empty/neutral set (lenient — the
	# validate-before-USE gate is the assignment's job).
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository()
	assert_true(repository.tactical_rules_for(&"does_not_exist").is_empty(), "AC3: tactical_rules_for(<unknown id>) must fail-safe to the EMPTY set (never crash).")
	assert_true(repository.tactical_rules_for(&"").is_empty(), "AC3: tactical_rules_for(<empty id>) must fail-safe to the EMPTY set.")


func _tactical_rules_for_is_a_pure_read() -> void:
	# tactical_rules_for returns a fresh deep copy — mutating it must not perturb the repository's stored rules.
	var repository: AffinityRepository = AffinityRepository.create_baseline_repository()
	var first: Array = repository.tactical_rules_for(&"scorched")
	var original_count: int = first.size()
	first.append({"rule_id": "intruder", "description": "Should not leak back."})
	var second: Array = repository.tactical_rules_for(&"scorched")
	assert_equal(second.size(), original_count, "Mutating a returned tactical_rules_for result must not change the stored rules (pure read).")
