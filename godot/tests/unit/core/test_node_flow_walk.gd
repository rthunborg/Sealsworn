extends "res://tests/unit/test_case.gd"

# Story 4.4 — the cross-command node-flow WALK (Task 4.3 / 7.3) + the Story 4.3 idempotency regression
# (Task 4.1 / 7.5). This is the load-bearing 4.3+4.4 interaction proof: on 4.2-generated routes, run
# advance -> enter -> exit repeatedly to the boss tier, asserting run.validate() is green at EVERY step,
# the phase ping-pongs ACTIVE_ROUTE <-> NODE_RESOLUTION correctly, and cleared_node_ids NEVER duplicates
# (the real cross-command bug: 4.4 exit clears the CURRENT node AND 4.3's next advance re-clears that
# same node — without the 4.3 idempotency guard this produces a duplicate_cleared_node rejection).
#
# The walk only ENTERS combat/elite nodes (4.4 scopes entry to those). On a non-combat interior node, the
# walk advances past it WITHOUT entering (per-type resolution is Story 4.5) so it can still reach the boss
# across arbitrary generated routes; on the combat/elite nodes it performs the full advance/enter/exit
# cycle that exercises the duplicate-clear interaction.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const NodeEnterCommand = preload("res://scripts/core/commands/node_enter_command.gd")
const NodeExitCommand = preload("res://scripts/core/commands/node_exit_command.gd")
const RouteAdvanceCommand = preload("res://scripts/core/commands/route_advance_command.gd")
const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# Representative seeds (exercise both 4.2 width patterns; same set the 4.3 walk uses).
const WALK_SEEDS: Array[int] = [1, 7, 42, 2026]

func run() -> Dictionary:
	_advance_enter_exit_walk_to_boss_never_duplicates_cleared()
	_advance_off_an_already_cleared_node_is_idempotent()
	_enter_then_exit_round_trips_the_phase()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# Build a RunState parked on the start node of a freshly generated route, in PHASE_ACTIVE_ROUTE.
func _active_run_for_seed(seed_value: int) -> RunState:
	var generation = RouteGenerator.generate(seed_value)
	assert_true(not generation.is_error(), "Route generation should succeed for seed %d." % seed_value)
	var route: RouteState = RouteGenerator.route_from_result(generation)
	assert_true(route != null, "route_from_result should rehydrate a route for seed %d." % seed_value)
	var start_id: String = route.nodes()[0].id
	var run: RunState = RunState.new_run(seed_value, false, route)
	run.route.current_node_id = start_id
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	assert_true(run.validate().succeeded, "Setup: the generated active run should validate for seed %d." % seed_value)
	return run


func _is_combat_type(node_type: StringName) -> bool:
	return node_type == RouteNode.TYPE_COMBAT or node_type == RouteNode.TYPE_ELITE_COMBAT


# ---- Task 4.3 / 7.3: the advance/enter/exit walk to the boss -------------------------------------

func _advance_enter_exit_walk_to_boss_never_duplicates_cleared() -> void:
	for seed_value: int in WALK_SEEDS:
		var run: RunState = _active_run_for_seed(seed_value)
		var steps: int = 0
		var max_steps: int = 64  # generous guard; the boss is at a fixed shallow depth.
		var reached_boss: bool = false
		var entered_at_least_one_combat: bool = false

		while steps < max_steps:
			var current: RouteNode = run.route.node_by_id(run.route.current_node_id)
			if current.type == RouteNode.TYPE_BOSS:
				reached_boss = true
				break

			# On a combat/elite node, run the FULL enter -> exit cycle (the part that exercises the
			# cross-command duplicate-clear interaction). The walk must be in ACTIVE_ROUTE here.
			assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: the walk should be in ACTIVE_ROUTE before entering at step %d." % [seed_value, steps])
			if _is_combat_type(current.type):
				var enter: ActionResult = NodeEnterCommand.new().execute(run)
				assert_true(enter.succeeded, "Seed %d: entering the combat node should succeed at step %d: %s" % [seed_value, steps, enter.metadata])
				assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "Seed %d: entry should move the run to NODE_RESOLUTION at step %d." % [seed_value, steps])
				assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after entry at step %d." % [seed_value, steps])

				var exit: ActionResult = NodeExitCommand.new().execute(run)
				assert_true(exit.succeeded, "Seed %d: exiting the resolved node should succeed at step %d: %s" % [seed_value, steps, exit.metadata])
				assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: exit should move the run back to ACTIVE_ROUTE at step %d." % [seed_value, steps])
				assert_true(run.route.cleared_node_ids.has(current.id), "Seed %d: the exited node should be cleared at step %d." % [seed_value, steps])
				assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after exit at step %d." % [seed_value, steps])
				_assert_no_duplicate_cleared(run, seed_value, steps)
				entered_at_least_one_combat = true

			# Advance to the first eligible choice. For a combat node this advances OFF a node that
			# NodeExitCommand just cleared — the exact interaction that would duplicate-clear without the
			# 4.3 idempotency guard.
			var eligible: Array[String] = run.route.eligible_choice_ids()
			assert_true(not eligible.is_empty(), "Seed %d: a non-boss node must always have an eligible choice (no soft-lock) at step %d." % [seed_value, steps])
			var advance: ActionResult = RouteAdvanceCommand.new(eligible[0]).execute(run)
			assert_true(advance.succeeded, "Seed %d: advancing to an eligible choice should succeed at step %d: %s" % [seed_value, steps, advance.metadata])
			assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: advance keeps the run in ACTIVE_ROUTE at step %d." % [seed_value, steps])
			assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after each advance at step %d." % [seed_value, steps])
			_assert_no_duplicate_cleared(run, seed_value, steps)
			steps += 1

		assert_true(reached_boss, "Seed %d: the walk should reach the boss tier within the step guard." % seed_value)
		assert_true(entered_at_least_one_combat, "Seed %d: the walk should enter at least one combat/elite node (the start is always combat)." % seed_value)


