extends "res://tests/unit/test_case.gd"

# Story 8.1 — CompleteRunCommand (the run-END RESOLUTION command). Covers AC1 (death -> PHASE_FAILED + run_failed with
# a CAUSE + the outpost flow signal), AC2 (completion -> PHASE_COMPLETED + run_completed with the broadened `completed`
# outcome + the outpost flow signal, from BOTH ACTIVE_ROUTE via the two-step AND NODE_RESOLUTION directly; the boss
# path's existing boss_placeholder behavior stays untouched), AC3 (a SECOND resolution on an already-terminal run is
# the stable run_already_terminal error with ZERO second event + ZERO mutation; a double-fail and a fail-then-complete
# are both blocked), plus the 4.3-idiom guards (sequence_id <= 0 rejected FIRST; an illegal-phase transition rejected
# with a stable code + ZERO mutation + ZERO events; invalid context; ZERO RNG drawn; determinism).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const CompleteRunCommand = preload("res://scripts/core/commands/complete_run_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const NodeResolvePlaceholderCommand = preload("res://scripts/core/commands/node_resolve_placeholder_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_death_resolves_to_failed_and_emits_run_failed_with_cause()
	_death_resolves_from_node_resolution_phase()
	_each_death_cause_resolves_to_failed()
	_completion_resolves_to_completed_from_active_route_two_step()
	_completion_resolves_to_completed_from_node_resolution()
	_re_resolution_of_terminal_run_is_blocked_idempotent()
	_double_fail_and_fail_then_complete_are_blocked()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_unknown_outcome_with_no_mutation()
	_rejects_completion_from_new_run_with_no_mutation()
	_rejects_death_from_new_run_with_no_mutation()
	_rejects_invalid_context()
	_resolve_draws_no_rng_on_success_and_reject()
	_resolve_is_deterministic()
	_boss_run_completed_path_stays_unchanged()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A run in PHASE_ACTIVE_ROUTE parked on a combat node (node-1-0). The start is already cleared (the player advanced).
func _active_run_on_node() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var node: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, node, boss], "node-1-0", ["node-0-0"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the active-route run should validate.")
	return run


# A run in PHASE_NODE_RESOLUTION parked on a node (the player entered node-1-0). The start is cleared.
func _node_resolution_run() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var node: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, node, boss], "node-1-0", ["node-0-0"])
	var run: RunState = RunState.new(RunState.PHASE_NODE_RESOLUTION, 707, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the node-resolution run should validate.")
	return run


# A fresh run in PHASE_NEW_RUN (parked at a route choice, no current node).
func _new_run() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var node: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, node], "", [])
	var run: RunState = RunState.new(RunState.PHASE_NEW_RUN, 11, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the new run should validate.")
	return run


func _assert_emitted_event_round_trips(event: DomainEvent, label: String) -> void:
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "%s should pass payload validation through real JSON: %s" % [label, parsed.metadata])


# ---- AC1: death -> FAILED + run_failed + cause + outpost ------------------------------------------

func _death_resolves_to_failed_and_emits_run_failed_with_cause() -> void:
	var run: RunState = _active_run_on_node()

	var resolved: ActionResult = CompleteRunCommand.new(&"hero_death", 11).execute(run)
	assert_true(resolved.succeeded, "A hero_death resolution from ACTIVE_ROUTE should succeed: %s" % resolved.metadata)

	# Phase transitioned ACTIVE_ROUTE -> FAILED (terminal).
	assert_equal(run.phase, RunState.PHASE_FAILED, "A death resolution should transition the run to FAILED.")
	assert_true(run.is_terminal(), "A death-resolved run should be terminal.")
	assert_true(run.validate().succeeded, "A committed death resolution should leave the run structurally valid.")

	# Exactly one run_failed event with the cause + the outpost flow signal.
	assert_equal(resolved.events.size(), 1, "A death resolution should emit exactly one event (run_failed).")
	var event: DomainEvent = resolved.events[0]
	assert_equal(event.event_type, DomainEvent.Type.RUN_FAILED, "The emitted event should be run_failed.")
	assert_equal(String(event.actor_id), "", "run_failed is a system event with no actor.")
	assert_equal(event.payload.get("cause"), "hero_death", "run_failed should carry the supplied cause.")
	assert_equal(event.payload.get("node_id"), "node-1-0", "run_failed should carry the node the run died on.")
	assert_equal(event.payload.get("cleared_node_count"), 1, "run_failed cleared_node_count should be the nodes cleared before death (start = 1).")
	assert_equal(event.payload.get("next_destination"), "outpost", "run_failed should carry the outpost next-destination flow signal (FR32).")
	_assert_emitted_event_round_trips(event, "run_failed")

	# Metadata surfaces the flow signal + cause (AC1 — the next app flow destination is the outpost).
	assert_true(bool(resolved.metadata.get("run_failed")), "Death metadata should flag run_failed.")
	assert_equal(resolved.metadata.get("cause"), "hero_death", "Death metadata should carry the cause.")
	assert_equal(resolved.metadata.get("next_destination"), "outpost", "Death metadata should carry the outpost destination.")
	assert_false(bool(resolved.metadata.get("run_completed", false)), "A death resolution must NOT flag run_completed.")


