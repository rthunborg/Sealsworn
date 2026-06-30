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
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const EventDefinition = preload("res://scripts/content/definitions/event_definition.gd")
const EventOffer = preload("res://scripts/run/event_offer.gd")
const EventRepository = preload("res://scripts/content/repositories/event_repository.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const GoldRewardDefinition = preload("res://scripts/content/definitions/gold_reward_definition.gd")
const GoldRewardRepository = preload("res://scripts/content/repositories/gold_reward_repository.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const NodeEnterCommand = preload("res://scripts/core/commands/node_enter_command.gd")
const NodeExitCommand = preload("res://scripts/core/commands/node_exit_command.gd")
const NodeResolvePlaceholderCommand = preload("res://scripts/core/commands/node_resolve_placeholder_command.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RewardOfferBuilder = preload("res://scripts/content/reward_offer_builder.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")
const RewardTableRepository = preload("res://scripts/content/repositories/reward_table_repository.gd")
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
# The reward-table repository for the reward GENERATE path (Story 6.3). Default to the baseline repository;
# injectable for tests (mirrors the recipe/enemy injection). Resolves a table id to a VALIDATED
# RewardTableDefinition (fail-closed null on a miss) — the reward-table validate-before-draw posture (the 6.1
# [Review][Decision]) is satisfied by routing every draw through this repo (validated tables only) + the builder
# (which re-validates before drawing).
var _reward_table_repository: RewardTableRepository = null
# Story 7.1: the gold-reward repository for the GENERATE-time gold roll (the T1 wire-off). Default to the baseline
# repository; injectable for tests (mirrors the reward-table injection). Resolves a gold-reward content id (the
# offered gold entry's content_id) to its typed GoldRewardDefinition so the orchestrator can roll gold_min..gold_max
# within the BAND. The roll routes through the run-level streams (the named-RNG rule); fail-closed on a repo miss.
var _gold_reward_repository: GoldRewardRepository = null
# Story 7.3: the risk/reward-EVENT repository for the GENERATE-time event offer (the FIRST `events`-stream consumer).
# Default to the baseline repository; injectable for tests (mirrors the reward-table/gold-reward injection). Resolves an
# event id to its typed EventDefinition (validated events only); fail-closed `unknown_event` on a repo miss. When the
# caller supplies no specific event id, generate_event_offer SELECTS one from this repository's baseline deterministically
# through the `events` stream.
var _event_repository: EventRepository = null
# Story 7.4: the AFFINITY repository for the deterministic affinity ASSIGNMENT (AC2). Default to the baseline
# repository; injectable for tests (mirrors the event/reward-table/gold-reward injection). Resolves the SELECTED
# affinity id to its typed AffinityDefinition (validated affinities only); fail-closed `unknown_affinity` on a repo
# miss. assign_affinity SELECTS one from this repository's baseline deterministically through the `map` stream.
var _affinity_repository: AffinityRepository = null
# Last composed route-position snapshot (set when persistence is requested at a between-node boundary).
var _last_route_position_snapshot: RunSnapshot = null


func _init(
	recipe_repository: LevelRecipeRepository = null,
	enemy_repository: EnemyRepository = null,
	reward_table_repository: RewardTableRepository = null,
	gold_reward_repository: GoldRewardRepository = null,
	event_repository: EventRepository = null,
	affinity_repository: AffinityRepository = null
) -> void:
	_recipe_repository = recipe_repository if recipe_repository != null else LevelRecipeRepository.create_baseline_repository()
	_enemy_repository = enemy_repository if enemy_repository != null else EnemyRepository.create_baseline_repository()
	_reward_table_repository = reward_table_repository if reward_table_repository != null else RewardTableRepository.create_baseline_repository()
	_gold_reward_repository = gold_reward_repository if gold_reward_repository != null else GoldRewardRepository.create_baseline_repository()
	_event_repository = event_repository if event_repository != null else EventRepository.create_baseline_repository()
	_affinity_repository = affinity_repository if affinity_repository != null else AffinityRepository.create_baseline_repository()


# Start a fresh run from (root_seed, is_manual_seed[, class_id]) via RunStartCommand. Seats the live RunState
# + the run-level RngStreamSet (seeded from the SAME root_seed so route generation in the command and level
# generation here share the run's deterministic streams), captures the run_started event, and advances the
# sequence counter past it. Returns the RunStartCommand result verbatim (surface any error to the caller).
#
# Story 5.2 (the confirm-path seam — direct orchestrator entry): an OPTIONAL class_id (default &"" = the
# legacy "no class chosen" start) is threaded into RunStartCommand.new(...). The command resolves it through
# its injected ClassRepository and REJECTS fail-closed on an unknown/locked class BEFORE building any run — so
# a rejected start surfaces the command's unknown_class / class_not_selectable error VERBATIM and seats NO run
# (the orchestrator stays unseeded; the caller cannot drive a rejected run). On success the seated run records
# selected_class_id (AC3). The hero-select HeroSelectViewModel.is_class_selectable(id) is the UI-side pre-gate;
# THIS command path is the authoritative fail-closed gate (AC2 — "no run can start with the locked class").
func start(root_seed: int, is_manual_seed: bool = false, class_id: StringName = &"") -> ActionResult:
	var start_result: ActionResult = RunStartCommand.new(root_seed, is_manual_seed, _next_sequence_id, class_id).execute(null)
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


# ---- reward offer generation (Story 6.3 — the FIRST live reward roll + the T2 inert-stream fix) --------------

# GENERATE a deterministic SINGLE-PICK reward offer from `table_id`, drawing through the RUN-LEVEL RngStreamSet
# (`streams`) on `stream_name` (rewards / loot) via the EXISTING RewardOfferBuilder, and STORE it on RunState as
# `pending`. This is the T2 fix: the draw advances the SAME run-level set the route-position save persists (so a
# route-position save composed AFTER a reward roll round-trips an ADVANCED stream — interrupted == uninterrupted
# determinism once RNG advances mid-run). Resolves the table through _reward_table_repository (validated tables
# only) -> hands the resolved RewardTableDefinition to the builder (which re-validates before the draw) — the 6.1
# validate-before-draw [Review][Decision] is satisfied end-to-end (never a hand-rolled draw against an
# unvalidated table). Emits a reward_offered event + advances the sequence counter. Returns the builder/table
# error VERBATIM on failure (no partial offer); fail-closed `unknown_reward_table` on a repository miss; rejects
# a generate while an offer is still pending (`reward_offer_pending`).
#
# stream_name defaults to STREAM_REWARDS (a standard combat/reward offer). A LOOT offer passes STREAM_LOOT.
func generate_reward_offer(table_id: StringName, stream_name: StringName = RngStreamSet.STREAM_REWARDS) -> ActionResult:
	var precheck: ActionResult = _reward_generate_precheck(table_id)
	if precheck.is_error():
		return precheck
	var table: RewardTableDefinition = precheck.metadata.get("table") as RewardTableDefinition

	# The ONE RNG draw — through the RUN-LEVEL streams (the T2 fix), via the builder (validate-before-draw).
	var draw: ActionResult = RewardOfferBuilder.new().build_offer(streams, stream_name, table)
	if draw.is_error():
		return draw

	var offer_payload: Dictionary = draw.metadata.get("offer")
	var selected: Dictionary = offer_payload.get("selected")
	var offered_entries: Array = [{
		"category": String(selected.get("category")),
		"content_id": String(selected.get("content_id"))
	}]

	# Story 7.1 (the T1 wire-off, GENERATE half): when the drawn entry is a GOLD reward, roll the CONCRETE gold amount
	# within the GoldRewardDefinition's gold_min..gold_max BAND NOW (a SECOND draw on the SAME run-level stream — the
	# named-RNG rule + deterministic/reproducible from the seed/state), so RESOLVE stays purely deterministic (it
	# credits the already-rolled amount, drawing ZERO new RNG — the Epic-6 zero-new-RNG-on-resolve invariant). A
	# non-gold entry rolls no gold (gold_amount stays 0). A gold entry whose definition does not resolve is a
	# fail-closed error (never a fabricated amount).
	var gold_amount: int = 0
	if StringName(String(selected.get("category"))) == RewardTableDefinition.CATEGORY_GOLD:
		var gold_result: ActionResult = _roll_gold_amount(StringName(String(selected.get("content_id"))), stream_name)
		if gold_result.is_error():
			return gold_result
		gold_amount = int(gold_result.metadata.get("gold_amount"))

	return _store_offer_and_emit(table, offered_entries, draw, stream_name, gold_amount)


# GENERATE a deterministic AC4 3-CHOICE PASSIVE reward offer from `table_id`, drawing THREE DISTINCT passive
# content ids WITHOUT REPLACEMENT through the run-level streams (re-drawing a duplicate via the builder — each
# draw advances the SAME run-level stream, so it is deterministic + reproduces from the same seed/state). The
# table's declared `choice_count` is the target distinct count (3 for a passive 3-choice moment); a table whose
# distinct-content-id count is below `choice_count` is VALID only with the explicit MVP exception marker (enforced
# by RewardTableDefinition.validate() at registration), and this path then offers as many distinct as the table
# can yield (the sanctioned reduced density). Stores the offer on RunState as `pending`, emits reward_offered,
# advances the sequence. Same stream contract (default STREAM_REWARDS). Provenance (roll/draw_index/state_after)
# reflects the LAST draw of the multi-pick.
func generate_passive_reward_offer(table_id: StringName, stream_name: StringName = RngStreamSet.STREAM_REWARDS) -> ActionResult:
	var precheck: ActionResult = _reward_generate_precheck(table_id)
	if precheck.is_error():
		return precheck
	var table: RewardTableDefinition = precheck.metadata.get("table") as RewardTableDefinition

	# The target distinct count: the table's declared choice_count, capped by the distinct content ids available
	# (a validated non-exception table has distinct_count >= choice_count; an exception-marked table may have
	# fewer, in which case the sanctioned reduced density is offered).
	var target: int = mini(table.choice_count, table.distinct_content_id_count())
	if target < 1:
		target = 1

	var offered_entries: Array = []
	var seen: Dictionary = {}
	var last_draw: ActionResult = null
	# Deterministic draw-without-replacement: keep drawing through the run-level stream, skipping a duplicate
	# content_id, until `target` distinct entries are collected. A generous attempt bound guards against a
	# pathological table (never reached for a validated table: distinct_count >= target by construction).
	var max_attempts: int = maxi(target * 64, 64)
	var attempts: int = 0
	while offered_entries.size() < target and attempts < max_attempts:
		attempts += 1
		var draw: ActionResult = RewardOfferBuilder.new().build_offer(streams, stream_name, table)
		if draw.is_error():
			return draw
		last_draw = draw
		var selected: Dictionary = draw.metadata.get("offer").get("selected")
		var content_id: String = String(selected.get("content_id"))
		if seen.has(content_id):
			continue
		seen[content_id] = true
		offered_entries.append({
			"category": String(selected.get("category")),
			"content_id": content_id
		})

	if offered_entries.is_empty() or last_draw == null:
		# Defensive: a validated table always yields >= 1 distinct entry; fail closed rather than store an empty
		# offer (never fabricate a default).
		return ActionResult.error(&"reward_offer_generation_failed", {
			"command": "run_orchestrator",
			"table_id": String(table_id)
		})
	# A passive 3-choice offer never offers gold (the choices are all passives), so gold_amount stays 0.
	return _store_offer_and_emit(table, offered_entries, last_draw, stream_name, 0)


# Shared GENERATE precheck: the orchestrator must be seated (a non-null run), no offer may already be pending
# (resolve the prior offer first — never silently overwrite an unresolved offer, which would drop a reward), and
# the table id must resolve through the repository (validated tables only; fail-closed unknown_reward_table on a
# miss). On success returns ok with metadata.table.
func _reward_generate_precheck(table_id: StringName) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})
	if run.pending_reward_offer != null and run.pending_reward_offer.is_pending():
		# An unresolved offer is still open — generating a new one would silently drop it. Fail closed.
		return ActionResult.error(&"reward_offer_pending", {
			"command": "run_orchestrator",
			"table_id": String(run.pending_reward_offer.table_id)
		})
	var table: RewardTableDefinition = _reward_table_repository.get_reward_table(table_id)
	if table == null:
		return ActionResult.error(&"unknown_reward_table", {
			"command": "run_orchestrator",
			"table_id": String(table_id)
		})
	return ActionResult.ok([], {"table": table})


# Story 7.1 (the T1 wire-off, GENERATE half): resolve `gold_reward_id` to its GoldRewardDefinition through the
# gold-reward repository and roll a CONCRETE amount in [gold_min, gold_max] through the RUN-LEVEL streams on
# `stream_name` (the SAME stream the offer drew through — a SECOND named-stream draw, deterministic + reproducible).
# Returns ok with metadata.gold_amount, or a fail-closed error (never a fabricated amount): unknown_gold_reward on a
# repo miss, or the stream's error VERBATIM. The roll is the ONLY new RNG site this story adds, and it routes
# EXCLUSIVELY through the run-level set (NEVER randi/randf/a new RandomNumberGenerator).
func _roll_gold_amount(gold_reward_id: StringName, stream_name: StringName) -> ActionResult:
	var definition: GoldRewardDefinition = _gold_reward_repository.get_gold_reward(gold_reward_id)
	if definition == null:
		return ActionResult.error(&"unknown_gold_reward", {
			"command": "run_orchestrator",
			"gold_reward_id": String(gold_reward_id)
		})
	# Roll within the inclusive band [gold_min, gold_max] (validate() guarantees 0 <= gold_min <= gold_max). A
	# collapsed band (min == max) draws the count anyway so the stream advances identically (mirroring the generator's
	# always-fire count-draw discipline).
	var draw: ActionResult = streams.rand_int(stream_name, definition.gold_min, definition.gold_max, {"consumer": "gold_reward_roll", "gold_reward_id": String(gold_reward_id)})
	if draw.is_error():
		return draw
	return ActionResult.ok([], {"gold_amount": int(draw.metadata.get("value"))})


# Store the generated offer on RunState as `pending`, emit the reward_offered event, advance the sequence counter,
# and return ok with the offer + event. `provenance_draw` is the builder ActionResult whose metadata carries the
# roll/draw_index/state_after (the last draw for a multi-pick). Shared by the single + multi pick paths.
func _store_offer_and_emit(table: RewardTableDefinition, offered_entries: Array, provenance_draw: ActionResult, stream_name: StringName, gold_amount: int) -> ActionResult:
	var offer: RewardOffer = RewardOffer.new(
		table.table_id,
		RewardOffer.STATUS_PENDING,
		offered_entries,
		{},
		String(stream_name),
		int(provenance_draw.metadata.get("offer").get("roll")),
		int(provenance_draw.metadata.get("draw_index")),
		int(provenance_draw.metadata.get("state_after")),
		gold_amount
	)
	run.pending_reward_offer = offer

	var offered_event: DomainEvent = DomainEvent.reward_offered(_next_sequence_id, {
		"table_id": String(table.table_id),
		"offered_entries": offered_entries,
		"roll": offer.roll,
		"draw_index": offer.draw_index
	})
	var result: ActionResult = ActionResult.ok([offered_event], {
		"reward_offered": true,
		"table_id": String(table.table_id),
		"offered_entries": offered_entries,
		"stream_name": String(stream_name),
		"offer": offer.to_dictionary()
	})
	_advance_sequence_past(result)
	return result


# GENERATE a deterministic risk/reward EVENT offer (Story 7.3, AC1), drawing through the RUN-LEVEL RngStreamSet
# (`streams`) on the `events` stream (STREAM_EVENTS) — the FIRST `events`-stream consumer. The draw deterministically
# SELECTS which approved EventDefinition to OFFER from `_event_repository` (or, when the caller supplies a specific
# `event_id`, presents THAT event while still advancing the `events` stream for reproducible provenance), stores the
# EventOffer on RunState as `pending`, emits an event_offered record, and advances the sequence counter. Deterministic +
# reproducible from the seed/state (same seed + same pre-draw state -> same offered event/choices). The offer carries
# the offered event's choice ids; ChooseEventOptionCommand later applies the player's pick (drawing ZERO new RNG — the
# choice amounts are AUTHORED on the definition, so the OFFER roll here is the ONLY `events` draw). Fail-closed:
# `no_active_run` (orchestrator unseated), `event_offer_pending` (an unresolved event offer is already open — never
# silently overwrite it), `no_events_available` (an empty repository), `unknown_event` (a supplied id that does not
# resolve through the validated-only repository — the validate-before-use gate). The draw routes EXCLUSIVELY through the
# run-level set (NEVER randi/randf/a new RandomNumberGenerator).
#
# CALLER-DRIVEN (the 6.3 generate_reward_offer posture VERBATIM): this is NOT wired into _resolve_combat /
# _resolve_non_combat_placeholder / run_to_completion — the `event` node still resolves through
# NodeResolvePlaceholderCommand (the no-soft-lock partition). A later HUD/run-flow story owns the "enter event node ->
# generate offer -> present choices -> choose" call site + the auto-resolution policy. Keeping it OFF the auto-resolve
# loop means a route-position save composed in that loop is never perturbed by an `events` draw (interrupted ==
# uninterrupted determinism holds).
func generate_event_offer(event_id: StringName = &"", stream_name: StringName = RngStreamSet.STREAM_EVENTS) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})
	if run.pending_event_offer != null and run.pending_event_offer.is_pending():
		# An unresolved event offer is still open — generating a new one would silently drop it. Fail closed.
		return ActionResult.error(&"event_offer_pending", {
			"command": "run_orchestrator",
			"event_id": String(run.pending_event_offer.event_id)
		})

	# The candidate event id set: a single explicit id (presented verbatim, fail-closed on a repo miss), or the whole
	# repository baseline (the `events` draw SELECTS one). Resolving every candidate through the validated-only repo
	# satisfies the validate-before-use gate (a fabricated/invalid event can never be offered).
	var candidate_ids: Array[StringName] = []
	if String(event_id).is_empty():
		candidate_ids = _event_repository.event_ids()
		if candidate_ids.is_empty():
			return ActionResult.error(&"no_events_available", {"command": "run_orchestrator"})
	else:
		if _event_repository.get_event(event_id) == null:
			return ActionResult.error(&"unknown_event", {
				"command": "run_orchestrator",
				"event_id": String(event_id)
			})
		candidate_ids = [event_id]

	# The ONE RNG draw — through the RUN-LEVEL streams on the `events` stream. roll selects the offered event index over
	# [0, candidate_ids.size() - 1] (a single-candidate roll still draws so the stream advances identically — the
	# generator's always-fire count-draw discipline). Routes EXCLUSIVELY through streams.rand_int (never randi/randf).
	var draw: ActionResult = streams.rand_int(stream_name, 0, candidate_ids.size() - 1, {"consumer": "event_offer_select", "candidate_count": candidate_ids.size()})
	if draw.is_error():
		return draw
	var roll: int = int(draw.metadata.get("value"))
	var selected_event_id: StringName = candidate_ids[roll]

	# Resolve the SELECTED event (re-validate-before-use; it is in the repo, so this is non-null) and snapshot its
	# offered choice ids.
	var definition: EventDefinition = _event_repository.get_event(selected_event_id)
	if definition == null:
		# Defensive: a selected id is always in the repo; fail closed rather than store a fabricated offer.
		return ActionResult.error(&"unknown_event", {
			"command": "run_orchestrator",
			"event_id": String(selected_event_id)
		})
	var offered_choice_ids: Array = []
	for choice_id: StringName in definition.choice_ids():
		offered_choice_ids.append(String(choice_id))

	# Store the offer on RunState as pending.
	var offer: EventOffer = EventOffer.new(
		definition.event_id,
		EventOffer.STATUS_PENDING,
		offered_choice_ids,
		&"",
		String(stream_name),
		roll,
		int(draw.metadata.get("draw_index")),
		int(draw.metadata.get("state_after"))
	)
	run.pending_event_offer = offer

	# Emit the event_offered record (the GENERATE provenance — DOES carry roll/draw_index because the OFFER was rolled).
	var offered_event: DomainEvent = DomainEvent.event_offered(_next_sequence_id, {
		"event_id": String(definition.event_id),
		"offered_choice_ids": offered_choice_ids,
		"roll": offer.roll,
		"draw_index": offer.draw_index
	})
	var result: ActionResult = ActionResult.ok([offered_event], {
		"event_offered": true,
		"event_id": String(definition.event_id),
		"offered_choice_ids": offered_choice_ids,
		"stream_name": String(stream_name),
		"offer": offer.to_dictionary()
	})
	_advance_sequence_past(result)
	return result


