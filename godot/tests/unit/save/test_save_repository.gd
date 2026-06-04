extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")

const TEST_SAVE_PATH := "user://test_run_autosave.json"

func run() -> Dictionary:
	_write_then_read_round_trips_snapshot()
	_read_rejects_unsupported_schema()
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


func _cleanup() -> void:
	for path: String in [TEST_SAVE_PATH, "%s.tmp" % TEST_SAVE_PATH, "%s.bak" % TEST_SAVE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