func _death_resolves_from_node_resolution_phase() -> void:
	# A death is legal from NODE_RESOLUTION too (e.g. the hero dies INSIDE a level/event/boss). The cleared set has
	# only the start, and the run died on node-1-0.
	var run: RunState = _node_resolution_run()

	var resolved: ActionResult = CompleteRunCommand.new(&"boss_defeat", 5).execute(run)
	assert_true(resolved.succeeded, "A death resolution from NODE_RESOLUTION should succeed: %s" % resolved.metadata)
	assert_equal(run.phase, RunState.PHASE_FAILED, "A death from NODE_RESOLUTION should transition to FAILED.")
	assert_equal(resolved.events[0].payload.get("cause"), "boss_defeat", "The boss_defeat cause should be carried.")
	assert_equal(resolved.events[0].payload.get("node_id"), "node-1-0", "run_failed should carry the node the run died on.")


func _each_death_cause_resolves_to_failed() -> void:
	# Every allowlisted cause resolves the death identically (transition -> FAILED + run_failed with that cause). The
	# cause distinguishes the context (AC1's "during a level, event, or boss encounter" + an abandoned run).
	for cause: StringName in DomainEvent.RUN_FAILED_CAUSES:
		var run: RunState = _active_run_on_node()
		var resolved: ActionResult = CompleteRunCommand.new(cause, 9).execute(run)
		assert_true(resolved.succeeded, "A %s death resolution should succeed: %s" % [String(cause), resolved.metadata])
		assert_equal(run.phase, RunState.PHASE_FAILED, "A %s death should transition to FAILED." % String(cause))
		assert_equal(resolved.events[0].event_type, DomainEvent.Type.RUN_FAILED, "A %s death should emit run_failed." % String(cause))
		assert_equal(resolved.events[0].payload.get("cause"), String(cause), "run_failed should carry the %s cause." % String(cause))
		_assert_emitted_event_round_trips(resolved.events[0], "run_failed (%s)" % String(cause))


# ---- AC2: completion -> COMPLETED + run_completed + outpost ---------------------------------------

func _completion_resolves_to_completed_from_active_route_two_step() -> void:
	var run: RunState = _active_run_on_node()

	var resolved: ActionResult = CompleteRunCommand.new(&"completed", 21).execute(run)
	assert_true(resolved.succeeded, "A completion resolution from ACTIVE_ROUTE should succeed (the two-step): %s" % resolved.metadata)

	# Phase transitioned ACTIVE_ROUTE -> NODE_RESOLUTION -> COMPLETED (terminal) — NO new transition edge.
	assert_equal(run.phase, RunState.PHASE_COMPLETED, "A completion resolution should transition the run to COMPLETED.")
	assert_true(run.is_terminal(), "A completion-resolved run should be terminal.")
	assert_true(run.validate().succeeded, "A committed completion resolution should leave the run structurally valid.")

	# Exactly one run_completed event with the broadened `completed` outcome + the outpost flow signal.
	assert_equal(resolved.events.size(), 1, "A completion resolution should emit exactly one event (run_completed).")
	var event: DomainEvent = resolved.events[0]
	assert_equal(event.event_type, DomainEvent.Type.RUN_COMPLETED, "The emitted event should be run_completed.")
	assert_equal(String(event.actor_id), "", "run_completed is a system event with no actor.")
	assert_equal(event.payload.get("outcome"), "completed", "run_completed should carry the broadened `completed` outcome (NOT boss_placeholder).")
	assert_equal(event.payload.get("cleared_node_count"), 1, "run_completed cleared_node_count should be the cleared set size (start = 1).")
	assert_equal(event.payload.get("next_destination"), "outpost", "run_completed should carry the outpost next-destination flow signal (FR32).")
	# A generic completion carries NO boss node id (the field is omitted for the `completed` outcome).
	assert_false(event.payload.has("boss_node_id"), "A generic completion run_completed should NOT carry a boss_node_id.")
	_assert_emitted_event_round_trips(event, "run_completed (completed)")

	# Metadata surfaces the flow signal + outcome.
	assert_true(bool(resolved.metadata.get("run_completed")), "Completion metadata should flag run_completed.")
	assert_equal(resolved.metadata.get("outcome"), "completed", "Completion metadata should carry the outcome.")
	assert_equal(resolved.metadata.get("next_destination"), "outpost", "Completion metadata should carry the outpost destination.")

	# The command's marker constants are pinned.
	assert_equal(String(CompleteRunCommand.COMPLETION_OUTCOME), "completed", "COMPLETION_OUTCOME must be `completed`.")
	assert_equal(String(CompleteRunCommand.NEXT_DESTINATION_OUTPOST), "outpost", "NEXT_DESTINATION_OUTPOST must be `outpost`.")


