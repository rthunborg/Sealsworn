extends "res://tests/unit/test_case.gd"

# Story 7.3 Task 1 — EventDefinition + EventChoiceDefinition (the typed, validated risk/reward EVENT content definition,
# AC1/AC2). Covers the AC1/AC2 event contract: a valid baseline passes validate(); each top-level per-field reject (bad
# event_id, blank display_name/prompt, empty choices, duplicate choice_id, the no-genuine-tradeoff reject); each
# per-CHOICE reject surfaced with the choice index (bad/blank choice_id, blank choice_text, negative ints, non-lower_snake
# risk flag, duplicate risk flag); and the at-least-one-genuine-tradeoff rule both ways. Mirrors
# test_cursed_reward_definition.gd (the typed-Resource validate() per-field shape).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const EventChoiceDefinition = preload("res://scripts/content/definitions/event_choice_definition.gd")
const EventDefinition = preload("res://scripts/content/definitions/event_definition.gd")
const EventRepository = preload("res://scripts/content/repositories/event_repository.gd")

func run() -> Dictionary:
	_baseline_definitions_validate()
	_a_valid_event_validates()
	_rejects_a_non_lower_snake_event_id()
	_rejects_a_blank_display_name()
	_rejects_a_blank_prompt()
	_rejects_an_empty_choices_list()
	_rejects_a_duplicate_choice_id()
	_rejects_a_no_genuine_tradeoff_event()
	_a_safe_decline_choice_is_valid_alongside_a_tradeoff()
	_rejects_per_choice_bad_choice_id()
	_rejects_per_choice_blank_choice_text()
	_rejects_per_choice_negative_ints()
	_rejects_per_choice_non_lower_snake_risk_flag()
	_rejects_per_choice_duplicate_risk_flag()
	_choice_classification_helpers_reflect_the_tradeoff()
	_get_choice_and_choice_ids_resolve()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A genuine-tradeoff choice (gold benefit + a raised risk flag).
func _tradeoff_choice() -> EventChoiceDefinition:
	return EventChoiceDefinition.new(
		&"take_the_gold",
		"Take the gold and accept the elites later.",
		30, 0, 0, 0, 0, 0, ["elite_chance"]
	)


# A safe decline choice (no reward, no risk, no flag).
func _safe_choice() -> EventChoiceDefinition:
	return EventChoiceDefinition.new(
		&"leave_it",
		"Leave it untouched.",
		0, 0, 0, 0, 0, 0, []
	)


# A genuine-tradeoff event with a tradeoff + a safe decline. Mutate one field per reject test.
func _valid_definition() -> EventDefinition:
	return EventDefinition.new(
		&"test_event",
		"Test Event",
		"You face a tempting choice with a known risk.",
		[_tradeoff_choice(), _safe_choice()]
	)


# ---- the baseline + a valid definition -----------------------------------------------------------

func _baseline_definitions_validate() -> void:
	var repo: EventRepository = EventRepository.create_baseline_repository()
	assert_true(repo != null, "The baseline event repository must build (every baseline validates).")
	for event_id: StringName in EventRepository.BASELINE_EVENT_IDS:
		var definition: EventDefinition = repo.get_event(event_id)
		assert_true(definition != null, "Baseline event %s must resolve." % String(event_id))
		assert_true(definition.validate().succeeded, "Baseline event %s must validate." % String(event_id))
		# Each baseline must offer at least one genuine tradeoff (the node is a real decision).
		var has_tradeoff: bool = false
		for choice: EventChoiceDefinition in definition.choices:
			if choice.is_genuine_tradeoff():
				has_tradeoff = true
		assert_true(has_tradeoff, "Baseline event %s must offer at least one genuine tradeoff." % String(event_id))


func _a_valid_event_validates() -> void:
	assert_true(_valid_definition().validate().succeeded, "A genuine-tradeoff event must validate.")


# ---- top-level per-field rejects -----------------------------------------------------------------

func _assert_invalid_field(definition: EventDefinition, expected_field: String, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.is_error(), "%s (must reject)." % message)
	assert_equal(validation.error_code, &"invalid_event_definition", "%s (stable code)." % message)
	assert_equal(String(validation.metadata.get("field")), expected_field, "%s (field in metadata)." % message)


