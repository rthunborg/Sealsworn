extends "res://tests/unit/test_case.gd"

# Story 15.4 (AC1) — the QUIT-SAVE COMPOSITION seam (QuitRunBridge). The live-board Quit-run action saves the run's
# route position through the EXISTING Epic-2 seam so the descent survives closing the game. This pins the two quit
# positions:
#   - BETWEEN-NODE (ACTIVE_ROUTE): the compose is a PURE READ — the live run + streams are unmutated, zero RNG —
#     and round-trips to the same route position;
#   - MID-FIGHT (NODE_RESOLUTION): the in-node fight is EPHEMERAL. The bridge composes at the RESUMABLE BOUNDARY —
#     it backs the run out to ACTIVE_ROUTE parked on the current, UN-CLEARED node ON A COPY (the live run is
#     unmutated) so on resume the node RE-ENTERS cleanly (NodeEnterCommand requires ACTIVE_ROUTE). No new save key;
#     the 23-key RunSnapshot gate stays 23.
# A null / unseated / terminal orchestrator composes NO quit save (a completed/failed run is not a resumable
# route position).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const QuitRunBridge = preload("res://scripts/ui/flow/quit_run_bridge.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunResumeService = preload("res://scripts/save/run_resume_service.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")

const SAVE_PATH := "user://test_quit_run_bridge_save.json"
const SEED := 4242

func run() -> Dictionary:
	_between_node_quit_is_a_pure_read_and_round_trips()
	_mid_fight_quit_backs_out_to_active_route_on_a_copy_and_re_enters()
	# Story 15.4 (Review D2) — a mid-fight quit -> resume -> re-enter yields the SAME room affinity (no reroll) and
	# the `map` stream is at the SAME position an uninterrupted run would have (no extra draw) for a non-none room.
	_mid_fight_quit_preserves_room_affinity_and_map_stream_on_resume()
	_null_unseated_and_terminal_return_null()
	_cleanup()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# Drive an orchestrator partway (resolve + advance) so the run is parked at an ACTIVE_ROUTE choice after clearing
# >= 1 node, NOT terminal (the between-node quit position). Mirrors the route-position save test's helper.
func _parked_after_clearing(seed_value: int, advances: int) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(seed_value, false).succeeded, "Setup: start should succeed.")
	var steps: int = 0
	while steps < advances and not orchestrator.run.is_terminal():
		var current: RouteNode = orchestrator.run.route.node_by_id(orchestrator.run.route.current_node_id)
		if current.type == RouteNode.TYPE_BOSS:
			break
		assert_true(orchestrator.resolve_current_node().succeeded, "Setup: resolve should succeed at step %d." % steps)
		assert_true(orchestrator.advance_to_first_eligible().succeeded, "Setup: advance should succeed at step %d." % steps)
		steps += 1
	assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "Setup: the parked run is at an ACTIVE_ROUTE choice.")
	return orchestrator


func _write(snapshot: RunSnapshot) -> void:
	assert_true(SaveRepository.new().write_run_snapshot(snapshot, SAVE_PATH).succeeded, "Writing the quit save should succeed.")


func _cleanup() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


# ---- between-node quit: pure read + round-trip ---------------------------------------------------

func _between_node_quit_is_a_pure_read_and_round_trips() -> void:
	var orchestrator: RunOrchestrator = _parked_after_clearing(SEED, 2)
	var saved_pointer: String = orchestrator.run.route.current_node_id
	var pre_run: String = JSON.stringify(orchestrator.run.to_dictionary())
	var pre_streams: String = JSON.stringify(orchestrator.streams.to_snapshot())

	var snapshot: RunSnapshot = QuitRunBridge.compose_quit_save(orchestrator)
	assert_true(snapshot != null, "A between-node quit composes a route-position snapshot.")
	# PURE READ: the compose mutates neither the live run nor the streams (zero RNG).
	assert_equal(JSON.stringify(orchestrator.run.to_dictionary()), pre_run, "The between-node compose must not mutate the live run.")
	assert_equal(JSON.stringify(orchestrator.streams.to_snapshot()), pre_streams, "The between-node compose must draw ZERO RNG (streams unchanged).")
	# The saved position is the ACTIVE_ROUTE resumable boundary, and level_state is empty (no board at a choice).
	assert_equal(String(snapshot.route_state.get(String(RunState.RUN_PHASE_KEY))), String(RunState.PHASE_ACTIVE_ROUTE), "The quit save nests the ACTIVE_ROUTE resumable phase.")
	assert_true(snapshot.level_state.is_empty(), "The quit save carries an EMPTY level_state (no embedded board).")

	# Round-trip through the real repository restores the same position.
	_write(snapshot)
	var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
	assert_true(restore.succeeded, "Resuming the between-node quit save should succeed: %s" % restore.metadata)
	var restored_run: RunState = restore.metadata.get("run_state") as RunState
	assert_equal(restored_run.route.current_node_id, saved_pointer, "The restored run parks on the same node.")
	assert_equal(restored_run.phase, RunState.PHASE_ACTIVE_ROUTE, "The restored run is at the ACTIVE_ROUTE boundary.")
	assert_true(restored_run.validate().succeeded, "The restored run validates.")


