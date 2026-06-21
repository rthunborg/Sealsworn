extends "res://tests/unit/test_case.gd"

# Story 4.3 — RouteAdvanceCommand (the route CHOICE / forward-commitment command). Covers AC1
# (reveal-gated eligibility), AC2 (successful advance + reveal-on-arrival + route_advanced event +
# determinism/no-RNG + persistence coherence), and AC3 (no-mutation stable-error rejections).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteAdvanceCommand = preload("res://scripts/core/commands/route_advance_command.gd")
const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# A couple of representative seeds for the generated-route walks (exercise both width patterns).
const WALK_SEEDS: Array[int] = [1, 7, 42, 2026]

func run() -> Dictionary:
	_successful_advance_clears_left_node_reveals_forward_and_emits_event()
	_reveal_on_arrival_prevents_soft_lock_across_seeds()
	_rejects_wrong_phase_with_no_mutation()
	_rejects_no_current_node()
	_rejects_hidden_cleared_unlinked_unknown_and_current_targets_with_no_mutation()
	_rejects_invalid_context()
	_rejects_non_positive_sequence_id_with_no_mutation()
	_advance_draws_no_rng_on_success_and_reject()
	_advance_is_deterministic()
	_post_advance_run_still_validates_and_bridges_into_run_snapshot()
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
	# new_run resets the pointer to ""; park the run on the start node and enter the route choice phase.
	run.route.current_node_id = start_id
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	return run


# A small hand-built run: start (revealed) -> revealed-a, revealed-b, hidden-c ; the depth-1 nodes
# each link to a depth-2 node (initially hidden) so reveal-on-arrival has something to flip.
func _hand_built_active_run() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0", "node-1-1"])
	var a: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_ELITE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var b: RouteNode = RouteNode.new("node-1-1", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var c: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, a, b, c], "node-0-0", [])
	var run: RunState = RunState.new_run(123, false, route)
	run.route.current_node_id = "node-0-0"
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	assert_true(run.validate().succeeded, "Hand-built active run should validate.")
	return run


# ---- AC2: successful advance ---------------------------------------------------------------------

func _successful_advance_clears_left_node_reveals_forward_and_emits_event() -> void:
	var run: RunState = _hand_built_active_run()
	# Eligible choices from the start are the two revealed depth-1 nodes.
	assert_equal(run.route.eligible_choice_ids(), ["node-1-0", "node-1-1"], "Both revealed depth-1 nodes are eligible from the start.")

	var command: RouteAdvanceCommand = RouteAdvanceCommand.new("node-1-0")
	var advance: ActionResult = command.execute(run)
	assert_true(advance.succeeded, "A legal advance to a revealed linked node should succeed: %s" % advance.metadata)

	# Pointer advanced.
	assert_equal(run.route.current_node_id, "node-1-0", "current_node_id should advance to the chosen node.")
	# Left node cleared + REVEAL_CLEARED.
	assert_true(run.route.cleared_node_ids.has("node-0-0"), "The left node should be recorded in cleared_node_ids.")
	assert_equal(run.route.node_by_id("node-0-0").reveal_state, RouteNode.REVEAL_CLEARED, "The left node should be marked REVEAL_CLEARED.")
	# The OTHER depth-1 node is untouched (still revealed) but is no longer a current-node link.
	assert_equal(run.route.node_by_id("node-1-1").reveal_state, RouteNode.REVEAL_REVEALED, "Reveal is monotonic: the un-chosen sibling stays revealed.")
	# Reveal-on-arrival flipped the arrived node's forward neighbor (depth-2) to revealed.
	assert_equal(run.route.node_by_id("node-2-0").reveal_state, RouteNode.REVEAL_REVEALED, "The arrived node's hidden forward neighbor should be revealed on arrival.")
	# The next tier is now selectable (no soft-lock).
	assert_equal(run.route.eligible_choice_ids(), ["node-2-0"], "After arrival the next tier is eligible.")
	# Run stays in ACTIVE_ROUTE (decision: 4.3 does NOT transition to NODE_RESOLUTION).
	assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "4.3 leaves the run in ACTIVE_ROUTE (no node-resolution transition).")

	# Exactly one route_advanced event with the right payload.
	assert_equal(advance.events.size(), 1, "A successful advance should emit exactly one event.")
	var event: DomainEvent = advance.events[0]
	assert_equal(event.event_type, DomainEvent.Type.ROUTE_ADVANCED, "The emitted event should be route_advanced.")
	assert_equal(String(event.actor_id), "", "route_advanced is a system event with no actor.")
	assert_equal(event.payload.get("from_node_id"), "node-0-0", "Event from-node id should be the left node.")
	assert_equal(event.payload.get("to_node_id"), "node-1-0", "Event to-node id should be the chosen node.")
	assert_equal(event.payload.get("to_node_type"), "elite_combat", "Event should carry the arrived node type.")
	assert_equal(event.payload.get("to_node_depth"), 1, "Event should carry the arrived node depth.")
	assert_equal(event.payload.get("cleared_node_id"), "node-0-0", "Event cleared-node id should be the left node.")
	assert_equal(event.payload.get("revealed_node_ids"), ["node-2-0"], "Event should list the newly-revealed neighbors.")
	# The emitted event is a valid DomainEvent (full payload-validation round-trip).
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "The emitted route_advanced event should pass payload validation: %s" % parsed.metadata)

	# Metadata advertises the advance.
	assert_true(bool(advance.metadata.get("advances_route")), "Metadata should flag advances_route.")
	assert_equal(advance.metadata.get("revealed_node_ids"), ["node-2-0"], "Metadata should carry the revealed ids.")

	# Post-advance run still validates structurally.
	assert_true(run.validate().succeeded, "A committed advance should leave the run structurally valid.")

	# A SECOND commit proves reveal-on-arrival keeps the descent traversable.
	var second: RouteAdvanceCommand = RouteAdvanceCommand.new("node-2-0")
	var second_result: ActionResult = second.execute(run)
	assert_true(second_result.succeeded, "A second advance to the newly-revealed node should succeed: %s" % second_result.metadata)
	assert_equal(run.route.current_node_id, "node-2-0", "The second commit should advance to the boss tier.")
	assert_true(run.route.cleared_node_ids.has("node-1-0"), "The second left node should be cleared.")


