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
# V0 COMBAT-AUTO-RESOLVE BOUNDARY ([Decision], documented per the story): the DEFAULT run driver
# (resolve_current_node / run_to_completion) AUTO-RESOLVES combat as "level generated successfully -> node
# cleared" — it proves the level GENERATES and is playable (the route<->level handoff + determinism), then
# exits. This auto-resolve path is RETAINED for the explicitly-NON-LIVE simulation / headless seed-batch use
# (a fast deterministic driver whose stream advancement the interrupted==uninterrupted route-position save
# depends on; it must NOT change).
#
# STORY 11.2 — THE LIVE RUN FLOW (additive, opt-in; the DEFAULT path above is UNCHANGED): resolve_current_node_live
# / run_to_completion_live resolve a combat/elite node from REAL tactical play on the board (LiveCombatResolver —
# the generalized Epic-1 micro-combat loop) to a terminal CombatOutcomeState, and a live DEFEAT auto-fires the
# run-end hero-death SOURCE (resolve_run_end -> PHASE_FAILED). auto_play_boss_fight / auto_play_full_run auto-play
# the Larval Avatar fight (both sides simulated) to the boss VICTORY production call site (resolve_boss_victory).
# These are OPT-IN live drivers layered ON TOP of the unchanged default methods — a live fight is NEVER silently
# auto-resolved, and the default run_to_completion (used by the reward/route/finale fingerprints) is byte-identical.
# The on-screen HUD that RENDERS this live loop is Story 11.3; 11.2 wires the scene-free domain seam only.
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
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossNodeEnterCommand = preload("res://scripts/core/commands/boss_node_enter_command.gd")
const BossRepository = preload("res://scripts/content/repositories/boss_repository.gd")
const BossTurnResolver = preload("res://scripts/tactical/turns/boss_turn_resolver.gd")
const CompleteRunCommand = preload("res://scripts/core/commands/complete_run_command.gd")
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
const LiveCombatResolver = preload("res://scripts/run/live_combat_resolver.gd")
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
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

# Story 11.2: the live-flow entity ids (the hero the LiveCombatResolver/boss auto-play place on the board) + the boss
# entity id. The hero + boss are placed by the run flow (generation places enemies only); these match the ids the
# existing tactical resolvers key off (EnemyTurnResolver HERO_ID default, BossTurnResolver larval_avatar).
const HERO_ID := &"hero"
const BOSS_ID := &"larval_avatar"
# Story 11.2: the caller-reserved sequence-id base for the boss auto-play's interleaved fight log (above any run-level
# route-event id so the merged boss-action + phase-change + boss_defeat ids never collide with the run_completed id the
# orchestrator assigns from its own lower counter — the sequence-id seam contract). Mirrors test_finale_full_run's
# fight_base = 100000.
const BOSS_FIGHT_SEQUENCE_BASE: int = 100000

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
# Story 8.1: the run-FAILED event + cause + the run-end next-destination flow signal surfaced for the caller (set by
# resolve_run_end). The boss path (4.5) populates _run_completed_*; the 8.1 generic completion / death path populates
# these via the CompleteRunCommand-driven resolve_run_end hook.
var _run_failed_event: DomainEvent = null
var _run_failed_cause: String = ""
var _run_end_destination: String = ""
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
# Story 9.1: the boss-ENCOUNTER-SETUP surface. When the boss node resolves, _resolve_boss SETS UP the Larval
# Avatar encounter (build the request + arena, transition ACTIVE_ROUTE -> NODE_RESOLUTION) and leaves the run in
# NODE_RESOLUTION awaiting the real fight/victory (9.3/9.4) — it does NOT complete the run anymore. These capture
# the boss-entered event + the live request + the arena payload for the caller (the later live boss loop). The
# pending flag lets run_to_completion STOP at the boss setup (a non-terminal boss awaiting the fight).
var _boss_encounter_started_event: DomainEvent = null
var _boss_encounter_request = null
var _boss_arena_payload: Dictionary = {}
var _boss_encounter_pending: bool = false


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
		# Story 9.1: the boss node now SETS UP the encounter (BossNodeEnterCommand) instead of auto-completing —
		# the run is left in NODE_RESOLUTION (non-terminal) awaiting the real fight/victory (9.3/9.4). STOP the
		# loop here: the boss has no forward choice (advance_to_first_eligible would fail), and there is no live
		# fight to auto-play in v0. The run is NOT terminal; the caller (the later live boss loop) drives the fight.
		# Do NOT auto-complete the run on boss arrival (the run-END is 9.4's victory or a death).
		if _boss_encounter_pending:
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

	# Story 9.1: the boss-encounter-SETUP terminus. The loop STOPS at the boss setup with the run non-terminal
	# (in NODE_RESOLUTION, the boss encounter requested + its arena built) — the real fight/victory is 9.3/9.4. This
	# is a SUCCESS (the run reached its terminal boss node and set up the encounter), NOT the run_did_not_complete
	# soft-lock error. Surface the boss-encounter setup for the caller (the live boss loop drives the fight).
	if _boss_encounter_pending and not run.is_terminal():
		return ActionResult.ok([], {
			"run": run,
			"outcome": "",
			"resolution": "boss_encounter_started",
			"boss_encounter_pending": true,
			"boss_encounter_started_event": _boss_encounter_started_event,
			"arena_payload": _boss_arena_payload,
			"cleared_node_count": run.route.cleared_node_ids.size()
		})

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


