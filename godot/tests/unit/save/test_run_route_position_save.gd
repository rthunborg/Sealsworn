extends "res://tests/unit/test_case.gd"

# Story 4.6 Task 6 — route-position save/resume (AC2: interrupted == uninterrupted). This is the single
# most error-prone part of 4.6: the run shell saves/restores the ROUTE position, which is DIFFERENT from the
# Epic-2 board-centric save (there is NO live BoardState at a route choice). It proves the board-free
# RunSnapshot.from_route_position compose helper + the RunResumeService.resume_route_position seam:
#   - a mid-route run (parked at a choice after clearing >= 1 node) saves + restores the SAME phase /
#     current_node_id / cleared_node_ids / meta_progression_eligible / is_manual_seed / root_seed / node
#     reveal states, through a REAL JSON round-trip via SaveRepository (to_dictionary -> JSON -> parse);
#   - the run-level RngStreamSet round-trips (int64 decimal-string discipline) and reproduces the exact next
#     draw;
#   - interrupted == uninterrupted: continuing from the RESTORED run reaches the SAME COMPLETED outcome /
#     run_completed cleared_node_count as the uninterrupted path;
#   - a corrupt / missing route-position save returns the FIRST structured error with NO restored RunState;
#   - the composed route-position snapshot stays within the 23-key no-surprise-key gate (no new top-level
#     key), and carries an EMPTY level_state (no embedded tactical board at a route choice).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunResumeService = preload("res://scripts/save/run_resume_service.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")

const SAVE_PATH := "user://test_route_position_save.json"

func run() -> Dictionary:
	_route_position_save_restores_the_route_position()
	_route_position_rng_round_trips_and_reproduces_next_draw()
	_interrupted_equals_uninterrupted()
	_callback_autosave_position_resumes_equals_uninterrupted()
	_corrupt_and_missing_save_expose_no_partial_state()
	_composed_route_position_snapshot_stays_within_the_23_key_gate()
	_route_position_seed_mismatch_rejects()
	_resume_route_position_seed_mismatch_rejects()
	_start_from_rejects_a_terminal_or_invalid_run()
	_cleanup()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# Drive an orchestrator partway (resolve + advance N times) so the run is parked at a route CHOICE in
# ACTIVE_ROUTE after clearing >= 1 node, NOT mid-level and NOT terminal. Returns the orchestrator.
func _orchestrator_parked_after_clearing(seed_value: int, advances: int) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(seed_value, false).succeeded, "Seed %d: start should succeed." % seed_value)
	var steps: int = 0
	while steps < advances and not orchestrator.run.is_terminal():
		var current: RouteNode = orchestrator.run.route.node_by_id(orchestrator.run.route.current_node_id)
		if current.type == RouteNode.TYPE_BOSS:
			break  # do not resolve the boss (that ends the run); stop parked before it.
		assert_true(orchestrator.resolve_current_node().succeeded, "Seed %d: resolve should succeed at parked step %d." % [seed_value, steps])
		assert_true(orchestrator.advance_to_first_eligible().succeeded, "Seed %d: advance should succeed at parked step %d." % [seed_value, steps])
		steps += 1
	assert_false(orchestrator.run.is_terminal(), "Seed %d: the parked run must NOT be terminal." % seed_value)
	assert_equal(orchestrator.run.phase, RunState.PHASE_ACTIVE_ROUTE, "Seed %d: the parked run must be at an ACTIVE_ROUTE choice." % seed_value)
	assert_true(orchestrator.run.route.cleared_node_ids.size() >= 1, "Seed %d: the parked run must have cleared >= 1 node." % seed_value)
	return orchestrator


# Write a RunSnapshot through the REAL SaveRepository (atomic JSON write) so the restore reads it back from a
# real JSON file (the latent-serialization-bug guard — never round-trip native dicts only).
func _write_through_repository(snapshot: RunSnapshot) -> void:
	var write_result: ActionResult = SaveRepository.new().write_run_snapshot(snapshot, SAVE_PATH)
	assert_true(write_result.succeeded, "Writing the route-position snapshot should succeed: %s" % write_result.metadata)


# ---- the route-position save/restore proof -------------------------------------------------------

