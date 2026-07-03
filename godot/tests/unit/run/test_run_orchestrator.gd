extends "res://tests/unit/test_case.gd"

# Story 4.6 Task 5.2 / 5.3 — RunOrchestrator: the multi-seed start-to-COMPLETED orchestrated run (the
# load-bearing AC1/AC2/AC3 proof). Unlike the 4.5 type-dispatch walk (test_node_type_resolution_walk.gd),
# which drives the commands by hand and SKIPS level generation, the orchestrator actually RUNS
# LevelGenerator.generate(...) for combat/elite nodes (the FIRST 4.x success-path level GenerationResult
# consumer) and threads ONE RunState + one run-level RngStreamSet + a monotonic sequence_id start-to-end.
#
# Pins, on 4.2-generated routes across a VARIETY of seeds (Story 9.1: the boss now SETS UP the Larval Avatar
# encounter instead of auto-completing — the run STOPS at the boss-encounter setup in NODE_RESOLUTION awaiting
# the real fight/victory, which is 9.3/9.4):
#   - the run starts in ACTIVE_ROUTE on the depth-0 combat start node, run.validate() green;
#   - dispatch-by-type drives the run to the boss-encounter SETUP with EXACTLY one run_started (start) + EXACTLY
#     one boss_encounter_started (the 9.1 boss SETUP; NO run_completed — the boss no longer auto-completes);
#   - the boss dispatch leaves the run in NODE_RESOLUTION (non-terminal), the boss NOT cleared (9.4 clears it on
#     victory), and surfaces the deterministic arena payload with a placeholder boss slot;
#   - combat/elite nodes GENERATE a playable level (LevelGenerator.generate success, a non-empty
#     payload.level_seed read on the SUCCESS path — never result.seed);
#   - NO soft-lock (a non-boss node always advances), cleared_node_ids never duplicates, run.validate() green
#     at every boundary;
#   - across the seed set BOTH paths are exercised: >= 1 combat node AND >= 1 non-combat placeholder node;
#   - every emitted run-level event has a UNIQUE, monotonically-increasing sequence id (the orchestrator's
#     run-level log seam);
#   - determinism: the SAME (root_seed, first-eligible strategy) -> the SAME final run.to_dictionary() + the
#     SAME ordered run-level event-id/type sequence + the SAME per-combat-node level_seed.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RouteGenerator = preload("res://scripts/generation/route/route_generator.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The 4.4/4.5 walk seeds + a few more so a VARIETY of node types is hit across the set.
const RUN_SEEDS: Array[int] = [1, 7, 42, 2026, 13, 99, 314, 777]

func run() -> Dictionary:
	_orchestrated_run_reaches_boss_setup_for_every_seed()
	_orchestrated_run_is_fully_deterministic()
	# Story 5.2 — the confirm-path seam: RunOrchestrator.start threads the chosen class into RunStartCommand.
	_start_with_selectable_class_records_it_on_the_seated_run()
	_start_with_locked_class_surfaces_command_error_and_seats_no_run()
	# Story 8.1 — the run-END dispatch hook: resolve_run_end drives death/completion + surfaces the flow signal.
	_resolve_run_end_death_surfaces_run_failed_and_destination()
	_resolve_run_end_completion_surfaces_run_completed_and_destination()
	_resolve_run_end_on_terminal_run_is_blocked()
	_resolve_run_end_with_no_active_run_errors()
	return result()


# ---- Story 8.1: the run-END dispatch hook (resolve_run_end) ---------------------------------------

# resolve_run_end with a death cause drives the seated ACTIVE_ROUTE run to FAILED, emits run_failed, and surfaces the
# cause + the outpost next-destination flow signal (AC1). The orchestrator is started (a fresh run is in ACTIVE_ROUTE).
func _resolve_run_end_death_surfaces_run_failed_and_destination() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(42, false).succeeded, "Setup: start should succeed.")
	assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "Setup: a fresh run is in ACTIVE_ROUTE.")

	var resolved: ActionResult = orchestrator.resolve_run_end(&"hero_death")
	assert_true(resolved.succeeded, "resolve_run_end with a death cause should succeed: %s" % resolved.metadata)
	assert_equal(orchestrator.run.phase, RunState.PHASE_FAILED, "A death resolution should drive the run to FAILED.")
	assert_true(orchestrator.run.is_terminal(), "A death-resolved run should be terminal.")
	# The surfaced run-end fields.
	assert_true(orchestrator.run_failed_event() != null, "The orchestrator should surface the run_failed event.")
	assert_equal(orchestrator.run_failed_event().event_type, DomainEvent.Type.RUN_FAILED, "The surfaced event should be run_failed.")
	assert_equal(orchestrator.run_failed_cause(), "hero_death", "The orchestrator should surface the death cause.")
	assert_equal(orchestrator.run_end_destination(), "outpost", "The orchestrator should surface the outpost next-destination (AC1).")


