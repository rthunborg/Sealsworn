extends "res://tests/unit/test_case.gd"

# Story 4.4 — NodeExitCommand (the node EXIT command). Covers AC2 (mark resolved node cleared, transition
# NODE_RESOLUTION -> ACTIVE_ROUTE, node_exited event, rewards-placeholder flag, autosave seam), AC3
# (route_sealed door-sealed cue carrying door_sealed_placeholder), and AC4 (no-mutation stable-error
# rejections), plus the no-RNG + determinism + post-exit validate discipline and the persistence
# round-trip (Task 7.4).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const NodeExitCommand = preload("res://scripts/core/commands/node_exit_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_successful_exit_clears_node_transitions_and_emits_both_events()
	_exit_records_rewards_placeholder_and_autosave_seam()
	_rejects_wrong_phase_with_no_mutation()
	_rejects_no_current_node()
	_rejects_invalid_context()
	_rejects_non_positive_sequence_id_with_no_mutation()
	_exit_draws_no_rng_on_success_and_reject()
	_exit_is_deterministic()
	_post_exit_run_round_trips_through_run_snapshot()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A run in PHASE_NODE_RESOLUTION parked on the resolved combat node (node-1-0). The start is already
# cleared (the player advanced to and then entered node-1-0). node-1-0 links forward to the boss.
func _resolving_run_on_combat_node() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var combat: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
	# Build the run DIRECTLY in NODE_RESOLUTION parked on node-1-0 (new_run() would reset current/cleared).
	var route: RouteState = RouteState.new([start, combat, boss], "node-1-0", ["node-0-0"])
	var run: RunState = RunState.new(RunState.PHASE_NODE_RESOLUTION, 4242, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the resolving combat-node run should validate.")
	return run


# ---- AC2 + AC3: successful exit ------------------------------------------------------------------

func _successful_exit_clears_node_transitions_and_emits_both_events() -> void:
	var run: RunState = _resolving_run_on_combat_node()

	var command: NodeExitCommand = NodeExitCommand.new()
	var exited: ActionResult = command.execute(run)
	assert_true(exited.succeeded, "Exiting a resolved node from NODE_RESOLUTION should succeed: %s" % exited.metadata)

	# Phase transitioned NODE_RESOLUTION -> ACTIVE_ROUTE.
	assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Node exit should transition the run back to ACTIVE_ROUTE.")
	# The resolved node is marked cleared (BOTH reveal-state AND cleared_node_ids membership).
	assert_equal(run.route.node_by_id("node-1-0").reveal_state, RouteNode.REVEAL_CLEARED, "The exited node should be marked REVEAL_CLEARED.")
	assert_true(run.route.cleared_node_ids.has("node-1-0"), "The exited node should be in cleared_node_ids.")
	# The pointer STAYS on the just-cleared node (the next advance moves off it).
	assert_equal(run.route.current_node_id, "node-1-0", "Node exit leaves the pointer on the just-cleared node.")
	# Post-exit run still validates structurally (no duplicate cleared id, pointer still a known node).
	assert_true(run.validate().succeeded, "A committed exit should leave the run structurally valid (no duplicate cleared id).")

	# Exactly two events: node_exited then route_sealed, with distinct sequence ids.
	assert_equal(exited.events.size(), 2, "A successful exit should emit exactly two events (node_exited + route_sealed).")
	var exited_event: DomainEvent = exited.events[0]
	var sealed_event: DomainEvent = exited.events[1]
	assert_equal(exited_event.event_type, DomainEvent.Type.NODE_EXITED, "The first emitted event should be node_exited.")
	assert_equal(sealed_event.event_type, DomainEvent.Type.ROUTE_SEALED, "The second emitted event should be route_sealed.")
	assert_equal(String(exited_event.actor_id), "", "node_exited is a system event with no actor.")
	assert_equal(String(sealed_event.actor_id), "", "route_sealed is a system event with no actor.")
	assert_true(exited_event.sequence_id != sealed_event.sequence_id, "The two exit events should have distinct sequence ids.")

	# node_exited payload.
	assert_equal(exited_event.payload.get("node_id"), "node-1-0", "node_exited should carry the resolved node id.")
	assert_equal(exited_event.payload.get("node_type"), "combat", "node_exited should carry the node type.")
	assert_equal(exited_event.payload.get("node_depth"), 1, "node_exited should carry the node depth.")
	assert_equal(exited_event.payload.get("rewards_placeholder"), true, "node_exited should flag rewards_placeholder for a combat node.")

	# route_sealed payload — the door-sealed containment cue with the EXACT stable cue id.
	assert_equal(sealed_event.payload.get("node_id"), "node-1-0", "route_sealed should carry the sealed node id.")
	assert_equal(sealed_event.payload.get("cue_id"), "door_sealed_placeholder", "route_sealed must carry the stable door_sealed_placeholder cue id.")
	assert_equal(String(NodeExitCommand.DOOR_SEALED_CUE), "door_sealed_placeholder", "The door-cue constant must be door_sealed_placeholder.")

	# Both emitted events are valid DomainEvents (full payload-validation round-trip through real JSON).
	var exited_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(exited_event.to_dictionary())))
	assert_true(exited_parse.succeeded, "The emitted node_exited event should pass payload validation: %s" % exited_parse.metadata)
	var sealed_parse: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(sealed_event.to_dictionary())))
	assert_true(sealed_parse.succeeded, "The emitted route_sealed event should pass payload validation: %s" % sealed_parse.metadata)