func _completion_resolves_to_completed_from_node_resolution() -> void:
	# A completion from NODE_RESOLUTION is a single direct step (NODE_RESOLUTION -> COMPLETED), no two-step.
	var run: RunState = _node_resolution_run()
	var resolved: ActionResult = CompleteRunCommand.new(&"completed", 3).execute(run)
	assert_true(resolved.succeeded, "A completion from NODE_RESOLUTION should succeed: %s" % resolved.metadata)
	assert_equal(run.phase, RunState.PHASE_COMPLETED, "A completion from NODE_RESOLUTION should transition to COMPLETED.")
	assert_equal(resolved.events[0].event_type, DomainEvent.Type.RUN_COMPLETED, "The emitted event should be run_completed.")
	assert_equal(resolved.events[0].payload.get("outcome"), "completed", "The completion outcome should be `completed`.")


# ---- AC3: idempotency / no-double-grant -----------------------------------------------------------

func _re_resolution_of_terminal_run_is_blocked_idempotent() -> void:
	# A first completion succeeds; a SECOND resolution on the now-terminal run is the stable run_already_terminal error
	# with ZERO new events + a BYTE-IDENTICAL run-state (so nothing can be granted twice — AC3).
	var run: RunState = _active_run_on_node()
	var first: ActionResult = CompleteRunCommand.new(&"completed", 1).execute(run)
	assert_true(first.succeeded, "The first completion should succeed.")
	assert_equal(run.phase, RunState.PHASE_COMPLETED, "The run should be COMPLETED after the first resolution.")

	var before: Dictionary = run.to_dictionary()
	var second: ActionResult = CompleteRunCommand.new(&"completed", 2).execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(second.is_error(), "A second resolution on a terminal run should be rejected.")
	assert_equal(second.error_code, &"run_already_terminal", "A re-resolution should use the stable run_already_terminal code.")
	assert_equal(second.metadata.get("phase"), String(RunState.PHASE_COMPLETED), "The rejection should carry the actual terminal phase.")
	assert_false(second.has_events(), "A re-resolution must emit ZERO new events (no double-grant).")
	assert_equal(after, before, "A re-resolution must leave the run BYTE-IDENTICAL (no mutation, no double-grant).")


func _double_fail_and_fail_then_complete_are_blocked() -> void:
	# A failed run is terminal: a second death AND a completion are both blocked (terminal is terminal — AC3).
	var run: RunState = _active_run_on_node()
	assert_true(CompleteRunCommand.new(&"hero_death", 1).execute(run).succeeded, "The first death should succeed.")
	assert_equal(run.phase, RunState.PHASE_FAILED, "The run should be FAILED after the first death.")

	# A second death is blocked.
	var before_a: Dictionary = run.to_dictionary()
	var double_fail: ActionResult = CompleteRunCommand.new(&"abandoned", 2).execute(run)
	assert_true(double_fail.is_error(), "A second death on a FAILED run should be rejected.")
	assert_equal(double_fail.error_code, &"run_already_terminal", "A double-fail should use run_already_terminal.")
	assert_false(double_fail.has_events(), "A double-fail must emit zero events.")
	assert_equal(run.to_dictionary(), before_a, "A double-fail must leave the run byte-identical.")

	# A completion of a FAILED run is blocked (the same terminal guard).
	var before_b: Dictionary = run.to_dictionary()
	var fail_then_complete: ActionResult = CompleteRunCommand.new(&"completed", 3).execute(run)
	assert_true(fail_then_complete.is_error(), "Completing a FAILED run should be rejected.")
	assert_equal(fail_then_complete.error_code, &"run_already_terminal", "A fail-then-complete should use run_already_terminal.")
	assert_false(fail_then_complete.has_events(), "A fail-then-complete must emit zero events.")
	assert_equal(run.to_dictionary(), before_b, "A fail-then-complete must leave the run byte-identical.")


