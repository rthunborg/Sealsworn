extends "res://tests/unit/test_case.gd"

# Story 4.5 — NodeResolvePlaceholderCommand (the placeholder node RESOLUTION command). Covers AC1 (the two
# commands partition all 8 node types; combat/elite rejected here), AC2 (non-boss placeholder resolve ->
# NODE_RESOLUTION + node_placeholder_resolved, then NodeExitCommand exits it like a combat node), AC3 (boss
# placeholder resolve -> NODE_RESOLUTION -> COMPLETED + node_placeholder_resolved + run_completed, boss
# cleared, run terminal, NodeExitCommand on the COMPLETED boss rejects), plus the no-mutation stable-error
# rejections, no-RNG, and determinism discipline. The multi-seed start-to-COMPLETED walk lives in
# test_node_type_resolution_walk.gd.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const NodeEnterCommand = preload("res://scripts/core/commands/node_enter_command.gd")
const NodeExitCommand = preload("res://scripts/core/commands/node_exit_command.gd")
const NodeResolvePlaceholderCommand = preload("res://scripts/core/commands/node_resolve_placeholder_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The five non-combat placeholder types (boss is exercised separately by the boss-path tests).
const NON_BOSS_PLACEHOLDER_TYPES: Array[StringName] = [
	RouteNode.TYPE_SHOP,
	RouteNode.TYPE_REFORGE,
	RouteNode.TYPE_GAMBLING,
	RouteNode.TYPE_EVENT,
	RouteNode.TYPE_SECRET
]

func run() -> Dictionary:
	_resolves_each_non_boss_placeholder_then_exits_round_trips()
	_resolves_boss_to_completed_and_emits_run_completed()
	_boss_run_rejects_node_exit_after_completion()
	_rejects_wrong_phase_with_no_mutation()
	_rejects_no_current_node()
	_rejects_combat_and_elite_with_node_not_placeholder()
	_rejects_invalid_context()
	_rejects_non_positive_sequence_id_with_no_mutation()
	_resolve_draws_no_rng_on_success_and_reject()
	_resolve_is_deterministic()
	_placeholder_and_combat_sets_partition_all_node_types()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A run in PHASE_ACTIVE_ROUTE parked on a placeholder node (node-1-0) of the given type. The start is
# already cleared (the player advanced to node-1-0). node-1-0 links forward to the boss. Built DIRECTLY in
# ACTIVE_ROUTE (new_run() would reset current/cleared).
func _active_run_on_placeholder_node(node_type: StringName) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var node: RouteNode = RouteNode.new("node-1-0", node_type, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, node, boss], "node-1-0", ["node-0-0"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the active %s-node run should validate." % String(node_type))
	return run


# A run in PHASE_ACTIVE_ROUTE parked on the BOSS node (node-2-0). The start and a mid node are cleared.
func _active_run_on_boss_node() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var mid: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_CLEARED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, mid, boss], "node-2-0", ["node-0-0", "node-1-0"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 909, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the active boss-node run should validate.")
	return run


# ---- AC1 + AC2: non-boss placeholder resolve + exit round-trip -----------------------------------

func _resolves_each_non_boss_placeholder_then_exits_round_trips() -> void:
	# Every non-combat placeholder type resolves from ACTIVE_ROUTE -> NODE_RESOLUTION with one
	# node_placeholder_resolved event + NO cleared-set mutation, then NodeExitCommand exits it (clears +
	# back to ACTIVE_ROUTE) — proving the non-combat node round-trips exactly like a combat node.
	for placeholder_type: StringName in NON_BOSS_PLACEHOLDER_TYPES:
		var run: RunState = _active_run_on_placeholder_node(placeholder_type)

		var resolved: ActionResult = NodeResolvePlaceholderCommand.new().execute(run)
		assert_true(resolved.succeeded, "Resolving a %s placeholder from ACTIVE_ROUTE should succeed: %s" % [String(placeholder_type), resolved.metadata])

		# Phase transitioned ACTIVE_ROUTE -> NODE_RESOLUTION.
		assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "Resolving a %s placeholder should transition to NODE_RESOLUTION." % String(placeholder_type))
		# NO cleared-set mutation on resolve (the exit clears it; the start stays the only cleared node).
		assert_equal(run.route.cleared_node_ids, ["node-0-0"], "Placeholder resolve must NOT mutate the cleared set (%s)." % String(placeholder_type))
		# The node is NOT marked cleared yet (the exit does that).
		assert_equal(run.route.node_by_id("node-1-0").reveal_state, RouteNode.REVEAL_REVEALED, "Placeholder resolve must NOT clear the node's reveal state (%s)." % String(placeholder_type))
		# The pointer stays on the resolved node.
		assert_equal(run.route.current_node_id, "node-1-0", "Placeholder resolve leaves the pointer on the resolved node (%s)." % String(placeholder_type))
		# Post-resolve run still validates.
		assert_true(run.validate().succeeded, "A committed placeholder resolve should leave the run structurally valid (%s)." % String(placeholder_type))

		# Exactly one node_placeholder_resolved event with the right payload.
		assert_equal(resolved.events.size(), 1, "A non-boss placeholder resolve should emit exactly one event (%s)." % String(placeholder_type))
		var event: DomainEvent = resolved.events[0]
		assert_equal(event.event_type, DomainEvent.Type.NODE_PLACEHOLDER_RESOLVED, "The emitted event should be node_placeholder_resolved (%s)." % String(placeholder_type))
		assert_equal(String(event.actor_id), "", "node_placeholder_resolved is a system event with no actor (%s)." % String(placeholder_type))
		assert_equal(event.payload.get("node_id"), "node-1-0", "The event should carry the ORIGINAL hyphenated node id (%s)." % String(placeholder_type))
		assert_equal(event.payload.get("node_type"), String(placeholder_type), "The event should carry the node type (%s)." % String(placeholder_type))
		assert_equal(event.payload.get("node_depth"), 1, "The event should carry the node depth (%s)." % String(placeholder_type))
		assert_equal(event.payload.get("resolution"), "placeholder_completed", "The event should carry the stable placeholder_completed marker (%s)." % String(placeholder_type))
		# The emitted event is a valid DomainEvent (full payload-validation round-trip through real JSON).
		var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
		assert_true(parsed.succeeded, "The emitted node_placeholder_resolved event should pass payload validation (%s): %s" % [String(placeholder_type), parsed.metadata])

		# Metadata flag + fields.
		assert_true(bool(resolved.metadata.get("placeholder_resolved")), "Metadata should flag placeholder_resolved (%s)." % String(placeholder_type))
		assert_equal(resolved.metadata.get("node_id"), "node-1-0", "Metadata should carry the node id (%s)." % String(placeholder_type))
		assert_equal(resolved.metadata.get("resolution"), "placeholder_completed", "Metadata should carry the resolution marker (%s)." % String(placeholder_type))
		assert_false(bool(resolved.metadata.get("run_completed", false)), "A non-boss placeholder resolve must NOT flag run_completed (%s)." % String(placeholder_type))

		# Now exit it via the EXISTING NodeExitCommand — it round-trips exactly like a combat node.
		var exited: ActionResult = NodeExitCommand.new().execute(run)
		assert_true(exited.succeeded, "NodeExitCommand should exit a resolved %s placeholder: %s" % [String(placeholder_type), exited.metadata])
		assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Exit should move the run back to ACTIVE_ROUTE (%s)." % String(placeholder_type))
		assert_equal(run.route.node_by_id("node-1-0").reveal_state, RouteNode.REVEAL_CLEARED, "Exit should mark the placeholder node REVEAL_CLEARED (%s)." % String(placeholder_type))
		assert_true(run.route.cleared_node_ids.has("node-1-0"), "Exit should add the placeholder node to cleared_node_ids (%s)." % String(placeholder_type))
		assert_true(run.validate().succeeded, "The run must stay valid after a placeholder resolve + exit (%s)." % String(placeholder_type))
		# cleared_node_ids stays duplicate-free (resolve did not clear; only exit did).
		_assert_no_duplicate_cleared(run, String(placeholder_type))


# ---- AC3: boss placeholder run-end ----------------------------------------------------------------

func _resolves_boss_to_completed_and_emits_run_completed() -> void:
	var run: RunState = _active_run_on_boss_node()

	var resolved: ActionResult = NodeResolvePlaceholderCommand.new().execute(run)
	assert_true(resolved.succeeded, "Resolving the boss placeholder from ACTIVE_ROUTE should succeed: %s" % resolved.metadata)

	# Phase transitioned ACTIVE_ROUTE -> NODE_RESOLUTION -> COMPLETED (terminal).
	assert_equal(run.phase, RunState.PHASE_COMPLETED, "Resolving the boss placeholder should transition the run to COMPLETED.")
	assert_true(run.is_terminal(), "A boss-resolved run should be terminal.")
	# The boss node is marked cleared (BOTH reveal-state AND cleared_node_ids membership).
	assert_equal(run.route.node_by_id("node-2-0").reveal_state, RouteNode.REVEAL_CLEARED, "The boss node should be marked REVEAL_CLEARED.")
	assert_true(run.route.cleared_node_ids.has("node-2-0"), "The boss node should be in cleared_node_ids.")
	# Post-resolve run still validates structurally (no duplicate cleared id, pointer still a known node).
	assert_true(run.validate().succeeded, "A committed boss resolve should leave the run structurally valid.")
	_assert_no_duplicate_cleared(run, "boss")

	# Exactly two events: node_placeholder_resolved then run_completed, with distinct sequence ids.
	assert_equal(resolved.events.size(), 2, "A successful boss resolve should emit exactly two events (node_placeholder_resolved + run_completed).")
	var placeholder_event: DomainEvent = resolved.events[0]
	var run_completed_event: DomainEvent = resolved.events[1]
	assert_equal(placeholder_event.event_type, DomainEvent.Type.NODE_PLACEHOLDER_RESOLVED, "The first emitted event should be node_placeholder_resolved.")
	assert_equal(run_completed_event.event_type, DomainEvent.Type.RUN_COMPLETED, "The second emitted event should be run_completed.")
	assert_equal(String(placeholder_event.actor_id), "", "node_placeholder_resolved is a system event with no actor.")
	assert_equal(String(run_completed_event.actor_id), "", "run_completed is a system event with no actor.")
	assert_true(placeholder_event.sequence_id != run_completed_event.sequence_id, "The two boss events should have distinct sequence ids.")

	# node_placeholder_resolved payload (the boss IS a placeholder node too).
	assert_equal(placeholder_event.payload.get("node_id"), "node-2-0", "node_placeholder_resolved should carry the boss node id.")
	assert_equal(placeholder_event.payload.get("node_type"), "boss", "node_placeholder_resolved should carry the boss node type.")
	assert_equal(placeholder_event.payload.get("node_depth"), 2, "node_placeholder_resolved should carry the boss node depth.")
	assert_equal(placeholder_event.payload.get("resolution"), "placeholder_completed", "node_placeholder_resolved should carry the stable placeholder_completed marker.")

	# run_completed payload — the boss-placeholder run-end record with the EXACT stable outcome.
	assert_equal(run_completed_event.payload.get("outcome"), "boss_placeholder", "run_completed must carry the stable boss_placeholder outcome.")
	assert_equal(run_completed_event.payload.get("boss_node_id"), "node-2-0", "run_completed should carry the boss node id.")
	# cleared_node_count includes the boss (start + mid + boss = 3).
	assert_equal(run_completed_event.payload.get("cleared_node_count"), 3, "run_completed cleared_node_count should include the boss (start + mid + boss = 3).")
	assert_equal(run_completed_event.payload.get("cleared_node_count"), run.route.cleared_node_ids.size(), "run_completed cleared_node_count should equal the post-clear cleared set size.")

	# Constants pin the exact markers.
	assert_equal(String(NodeResolvePlaceholderCommand.RESOLUTION_PLACEHOLDER), "placeholder_completed", "RESOLUTION_PLACEHOLDER must be placeholder_completed.")
	assert_equal(String(NodeResolvePlaceholderCommand.BOSS_OUTCOME), "boss_placeholder", "BOSS_OUTCOME must be boss_placeholder.")

	# Both emitted events are valid DomainEvents (full payload-validation round-trip through real JSON).
	var placeholder_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(placeholder_event.to_dictionary())))
	assert_true(placeholder_parse.succeeded, "The emitted boss node_placeholder_resolved event should pass payload validation: %s" % placeholder_parse.metadata)
	var run_completed_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(run_completed_event.to_dictionary())))
	assert_true(run_completed_parse.succeeded, "The emitted run_completed event should pass payload validation: %s" % run_completed_parse.metadata)

	# Metadata flags.
	assert_true(bool(resolved.metadata.get("placeholder_resolved")), "Boss metadata should flag placeholder_resolved.")
	assert_true(bool(resolved.metadata.get("run_completed")), "Boss metadata should flag run_completed.")
	assert_equal(resolved.metadata.get("outcome"), "boss_placeholder", "Boss metadata should carry the outcome.")
	assert_equal(resolved.metadata.get("cleared_node_count"), 3, "Boss metadata should carry the cleared node count.")