func _reveal_on_arrival_prevents_soft_lock_across_seeds() -> void:
	# On 4.2-generated routes, walk start -> ... -> boss tier, asserting eligible_choice_ids() is
	# NON-EMPTY at every step before the boss (proving reveal-on-arrival keeps the route traversable).
	for seed_value: int in WALK_SEEDS:
		var run: RunState = _active_run_for_seed(seed_value)
		var steps: int = 0
		var max_steps: int = 64  # generous guard; the boss is at a fixed shallow depth.
		var reached_boss: bool = false
		while steps < max_steps:
			var current: RouteNode = run.route.node_by_id(run.route.current_node_id)
			if current.type == RouteNode.TYPE_BOSS:
				reached_boss = true
				break
			var eligible: Array[String] = run.route.eligible_choice_ids()
			assert_true(not eligible.is_empty(), "Seed %d: a non-boss node must always have an eligible choice (no soft-lock) at step %d." % [seed_value, steps])
			# Advance to the first eligible choice.
			var command: RouteAdvanceCommand = RouteAdvanceCommand.new(eligible[0])
			var advance: ActionResult = command.execute(run)
			assert_true(advance.succeeded, "Seed %d: advancing to an eligible choice should succeed at step %d: %s" % [seed_value, steps, advance.metadata])
			assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after each advance." % seed_value)
			steps += 1
		assert_true(reached_boss, "Seed %d: the walk should reach the boss tier within the step guard." % seed_value)


# ---- AC3: no-mutation rejections -----------------------------------------------------------------

