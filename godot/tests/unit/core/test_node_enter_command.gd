extends "res://tests/unit/test_case.gd"

# Story 4.4 — NodeEnterCommand (the node ENTRY command). Covers AC1 (build + validate the level
# GenerationRequest, transition ACTIVE_ROUTE -> NODE_RESOLUTION, emit node_entered) and AC4 (no-mutation
# stable-error rejections: wrong phase, not parked, unsupported node type, invalid context, bad sequence
# id, invalid level request), plus the no-RNG + determinism discipline.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const NodeEnterCommand = preload("res://scripts/core/commands/node_enter_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_successful_enter_builds_request_transitions_and_emits_event()
	_elite_combat_node_maps_to_medium_recipe()
	_rejects_wrong_phase_with_no_mutation()
	_rejects_no_current_node()
	_rejects_unsupported_node_type_with_no_mutation()
	_rejects_invalid_context()
	_rejects_non_positive_sequence_id_with_no_mutation()
	_enter_draws_no_rng_on_success_and_reject()
	_enter_is_deterministic()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A small hand-built run parked on a COMBAT node (node-1-0) in PHASE_ACTIVE_ROUTE. The start has
# already been cleared (the player advanced to node-1-0). node-1-0 links forward to the boss.
func _active_run_on_combat_node() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var combat: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
	# Build the run DIRECTLY in ACTIVE_ROUTE parked on node-1-0 with the start pre-cleared (new_run()
	# would reset current/cleared to a fresh-run state).
	var route: RouteState = RouteState.new([start, combat, boss], "node-1-0", ["node-0-0"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the active combat-node run should validate.")
	return run


# A run parked on an ELITE_COMBAT node (node-1-0) in PHASE_ACTIVE_ROUTE.
func _active_run_on_elite_node() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var elite: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_ELITE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, elite, boss], "node-1-0", ["node-0-0"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 777, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the active elite-node run should validate.")
	return run


# ---- AC1: successful enter -----------------------------------------------------------------------

func _successful_enter_builds_request_transitions_and_emits_event() -> void:
	var run: RunState = _active_run_on_combat_node()

	var command: NodeEnterCommand = NodeEnterCommand.new()
	var entered: ActionResult = command.execute(run)
	assert_true(entered.succeeded, "Entering a combat node from ACTIVE_ROUTE should succeed: %s" % entered.metadata)

	# Phase transitioned ACTIVE_ROUTE -> NODE_RESOLUTION.
	assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "Node entry should transition the run to NODE_RESOLUTION.")
	# No cleared-set mutation on ENTER (exit clears; the start stays the only cleared node).
	assert_equal(run.route.cleared_node_ids, ["node-0-0"], "Node entry must NOT mutate the cleared set.")
	# The pointer stays on the entered node.
	assert_equal(run.route.current_node_id, "node-1-0", "Node entry leaves the pointer on the entered node.")

	# Exactly one node_entered event with the right payload.
	assert_equal(entered.events.size(), 1, "A successful enter should emit exactly one event.")
	var event: DomainEvent = entered.events[0]
	assert_equal(event.event_type, DomainEvent.Type.NODE_ENTERED, "The emitted event should be node_entered.")
	assert_equal(String(event.actor_id), "", "node_entered is a system event with no actor.")
	assert_equal(event.payload.get("node_id"), "node-1-0", "Event should carry the ORIGINAL hyphenated node id.")
	assert_equal(event.payload.get("node_type"), "combat", "Event should carry the node type.")
	assert_equal(event.payload.get("node_depth"), 1, "Event should carry the node depth.")
	assert_equal(event.payload.get("level_request_node_id"), "node_1_0", "Event should carry the DERIVED lower_snake request id.")
	assert_equal(event.payload.get("recipe_id"), "small_combat_basic", "A combat node maps to small_combat_basic.")
	assert_equal(event.payload.get("size_class"), "small", "A combat node maps to the Small size class.")
	# The emitted event is a valid DomainEvent (full payload-validation round-trip through real JSON).
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "The emitted node_entered event should pass payload validation: %s" % parsed.metadata)

	# Metadata carries the live, VALID GenerationRequest + the derived/original ids.
	assert_true(bool(entered.metadata.get("enters_node")), "Metadata should flag enters_node.")
	var request_value: Variant = entered.metadata.get("level_request")
	assert_true(request_value is GenerationRequest, "Metadata should carry the live GenerationRequest.")
	var request: GenerationRequest = request_value as GenerationRequest
	assert_true(request.validate().succeeded, "The built level request must be valid: %s" % request.validate().metadata)
	assert_equal(String(request.node_id), "node_1_0", "The request node id should be the derived lower_snake id.")
	assert_equal(String(request.node_type), "combat", "The request node type should be the route node type.")
	assert_equal(String(request.recipe_id), "small_combat_basic", "The request recipe should be small_combat_basic.")
	assert_equal(String(request.size_class), "small", "The request size class should be Small.")
	assert_equal(request.root_seed, 4242, "The request root seed should be the run root seed (un-mangled).")
	assert_equal(entered.metadata.get("node_id"), "node-1-0", "Metadata should preserve the original hyphenated id.")

	# Post-enter run still validates structurally.
	assert_true(run.validate().succeeded, "A committed enter should leave the run structurally valid.")


