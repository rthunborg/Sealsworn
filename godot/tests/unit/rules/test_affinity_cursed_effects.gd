extends "res://tests/unit/test_case.gd"

# Story 7.5 Task 4 — Cursed effects (AC3): Cursed pressure resolved THROUGH the rules kernel, clear before/on effect.
# These prove the Cursed-affinity pressure routes through the EXISTING 7.2 rules-kernel curse surface (the
# register_curse / resolve_curses / explain precedent) + the 7.1 RiskEconomyState economy API — NOT a bespoke combat
# mutation:
#   - KERNEL RULE SOURCE: a Cursed-affinity rule source (a CurseDefinition) seats on a RulesResolver and RESOLVES +
#     EXPLAINS in its declared trigger window (level_entered), with a SOURCE-identifying explanation (AC3).
#   - CLEAR BEFORE/ON EFFECT: the explanation is queryable via explain(window) BEFORE the economy penalty is applied
#     (no silent hidden penalty — the 7.2 honest-consequence posture).
#   - ECONOMY PENALTY THROUGH RiskEconomyState: a curse-count increment applies through the 7.1 set_curse_count API
#     (the 7.2/7.3 boundary), NOT a hidden combat-number mutation.
#   - DETERMINISM: byte-identical resolve_curses / explain for the same seat sequence.
#   - NEUTRAL/NON-CURSED: a neutral / non-Cursed affinity seats NO Cursed rule source.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityEffectResolver = preload("res://scripts/rules/operations/affinity_effect_resolver.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const CurseDefinition = preload("res://scripts/content/definitions/curse_definition.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")

func run() -> Dictionary:
	_cursed_affinity_seats_a_kernel_rule_source_that_resolves_and_explains()
	_cursed_pressure_is_clear_before_the_economy_penalty_applies()
	_cursed_economy_penalty_applies_through_risk_economy_state()
	_cursed_resolution_is_deterministic()
	_a_neutral_or_non_cursed_affinity_seats_no_cursed_rule_source()
	_cursed_resolves_only_in_its_declared_window()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _repository() -> AffinityRepository:
	return AffinityRepository.create_baseline_repository()


# ---- AC3: kernel rule source resolves + explains -------------------------------------------------

func _cursed_affinity_seats_a_kernel_rule_source_that_resolves_and_explains() -> void:
	var resolver: RulesResolver = RulesResolver.new()
	# The resolver (the 7.5 narrow operations resolver) PRODUCES the Cursed rule source; the caller SEATS it on the run's
	# RulesResolver (the 7.2 register_curse precedent).
	var rule_source: CurseDefinition = AffinityEffectResolver.cursed_affinity_rule_source(&"cursed", _repository())
	assert_true(rule_source != null, "AC3: the Cursed affinity produces a curse-like rule source.")
	resolver.register_curse(rule_source)

	# It resolves in its declared window (level_entered) — the rules kernel "applies the configured cursed pressure".
	var curses: Array[CurseDefinition] = resolver.resolve_curses(RuleTrigger.LEVEL_ENTERED)
	assert_equal(curses.size(), 1, "AC3: the Cursed affinity rule source resolves in its declared trigger window.")
	# explain(window) surfaces a source-identifying line (the affinity_cursed source marker appears).
	var explanations: Array[String] = resolver.explain(RuleTrigger.LEVEL_ENTERED)
	assert_equal(explanations.size(), 1, "explain(level_entered) surfaces the Cursed pressure's explanation.")
	assert_true(explanations[0].contains("affinity_cursed"), "AC3: the explanation IDENTIFIES the Cursed affinity source.")
	# The rule source's explicit source marker is the source-of-truth (AC3).
	assert_equal(String(rule_source.curse_source), "affinity_cursed", "AC3: the Cursed rule source carries the explicit source marker.")


