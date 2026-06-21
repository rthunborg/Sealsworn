extends "res://tests/unit/test_case.gd"

# Story 4.5 — the start-to-COMPLETED TYPE-DISPATCH walk (Task 4 / 7.5). This is the load-bearing
# AC1/AC2/AC3 no-soft-lock / no-broken-gameplay proof: on 4.2-generated routes, walk start -> boss
# DISPATCHING BY NODE TYPE — NodeEnterCommand + NodeExitCommand for combat/elite, NodeResolvePlaceholder
# Command (+ NodeExitCommand) for the five non-combat types, NodeResolvePlaceholderCommand (-> COMPLETED)
# for the boss — with RouteAdvanceCommand stepping to the next eligible choice between nodes.
#
# It asserts at EVERY step: run.validate() is green, the phase ping-pongs ACTIVE_ROUTE <-> NODE_RESOLUTION
# correctly, cleared_node_ids NEVER duplicates, and a non-boss node ALWAYS has an eligible forward choice
# (no soft-lock through ANY node type). Each seed reaches PHASE_COMPLETED with exactly one run_completed
# event (outcome == "boss_placeholder"), and across the seed set at least one NON-combat placeholder node
# is genuinely resolved (so AC2's placeholder path is exercised, not vacuously skipped). A single-type walk
# would miss the "every node type resolves safely" guarantee; this walk dispatches by type.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const NodeEnterCommand = preload("res://scripts/core/commands/node_enter_command.gd")
const NodeExitCommand = preload("res://scripts/core/commands/node_exit_command.gd")
const NodeResolvePlaceholderCommand = preload("res://scripts/core/commands/node_resolve_placeholder_command.gd")
const RouteAdvanceCommand = preload("res://scripts/core/commands/route_advance_command.gd")
const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# Representative seeds (the 4.4 walk set [1, 7, 42, 2026] plus a few more so the interior actually hits a
# VARIETY of node types — shop/reforge/gambling/event/secret — not only combat across the set).
const WALK_SEEDS: Array[int] = [1, 7, 42, 2026, 13, 99, 314, 777]

func run() -> Dictionary:
	_type_dispatch_walk_to_completed_for_every_seed()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# Build a RunState parked on the start node of a freshly generated route, in PHASE_ACTIVE_ROUTE (mirrors
# test_node_flow_walk.gd::_active_run_for_seed — new_run() then transition_to(ACTIVE_ROUTE)).
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


# ---- the type-dispatch walk -----------------------------------------------------------------------