# ---- run-END resolution (Story 8.1 — the OPTIONAL thin dispatch hook, AC1/AC2/AC3) --------------------------------

# Resolve the seated run's END through CompleteRunCommand (mirroring _resolve_boss's command-dispatch + event-capture
# shape), surfacing the run_failed/run_completed event + the cause/outcome + the next-destination flow signal for the
# caller. `outcome` is EITHER a death cause (DomainEvent.RUN_FAILED_CAUSES — death -> PHASE_FAILED + run_failed, AC1)
# OR the completion marker (DomainEvent.RUN_COMPLETED_OUTCOME_COMPLETED — completion -> PHASE_COMPLETED + run_completed,
# AC2). Threads the next free run-level sequence id into the command and advances the counter past its event. Returns
# the command result VERBATIM (surface any error — wrong phase / already-terminal / unknown outcome — to the caller),
# capturing the surfaced fields only on success.
#
# CALLER-DRIVEN (the 6.3 generate_reward_offer / 7.3 generate_event_offer posture VERBATIM): this is NOT wired into
# run_to_completion / _resolve_combat / _resolve_non_combat_placeholder — there is NO live death source in v0 (combat
# auto-resolves to success), so a death NEVER auto-fires; the caller (a later HUD/run-flow story that owns the live
# death / a real victory) invokes it explicitly. Since Story 9.1, _resolve_boss no longer auto-completes the run:
# it SETS UP the Larval Avatar encounter via BossNodeEnterCommand (the run parks non-terminal in NODE_RESOLUTION,
# emitting boss_encounter_started — it does NOT resolve through NodeResolvePlaceholderCommand in the live path).
# NodeResolvePlaceholderCommand's boss branch (the boss run_completed / boss_placeholder / boss_node_id boundary) is
# retained UNCHANGED for Story 9.4 to reuse — it is just no longer the orchestrator's live boss dispatch. resolve_run_end
# stays the generic caller-driven run-END path; 9.4's boss VICTORY drives it (via CompleteRunCommand) from the
# boss-setup terminus. AC3 idempotency is the command's: a re-resolution of an already-terminal run surfaces the
# command's stable run_already_terminal error here (the orchestrator captures nothing new — no second event, no mutation).
func resolve_run_end(outcome: StringName) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})
	var resolved: ActionResult = CompleteRunCommand.new(outcome, _next_sequence_id).execute(run)
	if resolved.is_error():
		return resolved
	_advance_sequence_past(resolved)

	# Capture the surfaced run-end fields (the next-destination flow signal + the cause/outcome) for the caller.
	_run_end_destination = String(resolved.metadata.get("next_destination", ""))
	for event: DomainEvent in resolved.events:
		if event.event_type == DomainEvent.Type.RUN_FAILED:
			_run_failed_event = event
			_run_failed_cause = String(event.payload.get("cause"))
		elif event.event_type == DomainEvent.Type.RUN_COMPLETED:
			_run_completed_event = event
			_run_completed_outcome = String(event.payload.get("outcome"))
	return resolved