# resolve_run_end with the completion marker drives the seated ACTIVE_ROUTE run to COMPLETED (the two-step), emits
# run_completed with the broadened `completed` outcome, and surfaces the outpost destination (AC2).
func _resolve_run_end_completion_surfaces_run_completed_and_destination() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(7, false).succeeded, "Setup: start should succeed.")

	var resolved: ActionResult = orchestrator.resolve_run_end(&"completed")
	assert_true(resolved.succeeded, "resolve_run_end with the completion marker should succeed: %s" % resolved.metadata)
	assert_equal(orchestrator.run.phase, RunState.PHASE_COMPLETED, "A completion resolution should drive the run to COMPLETED.")
	assert_true(orchestrator.run_completed_event() != null, "The orchestrator should surface the run_completed event.")
	assert_equal(orchestrator.run_completed_outcome(), "completed", "The orchestrator should surface the broadened `completed` outcome (NOT boss_placeholder).")
	assert_equal(orchestrator.run_end_destination(), "outpost", "The orchestrator should surface the outpost next-destination (AC2).")


# resolve_run_end on an already-terminal run surfaces the command's stable run_already_terminal error (AC3) — the
# orchestrator captures nothing new (no second event, no mutation).
func _resolve_run_end_on_terminal_run_is_blocked() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(13, false).succeeded, "Setup: start should succeed.")
	assert_true(orchestrator.resolve_run_end(&"completed").succeeded, "The first completion should succeed.")
	var before: Dictionary = orchestrator.run.to_dictionary()

	var second: ActionResult = orchestrator.resolve_run_end(&"hero_death")
	assert_true(second.is_error(), "A second resolve_run_end on a terminal run should be rejected.")
	assert_equal(second.error_code, &"run_already_terminal", "A re-resolution should surface the stable run_already_terminal code.")
	assert_equal(orchestrator.run.to_dictionary(), before, "A blocked re-resolution must leave the run byte-identical (no double-grant).")


# resolve_run_end on an unseated orchestrator (no run started) errors with no_active_run.
func _resolve_run_end_with_no_active_run_errors() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var resolved: ActionResult = orchestrator.resolve_run_end(&"completed")
	assert_true(resolved.is_error(), "resolve_run_end with no active run should be rejected.")
	assert_equal(resolved.error_code, &"no_active_run", "An unseated resolve_run_end should use no_active_run.")


# Story 5.2 (confirm-path option b — direct orchestrator entry): RunOrchestrator.start(seed, is_manual,
# class_id) threads the chosen class into RunStartCommand, so the seated run RECORDS the selected class and is
# otherwise an ordinary started run (ACTIVE_ROUTE on the depth-0 combat node, validate() green).
func _start_with_selectable_class_records_it_on_the_seated_run() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var start: ActionResult = orchestrator.start(42, false, &"warrior")
	assert_true(start.succeeded, "Starting a run with a selectable class should succeed: %s" % start.metadata)
	var run: RunState = orchestrator.run
	assert_true(run != null, "A class run start should seat the live RunState on the orchestrator.")
	assert_equal(run.selected_class_id, &"warrior", "The seated run must RECORD the chosen class id.")
	assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "A class run start should be in ACTIVE_ROUTE.")
	assert_true(run.validate().succeeded, "A class run start should validate.")
	# The orchestrator drives the class run start-to-end exactly like a seed-only run (the class records only
	# a field; it does not alter dispatch). Story 9.1: the drive STOPS at the boss-encounter SETUP (the boss no
	# longer auto-completes — the fight/victory is 9.3/9.4), so the run parks non-terminal in NODE_RESOLUTION.
	var completion: ActionResult = orchestrator.run_to_completion()
	assert_true(completion.succeeded, "A class run should drive to the boss-encounter setup like a seed-only run: %s" % completion.metadata)
	assert_equal(orchestrator.run.phase, RunState.PHASE_NODE_RESOLUTION, "A class run should reach the boss-encounter setup (NODE_RESOLUTION), not a terminal phase (9.1).")
	assert_true(orchestrator.boss_encounter_pending(), "A class run should have a pending boss encounter set up.")
	assert_equal(orchestrator.run.selected_class_id, &"warrior", "The class id must persist on the run through the boss setup.")


