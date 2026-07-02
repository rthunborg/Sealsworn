extends "res://tests/unit/test_case.gd"

# Story 8.3 Task 2 (AC1, AC5): the ProfileRepository — atomic-write + structured-error, mirroring
# test_save_repository.gd. Write→read round-trip; a profile-not-found read (fresh-profile recovery); a save failure
# returns a structured error (AC5); a malformed-JSON read; an unsupported-schema read (the migration reject); a failed
# write preserves a prior valid profile.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")

const TEST_PROFILE_PATH := "user://test_profile.json"

func run() -> Dictionary:
	_write_then_read_round_trips_profile()
	_read_of_absent_file_returns_profile_not_found()
	_write_failure_returns_structured_error_without_mutation()
	_write_failure_preserves_existing_valid_profile()
	_read_of_malformed_json_returns_profile_parse_failed()
	_read_of_unsupported_schema_surfaces_the_migration_reject()
	_profile_uses_a_separate_path_from_the_run_autosave()
	_cleanup()
	return result()


func _write_then_read_round_trips_profile() -> void:
	_cleanup()

	var repository: ProfileRepository = ProfileRepository.new()
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.oath_shards = 15
	snapshot.profile_id = "player-one"
	snapshot.last_awarded_run_seed = "7777"

	var write_result: ActionResult = repository.write_profile(snapshot, TEST_PROFILE_PATH)
	var read_result: ActionResult = repository.read_profile(TEST_PROFILE_PATH)

	assert_true(write_result.succeeded, "ProfileRepository should write through the temp/replace path: %s" % write_result.metadata)
	assert_true(read_result.succeeded, "ProfileRepository should read a written profile: %s" % read_result.metadata)
	if read_result.succeeded:
		var restored: ProfileSnapshot = read_result.metadata.get("snapshot")
		assert_equal(restored.oath_shards, 15, "ProfileRepository should round-trip the oath_shards total.")
		assert_equal(restored.profile_id, "player-one", "ProfileRepository should round-trip the profile id.")
		assert_equal(restored.last_awarded_run_seed, "7777", "ProfileRepository should round-trip the idempotency marker.")


func _read_of_absent_file_returns_profile_not_found() -> void:
	_cleanup()

	var repository: ProfileRepository = ProfileRepository.new()
	var read_result: ActionResult = repository.read_profile(TEST_PROFILE_PATH)

	assert_true(read_result.is_error(), "A read of a non-existent profile must fail (the caller starts fresh).")
	assert_equal(read_result.error_code, &"profile_not_found", "A missing profile must surface the stable profile_not_found code (AC5 fresh-profile recovery).")
	assert_true(read_result.metadata.has("path"), "profile_not_found must include the diagnostic path.")

	# AC5 recovery: the caller starts a FRESH profile on profile_not_found.
	var fresh: ProfileSnapshot = ProfileSnapshot.fresh()
	assert_equal(fresh.oath_shards, 0, "The fresh-profile recovery starts a brand-new player with 0 Oath Shards.")


# AC5: a forced write failure returns a structured error and never mutates the in-memory snapshot.
func _write_failure_returns_structured_error_without_mutation() -> void:
	var repository: ProfileRepository = ProfileRepository.new()
	var snapshot: ProfileSnapshot = ProfileSnapshot.new()
	snapshot.oath_shards = 8

	var snapshot_before: Dictionary = snapshot.to_dictionary()

	# Writing into a non-existent directory fails at temp open (FileAccess does not create dirs).
	var failing_path: String = "user://__test_missing_profile_dir__/profile.json"
	var write_result: ActionResult = repository.write_profile(snapshot, failing_path)

	assert_true(write_result.is_error(), "A write into a missing directory must fail.")
	assert_equal(write_result.error_code, &"profile_save_open_failed", "Write failure must surface a stable structured error code (AC5).")
	assert_true(write_result.metadata.has("path"), "Write failure must include diagnostic path metadata.")
	assert_true(write_result.metadata.has("open_error"), "Write failure must include the open error diagnostic.")

	# Saving is a read of the snapshot: nothing may be mutated by a failed write.
	assert_equal(snapshot.to_dictionary(), snapshot_before, "A failed write must not mutate the in-memory ProfileSnapshot.")
	assert_false(FileAccess.file_exists("%s.tmp" % failing_path), "A failed write must not leave a temp file behind.")