# Resolve the boss VICTORY from the boss-setup terminus (Story 9.5, AC2 — the THIN caller-driven integration
# continuation, NOT an auto-play loop). It is the seam that closes the long-parked "the boss-defeat -> run-victory chain
# has no production call site" (9.4's review recorded this; a human accepted it belongs to 9.5): after the caller has
# driven the live boss fight to 0 HP on the arena board (via BossTurnResolver's explicit turns — the 9.3 posture, NOT an
# auto-played loop inside run_to_completion) and confirmed the boss is defeated (detect_boss_defeat), this method (1)
# CLEARS the boss route node so RunSummary.boss_cleared derives true (the reconciliation, [Decision] A) and (2) drives
# resolve_run_end(&"victory") to transition the run to PHASE_COMPLETED + emit run_completed(victory) + surface the outpost
# destination.
#
# THE boss_cleared RECONCILIATION ([Decision] A, RECOMMENDED): the live 9.4 victory chain (CompleteRunCommand.
# _resolve_completed) drives PHASE_COMPLETED WITHOUT clearing the boss route node (no REVEAL_CLEARED, no cleared_node_ids
# append) — so RunSummary.boss_cleared (which derives from a cleared TYPE_BOSS node) would read FALSE after a live victory.
# This method reconciles it by mirroring the NodeResolvePlaceholderCommand._resolve_boss boss-clear discipline EXACTLY
# (node.reveal_state = REVEAL_CLEARED + an IDEMPOTENT cleared_node_ids append, guarded on existing membership so the
# RouteState.validate() duplicate_cleared_node guard stays green), MUTATE-BEFORE-the-infallible-resolve_run_end (the 4.4
# ordering). A defeated boss IS a cleared boss node — this keeps the route state HONEST and run.validate() green, WITHOUT
# changing CompleteRunCommand (the boss-clear is a boss-specific caller step the placeholder command already owns; the
# generic completion command must not clear a boss node it does not know about). It does NOT touch the boss AI / adapter /
# telegraph / phase / defeat contracts (9.1-9.4 are consumed, not changed).
#
# Fail-closed: no_active_run (orchestrator unseated); no_boss_node (the run has no terminal boss route node — a
# structurally-wrong run, never true for a real full run); the resolve_run_end error VERBATIM (wrong phase / already
# terminal / unknown outcome). Draws ZERO RNG (the clear is a state mutation; resolve_run_end is deterministic).
func resolve_boss_victory() -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})

	# Find the terminal boss route node (the node the victory clears).
	var boss_node: RouteNode = _boss_route_node()
	if boss_node == null:
		return ActionResult.error(&"no_boss_node", {"command": "run_orchestrator"})

	# Reconcile boss_cleared: mark the boss REVEAL_CLEARED + idempotently append it to cleared_node_ids (the
	# NodeResolvePlaceholderCommand._resolve_boss discipline, mirrored here). MUTATE-BEFORE-the-infallible resolve_run_end
	# (so a defeated boss IS a cleared boss node before the run transitions to COMPLETED). Idempotent (guarded on existing
	# membership — the RouteState.validate() duplicate_cleared_node guard stays green even if called twice).
	boss_node.reveal_state = RouteNode.REVEAL_CLEARED
	if not run.route.cleared_node_ids.has(boss_node.id):
		var cleared: Array[String] = run.route.cleared_node_ids.duplicate()
		cleared.append(boss_node.id)
		run.route.cleared_node_ids = cleared

	# Drive the generic run-END victory resolution (transition to COMPLETED + run_completed(victory) + outpost). Surfaces
	# the command error VERBATIM (a wrong-phase / already-terminal reject leaves the boss-clear applied but the run
	# un-completed — the caller sees the error; the clear is idempotent so a retry is safe).
	return resolve_run_end(DomainEvent.RUN_COMPLETED_OUTCOME_VICTORY)


# The terminal boss route node on the seated run (the TYPE_BOSS node), or null if the run has none (a structurally-wrong
# run). A pure read.
func _boss_route_node() -> RouteNode:
	if run == null or run.route == null:
		return null
	for node: RouteNode in run.route.nodes():
		if node.type == RouteNode.TYPE_BOSS:
			return node
	return null


func run_started_event() -> DomainEvent:
	return _run_started_event


func run_completed_event() -> DomainEvent:
	return _run_completed_event


func run_completed_outcome() -> String:
	return _run_completed_outcome


# Story 8.1: the run-FAILED event + cause + the run-end next-destination flow signal surfaced by resolve_run_end.
func run_failed_event() -> DomainEvent:
	return _run_failed_event


func run_failed_cause() -> String:
	return _run_failed_cause


func run_end_destination() -> String:
	return _run_end_destination


func last_route_position_snapshot() -> RunSnapshot:
	return _last_route_position_snapshot


# Story 9.1: the boss-ENCOUNTER-SETUP surface (set by _resolve_boss). The boss-entered event, the live boss
# encounter request, the deterministic arena payload, and whether a boss encounter is currently set up (the run
# parked in NODE_RESOLUTION on the boss awaiting the fight). The later live boss loop (9.3/9.4) reads these to
# run the real fight + victory.
func boss_encounter_started_event() -> DomainEvent:
	return _boss_encounter_started_event


func boss_encounter_request():
	return _boss_encounter_request


func boss_arena_payload() -> Dictionary:
	return _boss_arena_payload


func boss_encounter_pending() -> bool:
	return _boss_encounter_pending


# ---- Story 11.2: the LIVE run flow (additive, opt-in — the DEFAULT methods above are UNCHANGED) --------------------