func _boss_run_rejects_node_exit_after_completion() -> void:
	# The boss is the ONLY node that does not round-trip back to ACTIVE_ROUTE: it ends in COMPLETED
	# (terminal), from which NodeExitCommand correctly rejects with wrong_run_phase — the boss is never
	# exited back to a route choice.
	var run: RunState = _active_run_on_boss_node()
	assert_true(NodeResolvePlaceholderCommand.new().execute(run).succeeded, "Boss resolve should succeed.")
	assert_equal(run.phase, RunState.PHASE_COMPLETED, "The run should be COMPLETED after a boss resolve.")

	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = NodeExitCommand.new().execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "NodeExitCommand on a COMPLETED boss run should be rejected (the boss never exits).")
	assert_equal(rejected.error_code, &"wrong_run_phase", "Exiting a COMPLETED boss run should use the stable wrong_run_phase code.")
	assert_false(rejected.has_events(), "A rejected boss-run exit should emit zero events.")
	assert_equal(after, before, "A rejected boss-run exit must leave the run byte-identical.")


# ---- AC1/AC4: no-mutation rejections --------------------------------------------------------------

func _rejects_wrong_phase_with_no_mutation() -> void:
	# Every non-ACTIVE_ROUTE phase must reject placeholder resolution with wrong_run_phase + no mutation +
	# zero events. The two terminal phases are built DIRECTLY (unreachable via transition_to from a parked
	# choice).
	for phase: StringName in [
		RunState.PHASE_NEW_RUN,
		RunState.PHASE_NODE_RESOLUTION,
		RunState.PHASE_COMPLETED,
		RunState.PHASE_FAILED
	]:
		var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
		var shop: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
		var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
		var route: RouteState = RouteState.new([start, shop, boss], "node-1-0", ["node-0-0"])
		var run: RunState = RunState.new(phase, 5, false, true, route)
		assert_equal(run.phase, phase, "Setup: run should be in %s." % String(phase))
		assert_true(run.validate().succeeded, "Setup: the %s run should validate." % String(phase))

		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = NodeResolvePlaceholderCommand.new().execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "Resolution outside ACTIVE_ROUTE should be rejected (%s)." % String(phase))
		assert_equal(rejected.error_code, &"wrong_run_phase", "Wrong-phase resolution should use the stable code (%s)." % String(phase))
		assert_equal(rejected.metadata.get("phase"), String(phase), "Wrong-phase rejection should carry the actual phase (%s)." % String(phase))
		assert_equal(rejected.metadata.get("expected_phase"), String(RunState.PHASE_ACTIVE_ROUTE), "Wrong-phase rejection should carry the expected phase (%s)." % String(phase))
		assert_false(rejected.has_events(), "A rejected resolution should emit zero events (%s)." % String(phase))
		assert_equal(after, before, "A wrong-phase rejected resolution must leave the run byte-identical (%s)." % String(phase))