func _route_position_save_restores_the_route_position() -> void:
	var orchestrator: RunOrchestrator = _orchestrator_parked_after_clearing(42, 3)
	var saved_run: RunState = orchestrator.run
	var saved_phase: StringName = saved_run.phase
	var saved_pointer: String = saved_run.route.current_node_id
	var saved_cleared: Array[String] = saved_run.route.cleared_node_ids.duplicate()
	var saved_reveals: Dictionary = _reveal_states(saved_run)

	# Compose the board-free route-position snapshot + write+read through the REAL repository.
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	assert_true(snapshot != null, "compose_route_position_snapshot should return a snapshot.")
	assert_true(snapshot.level_state.is_empty(), "A route-position snapshot must carry an EMPTY level_state (no embedded tactical board at a route choice).")
	_write_through_repository(snapshot)

	var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
	assert_true(restore.succeeded, "Resuming the route position should succeed: %s" % restore.metadata)
	var restored_run: RunState = restore.metadata.get("run_state") as RunState
	assert_true(restored_run != null, "The route-position resume should return a restored RunState.")

	# The restored run matches the saved run on every route-position field.
	assert_equal(restored_run.phase, saved_phase, "Restored phase must match the saved phase.")
	assert_equal(restored_run.route.current_node_id, saved_pointer, "Restored current_node_id must match the saved pointer.")
	assert_equal(restored_run.root_seed, saved_run.root_seed, "Restored root_seed must match.")
	assert_equal(restored_run.is_manual_seed, saved_run.is_manual_seed, "Restored is_manual_seed must match.")
	assert_equal(restored_run.meta_progression_eligible, saved_run.meta_progression_eligible, "Restored meta_progression_eligible must match.")
	assert_true(restored_run.validate().succeeded, "The restored run must validate.")
	# Cleared set matches (same membership + order).
	assert_equal(restored_run.route.cleared_node_ids.size(), saved_cleared.size(), "Restored cleared-set size must match.")
	for cleared_id: String in saved_cleared:
		assert_true(restored_run.route.cleared_node_ids.has(cleared_id), "Restored cleared set must contain %s." % cleared_id)
	# Reveal states match for every node.
	var restored_reveals: Dictionary = _reveal_states(restored_run)
	for node_id: String in saved_reveals.keys():
		assert_equal(restored_reveals.get(node_id), saved_reveals.get(node_id), "Restored reveal state for %s must match the saved state." % node_id)


func _route_position_rng_round_trips_and_reproduces_next_draw() -> void:
	var orchestrator: RunOrchestrator = _orchestrator_parked_after_clearing(2026, 2)
	# Capture the saved streams' NEXT draw (a pure peek via a copy: snapshot -> restore -> draw, so the live
	# streams are untouched).
	var saved_snapshot_dict: Dictionary = orchestrator.streams.to_snapshot()
	var expected_streams: RngStreamSet = RngStreamSet.new(0)
	assert_true(expected_streams.try_restore(saved_snapshot_dict).succeeded, "Saved RNG snapshot should restore for the expected-draw peek.")
	var expected_draw: ActionResult = expected_streams.rand_int(RngStreamSet.STREAM_MAP, 0, 1000000, {})
	assert_true(expected_draw.succeeded, "The expected next draw should succeed.")

	# Save + restore through the repository, then assert the restored streams reproduce the EXACT next draw.
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	_write_through_repository(snapshot)
	var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
	assert_true(restore.succeeded, "Route-position resume should succeed for the RNG round-trip: %s" % restore.metadata)
	var restored_streams: RngStreamSet = restore.metadata.get("rng_streams") as RngStreamSet
	assert_true(restored_streams != null, "The route-position resume should return restored RNG streams.")
	var restored_draw: ActionResult = restored_streams.rand_int(RngStreamSet.STREAM_MAP, 0, 1000000, {})
	assert_true(restored_draw.succeeded, "The restored next draw should succeed.")
	assert_equal(restored_draw.metadata.get("value"), expected_draw.metadata.get("value"), "The restored run-level streams must reproduce the EXACT next map draw (int64 round-trip).")