func _assert_no_duplicate_cleared(run: RunState, seed_value: int, step: int) -> void:
	var seen: Dictionary = {}
	for cleared_id: String in run.route.cleared_node_ids:
		assert_false(seen.has(cleared_id), "Seed %d: cleared_node_ids must never duplicate (%s at step %d)." % [seed_value, cleared_id, step])
		seen[cleared_id] = true


# ---- Task 4.1 / 7.5: the 4.3 idempotency regression ----------------------------------------------

func _advance_off_an_already_cleared_node_is_idempotent() -> void:
	# Directly exercise the guard: a node that is ALREADY in cleared_node_ids (and REVEAL_CLEARED, as
	# NodeExitCommand leaves it) must, when advanced OFF, NOT be appended a second time. Without the 4.3
	# idempotency guard this produces a duplicate_cleared_node rejection from RouteState.validate().
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var combat: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_CLEARED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
	# Parked on node-1-0, which is ALREADY cleared (mirrors the state right after NodeExitCommand). The
	# start is also cleared. node-2-0 (the boss) is revealed and eligible.
	var route: RouteState = RouteState.new([start, combat, boss], "node-1-0", ["node-0-0", "node-1-0"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 321, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the pre-cleared parked run should validate.")

	# node-1-0 is already cleared; advancing off it must remain idempotent.
	var before_count: int = run.route.cleared_node_ids.size()
	var advance: ActionResult = RouteAdvanceCommand.new("node-2-0").execute(run)
	assert_true(advance.succeeded, "Advancing off an already-cleared node should succeed: %s" % advance.metadata)
	assert_equal(run.route.current_node_id, "node-2-0", "The advance should move the pointer to the boss.")
	# cleared_node_ids did NOT grow (node-1-0 was already present; the guard skipped the re-append).
	assert_equal(run.route.cleared_node_ids.size(), before_count, "Advancing off an already-cleared node must not append a duplicate.")
	# No duplicate, run still valid.
	var seen: Dictionary = {}
	for cleared_id: String in run.route.cleared_node_ids:
		assert_false(seen.has(cleared_id), "cleared_node_ids must stay duplicate-free after advancing off an already-cleared node (%s)." % cleared_id)
		seen[cleared_id] = true
	assert_true(run.validate().succeeded, "The run must stay valid after advancing off an already-cleared node (no duplicate_cleared_node).")
	assert_true(run.route.cleared_node_ids.has("node-1-0"), "node-1-0 must still be recorded as cleared exactly once.")


# ---- phase ping-pong sanity ----------------------------------------------------------------------

func _enter_then_exit_round_trips_the_phase() -> void:
	# A single enter -> exit cycle on a hand-built combat node leaves the run back in ACTIVE_ROUTE with
	# the node cleared and the pointer unchanged (the next advance moves off it).
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var combat: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, combat, boss], "node-1-0", ["node-0-0"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 99, false, true, route)

	assert_true(NodeEnterCommand.new().execute(run).succeeded, "Enter should succeed.")
	assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "After enter the run is in NODE_RESOLUTION.")
	assert_true(NodeExitCommand.new().execute(run).succeeded, "Exit should succeed.")
	assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "After exit the run is back in ACTIVE_ROUTE.")
	assert_equal(run.route.current_node_id, "node-1-0", "The pointer stays on the cleared node after exit.")
	assert_true(run.route.cleared_node_ids.has("node-1-0"), "The resolved node is cleared after exit.")
	assert_true(run.validate().succeeded, "The run is valid after a full enter/exit cycle.")