# ---- mid-fight quit: back out on a copy + re-enter -----------------------------------------------

func _mid_fight_quit_backs_out_to_active_route_on_a_copy_and_re_enters() -> void:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(SEED, false, &"warrior").succeeded, "Setup: warrior start should succeed.")
	var node_id: String = orchestrator.run.route.current_node_id
	var start_node: RouteNode = orchestrator.run.route.node_by_id(node_id)
	# Enter the node interactively -> the run is mid-fight in NODE_RESOLUTION, the node un-cleared.
	assert_true(orchestrator.begin_interactive_combat_node(start_node).succeeded, "Setup: interactive begin should succeed.")
	assert_equal(orchestrator.run.phase, RunState.PHASE_NODE_RESOLUTION, "Setup: mid-fight the run is in NODE_RESOLUTION.")
	assert_false(orchestrator.run.route.cleared_node_ids.has(node_id), "Setup: the mid-fight node is NOT yet cleared.")
	var pre_run: String = JSON.stringify(orchestrator.run.to_dictionary())

	# Compose the quit save. The live run stays NODE_RESOLUTION (composed from a backed-out COPY) — a pure read.
	var snapshot: RunSnapshot = QuitRunBridge.compose_quit_save(orchestrator)
	assert_true(snapshot != null, "A mid-fight quit composes a route-position snapshot.")
	assert_equal(JSON.stringify(orchestrator.run.to_dictionary()), pre_run, "The mid-fight compose must NOT mutate the live run (it composes from a copy).")
	# The saved position is backed out to the resumable ACTIVE_ROUTE boundary, parked on the same UN-CLEARED node.
	assert_equal(String(snapshot.route_state.get(String(RunState.RUN_PHASE_KEY))), String(RunState.PHASE_ACTIVE_ROUTE), "The mid-fight quit save is backed out to the ACTIVE_ROUTE resumable boundary.")
	assert_equal(snapshot.current_route_node_id, node_id, "The quit save parks on the current node.")
	assert_false((snapshot.route_state.get("cleared_node_ids", []) as Array).has(node_id), "The quit save leaves the current node UN-CLEARED (the fight is ephemeral).")

	# Round-trip + RE-ENTER: resume -> seat via start_from -> begin_interactive_combat_node re-enters cleanly.
	_write(snapshot)
	var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
	assert_true(restore.succeeded, "Resuming the mid-fight quit save should succeed: %s" % restore.metadata)
	var restored_run: RunState = restore.metadata.get("run_state") as RunState
	var restored_streams: RngStreamSet = restore.metadata.get("rng_streams") as RngStreamSet
	assert_equal(restored_run.phase, RunState.PHASE_ACTIVE_ROUTE, "The resumed run is at the ACTIVE_ROUTE boundary (re-enterable).")
	assert_equal(restored_run.route.current_node_id, node_id, "The resumed run parks on the same node.")

	var resumed: RunOrchestrator = RunOrchestrator.new()
	assert_true(resumed.start_from(restored_run, restored_streams).succeeded, "Seating the resumed run should succeed.")
	var re_node: RouteNode = resumed.run.route.node_by_id(resumed.run.route.current_node_id)
	var re_enter: ActionResult = resumed.begin_interactive_combat_node(re_node)
	assert_true(re_enter.succeeded, "The un-cleared node must RE-ENTER cleanly on resume (NodeEnterCommand from ACTIVE_ROUTE): %s" % re_enter.metadata)


# ---- D2: the entered room's affinity survives quit/resume (no reroll, no extra map draw) ----------