func _rejects_no_current_node() -> void:
	# A run in ACTIVE_ROUTE but not parked on a node cannot resolve one.
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var shop: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, shop], "", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 9, false, true, route)
	assert_equal(run.route.current_node_id, "", "Setup: the run is not parked on a node.")
	assert_true(run.validate().succeeded, "Setup: an empty-pointer ACTIVE_ROUTE run still validates.")

	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = NodeResolvePlaceholderCommand.new().execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(rejected.is_error(), "A resolution with no current node should be rejected.")
	assert_equal(rejected.error_code, &"no_current_node", "Not-parked resolution should use the stable no_current_node code.")
	assert_false(rejected.has_events(), "A rejected resolution should emit zero events.")
	assert_equal(after, before, "A not-parked rejected resolution must leave the run byte-identical.")


func _rejects_combat_and_elite_with_node_not_placeholder() -> void:
	# A combat/elite node is genuinely not this command's concern (it uses NodeEnterCommand). The
	# placeholder command rejects it with node_not_placeholder + no mutation + zero events.
	for combat_type: StringName in [RouteNode.TYPE_COMBAT, RouteNode.TYPE_ELITE_COMBAT]:
		var run: RunState = _active_run_on_placeholder_node(combat_type)  # builds a parked node of this type

		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = NodeResolvePlaceholderCommand.new().execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "Resolving a %s node via the placeholder command should be rejected." % String(combat_type))
		assert_equal(rejected.error_code, &"node_not_placeholder", "A combat node passed to the placeholder command should use node_not_placeholder (%s)." % String(combat_type))
		assert_equal(rejected.metadata.get("node_type"), String(combat_type), "The rejection should carry the offending node type (%s)." % String(combat_type))
		assert_equal(rejected.metadata.get("node_id"), "node-1-0", "The rejection should carry the node id in metadata (%s)." % String(combat_type))
		assert_false(rejected.has_events(), "A rejected resolution should emit zero events (%s)." % String(combat_type))
		assert_equal(after, before, "A node_not_placeholder rejection must leave the run byte-identical (%s)." % String(combat_type))


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context.
	var command: NodeResolvePlaceholderCommand = NodeResolvePlaceholderCommand.new()
	var not_a_run: ActionResult = command.execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is rejected as invalid_context + surfaces the inner
	# RouteState.validate() error.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_SHOP, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	var before_invalid: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = command.execute(run)
	var after_invalid: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner RouteState.validate() error code.")
	assert_false(invalid_run.has_events(), "An invalid-context rejection should emit zero events.")
	assert_equal(after_invalid, before_invalid, "An invalid-context rejection must leave the run byte-identical.")


