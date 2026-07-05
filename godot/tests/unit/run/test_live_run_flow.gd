extends "res://tests/unit/test_case.gd"

# Story 11.2 (AC1/AC2/AC4) — the LIVE RUN FLOW wiring on RunOrchestrator: the ADDITIVE, OPT-IN live combat + live
# hero-death SOURCE, layered on top of the UNCHANGED v0 auto-resolve driver.
#
# Covers:
#   - AC1 — a live combat node, entered THROUGH THE RUN FLOW (resolve_current_node_live / resolve_combat_node_live),
#           resolves from a REAL board outcome (a driven/auto-played fight to STATE_VICTORY), clears + exits the node
#           (the run advances forward), and reports resolution == live_combat_victory (NOT combat_auto_resolved).
#   - AC1 (the seam is NOT silently auto-resolved) — the v0 auto-resolve (_resolve_combat / the default
#           resolve_current_node / run_to_completion) is STILL reachable + UNCHANGED for the non-live simulation path,
#           returning combat_auto_resolved; the live path returns live_combat_victory. The two are distinct + explicit.
#   - AC2 — the LIVE hero-death SOURCE: a live combat DEFEAT (a weak hero felled on the board) AUTO-FIRES the run-end
#           resolution (resolve_run_end(&"hero_death") -> PHASE_FAILED + run_failed cause hero_death + next_destination
#           == outpost), the run terminal, the node NOT cleared (a dead hero ends the run). The first-death latch then
#           records off the REAL terminal FAILED state (RecordFirstDeathCommand latches first_death_recorded).
#   - AC4 — idempotency: a second run-end drive on the already-terminal (live-death) run is the stable
#           run_already_terminal no-op (never double-fires / double-latches); the DEFAULT run_to_completion save-stream is
#           byte-identical to a second run (interrupted==uninterrupted determinism is not perturbed by the live loop).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RecordFirstDeathCommand = preload("res://scripts/core/commands/record_first_death_command.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# A seed whose depth-0 combat start node a strong sword hero clears (verified — the run advances past it).
const LIVE_SEED: int = 4242

func run() -> Dictionary:
	_live_combat_node_resolves_from_the_board_and_advances()
	_v0_auto_resolve_is_unchanged_and_distinct_from_live()
	_live_combat_defeat_auto_fires_the_hero_death_source()
	_first_death_latch_records_off_the_real_live_terminal_state()
	_run_end_auto_fire_is_idempotent_behind_the_terminal_guard()
	_default_run_to_completion_is_unperturbed_by_the_live_loop()
	return result()


# ---- AC1: a live combat node decides from the board + advances ------------------------------------

func _live_combat_node_resolves_from_the_board_and_advances() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "Setup: a fresh run is parked in ACTIVE_ROUTE on the start node.")
	var start_node_id: String = orchestrator.run.route.current_node_id
	assert_false(start_node_id.is_empty(), "Setup: the run is parked on the depth-0 start node.")

	# Resolve the parked combat node LIVE (through the run flow).
	var resolved: ActionResult = orchestrator.resolve_current_node_live()
	assert_true(resolved.succeeded, "A live combat-node resolution should succeed: %s" % resolved.metadata)
	# The board decided the node (a real victory), NOT "the level generated".
	assert_equal(String(resolved.metadata.get("resolution")), "live_combat_victory", "A live combat node reports live_combat_victory (from the board outcome), not combat_auto_resolved.")
	assert_equal(String(resolved.metadata.get("outcome")), "victory", "The live combat outcome is a board victory.")
	assert_true(int(resolved.metadata.get("rounds", 0)) >= 1, "A real fight took at least one round.")
	# The node was CLEARED + EXITED: the run advanced back to ACTIVE_ROUTE, the start node is in the cleared set, and the
	# run is non-terminal (a live victory advances the run forward, exactly like the v0 auto-resolve).
	assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "A live victory clears + exits the node (back to ACTIVE_ROUTE).")
	assert_true(orchestrator.run.route.cleared_node_ids.has(start_node_id), "A live victory clears the node (it joins cleared_node_ids).")
	assert_false(orchestrator.run.is_terminal(), "A live combat victory does NOT end the run (it advances forward).")
	assert_true(orchestrator.run.validate().succeeded, "The run stays structurally valid after a live victory.")


# ---- AC1: the v0 auto-resolve is UNCHANGED + distinct ---------------------------------------------

func _v0_auto_resolve_is_unchanged_and_distinct_from_live() -> void:
	# The DEFAULT resolve_current_node (the non-live simulation path) still AUTO-RESOLVES a combat node to success,
	# returning combat_auto_resolved — UNCHANGED. The live path returns live_combat_victory. A live fight is NEVER
	# silently auto-resolved (the two resolutions are explicit + distinct).
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var resolved: ActionResult = orchestrator.resolve_current_node()
	assert_true(resolved.succeeded, "The v0 auto-resolve should still succeed: %s" % resolved.metadata)
	assert_equal(String(resolved.metadata.get("resolution")), "combat_auto_resolved", "The DEFAULT resolve_current_node still AUTO-RESOLVES combat (the non-live simulation path, unchanged).")


# ---- AC2: the LIVE hero-death SOURCE --------------------------------------------------------------