func _interrupted_equals_uninterrupted() -> void:
	# Run a route partway, SAVE the route position, RESTORE it, continue to COMPLETED — and assert the SAME
	# final outcome / run_completed cleared_node_count / final run.to_dictionary() as the UNINTERRUPTED path.
	for seed_value: int in [42, 777]:
		# Uninterrupted reference run.
		var uninterrupted: RunOrchestrator = RunOrchestrator.new()
		assert_true(uninterrupted.start(seed_value, false).succeeded, "Seed %d: uninterrupted start should succeed." % seed_value)
		assert_true(uninterrupted.run_to_completion().succeeded, "Seed %d: uninterrupted run should complete." % seed_value)
		var uninterrupted_final: String = JSON.stringify(uninterrupted.run.to_dictionary())
		var uninterrupted_cleared: int = uninterrupted.run.route.cleared_node_ids.size()
		var uninterrupted_outcome: String = uninterrupted.run_completed_outcome()

		# Interrupted: park partway, save, restore, continue.
		var parked: RunOrchestrator = _orchestrator_parked_after_clearing(seed_value, 2)
		var snapshot: RunSnapshot = parked.compose_route_position_snapshot()
		_write_through_repository(snapshot)
		var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
		assert_true(restore.succeeded, "Seed %d: route-position resume should succeed: %s" % [seed_value, restore.metadata])
		var restored_run: RunState = restore.metadata.get("run_state") as RunState
		var restored_streams: RngStreamSet = restore.metadata.get("rng_streams") as RngStreamSet

		# Continue the RESTORED run to completion through a fresh orchestrator seated on the restored state.
		var resumed: RunOrchestrator = RunOrchestrator.new()
		assert_true(resumed.start_from(restored_run, restored_streams).succeeded, "Seed %d: seating the restored non-terminal run should succeed." % seed_value)
		var completion: ActionResult = resumed.run_to_completion()
		assert_true(completion.succeeded, "Seed %d: the resumed run should complete: %s" % [seed_value, completion.metadata])

		assert_equal(resumed.run.phase, RunState.PHASE_COMPLETED, "Seed %d: the resumed run should reach COMPLETED." % seed_value)
		assert_equal(resumed.run_completed_outcome(), uninterrupted_outcome, "Seed %d: the resumed outcome must match the uninterrupted outcome." % seed_value)
		assert_equal(resumed.run.route.cleared_node_ids.size(), uninterrupted_cleared, "Seed %d: the resumed cleared_node_count must match the uninterrupted path." % seed_value)
		# The full final run state matches byte-for-byte (route + cleared + phase + seed). Mismatches identify
		# the first divergent step via the stringified diff in the message.
		assert_equal(JSON.stringify(resumed.run.to_dictionary()), uninterrupted_final, "Seed %d: interrupted == uninterrupted — the resumed final run state must match the uninterrupted final run state." % seed_value)