func _elite_combat_node_maps_to_medium_recipe() -> void:
	var run: RunState = _active_run_on_elite_node()
	var entered: ActionResult = NodeEnterCommand.new().execute(run)
	assert_true(entered.succeeded, "Entering an elite node should succeed: %s" % entered.metadata)
	var request: GenerationRequest = entered.metadata.get("level_request") as GenerationRequest
	assert_equal(String(request.recipe_id), "medium_combat_basic", "An elite node maps to medium_combat_basic.")
	assert_equal(String(request.size_class), "medium", "An elite node maps to the Medium size class.")
	assert_equal(entered.events[0].payload.get("recipe_id"), "medium_combat_basic", "The event should carry the medium recipe.")


# ---- AC4: no-mutation rejections -----------------------------------------------------------------

func _rejects_wrong_phase_with_no_mutation() -> void:
	# Every non-ACTIVE_ROUTE phase must reject node entry with wrong_run_phase + no mutation + zero
	# events. The two terminal phases are built DIRECTLY (unreachable via transition_to from a parked
	# choice).
	for phase: StringName in [
		RunState.PHASE_NEW_RUN,
		RunState.PHASE_NODE_RESOLUTION,
		RunState.PHASE_COMPLETED,
		RunState.PHASE_FAILED
	]:
		var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
		var combat: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
		var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
		var route: RouteState = RouteState.new([start, combat, boss], "node-1-0", ["node-0-0"])
		var run: RunState = RunState.new(phase, 5, false, true, route)
		assert_equal(run.phase, phase, "Setup: run should be in %s." % String(phase))
		assert_true(run.validate().succeeded, "Setup: the %s run should validate." % String(phase))

		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = NodeEnterCommand.new().execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "Entry outside ACTIVE_ROUTE should be rejected (%s)." % String(phase))
		assert_equal(rejected.error_code, &"wrong_run_phase", "Wrong-phase entry should use the stable code (%s)." % String(phase))
		assert_equal(rejected.metadata.get("phase"), String(phase), "Wrong-phase rejection should carry the actual phase (%s)." % String(phase))
		assert_equal(rejected.metadata.get("expected_phase"), String(RunState.PHASE_ACTIVE_ROUTE), "Wrong-phase rejection should carry the expected phase (%s)." % String(phase))
		assert_false(rejected.has_events(), "A rejected entry should emit zero events (%s)." % String(phase))
		assert_equal(after, before, "A wrong-phase rejected entry must leave the run byte-identical (%s)." % String(phase))


func _rejects_no_current_node() -> void:
	# A run in ACTIVE_ROUTE but not parked on a node cannot enter one.
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var a: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, a], "", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 9, false, true, route)
	assert_equal(run.route.current_node_id, "", "Setup: the run is not parked on a node.")

	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = NodeEnterCommand.new().execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(rejected.is_error(), "An entry with no current node should be rejected.")
	assert_equal(rejected.error_code, &"no_current_node", "Not-parked entry should use the stable no_current_node code.")
	assert_false(rejected.has_events(), "A rejected entry should emit zero events.")
	assert_equal(after, before, "A not-parked rejected entry must leave the run byte-identical.")


