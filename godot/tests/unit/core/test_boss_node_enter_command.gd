extends "res://tests/unit/test_case.gd"

# Story 9.1 — BossNodeEnterCommand (the boss-ENTRY / finale-SETUP command). Covers AC1 (build + validate the
# boss encounter request + the deterministic arena, transition ACTIVE_ROUTE -> NODE_RESOLUTION, emit ONE
# boss_encounter_started, return the request + arena payload in metadata), AC2 (the arena snapshot carries
# entrance / arena / player start / boss-entity slot / finale constraints + determinism), AC3 (the command
# does NOT complete the run + no-mutation stable-error rejections: wrong phase, not parked, non-boss node,
# invalid context, bad sequence id), plus the ZERO-RNG discipline.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BossEncounterRequest = preload("res://scripts/generation/boss/boss_encounter_request.gd")
const BossNodeEnterCommand = preload("res://scripts/core/commands/boss_node_enter_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_successful_setup_builds_request_transitions_and_emits_event()
	_setup_arena_payload_carries_the_required_finale_fields()
	_setup_does_not_complete_the_run_or_clear_the_boss()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_wrong_phase_with_no_mutation()
	_rejects_no_current_node()
	_rejects_non_boss_node_with_no_mutation()
	_rejects_invalid_context()
	_setup_draws_no_rng_on_success_and_reject()
	_setup_is_deterministic()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A small hand-built run parked on the terminal BOSS node (node-7-0) in PHASE_ACTIVE_ROUTE, with the start
# pre-cleared (the player advanced to the boss). Mirrors the NodeEnterCommand fixture shape but parks on boss.
func _active_run_on_boss_node(seed_value: int = 4242) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-7-0"])
	var boss: RouteNode = RouteNode.new("node-7-0", RouteNode.TYPE_BOSS, 7, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, boss], "node-7-0", ["node-0-0"])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, seed_value, false, true, route)
	assert_true(run.validate().succeeded, "Setup: the active boss-node run should validate.")
	return run


# ---- AC1: successful setup -----------------------------------------------------------------------

func _successful_setup_builds_request_transitions_and_emits_event() -> void:
	var run: RunState = _active_run_on_boss_node()

	var command: BossNodeEnterCommand = BossNodeEnterCommand.new()
	var setup: ActionResult = command.execute(run)
	assert_true(setup.succeeded, "Entering the boss node from ACTIVE_ROUTE should succeed: %s" % setup.metadata)

	# Phase transitioned ACTIVE_ROUTE -> NODE_RESOLUTION (the setup half; NO further -> COMPLETED here).
	assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "Boss setup should transition the run to NODE_RESOLUTION.")
	# The pointer stays on the boss node.
	assert_equal(run.route.current_node_id, "node-7-0", "Boss setup leaves the pointer on the boss node.")

	# Exactly one boss_encounter_started event with the right payload.
	assert_equal(setup.events.size(), 1, "A successful boss setup should emit exactly one event.")
	var event: DomainEvent = setup.events[0]
	assert_equal(event.event_type, DomainEvent.Type.BOSS_ENCOUNTER_STARTED, "The emitted event should be boss_encounter_started.")
	assert_equal(String(event.actor_id), "", "boss_encounter_started is a system event with no actor.")
	assert_equal(event.payload.get("boss_node_id"), "node-7-0", "Event should carry the ORIGINAL hyphenated boss node id.")
	assert_equal(event.payload.get("boss_entity_id"), "larval_avatar", "Event should carry the reserved boss-entity slot id.")
	assert_equal(event.payload.get("arena_width"), 12, "Event should carry the arena width.")
	assert_equal(event.payload.get("arena_height"), 12, "Event should carry the arena height.")
	# The emitted event is a valid DomainEvent (full payload-validation round-trip through real JSON).
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "The emitted boss_encounter_started event should pass payload validation: %s" % parsed.metadata)

	# Metadata carries the live, VALID BossEncounterRequest + the derived/original ids.
	assert_true(bool(setup.metadata.get("boss_encounter_started")), "Metadata should flag boss_encounter_started.")
	var request_value: Variant = setup.metadata.get("boss_encounter_request")
	assert_true(request_value is BossEncounterRequest, "Metadata should carry a live BossEncounterRequest.")
	var request: BossEncounterRequest = request_value as BossEncounterRequest
	assert_true(request.validate().succeeded, "The returned boss encounter request must be valid.")
	assert_equal(String(request.node_id), "node_7_0", "The request node id must be the DERIVED lower_snake boss id.")
	assert_equal(request.root_seed, run.root_seed, "The request seed must be the run root seed.")
	assert_equal(setup.metadata.get("boss_request_node_id"), "node_7_0", "Metadata should carry the derived lower_snake request id.")