func _rejects_a_non_lower_snake_event_id() -> void:
	var definition: EventDefinition = _valid_definition()
	definition.event_id = &"Bad-Id"
	_assert_invalid_field(definition, "event_id", "A non-lower_snake event_id")


func _rejects_a_blank_display_name() -> void:
	var definition: EventDefinition = _valid_definition()
	definition.display_name = "   "
	_assert_invalid_field(definition, "display_name", "A blank display_name")


func _rejects_a_blank_prompt() -> void:
	var definition: EventDefinition = _valid_definition()
	definition.prompt = ""
	_assert_invalid_field(definition, "prompt", "A blank prompt")


func _rejects_an_empty_choices_list() -> void:
	var definition: EventDefinition = EventDefinition.new(&"test_event", "Test Event", "A prompt.", [])
	_assert_invalid_field(definition, "choices", "An empty choices list")


func _rejects_a_duplicate_choice_id() -> void:
	var definition: EventDefinition = EventDefinition.new(
		&"test_event", "Test Event", "A prompt.",
		[_tradeoff_choice(), _tradeoff_choice()]  # same choice_id twice
	)
	var validation: ActionResult = definition.validate()
	assert_true(validation.is_error(), "A duplicate choice_id must reject.")
	assert_equal(validation.error_code, &"invalid_event_definition", "A duplicate choice_id uses the stable code.")
	assert_equal(String(validation.metadata.get("field")), "choice_id", "A duplicate choice_id names the choice_id field.")
	assert_equal(int(validation.metadata.get("choice_index")), 1, "A duplicate choice_id reports the offending choice index.")


func _rejects_a_no_genuine_tradeoff_event() -> void:
	# An event whose ONLY choice is a safe decline (no reward, no risk) is rejected — the node would be a free
	# nothing, not a tempting risk/reward decision (the load-bearing at-least-one-tradeoff rule).
	var definition: EventDefinition = EventDefinition.new(
		&"all_safe_event", "All Safe Event", "A prompt with no real decision.",
		[_safe_choice()]
	)
	_assert_invalid_field(definition, "choices", "A no-genuine-tradeoff event")

	# An event whose choices are all FREE rewards (a reward but no risk) is ALSO not a genuine tradeoff -> rejected.
	var free_reward: EventChoiceDefinition = EventChoiceDefinition.new(
		&"free_gold", "Take free gold.", 50, 0, 0, 0, 0, 0, []  # reward, no risk, no flag
	)
	var free_event: EventDefinition = EventDefinition.new(
		&"free_event", "Free Event", "A prompt.", [free_reward]
	)
	_assert_invalid_field(free_event, "choices", "A free-reward-only event (no risk)")


func _a_safe_decline_choice_is_valid_alongside_a_tradeoff() -> void:
	# A safe decline is a VALID additional option as long as the event ALSO offers a genuine tradeoff.
	var definition: EventDefinition = EventDefinition.new(
		&"mixed_event", "Mixed Event", "A prompt.",
		[_tradeoff_choice(), _safe_choice()]
	)
	assert_true(definition.validate().succeeded, "A safe decline is valid alongside a genuine tradeoff.")


# ---- per-CHOICE rejects (surfaced with the choice index) -----------------------------------------

func _assert_invalid_choice(definition: EventDefinition, expected_index: int, expected_field: String, message: String) -> void:
	var validation: ActionResult = definition.validate()
	assert_true(validation.is_error(), "%s (must reject)." % message)
	assert_equal(validation.error_code, &"invalid_event_definition", "%s (stable code)." % message)
	assert_equal(String(validation.metadata.get("reason")), "invalid_choice", "%s (reason invalid_choice)." % message)
	assert_equal(int(validation.metadata.get("choice_index")), expected_index, "%s (choice index)." % message)
	assert_equal(String(validation.metadata.get("field")), expected_field, "%s (field in metadata)." % message)


func _rejects_per_choice_bad_choice_id() -> void:
	var bad: EventChoiceDefinition = _tradeoff_choice()
	bad.choice_id = &"Bad-Choice"
	var definition: EventDefinition = EventDefinition.new(&"test_event", "Test Event", "A prompt.", [bad])
	_assert_invalid_choice(definition, 0, "choice_id", "A non-lower_snake choice_id")