func _rejects_wrong_phase_with_no_mutation() -> void:
	# Every non-ACTIVE_ROUTE phase must reject a route advance with wrong_run_phase + no mutation +
	# zero events. The command's guard is phase-agnostic (rejects ANY phase != ACTIVE_ROUTE), so the
	# two non-terminal (NEW_RUN, NODE_RESOLUTION) AND the two terminal (COMPLETED, FAILED) phases all
	# exercise the same single branch — but each gets a dedicated negative test. The terminal phases
	# cannot be reached from a parked choice via the transition table, so the run is built DIRECTLY in
	# the target phase via the RunState(phase, ...) constructor.
	for phase: StringName in [
		RunState.PHASE_NEW_RUN,
		RunState.PHASE_NODE_RESOLUTION,
		RunState.PHASE_COMPLETED,
		RunState.PHASE_FAILED
	]:
		# A minimal valid route parked on the start node (revealed depth-1 link).
		var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
		var a: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, [])
		var route: RouteState = RouteState.new([start, a], "node-0-0", [])
		# Build the run DIRECTLY in the target phase (terminal phases are unreachable via transition_to
		# from a parked choice). meta_progression_eligible = not is_manual_seed, so pass false/true.
		var run: RunState = RunState.new(phase, 5, false, true, route)
		assert_equal(run.phase, phase, "Setup: run should be in %s." % String(phase))
		assert_true(run.validate().succeeded, "Setup: the %s run should validate." % String(phase))

		var before: Dictionary = run.to_dictionary()
		var command: RouteAdvanceCommand = RouteAdvanceCommand.new("node-1-0")
		var rejected: ActionResult = command.execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "An advance outside ACTIVE_ROUTE should be rejected (%s)." % String(phase))
		assert_equal(rejected.error_code, &"wrong_run_phase", "Wrong-phase advance should use the stable wrong_run_phase code (%s)." % String(phase))
		assert_equal(rejected.metadata.get("phase"), String(phase), "Wrong-phase rejection should carry the actual phase (%s)." % String(phase))
		assert_false(rejected.has_events(), "A rejected advance should emit zero events (%s)." % String(phase))
		assert_equal(after, before, "A wrong-phase rejected advance must leave the run byte-identical (%s)." % String(phase))


func _rejects_no_current_node() -> void:
	# A run in ACTIVE_ROUTE but not parked on a node has no choice.
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var a: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([start, a], "", [])
	var run: RunState = RunState.new_run(9, false, route)
	run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	assert_equal(run.route.current_node_id, "", "Setup: the run is not parked on a node.")

	var before: Dictionary = run.to_dictionary()
	var command: RouteAdvanceCommand = RouteAdvanceCommand.new("node-1-0")
	var rejected: ActionResult = command.execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(rejected.is_error(), "An advance with no current node should be rejected.")
	assert_equal(rejected.error_code, &"no_current_node", "Not-parked advance should use the stable no_current_node code.")
	assert_false(rejected.has_events(), "A rejected advance should emit zero events.")
	assert_equal(after, before, "A not-parked rejected advance must leave the run byte-identical.")


func _rejects_hidden_cleared_unlinked_unknown_and_current_targets_with_no_mutation() -> void:
	# Build a richer route so EVERY ineligibility reason is exercisable as a distinct case (the reason
	# derivation order is is_current_node -> unknown_node -> cleared_node -> not_linked -> hidden_node,
	# so each target below is chosen to isolate exactly one reason). See _build_rejection_route.
	var cases: Array = [
		# [target, expected_reason]
		["node-1-2", "hidden_node"],     # a node LINKED from the current node but REVEAL_HIDDEN
		["node-1-1", "cleared_node"],    # a sibling that is pre-cleared (and linked)
		["node-1-9", "not_linked"],      # a known, revealed node NOT linked from the current node
		["ghost-node", "unknown_node"],  # an unknown id
		["node-0-0", "is_current_node"]  # the current node itself
	]
	for case_value: Array in cases:
		var target: String = case_value[0]
		var expected_reason: String = case_value[1]
		var run: RunState = _build_rejection_route()

		var before: Dictionary = run.to_dictionary()
		var command: RouteAdvanceCommand = RouteAdvanceCommand.new(target)
		var rejected: ActionResult = command.execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "Selecting %s should be rejected (%s)." % [target, expected_reason])
		assert_equal(rejected.error_code, &"ineligible_route_choice", "An ineligible target should use the stable ineligible_route_choice code (%s)." % expected_reason)
		assert_equal(rejected.metadata.get("reason"), expected_reason, "Ineligible target should carry the precise reason in metadata (%s)." % expected_reason)
		assert_equal(rejected.metadata.get("target_node_id"), target, "Ineligible rejection should echo the target id in metadata.")
		assert_false(rejected.has_events(), "A rejected advance should emit zero events (%s)." % expected_reason)
		assert_equal(after, before, "An ineligible rejected advance must leave the run byte-identical (%s)." % expected_reason)