func _type_dispatch_walk_to_completed_for_every_seed() -> void:
	var total_non_combat_resolved: int = 0
	var node_types_resolved: Dictionary = {}  # union of placeholder types resolved across the seed set

	for seed_value: int in WALK_SEEDS:
		var run: RunState = _active_run_for_seed(seed_value)
		var steps: int = 0
		var max_steps: int = 64  # generous guard; the boss is at a fixed shallow depth (depth 7).
		var reached_completed: bool = false
		var run_completed_event_count: int = 0
		var run_completed_outcome: String = ""

		while steps < max_steps:
			var current: RouteNode = run.route.node_by_id(run.route.current_node_id)
			assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: the walk should be in ACTIVE_ROUTE before resolving at step %d." % [seed_value, steps])

			if current.type == RouteNode.TYPE_BOSS:
				# Boss: resolve through NodeResolvePlaceholderCommand to COMPLETED. No exit follows.
				var boss_resolved: ActionResult = NodeResolvePlaceholderCommand.new().execute(run)
				assert_true(boss_resolved.succeeded, "Seed %d: resolving the boss should succeed at step %d: %s" % [seed_value, steps, boss_resolved.metadata])
				assert_equal(run.phase, RunState.PHASE_COMPLETED, "Seed %d: boss resolve should move the run to COMPLETED at step %d." % [seed_value, steps])
				assert_true(run.is_terminal(), "Seed %d: the run should be terminal after the boss resolve." % seed_value)
				assert_true(run.route.cleared_node_ids.has(current.id), "Seed %d: the boss should be cleared after resolve." % seed_value)
				assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after the boss resolve." % seed_value)
				_assert_no_duplicate_cleared(run, seed_value, steps)
				# Count + capture the run_completed event.
				for event: DomainEvent in boss_resolved.events:
					if event.event_type == DomainEvent.Type.RUN_COMPLETED:
						run_completed_event_count += 1
						run_completed_outcome = String(event.payload.get("outcome"))
						# cleared_node_count must equal the final cleared-set size (incl. the boss).
						assert_equal(event.payload.get("cleared_node_count"), run.route.cleared_node_ids.size(), "Seed %d: run_completed cleared_node_count must equal the final cleared set size." % seed_value)
				reached_completed = true
				break

			if _is_combat_type(current.type):
				# Combat/elite: full enter -> exit cycle.
				var enter: ActionResult = NodeEnterCommand.new().execute(run)
				assert_true(enter.succeeded, "Seed %d: entering the combat node should succeed at step %d: %s" % [seed_value, steps, enter.metadata])
				assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "Seed %d: entry should move the run to NODE_RESOLUTION at step %d." % [seed_value, steps])
				assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after entry at step %d." % [seed_value, steps])

				var exit: ActionResult = NodeExitCommand.new().execute(run)
				assert_true(exit.succeeded, "Seed %d: exiting the resolved combat node should succeed at step %d: %s" % [seed_value, steps, exit.metadata])
				assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: exit should move the run back to ACTIVE_ROUTE at step %d." % [seed_value, steps])
				assert_true(run.route.cleared_node_ids.has(current.id), "Seed %d: the exited combat node should be cleared at step %d." % [seed_value, steps])
				assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after combat exit at step %d." % [seed_value, steps])
				_assert_no_duplicate_cleared(run, seed_value, steps)
			else:
				# Non-combat placeholder (shop/reforge/gambling/event/secret): resolve -> exit cycle.
				var resolved: ActionResult = NodeResolvePlaceholderCommand.new().execute(run)
				assert_true(resolved.succeeded, "Seed %d: resolving the %s placeholder should succeed at step %d: %s" % [seed_value, String(current.type), steps, resolved.metadata])
				assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "Seed %d: placeholder resolve should move the run to NODE_RESOLUTION at step %d." % [seed_value, steps])
				assert_false(bool(resolved.metadata.get("run_completed", false)), "Seed %d: a non-boss placeholder resolve must NOT complete the run at step %d." % [seed_value, steps])
				# Resolve did NOT clear the node (exit does that).
				assert_false(run.route.cleared_node_ids.has(current.id), "Seed %d: a non-boss placeholder resolve must NOT clear the node (the exit does) at step %d." % [seed_value, steps])
				assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after placeholder resolve at step %d." % [seed_value, steps])
				# Emitted exactly one node_placeholder_resolved event.
				assert_equal(resolved.events.size(), 1, "Seed %d: a non-boss placeholder resolve should emit one event at step %d." % [seed_value, steps])
				assert_equal(resolved.events[0].event_type, DomainEvent.Type.NODE_PLACEHOLDER_RESOLVED, "Seed %d: the emitted event should be node_placeholder_resolved at step %d." % [seed_value, steps])

				var exit: ActionResult = NodeExitCommand.new().execute(run)
				assert_true(exit.succeeded, "Seed %d: exiting the resolved %s placeholder should succeed at step %d: %s" % [seed_value, String(current.type), steps, exit.metadata])
				assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: exit should move the run back to ACTIVE_ROUTE at step %d." % [seed_value, steps])
				assert_true(run.route.cleared_node_ids.has(current.id), "Seed %d: the exited %s placeholder should be cleared at step %d." % [seed_value, String(current.type), steps])
				assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after placeholder exit at step %d." % [seed_value, steps])
				_assert_no_duplicate_cleared(run, seed_value, steps)
				total_non_combat_resolved += 1
				node_types_resolved[current.type] = true

			# Advance to the first eligible choice (a non-boss node must ALWAYS have one — no soft-lock).
			var eligible: Array[String] = run.route.eligible_choice_ids()
			assert_true(not eligible.is_empty(), "Seed %d: a non-boss node must always have an eligible choice (no soft-lock) at step %d." % [seed_value, steps])
			var advance: ActionResult = RouteAdvanceCommand.new(eligible[0]).execute(run)
			assert_true(advance.succeeded, "Seed %d: advancing to an eligible choice should succeed at step %d: %s" % [seed_value, steps, advance.metadata])
			assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: advance keeps the run in ACTIVE_ROUTE at step %d." % [seed_value, steps])
			assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after each advance at step %d." % [seed_value, steps])
			_assert_no_duplicate_cleared(run, seed_value, steps)
			steps += 1

		assert_true(reached_completed, "Seed %d: the walk should reach PHASE_COMPLETED within the step guard." % seed_value)
		assert_equal(run_completed_event_count, 1, "Seed %d: the walk should emit exactly one run_completed event." % seed_value)
		assert_equal(run_completed_outcome, "boss_placeholder", "Seed %d: the run_completed outcome should be boss_placeholder." % seed_value)

	# Across the seed set, AC2's placeholder path must be genuinely exercised (>= 1 non-combat resolve).
	assert_true(total_non_combat_resolved >= 1, "The walk should resolve at least one NON-combat placeholder node across the seed set (AC2 genuinely exercised); resolved %d." % total_non_combat_resolved)


func _assert_no_duplicate_cleared(run: RunState, seed_value: int, step: int) -> void:
	var seen: Dictionary = {}
	for cleared_id: String in run.route.cleared_node_ids:
		assert_false(seen.has(cleared_id), "Seed %d: cleared_node_ids must never duplicate (%s at step %d)." % [seed_value, cleared_id, step])
		seen[cleared_id] = true
