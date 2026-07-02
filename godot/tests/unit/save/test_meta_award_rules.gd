extends "res://tests/unit/test_case.gd"

# Story 8.3 Task 3 (AC1, AC3): the Oath-Shard award CALCULATION — deterministic, capped, sparse. An eligible completed
# run yields the expected capped amount; an over-cap signal clamps to MAX_AWARD (the AC3 cap); the calculation is
# deterministic (twice → identical) + draws ZERO RNG; a failed (death) run yields 0; a non-terminal/null run yields 0.
# The manual-seed DENIAL is enforced at the APPLICATION gate (test_award_meta_progress_command.gd), not here — the
# calculator is a pure amount.
#
# Code review of 8-3 Round 1 (human option (b), harden now): the amount is a PURE FUNCTION OF THE RunState — nodes_cleared
# is derived DIRECTLY off run.route.cleared_node_ids, NOT off a caller-supplied RunSummary. _amount_comes_from_the_run_state
# pins that a mismatched/foreign summary can no longer skew the award (the calculator no longer takes a summary at all).

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const MetaAwardRules = preload("res://scripts/save/meta_award_rules.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

func run() -> Dictionary:
	_completed_run_yields_expected_capped_amount()
	_over_cap_signal_clamps_to_max_award()
	_calculation_is_deterministic_and_rng_free()
	_failed_run_yields_zero()
	_non_terminal_and_null_run_yield_zero()
	_completed_run_with_zero_nodes_yields_the_base_award()
	_award_does_not_depend_on_economy_or_difficulty_signals()
	_amount_comes_from_the_run_state()
	return result()


func _completed_run_yields_expected_capped_amount() -> void:
	# A completed run over a 3-node cleared route: min(BASE + PER_NODE * 3, MAX_AWARD) = min(1 + 3, 5) = 4.
	var run: RunState = _completed_run_with_cleared_nodes(3)

	var award: int = MetaAwardRules.oath_shard_award_for(run)
	var expected: int = MetaAwardRules.BASE_AWARD + MetaAwardRules.PER_NODE_AWARD * 3
	assert_equal(award, expected, "A completed 3-node run should award BASE + PER_NODE * 3.")
	assert_true(award <= MetaAwardRules.MAX_AWARD, "The award must never exceed MAX_AWARD.")


func _over_cap_signal_clamps_to_max_award() -> void:
	# A completed run over a route with MANY cleared nodes must CLAMP to MAX_AWARD (AC3 cap enforced).
	var run: RunState = _completed_run_with_cleared_nodes(50)

	var award: int = MetaAwardRules.oath_shard_award_for(run)
	assert_equal(award, MetaAwardRules.MAX_AWARD, "A run whose signal exceeds the cap must clamp to MAX_AWARD (AC3 'capped').")


func _calculation_is_deterministic_and_rng_free() -> void:
	# Same terminal run → same award, every time (ZERO RNG — a deterministic calculation, not a roll).
	var run: RunState = _completed_run_with_cleared_nodes(2)

	var first: int = MetaAwardRules.oath_shard_award_for(run)
	var second: int = MetaAwardRules.oath_shard_award_for(run)
	var third: int = MetaAwardRules.oath_shard_award_for(run)
	assert_equal(first, second, "The award calculation must be deterministic (twice → identical).")
	assert_equal(second, third, "The award calculation must be deterministic (thrice → identical).")

	# A freshly rebuilt run from the SAME inputs yields the SAME award (a pure function of the run).
	var rebuilt_run: RunState = _completed_run_with_cleared_nodes(2)
	assert_equal(MetaAwardRules.oath_shard_award_for(rebuilt_run), first, "Rebuilding from the same inputs yields the same award (deterministic).")


func _failed_run_yields_zero() -> void:
	# A death (PHASE_FAILED) awards NOTHING this story ([Decision]).
	var run: RunState = _failed_run_with_cleared_nodes(3)

	var award: int = MetaAwardRules.oath_shard_award_for(run)
	assert_equal(award, 0, "A failed (death) run must award 0 Oath Shards this story.")


func _non_terminal_and_null_run_yield_zero() -> void:
	# A non-terminal run (still active) has no ended run to reward → 0. A null run → 0 (fail-safe).
	var active_route: RouteState = _cleared_route(2)
	var active_run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, active_route)
	assert_equal(MetaAwardRules.oath_shard_award_for(active_run), 0, "A non-terminal run must award 0.")

	assert_equal(MetaAwardRules.oath_shard_award_for(null), 0, "A null run must award 0 (fail-safe).")


func _completed_run_with_zero_nodes_yields_the_base_award() -> void:
	# A completed run that cleared 0 nodes still gets the BASE grant for reaching an ending.
	var run: RunState = _completed_run_with_cleared_nodes(0)

	var award: int = MetaAwardRules.oath_shard_award_for(run)
	assert_equal(award, MetaAwardRules.BASE_AWARD, "A completed 0-node run should award exactly the BASE grant.")


