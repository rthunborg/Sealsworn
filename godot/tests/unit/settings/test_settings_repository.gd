extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")
const SettingsRepository = preload("res://scripts/settings/settings_repository.gd")
const SettingsSnapshot = preload("res://scripts/settings/settings_snapshot.gd")

const TEST_SETTINGS_PATH := "user://test_settings.json"
const TEST_RUN_PATH := "user://test_settings_run_autosave.json"

func run() -> Dictionary:
	_write_then_read_round_trips_settings()
	_first_launch_missing_file_returns_defaults_success()
	_read_malformed_file_falls_back_to_defaults_with_diagnostic()
	_read_rejects_unsupported_schema()
	_write_failure_returns_structured_error_without_mutation()
	_write_failure_preserves_existing_valid_settings()
	_settings_save_does_not_touch_the_run_autosave()
	_cleanup()
	return result()


func _write_then_read_round_trips_settings() -> void:
	_cleanup()
	var repository: SettingsRepository = SettingsRepository.new()
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	snapshot.text_scale = 1.35
	snapshot.master_volume_db = -9.0
	snapshot.audio_muted = true
	snapshot.input_scheme = "mouse_keyboard"
	snapshot.colorblind_safe = true

	var write_result: ActionResult = repository.write_settings(snapshot, TEST_SETTINGS_PATH)
	assert_true(write_result.succeeded, "SettingsRepository should write through the temp/replace path: %s" % write_result.metadata)

	var read_result: ActionResult = repository.read_settings(TEST_SETTINGS_PATH)
	assert_true(read_result.succeeded, "SettingsRepository should read a written settings file: %s" % read_result.metadata)
	if read_result.succeeded:
		var restored: SettingsSnapshot = read_result.metadata.get("snapshot")
		assert_equal(restored.text_scale, 1.35, "Repository should round-trip text_scale.")
		assert_equal(restored.master_volume_db, -9.0, "Repository should round-trip master_volume_db.")
		assert_true(restored.audio_muted, "Repository should round-trip audio_muted.")
		assert_equal(restored.input_scheme, "mouse_keyboard", "Repository should round-trip input_scheme.")
		assert_true(restored.colorblind_safe, "Repository should round-trip colorblind_safe.")


# AC1: a first launch has NO settings file; loading settings must still succeed with defaults,
# never hard-error and block the player.
func _first_launch_missing_file_returns_defaults_success() -> void:
	_cleanup()
	var repository: SettingsRepository = SettingsRepository.new()
	var read_result: ActionResult = repository.read_settings(TEST_SETTINGS_PATH)
	assert_true(read_result.succeeded, "A missing settings file must read back as a SUCCESS with defaults.")
	if read_result.succeeded:
		var snapshot: SettingsSnapshot = read_result.metadata.get("snapshot")
		assert_equal(snapshot.to_dictionary(), SettingsSnapshot.defaults().to_dictionary(), "First-launch read should yield defaults().")
		assert_true(read_result.metadata.get("first_launch", false), "First-launch read should flag first_launch in metadata.")


# Documented policy: an unreadable / malformed settings file returns defaults() (preferences are
# non-critical and must never block the player) WITH a diagnostic note in metadata.
# NOTE: this exercises the real JSON.parse_string failure path; Godot prints one expected
# "ERROR: Parse JSON failed" line to stderr — that is NOT a suite failure (same as the save tests).
func _read_malformed_file_falls_back_to_defaults_with_diagnostic() -> void:
	_cleanup()
	var file: FileAccess = FileAccess.open(TEST_SETTINGS_PATH, FileAccess.WRITE)
	file.store_string("{ this is not valid json ")
	file.flush()
	file = null

	var repository: SettingsRepository = SettingsRepository.new()
	var read_result: ActionResult = repository.read_settings(TEST_SETTINGS_PATH)
	assert_true(read_result.succeeded, "A malformed settings file should fall back to defaults (success), not block the player.")
	if read_result.succeeded:
		var snapshot: SettingsSnapshot = read_result.metadata.get("snapshot")
		assert_equal(snapshot.to_dictionary(), SettingsSnapshot.defaults().to_dictionary(), "Malformed read should yield defaults().")
		assert_equal(read_result.metadata.get("recovered_reason", ""), "settings_parse_failed", "Malformed read should carry a recovered_reason diagnostic.")