# Resolve the parked node LIVE (Story 11.2, AC1/AC2), mirroring resolve_current_node's guards + dispatch but routing a
# combat/elite node through the LIVE combat driver (resolve_combat_node_live) instead of the v0 auto-resolve. A boss node
# still SETS UP the encounter (_resolve_boss — the fight is auto-played separately via auto_play_boss_fight); a non-combat
# node still resolves through the placeholder round-trip (no live tactical play). `hero_hp` / `hero_weapon_id` are the
# driver-supplied hero loadout threaded to the live combat driver (the class-kit -> combat wiring is a later story). The
# LIVE hero-death SOURCE lives inside resolve_combat_node_live (a live DEFEAT auto-fires resolve_run_end).
func resolve_current_node_live(hero_hp: int = LiveCombatResolver.DEFAULT_HERO_HP, hero_weapon_id: StringName = LiveCombatResolver.DEFAULT_HERO_WEAPON) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})
	if run.is_terminal():
		return ActionResult.error(&"run_already_terminal", {"phase": String(run.phase)})
	var current: RouteNode = run.route.node_by_id(run.route.current_node_id)
	if current == null:
		return ActionResult.error(&"no_current_node", {"command": "run_orchestrator"})

	# Already-cleared no-op guard (mirrors resolve_current_node): a parked-on-a-cleared-node position advances forward
	# rather than re-resolving.
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
		return resolve_combat_node_live(current, hero_hp, hero_weapon_id)
	return _resolve_non_combat_placeholder(current)


# Resolve a combat/elite node from REAL tactical play (Story 11.2, AC1/AC2). The LIVE counterpart of _resolve_combat: it
# ENTERS the node (NodeEnterCommand) + GENERATES the level (LevelGenerator.generate) EXACTLY as the v0 path does, then
# instead of auto-resolving on a successful generation it DRIVES a live fight on the generated board (LiveCombatResolver
# — the generalized Epic-1 micro-combat loop) to a terminal CombatOutcomeState:
#   - LIVE VICTORY: the node is CLEARED + EXITED (NodeExitCommand) exactly as the v0 path does, so the run advances
#     forward. The node is decided by the BOARD OUTCOME (STATE_VICTORY), not by "the level generated".
#   - LIVE DEFEAT: the LIVE hero-death SOURCE (AC2) auto-fires the run-end resolution (resolve_run_end(&"hero_death") ->
#     CompleteRunCommand -> PHASE_FAILED + run_failed cause hero_death + next_destination == outpost). A dead hero ENDS
#     the run — the node is NOT exited/cleared (death is a terminal resolution, not a forward node clear). The auto-fire
#     runs BEHIND the CompleteRunCommand run_already_terminal guard (a re-detection never double-fires — AC4 idempotency).
# The live loop draws gameplay RNG ONLY through the run-level `streams` (the `combat` stream, via AttackCommand's existing
# draws); the default sword hero draws ZERO combat RNG. This is ADDITIVE: _resolve_combat (the v0 auto-resolve) is
# UNCHANGED + still the default path, so the non-live route-position determinism is untouched.
func resolve_combat_node_live(node: RouteNode, hero_hp: int = LiveCombatResolver.DEFAULT_HERO_HP, hero_weapon_id: StringName = LiveCombatResolver.DEFAULT_HERO_WEAPON) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})

	var enter: ActionResult = NodeEnterCommand.new(_next_sequence_id).execute(run)
	if enter.is_error():
		return enter
	_advance_sequence_past(enter)

	var request = enter.metadata.get("level_request")
	var generation: GenerationResult = LevelGenerator.generate(request, _recipe_repository, _enemy_repository)
	if generation.is_error():
		return ActionResult.error(&"level_generation_failed", {
			"command": "run_orchestrator",
			"node_id": node.id,
			"node_type": String(node.type),
			"inner_failed_phase": String(generation.failed_phase),
			"inner_error_code": String(generation.error_code),
			"inner_reason": String(generation.reason)
		})

	# Drive the LIVE fight on the generated board (restore board + place the hero at the entrance + scripted-hero loop +
	# enemy turns -> a terminal CombatOutcomeState). The run-level `streams` is the ONLY RNG source (the `combat` stream).
	var combat: ActionResult = LiveCombatResolver.new(_enemy_repository).resolve(
		generation.payload.get("board", {}),
		generation.payload.get("entrance", {}),
		streams,
		hero_hp,
		hero_weapon_id
	)
	if combat.is_error():
		# A live fight that could not resolve (a stalled board within the driver's bound) is a hard run-progression error:
		# surface it structurally + STOP (no partial progression — the node is neither cleared nor failed).
		return ActionResult.error(&"live_combat_failed", {
			"command": "run_orchestrator",
			"node_id": node.id,
			"node_type": String(node.type),
			"inner_error_code": String(combat.error_code),
			"level_seed": String(generation.payload.get("level_seed", ""))
		})

	var is_victory: bool = bool(combat.metadata.get("is_victory", false))
	if not is_victory:
		# LIVE DEFEAT -> the live hero-death SOURCE (AC2): auto-fire the run-end resolution. hero_death is the general
		# level/encounter death cause (already in RUN_FAILED_CAUSES). Do NOT exit the node (a dead hero ends the run).
		var death: ActionResult = resolve_run_end(DomainEvent.RUN_FAILED_CAUSES[0])  # &"hero_death"
		if death.is_error():
			return death
		return ActionResult.ok(death.events, {
			"node_id": node.id,
			"node_type": String(node.type),
			"resolution": "live_combat_defeat",
			"outcome": String(combat.metadata.get("outcome", "")),
			"rounds": int(combat.metadata.get("rounds", 0)),
			"level_seed": String(generation.payload.get("level_seed", "")),
			"run_failed": true,
			"cause": run_failed_cause(),
			"next_destination": run_end_destination(),
			"run_completed": false
		})

	# LIVE VICTORY -> clear + exit the node (the v0 forward-advance), so the run continues. The board outcome decided it.
	var exit: ActionResult = NodeExitCommand.new(_next_sequence_id).execute(run)
	if exit.is_error():
		return exit
	_advance_sequence_past(exit)

	return ActionResult.ok([], {
		"node_id": node.id,
		"node_type": String(node.type),
		"resolution": "live_combat_victory",
		"outcome": String(combat.metadata.get("outcome", "")),
		"rounds": int(combat.metadata.get("rounds", 0)),
		"level_seed": String(generation.payload.get("level_seed", "")),
		"level_recipe_id": String(generation.payload.get("recipe_id", "")),
		"run_completed": false
	})