func _rejects_non_positive_sequence_id_with_no_mutation() -> void:
	# Self-consistency gate: resolve builds node_placeholder_resolved (sequence_id) AND — for the boss —
	# run_completed (sequence_id + 1); both require > 0. A non-positive id must be rejected before any event
	# is built. Exercise it on BOTH a non-boss placeholder run AND a boss run.
	for bad_sequence_id: int in [0, -1, -2]:
		var shop_run: RunState = _active_run_on_placeholder_node(RouteNode.TYPE_SHOP)
		var shop_before: Dictionary = shop_run.to_dictionary()
		var shop_rejected: ActionResult = NodeResolvePlaceholderCommand.new(bad_sequence_id).execute(shop_run)
		var shop_after: Dictionary = shop_run.to_dictionary()
		assert_true(shop_rejected.is_error(), "A non-positive sequence id (%d) must be rejected (shop)." % bad_sequence_id)
		assert_equal(shop_rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d, shop)." % bad_sequence_id)
		assert_false(shop_rejected.has_events(), "A sequence-id rejection should emit zero events (%d, shop)." % bad_sequence_id)
		assert_equal(shop_after, shop_before, "A sequence-id rejection must leave the run byte-identical (%d, shop)." % bad_sequence_id)

		var boss_run: RunState = _active_run_on_boss_node()
		var boss_before: Dictionary = boss_run.to_dictionary()
		var boss_rejected: ActionResult = NodeResolvePlaceholderCommand.new(bad_sequence_id).execute(boss_run)
		var boss_after: Dictionary = boss_run.to_dictionary()
		assert_true(boss_rejected.is_error(), "A non-positive sequence id (%d) must be rejected (boss)." % bad_sequence_id)
		assert_equal(boss_rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d, boss)." % bad_sequence_id)
		assert_false(boss_rejected.has_events(), "A sequence-id rejection should emit zero events (%d, boss)." % bad_sequence_id)
		assert_equal(boss_after, boss_before, "A sequence-id rejection must leave the run byte-identical (%d, boss)." % bad_sequence_id)

	# validate() alone (pure read) also rejects a non-positive id.
	var validate_run: RunState = _active_run_on_placeholder_node(RouteNode.TYPE_SHOP)
	var validate_only: ActionResult = NodeResolvePlaceholderCommand.new(0).validate(validate_run)
	assert_true(validate_only.is_error(), "validate() should reject a non-positive sequence id directly.")
	assert_equal(validate_only.error_code, &"invalid_event_sequence_id", "validate() should surface the stable sequence-id code.")