# A deliberate schema-version mismatch is the ONE case that returns a structured error
# (it indicates a settings file from an incompatible build, not mere corruption).
func _read_rejects_unsupported_schema() -> void:
	_cleanup()
	var file: FileAccess = FileAccess.open(TEST_SETTINGS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": SettingsSnapshot.SCHEMA_VERSION + 10,
		"content_version": "future"
	}))
	file.flush()
	file = null

	var repository: SettingsRepository = SettingsRepository.new()
	var read_result: ActionResult = repository.read_settings(TEST_SETTINGS_PATH)
	assert_true(read_result.is_error(), "SettingsRepository should reject an unsupported settings schema: %s" % read_result.metadata)
	assert_equal(read_result.error_code, &"unsupported_settings_schema", "SettingsRepository should return the schema error code.")


# A forced write failure returns a structured error and never mutates the source snapshot.
func _write_failure_returns_structured_error_without_mutation() -> void:
	var repository: SettingsRepository = SettingsRepository.new()
	var snapshot: SettingsSnapshot = SettingsSnapshot.defaults()
	snapshot.text_scale = 1.2
	var snapshot_before: Dictionary = snapshot.to_dictionary()

	# Writing into a non-existent directory fails at temp open (FileAccess does not create dirs).
	var failing_path: String = "user://__test_missing_settings_dir__/settings.json"
	var write_result: ActionResult = repository.write_settings(snapshot, failing_path)

	assert_true(write_result.is_error(), "A write into a missing directory must fail.")
	assert_equal(write_result.error_code, &"settings_open_failed", "Write failure must surface a stable structured error code.")
	assert_true(write_result.metadata.has("path"), "Write failure must include diagnostic path metadata.")
	assert_true(write_result.metadata.has("open_error"), "Write failure must include the open error diagnostic.")
	assert_equal(snapshot.to_dictionary(), snapshot_before, "A failed write must not mutate the source snapshot.")
	assert_false(FileAccess.file_exists("%s.tmp" % failing_path), "Failed write must not leave a temp file behind.")


# When a prior valid settings file exists and a new write fails, the original file is preserved.
func _write_failure_preserves_existing_valid_settings() -> void:
	var repository: SettingsRepository = SettingsRepository.new()
	_cleanup()
	var first: SettingsSnapshot = SettingsSnapshot.defaults()
	first.text_scale = 1.1
	first.input_scheme = "touch"
	var first_write: ActionResult = repository.write_settings(first, TEST_SETTINGS_PATH)
	assert_true(first_write.succeeded, "Initial valid settings should be written.")

	# Block the next write by occupying the temp path with a directory so temp open fails.
	var tmp_path: String = "%s.tmp" % TEST_SETTINGS_PATH
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
	DirAccess.make_dir_absolute(tmp_path)

	var second: SettingsSnapshot = SettingsSnapshot.defaults()
	second.text_scale = 2.0
	second.input_scheme = "mouse_keyboard"
	var second_write: ActionResult = repository.write_settings(second, TEST_SETTINGS_PATH)
	assert_true(second_write.is_error(), "The second write must fail because the temp path is blocked.")
	assert_equal(second_write.error_code, &"settings_open_failed", "Blocked write must surface a stable structured error.")

	assert_true(FileAccess.file_exists(TEST_SETTINGS_PATH), "Original settings file must be preserved after a failed write.")
	var read_back: ActionResult = repository.read_settings(TEST_SETTINGS_PATH)
	assert_true(read_back.succeeded, "Preserved original settings must still be readable after a failed write.")
	if read_back.succeeded:
		var snapshot: SettingsSnapshot = read_back.metadata.get("snapshot")
		assert_equal(snapshot.text_scale, 1.1, "Preserved settings must retain the ORIGINAL data, not the failed write.")
		assert_equal(snapshot.input_scheme, "touch", "Preserved settings must retain the original input_scheme.")

	DirAccess.remove_absolute(tmp_path)
	_cleanup()


