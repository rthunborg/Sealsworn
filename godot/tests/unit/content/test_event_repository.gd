extends "res://tests/unit/test_case.gd"

# Story 7.3 Task 2 — EventRepository (the fail-closed risk/reward-EVENT content repository). Mirrors
# test_cursed_reward_repository.gd: the baseline registers exactly the BASELINE_EVENT_IDS in stable order;
# get_event(id) resolves each baseline + returns null on a miss (fail-closed); has_event; the registration goes through
# the generic ContentRepository boundary; create_repository_from_definitions fails closed on a bad def (and does not
# mutate a provided content repository); and the all-repos duplicate-id fail-loud guard (duplicate_event).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const EventChoiceDefinition = preload("res://scripts/content/definitions/event_choice_definition.gd")
const EventDefinition = preload("res://scripts/content/definitions/event_definition.gd")
const EventRepository = preload("res://scripts/content/repositories/event_repository.gd")

func run() -> Dictionary:
	_baseline_registers_exactly_the_expected_ids()
	_get_event_resolves_each_baseline()
	_get_event_returns_null_on_a_miss()
	_has_event_reflects_registration()
	_repository_keeps_generic_content_registration_intact()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_rejects_duplicate_id_fail_loud()
	return result()


# A fully valid event (a genuine tradeoff + a safe decline) for fixtures that must PASS validate().
func _valid(event_id: StringName) -> EventDefinition:
	return EventDefinition.new(
		event_id,
		"Fixture Event",
		"A fixture prompt.",
		[
			EventChoiceDefinition.new(&"take", "Take the risk.", 10, 0, 0, 0, 0, 0, ["a_flag"]),
			EventChoiceDefinition.new(&"leave", "Leave it.", 0, 0, 0, 0, 0, 0, [])
		]
	)


func _baseline_registers_exactly_the_expected_ids() -> void:
	var repository: EventRepository = EventRepository.create_baseline_repository()
	assert_true(repository != null, "The baseline repository must build.")
	assert_equal(repository.event_ids(), EventRepository.BASELINE_EVENT_IDS, "The baseline should register EXACTLY the expected ids in stable order.")


func _get_event_resolves_each_baseline() -> void:
	var repository: EventRepository = EventRepository.create_baseline_repository()
	for event_id: StringName in EventRepository.BASELINE_EVENT_IDS:
		var definition: EventDefinition = repository.get_event(event_id)
		assert_true(definition != null, "Baseline event %s should resolve." % String(event_id))
		assert_equal(definition.event_id, event_id, "The resolved id should match the lookup id.")
		assert_true(definition.validate().succeeded, "Baseline event %s should validate." % String(event_id))


func _get_event_returns_null_on_a_miss() -> void:
	var repository: EventRepository = EventRepository.create_baseline_repository()
	assert_true(repository.get_event(&"does_not_exist") == null, "get_event must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_event(&"") == null, "get_event must return null on an empty id (fail-closed).")


func _has_event_reflects_registration() -> void:
	var repository: EventRepository = EventRepository.create_baseline_repository()
	assert_true(repository.has_event(EventRepository.BASELINE_EVENT_IDS[0]), "has_event should be true for a registered id.")
	assert_false(repository.has_event(&"does_not_exist"), "has_event should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: EventRepository = EventRepository.create_baseline_repository(content_repository)
	for event_id: StringName in EventRepository.BASELINE_EVENT_IDS:
		assert_true(
			content_repository.has_definition(EventDefinition.DEFINITION_TYPE, event_id),
			"Event %s should be registered through the generic content repository boundary." % String(event_id)
		)


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: EventDefinition = EventDefinition.new()
	var repository: EventRepository = EventRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "The factory should fail closed instead of returning partially registered content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var partial_repository: EventRepository = EventRepository.create_repository_from_definitions(
		[_valid(&"valid_one"), invalid_definition],
		shared_content_repository
	)
	assert_equal(partial_repository, null, "The factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(EventDefinition.DEFINITION_TYPE, &"valid_one"),
		"A failed repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: EventRepository = EventRepository.create_baseline_repository()
	assert_equal(EventRepository.BASELINE_EVENT_IDS, repository.event_ids(), "The BASELINE_EVENT_IDS constant should match the actually-registered ids.")


func _rejects_duplicate_id_fail_loud() -> void:
	var first: EventDefinition = _valid(&"dup_id")
	var duplicate: EventDefinition = _valid(&"dup_id")
	duplicate.display_name = "Distinct Duplicate"
	var repository: EventRepository = EventRepository.new()
	assert_true(repository.register_event(first).succeeded, "The first registration should succeed.")
	var duplicate_result: ActionResult = repository.register_event(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_event", "A duplicate id should use the stable duplicate_event code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "dup_id", "The duplicate error should carry the offending id.")
	assert_equal(repository.event_ids(), [&"dup_id"] as Array[StringName], "event_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_event(&"dup_id").display_name, "Fixture Event", "get_event must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: EventRepository = EventRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")
