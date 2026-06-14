extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const SaveManager = preload("res://scripts/autoloads/save_manager.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")

const TEST_SAVE_PATH := "user://test_run_autosave.json"

func run() -> Dictionary:
	_write_then_read_round_trips_snapshot()
	_read_rejects_unsupported_schema()
	_write_failure_returns_structured_error_without_mutation()
	_write_failure_preserves_existing_valid_save()
	_save_manager_autosave_between_level_delegates_to_repository()
	_cleanup()
	return result()


func _write_then_read_round_trips_snapshot() -> void:
	_cleanup()

	var repository: SaveRepository = SaveRepository.new()
	var snapshot: RunSnapshot = RunSnapshot.new()
	snapshot.root_seed = 9876

	var write_result: ActionResult = repository.write_run_snapshot(snapshot, TEST_SAVE_PATH)
	var read_result: ActionResult = repository.read_run_snapshot(TEST_SAVE_PATH)

	assert_true(write_result.succeeded, "SaveRepository should write through the temp/replace path: %s" % write_result.metadata)
	assert_true(read_result.succeeded, "SaveRepository should read a written snapshot: %s" % read_result.metadata)
	if read_result.succeeded:
		assert_equal(read_result.metadata.get("snapshot").root_seed, 9876, "SaveRepository should round-trip snapshot data.")


func _read_rejects_unsupported_schema() -> void:
	_cleanup()

	var file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": RunSnapshot.SCHEMA_VERSION + 10,
		"content_version": "future"
	}))
	file.flush()
	file = null

	var repository: SaveRepository = SaveRepository.new()
	var read_result: ActionResult = repository.read_run_snapshot(TEST_SAVE_PATH)

	assert_true(read_result.is_error(), "SaveRepository should reject unsupported save schemas: %s" % read_result.metadata)
	assert_equal(read_result.error_code, &"unsupported_save_schema", "SaveRepository should return the schema error.")


# AC4: a forced write failure returns a structured error and never mutates domain state.
func _write_failure_returns_structured_error_without_mutation() -> void:
	var repository: SaveRepository = SaveRepository.new()
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(555)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})

	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {"current_route_node_id": "n1"})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	var snapshot_before: Dictionary = snapshot.to_dictionary()
	var board_before: Dictionary = board.to_snapshot()
	var rng_before: Dictionary = streams.to_snapshot()

	# Writing into a non-existent directory fails at temp open (FileAccess does not create dirs).
	var failing_path: String = "user://__test_missing_dir__/run_autosave.json"
	var write_result: ActionResult = repository.write_run_snapshot(snapshot, failing_path)

	assert_true(write_result.is_error(), "A write into a missing directory must fail.")
	assert_equal(write_result.error_code, &"save_open_failed", "Write failure must surface a stable structured error code.")
	assert_true(write_result.metadata.has("path"), "Write failure must include diagnostic path metadata.")
	assert_true(write_result.metadata.has("open_error"), "Write failure must include the open error diagnostic.")

	# Saving is a read of domain state: nothing may be mutated by a failed write.
	assert_equal(snapshot.to_dictionary(), snapshot_before, "Failed write must not mutate the in-memory RunSnapshot.")
	assert_equal(board.to_snapshot(), board_before, "Failed write must not mutate the source BoardState.")
	assert_equal(streams.to_snapshot(), rng_before, "Failed write must not mutate the source RngStreamSet.")
	# Confirm no stray temp/backup artifacts were left in the real test dir for this path.
	assert_false(FileAccess.file_exists("%s.tmp" % failing_path), "Failed write must not leave a temp file behind.")


# AC4: when a prior valid save exists and a new write fails, the original file is preserved.
func _write_failure_preserves_existing_valid_save() -> void:
	var repository: SaveRepository = SaveRepository.new()
	var first_snapshot: RunSnapshot = RunSnapshot.new()
	first_snapshot.root_seed = 111
	first_snapshot.run_id = "original-run"

	_cleanup()
	var first_write: ActionResult = repository.write_run_snapshot(first_snapshot, TEST_SAVE_PATH)
	assert_true(first_write.succeeded, "Initial valid save should be written.")

	# Block the next write by occupying the temp path with a directory so temp open fails
	# AFTER a canonical valid save already exists.
	var tmp_path: String = "%s.tmp" % TEST_SAVE_PATH
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
	DirAccess.make_dir_absolute(tmp_path)

	var second_snapshot: RunSnapshot = RunSnapshot.new()
	second_snapshot.root_seed = 222
	second_snapshot.run_id = "doomed-run"
	var second_write: ActionResult = repository.write_run_snapshot(second_snapshot, TEST_SAVE_PATH)

	assert_true(second_write.is_error(), "The second write must fail because the temp path is blocked.")
	assert_equal(second_write.error_code, &"save_open_failed", "Blocked write must surface a stable structured error.")

	# The original valid save must still be present and intact (not destroyed or truncated).
	assert_true(FileAccess.file_exists(TEST_SAVE_PATH), "Original save file must be preserved after a failed write.")
	var read_back: ActionResult = repository.read_run_snapshot(TEST_SAVE_PATH)
	assert_true(read_back.succeeded, "Preserved original save must still be readable after a failed write.")
	assert_equal(read_back.metadata.get("snapshot").root_seed, 111, "Preserved save must retain the ORIGINAL data, not the failed write.")
	assert_equal(read_back.metadata.get("snapshot").run_id, "original-run", "Preserved save must retain the original run id.")

	# Cleanup the directory artifact.
	DirAccess.remove_absolute(tmp_path)
	_cleanup()


# AC1/AC4: the thin SaveManager between-level entry point delegates to SaveRepository unchanged.
func _save_manager_autosave_between_level_delegates_to_repository() -> void:
	var manager: Node = SaveManager.new()
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(321)
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {})
	var snapshot: RunSnapshot = compose_result.metadata.get("snapshot")

	# Happy-path delegation writes through the repository's default run autosave path.
	var manager_write: ActionResult = manager.autosave_between_level(snapshot)
	assert_true(manager_write.succeeded, "SaveManager.autosave_between_level should delegate a successful write: %s" % manager_write.metadata)

	# A forced failure must be returned UNCHANGED (structured error preserved, not swallowed to a bool).
	var failure_result: ActionResult = manager.autosave_between_level(snapshot, "user://__test_missing_dir__/run_autosave.json")
	assert_true(failure_result is ActionResult, "SaveManager must return the repository ActionResult, not a bool.")
	assert_true(failure_result.is_error(), "SaveManager must surface the repository failure.")
	assert_equal(failure_result.error_code, &"save_open_failed", "SaveManager must preserve the repository's structured error code.")
	assert_true(failure_result.metadata.has("path"), "SaveManager must preserve the repository's diagnostic metadata.")

	# Clean up the default autosave the happy path wrote.
	if FileAccess.file_exists(SaveRepository.DEFAULT_RUN_PATH):
		DirAccess.remove_absolute(SaveRepository.DEFAULT_RUN_PATH)
	if FileAccess.file_exists("%s.bak" % SaveRepository.DEFAULT_RUN_PATH):
		DirAccess.remove_absolute("%s.bak" % SaveRepository.DEFAULT_RUN_PATH)
	manager.free()


func _cleanup() -> void:
	for path: String in [TEST_SAVE_PATH, "%s.tmp" % TEST_SAVE_PATH, "%s.bak" % TEST_SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