# Story 5.2 AC2 (confirm-path option b): RunOrchestrator.start with a LOCKED class surfaces the command's
# class_not_selectable error VERBATIM and seats NO run (the orchestrator stays unseeded — no run can start
# with the locked class even through the orchestrator entry).
func _start_with_locked_class_surfaces_command_error_and_seats_no_run() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var start: ActionResult = orchestrator.start(42, false, &"necromancer")
	assert_true(start.is_error(), "AC2: starting through the orchestrator with a locked class must fail.")
	assert_equal(start.error_code, &"class_not_selectable", "The orchestrator must surface the command's class_not_selectable code verbatim.")
	assert_true(orchestrator.run == null, "AC2: a rejected locked-class start must seat NO run on the orchestrator.")
	# An unknown class likewise surfaces the command's unknown_class code with no run seated.
	var unknown_orchestrator: RunOrchestrator = RunOrchestrator.new()
	var unknown_start: ActionResult = unknown_orchestrator.start(42, false, &"does_not_exist")
	assert_true(unknown_start.is_error(), "AC2: starting through the orchestrator with an unknown class must fail.")
	assert_equal(unknown_start.error_code, &"unknown_class", "The orchestrator must surface the command's unknown_class code verbatim.")
	assert_true(unknown_orchestrator.run == null, "AC2: a rejected unknown-class start must seat NO run on the orchestrator.")


