class_name RunOrchestrator
extends RefCounted

# The run ORCHESTRATOR (Story 4.6) — the thin type-dispatch start-to-end driver. It is the dispatcher
# Story 4.5 named "the COMMANDS exist now; the run orchestrator (the dispatcher — a later 4.6 concern)".
# It threads ONE RunState + one run-level RngStreamSet + a monotonic run-level sequence_id through the whole
# loop, dispatching the per-node command BY NODE TYPE and stepping forward between nodes — so a 4.2-generated
# route is fully PLAYABLE from a fresh seed to a run_completed endpoint, deterministically.
#
# IT IS A SCENE-FREE RefCounted DOMAIN SERVICE (the `run` domain, alongside RunState/RouteState) — NOT a
# Node, NOT an autoload, NOT a scene. It has NO get_tree/get_node, registers no autoload, and OWNS no
# gameplay decision a command does not: it SEQUENCES the existing 4.3/4.4/4.5 commands UNCHANGED. It draws NO
# RNG itself — only via the commands/generators it calls (route generation in RunStartCommand drew the `map`
# stream; level generation for combat nodes draws the `level` stream through the run-level RngStreamSet).
#
# DISPATCH (the EXACT 4.5 partition — REUSE the constants, do not re-derive the table):
#   - combat / elite_combat (NodeEnterCommand.NODE_TYPE_RECIPE): NodeEnterCommand.execute(run) -> run
#     LevelGenerator.generate(metadata.level_request) (the FIRST 4.x success-path level GenerationResult
#     consumer — read payload.level_seed on success, NEVER result.seed) -> v0 AUTO-RESOLVE combat on a
#     successful generation -> NodeExitCommand.execute(run) (clear + return to ACTIVE_ROUTE).
#   - shop/reforge/gambling/event/secret (NodeResolvePlaceholderCommand.PLACEHOLDER_NODE_TYPES, non-boss):
#     NodeResolvePlaceholderCommand.execute(run) -> NodeExitCommand.execute(run) (the 4.5 round-trip).
#   - boss: NodeResolvePlaceholderCommand.execute(run) (-> COMPLETED + run_completed); STOP (no exit/advance).
#
# V0 COMBAT-AUTO-RESOLVE BOUNDARY ([Decision], documented per the story): there is NO real tactical play loop
# wired into the headless orchestrator. Combat is auto-resolved as "level generated successfully -> node
# cleared" — the orchestrator proves the level GENERATES and is playable (the route<->level handoff +
# determinism, which is what AC1/AC2 require), then exits. Wiring the real tactical board play into the
# orchestrator is a presentation/HUD concern for a later story.
#
# CLEARED-SET LOCKSTEP (4.4/4.5): the orchestrator does NOT clear nodes itself — NodeExitCommand clears
# non-boss nodes on exit, NodeResolvePlaceholderCommand clears the boss on resolve, RouteAdvanceCommand's
# idempotent left-node clear handles the advance-after-clear. The orchestrator just SEQUENCES them.
#
# SEQUENCE IDS (the run-level log seam the 4.3/4.4/4.5 commands referenced — "a run-level log/orchestrator is
# a later story"): the run domain still has no event sequencer, so the orchestrator OWNS a monotonically
# increasing run-level sequence_id, threading the next free id into each command and ADVANCING the counter
# past the events that command emits, so every emitted event across the whole run has a unique id.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const NodeEnterCommand = preload("res://scripts/core/commands/node_enter_command.gd")
const NodeExitCommand = preload("res://scripts/core/commands/node_exit_command.gd")
const NodeResolvePlaceholderCommand = preload("res://scripts/core/commands/node_resolve_placeholder_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteAdvanceCommand = preload("res://scripts/core/commands/route_advance_command.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunStartCommand = preload("res://scripts/core/commands/run_start_command.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")

# The live run-progression state (set by start()/start_from). The orchestrator threads exactly ONE.
var run: RunState = null
# The run-level RNG authority (one RngStreamSet for the whole run). Level generation for combat nodes draws
# its `level` stream through this set; the route-position save round-trips it.
var streams: RngStreamSet = null

# The monotonic run-level event sequence id (the next free id to hand to a command). Starts at 1; advanced
# past every emitted event so ids stay unique across the whole run.
var _next_sequence_id: int = 1
# The run-level run_started + run_completed events surfaced for the caller.
var _run_started_event: DomainEvent = null
var _run_completed_event: DomainEvent = null
var _run_completed_outcome: String = ""
# Repositories for level generation (combat/elite nodes). Default to the baseline repositories; injectable
# for tests. The orchestrator is the ONLY 4.x site that runs LevelGenerator.generate.
var _recipe_repository: LevelRecipeRepository = null
var _enemy_repository: EnemyRepository = null
# Last composed route-position snapshot (set when persistence is requested at a between-node boundary).
var _last_route_position_snapshot: RunSnapshot = null


func _init(
	recipe_repository: LevelRecipeRepository = null,
	enemy_repository: EnemyRepository = null
) -> void:
	_recipe_repository = recipe_repository if recipe_repository != null else LevelRecipeRepository.create_baseline_repository()
	_enemy_repository = enemy_repository if enemy_repository != null else EnemyRepository.create_baseline_repository()


# Start a fresh run from (root_seed, is_manual_seed) via RunStartCommand. Seats the live RunState + the
# run-level RngStreamSet (seeded from the SAME root_seed so route generation in the command and level
# generation here share the run's deterministic streams), captures the run_started event, and advances the
# sequence counter past it. Returns the RunStartCommand result verbatim (surface any error to the caller).
func start(root_seed: int, is_manual_seed: bool = false) -> ActionResult:
	var start_result: ActionResult = RunStartCommand.new(root_seed, is_manual_seed, _next_sequence_id).execute(null)
	if start_result.is_error():
		return start_result
	run = start_result.metadata.get("run") as RunState
	streams = RngStreamSet.new(root_seed)
	_advance_sequence_past(start_result)
	if not start_result.events.is_empty():
		_run_started_event = start_result.events[0]
	return start_result


# Seat an ALREADY-started run (e.g. one restored from a route-position save) + its run-level RngStreamSet, so
# the orchestrator can continue it from the restored boundary. The run MUST be non-terminal and structurally
# valid: seating a terminal or invalid run would make the subsequent run_to_completion behave oddly (an
# already-terminal run returns the stale, null-for-a-seated-run _run_completed_* fields, surfacing
# outcome == ""). Mirrors the command no-partial contract: returns a structured ActionResult and rejects a
# null/terminal/invalid run with a stable code WITHOUT seating anything (the orchestrator stays unseeded so the
# caller cannot accidentally drive a rejected run). On success seats the run/streams/counter and returns ok.
func start_from(existing_run: RunState, existing_streams: RngStreamSet, next_sequence_id: int = 1) -> ActionResult:
	if existing_run == null:
		return ActionResult.error(&"invalid_seated_run", {"command": "run_orchestrator", "reason": "null_run"})
	if existing_streams == null:
		return ActionResult.error(&"invalid_seated_streams", {"command": "run_orchestrator", "reason": "null_streams"})
	if existing_run.is_terminal():
		return ActionResult.error(&"seated_run_terminal", {
			"command": "run_orchestrator",
			"phase": String(existing_run.phase)
		})
	var validation: ActionResult = existing_run.validate()
	if validation.is_error():
		return ActionResult.error(&"invalid_seated_run", {
			"command": "run_orchestrator",
			"inner_error_code": String(validation.error_code),
			"inner_metadata": validation.metadata.duplicate(true)
		})

	run = existing_run
	streams = existing_streams
	_next_sequence_id = maxi(1, next_sequence_id)
	return ActionResult.ok([], {"run": run})


# Resolve the node the run is currently parked on, DISPATCHING BY NODE TYPE. Returns a structured outcome
# ActionResult: ok with diagnostic metadata (including `node_type`, `run_completed`, and for combat nodes the
# generated `level_seed`) on success, or the FIRST command/generation error VERBATIM on failure (no swallow,
# no partial progression). The run is left valid at the boundary on success.
func resolve_current_node() -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})
	if run.is_terminal():
		return ActionResult.error(&"run_already_terminal", {"phase": String(run.phase)})
	var current: RouteNode = run.route.node_by_id(run.route.current_node_id)
	if current == null:
		return ActionResult.error(&"no_current_node", {"command": "run_orchestrator"})

	# Already-cleared no-op guard: if the run is parked on a node already in cleared_node_ids (a post-exit /
	# pre-advance position — e.g. resuming from a route-position save composed before the advance), do NOT
	# re-resolve it. NodeEnterCommand/NodeResolvePlaceholderCommand do not reject an already-cleared parked
	# node (they only check phase/parked/type), so without this guard run_to_completion would needlessly
	# re-enter the cleared node (regenerate a level / re-resolve a placeholder). The idempotent clear guards
	# keep state uncorrupted, but the work is wasted and the semantics are surprising — early-return ok (a
	# no-op) so the loop advances past it instead.
	if run.route.cleared_node_ids.has(current.id):
		return ActionResult.ok([], {
			"node_id": current.id,
			"node_type": String(current.type),
			"resolution": "already_cleared_noop",
			"run_completed": false
		})

	if current.type == RouteNode.TYPE_BOSS:
		return _resolve_boss(current)
	if NodeEnterCommand.NODE_TYPE_RECIPE.has(current.type):
		return _resolve_combat(current)
	return _resolve_non_combat_placeholder(current)