func _rejects_unsupported_node_type_with_no_mutation() -> void:
	# A non-combat node (shop) is out of this story's ENTRY scope (per-type resolution is Story 4.5).
	# Cover a representative set of the non-combat MVP types.
	for unsupported_type: StringName in [
		RouteNode.TYPE_SHOP,
		RouteNode.TYPE_REFORGE,
		RouteNode.TYPE_GAMBLING,
		RouteNode.TYPE_EVENT,
		RouteNode.TYPE_SECRET,
		RouteNode.TYPE_BOSS
	]:
		var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
		var node: RouteNode = RouteNode.new("node-1-0", unsupported_type, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
		var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
		var route: RouteState = RouteState.new([start, node, boss], "node-1-0", ["node-0-0"])
		var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 11, false, true, route)
		assert_true(run.validate().succeeded, "Setup: the %s-node run should validate." % String(unsupported_type))

		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = NodeEnterCommand.new().execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "Entering a %s node should be rejected (out of scope)." % String(unsupported_type))
		assert_equal(rejected.error_code, &"unsupported_node_entry", "Unsupported-type entry should use the stable code (%s)." % String(unsupported_type))
		assert_equal(rejected.metadata.get("node_type"), String(unsupported_type), "The rejection should carry the offending node type (%s)." % String(unsupported_type))
		assert_equal(rejected.metadata.get("node_id"), "node-1-0", "The rejection should carry the node id in metadata (%s)." % String(unsupported_type))
		assert_false(rejected.has_events(), "A rejected entry should emit zero events (%s)." % String(unsupported_type))
		assert_equal(after, before, "An unsupported-type rejected entry must leave the run byte-identical (%s)." % String(unsupported_type))


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context (no crash, no mutation possible).
	var command: NodeEnterCommand = NodeEnterCommand.new()
	var not_a_run: ActionResult = command.execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is rejected as invalid_context, AND surfaces the
	# inner RouteState.validate() error for diagnosis.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	var before_invalid: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = command.execute(run)
	var after_invalid: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner RouteState.validate() error code for diagnosis.")
	assert_false(invalid_run.has_events(), "An invalid-context rejection should emit zero events.")
	assert_equal(after_invalid, before_invalid, "An invalid-context rejection must leave the run byte-identical.")


func _rejects_non_positive_sequence_id_with_no_mutation() -> void:
	# Self-consistency gate: execute() builds a node_entered event with the caller-supplied sequence id,
	# and DomainEvent.try_from_dictionary requires sequence_id > 0. A non-positive id must be rejected
	# BEFORE the event is built; the rejection leaves the run byte-identical with zero events.
	for bad_sequence_id: int in [0, -1]:
		var run: RunState = _active_run_on_combat_node()
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = NodeEnterCommand.new(bad_sequence_id).execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_equal(rejected.metadata.get("sequence_id"), bad_sequence_id, "The rejection should echo the offending sequence id.")
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)

	# validate() alone (pure read) also rejects a non-positive id.
	var validate_run: RunState = _active_run_on_combat_node()
	var validate_only: ActionResult = NodeEnterCommand.new(0).validate(validate_run)
	assert_true(validate_only.is_error(), "validate() should reject a non-positive sequence id directly.")
	assert_equal(validate_only.error_code, &"invalid_event_sequence_id", "validate() should surface the stable sequence-id code.")


# ---- AC1: determinism / no RNG -------------------------------------------------------------------

func _enter_draws_no_rng_on_success_and_reject() -> void:
	# Node entry draws ZERO RNG (building a request is pure; the `level` stream is drawn by generation
	# LATER, not here). Hold a stream set, snapshot it, run a SUCCESSFUL enter and a REJECTED enter, and
	# assert the streams are byte-identical in both cases.
	var streams: RngStreamSet = RngStreamSet.new(24680)
	var before: Dictionary = streams.to_snapshot()

	var run: RunState = _active_run_on_combat_node()
	NodeEnterCommand.new().execute(run)
	assert_equal(streams.to_snapshot(), before, "A successful enter must draw no RNG (stream set unchanged).")

	# A rejected enter (wrong phase via a NODE_RESOLUTION run) also draws no RNG.
	var reject_run: RunState = _active_run_on_combat_node()
	reject_run.transition_to(RunState.PHASE_NODE_RESOLUTION)
	NodeEnterCommand.new().execute(reject_run)
	assert_equal(streams.to_snapshot(), before, "A rejected enter must draw no RNG (stream set unchanged).")


func _enter_is_deterministic() -> void:
	# Same starting run + same command -> byte-identical resulting run.to_dictionary().
	var run_a: RunState = _active_run_on_combat_node()
	var run_b: RunState = _active_run_on_combat_node()
	NodeEnterCommand.new().execute(run_a)
	NodeEnterCommand.new().execute(run_b)
	assert_equal(run_a.to_dictionary(), run_b.to_dictionary(), "Node entry must be a deterministic state transition.")