# An instrumented start-to-completion drive that asserts the per-boundary invariants the production
# run_to_completion() does not (validate/phase/no-duplicate at every step), AND runs the real level
# generation for combat nodes. Returns a small report dict for the cross-seed aggregate assertions.
func _drive_and_assert(seed_value: int) -> Dictionary:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var start: ActionResult = orchestrator.start(seed_value, false)
	assert_true(start.succeeded, "Seed %d: orchestrator start should succeed: %s" % [seed_value, start.metadata])
	var run: RunState = orchestrator.run
	assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: a started run should be in ACTIVE_ROUTE." % seed_value)
	assert_true(run.validate().succeeded, "Seed %d: a started run should validate." % seed_value)
	# The start node is always the depth-0 combat node (AC1).
	var start_node: RouteNode = run.route.node_by_id(run.route.current_node_id)
	assert_equal(start_node.depth, 0, "Seed %d: the run should start on the depth-0 node." % seed_value)
	assert_equal(start_node.type, RouteNode.TYPE_COMBAT, "Seed %d: the depth-0 start node is always combat." % seed_value)

	# Exactly one run_started captured.
	var run_started: DomainEvent = orchestrator.run_started_event()
	assert_true(run_started != null, "Seed %d: the orchestrator should capture the run_started event." % seed_value)
	assert_equal(run_started.event_type, DomainEvent.Type.RUN_STARTED, "Seed %d: the captured start event should be run_started." % seed_value)

	var combat_nodes_resolved: int = 0
	var non_combat_nodes_resolved: int = 0
	var combat_level_seeds: Array[String] = []
	var emitted_sequence_ids: Array[int] = []
	var boss_setup_seen: int = 0
	var reached_boss_setup: bool = false

	# Collect the run_started's id first (it is the first event in the run-level log).
	emitted_sequence_ids.append(run_started.sequence_id)

	var max_steps: int = 256
	var steps: int = 0
	while not run.is_terminal() and steps < max_steps:
		var current: RouteNode = run.route.node_by_id(run.route.current_node_id)
		assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: should be in ACTIVE_ROUTE before resolving at step %d." % [seed_value, steps])
		var is_boss: bool = current.type == RouteNode.TYPE_BOSS
		var is_combat: bool = current.type == RouteNode.TYPE_COMBAT or current.type == RouteNode.TYPE_ELITE_COMBAT

		var resolved: ActionResult = orchestrator.resolve_current_node()
		assert_true(resolved.succeeded, "Seed %d: resolving the %s node should succeed at step %d: %s" % [seed_value, String(current.type), steps, resolved.metadata])

		if is_boss:
			# Story 9.1: the boss SETS UP the Larval Avatar encounter (BossNodeEnterCommand) — it does NOT
			# auto-complete the run anymore. The run is in NODE_RESOLUTION (NOT terminal), the boss is NOT yet
			# cleared (9.4's victory clears it), NO run_completed is emitted; instead boss_encounter_started is
			# surfaced with the arena payload. The real fight/victory is 9.3/9.4.
			assert_equal(run.phase, RunState.PHASE_NODE_RESOLUTION, "Seed %d: boss resolve should SET UP the encounter (NODE_RESOLUTION), not COMPLETED, at step %d." % [seed_value, steps])
			assert_false(run.is_terminal(), "Seed %d: the run must NOT be terminal after the boss SETUP (9.1)." % seed_value)
			assert_false(run.route.cleared_node_ids.has(current.id), "Seed %d: the boss must NOT be cleared by the 9.1 setup (9.4's victory clears it)." % seed_value)
			assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after the boss setup." % seed_value)
			assert_equal(resolved.metadata.get("resolution"), "boss_encounter_started", "Seed %d: the boss dispatch should surface the boss_encounter_started resolution." % seed_value)
			assert_true(bool(resolved.metadata.get("boss_encounter_pending", false)), "Seed %d: the boss dispatch should flag a pending boss encounter." % seed_value)
			assert_true(orchestrator.run_completed_event() == null, "Seed %d: the 9.1 boss setup must NOT surface a run_completed event." % seed_value)
			var boss_event: DomainEvent = orchestrator.boss_encounter_started_event()
			assert_true(boss_event != null, "Seed %d: the orchestrator should surface the boss_encounter_started event." % seed_value)
			assert_equal(boss_event.event_type, DomainEvent.Type.BOSS_ENCOUNTER_STARTED, "Seed %d: the surfaced boss event should be boss_encounter_started." % seed_value)
			assert_equal(boss_event.payload.get("boss_node_id"), current.id, "Seed %d: the boss event must carry the boss node id." % seed_value)
			# The arena payload is present + deterministic (a board snapshot + entrance/player_start/boss_slot).
			var arena_payload: Dictionary = orchestrator.boss_arena_payload()
			assert_false(arena_payload.is_empty(), "Seed %d: the orchestrator should surface the boss arena payload." % seed_value)
			assert_true((arena_payload.get("boss_slot") as Dictionary).get("is_placeholder", false), "Seed %d: the boss slot must be marked placeholder (9.2 fills the real definition)." % seed_value)
			boss_setup_seen += 1
			emitted_sequence_ids.append(boss_event.sequence_id)
			reached_boss_setup = true
			break

		if is_combat:
			combat_nodes_resolved += 1
			# The combat node GENERATED a playable level (read on the SUCCESS path: payload.level_seed).
			var level_seed: String = String(resolved.metadata.get("level_seed", ""))
			assert_false(level_seed.is_empty(), "Seed %d: a combat node must generate a playable level with a non-empty level_seed at step %d." % [seed_value, steps])
			combat_level_seeds.append(level_seed)
			assert_equal(resolved.metadata.get("resolution"), "combat_auto_resolved", "Seed %d: a combat node should v0-auto-resolve at step %d." % [seed_value, steps])
			assert_true(run.route.cleared_node_ids.has(current.id), "Seed %d: the combat node should be cleared after resolve at step %d." % [seed_value, steps])
		else:
			non_combat_nodes_resolved += 1
			assert_equal(resolved.metadata.get("resolution"), "placeholder_resolved", "Seed %d: a non-combat node should placeholder-resolve at step %d." % [seed_value, steps])
			assert_true(run.route.cleared_node_ids.has(current.id), "Seed %d: the placeholder node should be cleared after resolve at step %d." % [seed_value, steps])

		assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: a non-boss resolve should return to ACTIVE_ROUTE at step %d." % [seed_value, steps])
		assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after resolving at step %d." % [seed_value, steps])
		_assert_no_duplicate_cleared(run, seed_value, steps)

		# Advance to the first eligible choice (no soft-lock — a non-boss node always has one).
		var advance: ActionResult = orchestrator.advance_to_first_eligible()
		assert_true(advance.succeeded, "Seed %d: advancing to an eligible choice should succeed at step %d: %s" % [seed_value, steps, advance.metadata])
		assert_equal(run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: advance keeps the run in ACTIVE_ROUTE at step %d." % [seed_value, steps])
		assert_true(run.validate().succeeded, "Seed %d: the run must stay valid after each advance at step %d." % [seed_value, steps])
		_assert_no_duplicate_cleared(run, seed_value, steps)
		# Record the advance event's id (part of the run-level log).
		for event: DomainEvent in advance.events:
			emitted_sequence_ids.append(event.sequence_id)
		steps += 1

	assert_true(reached_boss_setup, "Seed %d: the orchestrated run should reach the boss-encounter SETUP within the guard (9.1)." % seed_value)
	assert_equal(boss_setup_seen, 1, "Seed %d: exactly one boss-encounter setup should be surfaced." % seed_value)
	# At least one combat node was resolved (the start is always combat).
	assert_true(combat_nodes_resolved >= 1, "Seed %d: at least one combat node must be resolved (the start is always combat)." % seed_value)

	# Every collected run-level event id is unique + monotonically increasing (the orchestrator's sequence
	# seam). Note: this collects run_started + advances + run_completed (the resolve-internal ids are also
	# monotonic by construction; the collected subset is sufficient to prove uniqueness/monotonicity).
	for index: int in range(1, emitted_sequence_ids.size()):
		assert_true(emitted_sequence_ids[index] > emitted_sequence_ids[index - 1], "Seed %d: run-level event sequence ids must strictly increase (id[%d]=%d <= id[%d]=%d)." % [seed_value, index, emitted_sequence_ids[index], index - 1, emitted_sequence_ids[index - 1]])

	return {
		"combat_nodes_resolved": combat_nodes_resolved,
		"non_combat_nodes_resolved": non_combat_nodes_resolved,
		"final_run_dict": run.to_dictionary(),
		"combat_level_seeds": combat_level_seeds
	}


func _orchestrated_run_reaches_boss_setup_for_every_seed() -> void:
	var total_combat: int = 0
	var total_non_combat: int = 0
	for seed_value: int in RUN_SEEDS:
		var report: Dictionary = _drive_and_assert(seed_value)
		total_combat += int(report.get("combat_nodes_resolved"))
		total_non_combat += int(report.get("non_combat_nodes_resolved"))
	# Across the seed set BOTH paths are genuinely exercised (AC1 combat + AC2 placeholder).
	assert_true(total_combat >= 1, "The orchestrated runs should resolve at least one combat node across the seed set (resolved %d)." % total_combat)
	assert_true(total_non_combat >= 1, "The orchestrated runs should resolve at least one NON-combat placeholder node across the seed set (resolved %d)." % total_non_combat)


func _orchestrated_run_is_fully_deterministic() -> void:
	# The SAME (root_seed, first-eligible strategy) -> the SAME final run.to_dictionary() + the SAME ordered
	# run-level event-id/type sequence + the SAME per-combat-node level_seed list. Run two independent
	# orchestrators on the same seed via the production run_to_completion() and the instrumented drive, and
	# cross-check.
	for seed_value: int in [42, 2026]:
		# Two independent instrumented drives must agree byte-for-byte.
		var first: Dictionary = _drive_and_assert(seed_value)
		var second: Dictionary = _drive_and_assert(seed_value)
		assert_equal(JSON.stringify(first.get("final_run_dict")), JSON.stringify(second.get("final_run_dict")), "Seed %d: the same inputs must produce a byte-identical final run.to_dictionary()." % seed_value)
		assert_equal(str(first.get("combat_level_seeds")), str(second.get("combat_level_seeds")), "Seed %d: the same inputs must produce the same per-combat-node level seeds." % seed_value)

		# The production run_to_completion() driver reaches the SAME boss-setup terminus as the instrumented drive.
		# Story 9.1: run_to_completion STOPS at the boss-encounter setup (NODE_RESOLUTION, non-terminal, a pending
		# boss encounter) rather than auto-completing — the real fight/victory is 9.3/9.4.
		var production: RunOrchestrator = RunOrchestrator.new()
		assert_true(production.start(seed_value, false).succeeded, "Seed %d: production start should succeed." % seed_value)
		var completion: ActionResult = production.run_to_completion()
		assert_true(completion.succeeded, "Seed %d: production run_to_completion should succeed: %s" % [seed_value, completion.metadata])
		assert_equal(production.run.phase, RunState.PHASE_NODE_RESOLUTION, "Seed %d: production run should reach the boss-encounter setup (NODE_RESOLUTION), not COMPLETED (9.1)." % seed_value)
		assert_true(production.boss_encounter_pending(), "Seed %d: production run should have a pending boss encounter set up." % seed_value)
		assert_equal(completion.metadata.get("resolution"), "boss_encounter_started", "Seed %d: production run_to_completion should surface the boss_encounter_started terminus." % seed_value)
		assert_equal(JSON.stringify(production.run.to_dictionary()), JSON.stringify(first.get("final_run_dict")), "Seed %d: production run_to_completion must reach the same final run state as the instrumented drive." % seed_value)


func _assert_no_duplicate_cleared(run: RunState, seed_value: int, step: int) -> void:
	var seen: Dictionary = {}
	for cleared_id: String in run.route.cleared_node_ids:
		assert_false(seen.has(cleared_id), "Seed %d: cleared_node_ids must never duplicate (%s at step %d)." % [seed_value, cleared_id, step])
		seen[cleared_id] = true
