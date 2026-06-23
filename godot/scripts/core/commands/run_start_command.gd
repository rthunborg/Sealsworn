class_name RunStartCommand
extends "res://scripts/core/commands/game_command.gd"

# The run-START command (Story 4.6) — the FIRST run_started emitter. It is the ONE genuinely-new command
# in 4.6: where the 4.3/4.4/4.5 run commands take an EXISTING RunState (in ACTIVE_ROUTE / NODE_RESOLUTION),
# this command CREATES the run. From (root_seed, is_manual_seed) it:
#   (1) generates the deterministic 8-12-non-boss-node route via RouteGenerator.generate(root_seed) (the ONE
#       place a run-affecting draw happens — the `map` stream, owned by RouteGenerator, not re-implemented),
#   (2) rehydrates the live RouteState via RouteGenerator.route_from_result(...),
#   (3) builds a fresh RunState (RunState.new_run(...)) and parks current_node_id on the depth-0 start node
#       (always combat — Story 4.2, so AC1's "enter at least one combat level" holds),
#   (4) transitions NEW_RUN -> ACTIVE_ROUTE (a legal edge), and
#   (5) emits ONE run_started DomainEvent carrying the decimal-string root_seed, is_manual_seed, and the
#       bounded [8, 12] non-boss node_count,
# returning the live RunState + the non-boss count in the result metadata. On any rejection it returns a
# structured ActionResult.error with ZERO events and builds NO run (byte-identical no-mutation contract).
#
# CONTEXT SHAPE — Option A ([Decision], per the story AC-interpretation notes): the run does not exist yet,
# so the "take a RunState directly" idiom (4.3/4.4/4.5) does not fit. This command takes the seed + flags in
# its CONSTRUCTOR and execute(_state) BUILDS and returns the new RunState in metadata; the `state` arg is
# UNUSED (accepts null). This keeps the run-start a self-contained "start a run" factory whose output is the
# live run — the cleanest fit for an orchestrator that has no run yet. Option B (a non-command service) was
# REJECTED for the event-emitting path: an emitting action must be a GameCommand returning ActionResult so
# run_started rides the same validate/execute/no-mutation/result contract as every other event.
#
# WHAT THIS IS NOT (scope boundaries):
#   - It does NOT change RouteGenerator / the `map` stream / the route fingerprints (it CONSUMES generation).
#   - It does NOT run LevelGenerator (that is the orchestrator's combat-node concern, Story 4.6 Task 3).
#   - It does NOT re-create / rename / duplicate run_completed (Story 4.5 OWNS it; 4.6 CONSUMES it).
#   - It adds NO new DomainEvent: run_started is the existing 4.1-wired event, emitted here for the first time.
#
# DETERMINISM: a started run is a pure function of (root_seed, is_manual_seed). Same inputs -> byte-identical
# run.to_dictionary() + the same run_started event. The command draws RNG ONLY via the delegated
# RouteGenerator.generate (the `map` stream); it touches no other stream directly.

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var root_seed: int = 0
var is_manual_seed: bool = false
var sequence_id: int = 1

func _init(new_root_seed: int = 0, new_is_manual_seed: bool = false, new_sequence_id: int = 1) -> void:
	command_id = &"run_start"
	root_seed = new_root_seed
	is_manual_seed = new_is_manual_seed
	sequence_id = new_sequence_id


# Pure read: validate the sequence id and the seed. No mutation, no event, no RNG. Option-A context: the
# `state` arg is unused (there is no run to pass in); it accepts null.
func validate(_state: Variant) -> ActionResult:
	# Self-consistency gate (mirror the 4.3/4.4/4.5 commands): execute() builds a run_started event with this
	# sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id would
	# make the success path emit a non-round-trippable event. Reject it BEFORE anything else so a command's
	# success path can never emit an event its own validator rejects.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	# Reject a negative root_seed with a stable code BEFORE generating (mirror RouteGenerator.generate's
	# root_seed < 0 guard; the run domain elsewhere assumes a non-negative seed — RngStreamSet derives streams
	# from it, RunState/RunSnapshot string-encode it on the int64 rule).
	if root_seed < 0:
		return ActionResult.error(&"invalid_run_seed", {
			"command": String(command_id),
			"root_seed": root_seed
		})
	return ActionResult.ok()