func _build_rejection_route() -> RunState:
	# Current node node-0-0 links to: node-1-0 (revealed, eligible), node-1-1 (cleared sibling),
	# node-1-2 (linked but HIDDEN). node-1-9 is a known, revealed node NOT linked from the current
	# node (an island reachable only via node-1-0). node-2-0 is the terminal boss. All edges are
	# strictly forward; node-1-1 is pre-cleared (so it is in cleared_node_ids AND marked CLEARED).
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0", "node-1-1", "node-1-2"])
	var a: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-1-9"])
	var b: RouteNode = RouteNode.new("node-1-1", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_CLEARED, ["node-2-0"])
	var hidden_link: RouteNode = RouteNode.new("node-1-2", RouteNode.TYPE_EVENT, 1, RouteNode.REVEAL_HIDDEN, ["node-2-0"])
	var island: RouteNode = RouteNode.new("node-1-9", RouteNode.TYPE_ELITE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["node-2-0"])
	var boss: RouteNode = RouteNode.new("node-2-0", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, a, b, hidden_link, island, boss], "node-0-0", ["node-1-1"])
	# Construct the run DIRECTLY in ACTIVE_ROUTE (new_run() would reset cleared_node_ids/current_node_id
	# to a fresh-run state, wiping the pre-cleared node this fixture needs).
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 321, false, true, route)
	assert_true(run.validate().succeeded, "The rejection-route run should validate.")
	return run


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context (no crash, no mutation possible).
	var command: RouteAdvanceCommand = RouteAdvanceCommand.new("node-1-0")
	var not_a_run: ActionResult = command.execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is also rejected as invalid_context, AND the
	# top-level invalid_context metadata surfaces the inner RouteState.validate() error so a corrupt-run
	# rejection is diagnosable (the precise structural reason is not discarded).
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	var before_invalid: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = command.execute(run)
	var after_invalid: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner RouteState.validate() error code for diagnosis.")
	var inner_metadata: Variant = invalid_run.metadata.get("inner_metadata")
	assert_true(inner_metadata is Dictionary, "invalid_context should carry the inner validation metadata.")
	assert_equal((inner_metadata as Dictionary).get("node_id"), "ghost", "The inner metadata should pinpoint the offending node id.")
	assert_false(invalid_run.has_events(), "An invalid-context rejection should emit zero events.")
	assert_equal(after_invalid, before_invalid, "An invalid-context rejection must leave the run byte-identical.")


func _rejects_non_positive_sequence_id_with_no_mutation() -> void:
	# Self-consistency gate (Round-1 finding 1): execute() builds a route_advanced event with the
	# caller-supplied sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0. So a
	# non-positive sequence id must be REJECTED before the event is built — the success path must never
	# emit an event its own validator would reject. The rejection leaves the run byte-identical with
	# zero events. (The constructor default is 1, so no current caller can hit this — it is a guard.)
	for bad_sequence_id: int in [0, -1]:
		var run: RunState = _hand_built_active_run()
		var before: Dictionary = run.to_dictionary()
		# Target node-1-0 is a perfectly LEGAL choice — only the sequence id is bad, proving the gate
		# fires on the sequence id and not on the target.
		var command: RouteAdvanceCommand = RouteAdvanceCommand.new("node-1-0", bad_sequence_id)
		var rejected: ActionResult = command.execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable invalid_event_sequence_id code (%d)." % bad_sequence_id)
		assert_equal(rejected.metadata.get("sequence_id"), bad_sequence_id, "The rejection should echo the offending sequence id.")
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)

	# validate() alone (pure read) also rejects a non-positive id before touching the run.
	var validate_run: RunState = _hand_built_active_run()
	var validate_only: ActionResult = RouteAdvanceCommand.new("node-1-0", 0).validate(validate_run)
	assert_true(validate_only.is_error(), "validate() should reject a non-positive sequence id directly.")
	assert_equal(validate_only.error_code, &"invalid_event_sequence_id", "validate() should surface the stable sequence-id code.")


# ---- AC2: determinism / no RNG -------------------------------------------------------------------

func _advance_draws_no_rng_on_success_and_reject() -> void:
	# Route advance draws ZERO RNG. Hold a stream set, snapshot it, run a SUCCESSFUL advance and a
	# REJECTED advance, and assert the streams are byte-identical in both cases.
	var streams: RngStreamSet = RngStreamSet.new(24680)
	var before: Dictionary = streams.to_snapshot()

	var run: RunState = _hand_built_active_run()
	var ok_command: RouteAdvanceCommand = RouteAdvanceCommand.new("node-1-0")
	ok_command.execute(run)
	assert_equal(streams.to_snapshot(), before, "A successful advance must draw no RNG (stream set unchanged).")

	var reject_run: RunState = _hand_built_active_run()
	var bad_command: RouteAdvanceCommand = RouteAdvanceCommand.new("ghost")
	bad_command.execute(reject_run)
	assert_equal(streams.to_snapshot(), before, "A rejected advance must draw no RNG (stream set unchanged).")