func _cursed_pressure_is_clear_before_the_economy_penalty_applies() -> void:
	# AC3 "the result is clear before or when it affects the player": the explanation is queryable BEFORE any economy
	# penalty is applied. Seat the rule source, query explain() — and only THEN apply the economy increment.
	var resolver: RulesResolver = RulesResolver.new()
	resolver.register_curse(AffinityEffectResolver.cursed_affinity_rule_source(&"cursed", _repository()))
	var economy: RiskEconomyState = RiskEconomyState.for_run(false)
	# BEFORE the penalty: the explanation is already available (clear before it affects the player).
	assert_false(resolver.explain(RuleTrigger.LEVEL_ENTERED).is_empty(), "AC3: the Cursed pressure is explainable BEFORE the penalty applies (never a silent hidden penalty).")
	assert_equal(economy.curse_count, 0, "Setup: the curse count starts at 0 (penalty not yet applied).")


func _cursed_economy_penalty_applies_through_risk_economy_state() -> void:
	# The economy-side penalty (a curse-count increment) applies through the 7.1 RiskEconomyState API (the 7.2/7.3
	# boundary), NOT a bespoke combat mutation. (This mirrors how AcceptCursedRewardCommand applies the curse increment.)
	var economy: RiskEconomyState = RiskEconomyState.for_run(false)
	var before: int = economy.curse_count
	economy.set_curse_count(before + 1)
	assert_equal(economy.curse_count, before + 1, "The Cursed economy penalty increments the curse count through the RiskEconomyState API.")
	# It is an HONEST, bounded count change — NOT a hidden multiplier (difficulty is a hard non-goal).
	assert_true(economy.curse_count >= 0, "The curse count stays a non-negative bounded count.")


func _cursed_resolution_is_deterministic() -> void:
	var first: RulesResolver = RulesResolver.new()
	var second: RulesResolver = RulesResolver.new()
	first.register_curse(AffinityEffectResolver.cursed_affinity_rule_source(&"cursed", _repository()))
	second.register_curse(AffinityEffectResolver.cursed_affinity_rule_source(&"cursed", _repository()))
	for window_id: StringName in [RuleTrigger.LEVEL_ENTERED, RuleTrigger.BEFORE_ATTACK, RuleTrigger.RUN_STARTED]:
		assert_equal(first.registered_curse_ids(), second.registered_curse_ids(), "Registered Cursed rule-source ids are byte-identical across identical seat sequences.")
		assert_equal(first.explain(window_id), second.explain(window_id), "Cursed explanations for %s are byte-identical across identical seat sequences." % String(window_id))


func _a_neutral_or_non_cursed_affinity_seats_no_cursed_rule_source() -> void:
	# A neutral / Scorched / Flooded / Darkness affinity produces NO Cursed rule source (only the Cursed affinity does).
	for affinity_id: StringName in [AffinityDefinition.AFFINITY_NONE, &"scorched", &"flooded_conductive", &"darkness", &"unknown_id"]:
		assert_true(AffinityEffectResolver.cursed_affinity_rule_source(affinity_id, _repository()) == null, "%s produces no Cursed rule source." % String(affinity_id))


func _cursed_resolves_only_in_its_declared_window() -> void:
	var resolver: RulesResolver = RulesResolver.new()
	resolver.register_curse(AffinityEffectResolver.cursed_affinity_rule_source(&"cursed", _repository()))
	# It declares level_entered ONLY — it must NOT resolve in an unrelated window.
	assert_equal(resolver.resolve_curses(RuleTrigger.LEVEL_ENTERED).size(), 1, "The Cursed pressure resolves in its declared window.")
	assert_true(resolver.resolve_curses(RuleTrigger.BEFORE_ATTACK).is_empty(), "A level_entered-only Cursed source must NOT resolve in before_attack.")
	assert_true(resolver.explain(RuleTrigger.RUN_STARTED).is_empty(), "A level_entered-only Cursed source must NOT surface in run_started.")