# ---- AC2: the arena payload ----------------------------------------------------------------------

func _setup_arena_payload_carries_the_required_finale_fields() -> void:
	var run: RunState = _active_run_on_boss_node()
	var setup: ActionResult = BossNodeEnterCommand.new().execute(run)
	assert_true(setup.succeeded, "Boss setup should succeed for the arena-payload check.")

	var arena: Dictionary = setup.metadata.get("arena_payload")
	assert_false(arena.is_empty(), "The setup should return a non-empty arena payload.")
	# AC2: the level snapshot includes entrance, boss arena, player start, boss entity slot, and finale constraints.
	assert_true(arena.has("board_snapshot"), "The arena payload must carry the board snapshot (the boss arena).")
	assert_true(arena.has("entrance"), "The arena payload must carry the entrance.")
	assert_true(arena.has("player_start"), "The arena payload must carry the player start.")
	assert_true(arena.has("boss_slot"), "The arena payload must carry the boss-entity slot.")
	assert_true(arena.has("finale_constraints"), "The arena payload must carry the finale constraints.")

	var boss_slot: Dictionary = arena.get("boss_slot")
	assert_equal(boss_slot.get("entity_id"), "larval_avatar", "The boss slot must reserve the Larval Avatar entity id.")
	assert_true(bool(boss_slot.get("is_placeholder")), "The boss slot must be marked placeholder (9.2 fills the real definition).")

	var finale: Dictionary = arena.get("finale_constraints")
	assert_true(bool(finale.get("is_terminal_encounter")), "The finale constraints must mark the encounter terminal (no forward exit).")
	assert_true(bool(finale.get("boss_required")), "The finale constraints must mark the boss required (FR31).")

	# The payload is PURE serializable data — it survives a JSON round-trip as a Dictionary with its stable string
	# fields intact (a raw byte-identity re-stringify is NOT valid across the JSON boundary — nested ints decode as
	# floats, the documented int-coercion footgun; fidelity is the surviving keys/values + a strict re-validation).
	var round_trip: Variant = JSON.parse_string(JSON.stringify(arena))
	assert_true(round_trip is Dictionary, "The arena payload must survive a JSON round-trip as a Dictionary.")
	assert_equal((round_trip as Dictionary).get("boss_node_id"), "node_7_0", "The boss node id must survive the arena-payload JSON round-trip.")
	assert_equal(((round_trip as Dictionary).get("boss_slot") as Dictionary).get("entity_id"), "larval_avatar", "The boss slot entity id must survive the JSON round-trip.")


# ---- AC3: does NOT complete the run --------------------------------------------------------------

func _setup_does_not_complete_the_run_or_clear_the_boss() -> void:
	var run: RunState = _active_run_on_boss_node()
	var setup: ActionResult = BossNodeEnterCommand.new().execute(run)
	assert_true(setup.succeeded, "Boss setup should succeed for the no-completion check.")

	# The run is NOT terminal (9.1 sets up; 9.4 completes on victory).
	assert_false(run.is_terminal(), "The 9.1 boss setup must NOT complete the run.")
	assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "The run stays in NODE_RESOLUTION after the boss setup.")
	# The boss node is NOT cleared (9.4's victory clears it).
	assert_false(run.route.cleared_node_ids.has("node-7-0"), "The 9.1 boss setup must NOT clear the boss node.")
	# NO run_completed event is emitted (the run_completed boundary is 9.4's concern).
	for event: DomainEvent in setup.events:
		assert_false(event.event_type == DomainEvent.Type.RUN_COMPLETED, "The 9.1 boss setup must NOT emit run_completed.")
	assert_false(bool(setup.metadata.get("run_completed", false)), "The boss setup metadata must NOT flag run_completed.")