# Drive the run start-to-end through the LIVE flow (Story 11.2 — the opt-in live counterpart of run_to_completion). Loops
# resolve_current_node_live -> (if not terminal AND not the boss terminus) advance-to-first-eligible, until the run is
# terminal (a live DEFEAT ends it) OR it parks at the boss-setup terminus (the boss fight is auto-played separately via
# auto_play_boss_fight / auto_play_full_run). Surfaces the FIRST error verbatim + STOPS. The DEFAULT run_to_completion is
# UNCHANGED; this is a separate driver so the non-live fingerprints + the interrupted==uninterrupted route-position
# determinism hold. `hero_hp` / `hero_weapon_id` thread the live hero loadout.
func run_to_completion_live(hero_hp: int = LiveCombatResolver.DEFAULT_HERO_HP, hero_weapon_id: StringName = LiveCombatResolver.DEFAULT_HERO_WEAPON) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})

	var max_steps: int = 256
	var steps: int = 0
	while not run.is_terminal() and steps < max_steps:
		var resolved: ActionResult = resolve_current_node_live(hero_hp, hero_weapon_id)
		if resolved.is_error():
			return resolved
		if run.is_terminal():
			break
		if _boss_encounter_pending:
			break
		var advance: ActionResult = advance_to_first_eligible()
		if advance.is_error():
			return advance
		steps += 1

	if _boss_encounter_pending and not run.is_terminal():
		return ActionResult.ok([], {
			"run": run,
			"outcome": "",
			"resolution": "boss_encounter_started",
			"boss_encounter_pending": true,
			"cleared_node_count": run.route.cleared_node_ids.size()
		})

	if not run.is_terminal():
		return ActionResult.error(&"run_did_not_complete", {"command": "run_orchestrator", "steps": steps})

	# Terminal via the live flow: a live hero DEATH (PHASE_FAILED) is the expected non-boss live terminus (a run the hero
	# lost on the board). Surface the run-end outcome/cause for the caller.
	return ActionResult.ok([], {
		"run": run,
		"outcome": _run_completed_outcome,
		"cause": _run_failed_cause,
		"phase": String(run.phase),
		"cleared_node_count": run.route.cleared_node_ids.size()
	})


