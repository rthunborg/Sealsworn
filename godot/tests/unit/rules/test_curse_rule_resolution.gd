extends "res://tests/unit/test_case.gd"

# Story 7.2 Task 5 — curse/corruption rule resolution through the RULES KERNEL (AC3). These prove the v0
# EXPLANATION-ONLY rules-kernel curse-resolution contract, end-to-end through AcceptCursedRewardCommand (the seam every
# accepted curse flows through):
#   - TRIGGER WINDOW: a curse resolves ONLY in its declared trigger window(s), not others.
#   - STABLE ORDER:   a curse resolves alongside passives in STABLE registration order (passives first, then curses) in
#                     explain(window).
#   - SOURCE-IDENTIFYING EXPLANATION: explain(window) surfaces a line that IDENTIFIES the curse SOURCE (AC3).
#   - DETERMINISM:    byte-identical resolve_curses / explain for the same registration sequence.
#   - EMPTY:          an unregistered window returns empty.
#
# v0 is EXPLANATION-ONLY (the SAME bar v0 passives meet — Story 5.4): resolution SURFACES the curse + its
# source-identifying explanation; it does NOT mutate an HP/damage number (the per-effect operation engine is the later
# operations story — scripts/rules/{conditions,operations} stay empty). The economy-side curse_count/corruption
# increment is applied by AcceptCursedRewardCommand, NOT by the resolver (the resolver is a PURE READ — no RNG, no
# command, no mutation). Mirrors test_passive_trigger_order.gd.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AcceptCursedRewardCommand = preload("res://scripts/core/commands/accept_cursed_reward_command.gd")
const CurseDefinition = preload("res://scripts/content/definitions/curse_definition.gd")
const CursedRewardDefinition = preload("res://scripts/content/definitions/cursed_reward_definition.gd")
const CursedRewardRepository = preload("res://scripts/content/repositories/cursed_reward_repository.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_a_curse_resolves_in_its_declared_window_with_a_source_identifying_explanation()
	_a_curse_resolves_alongside_passives_in_stable_order()
	_a_curse_resolves_only_in_its_declared_window()
	_resolution_is_deterministic_for_the_same_accept_sequence()
	_an_unregistered_window_returns_empty()
	_curse_definition_validate_requires_an_explicit_source_marker()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _valid_run() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, boss], "", [])
	var run: RunState = RunState.new_run(7, false, route)
	assert_true(run.validate().succeeded, "Setup: the valid run should validate.")
	return run


func _fixture_repository() -> CursedRewardRepository:
	return CursedRewardRepository.create_repository_from_definitions([
		CursedRewardDefinition.new(
			&"test_curse_reward", "Test Curse Reward",
			"Gain 10 gold.", "Take on 1 curse.",
			10, 0, 1, 0, 0, 0, false, "The curse is the cost."
		)
	])


func _accept_curse(run: RunState) -> ActionResult:
	return AcceptCursedRewardCommand.new(&"test_curse_reward", 1, _fixture_repository()).execute(run)


# ---- AC3: trigger window + source-identifying explanation -----------------------------------------

func _a_curse_resolves_in_its_declared_window_with_a_source_identifying_explanation() -> void:
	var run: RunState = _valid_run()
	assert_true(_accept_curse(run).succeeded, "Accepting the cursed reward should seat the curse.")
	# The curse (CurseDefinition.for_cursed_reward declares level_entered) resolves in level_entered.
	var curses: Array[CurseDefinition] = run.rules_resolver.resolve_curses(RuleTrigger.LEVEL_ENTERED)
	assert_equal(curses.size(), 1, "AC3: the curse resolves in its declared trigger window.")
	# explain(level_entered) surfaces a source-identifying line (the cursed_reward_id appears in the explanation).
	var explanations: Array[String] = run.rules_resolver.explain(RuleTrigger.LEVEL_ENTERED)
	assert_equal(explanations.size(), 1, "explain(level_entered) surfaces the curse's explanation.")
	assert_true(explanations[0].contains("test_curse_reward"), "AC3: the curse's explanation IDENTIFIES the curse source (the cursed_reward_id).")