# Validate-then-mutate. On success: generate + rehydrate the route, park the start node, transition
# NEW_RUN -> ACTIVE_ROUTE, emit ONE run_started event, and return the live RunState + the bounded non-boss
# count in metadata. Draws RNG ONLY via the delegated RouteGenerator.generate (the `map` stream); builds no
# half-run on failure.
func execute(_state: Variant) -> ActionResult:
	var validation: ActionResult = validate(_state)
	if validation.is_error():
		return validation

	# (1) Generate the route (the ONE place a run-affecting draw happens — the `map` stream, owned by
	# RouteGenerator). On a structured generation failure, surface route_generation_failed carrying the inner
	# phase/code in metadata, emit ZERO events, and build NO half-run.
	var generation = RouteGenerator.generate(root_seed)
	if generation.is_error():
		return ActionResult.error(&"route_generation_failed", {
			"command": String(command_id),
			"root_seed": root_seed,
			"inner_failed_phase": String(generation.failed_phase),
			"inner_error_code": String(generation.error_code),
			"inner_reason": String(generation.reason)
		})

	# (2) Rehydrate the live RouteState from the successful generation result.
	var route: RouteState = RouteGenerator.route_from_result(generation)
	if route == null or route.nodes().is_empty():
		# Defensive: a successful generation result whose route cannot rehydrate (or is empty) is a generator
		# contract break, not a routine reject — surface it structurally rather than crashing on nodes()[0].
		return ActionResult.error(&"route_rehydration_failed", {
			"command": String(command_id),
			"root_seed": root_seed
		})

	# (3) Build a fresh RunState and park the start pointer on the depth-0 start node. RunState.new_run(...)
	# RESETS current_node_id + cleared_node_ids to fresh-run state (the 4.3 fixture trap), which is exactly
	# right here — the start IS a fresh run — so set the start pointer AFTER new_run().
	var run: RunState = RunState.new_run(root_seed, is_manual_seed, route)
	run.route.current_node_id = route.nodes()[0].id

	# (4) Transition NEW_RUN -> ACTIVE_ROUTE (a legal edge; transition_to validates it). Build the event ONLY
	# AFTER the transition succeeds (the 4.4/4.5 mutate-before-infallible-transition discipline). The
	# new_run() default phase is NEW_RUN, so this edge is always legal — but check defensively and surface a
	# structured error WITHOUT having emitted any event if it ever failed.
	var transition: ActionResult = run.transition_to(RunState.PHASE_ACTIVE_ROUTE)
	if transition.is_error():
		return ActionResult.error(&"wrong_run_phase", {
			"command": String(command_id),
			"phase": String(run.phase),
			"expected_phase": String(RunState.PHASE_NEW_RUN),
			"inner_error_code": String(transition.error_code)
		})

	# (5) Build the single run_started event AFTER the transition. node_count is the route's NON-BOSS count
	# (bounded [8, 12], RouteGenerator.PAYLOAD_NODE_COUNT_KEY / metadata.node_count) — a small bounded count,
	# carried as a raw integer (NOT decimal-string encoded; it is a count, not a seed). root_seed is decimal-
	# string encoded by the run_started factory (int64-safe).
	var non_boss_count: int = int(generation.payload.get(RouteGenerator.PAYLOAD_NODE_COUNT_KEY, 0))
	var event: DomainEvent = DomainEvent.run_started(sequence_id, {
		"root_seed": root_seed,
		"is_manual_seed": is_manual_seed,
		"node_count": non_boss_count
	})

	return ActionResult.ok([event], {
		"run": run,
		"node_count": non_boss_count,
		"root_seed": root_seed,
		"is_manual_seed": is_manual_seed
	})