# Auto-play the Larval Avatar boss fight to VICTORY from the boss-setup terminus (Story 11.2, AC3 — the resolve_boss_victory
# PRODUCTION call site + the both-sides-simulated boss auto-play). PRECONDITION: the run is parked at the boss terminus
# (boss_encounter_pending() — reached via run_to_completion / run_to_completion_live). It:
#   (1) restores the boss arena BoardState from boss_arena_payload() + places the live boss (larval_avatar, BossRepository
#       max_hp) at the arena slot + the hero at the entrance (the 9.1 arena reserves the slot; the run flow places both),
#   (2) AUTO-PLAYS the fight — BOTH sides simulated: the boss via BossTurnResolver.resolve_boss_turn, the hero via a
#       deterministic scripted driver (the same focus-fire pattern the level combat uses, generalized to one boss target)
#       — until the boss reaches 0 HP OR the hero dies,
#   (3) threads the SHARED sequence-id cursor through resolve_phase_transitions -> detect_boss_defeat -> the run-end append
#       (the seam contract — a caller-reserved base above the run's route-event ids), and
#   (4) on boss DEFEAT drives resolve_boss_victory() (clears the boss node + resolve_run_end(victory) -> PHASE_COMPLETED +
#       run_completed(victory) + outpost); on a HERO DEATH during the boss fight auto-fires resolve_run_end(&"boss_defeat")
#       (the boss-context death cause, already in RUN_FAILED_CAUSES) -> PHASE_FAILED.
# ZERO-new-RNG (the boss AI + phase resolver + defeat are ZERO-RNG; a hero attack proc would draw only the `combat`
# stream — the default sword hero draws none). Returns ok with the interleaved fight+run-end events + the outcome.
func auto_play_boss_fight(hero_hp: int = LiveCombatResolver.DEFAULT_HERO_HP, hero_weapon_id: StringName = LiveCombatResolver.DEFAULT_HERO_WEAPON) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})
	if not _boss_encounter_pending:
		return ActionResult.error(&"no_boss_encounter_pending", {"command": "run_orchestrator", "phase": String(run.phase)})

	# Restore the arena board + place the boss + hero.
	var payload: Dictionary = _boss_arena_payload
	var snapshot: Dictionary = payload.get("board_snapshot", {})
	if snapshot.is_empty():
		return ActionResult.error(&"invalid_boss_arena_payload", {"command": "run_orchestrator", "reason": "no_board_snapshot"})
	var board_result: ActionResult = BoardState.try_from_snapshot(snapshot)
	if board_result.is_error():
		return ActionResult.error(&"invalid_boss_arena_payload", {"command": "run_orchestrator", "inner_error_code": String(board_result.error_code)})
	var board: BoardState = board_result.metadata.get("board") as BoardState

	var definition: BossDefinition = BossRepository.create_baseline_repository().get_boss(BOSS_ID)
	if definition == null:
		return ActionResult.error(&"unknown_boss", {"command": "run_orchestrator", "boss_id": String(BOSS_ID)})
	# The arena is the source of truth for BOTH placement cells — a missing boss_slot/entrance key is a malformed payload,
	# NOT a cue to place onto a magic coordinate. Fail closed (mirrors the board_snapshot/board_result checks above) so a
	# future arena-shape change that dropped/renamed either key fails loud on the missing key rather than a silent substitution.
	var slot: Dictionary = payload.get("boss_slot", {})
	if not (slot.has("x") and slot.has("y")):
		return ActionResult.error(&"invalid_boss_arena_payload", {"command": "run_orchestrator", "reason": "no_boss_slot"})
	var slot_cell: Vector2i = Vector2i(int(slot.get("x")), int(slot.get("y")))
	var entrance: Dictionary = payload.get("entrance", {})
	if not (entrance.has("x") and entrance.has("y")):
		return ActionResult.error(&"invalid_boss_arena_payload", {"command": "run_orchestrator", "reason": "no_entrance"})
	var entrance_cell: Vector2i = Vector2i(int(entrance.get("x")), int(entrance.get("y")))
	var resolved_hp: int = maxi(1, hero_hp)
	# Check each placement result and surface a structured error (mirroring LiveCombatResolver.resolve's hero_placement_failed)
	# so a placement failure (e.g. slot/entrance collision, wall, or out-of-bounds) reports its precise cause rather than
	# failing generically downstream via the round loop's null-entity break.
	var boss: TacticalEntityState = TacticalEntityState.new(BOSS_ID, TacticalEntityState.EntityType.ENEMY, &"boss", slot_cell, definition.max_hp, definition.max_hp, true, BOSS_ID)
	var boss_place: ActionResult = board.place_entity_for_setup(boss)
	if boss_place.is_error():
		return ActionResult.error(&"invalid_boss_arena_payload", {"command": "run_orchestrator", "reason": "boss_placement_failed", "inner_error_code": String(boss_place.error_code)})
	var hero: TacticalEntityState = TacticalEntityState.new(HERO_ID, TacticalEntityState.EntityType.PLAYER, &"player", entrance_cell, resolved_hp, resolved_hp, true, HERO_ID)
	var hero_place: ActionResult = board.place_entity_for_setup(hero)
	if hero_place.is_error():
		return ActionResult.error(&"invalid_boss_arena_payload", {"command": "run_orchestrator", "reason": "hero_placement_failed", "inner_error_code": String(hero_place.error_code)})
	for board_cell in board.cells():
		board_cell.visible = true
		board_cell.explored = true

	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, HERO_ID)
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var resolver: BossTurnResolver = BossTurnResolver.new(definition, BOSS_ID, HERO_ID)

	# AUTO-PLAY the fight (both sides). A bounded round cap guards against a non-progressing board; the hero out-damages
	# the boss deterministically. `run_events` is the run-level SYSTEM stream (boss_phase_changed + boss_defeated, from the
	# reserved high base); `board_events` is the tactical board log (hero/boss actions, the board's own id space).
	var play: ActionResult = _auto_play_boss_rounds(board, context, resolver, definition, hero_weapon_id)
	if play.is_error():
		return play
	var run_events: Array = play.metadata.get("run_events", [])
	var board_events: Array = play.metadata.get("board_events", [])
	var hero_dead: bool = bool(play.metadata.get("hero_dead", false))

	if hero_dead:
		# A live hero death DURING the boss fight -> the live hero-death SOURCE with the boss-context cause (boss_defeat).
		# The run_failed event uses the orchestrator's OWN (lower) monotonic cursor — a separate id space from the reserved
		# fight base, so it never collides with the interleaved boss SYSTEM ids.
		var death: ActionResult = resolve_run_end(&"boss_defeat")
		if death.is_error():
			return death
		return ActionResult.ok([], {
			"run": run,
			"outcome": "",
			"cause": run_failed_cause(),
			"resolution": "boss_fight_hero_death",
			"next_destination": run_end_destination(),
			"events": run_events + death.events,
			"board_events": board_events,
			"phase": String(run.phase)
		})

	# Boss DEFEATED -> the boss-VICTORY production call site (AC3). resolve_boss_victory clears the boss node + drives
	# resolve_run_end(victory) -> PHASE_COMPLETED + run_completed(victory) + outpost. The run_completed event uses the
	# orchestrator's OWN (lower) monotonic cursor — distinct from the reserved fight base, so no id collides.
	var victory: ActionResult = resolve_boss_victory()
	if victory.is_error():
		return victory
	return ActionResult.ok([], {
		"run": run,
		"outcome": _run_completed_outcome,
		"resolution": "boss_victory",
		"next_destination": run_end_destination(),
		"events": run_events + victory.events,
		"board_events": board_events,
		"phase": String(run.phase)
	})


