extends "res://tests/unit/test_case.gd"

# Story 7.3 Task 7 — EventViewModel (the scene-free risk/reward EVENT read surface, AC1). Mirrors
# test_cursed_reward_view_model.gd: the view model surfaces the prompt + each choice's text + reward/risk amounts +
# raised flags from a validated EventDefinition; the projection exposes EXACTLY the pinned MODAL_KEYS / CHOICE_KEYS; an
# unresolved id projects the identity-absent modal (fail-closed); and it is a PURE read (building it twice from the same
# definition yields identical data; it mutates nothing).

const EventChoiceDefinition = preload("res://scripts/content/definitions/event_choice_definition.gd")
const EventDefinition = preload("res://scripts/content/definitions/event_definition.gd")
const EventRepository = preload("res://scripts/content/repositories/event_repository.gd")
const EventViewModel = preload("res://scripts/ui/view_models/event_view_model.gd")

func run() -> Dictionary:
	_projects_the_baseline_event_with_the_exact_keys()
	_surfaces_each_choices_reward_risk_and_flags()
	_unresolved_id_projects_the_identity_absent_modal()
	_is_a_pure_read()
	return result()


func _fixture_repository() -> EventRepository:
	return EventRepository.create_repository_from_definitions([
		EventDefinition.new(
			&"view_event", "View Event", "A readable prompt the player faces.",
			[
				EventChoiceDefinition.new(&"take", "Take the risk and raise a flag.", 25, 0, 0, 0, 0, 0, ["elite_chance"]),
				EventChoiceDefinition.new(&"leave", "Leave it.", 0, 0, 0, 0, 0, 0, [])
			]
		)
	])


func _vm() -> EventViewModel:
	return EventViewModel.new(_fixture_repository())


func _projects_the_baseline_event_with_the_exact_keys() -> void:
	# The baseline view model (no injection) projects every baseline event with the exact MODAL_KEYS.
	var baseline_vm: EventViewModel = EventViewModel.new()
	for event_id: StringName in EventRepository.BASELINE_EVENT_IDS:
		var modal: Dictionary = baseline_vm.project_event(event_id)
		assert_equal(modal.keys().size(), EventViewModel.MODAL_KEYS.size(), "The projection must expose exactly the pinned MODAL_KEYS count for %s." % String(event_id))
		for key: String in EventViewModel.MODAL_KEYS:
			assert_true(modal.has(key), "The projection of %s must carry the pinned key '%s'." % [String(event_id), key])
		assert_true(bool(modal.get("has_event")), "A resolved event projects has_event == true.")
		assert_true((modal.get("choices") as Array).size() >= 1, "A resolved event surfaces at least one choice.")
		# Each choice carries the exact CHOICE_KEYS.
		for choice_value: Variant in (modal.get("choices") as Array):
			var choice: Dictionary = choice_value
			assert_equal(choice.keys().size(), EventViewModel.CHOICE_KEYS.size(), "Each choice must expose exactly the pinned CHOICE_KEYS count.")
			for choice_key: String in EventViewModel.CHOICE_KEYS:
				assert_true(choice.has(choice_key), "Each choice must carry the pinned key '%s'." % choice_key)


func _surfaces_each_choices_reward_risk_and_flags() -> void:
	var modal: Dictionary = _vm().project_event(&"view_event")
	assert_true(bool(modal.get("has_event")), "The fixture event resolves.")
	assert_equal(String(modal.get("prompt")), "A readable prompt the player faces.", "The view model surfaces the prompt.")
	var choices: Array = modal.get("choices")
	assert_equal(choices.size(), 2, "The view model surfaces both choices.")
	# The tradeoff choice: the reward amounts + the raised flag + is_genuine_tradeoff.
	var take: Dictionary = choices[0]
	assert_equal(String(take.get("choice_text")), "Take the risk and raise a flag.", "The view model surfaces the choice text.")
	assert_equal(int(take.get("gold_benefit")), 25, "The view model surfaces the concrete reward amount.")
	assert_equal((take.get("risk_flags") as Array), ["elite_chance"], "The view model surfaces the raised risk-flag ids honestly BEFORE choosing.")
	assert_true(bool(take.get("is_genuine_tradeoff")), "The tradeoff choice is flagged as a genuine tradeoff.")
	assert_false(bool(take.get("is_safe")), "The tradeoff choice is not safe.")
	# The safe choice.
	var leave: Dictionary = choices[1]
	assert_true(bool(leave.get("is_safe")), "The decline choice is flagged as safe.")
	assert_false(bool(leave.get("is_genuine_tradeoff")), "The decline choice is not a genuine tradeoff.")


func _unresolved_id_projects_the_identity_absent_modal() -> void:
	var modal: Dictionary = _vm().project_event(&"does_not_exist")
	assert_equal(modal.keys().size(), EventViewModel.MODAL_KEYS.size(), "The identity-absent modal exposes the SAME MODAL_KEYS set.")
	assert_false(bool(modal.get("has_event")), "An unresolved id projects has_event == false (fail-closed).")
	assert_equal(String(modal.get("event_id")), "", "The identity-absent modal has an empty event id.")
	assert_equal((modal.get("choices") as Array).size(), 0, "The identity-absent modal has an empty choices list.")


func _is_a_pure_read() -> void:
	# Building the projection twice from the same definition yields identical data (no mutation, no RNG).
	var vm: EventViewModel = _vm()
	var first: Dictionary = vm.project_event(&"view_event")
	var second: Dictionary = vm.project_event(&"view_event")
	assert_equal(JSON.stringify(first), JSON.stringify(second), "Projecting the same event twice yields identical data (a pure read).")