# Finding-1 regression: the wired run_to_completion route-position autosave callback must save a position the
# resume path can round-trip. Drive run_to_completion WITH a real save callback (which now fires AFTER each
# advance, capturing the POST-ADVANCE fresh-node position), resume from the FIRST captured snapshot, continue
# to COMPLETED, and assert interrupted == uninterrupted for THAT callback boundary. Before the fix the callback
# fired pre-advance (pointer on a just-cleared node); resuming from it re-entered the cleared node. The
# resolve_current_node() already-cleared no-op guard is the defense-in-depth; this proves the SAVED position is
# a fresh, cleanly-resumable node.
func _callback_autosave_position_resumes_equals_uninterrupted() -> void:
	for seed_value: int in [42, 314]:
		# Uninterrupted reference run.
		var uninterrupted: RunOrchestrator = RunOrchestrator.new()
		assert_true(uninterrupted.start(seed_value, false).succeeded, "Seed %d: callback-autosave uninterrupted start should succeed." % seed_value)
		assert_true(uninterrupted.run_to_completion().succeeded, "Seed %d: callback-autosave uninterrupted run should complete." % seed_value)
		var uninterrupted_final: String = JSON.stringify(uninterrupted.run.to_dictionary())
		var uninterrupted_cleared: int = uninterrupted.run.route.cleared_node_ids.size()
		var uninterrupted_outcome: String = uninterrupted.run_completed_outcome()

		# Drive a fresh run to completion WITH a save callback; capture the FIRST autosaved snapshot through
		# the REAL repository (the callback persists each post-advance position).
		var captured: Array[RunSnapshot] = []
		var driver: RunOrchestrator = RunOrchestrator.new()
		assert_true(driver.start(seed_value, false).succeeded, "Seed %d: callback-autosave driver start should succeed." % seed_value)
		var callback: Callable = func(snapshot: RunSnapshot) -> void:
			if captured.is_empty():
				captured.append(snapshot)
				_write_through_repository(snapshot)
		assert_true(driver.run_to_completion(callback).succeeded, "Seed %d: callback-autosave driver run should complete." % seed_value)
		assert_false(captured.is_empty(), "Seed %d: the autosave callback must fire at least once (>= 1 between-node boundary)." % seed_value)
		# The captured (post-advance) save position parks on a node that is NOT yet cleared (the fix's point).
		var captured_snapshot: RunSnapshot = captured[0]
		assert_false(captured_snapshot.route_state.get("cleared_node_ids", []).has(captured_snapshot.current_route_node_id), "Seed %d: the callback-saved position must park on a node NOT already cleared (post-advance fresh node)." % seed_value)

		# Resume from the FIRST callback-saved snapshot and continue to COMPLETED via a fresh orchestrator.
		var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
		assert_true(restore.succeeded, "Seed %d: resuming the callback-saved position should succeed: %s" % [seed_value, restore.metadata])
		var restored_run: RunState = restore.metadata.get("run_state") as RunState
		var restored_streams: RngStreamSet = restore.metadata.get("rng_streams") as RngStreamSet
		var resumed: RunOrchestrator = RunOrchestrator.new()
		assert_true(resumed.start_from(restored_run, restored_streams).succeeded, "Seed %d: seating the callback-restored run should succeed." % seed_value)
		var completion: ActionResult = resumed.run_to_completion()
		assert_true(completion.succeeded, "Seed %d: the callback-resumed run should complete: %s" % [seed_value, completion.metadata])

		assert_equal(resumed.run.phase, RunState.PHASE_COMPLETED, "Seed %d: the callback-resumed run should reach COMPLETED." % seed_value)
		assert_equal(resumed.run_completed_outcome(), uninterrupted_outcome, "Seed %d: the callback-resumed outcome must match the uninterrupted outcome." % seed_value)
		assert_equal(resumed.run.route.cleared_node_ids.size(), uninterrupted_cleared, "Seed %d: the callback-resumed cleared_node_count must match the uninterrupted path." % seed_value)
		assert_equal(JSON.stringify(resumed.run.to_dictionary()), uninterrupted_final, "Seed %d: callback-autosave interrupted == uninterrupted — the resumed final run state must match." % seed_value)


func _corrupt_and_missing_save_expose_no_partial_state() -> void:
	# A MISSING route-position save returns the first structured read error with NO restored RunState.
	var missing: ActionResult = RunResumeService.new().resume_route_position("user://test_route_position_missing.json")
	assert_true(missing.is_error(), "A missing route-position save must be a structured error.")
	assert_equal(missing.error_code, &"save_not_found", "A missing save should use the stable save_not_found code.")
	assert_false(missing.metadata.has("run_state"), "A missing-save failure must expose no restored RunState.")

	# A CORRUPT route-position save (a structurally-invalid route, e.g. an unknown current pointer) returns
	# the first structured error with NO restored RunState. Compose a valid snapshot, corrupt its route_state
	# pointer to a node that does not exist, write it, and resume.
	var orchestrator: RunOrchestrator = _orchestrator_parked_after_clearing(13, 2)
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	# Corrupt the nested route_state current_node_id to an unknown node (RouteState.validate rejects it).
	var corrupt_route_state: Dictionary = snapshot.route_state.duplicate(true)
	corrupt_route_state["current_node_id"] = "node-does-not-exist"
	snapshot.route_state = corrupt_route_state
	snapshot.current_route_node_id = "node-does-not-exist"
	_write_through_repository(snapshot)
	var corrupt: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
	assert_true(corrupt.is_error(), "A corrupt route-position save must be a structured error.")
	assert_false(corrupt.metadata.has("run_state"), "A corrupt-save failure must expose no restored RunState (no partial state).")