# Auto-play a FULL run to a run-END through the shell (Story 11.2, AC3 — "run_to_completion can auto-play the full boss
# fight headlessly"). Drives run_to_completion() to the boss-setup terminus (the DEFAULT driver — the pre-boss combat is
# v0 auto-resolved, keeping the fingerprints byte-identical), then auto-plays the boss fight (auto_play_boss_fight) to the
# boss VICTORY (or a hero death during the boss fight). This is the OPT-IN full-run auto-play the seed-batch / simulation
# tests call; the DEFAULT run_to_completion (which STOPS at the boss terminus) is UNCHANGED. Returns the boss auto-play
# result (the terminal run + the interleaved fight+run-end events + the outcome).
func auto_play_full_run(hero_hp: int = LiveCombatResolver.DEFAULT_HERO_HP, hero_weapon_id: StringName = LiveCombatResolver.DEFAULT_HERO_WEAPON) -> ActionResult:
	if run == null:
		return ActionResult.error(&"no_active_run", {"command": "run_orchestrator"})

	var completion: ActionResult = run_to_completion()
	if completion.is_error():
		return completion
	# If the run already ended (no boss node — a structurally-degenerate run), surface the completion verbatim.
	if run.is_terminal():
		return completion
	if not _boss_encounter_pending:
		return ActionResult.error(&"run_did_not_reach_boss_terminus", {"command": "run_orchestrator", "phase": String(run.phase)})
	return auto_play_boss_fight(hero_hp, hero_weapon_id)