# ---- 4.3-idiom guards -----------------------------------------------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	# sequence_id <= 0 is rejected FIRST (before any state read/mutation) so a success path can never emit an event its
	# own validator would reject. Holds for both a death cause and the completion marker, and for sequence_id 0 and -1.
	for outcome: StringName in [&"hero_death", &"completed"]:
		for bad_id: int in [0, -1]:
			var run: RunState = _active_run_on_node()
			var before: Dictionary = run.to_dictionary()
			var rejected: ActionResult = CompleteRunCommand.new(outcome, bad_id).execute(run)
			var after: Dictionary = run.to_dictionary()
			assert_true(rejected.is_error(), "A %s resolution with sequence_id %d should be rejected." % [String(outcome), bad_id])
			assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%s, %d)." % [String(outcome), bad_id])
			assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%s, %d)." % [String(outcome), bad_id])
			assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%s, %d)." % [String(outcome), bad_id])


func _rejects_unknown_outcome_with_no_mutation() -> void:
	# An outcome that is neither a known death cause nor the completion marker is rejected fail-loud (the offending
	# value rides metadata, never the error code) with no mutation + zero events. `victory` is a deliberately-unknown
	# value here (it is reserved for Epic 9's boss victory, NOT a v0 CompleteRunCommand outcome).
	for bad_outcome: StringName in [&"victory", &"boss_placeholder", &"", &"garbage"]:
		var run: RunState = _active_run_on_node()
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = CompleteRunCommand.new(bad_outcome, 1).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "An unknown outcome `%s` should be rejected." % String(bad_outcome))
		assert_equal(rejected.error_code, &"unknown_run_end_outcome", "An unknown outcome should use the stable code (`%s`)." % String(bad_outcome))
		assert_equal(rejected.metadata.get("outcome"), String(bad_outcome), "The rejection should carry the offending outcome in metadata (`%s`)." % String(bad_outcome))
		assert_false(rejected.has_events(), "An unknown-outcome rejection should emit zero events (`%s`)." % String(bad_outcome))
		assert_equal(after, before, "An unknown-outcome rejection must leave the run byte-identical (`%s`)." % String(bad_outcome))


func _rejects_completion_from_new_run_with_no_mutation() -> void:
	# A completion is NOT reachable from NEW_RUN (neither NODE_RESOLUTION nor COMPLETED is a legal edge from NEW_RUN
	# except ACTIVE_ROUTE). Reject with the stable wrong_run_phase code + no mutation + zero events.
	var run: RunState = _new_run()
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = CompleteRunCommand.new(&"completed", 1).execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "Completing a NEW_RUN run should be rejected.")
	assert_equal(rejected.error_code, &"wrong_run_phase", "A NEW_RUN completion should use the stable wrong_run_phase code.")
	assert_equal(rejected.metadata.get("phase"), String(RunState.PHASE_NEW_RUN), "The rejection should carry the actual phase.")
	assert_equal(rejected.metadata.get("requested_phase"), String(RunState.PHASE_COMPLETED), "The rejection should carry the requested phase.")
	assert_false(rejected.has_events(), "A NEW_RUN completion rejection should emit zero events.")
	assert_equal(after, before, "A NEW_RUN completion rejection must leave the run byte-identical.")


func _rejects_death_from_new_run_with_no_mutation() -> void:
	# A death is NOT a legal edge from NEW_RUN (only ACTIVE_ROUTE is). Reject with wrong_run_phase + no mutation.
	var run: RunState = _new_run()
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = CompleteRunCommand.new(&"hero_death", 1).execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "A death from NEW_RUN should be rejected (FAILED is not a legal edge from NEW_RUN).")
	assert_equal(rejected.error_code, &"wrong_run_phase", "A NEW_RUN death should use the stable wrong_run_phase code.")
	assert_equal(rejected.metadata.get("requested_phase"), String(RunState.PHASE_FAILED), "The rejection should carry the requested FAILED phase.")
	assert_false(rejected.has_events(), "A NEW_RUN death rejection should emit zero events.")
	assert_equal(after, before, "A NEW_RUN death rejection must leave the run byte-identical.")


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context.
	var command: CompleteRunCommand = CompleteRunCommand.new(&"completed", 1)
	var not_a_run: ActionResult = command.execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")