func _composed_route_position_snapshot_stays_within_the_23_key_gate() -> void:
	var orchestrator: RunOrchestrator = _orchestrator_parked_after_clearing(99, 2)
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	var data: Dictionary = snapshot.to_dictionary()
	# Real JSON round-trip (the int64 root_seed in rng_streams + root_seed survives).
	var json_data: Variant = JSON.parse_string(JSON.stringify(data))
	assert_true(json_data is Dictionary, "The route-position snapshot must survive a JSON round-trip.")
	var allowed: Dictionary = _allowed_run_snapshot_keys()
	for key: Variant in (json_data as Dictionary).keys():
		assert_true(allowed.has(key), "A route-position save must not introduce a surprise top-level key (%s)." % str(key))
	# The three route fields + rng_streams are populated; level_state is empty.
	assert_true((json_data as Dictionary).has("route_state"), "The route-position save must populate route_state.")
	assert_true((json_data as Dictionary).has("current_route_node_id"), "The route-position save must populate current_route_node_id.")
	assert_true((json_data as Dictionary).has("revealed_route_node_ids"), "The route-position save must populate revealed_route_node_ids.")
	assert_true((json_data as Dictionary).has("rng_streams"), "The route-position save must populate rng_streams.")
	assert_equal((json_data as Dictionary).get("level_state"), {}, "The route-position save must carry an empty level_state.")
	# The run-level RNG root_seed in the snapshot must be the int64-safe decimal STRING form.
	var rng_streams: Dictionary = (json_data as Dictionary).get("rng_streams")
	assert_true(rng_streams.get("root_seed") is String, "The rng_streams root_seed must be a decimal string (int64-safe).")


# Finding-2 regression: from_route_position must reject a streams set seeded differently from the run (the
# run-seed and RNG-seed would otherwise diverge silently in the snapshot). The single orchestrator caller
# always passes matching seeds; this drives the defensive guard directly.
func _route_position_seed_mismatch_rejects() -> void:
	var orchestrator: RunOrchestrator = _orchestrator_parked_after_clearing(42, 2)
	# A matching-seed compose succeeds (the normal path).
	var ok_result: ActionResult = RunSnapshot.from_route_position(orchestrator.run, orchestrator.streams)
	assert_true(ok_result.succeeded, "A matching run/streams seed should compose a route-position snapshot.")
	# A DIFFERENT-seed streams set must be rejected with the stable mismatch code and NO snapshot.
	var mismatched_streams: RngStreamSet = RngStreamSet.new(orchestrator.run.root_seed + 1)
	var bad_result: ActionResult = RunSnapshot.from_route_position(orchestrator.run, mismatched_streams)
	assert_true(bad_result.is_error(), "A run/streams root_seed mismatch must be a structured error.")
	assert_equal(bad_result.error_code, &"route_position_seed_mismatch", "A seed mismatch should use the stable route_position_seed_mismatch code.")
	assert_false(bad_result.metadata.has("snapshot"), "A seed-mismatch failure must expose no composed snapshot.")


