extends "res://tests/unit/test_case.gd"

# Story 9.2 Task 2 + Task 6 cross-check — BossRepository (the fail-closed Larval Avatar content repository, AC1).
# Mirrors test_event_repository.gd: the baseline registers exactly BASELINE_BOSS_IDS in stable order; get_boss(id)
# resolves the baseline + validates it + returns null on a miss (fail-closed); has_boss; the registration goes through
# the generic ContentRepository boundary; create_repository_from_definitions fails closed on a bad def (and does not
# mutate a provided content repository); the all-repos duplicate-id fail-loud guard (duplicate_boss). Task-6 cross-check:
# the registered boss id == BossEncounterRequest.BOSS_ENTITY_ID == the 9.1 arena boss_slot.entity_id ("larval_avatar")
# so 9.2 fills the SAME slot 9.1 reserved.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const BossActionDefinition = preload("res://scripts/content/definitions/boss_action_definition.gd")
const BossPhaseDefinition = preload("res://scripts/content/definitions/boss_phase_definition.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossRepository = preload("res://scripts/content/repositories/boss_repository.gd")
const BossEncounterRequest = preload("res://scripts/generation/boss/boss_encounter_request.gd")
const BossArenaBuilder = preload("res://scripts/generation/boss/boss_arena_builder.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")

func run() -> Dictionary:
	_baseline_registers_exactly_the_expected_ids()
	_get_boss_resolves_the_baseline()
	_get_boss_returns_null_on_a_miss()
	_has_boss_reflects_registration()
	_repository_keeps_generic_content_registration_intact()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_rejects_duplicate_id_fail_loud()
	_baseline_boss_id_matches_the_9_1_slot()
	return result()


# A fully valid two-phase boss for fixtures that must PASS validate() (distinct id for duplicate tests).
func _valid(boss_id: StringName) -> BossDefinition:
	return BossDefinition.new(
		boss_id,
		20,
		[
			BossPhaseDefinition.new(&"open", 100, [BossActionDefinition.new(&"strike", "Telegraph.", 5, &"physical", "Strikes.")], "Opening phase."),
			BossPhaseDefinition.new(&"close", 40, [BossActionDefinition.new(&"strike", "Telegraph.", 7, &"physical", "Strikes harder.")], "Closing phase.")
		],
		"A fixture boss."
	)


func _baseline_registers_exactly_the_expected_ids() -> void:
	var repository: BossRepository = BossRepository.create_baseline_repository()
	assert_true(repository != null, "The baseline repository must build.")
	assert_equal(repository.boss_ids(), BossRepository.BASELINE_BOSS_IDS, "The baseline should register EXACTLY the expected ids in stable order.")


func _get_boss_resolves_the_baseline() -> void:
	var repository: BossRepository = BossRepository.create_baseline_repository()
	for boss_id: StringName in BossRepository.BASELINE_BOSS_IDS:
		var definition: BossDefinition = repository.get_boss(boss_id)
		assert_true(definition != null, "Baseline boss %s should resolve." % String(boss_id))
		assert_equal(definition.boss_id, boss_id, "The resolved id should match the lookup id.")
		assert_true(definition.validate().succeeded, "Baseline boss %s should validate." % String(boss_id))
		assert_true(definition.phase_count() >= 2, "The baseline boss should have >= 2 phases (a readable escalation).")


func _get_boss_returns_null_on_a_miss() -> void:
	var repository: BossRepository = BossRepository.create_baseline_repository()
	assert_true(repository.get_boss(&"does_not_exist") == null, "get_boss must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_boss(&"") == null, "get_boss must return null on an empty id (fail-closed).")


func _has_boss_reflects_registration() -> void:
	var repository: BossRepository = BossRepository.create_baseline_repository()
	assert_true(repository.has_boss(BossRepository.BASELINE_BOSS_IDS[0]), "has_boss should be true for a registered id.")
	assert_false(repository.has_boss(&"does_not_exist"), "has_boss should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: BossRepository = BossRepository.create_baseline_repository(content_repository)
	for boss_id: StringName in BossRepository.BASELINE_BOSS_IDS:
		assert_true(
			content_repository.has_definition(BossDefinition.DEFINITION_TYPE, boss_id),
			"Boss %s should be registered through the generic content repository boundary." % String(boss_id)
		)


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: BossDefinition = BossDefinition.new()
	var repository: BossRepository = BossRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "The factory should fail closed instead of returning partially registered content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var partial_repository: BossRepository = BossRepository.create_repository_from_definitions(
		[_valid(&"valid_one"), invalid_definition],
		shared_content_repository
	)
	assert_equal(partial_repository, null, "The factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(BossDefinition.DEFINITION_TYPE, &"valid_one"),
		"A failed repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: BossRepository = BossRepository.create_baseline_repository()
	assert_equal(BossRepository.BASELINE_BOSS_IDS, repository.boss_ids(), "The BASELINE_BOSS_IDS constant should match the actually-registered ids.")


func _rejects_duplicate_id_fail_loud() -> void:
	var first: BossDefinition = _valid(&"dup_boss")
	var duplicate: BossDefinition = _valid(&"dup_boss")
	duplicate.explanation = "Distinct duplicate."
	var repository: BossRepository = BossRepository.new()
	assert_true(repository.register_boss(first).succeeded, "The first registration should succeed.")
	var duplicate_result: ActionResult = repository.register_boss(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_boss", "A duplicate id should use the stable duplicate_boss code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "dup_boss", "The duplicate error should carry the offending id.")
	assert_equal(repository.boss_ids(), [&"dup_boss"] as Array[StringName], "boss_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_boss(&"dup_boss").explanation, "A fixture boss.", "get_boss must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: BossRepository = BossRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")


# Task 6 cross-check: 9.2 fills the SAME boss-entity slot Story 9.1 reserved. The baseline boss id must equal the
# BossEncounterRequest.BOSS_ENTITY_ID constant AND the arena payload's boss_slot.entity_id (both == "larval_avatar").
func _baseline_boss_id_matches_the_9_1_slot() -> void:
	assert_equal(BossDefinition.BOSS_ID, BossEncounterRequest.BOSS_ENTITY_ID, "The boss definition id must equal the 9.1 reserved slot id.")
	assert_equal(BossRepository.BASELINE_BOSS_IDS[0], BossEncounterRequest.BOSS_ENTITY_ID, "The registered baseline boss id must equal the 9.1 slot id.")

	# The arena payload's boss_slot.entity_id (the actual reserved slot marker) must equal the definition id we fill.
	var request: BossEncounterRequest = BossEncounterRequest.new(4242, &"node_7_0")
	var arena_result: GenerationResult = BossArenaBuilder.new().build(request)
	assert_true(arena_result.succeeded, "The 9.1 arena build should succeed for the cross-check.")
	var boss_slot: Dictionary = arena_result.payload.get("boss_slot", {})
	assert_equal(String(boss_slot.get("entity_id")), String(BossDefinition.BOSS_ID), "The definition fills the arena boss_slot.entity_id.")
	assert_true(bool(boss_slot.get("is_placeholder")), "The 9.1 slot is still marked is_placeholder (9.2 supplies the definition, not a live board entity).")