func _a_curse_resolves_alongside_passives_in_stable_order() -> void:
	# Seat a STARTING passive that declares level_entered alongside the curse, then accept the curse. explain shows the
	# passive FIRST then the curse (stable order — passives, then curses).
	var run: RunState = _valid_run()
	var resolver: RulesResolver = RulesResolver.new()
	# A passive that fires in level_entered: the baseline passives declare before_attack / run_started, so build a
	# custom valid passive declaring level_entered directly (to prove a curse resolves ALONGSIDE a passive in one
	# window, passives first then curses).
	resolver.register_passive(_level_entered_passive())
	run.rules_resolver = resolver
	assert_true(_accept_curse(run).succeeded, "Accepting the cursed reward should append the curse to the existing resolver.")

	# resolve() (passives only) still returns exactly the passive in level_entered (the typed passive contract intact).
	assert_equal(run.rules_resolver.resolve(RuleTrigger.LEVEL_ENTERED).size(), 1, "resolve() returns only the passive (typed passive contract intact).")
	assert_equal(run.rules_resolver.resolve_curses(RuleTrigger.LEVEL_ENTERED).size(), 1, "resolve_curses() returns the curse.")
	# explain() merges both: the passive's explanation FIRST, then the curse's (stable order).
	var explanations: Array[String] = run.rules_resolver.explain(RuleTrigger.LEVEL_ENTERED)
	assert_equal(explanations.size(), 2, "explain(level_entered) surfaces BOTH the passive and the curse explanation.")
	assert_equal(explanations[0], _level_entered_passive().explanation, "The passive's explanation surfaces FIRST (stable order — passives before curses).")
	assert_true(explanations[1].contains("test_curse_reward"), "The curse's explanation surfaces SECOND, identifying its source.")


func _a_curse_resolves_only_in_its_declared_window() -> void:
	var run: RunState = _valid_run()
	assert_true(_accept_curse(run).succeeded, "Accepting the cursed reward should seat the curse.")
	# The curse declares level_entered ONLY — it must NOT resolve in an unrelated window.
	assert_true(run.rules_resolver.resolve_curses(RuleTrigger.LEVEL_ENTERED).size() == 1, "The curse resolves in its declared window.")
	assert_true(run.rules_resolver.resolve_curses(RuleTrigger.BEFORE_ATTACK).is_empty(), "A level_entered-only curse must NOT resolve in before_attack (trigger timing).")
	assert_true(run.rules_resolver.explain(RuleTrigger.RUN_STARTED).is_empty(), "A level_entered-only curse must NOT surface in run_started.")


# ---- AC3: determinism ----------------------------------------------------------------------------

func _resolution_is_deterministic_for_the_same_accept_sequence() -> void:
	var first: RunState = _valid_run()
	var second: RunState = _valid_run()
	assert_true(_accept_curse(first).succeeded, "Setup: the first accept should succeed.")
	assert_true(_accept_curse(second).succeeded, "Setup: the second accept should succeed.")
	for window_id: StringName in [RuleTrigger.LEVEL_ENTERED, RuleTrigger.BEFORE_ATTACK, RuleTrigger.RUN_STARTED]:
		assert_equal(
			first.rules_resolver.registered_curse_ids(),
			second.rules_resolver.registered_curse_ids(),
			"Registered curse ids must be byte-identical across identical accept sequences."
		)
		assert_equal(
			first.rules_resolver.explain(window_id),
			second.rules_resolver.explain(window_id),
			"Explanations for %s must be byte-identical across identical accept sequences." % String(window_id)
		)


# ---- AC3: empty ----------------------------------------------------------------------------------

func _an_unregistered_window_returns_empty() -> void:
	var resolver: RulesResolver = RulesResolver.new()
	# No curse registered: every window resolves empty.
	for window_id: StringName in RuleTrigger.WINDOWS:
		assert_true(resolver.resolve_curses(window_id).is_empty(), "An empty resolver resolves no curses in %s." % String(window_id))
		assert_true(resolver.explain(window_id).is_empty(), "An empty resolver explains nothing in %s." % String(window_id))