# Auto-play the boss fight ROUNDS (both sides): each round the hero acts (focus-fire the boss — attack when in range/
# aligned, else approach), then (if the boss lives) the boss takes its turn (BossTurnResolver.resolve_boss_turn), then the
# phase transitions are re-resolved from the boss's post-hit HP (the seam-contract shared cursor). Loops until the boss is
# dead OR the hero is dead OR the round cap is hit. On the boss's death it emits the phase chain (through the defeat HP) +
# the boss_defeated event (threading the shared cursor). Returns TWO event streams (kept distinct because they live in
# DIFFERENT id spaces): `run_events` — the run-level interleaved SYSTEM stream (boss_phase_changed + boss_defeated), which
# the caller extends with the run_completed/run_failed run-END event, ALL sequenced from the reserved high base
# (BOSS_FIGHT_SEQUENCE_BASE) so they are mutually UNIQUE (the seam contract); and `board_events` — the tactical board log
# (the hero/boss action events, which carry the ARENA board's OWN sequence ids, a separate id space). Also returns whether
# the hero died. The hero driver reuses the LiveCombatResolver's scripted-hit discipline against the single boss target.
func _auto_play_boss_rounds(board: BoardState, context: TacticalActionContext, resolver: BossTurnResolver, definition: BossDefinition, hero_weapon_id: StringName) -> ActionResult:
	var run_events: Array = []
	var board_events: Array = []
	# ONE LiveCombatResolver for BOTH the weapon lookup AND the scripted-hero step loop (both are pure lookups on the same
	# driver — a second throwaway instance to resolve the weapon would re-build a baseline repository for nothing).
	var live_driver: LiveCombatResolver = LiveCombatResolver.new(_enemy_repository)
	var weapon = live_driver.hero_weapon(hero_weapon_id)
	if weapon == null:
		return ActionResult.error(&"unknown_hero_weapon", {"command": "run_orchestrator", "weapon_id": String(hero_weapon_id)})
	var fight_base: int = BOSS_FIGHT_SEQUENCE_BASE
	var max_rounds: int = 128
	var rounds: int = 0
	while rounds < max_rounds:
		rounds += 1
		var boss: TacticalEntityState = board.get_entity(BOSS_ID)
		var hero: TacticalEntityState = board.get_entity(HERO_ID)
		if boss == null or boss.is_dead():
			break
		if hero == null or hero.is_dead():
			return ActionResult.ok([], {"run_events": run_events, "board_events": board_events, "hero_dead": true, "rounds": rounds})

		# Hero turn: a scripted hit against the boss (attack when the AttackCommand accepts it, else approach). Reuses the
		# LiveCombatResolver's public single-target step so the hero AI is one implementation. Its events are board-log
		# events (the board's own id space) — collected in board_events, NOT the run-level uniqueness stream.
		var phase_before_hit: int = resolver.active_phase_index_for_hp(boss.current_hp)
		var hero_step: ActionResult = live_driver.drive_hero_step_against(context, weapon, BOSS_ID)
		if hero_step.is_error():
			return hero_step
		board_events.append_array(hero_step.events)

		# Re-resolve the boss phase from its post-hit HP (the live phase seam) — SYSTEM events threaded from the reserved
		# shared cursor (the seam contract).
		boss = board.get_entity(BOSS_ID)
		var phase_result: ActionResult = resolver.resolve_phase_transitions(context, phase_before_hit, fight_base)
		run_events.append_array(phase_result.events)
		fight_base = int(phase_result.metadata.get("next_sequence_id_after", fight_base))
		if boss.is_dead():
			break

		# Boss turn (both sides simulated) — the boss acts if it still lives. Board-log events (board id space).
		var boss_turn: ActionResult = resolver.resolve_boss_turn(context)
		if boss_turn.is_error():
			return boss_turn
		board_events.append_array(boss_turn.events)

	var final_boss: TacticalEntityState = board.get_entity(BOSS_ID)
	if final_boss == null or not final_boss.is_dead():
		# The hero could not fell the boss within the bound (a stalled fight) — fail loud (never a fabricated victory).
		var final_hero: TacticalEntityState = board.get_entity(HERO_ID)
		if final_hero != null and final_hero.is_dead():
			return ActionResult.ok([], {"run_events": run_events, "board_events": board_events, "hero_dead": true, "rounds": rounds})
		return ActionResult.error(&"boss_fight_did_not_resolve", {"command": "run_orchestrator", "rounds": rounds})

	# Boss defeated: emit the boss_defeated SYSTEM event (threading the shared cursor — the seam contract).
	var defeat_result: ActionResult = resolver.detect_boss_defeat(context, fight_base)
	run_events.append_array(defeat_result.events)
	fight_base = int(defeat_result.metadata.get("next_sequence_id_after", fight_base))
	return ActionResult.ok([], {"run_events": run_events, "board_events": board_events, "hero_dead": false, "rounds": rounds})


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


# Boss (Story 9.1): SET UP the Larval Avatar encounter via BossNodeEnterCommand — build the boss encounter
# REQUEST + the deterministic arena, transition ACTIVE_ROUTE -> NODE_RESOLUTION, emit boss_encounter_started —
# and STOP. The run stays in NODE_RESOLUTION awaiting the real boss fight + victory (Story 9.4, which reuses the
# run_completed boundary UNCHANGED). It does NOT auto-complete the run on boss arrival anymore, does NOT clear the
# boss node (9.4's victory does), and does NOT run a live turn loop. Mirrors _resolve_combat's enter->generate
# shape (enter the boss -> build the arena request), minus the exit/advance (a terminal boss has no return-to-route)
# and minus the auto-resolve completion. Surfaces the boss request + arena payload + setup diagnostics for the
# caller (the later live boss loop). This is the SETUP half of Epic 9's "reach and defeat the Larval Avatar".
func _resolve_boss(node: RouteNode) -> ActionResult:
	var setup: ActionResult = BossNodeEnterCommand.new(_next_sequence_id).execute(run)
	if setup.is_error():
		# A boss node whose encounter cannot be set up is a hard run-progression error: surface it structurally
		# and STOP — do NOT advance/complete past an un-set-up boss (no partial progression, no broken boss state;
		# the command already guaranteed a byte-identical no-mutation run on its own reject).
		return setup
	_advance_sequence_past(setup)

	# Capture the boss-encounter-setup surface for the caller (the live boss loop 9.3/9.4). The run is now in
	# NODE_RESOLUTION (NOT terminal) — the boss fight/victory has not happened yet.
	if not setup.events.is_empty():
		_boss_encounter_started_event = setup.events[0]
	_boss_encounter_request = setup.metadata.get("boss_encounter_request")
	_boss_arena_payload = setup.metadata.get("arena_payload", {})
	_boss_encounter_pending = true

	return ActionResult.ok([], {
		"node_id": node.id,
		"node_type": String(node.type),
		"resolution": "boss_encounter_started",
		"run_completed": false,
		"boss_encounter_pending": true,
		"boss_entity_id": String(setup.metadata.get("boss_entity_id", "")),
		"arena_payload": _boss_arena_payload
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