# ---- ZERO RNG + determinism -----------------------------------------------------------------------

func _resolve_draws_no_rng_on_success_and_reject() -> void:
	# Run-END resolution is a deterministic phase transition + event — it draws ZERO RNG. The command takes only the
	# RunState (no stream set), so a held RngStreamSet must be byte-identical before/after a success AND a reject.
	var streams: RngStreamSet = RngStreamSet.new(12345)
	var before: Dictionary = streams.to_snapshot()

	# Success (death).
	var failed_run: RunState = _active_run_on_node()
	assert_true(CompleteRunCommand.new(&"hero_death", 1).execute(failed_run).succeeded, "Death resolution should succeed.")
	assert_equal(streams.to_snapshot(), before, "A death resolution must draw no RNG (stream set unchanged).")

	# Success (completion).
	var completed_run: RunState = _active_run_on_node()
	assert_true(CompleteRunCommand.new(&"completed", 1).execute(completed_run).succeeded, "Completion resolution should succeed.")
	assert_equal(streams.to_snapshot(), before, "A completion resolution must draw no RNG (stream set unchanged).")

	# Reject (already-terminal).
	assert_true(CompleteRunCommand.new(&"completed", 2).execute(completed_run).is_error(), "A re-resolution should reject.")
	assert_equal(streams.to_snapshot(), before, "A rejected resolution must draw no RNG (stream set unchanged).")


func _resolve_is_deterministic() -> void:
	# Same (run, outcome, sequence_id) -> identical result (the run-end resolution is a pure deterministic transition +
	# event). Two independent runs at the same seed resolved identically produce byte-identical event payloads.
	var run_a: RunState = _active_run_on_node()
	var run_b: RunState = _active_run_on_node()
	var a: ActionResult = CompleteRunCommand.new(&"hero_death", 7).execute(run_a)
	var b: ActionResult = CompleteRunCommand.new(&"hero_death", 7).execute(run_b)
	assert_true(a.succeeded and b.succeeded, "Both death resolutions should succeed.")
	assert_equal(a.events[0].to_dictionary(), b.events[0].to_dictionary(), "Identical inputs must produce byte-identical run_failed payloads (determinism).")
	assert_equal(run_a.to_dictionary(), run_b.to_dictionary(), "Identical inputs must leave byte-identical run states (determinism).")


# ---- the boss path stays unchanged (the AC2 regression guard) -------------------------------------

func _boss_run_completed_path_stays_unchanged() -> void:
	# The Story-4.5 boss path (NodeResolvePlaceholderCommand) still emits run_completed with the EXACT boss_placeholder
	# outcome — the 8.1 broadening did not regress the boss boundary Epic 9 depends on. (A focused cross-check; the full
	# boss behavior is owned by test_node_resolve_placeholder_command.gd.)
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, boss], "node-1-0", ["node-0-0"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 55, false, true, route)

	var resolved: ActionResult = NodeResolvePlaceholderCommand.new(1).execute(run)
	assert_true(resolved.succeeded, "The boss resolve should still succeed: %s" % resolved.metadata)
	assert_equal(run.phase, RunState.PHASE_COMPLETED, "The boss resolve should still reach COMPLETED.")
	var run_completed_event: DomainEvent = resolved.events[1]
	assert_equal(run_completed_event.event_type, DomainEvent.Type.RUN_COMPLETED, "The boss should still emit run_completed.")
	assert_equal(run_completed_event.payload.get("outcome"), "boss_placeholder", "The boss outcome must stay boss_placeholder (Epic 9 contract).")
	assert_equal(run_completed_event.payload.get("boss_node_id"), "node-1-0", "The boss run_completed must still carry boss_node_id.")
	# The broadened validator now also requires next_destination — the factory defaults it, so the boss event still
	# validates through real JSON (the boss event picks up the outpost destination automatically).
	_assert_emitted_event_round_trips(run_completed_event, "boss run_completed")
	assert_equal(run_completed_event.payload.get("next_destination"), "outpost", "The boss run_completed now also carries the outpost destination (defaulted by the factory).")