# ---- CurseDefinition validate: the EXPLICIT source-marker rule (Story 7.2 review — tightened) ------
# Source identity (AC3) is carried by the EXPLICIT `curse_source` marker field, validated directly as a first-class
# lower_snake id (present / non-empty / well-formed) — exactly like every other *_id/source field in the codebase. It
# is NO LONGER inferred by substring-matching the human-readable `explanation` (which is display-only). These assert
# the explicit-marker contract: a malformed/blank/missing `curse_source` is rejected; the `explanation` is no longer
# load-bearing for source identity.

func _curse_definition_validate_requires_an_explicit_source_marker() -> void:
	# A curse with a NON-lower_snake explicit source marker is rejected, naming the curse_source field (AC3 — the
	# source must be a clean, first-class marker, not free-text).
	var bad_marker: CurseDefinition = CurseDefinition.new(
		&"curse_bad", &"Anon-Source", "Bad Marker Curse",
		[RuleTrigger.LEVEL_ENTERED],
		"A curse whose source marker is malformed."
	)
	var bad_validation: ActionResult = bad_marker.validate()
	assert_true(bad_validation.is_error(), "A curse with a non-lower_snake curse_source must be rejected.")
	assert_equal(bad_validation.error_code, &"invalid_curse_definition", "A bad-source-marker curse uses the stable code.")
	assert_equal(String(bad_validation.metadata.get("field")), "curse_source", "The reject names the curse_source field (the explicit marker).")

	# A curse with a BLANK explicit source marker is rejected, naming the curse_source field.
	var blank_marker: CurseDefinition = CurseDefinition.new(
		&"curse_blank", &"", "Blank Marker Curse",
		[RuleTrigger.LEVEL_ENTERED],
		"A curse with no source marker at all."
	)
	var blank_validation: ActionResult = blank_marker.validate()
	assert_true(blank_validation.is_error(), "A curse with a blank curse_source must be rejected.")
	assert_equal(String(blank_validation.metadata.get("field")), "curse_source", "A blank curse_source reject names the curse_source field.")

	# A curse with a VALID explicit source marker whose explanation does NOT mention the source text is now VALID:
	# the explanation is display-only and is NO LONGER cross-checked against the source (the tightening — the brittle
	# substring inference is gone; source identity rides the explicit marker).
	var explicit_only: CurseDefinition = CurseDefinition.new(
		&"curse_explicit", &"some_source_marker", "Explicit Marker Curse",
		[RuleTrigger.LEVEL_ENTERED],
		"This explanation never names where it came from."
	)
	assert_true(explicit_only.validate().succeeded, "A curse with a valid explicit curse_source validates even when the explanation omits the source (explanation is display-only).")
	assert_equal(String(explicit_only.curse_source), "some_source_marker", "The explicit curse_source marker is the source-of-truth (AC3).")

	# The factory-built curse sets the explicit marker DIRECTLY from the cursed_reward_id and validates; its explain()
	# surface still identifies the source for display readability.
	var named: CurseDefinition = CurseDefinition.for_cursed_reward(&"cursed_blade_of_the_forsaken", "Cursed Blade")
	assert_true(named.validate().succeeded, "A factory-built curse sets the explicit source marker and validates.")
	assert_equal(String(named.curse_source), "cursed_blade_of_the_forsaken", "The factory sets curse_source DIRECTLY to the cursed_reward_id (the explicit marker).")
	assert_true(named.explanation.contains("cursed_blade_of_the_forsaken"), "The factory-built curse's explanation still mentions the source for display (not load-bearing).")


# A valid PassiveDefinition declaring the level_entered window (for the alongside-passives order test).
func _level_entered_passive():
	var PassiveDefinition = load("res://scripts/content/definitions/passive_definition.gd")
	return PassiveDefinition.new(
		&"test_level_entered_passive",
		"Level Entered Passive",
		PassiveDefinition.KIND_CLASS,
		[RuleTrigger.LEVEL_ENTERED],
		"A test passive that fires when a level is entered.",
		PassiveDefinition.ICON_PLACEHOLDER,
		"A test flavor line.",
		"A test explicit mechanics line.",
		"Consume test text.",
		"Destroy test text.",
		false,
		"No hidden cost.",
		[PassiveDefinition.PILLAR_TACTICAL_CLARITY]
	)