# Story 15.4 (Review D2). A mid-fight quit discards the ephemeral fight but the ENTERED room's assigned affinity
# must survive the quit/resume round trip so the player re-enters the SAME room, and the `map` stream must NOT take
# an extra draw. WITHOUT the fix the route-position restore rebuilds the run with an EMPTY assigned_affinities, so
# re-entering the un-cleared node re-runs assign_affinity (a second `map` draw -> possible reroll + a one-draw map
# drift). This drives the real interactive entry (a natural affinity draw), quits at the resumable boundary, resumes
# through RunResumeService, seats via start_from, and re-enters — asserting the room affinity is preserved for EVERY
# seed and, for a NON-none room (the guard-skip path), the map stream is byte-at-the-same-position as an
# uninterrupted single entry. Iterates seeds so at least one exercises a non-none room (none is 1 of 5 affinities).
func _mid_fight_quit_preserves_room_affinity_and_map_stream_on_resume() -> void:
	var proved_non_none: bool = false
	for seed_value: int in [4242, 42, 777, 2026, 13, 99]:
		# Enter the depth-0 combat node interactively (RouteGenerator GUARANTEES depth-0 is a combat node) so the
		# room's affinity is drawn + recorded and the run is mid-fight (NODE_RESOLUTION, node un-cleared).
		var live: RunOrchestrator = RunOrchestrator.new()
		assert_true(live.start(seed_value, false, &"warrior").succeeded, "Seed %d: warrior start should succeed." % seed_value)
		var node_id: String = live.run.route.current_node_id
		var node: RouteNode = live.run.route.node_by_id(node_id)
		assert_true(live.begin_interactive_combat_node(node).succeeded, "Seed %d: entering the depth-0 room should succeed." % seed_value)
		var entered_affinity: String = String(live.assigned_affinity_for(node_id))
		var map_after_entry: int = _map_draw_index(live.streams)

		# Quit mid-fight -> compose at the resumable boundary. The snapshot mirrors the entered room's affinity.
		var snapshot: RunSnapshot = QuitRunBridge.compose_quit_save(live)
		assert_true(snapshot != null, "Seed %d: a mid-fight quit composes a snapshot." % seed_value)
		assert_equal(String(snapshot.affinities.get(node_id, "")), entered_affinity, "Seed %d: the quit save mirrors the entered room's affinity." % seed_value)
		_write(snapshot)

		# Resume -> D2: the restored run carries the entered room's affinity (NOT an empty reroll surface).
		var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
		assert_true(restore.succeeded, "Seed %d: resuming the mid-fight quit save should succeed: %s" % [seed_value, restore.metadata])
		var restored_run: RunState = restore.metadata.get("run_state") as RunState
		assert_equal(String(restored_run.assigned_affinities.get(node_id, "")), entered_affinity, "Seed %d: D2 — the resumed run restores the entered room's assigned affinity (no reroll surface)." % seed_value)

		# For a NON-none room the assign-if-absent guard SKIPS the draw on re-enter -> the room is the SAME and the
		# `map` stream is at the SAME position an uninterrupted single entry left it (no extra draw). (A `none` room
		# re-rolls by the guard's design — the human-accepted deferred edge; do not assert the map position there.)
		if entered_affinity != String(AffinityDefinition.AFFINITY_NONE):
			var resumed: RunOrchestrator = RunOrchestrator.new()
			assert_true(resumed.start_from(restored_run, restore.metadata.get("rng_streams") as RngStreamSet).succeeded, "Seed %d: seating the resumed run should succeed." % seed_value)
			var re_node: RouteNode = resumed.run.route.node_by_id(node_id)
			assert_true(resumed.begin_interactive_combat_node(re_node).succeeded, "Seed %d: the un-cleared room re-enters cleanly on resume." % seed_value)
			assert_equal(String(resumed.assigned_affinity_for(node_id)), entered_affinity, "Seed %d: D2 — re-entering the resumed room yields the SAME affinity (no reroll)." % seed_value)
			assert_equal(_map_draw_index(resumed.streams), map_after_entry, "Seed %d: D2 — a non-none room takes NO extra map draw on resume (interrupted map position == uninterrupted)." % seed_value)
			proved_non_none = true
	assert_true(proved_non_none, "D2: at least one seed must exercise a non-none room (the guard-skip / no-extra-draw path).")


# The `map` stream's draw index from an RngStreamSet snapshot (the position the affinity draw advances). The
# affinity assign is the ONLY run-level `map` draw in begin_interactive_combat_node (LevelGenerator mints its own
# level stream; NodeEnterCommand never sees the run-level streams), so this index advances by exactly 1 per entry.
func _map_draw_index(streams: RngStreamSet) -> int:
	var by_stream: Dictionary = streams.to_snapshot().get("streams", {})
	return int((by_stream.get("map", {}) as Dictionary).get("draw_index", 0))


# ---- null / unseated / terminal ------------------------------------------------------------------

func _null_unseated_and_terminal_return_null() -> void:
	assert_true(QuitRunBridge.compose_quit_save(null) == null, "A null orchestrator composes no quit save.")
	assert_true(QuitRunBridge.compose_quit_save(RunOrchestrator.new()) == null, "An unseated orchestrator (no run) composes no quit save.")

	var terminal: RunOrchestrator = RunOrchestrator.new()
	assert_true(terminal.start(SEED, false).succeeded, "Setup: start should succeed.")
	assert_true(terminal.resolve_run_end(&"completed").succeeded, "Setup: completing the run should succeed.")
	assert_true(terminal.run.is_terminal(), "Setup: the run is terminal.")
	assert_true(QuitRunBridge.compose_quit_save(terminal) == null, "A terminal run composes no quit save (not a resumable route position).")