# ---- AC3: no-mutation stable-error rejections ----------------------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	# A non-positive sequence id is rejected FIRST (before any state read/mutation) so a success path can never
	# emit an event its own validator would reject.
	for bad_sequence_id: int in [0, -1, -100]:
		var run: RunState = _active_run_on_boss_node()
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = BossNodeEnterCommand.new(bad_sequence_id).execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_equal(rejected.metadata.get("sequence_id"), bad_sequence_id, "The rejection should echo the offending sequence id.")
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)

	# validate() alone (pure read) also rejects a non-positive id.
	var validate_run: RunState = _active_run_on_boss_node()
	var validate_only: ActionResult = BossNodeEnterCommand.new(0).validate(validate_run)
	assert_true(validate_only.is_error(), "validate() should reject a non-positive sequence id directly.")
	assert_equal(validate_only.error_code, &"invalid_event_sequence_id", "validate() should surface the stable sequence-id code.")


func _rejects_wrong_phase_with_no_mutation() -> void:
	# A boss setup from a non-ACTIVE_ROUTE phase (NODE_RESOLUTION) is rejected with no mutation.
	var run: RunState = _active_run_on_boss_node()
	run.transition_to(RunState.PHASE_NODE_RESOLUTION)
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = BossNodeEnterCommand.new().execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(rejected.is_error(), "A boss setup in the wrong phase should be rejected.")
	assert_equal(rejected.error_code, &"wrong_run_phase", "Wrong-phase setup should use the stable wrong_run_phase code.")
	assert_false(rejected.has_events(), "A wrong-phase rejection should emit zero events.")
	assert_equal(after, before, "A wrong-phase rejected setup must leave the run byte-identical.")


func _rejects_no_current_node() -> void:
	# A run not parked on a node is rejected.
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-7-0"])
	var boss: RouteNode = RouteNode.new("node-7-0", RouteNode.TYPE_BOSS, 7, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, boss], "", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 9, false, true, route)
	assert_equal(run.route.current_node_id, "", "Setup: the run is not parked on a node.")

	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = BossNodeEnterCommand.new().execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(rejected.is_error(), "A boss setup with no current node should be rejected.")
	assert_equal(rejected.error_code, &"no_current_node", "Not-parked setup should use the stable no_current_node code.")
	assert_false(rejected.has_events(), "A rejected setup should emit zero events.")
	assert_equal(after, before, "A not-parked rejected setup must leave the run byte-identical.")


func _rejects_non_boss_node_with_no_mutation() -> void:
	# A non-boss node passed to the boss command is a caller dispatch error — rejected with a stable code + ZERO
	# mutation. Cover a representative set of the non-boss types (combat + a placeholder type).
	for non_boss_type: StringName in [
		RouteNode.TYPE_COMBAT,
		RouteNode.TYPE_ELITE_COMBAT,
		RouteNode.TYPE_SHOP,
		RouteNode.TYPE_EVENT
	]:
		var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
		var node: RouteNode = RouteNode.new("node-1-0", non_boss_type, 1, RouteNode.REVEAL_REVEALED, ["node-7-0"])
		var boss: RouteNode = RouteNode.new("node-7-0", RouteNode.TYPE_BOSS, 7, RouteNode.REVEAL_REVEALED, [])
		var route: RouteState = RouteState.new([start, node, boss], "node-1-0", ["node-0-0"])
		var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 11, false, true, route)
		assert_true(run.validate().succeeded, "Setup: the %s-node run should validate." % String(non_boss_type))

		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = BossNodeEnterCommand.new().execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "Passing a %s node to the boss command should be rejected." % String(non_boss_type))
		assert_equal(rejected.error_code, &"node_not_boss", "A non-boss node should use the stable node_not_boss code (%s)." % String(non_boss_type))
		assert_equal(rejected.metadata.get("node_type"), String(non_boss_type), "The rejection should carry the offending node type (%s)." % String(non_boss_type))
		assert_equal(rejected.metadata.get("node_id"), "node-1-0", "The rejection should carry the node id in metadata (%s)." % String(non_boss_type))
		assert_false(rejected.has_events(), "A rejected non-boss setup should emit zero events (%s)." % String(non_boss_type))
		assert_equal(after, before, "A non-boss rejected setup must leave the run byte-identical (%s)." % String(non_boss_type))


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context (no crash, no mutation possible).
	var not_a_run: ActionResult = BossNodeEnterCommand.new().execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")