# ---- determinism / no RNG -------------------------------------------------------------------------

func _resolve_draws_no_rng_on_success_and_reject() -> void:
	# Placeholder resolution draws ZERO RNG (no GenerationRequest is built; no stream is touched). Hold a
	# stream set, snapshot it, run a SUCCESSFUL non-boss resolve, a SUCCESSFUL boss resolve, and a REJECTED
	# resolve, and assert the streams are byte-identical in all cases.
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var before: Dictionary = streams.to_snapshot()

	var shop_run: RunState = _active_run_on_placeholder_node(RouteNode.TYPE_SHOP)
	NodeResolvePlaceholderCommand.new().execute(shop_run)
	assert_equal(streams.to_snapshot(), before, "A successful non-boss placeholder resolve must draw no RNG (stream set unchanged).")

	var boss_run: RunState = _active_run_on_boss_node()
	NodeResolvePlaceholderCommand.new().execute(boss_run)
	assert_equal(streams.to_snapshot(), before, "A successful boss resolve must draw no RNG (stream set unchanged).")

	# A rejected resolve (combat node) also draws no RNG.
	var reject_run: RunState = _active_run_on_placeholder_node(RouteNode.TYPE_COMBAT)
	NodeResolvePlaceholderCommand.new().execute(reject_run)
	assert_equal(streams.to_snapshot(), before, "A rejected resolve must draw no RNG (stream set unchanged).")


