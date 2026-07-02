extends "res://tests/unit/test_case.gd"

# Story 8.3 Task 3 (AC1, AC3): the Oath-Shard award CALCULATION — deterministic, capped, sparse. An eligible completed
# run yields the expected capped amount; an over-cap signal clamps to MAX_AWARD (the AC3 cap); the calculation is
# deterministic (twice → identical) + draws ZERO RNG; a failed (death) run yields 0; a non-terminal/null run yields 0.
# The manual-seed DENIAL is enforced at the APPLICATION gate (test_award_meta_progress_command.gd), not here — the
# calculator is a pure amount.

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
	return result()


func _completed_run_yields_expected_capped_amount() -> void:
	# A completed run over a 3-node cleared route: min(BASE + PER_NODE * 3, MAX_AWARD) = min(1 + 3, 5) = 4.
	var run: RunState = _completed_run_with_cleared_nodes(3)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])

	var award: int = MetaAwardRules.oath_shard_award_for(run, summary)
	var expected: int = MetaAwardRules.BASE_AWARD + MetaAwardRules.PER_NODE_AWARD * 3
	assert_equal(award, expected, "A completed 3-node run should award BASE + PER_NODE * 3.")
	assert_true(award <= MetaAwardRules.MAX_AWARD, "The award must never exceed MAX_AWARD.")


func _over_cap_signal_clamps_to_max_award() -> void:
	# A completed run over a route with MANY cleared nodes must CLAMP to MAX_AWARD (AC3 cap enforced).
	var run: RunState = _completed_run_with_cleared_nodes(50)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])

	var award: int = MetaAwardRules.oath_shard_award_for(run, summary)
	assert_equal(award, MetaAwardRules.MAX_AWARD, "A run whose signal exceeds the cap must clamp to MAX_AWARD (AC3 'capped').")


func _calculation_is_deterministic_and_rng_free() -> void:
	# Same terminal run → same award, every time (ZERO RNG — a deterministic calculation, not a roll).
	var run: RunState = _completed_run_with_cleared_nodes(2)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])

	var first: int = MetaAwardRules.oath_shard_award_for(run, summary)
	var second: int = MetaAwardRules.oath_shard_award_for(run, summary)
	var third: int = MetaAwardRules.oath_shard_award_for(run, summary)
	assert_equal(first, second, "The award calculation must be deterministic (twice → identical).")
	assert_equal(second, third, "The award calculation must be deterministic (thrice → identical).")

	# A freshly rebuilt run+summary from the SAME inputs yields the SAME award (a pure function of the inputs).
	var rebuilt_run: RunState = _completed_run_with_cleared_nodes(2)
	var rebuilt_summary: RunSummary = RunSummary.build(rebuilt_run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	assert_equal(MetaAwardRules.oath_shard_award_for(rebuilt_run, rebuilt_summary), first, "Rebuilding from the same inputs yields the same award (deterministic).")


func _failed_run_yields_zero() -> void:
	# A death (PHASE_FAILED) awards NOTHING this story ([Decision]).
	var run: RunState = _failed_run_with_cleared_nodes(3)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_failed(1, {"cause": "hero_death"})])

	var award: int = MetaAwardRules.oath_shard_award_for(run, summary)
	assert_equal(award, 0, "A failed (death) run must award 0 Oath Shards this story.")


func _non_terminal_and_null_run_yield_zero() -> void:
	# A non-terminal run (still active) has no ended run to reward → 0. A null run → 0 (fail-safe).
	var active_route: RouteState = _cleared_route(2)
	var active_run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, active_route)
	var active_summary: RunSummary = RunSummary.build(active_run, [])
	assert_equal(MetaAwardRules.oath_shard_award_for(active_run, active_summary), 0, "A non-terminal run must award 0.")

	assert_equal(MetaAwardRules.oath_shard_award_for(null, null), 0, "A null run must award 0 (fail-safe).")


func _completed_run_with_zero_nodes_yields_the_base_award() -> void:
	# A completed run that cleared 0 nodes still gets the BASE grant for reaching an ending.
	var run: RunState = _completed_run_with_cleared_nodes(0)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])

	var award: int = MetaAwardRules.oath_shard_award_for(run, summary)
	assert_equal(award, MetaAwardRules.BASE_AWARD, "A completed 0-node run should award exactly the BASE grant.")


func _award_does_not_depend_on_economy_or_difficulty_signals() -> void:
	# The award reads ONLY the terminal phase + the bounded nodes-cleared signal — NOT gold/curse/corruption (economy)
	# and NOT any difficulty knob. Two completed runs with the SAME cleared-node count but wildly different economies
	# must award the SAME amount (AC3 secondary-to-variety; the difficulty non-goal).
	var poor_run: RunState = _completed_run_with_cleared_nodes_and_economy(2, 0, 0, 0)
	var rich_run: RunState = _completed_run_with_cleared_nodes_and_economy(2, 9999, 5, 5)
	var poor_summary: RunSummary = RunSummary.build(poor_run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var rich_summary: RunSummary = RunSummary.build(rich_run, [DomainEvent.run_completed(1, {"outcome": "completed"})])

	assert_equal(
		MetaAwardRules.oath_shard_award_for(poor_run, poor_summary),
		MetaAwardRules.oath_shard_award_for(rich_run, rich_summary),
		"The award must NOT scale by economy/difficulty — only by the bounded nodes-cleared signal."
	)


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
