extends "res://tests/unit/test_case.gd"

# Story 5.4 — RulesResolver (the minimal STARTING-passive rules-kernel resolver, AC1/AC2/AC3).
#
# Pins: registering passives + resolving a trigger window returns the matching registered passives in STABLE
# registration order; an unregistered/non-matching window returns empty; explain(window) surfaces each
# matching passive's explanation in the same stable order; same registration + same window -> byte-identical
# output (determinism); the resolver holds ONLY passive definitions and exposes no active-skill activation
# (AC3). Builds the two warrior starting passives directly (the resolver is content-agnostic; it does not need
# a RunStartCommand).

const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")

func run() -> Dictionary:
	_resolve_returns_matching_passives_in_registration_order()
	_resolve_unregistered_window_returns_empty()
	_explain_surfaces_explanations_in_stable_order()
	_resolution_is_deterministic_for_same_registration_and_window()
	_registered_passive_ids_are_in_registration_order()
	_resolver_holds_only_passives_and_exposes_no_active_skill()
	_register_null_passive_is_ignored()
	return result()


# The warrior class passive (before_attack) + the warrior equipment-synergy passive (run_started).
func _warrior_class_passive() -> PassiveDefinition:
	return PassiveDefinition.new(
		&"warrior_unbreakable_guard",
		"Unbreakable Guard",
		PassiveDefinition.KIND_CLASS,
		[RuleTrigger.BEFORE_ATTACK],
		"Unbreakable Guard steels the hero before an incoming attack."
	)


func _warrior_equip_passive() -> PassiveDefinition:
	return PassiveDefinition.new(
		&"warrior_blade_and_board",
		"Blade and Board",
		PassiveDefinition.KIND_EQUIPMENT_SYNERGY,
		[RuleTrigger.RUN_STARTED],
		"Blade and Board pairs sword and shield as the run begins."
	)


func _warrior_resolver() -> RulesResolver:
	var resolver: RulesResolver = RulesResolver.new()
	resolver.register_passive(_warrior_class_passive())
	resolver.register_passive(_warrior_equip_passive())
	return resolver


func _resolve_returns_matching_passives_in_registration_order() -> void:
	var resolver: RulesResolver = _warrior_resolver()
	# before_attack -> only the class passive.
	var before_attack: Array[PassiveDefinition] = resolver.resolve(RuleTrigger.BEFORE_ATTACK)
	assert_equal(before_attack.size(), 1, "before_attack should resolve exactly the one class passive.")
	assert_equal(before_attack[0].passive_id, &"warrior_unbreakable_guard", "before_attack should resolve the class passive.")
	# run_started -> only the equipment-synergy passive.
	var run_started: Array[PassiveDefinition] = resolver.resolve(RuleTrigger.RUN_STARTED)
	assert_equal(run_started.size(), 1, "run_started should resolve exactly the one equipment-synergy passive.")
	assert_equal(run_started[0].passive_id, &"warrior_blade_and_board", "run_started should resolve the equipment-synergy passive.")

	# Two passives sharing a window resolve in REGISTRATION order.
	var shared: RulesResolver = RulesResolver.new()
	var first: PassiveDefinition = PassiveDefinition.new(&"first_passive", "First", PassiveDefinition.KIND_CLASS, [RuleTrigger.BEFORE_ATTACK], "First in.")
	var second: PassiveDefinition = PassiveDefinition.new(&"second_passive", "Second", PassiveDefinition.KIND_CLASS, [RuleTrigger.BEFORE_ATTACK], "Second in.")
	shared.register_passive(first)
	shared.register_passive(second)
	var both: Array[PassiveDefinition] = shared.resolve(RuleTrigger.BEFORE_ATTACK)
	assert_equal(both.size(), 2, "Both passives sharing before_attack should resolve.")
	assert_equal(both[0].passive_id, &"first_passive", "The first-registered passive should resolve first (stable registration order).")
	assert_equal(both[1].passive_id, &"second_passive", "The second-registered passive should resolve second.")