# AC5: when a prior valid profile exists and a new write fails, the original file is preserved (atomic write rollback).
func _write_failure_preserves_existing_valid_profile() -> void:
	var repository: ProfileRepository = ProfileRepository.new()
	var first_snapshot: ProfileSnapshot = ProfileSnapshot.new()
	first_snapshot.oath_shards = 3
	first_snapshot.profile_id = "original-profile"

	_cleanup()
	var first_write: ActionResult = repository.write_profile(first_snapshot, TEST_PROFILE_PATH)
	assert_true(first_write.succeeded, "The initial valid profile should be written.")

	# Block the next write by occupying the temp path with a directory so temp open fails AFTER a canonical valid
	# profile already exists.
	var tmp_path: String = "%s.tmp" % TEST_PROFILE_PATH
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)
	DirAccess.make_dir_absolute(tmp_path)

	var second_snapshot: ProfileSnapshot = ProfileSnapshot.new()
	second_snapshot.oath_shards = 999
	second_snapshot.profile_id = "doomed-profile"
	var second_write: ActionResult = repository.write_profile(second_snapshot, TEST_PROFILE_PATH)

	assert_true(second_write.is_error(), "The second write must fail because the temp path is blocked.")
	assert_equal(second_write.error_code, &"profile_save_open_failed", "A blocked write must surface a stable structured error.")

	# The original valid profile must still be present and intact (not destroyed or truncated).
	assert_true(FileAccess.file_exists(TEST_PROFILE_PATH), "The original profile must be preserved after a failed write.")
	var read_back: ActionResult = repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_back.succeeded, "The preserved original profile must still be readable after a failed write.")
	assert_equal(read_back.metadata.get("snapshot").oath_shards, 3, "The preserved profile must retain the ORIGINAL total, not the failed write.")
	assert_equal(read_back.metadata.get("snapshot").profile_id, "original-profile", "The preserved profile must retain the original id.")

	DirAccess.remove_absolute(tmp_path)
	_cleanup()


func _read_of_malformed_json_returns_profile_parse_failed() -> void:
	_cleanup()

	var file: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string("{ this is not valid json ]")
	file.flush()
	file = null

	var repository: ProfileRepository = ProfileRepository.new()
	var read_result: ActionResult = repository.read_profile(TEST_PROFILE_PATH)

	assert_true(read_result.is_error(), "A read of a malformed-JSON profile must fail.")
	assert_equal(read_result.error_code, &"profile_parse_failed", "A malformed-JSON profile must surface profile_parse_failed.")


func _read_of_unsupported_schema_surfaces_the_migration_reject() -> void:
	_cleanup()

	var file: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": ProfileSnapshot.SCHEMA_VERSION + 10,
		"content_version": "future"
	}))
	file.flush()
	file = null

	var repository: ProfileRepository = ProfileRepository.new()
	var read_result: ActionResult = repository.read_profile(TEST_PROFILE_PATH)

	assert_true(read_result.is_error(), "A read of an unsupported-schema profile must fail (the migration reject).")
	assert_equal(read_result.error_code, &"unsupported_profile_schema", "An unsupported-schema profile must surface unsupported_profile_schema through ProfileSnapshot.parse.")


func _profile_uses_a_separate_path_from_the_run_autosave() -> void:
	# AC2 separability: the profile is its OWN save file, NOT the run autosave. The default path must be distinct.
	assert_false(ProfileRepository.DEFAULT_PROFILE_PATH == "user://run_autosave.json", "The profile must NOT share the run autosave path.")
	assert_equal(ProfileRepository.DEFAULT_PROFILE_PATH, "user://profile.json", "The profile lives at its own user://profile.json path.")


func _cleanup() -> void:
	for path: String in [TEST_PROFILE_PATH, "%s.tmp" % TEST_PROFILE_PATH, "%s.bak" % TEST_PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