# ---- affinity assignment (Story 7.4 — the deterministic per-level affinity SELECT + RECORD, AC2) ----------------

# ASSIGN a deterministic affinity to the given route node and RECORD it in the level snapshot (AC2). It draws ONE roll
# through the RUN-LEVEL RngStreamSet (`streams`) on the `map` stream (STREAM_MAP — the route-structure stream
# RouteGenerator already uses; GDD line 225 groups "affinity assignments" with the run map / node structure / level
# layouts, so affinity is a ROUTE-STRUCTURE-level identity). The roll deterministically SELECTS an affinity id (incl.
# the neutral `none`) from `_affinity_repository`'s baseline; the SELECTED id is resolved back through the validated-only
# repository (fail-closed `unknown_affinity` on a miss — the validate-before-USE gate); and the id is RECORDED on
# RunState.assigned_affinities keyed by the node id (the source of truth; RunSnapshot.from_route_position MIRRORS it into
# the existing top-level RunSnapshot.affinities placeholder, so it is reproducibly readable from the recorded snapshot).
#
# DETERMINISTIC + REPRODUCIBLE (AC2; the GDD line 225 "Seeds reproduce ... affinity assignments" invariant): the node id
# rides the draw `consumer_context`, and the roll keys off the `map` stream's state, so the SAME (root_seed, pre-draw map
# state) -> the SAME selected affinity. Re-running for the same node re-draws (the map stream advances) and records the
# same value for that pre-draw state — assignment is a pure deterministic function of the seed + route position.
#
# CALLER-DRIVEN (the 6.3 generate_reward_offer / 7.3 generate_event_offer posture VERBATIM): this is NOT wired into
# _resolve_combat / _resolve_non_combat_placeholder / run_to_completion — a level still generates + auto-resolves without
# an affinity. A later HUD/run-flow story owns the "enter node -> assign affinity -> apply effects" call site (the EFFECTS
# are 7.5/7.6). Keeping it OFF the auto-resolve loop means a route-position save composed in that loop is never perturbed
# by a `map`-stream affinity draw unless the caller explicitly assigned one.
#
# THE 4.6 inert run-level RngStreamSet INJECTION HALF (RE-AFFIRMED across 7.1/7.2/7.3 to "the later level-gen-RNG story
# 7.4/7.5"): the affinity draw routes through the orchestrator's run-level `streams` (a run-level/route-structure draw),
# NOT inside LevelGenerator.generate (which still mints its OWN level-stream RngStreamSet from request.level_seed()). So
# 7.4 KNOWINGLY WORKS AROUND the injection half (adds NO new inert-stream exposure, regresses no determinism, perturbs no
# generator/route fingerprint) and RE-AFFIRMS the injection-into-LevelGenerator.generate half to 7.5 (the affinity-EFFECTS
# story that may need the run-level set INSIDE generation to apply hazard/terrain effects).
#
# Fail-closed: `no_active_run` (orchestrator unseated), `invalid_affinity_node` (a null/empty-id node — assignment must
# key off a real node id), `no_affinities_available` (an empty repository), `unknown_affinity` (a selected id that does
# not resolve — defensive, since the id came from the repository). The draw routes EXCLUSIVELY through the run-level set
# (NEVER randi/randf/a new RandomNumberGenerator).
func assign_affinity(node: RouteNode, stream_name: StringName = RngStreamSet.STREAM_MAP) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})
	if node == null or String(node.id).is_empty():
		return ActionResult.error(&"invalid_affinity_node", {"command": "run_orchestrator"})

	# The candidate affinity ids: the whole repository baseline (incl. the neutral `none`). Resolving the SELECTED id
	# through the validated-only repo satisfies the validate-before-USE gate (a fabricated/invalid affinity can never be
	# assigned).
	var candidate_ids: Array[StringName] = _affinity_repository.affinity_ids()
	if candidate_ids.is_empty():
		return ActionResult.error(&"no_affinities_available", {"command": "run_orchestrator"})

	# The ONE RNG draw — through the RUN-LEVEL streams on the `map` stream. roll selects the assigned affinity index over
	# [0, candidate_ids.size() - 1] (a single-candidate roll still draws so the stream advances identically — the
	# generator's always-fire count-draw discipline). The node id rides the consumer_context so the assignment is a
	# reproducible function of (root_seed, route position). Routes EXCLUSIVELY through streams.rand_int (never randi/randf).
	var draw: ActionResult = streams.rand_int(stream_name, 0, candidate_ids.size() - 1, {"consumer": "affinity_assign", "node_id": String(node.id)})
	if draw.is_error():
		return draw
	var roll: int = int(draw.metadata.get("value"))
	var selected_affinity_id: StringName = candidate_ids[roll]

	# Resolve the SELECTED affinity (re-validate-before-use; it is in the repo, so this is non-null) — fail closed rather
	# than record a fabricated id.
	var definition: AffinityDefinition = _affinity_repository.get_affinity(selected_affinity_id)
	if definition == null:
		return ActionResult.error(&"unknown_affinity", {
			"command": "run_orchestrator",
			"affinity_id": String(selected_affinity_id)
		})

	# RECORD the assigned affinity id on the run, keyed by node id (the AC2 "recorded in the level snapshot" source of
	# truth — RunSnapshot.from_route_position mirrors it into the top-level affinities placeholder).
	run.assigned_affinities[String(node.id)] = String(definition.affinity_id)

	return ActionResult.ok([], {
		"node_id": String(node.id),
		"affinity_id": String(definition.affinity_id),
		"is_neutral": definition.is_neutral(),
		"stream_name": String(stream_name),
		"roll": roll,
		"draw_index": int(draw.metadata.get("draw_index"))
	})


# The recorded affinity id for a node (AC2 read-back), or the neutral `none` id when no affinity was assigned to it
# (the AC3 no-affinity default — a node with no assigned affinity reads as `none`). A PURE READ (no RNG, no mutation).
func assigned_affinity_for(node_id: String) -> StringName:
	if run == null:
		return AffinityDefinition.AFFINITY_NONE
	return StringName(String(run.assigned_affinities.get(node_id, String(AffinityDefinition.AFFINITY_NONE))))


func affinity_repository() -> AffinityRepository:
	return _affinity_repository


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