func _resolve_unregistered_window_returns_empty() -> void:
	var resolver: RulesResolver = _warrior_resolver()
	# No starting passive declares level_completed.
	assert_true(resolver.resolve(RuleTrigger.LEVEL_COMPLETED).is_empty(), "An unregistered window should resolve to an empty array.")
	# An entirely unknown window also returns empty (not an error).
	assert_true(resolver.resolve(&"not_a_real_window").is_empty(), "An unknown window should resolve to an empty array.")
	# An empty resolver returns empty for any window.
	var empty: RulesResolver = RulesResolver.new()
	assert_true(empty.resolve(RuleTrigger.BEFORE_ATTACK).is_empty(), "An empty resolver should resolve to an empty array.")
	assert_equal(empty.registered_passive_count(), 0, "An empty resolver should hold zero passives.")


func _explain_surfaces_explanations_in_stable_order() -> void:
	var resolver: RulesResolver = _warrior_resolver()
	var before_attack: Array[String] = resolver.explain(RuleTrigger.BEFORE_ATTACK)
	assert_equal(before_attack.size(), 1, "before_attack should surface one explanation.")
	assert_equal(before_attack[0], "Unbreakable Guard steels the hero before an incoming attack.", "before_attack should surface the class passive's explanation.")
	var run_started: Array[String] = resolver.explain(RuleTrigger.RUN_STARTED)
	assert_equal(run_started[0], "Blade and Board pairs sword and shield as the run begins.", "run_started should surface the equipment-synergy passive's explanation.")
	# An unregistered window surfaces no explanations.
	assert_true(resolver.explain(RuleTrigger.LEVEL_COMPLETED).is_empty(), "An unregistered window should surface no explanations.")


func _resolution_is_deterministic_for_same_registration_and_window() -> void:
	# Same registration sequence + same window -> byte-identical resolved id list AND explanation list.
	var first: RulesResolver = _warrior_resolver()
	var second: RulesResolver = _warrior_resolver()
	for window_id: StringName in [RuleTrigger.BEFORE_ATTACK, RuleTrigger.RUN_STARTED, RuleTrigger.LEVEL_COMPLETED]:
		var first_ids: Array[StringName] = _resolved_ids(first, window_id)
		var second_ids: Array[StringName] = _resolved_ids(second, window_id)
		assert_equal(first_ids, second_ids, "Resolved ids for %s must be byte-identical across identical resolvers." % String(window_id))
		assert_equal(first.explain(window_id), second.explain(window_id), "Explanations for %s must be byte-identical across identical resolvers." % String(window_id))
	# Repeated calls on the SAME resolver are also identical (pure read, no mutation).
	assert_equal(_resolved_ids(first, RuleTrigger.BEFORE_ATTACK), _resolved_ids(first, RuleTrigger.BEFORE_ATTACK), "Repeated resolve() must be identical (pure read).")


func _registered_passive_ids_are_in_registration_order() -> void:
	var resolver: RulesResolver = _warrior_resolver()
	assert_equal(resolver.registered_passive_ids(), [&"warrior_unbreakable_guard", &"warrior_blade_and_board"] as Array[StringName], "registered_passive_ids must be in registration order.")
	assert_equal(resolver.registered_passive_count(), 2, "The warrior resolver should hold exactly two passives.")


# AC3: the resolver holds ONLY PassiveDefinition instances and exposes no active-skill activation path.
func _resolver_holds_only_passives_and_exposes_no_active_skill() -> void:
	var resolver: RulesResolver = _warrior_resolver()
	for window_id: StringName in [RuleTrigger.BEFORE_ATTACK, RuleTrigger.RUN_STARTED]:
		for definition: PassiveDefinition in resolver.resolve(window_id):
			assert_true(definition is PassiveDefinition, "The resolver must hold only PassiveDefinition instances (no active-skill type).")
	# No active-skill activation method exists on the resolver.
	for forbidden: String in ["activate", "activate_skill", "trigger_active_skill", "use_skill"]:
		assert_false(resolver.has_method(forbidden), "The resolver must not expose an active-skill activation method '%s' (AC3)." % forbidden)


func _register_null_passive_is_ignored() -> void:
	var resolver: RulesResolver = RulesResolver.new()
	resolver.register_passive(null)
	assert_equal(resolver.registered_passive_count(), 0, "Registering a null passive should be ignored (defensive).")


func _resolved_ids(resolver: RulesResolver, window_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: PassiveDefinition in resolver.resolve(window_id):
		ids.append(definition.passive_id)
	return ids