func _award_does_not_depend_on_economy_or_difficulty_signals() -> void:
	# The award reads ONLY the terminal phase + the bounded nodes-cleared signal — NOT gold/curse/corruption (economy)
	# and NOT any difficulty knob. Two completed runs with the SAME cleared-node count but wildly different economies
	# must award the SAME amount (AC3 secondary-to-variety; the difficulty non-goal).
	var poor_run: RunState = _completed_run_with_cleared_nodes_and_economy(2, 0, 0, 0)
	var rich_run: RunState = _completed_run_with_cleared_nodes_and_economy(2, 9999, 5, 5)

	assert_equal(
		MetaAwardRules.oath_shard_award_for(poor_run),
		MetaAwardRules.oath_shard_award_for(rich_run),
		"The award must NOT scale by economy/difficulty — only by the bounded nodes-cleared signal."
	)


func _amount_comes_from_the_run_state() -> void:
	# Code review of 8-3 Round 1, human option (b): the amount is derived from run.route.cleared_node_ids — NOT from any
	# externally-built RunSummary. The amount for a 3-node completed run must EQUAL what RunSummary.build would report for
	# THAT run's nodes_cleared, and a summary built from a DIFFERENT (foreign) run must not perturb it (the calculator no
	# longer accepts a summary — the coupling is structurally gone).
	var run: RunState = _completed_run_with_cleared_nodes(3)
	var own_summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var award: int = MetaAwardRules.oath_shard_award_for(run)

	# The amount is self-consistent with the run's OWN derived nodes-cleared signal (mirrors run_summary.gd:254).
	var own_nodes: int = int(own_summary.run_scoped.get("nodes_cleared", 0))
	assert_equal(own_nodes, 3, "Setup: the run's own summary should report 3 nodes cleared.")
	assert_equal(award, min(MetaAwardRules.BASE_AWARD + MetaAwardRules.PER_NODE_AWARD * own_nodes, MetaAwardRules.MAX_AWARD), "The amount must be derived from the run's own route node count.")

	# A FOREIGN run with a WILDLY different cleared-node count exists — but it is irrelevant: the amount is a pure
	# function of `run` alone, so building/ignoring a foreign summary changes nothing.
	var foreign_run: RunState = _completed_run_with_cleared_nodes(50)
	var _foreign_summary: RunSummary = RunSummary.build(foreign_run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	assert_equal(MetaAwardRules.oath_shard_award_for(run), award, "A foreign run's summary must never skew the award — the amount comes from the terminal run's own route.")


# ---- fixtures -----------------------------------------------------------------------------------

# A route whose first `cleared` nodes are all cleared. Node ids "node-0", "node-1", ... The last cleared node is the
# current node (a terminal run parked at its last node). An empty route (0 cleared) has a single uncleared start node
# but an empty cleared set.
func _cleared_route(cleared: int) -> RouteState:
	var nodes: Array[RouteNode] = []
	var cleared_ids: Array[String] = []
	var count: int = max(cleared, 1)
	for index: int in range(count):
		var node_id: String = "node-%d" % index
		var next_ids: Array[String] = []
		if index < count - 1:
			next_ids = ["node-%d" % (index + 1)]
		nodes.append(RouteNode.new(node_id, RouteNode.TYPE_COMBAT, index, RouteNode.REVEAL_CLEARED, next_ids))
		if index < cleared:
			cleared_ids.append(node_id)
	var current_id: String = cleared_ids[cleared_ids.size() - 1] if not cleared_ids.is_empty() else ""
	return RouteState.new(nodes, current_id, cleared_ids)


func _completed_run_with_cleared_nodes(cleared: int) -> RunState:
	var run: RunState = RunState.new(RunState.PHASE_COMPLETED, 4242, false, true, _cleared_route(cleared))
	assert_true(run.validate().succeeded, "Setup: the completed run should validate.")
	return run


func _failed_run_with_cleared_nodes(cleared: int) -> RunState:
	var run: RunState = RunState.new(RunState.PHASE_FAILED, 4242, false, true, _cleared_route(cleared))
	assert_true(run.validate().succeeded, "Setup: the failed run should validate.")
	return run


func _completed_run_with_cleared_nodes_and_economy(cleared: int, gold: int, curse: int, corruption: int) -> RunState:
	var economy: RiskEconomyState = RiskEconomyState.new(gold, 0, curse, corruption, true, [])
	var run: RunState = RunState.new(RunState.PHASE_COMPLETED, 4242, false, true, _cleared_route(cleared), &"", null, null, null, null, economy)
	assert_true(run.validate().succeeded, "Setup: the completed run with economy should validate.")
	return run