func _resolve_is_deterministic() -> void:
	# Same starting run + same command -> byte-identical resulting run.to_dictionary(), for BOTH the
	# non-boss and boss paths.
	var shop_a: RunState = _active_run_on_placeholder_node(RouteNode.TYPE_SHOP)
	var shop_b: RunState = _active_run_on_placeholder_node(RouteNode.TYPE_SHOP)
	NodeResolvePlaceholderCommand.new().execute(shop_a)
	NodeResolvePlaceholderCommand.new().execute(shop_b)
	assert_equal(shop_a.to_dictionary(), shop_b.to_dictionary(), "Non-boss placeholder resolve must be a deterministic state transition.")

	var boss_a: RunState = _active_run_on_boss_node()
	var boss_b: RunState = _active_run_on_boss_node()
	NodeResolvePlaceholderCommand.new().execute(boss_a)
	NodeResolvePlaceholderCommand.new().execute(boss_b)
	assert_equal(boss_a.to_dictionary(), boss_b.to_dictionary(), "Boss resolve must be a deterministic state transition.")


# ---- Task 3.2: complement-coverage ----------------------------------------------------------------

func _placeholder_and_combat_sets_partition_all_node_types() -> void:
	# NodeEnterCommand.NODE_TYPE_RECIPE (combat/elite) and NodeResolvePlaceholderCommand.PLACEHOLDER_NODE_
	# TYPES (everything else, incl. boss) together cover EXACTLY RouteNode.supported_types() with NO overlap
	# and NO gap — so every one of the 8 types has exactly one resolution path and no node type can ever be
	# a dead end.
	var combat_keys: Array = NodeEnterCommand.NODE_TYPE_RECIPE.keys()
	var placeholder_keys: Array = NodeResolvePlaceholderCommand.PLACEHOLDER_NODE_TYPES.keys()
	var supported: Array[StringName] = RouteNode.supported_types()

	# No overlap: no type is in BOTH sets.
	for combat_type: Variant in combat_keys:
		assert_false(NodeResolvePlaceholderCommand.PLACEHOLDER_NODE_TYPES.has(combat_type), "A combat type (%s) must NOT be in the placeholder set (no overlap)." % String(combat_type))

	# Union covers exactly supported_types() — every supported type is in exactly one set.
	var union: Dictionary = {}
	for combat_type: Variant in combat_keys:
		union[combat_type] = true
	for placeholder_type: Variant in placeholder_keys:
		union[placeholder_type] = true
	assert_equal(union.size(), supported.size(), "The combat + placeholder sets must cover exactly all %d supported types (no gap)." % supported.size())
	for supported_type: StringName in supported:
		assert_true(union.has(supported_type), "Every supported type (%s) must be covered by exactly one command." % String(supported_type))

	# The combat set is exactly {combat, elite_combat}; the placeholder set is the remaining 6 incl. boss.
	assert_equal(combat_keys.size(), 2, "The combat set should be exactly two types (combat, elite_combat).")
	assert_true(NodeResolvePlaceholderCommand.PLACEHOLDER_NODE_TYPES.has(RouteNode.TYPE_BOSS), "The placeholder set must include boss.")
	for non_boss_type: StringName in NON_BOSS_PLACEHOLDER_TYPES:
		assert_true(NodeResolvePlaceholderCommand.PLACEHOLDER_NODE_TYPES.has(non_boss_type), "The placeholder set must include %s." % String(non_boss_type))


# ---- shared assertions ----------------------------------------------------------------------------

func _assert_no_duplicate_cleared(run: RunState, label: String) -> void:
	var seen: Dictionary = {}
	for cleared_id: String in run.route.cleared_node_ids:
		assert_false(seen.has(cleared_id), "cleared_node_ids must never duplicate (%s at %s)." % [cleared_id, label])
		seen[cleared_id] = true