# Advance to a caller-supplied chosen next node (must be eligible). Threads the next sequence id into
# RouteAdvanceCommand and advances the counter past its event. Surfaces the command result verbatim.
func advance_to(chosen_id: String) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})
	var advance: ActionResult = RouteAdvanceCommand.new(chosen_id, _next_sequence_id).execute(run)
	if advance.is_error():
		return advance
	_advance_sequence_past(advance)
	return advance


# Advance to the FIRST eligible choice (the reveal-gated, cleared-excluded forward filter). A non-boss node
# always has one (no soft-lock — the 4.2 reveal-on-arrival invariant). Returns a structured error if the run
# is unexpectedly soft-locked (defensive — proves the no-soft-lock guarantee fails loud if it ever breaks).
func advance_to_first_eligible() -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})
	var eligible: Array[String] = run.route.eligible_choice_ids()
	if eligible.is_empty():
		return ActionResult.error(&"no_eligible_choice", {
			"command": "run_orchestrator",
			"current_node_id": run.route.current_node_id
		})
	return advance_to(eligible[0])


# Drive the run start-to-end: loop resolve-current-node -> (if not terminal) advance-to-first-eligible ->
# until run.is_terminal(). Surfaces the FIRST error verbatim and STOPS on it (no partial run progression).
# On success returns ok with the final run-ended outcome + the run_completed event in metadata. Asserts
# nothing — the load-bearing run.validate()/phase/no-duplicate assertions live in the orchestrator TEST; this
# method is the production driver, so it fails LOUD (returns the error) rather than asserting.
#
# `request_route_position_save_callback` (optional Callable): if provided, it is called with the composed
# route-position RunSnapshot after each between-node boundary (post-exit, pre-advance) so a caller/boot layer
# can persist a between-node autosave. The orchestrator owns the RngStreamSet, so it composes the snapshot;
# the callback only persists it (keeping the commands save-free).
func run_to_completion(request_route_position_save_callback: Variant = null) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})

	var max_steps: int = 256  # generous guard; the boss is at a fixed shallow depth (8 tiers).
	var steps: int = 0
	while not run.is_terminal() and steps < max_steps:
		var resolved: ActionResult = resolve_current_node()
		if resolved.is_error():
			return resolved
		if run.is_terminal():
			break
		var advance: ActionResult = advance_to_first_eligible()
		if advance.is_error():
			return advance
		# Between-node boundary: optionally compose + hand off a route-position autosave (the 4.4 NodeExit
		# autosave seam, now board-free for a route choice). It is composed AFTER advance_to_first_eligible()
		# so the snapshot captures the POST-ADVANCE position (the run parked on a FRESH, unresolved node in
		# ACTIVE_ROUTE) — the exact position shape RunResumeService.resume_route_position +
		# test_run_route_position_save round-trip, NOT the post-exit/pre-advance pointer parked on a
		# just-cleared node (resuming from which would needlessly re-enter an already-cleared node — see the
		# resolve_current_node() already-cleared no-op guard for the defense-in-depth).
		if request_route_position_save_callback is Callable:
			var snapshot: RunSnapshot = compose_route_position_snapshot()
			_last_route_position_snapshot = snapshot
			(request_route_position_save_callback as Callable).call(snapshot)
		steps += 1

	if not run.is_terminal():
		return ActionResult.error(&"run_did_not_complete", {
			"command": "run_orchestrator",
			"steps": steps
		})

	return ActionResult.ok([], {
		"run": run,
		"outcome": _run_completed_outcome,
		"run_completed_event": _run_completed_event,
		"cleared_node_count": run.route.cleared_node_ids.size()
	})