# CRITICAL AC1 cross-file isolation: a settings save/restore MUST NOT read, write, or mutate the
# run autosave or any run/tactical/RNG state. Write a run autosave, then write+read settings, then
# re-read the run autosave and assert it is byte-for-byte and snapshot-equal unchanged.
func _settings_save_does_not_touch_the_run_autosave() -> void:
	_cleanup()
	var save_repository: SaveRepository = SaveRepository.new()
	var board: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	var streams: RngStreamSet = RngStreamSet.new(4242)
	streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"system": "combat"})
	var compose_result: ActionResult = RunSnapshot.from_between_level(board, streams, {"current_route_node_id": "n7"})
	var run_snapshot: RunSnapshot = compose_result.metadata.get("snapshot")
	var run_write: ActionResult = save_repository.write_run_snapshot(run_snapshot, TEST_RUN_PATH)
	assert_true(run_write.succeeded, "Run autosave fixture should be written: %s" % run_write.metadata)

	# Capture the run autosave bytes and parsed snapshot BEFORE any settings activity.
	var run_bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(TEST_RUN_PATH)
	var run_read_before: ActionResult = save_repository.read_run_snapshot(TEST_RUN_PATH)
	assert_true(run_read_before.succeeded, "Run autosave should read back before settings activity.")
	var run_dict_before: Dictionary = (run_read_before.metadata.get("snapshot") as RunSnapshot).to_dictionary()

	# Full settings save + read cycle through its OWN file.
	var settings_repository: SettingsRepository = SettingsRepository.new()
	var settings: SettingsSnapshot = SettingsSnapshot.defaults()
	settings.text_scale = 1.6
	settings.master_volume_db = -3.0
	settings.audio_muted = true
	settings.input_scheme = "touch"
	var settings_write: ActionResult = settings_repository.write_settings(settings, TEST_SETTINGS_PATH)
	assert_true(settings_write.succeeded, "Settings write should succeed independently: %s" % settings_write.metadata)
	var settings_read: ActionResult = settings_repository.read_settings(TEST_SETTINGS_PATH)
	assert_true(settings_read.succeeded, "Settings read should succeed independently.")

	# The run autosave must be byte-identical AND snapshot-identical after all settings activity.
	var run_bytes_after: PackedByteArray = FileAccess.get_file_as_bytes(TEST_RUN_PATH)
	assert_equal(run_bytes_after, run_bytes_before, "Settings activity must leave the run autosave byte-for-byte unchanged.")
	var run_read_after: ActionResult = save_repository.read_run_snapshot(TEST_RUN_PATH)
	assert_true(run_read_after.succeeded, "Run autosave should still read back after settings activity.")
	var run_dict_after: Dictionary = (run_read_after.metadata.get("snapshot") as RunSnapshot).to_dictionary()
	assert_equal(run_dict_after, run_dict_before, "Settings activity must leave the run autosave snapshot unchanged.")

	# The default run autosave path must never be created by settings (settings uses its own file).
	assert_false(FileAccess.file_exists(SaveRepository.DEFAULT_RUN_PATH), "Settings must NOT create the default run autosave file.")
	# And the settings repository must not have written to the run autosave path.
	assert_false(FileAccess.file_exists("%s.tmp" % TEST_RUN_PATH), "Settings must not leave a run-autosave temp artifact.")


func _cleanup() -> void:
	var paths: Array[String] = [
		TEST_SETTINGS_PATH, "%s.tmp" % TEST_SETTINGS_PATH, "%s.bak" % TEST_SETTINGS_PATH,
		TEST_RUN_PATH, "%s.tmp" % TEST_RUN_PATH, "%s.bak" % TEST_RUN_PATH
	]
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
