extends "res://tests/unit/test_case.gd"

# Story 5.4 — PassiveRepository (the fail-closed passive content repository, AC1/AC3).
#
# Pins: the baseline registers EXACTLY the six starting-passive ids the 5.1 selectable classes reference, in
# stable order; get_passive(id) resolves each baseline + returns null on a miss (fail-closed); has_passive;
# passive_ids order; registration goes through the generic ContentRepository boundary;
# create_repository_from_definitions fails closed on a bad def (and does not mutate a provided content
# repository). No duplicate ids are registered (the duplicate-id trap stays untriggered).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")

# The six baseline starting-passive ids the three selectable classes reference (the 5.1 class baselines), with
# their expected kind. A drift here (a renamed/missing id) would fail-closed a class start.
const EXPECTED_PASSIVES: Dictionary = {
	&"warrior_unbreakable_guard": PassiveDefinition.KIND_CLASS,
	&"warrior_blade_and_board": PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
	&"pyromancer_kindling_focus": PassiveDefinition.KIND_CLASS,
	&"pyromancer_arcane_conduit": PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
	&"ranger_steady_aim": PassiveDefinition.KIND_CLASS,
	&"ranger_hunters_quiver": PassiveDefinition.KIND_EQUIPMENT_SYNERGY
}

func run() -> Dictionary:
	_baseline_registers_exactly_the_six_starting_passives()
	_get_passive_resolves_each_baseline_and_exposes_correct_kind()
	_get_passive_returns_null_on_a_miss()
	_has_passive_reflects_registration()
	_repository_keeps_generic_content_registration_intact()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_passive_ids_constant_matches_registered_ids()
	return result()


func _baseline_registers_exactly_the_six_starting_passives() -> void:
	var repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	var actual_ids: Array[StringName] = repository.passive_ids()
	assert_equal(actual_ids, EXPECTED_PASSIVES.keys(), "The baseline should register EXACTLY the six starting-passive ids in stable order.")
	assert_equal(actual_ids.size(), 6, "The baseline starting-passive set is exactly six (FR44: two per selectable class).")


func _get_passive_resolves_each_baseline_and_exposes_correct_kind() -> void:
	var repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	for passive_id: StringName in EXPECTED_PASSIVES.keys():
		var definition: PassiveDefinition = repository.get_passive(passive_id)
		assert_true(definition != null, "Baseline passive %s should resolve through the repository." % String(passive_id))
		assert_equal(definition.passive_id, passive_id, "The resolved passive's id should match the lookup id.")
		assert_equal(definition.passive_kind, EXPECTED_PASSIVES[passive_id], "Passive %s should expose its expected kind." % String(passive_id))
		assert_true(definition.validate().succeeded, "Baseline passive %s should validate." % String(passive_id))
		# Each baseline declares at least one valid trigger window (the explicit-window AC1 demands).
		assert_false(definition.trigger_windows.is_empty(), "Baseline passive %s should declare at least one trigger window." % String(passive_id))
		for window_id: StringName in definition.trigger_windows:
			assert_true(RuleTrigger.is_valid_window(window_id), "Baseline passive %s window %s must be in the fixed vocabulary." % [String(passive_id), String(window_id)])


func _get_passive_returns_null_on_a_miss() -> void:
	var repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	assert_true(repository.get_passive(&"does_not_exist") == null, "get_passive must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_passive(&"") == null, "get_passive must return null on an empty id (fail-closed).")


func _has_passive_reflects_registration() -> void:
	var repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	assert_true(repository.has_passive(&"warrior_unbreakable_guard"), "has_passive should be true for a registered id.")
	assert_false(repository.has_passive(&"does_not_exist"), "has_passive should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: PassiveRepository = PassiveRepository.create_baseline_repository(content_repository)
	for passive_id: StringName in EXPECTED_PASSIVES.keys():
		assert_true(
			content_repository.has_definition(PassiveDefinition.DEFINITION_TYPE, passive_id),
			"Passive %s should be registered through the generic content repository boundary." % String(passive_id)
		)
		assert_equal(
			content_repository.get_definition(PassiveDefinition.DEFINITION_TYPE, passive_id),
			repository.get_passive(passive_id),
			"Passive %s should not require direct gameplay file access." % String(passive_id)
		)


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: PassiveDefinition = PassiveDefinition.new()
	var repository: PassiveRepository = PassiveRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "The factory should fail closed instead of returning partially registered passive content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: PassiveDefinition = PassiveDefinition.new(
		&"warrior_unbreakable_guard",
		"Unbreakable Guard",
		PassiveDefinition.KIND_CLASS,
		[RuleTrigger.BEFORE_ATTACK],
		"Unbreakable Guard steels the hero before an incoming attack."
	)
	var partial_repository: PassiveRepository = PassiveRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition],
		shared_content_repository
	)
	assert_equal(partial_repository, null, "The factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(PassiveDefinition.DEFINITION_TYPE, &"warrior_unbreakable_guard"),
		"A failed passive repository creation must not mutate a provided content repository."
	)


func _baseline_passive_ids_constant_matches_registered_ids() -> void:
	var repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	assert_equal(PassiveRepository.BASELINE_PASSIVE_IDS, repository.passive_ids(), "The BASELINE_PASSIVE_IDS constant should match the actually-registered ids.")