func _exit_records_rewards_placeholder_and_autosave_seam() -> void:
	var run: RunState = _resolving_run_on_combat_node()
	var exited: ActionResult = NodeExitCommand.new().execute(run)
	assert_true(exited.succeeded, "Exit should succeed: %s" % exited.metadata)

	# AC2 rewards-placeholder flag in metadata (combat earns a reward at the boundary).
	assert_true(bool(exited.metadata.get("exits_node")), "Metadata should flag exits_node.")
	assert_equal(exited.metadata.get("rewards_placeholder"), true, "Metadata should flag rewards_placeholder for a combat node.")

	# AC2 autosave seam: autosave_requested + the route-side to_run_snapshot_fields() payload.
	assert_equal(exited.metadata.get("autosave_requested"), true, "Metadata should advertise autosave_requested.")
	var fields_value: Variant = exited.metadata.get("run_snapshot_fields")
	assert_true(fields_value is Dictionary, "Metadata should carry the route-side run_snapshot_fields for the caller to autosave.")
	var fields: Dictionary = fields_value
	assert_equal(fields.get("current_route_node_id"), "node-1-0", "The autosave fields should reflect the current node.")
	assert_true(fields.has("route_state"), "The autosave fields should carry the route_state payload.")
	var route_payload: Dictionary = fields.get("route_state")
	assert_equal(route_payload.get("run_phase"), "active_route", "The autosave fields should nest the post-exit phase (active_route) under route_state.")
	var revealed: Array = fields.get("revealed_route_node_ids")
	assert_true(revealed.has("node-1-0"), "The cleared resolved node surfaces in revealed_route_node_ids (revealed-or-cleared).")


# ---- AC4: no-mutation rejections -----------------------------------------------------------------

func _rejects_wrong_phase_with_no_mutation() -> void:
	# Every non-NODE_RESOLUTION phase must reject node exit with wrong_run_phase + no mutation + zero
	# events.
	for phase: StringName in [
		RunState.PHASE_ACTIVE_ROUTE,
		RunState.PHASE_NEW_RUN,
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
		var rejected: ActionResult = NodeExitCommand.new().execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "Exit outside NODE_RESOLUTION should be rejected (%s)." % String(phase))
		assert_equal(rejected.error_code, &"wrong_run_phase", "Wrong-phase exit should use the stable code (%s)." % String(phase))
		assert_equal(rejected.metadata.get("phase"), String(phase), "Wrong-phase rejection should carry the actual phase (%s)." % String(phase))
		assert_equal(rejected.metadata.get("expected_phase"), String(RunState.PHASE_NODE_RESOLUTION), "Wrong-phase rejection should carry the expected phase (%s)." % String(phase))
		assert_false(rejected.has_events(), "A rejected exit should emit zero events (%s)." % String(phase))
		assert_equal(after, before, "A wrong-phase rejected exit must leave the run byte-identical (%s)." % String(phase))


func _rejects_no_current_node() -> void:
	# A run in NODE_RESOLUTION but not parked on a node cannot exit one. (NODE_RESOLUTION is reachable
	# from ACTIVE_ROUTE; drive the run there along legal edges, then clear the pointer for the test.)
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var a: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, a], "", [])
	var run: RunState = RunState.new(RunState.PHASE_NODE_RESOLUTION, 9, false, true, route)
	assert_equal(run.route.current_node_id, "", "Setup: the run is not parked on a node.")
	assert_true(run.validate().succeeded, "Setup: an empty-pointer NODE_RESOLUTION run still validates.")

	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = NodeExitCommand.new().execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(rejected.is_error(), "An exit with no current node should be rejected.")
	assert_equal(rejected.error_code, &"no_current_node", "Not-parked exit should use the stable no_current_node code.")
	assert_false(rejected.has_events(), "A rejected exit should emit zero events.")
	assert_equal(after, before, "A not-parked rejected exit must leave the run byte-identical.")


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context.
	var command: NodeExitCommand = NodeExitCommand.new()
	var not_a_run: ActionResult = command.execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is rejected as invalid_context + surfaces the
	# inner RouteState.validate() error.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_NODE_RESOLUTION, 1, false, true, route)
	var before_invalid: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = command.execute(run)
	var after_invalid: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner RouteState.validate() error code.")
	assert_false(invalid_run.has_events(), "An invalid-context rejection should emit zero events.")
	assert_equal(after_invalid, before_invalid, "An invalid-context rejection must leave the run byte-identical.")


