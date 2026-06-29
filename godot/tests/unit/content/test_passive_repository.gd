extends "res://tests/unit/test_case.gd"

# Story 5.4 — PassiveRepository (the fail-closed passive content repository, AC1/AC3).
#
# Pins: the baseline registers EXACTLY the six starting-passive ids the 5.1 selectable classes reference, in
# stable order; get_passive(id) resolves each baseline + returns null on a miss (fail-closed); has_passive;
# passive_ids order; registration goes through the generic ContentRepository boundary;
# create_repository_from_definitions fails closed on a bad def (and does not mutate a provided content
# repository). Story 6.1 AC6: a duplicate passive id now fails loud (duplicate_passive) — pinned below.

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
	_passive_repository_rejects_duplicate_id_fail_loud()
	# Story 6.4 — the six baselines stay VALID + loadable after the tightened validation, each carrying the new
	# FR47 modal fields + >=1 served pillar; and the AC3 enforcement proof (an invalid passive cannot register).
	_baseline_repository_builds_with_the_extended_validation()
	_each_baseline_carries_the_modal_fields_and_a_served_pillar()
	_an_invalid_extended_passive_cannot_register()
	return result()


# Story 6.4 — a helper building a FULLY VALID extended passive (all the FR47 modal fields + a served pillar)
# so a fixture that needs to PASS the tightened validation (e.g. the duplicate-id guard, which validates
# before checking the duplicate) does not trip the new required fields.
func _valid_passive(passive_id: StringName, display_name: String, kind: StringName, window: StringName, explanation: String) -> PassiveDefinition:
	return PassiveDefinition.new(
		passive_id, display_name, kind, [window], explanation,
		PassiveDefinition.ICON_PLACEHOLDER,
		"A test flavor line.",
		"A test explicit mechanics line.",
		"Consume test text.",
		"Destroy test text.",
		false,
		"No hidden cost.",
		[PassiveDefinition.PILLAR_TACTICAL_CLARITY]
	)


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
	var valid_definition: PassiveDefinition = _valid_passive(&"warrior_unbreakable_guard", "Unbreakable Guard", PassiveDefinition.KIND_CLASS, RuleTrigger.BEFORE_ATTACK, "Unbreakable Guard steels the hero before an incoming attack.")
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


# Story 6.1 AC6 — a SECOND registration under an already-present passive id fails loud with a structured
# duplicate_passive error, leaving passive_ids() + get_passive consistent (closes the carried Epic-5
# cross-cutting [Review][Defer] for this repo). A duplicate in a batch fails closed.
func _passive_repository_rejects_duplicate_id_fail_loud() -> void:
	var first: PassiveDefinition = _valid_passive(&"warrior_unbreakable_guard", "Unbreakable Guard", PassiveDefinition.KIND_CLASS, RuleTrigger.BEFORE_ATTACK, "First definition.")
	var duplicate: PassiveDefinition = _valid_passive(&"warrior_unbreakable_guard", "Distinct Duplicate", PassiveDefinition.KIND_EQUIPMENT_SYNERGY, RuleTrigger.RUN_STARTED, "Distinct second definition under the same id.")
	var repository: PassiveRepository = PassiveRepository.new()
	assert_true(repository.register_passive(first).succeeded, "The first passive registration should succeed.")
	var duplicate_result: ActionResult = repository.register_passive(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same passive id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_passive", "A duplicate id should use the stable duplicate_passive code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "warrior_unbreakable_guard", "The duplicate error should carry the offending id.")
	assert_equal(repository.passive_ids(), [&"warrior_unbreakable_guard"] as Array[StringName], "passive_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_passive(&"warrior_unbreakable_guard").display_name, "Unbreakable Guard", "get_passive must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: PassiveRepository = PassiveRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")


# ---- Story 6.4: the extended baselines stay loadable + the AC3 fail-closed-load proof ----------------

# The LOAD-BEARING regression: with PassiveDefinition.validate() tightened (the FR47 modal fields + the FR77
# served pillar), create_baseline_repository() must STILL be non-null — i.e. every baseline passive was
# extended with the new required fields. If a baseline is missing a new field the whole baseline repo returns
# null and the class-start + reward-table paths break.
func _baseline_repository_builds_with_the_extended_validation() -> void:
	var repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	assert_true(repository != null, "create_baseline_repository() must stay non-null after the tightened validation (every baseline carries the new fields).")
	assert_equal(repository.passive_ids().size(), 6, "All six baseline passives must still register.")


# Each baseline passive resolves through get_passive(id) carrying non-empty FR47 modal fields + a consistent
# honest-unknown contract + at least one allowlisted served pillar (the FR77 pillar gate).
func _each_baseline_carries_the_modal_fields_and_a_served_pillar() -> void:
	var repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	for passive_id: StringName in EXPECTED_PASSIVES.keys():
		var definition: PassiveDefinition = repository.get_passive(passive_id)
		assert_true(definition != null, "Baseline passive %s should resolve." % String(passive_id))
		assert_false(String(definition.icon).strip_edges().is_empty(), "Baseline passive %s should carry a non-empty icon id." % String(passive_id))
		assert_false(definition.flavor.strip_edges().is_empty(), "Baseline passive %s should carry a flavor line." % String(passive_id))
		assert_false(definition.exact_mechanical_effects.strip_edges().is_empty(), "Baseline passive %s should carry an explicit mechanics string." % String(passive_id))
		assert_false(definition.consume_text.strip_edges().is_empty(), "Baseline passive %s should carry Consume text." % String(passive_id))
		assert_false(definition.destroy_text.strip_edges().is_empty(), "Baseline passive %s should carry Destroy text." % String(passive_id))
		assert_false(definition.consequences_text.strip_edges().is_empty(), "Baseline passive %s should carry a consequences line (known or honest-unknown)." % String(passive_id))
		assert_false(definition.served_pillars.is_empty(), "Baseline passive %s should serve at least one pillar." % String(passive_id))
		for pillar: StringName in definition.served_pillars:
			assert_true(PassiveDefinition.SERVED_PILLARS.has(pillar), "Baseline passive %s pillar %s must be in the fixed allowlist." % [String(passive_id), String(pillar)])


# AC3 enforcement proof: a PassiveDefinition that fails the TIGHTENED validate() (here: missing the new modal
# fields + pillar) is REJECTED at repository load — it can never be a registered passive a `passive`
# reward-table entry resolves to. A definition built with ONLY the Story-5.4 args (no modal fields, no pillar)
# now fails the extended validation, so the factory fails closed.
func _an_invalid_extended_passive_cannot_register() -> void:
	var pre_extension_passive: PassiveDefinition = PassiveDefinition.new(
		&"legacy_shaped_passive",
		"Legacy Shaped",
		PassiveDefinition.KIND_CLASS,
		[RuleTrigger.BEFORE_ATTACK],
		"A passive missing the Story-6.4 modal fields + served pillar."
	)
	assert_true(pre_extension_passive.validate().is_error(), "A passive missing the new required modal/pillar fields must fail the tightened validation.")
	var repository: PassiveRepository = PassiveRepository.create_repository_from_definitions([pre_extension_passive])
	assert_equal(repository, null, "A passive that fails the tightened validation cannot register (fail-closed load — AC3).")