func _advance_is_deterministic() -> void:
	# Same starting run + same chosen id -> byte-identical resulting run.to_dictionary().
	var run_a: RunState = _hand_built_active_run()
	var run_b: RunState = _hand_built_active_run()
	RouteAdvanceCommand.new("node-1-0").execute(run_a)
	RouteAdvanceCommand.new("node-1-0").execute(run_b)
	assert_equal(run_a.to_dictionary(), run_b.to_dictionary(), "The advance must be a deterministic state transition.")


# ---- AC2: persistence coherence ------------------------------------------------------------------

func _post_advance_run_still_validates_and_bridges_into_run_snapshot() -> void:
	var run: RunState = _hand_built_active_run()
	RouteAdvanceCommand.new("node-1-0").execute(run)

	# The bridge surfaces the new current node and the newly-revealed/cleared ids automatically.
	var fields: Dictionary = run.to_run_snapshot_fields()
	assert_equal(fields.get("current_route_node_id"), "node-1-0", "The bridge should reflect the new current node.")
	var revealed: Array = fields.get("revealed_route_node_ids")
	# revealed-or-cleared: start (cleared), node-1-0 (current/revealed), node-1-1 (revealed sibling),
	# node-2-0 (revealed on arrival). All four surface; the hidden set is empty after the advance.
	assert_true(revealed.has("node-0-0"), "The cleared left node surfaces in revealed_route_node_ids (revealed-or-cleared).")
	assert_true(revealed.has("node-1-0"), "The arrived node surfaces in revealed_route_node_ids.")
	assert_true(revealed.has("node-2-0"), "The newly-revealed neighbor surfaces in revealed_route_node_ids.")

	# Real JSON round-trip through the existing RunSnapshot contract + reconstruct the run.
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.root_seed = fields.get("root_seed")
	snapshot.is_manual_seed = fields.get("is_manual_seed")
	snapshot.meta_progression_eligible = fields.get("meta_progression_eligible")
	snapshot.route_state = fields.get("route_state")
	snapshot.current_route_node_id = fields.get("current_route_node_id")
	snapshot.revealed_route_node_ids = fields.get("revealed_route_node_ids")

	var json_data: Variant = JSON.parse_string(JSON.stringify(snapshot.to_dictionary()))
	assert_true(json_data is Dictionary, "The advanced RunSnapshot should survive JSON stringify/parse.")
	var parse_result: ActionResult = RunSnapshot.parse(json_data)
	assert_true(parse_result.succeeded, "RunSnapshot.parse should accept the advanced route payload: %s" % parse_result.metadata)
	var parsed_snapshot: RunSnapshot = parse_result.metadata.get("snapshot") as RunSnapshot
	assert_equal(parsed_snapshot.route_state.get("run_phase"), "active_route", "Phase must stay nested under route_state and round-trip.")

	var rebuilt: ActionResult = RunState.try_from_run_snapshot_fields({
		"root_seed": parsed_snapshot.root_seed,
		"is_manual_seed": parsed_snapshot.is_manual_seed,
		"meta_progression_eligible": parsed_snapshot.meta_progression_eligible,
		"route_state": parsed_snapshot.route_state,
		"current_route_node_id": parsed_snapshot.current_route_node_id
	})
	assert_true(rebuilt.succeeded, "The advanced run should reconstruct from RunSnapshot fields: %s" % rebuilt.metadata)
	var rebuilt_run: RunState = rebuilt.metadata.get("run_state") as RunState
	assert_equal(rebuilt_run.route.current_node_id, "node-1-0", "The reconstructed run should keep the advanced current node.")
	assert_equal(rebuilt_run.route.node_by_id("node-0-0").reveal_state, RouteNode.REVEAL_CLEARED, "The reconstructed run should keep the cleared left node.")
	assert_equal(rebuilt_run.route.node_by_id("node-2-0").reveal_state, RouteNode.REVEAL_REVEALED, "The reconstructed run should keep the revealed-on-arrival neighbor.")