func _rejects_per_choice_blank_choice_text() -> void:
	var bad: EventChoiceDefinition = _tradeoff_choice()
	bad.choice_text = "   "
	var definition: EventDefinition = EventDefinition.new(&"test_event", "Test Event", "A prompt.", [bad])
	_assert_invalid_choice(definition, 0, "choice_text", "A blank choice_text")


func _rejects_per_choice_negative_ints() -> void:
	for field_name: String in ["gold_benefit", "healing_benefit", "curse_increment", "corruption_increment", "gold_cost", "healing_cost"]:
		var bad: EventChoiceDefinition = _tradeoff_choice()
		bad.set(field_name, -1)
		var definition: EventDefinition = EventDefinition.new(&"test_event", "Test Event", "A prompt.", [bad, _safe_choice()])
		_assert_invalid_choice(definition, 0, field_name, "A negative %s" % field_name)


func _rejects_per_choice_non_lower_snake_risk_flag() -> void:
	var bad: EventChoiceDefinition = EventChoiceDefinition.new(
		&"flagged", "A flagged choice.", 10, 0, 0, 0, 0, 0, ["Elite-Chance"]
	)
	var definition: EventDefinition = EventDefinition.new(&"test_event", "Test Event", "A prompt.", [bad])
	_assert_invalid_choice(definition, 0, "risk_flags", "A non-lower_snake risk flag")


func _rejects_per_choice_duplicate_risk_flag() -> void:
	var bad: EventChoiceDefinition = EventChoiceDefinition.new(
		&"flagged", "A flagged choice.", 10, 0, 0, 0, 0, 0, ["elite_chance", "elite_chance"]
	)
	var definition: EventDefinition = EventDefinition.new(&"test_event", "Test Event", "A prompt.", [bad])
	_assert_invalid_choice(definition, 0, "risk_flags", "A duplicate risk flag")


# ---- choice classification helpers ---------------------------------------------------------------

func _choice_classification_helpers_reflect_the_tradeoff() -> void:
	var tradeoff: EventChoiceDefinition = _tradeoff_choice()
	assert_true(tradeoff.has_reward(), "A gold-benefit choice has a reward.")
	assert_true(tradeoff.has_risk(), "A flag-raising choice has a risk.")
	assert_true(tradeoff.is_genuine_tradeoff(), "A reward + a raised flag is a genuine tradeoff.")
	assert_false(tradeoff.is_safe(), "A tradeoff choice is not safe.")
	assert_false(tradeoff.applies_curse(), "A flag-only choice applies no curse.")

	var safe: EventChoiceDefinition = _safe_choice()
	assert_false(safe.has_reward(), "A safe choice has no reward.")
	assert_false(safe.has_risk(), "A safe choice has no risk.")
	assert_false(safe.is_genuine_tradeoff(), "A safe choice is not a genuine tradeoff.")
	assert_true(safe.is_safe(), "A no-reward-no-risk choice is safe.")

	# A curse-increment choice applies a curse.
	var cursed: EventChoiceDefinition = EventChoiceDefinition.new(&"cursed", "A cursed choice.", 10, 0, 1, 0, 0, 0, [])
	assert_true(cursed.applies_curse(), "A curse_increment choice applies a curse.")
	assert_true(cursed.is_genuine_tradeoff(), "A reward + a curse increment is a genuine tradeoff.")

	# A resource-cost-only risk (a benefit + a gold cost, no flag, no curse) is still a genuine tradeoff.
	var cost: EventChoiceDefinition = EventChoiceDefinition.new(&"cost", "A cost choice.", 0, 5, 0, 0, 3, 0, [])
	assert_true(cost.is_genuine_tradeoff(), "A healing benefit + a gold cost is a genuine tradeoff.")
	assert_false(cost.applies_curse(), "A cost-only risk applies no curse.")


func _get_choice_and_choice_ids_resolve() -> void:
	var definition: EventDefinition = _valid_definition()
	assert_true(definition.get_choice(&"take_the_gold") != null, "get_choice resolves an offered choice id.")
	assert_true(definition.get_choice(&"does_not_exist") == null, "get_choice returns null on a miss.")
	assert_equal(definition.choice_ids(), [&"take_the_gold", &"leave_it"] as Array[StringName], "choice_ids returns the ordered choice ids.")