# Compose a board-FREE route-position snapshot of the CURRENT run + the run-level RngStreamSet (Story 4.6
# Task 4.1). A pure read: draws no RNG, mutates nothing. The orchestrator owns the RngStreamSet, so it is the
# right place to compose the route-position save. RunSnapshot.from_route_position returns an ActionResult
# (mirroring from_between_level); the orchestrator always passes a non-null run + streams, so the only error
# path (missing run/streams) is unreachable here — surface the composed RunSnapshot, returning null
# defensively if the (unreachable) error path is ever hit.
func compose_route_position_snapshot() -> RunSnapshot:
	var compose_result: ActionResult = RunSnapshot.from_route_position(run, streams)
	if compose_result.is_error():
		return null
	return compose_result.metadata.get("snapshot") as RunSnapshot


func run_started_event() -> DomainEvent:
	return _run_started_event


func run_completed_event() -> DomainEvent:
	return _run_completed_event


func run_completed_outcome() -> String:
	return _run_completed_outcome


func last_route_position_snapshot() -> RunSnapshot:
	return _last_route_position_snapshot


# ---- internal dispatch ---------------------------------------------------------------------------

# Combat / elite_combat: enter -> run LevelGenerator.generate(level_request) -> v0 auto-resolve on success ->
# exit. The level `level` stream is drawn here (through the run-level RngStreamSet's seed — LevelGenerator
# builds its own attempt-0-unperturbed RngStreamSet from request.level_seed(), the run root_seed). Reads
# payload.level_seed on success (NEVER result.seed — it is "" on success, the 3.7 footgun).
func _resolve_combat(node: RouteNode) -> ActionResult:
	var enter: ActionResult = NodeEnterCommand.new(_next_sequence_id).execute(run)
	if enter.is_error():
		return enter
	_advance_sequence_past(enter)

	var request = enter.metadata.get("level_request")
	var generation: GenerationResult = LevelGenerator.generate(request, _recipe_repository, _enemy_repository)
	if generation.is_error():
		# A combat node whose level cannot generate is a hard run-progression error: surface it structurally
		# (carry the inner phase/code + the node) and STOP — do NOT exit/advance past an un-generated combat
		# node (no partial progression).
		return ActionResult.error(&"level_generation_failed", {
			"command": "run_orchestrator",
			"node_id": node.id,
			"node_type": String(node.type),
			"inner_failed_phase": String(generation.failed_phase),
			"inner_error_code": String(generation.error_code),
			"inner_reason": String(generation.reason)
		})
	# Read the level seed from the SUCCESS payload (payload.level_seed, NOT result.seed).
	var level_seed: String = String(generation.payload.get("level_seed", ""))

	# v0 AUTO-RESOLVE: the level generated and is playable -> the combat node is cleared. Exit it (clear +
	# return to ACTIVE_ROUTE).
	var exit: ActionResult = NodeExitCommand.new(_next_sequence_id).execute(run)
	if exit.is_error():
		return exit
	_advance_sequence_past(exit)

	return ActionResult.ok([], {
		"node_id": node.id,
		"node_type": String(node.type),
		"resolution": "combat_auto_resolved",
		"level_seed": level_seed,
		"level_recipe_id": String(generation.payload.get("recipe_id", "")),
		"level_size_class": String(generation.payload.get("size_class", "")),
		"run_completed": false
	})