# Round-2 finding regression (READ-side symmetry): the compose side now guarantees the game never WRITES a
# route-position save whose top-level root_seed diverges from rng_streams.root_seed — but resume_route_position
# rebuilds the RunState (from the top-level root_seed) and the RngStreamSet (from rng_streams.root_seed)
# INDEPENDENTLY, so a HAND-EDITED / corrupted on-disk save must be rejected on the read side too. Write a valid
# snapshot, mutate ONLY its on-disk rng_streams.root_seed to a different (still-valid int64) value, and assert
# resume rejects with the stable route_position_seed_mismatch code and NO restored run_state (no partial state).
func _resume_route_position_seed_mismatch_rejects() -> void:
	var orchestrator: RunOrchestrator = _orchestrator_parked_after_clearing(42, 2)
	var snapshot: RunSnapshot = orchestrator.compose_route_position_snapshot()
	_write_through_repository(snapshot)

	# Hand-edit the on-disk JSON: diverge rng_streams.root_seed from the top-level root_seed (still a valid
	# int64 decimal string, so try_restore SUCCEEDS and the new symmetric cross-check is what rejects it).
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	assert_true(file != null, "The written route-position save should be readable for the hand-edit.")
	var on_disk: Variant = JSON.parse_string(file.get_as_text())
	file = null
	assert_true(on_disk is Dictionary, "The on-disk save must parse as a Dictionary.")
	var data: Dictionary = on_disk
	var rng_streams: Dictionary = data.get("rng_streams")
	rng_streams["root_seed"] = str(snapshot.root_seed + 1)
	data["rng_streams"] = rng_streams
	var rewrite: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	assert_true(rewrite != null, "The hand-edited save should be writable.")
	rewrite.store_string(JSON.stringify(data))
	rewrite.flush()
	rewrite = null

	var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
	assert_true(restore.is_error(), "A route-position save with a diverged on-disk rng_streams.root_seed must be a structured error.")
	assert_equal(restore.error_code, &"route_position_seed_mismatch", "The read-side seed mismatch should use the stable route_position_seed_mismatch code.")
	assert_false(restore.metadata.has("run_state"), "A read-side seed-mismatch failure must expose no restored RunState (no partial state).")


# Finding-3 regression: start_from must reject a terminal or structurally-invalid seated run (mirroring the
# command no-partial contract) so the resume-seat seam cannot drive a stale/invalid run. A valid non-terminal
# run is still accepted (the normal resume path).
func _start_from_rejects_a_terminal_or_invalid_run() -> void:
	# A null run / null streams reject.
	var null_run: ActionResult = RunOrchestrator.new().start_from(null, RngStreamSet.new(0))
	assert_true(null_run.is_error(), "Seating a null run must be a structured error.")
	assert_equal(null_run.error_code, &"invalid_seated_run", "A null seated run should use the stable invalid_seated_run code.")
	var parked: RunOrchestrator = _orchestrator_parked_after_clearing(7, 2)
	var null_streams: ActionResult = RunOrchestrator.new().start_from(parked.run, null)
	assert_true(null_streams.is_error(), "Seating null streams must be a structured error.")
	assert_equal(null_streams.error_code, &"invalid_seated_streams", "Null seated streams should use the stable invalid_seated_streams code.")

	# A TERMINAL run rejects: run a fresh run to COMPLETED, then try to seat it.
	var completed: RunOrchestrator = RunOrchestrator.new()
	assert_true(completed.start(7, false).succeeded, "Seating-terminal: start should succeed.")
	assert_true(completed.run_to_completion().succeeded, "Seating-terminal: run should complete.")
	assert_true(completed.run.is_terminal(), "Seating-terminal: the run should be terminal before the reject check.")
	var terminal_seat: ActionResult = RunOrchestrator.new().start_from(completed.run, completed.streams)
	assert_true(terminal_seat.is_error(), "Seating a terminal run must be a structured error.")
	assert_equal(terminal_seat.error_code, &"seated_run_terminal", "A terminal seated run should use the stable seated_run_terminal code.")

	# A valid NON-terminal run is still accepted (the normal resume-seat path).
	var ok_seat: ActionResult = RunOrchestrator.new().start_from(parked.run, parked.streams)
	assert_true(ok_seat.succeeded, "Seating a valid non-terminal run should succeed.")


# ---- utilities -----------------------------------------------------------------------------------

func _reveal_states(run: RunState) -> Dictionary:
	var reveals: Dictionary = {}
	for node: RouteNode in run.route.nodes():
		reveals[node.id] = String(node.reveal_state)
	return reveals


func _cleanup() -> void:
	# Remove the test save file so it does not linger between runs.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _allowed_run_snapshot_keys() -> Dictionary:
	var keys: Dictionary = {}
	for key: String in [
		"schema_version", "content_version", "profile_id", "run_id", "root_seed",
		"is_manual_seed", "meta_progression_eligible", "route_state", "current_route_node_id",
		"revealed_route_node_ids", "level_state", "turn_state", "rng_streams", "board",
		"inventory", "equipment", "passives", "curses", "gold", "oath_shards", "corruption",
		"affinities", "meta_progression"
	]:
		keys[key] = true
	return keys