# ---- AC2: determinism / no RNG -------------------------------------------------------------------

func _setup_draws_no_rng_on_success_and_reject() -> void:
	# Boss setup draws ZERO RNG (building the request + the fixed deterministic arena is pure — the
	# NodeEnterCommand posture). Hold an external stream set, snapshot it, run a SUCCESSFUL setup and a REJECTED
	# setup, and assert the streams are byte-identical in both cases (named-stream isolation).
	var streams: RngStreamSet = RngStreamSet.new(24680)
	var before: Dictionary = streams.to_snapshot()

	var run: RunState = _active_run_on_boss_node()
	BossNodeEnterCommand.new().execute(run)
	assert_equal(streams.to_snapshot(), before, "A successful boss setup must draw no RNG (stream set unchanged).")

	# A rejected setup (wrong phase) also draws no RNG.
	var reject_run: RunState = _active_run_on_boss_node()
	reject_run.transition_to(RunState.PHASE_NODE_RESOLUTION)
	BossNodeEnterCommand.new().execute(reject_run)
	assert_equal(streams.to_snapshot(), before, "A rejected boss setup must draw no RNG (stream set unchanged).")


func _setup_is_deterministic() -> void:
	# Same starting run (same root_seed + boss node) + same command -> byte-identical resulting run.to_dictionary()
	# AND a byte-identical arena payload (AC2 determinism: same (root_seed, run state) -> byte-identical boss setup).
	var run_a: RunState = _active_run_on_boss_node(2026)
	var run_b: RunState = _active_run_on_boss_node(2026)
	var setup_a: ActionResult = BossNodeEnterCommand.new().execute(run_a)
	var setup_b: ActionResult = BossNodeEnterCommand.new().execute(run_b)
	assert_equal(run_a.to_dictionary(), run_b.to_dictionary(), "Boss setup must be a deterministic state transition.")
	assert_equal(JSON.stringify(setup_a.metadata.get("arena_payload")), JSON.stringify(setup_b.metadata.get("arena_payload")), "The same (root_seed, run state) must produce a byte-identical arena payload (AC2).")

	# A DIFFERENT seed produces the SAME fixed arena layout (the arena is seed-independent by construction) but the
	# arena_seed provenance differs — assert the board snapshot is identical while the arena_seed reflects the seed.
	var run_c: RunState = _active_run_on_boss_node(999)
	var setup_c: ActionResult = BossNodeEnterCommand.new().execute(run_c)
	var arena_a: Dictionary = setup_a.metadata.get("arena_payload")
	var arena_c: Dictionary = setup_c.metadata.get("arena_payload")
	assert_equal(JSON.stringify(arena_a.get("board_snapshot")), JSON.stringify(arena_c.get("board_snapshot")), "The fixed arena board snapshot is identical across seeds (a deterministic hand-authored layout).")
	assert_equal(arena_a.get("arena_seed"), "2026", "The arena_seed provenance reflects the run root seed (2026).")
	assert_equal(arena_c.get("arena_seed"), "999", "The arena_seed provenance reflects the run root seed (999).")