# Non-combat placeholder (shop/reforge/gambling/event/secret): resolve -> exit (the 4.5 round-trip).
func _resolve_non_combat_placeholder(node: RouteNode) -> ActionResult:
	var resolved: ActionResult = NodeResolvePlaceholderCommand.new(_next_sequence_id).execute(run)
	if resolved.is_error():
		return resolved
	_advance_sequence_past(resolved)

	var exit: ActionResult = NodeExitCommand.new(_next_sequence_id).execute(run)
	if exit.is_error():
		return exit
	_advance_sequence_past(exit)

	return ActionResult.ok([], {
		"node_id": node.id,
		"node_type": String(node.type),
		"resolution": "placeholder_resolved",
		"run_completed": false
	})


# Boss: resolve to COMPLETED + run_completed (the 4.5 boss path). No exit, no advance — the run ENDS. Capture
# the run_completed event + outcome for the caller.
func _resolve_boss(node: RouteNode) -> ActionResult:
	var resolved: ActionResult = NodeResolvePlaceholderCommand.new(_next_sequence_id).execute(run)
	if resolved.is_error():
		return resolved
	_advance_sequence_past(resolved)

	for event: DomainEvent in resolved.events:
		if event.event_type == DomainEvent.Type.RUN_COMPLETED:
			_run_completed_event = event
			_run_completed_outcome = String(event.payload.get("outcome"))

	return ActionResult.ok([], {
		"node_id": node.id,
		"node_type": String(node.type),
		"resolution": "boss_resolved",
		"run_completed": true,
		"outcome": _run_completed_outcome
	})


# Advance the monotonic run-level sequence counter PAST every event the given command result emitted, so the
# next command gets a fresh, unique id. Each event's sequence_id was assigned from _next_sequence_id (or
# _next_sequence_id + offset for multi-event commands), so the next free id is one past the MAX emitted id.
func _advance_sequence_past(action_result: ActionResult) -> void:
	var max_emitted: int = _next_sequence_id - 1
	for event: DomainEvent in action_result.events:
		if event.sequence_id > max_emitted:
			max_emitted = event.sequence_id
	_next_sequence_id = max_emitted + 1