func _rejects_non_positive_sequence_id_with_no_mutation() -> void:
	# Self-consistency gate: exit builds node_exited (sequence_id) AND route_sealed (sequence_id + 1);
	# both require > 0. A non-positive id must be rejected before any event is built.
	for bad_sequence_id: int in [0, -1, -2]:
		var run: RunState = _resolving_run_on_combat_node()
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = NodeExitCommand.new(bad_sequence_id).execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)

	# validate() alone (pure read) also rejects a non-positive id.
	var validate_run: RunState = _resolving_run_on_combat_node()
	var validate_only: ActionResult = NodeExitCommand.new(0).validate(validate_run)
	assert_true(validate_only.is_error(), "validate() should reject a non-positive sequence id directly.")
	assert_equal(validate_only.error_code, &"invalid_event_sequence_id", "validate() should surface the stable sequence-id code.")


# ---- AC2: determinism / no RNG -------------------------------------------------------------------

func _exit_draws_no_rng_on_success_and_reject() -> void:
	# Node exit draws ZERO RNG and writes NO save. Hold a stream set, snapshot it, run a SUCCESSFUL exit
	# and a REJECTED exit, and assert the streams are byte-identical in both cases.
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var before: Dictionary = streams.to_snapshot()

	var run: RunState = _resolving_run_on_combat_node()
	NodeExitCommand.new().execute(run)
	assert_equal(streams.to_snapshot(), before, "A successful exit must draw no RNG (stream set unchanged).")

	# A rejected exit (wrong phase via an ACTIVE_ROUTE run) also draws no RNG.
	var reject_run: RunState = _resolving_run_on_combat_node()
	reject_run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	NodeExitCommand.new().execute(reject_run)
	assert_equal(streams.to_snapshot(), before, "A rejected exit must draw no RNG (stream set unchanged).")


func _exit_is_deterministic() -> void:
	# Same starting run + same command -> byte-identical resulting run.to_dictionary().
	var run_a: RunState = _resolving_run_on_combat_node()
	var run_b: RunState = _resolving_run_on_combat_node()
	NodeExitCommand.new().execute(run_a)
	NodeExitCommand.new().execute(run_b)
	assert_equal(run_a.to_dictionary(), run_b.to_dictionary(), "Node exit must be a deterministic state transition.")


# ---- Task 7.4: persistence coherence -------------------------------------------------------------

func _post_exit_run_round_trips_through_run_snapshot() -> void:
	# After exit, the route-side fields must survive a REAL JSON round-trip through the existing
	# RunSnapshot contract and reconstruct the run (current node, cleared set, reveal states, phase
	# nested under route_state).
	var run: RunState = _resolving_run_on_combat_node()
	var exited: ActionResult = NodeExitCommand.new().execute(run)
	assert_true(exited.succeeded, "Exit should succeed: %s" % exited.metadata)

	var fields: Dictionary = run.to_run_snapshot_fields()
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.root_seed = fields.get("root_seed")
	snapshot.is_manual_seed = fields.get("is_manual_seed")
	snapshot.meta_progression_eligible = fields.get("meta_progression_eligible")
	snapshot.route_state = fields.get("route_state")
	snapshot.current_route_node_id = fields.get("current_route_node_id")
	snapshot.revealed_route_node_ids = fields.get("revealed_route_node_ids")

	var json_data: Variant = JSON.parse_string(JSON.stringify(snapshot.to_dictionary()))
	assert_true(json_data is Dictionary, "The post-exit RunSnapshot should survive JSON stringify/parse.")
	var parse_result: ActionResult = RunSnapshot.parse(json_data)
	assert_true(parse_result.succeeded, "RunSnapshot.parse should accept the post-exit route payload: %s" % parse_result.metadata)
	var parsed_snapshot: RunSnapshot = parse_result.metadata.get("snapshot") as RunSnapshot
	assert_equal(parsed_snapshot.route_state.get("run_phase"), "active_route", "Phase must stay nested under route_state and round-trip.")

	var rebuilt: ActionResult = RunState.try_from_run_snapshot_fields({
		"root_seed": parsed_snapshot.root_seed,
		"is_manual_seed": parsed_snapshot.is_manual_seed,
		"meta_progression_eligible": parsed_snapshot.meta_progression_eligible,
		"route_state": parsed_snapshot.route_state,
		"current_route_node_id": parsed_snapshot.current_route_node_id
	})
	assert_true(rebuilt.succeeded, "The post-exit run should reconstruct from RunSnapshot fields: %s" % rebuilt.metadata)
	var rebuilt_run: RunState = rebuilt.metadata.get("run_state") as RunState
	assert_equal(rebuilt_run.phase, RunState.PHASE_ACTIVE_ROUTE, "The reconstructed run should keep the post-exit phase.")
	assert_equal(rebuilt_run.route.current_node_id, "node-1-0", "The reconstructed run should keep the current node.")
	assert_equal(rebuilt_run.route.node_by_id("node-1-0").reveal_state, RouteNode.REVEAL_CLEARED, "The reconstructed run should keep the cleared resolved node.")
	assert_true(rebuilt_run.route.cleared_node_ids.has("node-1-0"), "The reconstructed run should keep node-1-0 in cleared_node_ids.")