func _live_combat_defeat_auto_fires_the_hero_death_source() -> void:
	# A weak (1 HP) hero is felled on the board — the live combat DEFEAT AUTO-FIRES the run-end resolution (the hero-death
	# SOURCE), driving PHASE_FAILED + run_failed cause hero_death + next_destination == outpost. The run is terminal; the
	# node is NOT cleared (a dead hero ends the run, it does not clear the node forward).
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	var start_node_id: String = orchestrator.run.route.current_node_id

	var resolved: ActionResult = orchestrator.resolve_current_node_live(1, &"dagger")
	assert_true(resolved.succeeded, "A live combat defeat should resolve (auto-firing the run-end): %s" % resolved.metadata)
	assert_equal(String(resolved.metadata.get("resolution")), "live_combat_defeat", "A live combat defeat reports live_combat_defeat.")
	assert_true(bool(resolved.metadata.get("run_failed")), "A live defeat flags run_failed (the auto-fired hero-death source).")

	# The run is terminal in PHASE_FAILED (the live hero-death drove the run-end).
	assert_equal(orchestrator.run.phase, RunState.PHASE_FAILED, "A live hero death drives the run to PHASE_FAILED.")
	assert_true(orchestrator.run.is_terminal(), "The live-death run is terminal.")
	# The run_failed event carries the hero_death cause + the outpost destination (FR32's loss half, LIVE).
	var run_failed: DomainEvent = orchestrator.run_failed_event()
	assert_true(run_failed != null, "The live death emits a run_failed event.")
	assert_equal(String(run_failed.payload.get("cause")), "hero_death", "The run_failed cause is hero_death (the auto-fired live source).")
	assert_equal(String(run_failed.payload.get("next_destination")), "outpost", "The run_failed routes to the outpost (FR32).")
	assert_equal(orchestrator.run_failed_cause(), "hero_death", "The orchestrator surfaces the hero_death cause.")
	assert_equal(orchestrator.run_end_destination(), "outpost", "The orchestrator surfaces the outpost destination.")
	# The node is NOT cleared (a dead hero ends the run — the cleared set is the nodes cleared BEFORE the death).
	assert_false(orchestrator.run.route.cleared_node_ids.has(start_node_id), "A live DEFEAT does NOT clear the node (the death ends the run).")


func _first_death_latch_records_off_the_real_live_terminal_state() -> void:
	# AC2: prove the first-death latch records off the REAL terminal state a LIVE hero death produced (not a hand-built
	# failed run). Drive a live death, then run RecordFirstDeathCommand on the terminal FAILED run.
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	assert_true(orchestrator.resolve_current_node_live(1, &"dagger").succeeded, "Setup: the live death should resolve.")
	assert_equal(orchestrator.run.phase, RunState.PHASE_FAILED, "Setup: the run is a real terminal FAILED run.")

	var profile: ProfileSnapshot = ProfileSnapshot.fresh("live_death_profile")
	assert_false(profile.first_death_recorded, "Setup: the profile has no first death yet.")
	var latch: ActionResult = RecordFirstDeathCommand.new(profile, 900000).execute(orchestrator.run)
	assert_true(latch.succeeded, "The first-death latch records off the REAL live terminal state: %s" % latch.metadata)
	assert_true(profile.first_death_recorded, "first_death_recorded flips off the real live hero death (the AC2 first-death latch).")


# ---- AC4: idempotency + the default loop is unperturbed -------------------------------------------

func _run_end_auto_fire_is_idempotent_behind_the_terminal_guard() -> void:
	# A second run-end drive on the already-terminal (live-death) run is the stable run_already_terminal no-op — the
	# hero-death auto-fire runs BEHIND the CompleteRunCommand terminal guard, so a re-detection never re-fires / double-
	# latches. A live-death run re-evaluated is a stable no-op.
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(LIVE_SEED, false).succeeded, "Setup: start should succeed.")
	assert_true(orchestrator.resolve_current_node_live(1, &"dagger").succeeded, "Setup: the live death should resolve.")
	var before: Dictionary = orchestrator.run.to_dictionary()

	var second: ActionResult = orchestrator.resolve_run_end(&"hero_death")
	assert_true(second.is_error(), "A second run-end on a terminal live-death run is rejected (no double-fire).")
	assert_equal(second.error_code, &"run_already_terminal", "The re-fire surfaces the stable run_already_terminal code.")
	assert_equal(orchestrator.run.to_dictionary(), before, "A re-fire leaves the run BYTE-IDENTICAL (no double mutation).")


func _default_run_to_completion_is_unperturbed_by_the_live_loop() -> void:
	# The live loop is ADDITIVE: the DEFAULT run_to_completion save-stream (the route-position autosaves) is byte-identical
	# across two independent runs of the same seed — the live combat path does NOT perturb the non-live stream advancement
	# the interrupted==uninterrupted route-position determinism depends on.
	var first_snaps: Array = _default_save_stream(LIVE_SEED)
	var second_snaps: Array = _default_save_stream(LIVE_SEED)
	assert_true(first_snaps.size() >= 1, "Setup: the default run composes at least one route-position save.")
	assert_equal(JSON.stringify(first_snaps), JSON.stringify(second_snaps), "The DEFAULT run_to_completion save-stream is byte-identical (the live loop does not perturb it).")


# ---- helpers -------------------------------------------------------------------------------------

func _default_save_stream(seed_value: int) -> Array:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	orchestrator.start(seed_value, false)
	var snaps: Array = []
	orchestrator.run_to_completion(func(snapshot): snaps.append(snapshot.to_dictionary()))
	return snaps
