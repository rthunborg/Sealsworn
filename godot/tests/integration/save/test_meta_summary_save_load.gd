extends "res://tests/unit/test_case.gd"

# Story 8.7 (AC1/AC2/AC3) — the COMPREHENSIVE cross-cutting META / PROFILE / SUMMARY SAVE-LOAD + MIGRATION TEST MATRIX,
# the Epic-8 CAPSTONE + SAFETY NET. Every production surface this exercises ALREADY SHIPPED (8.1-8.6, all DONE); 8.7
# authors NO new production truth — it PROVES the whole persistence surface survives a real save -> app-restart -> load
# round-trip, that migration is honest (a version reject + a lenient forward-compat parse, both grant NO phantom
# progress), and that the four-case run-end grant/deny matrix ({eligible, manual-seed} x {completion, death}) holds
# end-to-end through the save layer.
#
# WHY AN INTEGRATION MATRIX (not more per-surface unit cases): each of 8.3/8.4/8.5 ships its OWN per-command round-trip +
# no-migration proof; 8.7's value is the CROSS-CUTTING composition ("a full run's meta state survives a restart") that
# ties the piecemeal coverage into one proof. It sits alongside test_between_level_save.gd (the integration save-load
# home) and mirrors its idiom: a REAL JSON round-trip THROUGH the repositories (JSON.stringify -> JSON.parse_string via
# ProfileRepository / SaveRepository write/read of real user:// files), a TEST path (user://test_*.json, NOT the real
# profile/run-autosave), cleanup first + last, ZERO RNG (a save-load/migration matrix is deterministic), and ZERO
# production-file mutation. It fills the GAPS + proves the COMPOSITION; it does NOT re-assert the green per-surface tests.
#
#   AC1 — a fully-populated ProfileSnapshot (EVERY 8.3/8.4/8.5 field) survives write -> restart -> read byte-identical,
#         AND the profile save (user://profile.json) is provably SEPARATE from the run autosave (user://run_autosave
#         .json) — writing/reading one never touches the other.
#   AC2 — the MIGRATION MATRIX: a current-schema (SCHEMA_VERSION == 1) round-trip; an UNSUPPORTED schema (!= 1) read
#         fails with the stable unsupported_profile_schema code + version metadata (never a crash / partial profile); a
#         LEGACY/partial dict parses LENIENTLY with clean defaults and grants NO unintended progress.
#   AC3 — the GRANT-vs-DENY MATRIX across the four run-end cases, each GRANTED case saved + reloaded with the granted
#         state intact + each DENIED case leaving the profile byte-identical; the three run-end markers are order-
#         independent; NO scene node is ever serialized (a structural no-Object guard on the snapshot dicts).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AwardMetaProgressCommand = preload("res://scripts/core/commands/award_meta_progress_command.gd")
const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const HeroSelectViewModel = preload("res://scripts/ui/view_models/hero_select_view_model.gd")
const MergeRunDiscoveriesCommand = preload("res://scripts/core/commands/merge_run_discoveries_command.gd")
const MetaAwardRules = preload("res://scripts/save/meta_award_rules.gd")
const MetaSpendRules = preload("res://scripts/save/meta_spend_rules.gd")
const OutpostViewModel = preload("res://scripts/ui/view_models/outpost_view_model.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RecordFirstDeathCommand = preload("res://scripts/core/commands/record_first_death_command.gd")
const RecordFirstVictoryCommand = preload("res://scripts/core/commands/record_first_victory_command.gd")
const SpendOathShardsCommand = preload("res://scripts/core/commands/spend_oath_shards_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")
const UnlockProgressRules = preload("res://scripts/save/unlock_progress_rules.gd")

# TEST save paths (NOT the real user://profile.json / user://run_autosave.json). The profile matrix + the run autosave
# separability write to their own distinct test files, each cleaned up.
const TEST_PROFILE_PATH := "user://test_meta_summary_profile.json"
const TEST_RUN_PATH := "user://test_meta_summary_run_autosave.json"

# A full-int64 seed near the signed-int64 ceiling — the decimal-string encoding is the ONLY thing that keeps it lossless
# across a JSON round-trip (JSON doubles truncate beyond 2^53). AC1 asserts the exact string survives.
const FULL_INT64_SEED := "9223372036854775000"

func run() -> Dictionary:
	_cleanup()
	# --- AC1: the comprehensive profile save-load round-trip -----------------------------------------
	_fully_populated_profile_survives_write_restart_read()
	_profile_save_is_separate_from_the_run_autosave()
	_reloaded_profile_drives_the_outpost_identically()
	# --- AC2: the migration matrix -------------------------------------------------------------------
	_current_schema_round_trips_without_migration()
	_unsupported_schema_rejects_native_and_through_the_repository()
	_legacy_partial_profile_parses_leniently_through_a_real_json_file()
	_migration_grants_no_unintended_progress()
	_schema_version_stays_one()
	# --- AC3: the grant/deny matrix across the four run-end cases -------------------------------------
	_eligible_completed_run_awards_and_merges_and_is_not_a_first_death()
	_eligible_death_awards_zero_merges_and_latches_first_death()
	_manual_seed_completed_run_denies_award_and_merge()
	_manual_seed_death_denies_award_and_merge_but_still_latches_first_death()
	_three_run_end_markers_are_order_independent()
	# --- Story 11.6: the spend interleaves with the run-end markers + round-trips (AC3 caller-ordering) ---
	_spend_interleaved_with_run_end_markers_leaves_each_independent()
	_spend_then_persist_round_trips_the_applied_unlock()
	_snapshots_serialize_no_scene_node()
	_cleanup()
	return result()


# ================================================================================================
# AC1 — a saved profile restores every cross-run field; the run autosave stays SEPARATE
# ================================================================================================

func _fully_populated_profile_survives_write_restart_read() -> void:
	# AC1 half 1: build a ProfileSnapshot exercising EVERY field the 8.3/8.4/8.5 systems can set, persist it through the
	# repository, SIMULATE AN APP RESTART (discard the in-memory objects + construct a FRESH repository), read it back, and
	# assert every field byte-identical after a REAL JSON file round-trip. This is the "a full run's meta state survives a
	# restart" proof the per-surface tests (each populating a subset) cannot make.
	_cleanup()
	var profile: ProfileSnapshot = _fully_populated_profile()

	# Snapshot the exact dict BEFORE persisting (the byte-identity yardstick).
	var expected: Dictionary = profile.to_dictionary()

	var write_repository: ProfileRepository = ProfileRepository.new()
	var write_result: ActionResult = write_repository.write_profile(profile, TEST_PROFILE_PATH)
	assert_true(write_result.succeeded, "A fully-populated profile should persist through the repository: %s" % write_result.metadata)

	# Simulate an app restart: discard the writer + the in-memory profile, construct a FRESH repository, read from disk.
	write_repository = null
	profile = null
	var read_repository: ProfileRepository = ProfileRepository.new()
	var read_result: ActionResult = read_repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.succeeded, "A fully-populated profile should read back after a simulated restart: %s" % read_result.metadata)
	var restored: ProfileSnapshot = read_result.metadata.get("snapshot")

	# The WHOLE profile round-trips faithfully across the real JSON file (this alone proves every field survives). The
	# comparison is int-coercion aware: JSON has no int/float distinction, so a class_mastery int VALUE decodes as a float
	# (Godot's Dictionary == is type-strict on values — {"warrior": 3} != {"warrior": 3.0} even though 3 == 3.0), which is
	# an EXPECTED encoding artifact, not a data loss. _profile_round_trip_matches normalizes those int values before
	# comparing so the assertion is faithful without a false failure.
	assert_true(_profile_round_trip_matches(restored, expected), "A fully-populated profile must round-trip faithfully after a simulated restart (int-coercion aware). Restored: %s vs expected %s" % [restored.to_dictionary(), expected])

	# Per-field documentation of the fields AC1 names explicitly:
	assert_equal(restored.oath_shards, 12, "oath_shards (a non-trivial awarded total) must restore exactly.")
	# The int64 seed marker restores LOSSLESSLY only because it is decimal-string encoded (assert the exact string — a JSON
	# double would have truncated it beyond 2^53).
	assert_equal(restored.last_awarded_run_seed, FULL_INT64_SEED, "last_awarded_run_seed (a full-int64 decimal string) must restore losslessly (no JSON-double truncation).")
	assert_equal(restored.echoes, ["echo_of_salt", "echo_of_tide"] as Array[String], "echoes must restore in order.")
	# Seal Fragments live INSIDE unlock_progress (the 8.4 home decision — NOT a top-level key).
	assert_equal((restored.unlock_progress.get(UnlockProgressRules.SEAL_FRAGMENTS_KEY) as Array), ["seal_a", "seal_b"], "unlock_progress.seal_fragments (the unique-id set) must restore verbatim.")
	assert_true(bool(restored.unlock_progress.get("seal_gate_1_unlocked")), "unlock_progress threshold flag (seal_gate_1_unlocked) must restore.")
	# The dedicated merge marker rides inside unlock_progress too.
	assert_equal(String(restored.unlock_progress.get(MergeRunDiscoveriesCommand.LAST_MERGED_RUN_SEED_KEY)), FULL_INT64_SEED, "unlock_progress._last_merged_run_seed (the merge marker) must restore verbatim.")
	# class_mastery is a SEPARATE top-level field; a JSON int decodes as a float — coerce with int(...) (the
	# test_profile_snapshot.gd precedent).
	assert_equal(int(restored.class_mastery.get("warrior")), 3, "class_mastery (per-class count) must restore (int-coerced — JSON int -> float).")
	assert_true(restored.first_death_recorded, "first_death_recorded (the set latch) must restore true.")
	assert_equal(restored.schema_version, ProfileSnapshot.SCHEMA_VERSION, "schema_version must stay 1 across the round-trip.")
	assert_equal(restored.content_version, "mvp-0", "content_version must restore.")
	assert_equal(restored.profile_id, "player-one", "profile_id must restore.")
	_cleanup()


func _profile_save_is_separate_from_the_run_autosave() -> void:
	# AC1 half 2: the profile is its OWN save file (user://profile.json) at a DISTINCT path from the run autosave
	# (user://run_autosave.json). Prove separability STRUCTURALLY (the default paths differ) AND behaviorally (writing/
	# reading one leaves the OTHER's file byte-identical — no per-surface test writes BOTH together). The profile OUTLIVES
	# a run; the run autosave is run-scoped.
	_cleanup()

	# The default paths differ (the profile is NOT the run autosave).
	assert_false(ProfileRepository.DEFAULT_PROFILE_PATH == SaveRepository.DEFAULT_RUN_PATH, "The profile must NOT share the run-autosave default path.")
	assert_equal(ProfileRepository.DEFAULT_PROFILE_PATH, "user://profile.json", "The profile lives at its own user://profile.json.")
	assert_equal(SaveRepository.DEFAULT_RUN_PATH, "user://run_autosave.json", "The run autosave lives at its own user://run_autosave.json.")

	# Write BOTH a profile AND a run autosave to their respective TEST paths.
	var profile: ProfileSnapshot = _fully_populated_profile()
	var profile_repository: ProfileRepository = ProfileRepository.new()
	assert_true(profile_repository.write_profile(profile, TEST_PROFILE_PATH).succeeded, "The profile should write to its own test path.")

	var run: RunState = _completed_run(2, 4242, false)
	var streams: RngStreamSet = RngStreamSet.new(4242)  # root_seed MUST match the run (from_route_position cross-checks).
	var compose_result: ActionResult = RunSnapshot.from_route_position(run, streams)
	assert_true(compose_result.succeeded, "A board-free route-position run autosave should compose: %s" % compose_result.metadata)
	var run_snapshot: RunSnapshot = compose_result.metadata.get("snapshot")
	var save_repository: SaveRepository = SaveRepository.new()
	assert_true(save_repository.write_run_snapshot(run_snapshot, TEST_RUN_PATH).succeeded, "The run autosave should write to its own test path.")

	# Capture each file's raw bytes AFTER both are written.
	var profile_bytes_after_both: String = _read_raw(TEST_PROFILE_PATH)
	var run_bytes_after_both: String = _read_raw(TEST_RUN_PATH)

	# Reading each back restores its OWN data.
	var profile_read: ActionResult = profile_repository.read_profile(TEST_PROFILE_PATH)
	assert_true(profile_read.succeeded, "The profile must read back its own data.")
	assert_equal((profile_read.metadata.get("snapshot") as ProfileSnapshot).oath_shards, 12, "The profile file restores the profile's oath_shards.")
	var run_read: ActionResult = save_repository.read_run_snapshot(TEST_RUN_PATH)
	assert_true(run_read.succeeded, "The run autosave must read back its own data.")
	assert_equal((run_read.metadata.get("snapshot") as RunSnapshot).root_seed, 4242, "The run-autosave file restores the run's root_seed.")

	# No cross-contamination: reading either did NOT touch the other's bytes.
	assert_equal(_read_raw(TEST_PROFILE_PATH), profile_bytes_after_both, "Reading the run autosave must NOT change the profile file.")
	assert_equal(_read_raw(TEST_RUN_PATH), run_bytes_after_both, "Reading the profile must NOT change the run-autosave file.")

	# A NEW descent (a FRESH run autosave) does NOT overwrite the accumulated profile: re-write the run autosave with a
	# DIFFERENT run and assert the profile file is byte-identical (the profile outlives the run autosave).
	var other_run: RunState = _completed_run(3, 9999, false)
	var other_streams: RngStreamSet = RngStreamSet.new(9999)
	var other_compose: ActionResult = RunSnapshot.from_route_position(other_run, other_streams)
	assert_true(other_compose.succeeded, "A second run autosave should compose.")
	assert_true(save_repository.write_run_snapshot(other_compose.metadata.get("snapshot"), TEST_RUN_PATH).succeeded, "A new descent's autosave should overwrite the run-autosave file.")
	assert_equal(_read_raw(TEST_PROFILE_PATH), profile_bytes_after_both, "A new descent's run autosave must NOT touch the accumulated profile file (the profile outlives the run).")
	# The run-autosave file DID change (it is run-scoped).
	assert_equal((save_repository.read_run_snapshot(TEST_RUN_PATH).metadata.get("snapshot") as RunSnapshot).root_seed, 9999, "The run autosave is run-scoped — a new descent replaces it.")
	# The profile still restores its full accumulated total (untouched by two run-autosave writes).
	assert_equal((profile_repository.read_profile(TEST_PROFILE_PATH).metadata.get("snapshot") as ProfileSnapshot).oath_shards, 12, "The profile still restores its accumulated total after the run autosave churned.")
	_cleanup()


func _reloaded_profile_drives_the_outpost_identically() -> void:
	# AC1 capstone (optional but a natural cross-cut): an OutpostViewModel (8.6) built from the RELOADED profile projects
	# the SAME profile-derived readout (oath_shards / echoes / unlock_progress / class_mastery / first_death_recorded) as
	# one built from the PRE-SAVE profile. This proves the reloaded profile drives the outpost surface identically — the
	# round-trip carries all the way into the read projection. It does NOT re-test the full OutpostViewModel surface
	# (8.6's test_outpost_view_model.gd pins that); it asserts ONLY the profile-derived fields survive into the outpost.
	_cleanup()
	var pre_save: ProfileSnapshot = _fully_populated_profile()
	var class_repository: ClassRepository = ClassRepository.create_baseline_repository()

	var repository: ProfileRepository = ProfileRepository.new()
	assert_true(repository.write_profile(pre_save, TEST_PROFILE_PATH).succeeded, "The profile should persist for the outpost capstone.")
	var read_result: ActionResult = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.succeeded, "The profile should reload for the outpost capstone.")
	var reloaded: ProfileSnapshot = read_result.metadata.get("snapshot")

	# Story 11.5: the constructor gained a first_victory_beat arg (position 4, before class_repository) — pass null for it
	# (no reveal beat needed for this profile-round-trip assertion) so class_repository lands in its (now 5th) slot.
	var outpost_before: OutpostViewModel = OutpostViewModel.new(pre_save, null, null, null, class_repository)
	var outpost_after: OutpostViewModel = OutpostViewModel.new(reloaded, null, null, null, class_repository)

	# The profile-derived readout is identical pre-save vs reloaded (class_mastery int-normalized — JSON int -> float; the
	# other fields round-trip as their JSON-native type with no nested int value).
	assert_equal(outpost_after.oath_shards, outpost_before.oath_shards, "The reloaded profile drives the SAME outpost oath_shards.")
	assert_equal(outpost_after.echoes, outpost_before.echoes, "The reloaded profile drives the SAME outpost echoes.")
	assert_equal(outpost_after.unlock_progress, outpost_before.unlock_progress, "The reloaded profile drives the SAME outpost unlock_progress.")
	assert_equal(_int_normalized_counts(outpost_after.class_mastery), _int_normalized_counts(outpost_before.class_mastery), "The reloaded profile drives the SAME outpost class_mastery (int-normalized).")
	assert_equal(outpost_after.first_death_recorded, outpost_before.first_death_recorded, "The reloaded profile drives the SAME outpost first_death_recorded.")
	assert_true(outpost_after.has_profile, "The reloaded profile is a REAL profile (has_profile == true).")
	# Concretely: the reloaded outpost shows the full accumulated meta (not a fresh 0-shard surface).
	assert_equal(outpost_after.oath_shards, 12, "The reloaded outpost shows the accumulated Oath-Shard total.")
	assert_true(outpost_after.first_death_recorded, "The reloaded outpost shows the set first-death latch.")
	_cleanup()


# ================================================================================================
# AC2 — the migration matrix (a supported older snapshot migrates OR fails with a clear version result)
# ================================================================================================

func _current_schema_round_trips_without_migration() -> void:
	# The SHIPPED case: a schema_version == 1 snapshot writes + reads back at the SAME version (NO migration needed). This
	# is the "current schema" leg of the matrix — parse succeeds, schema_version unchanged.
	_cleanup()
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 4
	assert_equal(profile.schema_version, 1, "Setup: the current schema is 1.")

	var repository: ProfileRepository = ProfileRepository.new()
	assert_true(repository.write_profile(profile, TEST_PROFILE_PATH).succeeded, "A current-schema profile should write.")
	var read_result: ActionResult = repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.succeeded, "A current-schema profile should read back with NO migration.")
	assert_equal((read_result.metadata.get("snapshot") as ProfileSnapshot).schema_version, 1, "The schema version must be unchanged (no migration on the current schema).")
	_cleanup()


func _unsupported_schema_rejects_native_and_through_the_repository() -> void:
	# The MIGRATION-REJECT path (AC2 "fail with a clear unsupported-version result"): a snapshot dict with schema_version
	# != 1 rejects with the stable unsupported_profile_schema code + {expected, actual} metadata — NEVER a crash, NEVER a
	# partial/false profile. Proven BOTH natively (ProfileSnapshot.parse) AND through the repository (a real user:// file).
	_cleanup()

	# (a) NATIVE parse of a bumped-version dict (a hypothetical FUTURE schema — we construct the dict, we do NOT add a v2
	# schema to production).
	var future_version: int = ProfileSnapshot.SCHEMA_VERSION + 10
	var native: ActionResult = ProfileSnapshot.parse({
		"schema_version": future_version,
		"content_version": "future",
		"oath_shards": 999
	})
	assert_true(native.is_error(), "A bumped-version dict must reject natively (the migration reject).")
	assert_equal(native.error_code, &"unsupported_profile_schema", "A bumped-version dict must reject with the stable unsupported_profile_schema code.")
	assert_equal(native.metadata.get("expected_schema_version"), ProfileSnapshot.SCHEMA_VERSION, "The reject must carry the expected schema version.")
	assert_equal(native.metadata.get("actual_schema_version"), future_version, "The reject must carry the actual (unsupported) schema version.")
	# NO profile is produced (no partial/false profile leaks out of the reject).
	assert_false(native.metadata.has("snapshot"), "An unsupported-schema reject must yield NO profile snapshot.")

	# (b) THROUGH the repository: write a JSON file with an unsupported schema, read it back — the repository surfaces the
	# SAME code (no crash, no partial profile). A schema_version == 2 file (the nearest future bump).
	var file: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": 2,
		"content_version": "future",
		"oath_shards": 999,
		"first_death_recorded": true
	}))
	file.flush()
	file = null
	var repo_result: ActionResult = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true(repo_result.is_error(), "An unsupported-schema file must reject through the repository (no crash, no partial profile).")
	assert_equal(repo_result.error_code, &"unsupported_profile_schema", "The repository must surface unsupported_profile_schema for a bad-schema file.")
	assert_equal(repo_result.metadata.get("actual_schema_version"), 2, "The repository reject must carry the actual unsupported version.")
	assert_false(repo_result.metadata.has("snapshot"), "An unsupported-schema file read must yield NO profile snapshot.")
	_cleanup()


func _legacy_partial_profile_parses_leniently_through_a_real_json_file() -> void:
	# The LEGACY/partial LENIENT-parse path (AC2 "an older SUPPORTED snapshot migrates"): a schema_version == 1 dict MISSING
	# the 8.4/8.5 fields (a pre-8.4/pre-8.5 profile) parses cleanly with defaults — a legacy profile still loads
	# forward-compatibly at v1 with empty new homes. Proven THROUGH a real JSON file + the repository (extending the
	# unit-level native _partial_legacy_dict_parses_leniently into the repository/JSON narrative).
	_cleanup()
	# A legacy profile predating the 8.4/8.5 homes: ONLY the header + oath_shards + the run marker (no class_mastery, no
	# echoes, no unlock_progress, no first_death_recorded).
	var file: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"schema_version": 1,
		"content_version": "mvp-0",
		"profile_id": "legacy-player",
		"oath_shards": 5,
		"last_awarded_run_seed": "1234"
	}))
	file.flush()
	file = null

	var read_result: ActionResult = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.succeeded, "A legacy partial profile must parse leniently at v1 (forward-compat).")
	var restored: ProfileSnapshot = read_result.metadata.get("snapshot")
	# The fields it HAD survive.
	assert_equal(restored.oath_shards, 5, "The legacy profile's oath_shards must survive.")
	assert_equal(restored.last_awarded_run_seed, "1234", "The legacy profile's run marker must survive.")
	assert_equal(restored.profile_id, "legacy-player", "The legacy profile's id must survive.")
	# The 8.4/8.5 homes it LACKED default cleanly (empty/false — NOT a coerced foreign shape).
	assert_equal(restored.class_mastery, {}, "A legacy profile's missing class_mastery defaults empty.")
	assert_equal(restored.echoes, [] as Array[String], "A legacy profile's missing echoes defaults empty.")
	assert_equal(restored.unlock_progress, {}, "A legacy profile's missing unlock_progress defaults empty.")
	assert_false(restored.first_death_recorded, "A legacy profile's missing first_death_recorded defaults false.")
	# It still round-trips forward at v1 (a re-save + re-read is stable — the legacy profile is now a full v1 profile).
	assert_true(ProfileRepository.new().write_profile(restored, TEST_PROFILE_PATH).succeeded, "The leniently-parsed legacy profile must re-save at v1.")
	var reread: ActionResult = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true(reread.succeeded, "The re-saved legacy profile must re-read at v1.")
	assert_equal((reread.metadata.get("snapshot") as ProfileSnapshot).schema_version, 1, "The forward-compat parse stays at SCHEMA_VERSION == 1 (no bump).")
	_cleanup()


func _migration_grants_no_unintended_progress() -> void:
	# The LOAD-BEARING SAFETY CLAUSE (AC2 "migration does not grant unintended progress"): NEITHER a leniently-parsed
	# legacy profile NOR a rejected unsupported-schema read grants any phantom progress. The migration/lenient-parse layer
	# can ONLY lose or zero fields, NEVER invent progress.
	_cleanup()

	# (a) A leniently-parsed EMPTY-ish v1 dict grants clean-zero defaults (a missing oath_shards -> 0, NOT a phantom award;
	# a missing first_death_recorded -> false, NOT a spuriously-set latch; a missing seal_fragments -> empty, NOT a phantom
	# unlock).
	var minimal: ActionResult = ProfileSnapshot.parse({"schema_version": 1})
	assert_true(minimal.succeeded, "A minimal v1 dict must parse leniently.")
	var minimal_profile: ProfileSnapshot = minimal.metadata.get("snapshot")
	assert_equal(minimal_profile.oath_shards, 0, "A missing oath_shards defaults to 0 (no phantom award).")
	assert_equal(minimal_profile.last_awarded_run_seed, "", "A missing run marker defaults to '' (never awarded).")
	assert_false(minimal_profile.first_death_recorded, "A missing first_death_recorded defaults to false (no spurious latch).")
	assert_equal(minimal_profile.class_mastery, {}, "A missing class_mastery defaults empty (no phantom mastery).")
	assert_equal(minimal_profile.echoes, [] as Array[String], "A missing echoes defaults empty (no phantom Echo).")
	assert_equal(minimal_profile.unlock_progress, {}, "A missing unlock_progress defaults empty (no phantom unlock).")

	# (b) GARBAGE/NEGATIVE values clamp/default — a NEGATIVE oath_shards floors to 0 (never a negative/inflated total); a
	# garbage unlock_progress/class_mastery defaults empty (never a coerced foreign shape).
	var garbage: ActionResult = ProfileSnapshot.parse({
		"schema_version": 1,
		"oath_shards": -50,
		"class_mastery": "not-a-dict",
		"echoes": "not-an-array",
		"unlock_progress": 12345,
		"first_death_recorded": false
	})
	assert_true(garbage.succeeded, "A garbage-valued v1 dict must still parse leniently.")
	var garbage_profile: ProfileSnapshot = garbage.metadata.get("snapshot")
	assert_equal(garbage_profile.oath_shards, 0, "A NEGATIVE oath_shards clamps to 0 (never negative/inflated).")
	assert_equal(garbage_profile.class_mastery, {}, "A garbage class_mastery defaults empty (never a coerced foreign shape).")
	assert_equal(garbage_profile.echoes, [] as Array[String], "A garbage echoes defaults empty.")
	assert_equal(garbage_profile.unlock_progress, {}, "A garbage unlock_progress defaults empty (never a coerced foreign shape).")

	# (c) A REJECTED unsupported-schema read yields NO profile at all — the caller falls back to ProfileSnapshot.fresh()
	# (a brand-new 0-shard profile). Assert the reject yields no snapshot AND the fresh fallback carries zero progress.
	var rejected: ActionResult = ProfileSnapshot.parse({"schema_version": 99, "oath_shards": 999, "first_death_recorded": true})
	assert_true(rejected.is_error(), "An unsupported-schema read must reject.")
	assert_false(rejected.metadata.has("snapshot"), "A rejected read must yield NO profile (the caller starts fresh).")
	var fresh: ProfileSnapshot = ProfileSnapshot.fresh()
	assert_equal(fresh.oath_shards, 0, "The fresh fallback grants 0 Oath Shards (no unintended progress from a rejected read).")
	assert_false(fresh.first_death_recorded, "The fresh fallback has first_death_recorded == false.")
	assert_equal(fresh.echoes, [] as Array[String], "The fresh fallback has no Echoes.")
	assert_equal(fresh.unlock_progress, {}, "The fresh fallback has no unlock progress.")
	assert_equal(fresh.class_mastery, {}, "The fresh fallback has no class mastery.")
	_cleanup()


func _schema_version_stays_one() -> void:
	# 8.7 does NOT bump the schema (the migration matrix tests the EXISTING v0 contract — the version reject + the lenient
	# parse; a real v1->v2 migrate() is a later story). Documents the invariant that 8.4/8.5 merged into reserved homes
	# WITHOUT a bump and 8.7 keeps it at 1.
	assert_equal(ProfileSnapshot.SCHEMA_VERSION, 1, "ProfileSnapshot.SCHEMA_VERSION must stay 1 (8.7 does NOT bump it — no v2 schema in production).")


# ================================================================================================
# AC3 — the headless grant/deny matrix across eligible / manual-seed / death / completion
# ================================================================================================

func _eligible_completed_run_awards_and_merges_and_is_not_a_first_death() -> void:
	# CASE 1 — Eligible + COMPLETED: award GRANTED (min(1 + nodes_cleared, 5) > 0), merge GRANTED (discoveries merged +
	# thresholds evaluated), first-death N/A (a completion is not a death — run_not_failed, ZERO mutation). Then the
	# GRANTED profile SAVES + RELOADS with the granted state byte-identical.
	_cleanup()
	var run: RunState = _completed_run(3, 4242, false)  # 3 cleared nodes -> award = min(1 + 3, 5) = 4.
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()

	# AWARD.
	var award: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute(run)
	assert_true(award.succeeded, "An eligible completed run must award: %s" % award.metadata)
	var expected_amount: int = MetaAwardRules.oath_shard_award_for(run)
	assert_equal(expected_amount, 4, "A 3-node completed run awards min(1 + 3, 5) == 4.")
	assert_equal(profile.oath_shards, 4, "The award raises the profile's oath_shards to the granted amount.")
	assert_equal(profile.last_awarded_run_seed, "4242", "The award records the run identity.")
	assert_equal(award.events.size(), 1, "The award emits exactly one oath_shards_awarded event.")

	# MERGE (a completed run discovered content).
	var discovery_events: Array = [
		DomainEvent.content_discovered(2, {"content_kind": "echo", "content_id": "echo_of_salt"}),
		DomainEvent.content_discovered(3, {"content_kind": "seal_fragment", "content_id": "seal_a"}),
		DomainEvent.content_discovered(4, {"content_kind": "class_mastery", "content_id": "warrior"})
	]
	var merge: ActionResult = MergeRunDiscoveriesCommand.new(profile, discovery_events, 5).execute(run)
	assert_true(merge.succeeded, "An eligible completed run must merge discoveries: %s" % merge.metadata)
	assert_true(profile.echoes.has("echo_of_salt"), "The merge adds the Echo.")
	assert_true((profile.unlock_progress.get(UnlockProgressRules.SEAL_FRAGMENTS_KEY) as Array).has("seal_a"), "The merge adds the Seal Fragment.")
	assert_equal(int(profile.class_mastery.get("warrior")), 1, "The merge adds the class-mastery point.")
	# The threshold crossing (1 seal fragment crosses seal_gate_1) is evaluated.
	assert_true(bool(profile.unlock_progress.get("seal_gate_1_unlocked")), "Crossing the 1-seal threshold flips seal_gate_1_unlocked (thresholds evaluated).")
	assert_true((merge.events[0] as DomainEvent).payload.get("thresholds_crossed").has("seal_gate_1"), "The merge event reports the crossed threshold.")

	# FIRST-DEATH is N/A on a completion (death-only gate) — ZERO mutation.
	var profile_before_death_attempt: Dictionary = profile.to_dictionary()
	var first_death: ActionResult = RecordFirstDeathCommand.new(profile, 6).execute(run)
	assert_true(first_death.is_error(), "A completion must reject the first-death record (a completion is not a death).")
	assert_equal(first_death.error_code, &"run_not_failed", "A completion rejects first-death with run_not_failed.")
	assert_false(first_death.has_events(), "A completion emits NO first-death event.")
	assert_equal(profile.to_dictionary(), profile_before_death_attempt, "A completion leaves the profile byte-identical at the first-death gate.")
	assert_false(profile.first_death_recorded, "A completion does NOT set the first-death latch.")

	# GRANTED-state SURVIVES a save-reload.
	var expected: Dictionary = profile.to_dictionary()
	var repository: ProfileRepository = ProfileRepository.new()
	assert_true(repository.write_profile(profile, TEST_PROFILE_PATH).succeeded, "The eligible-completed granted profile should persist.")
	var reloaded: ActionResult = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true(reloaded.succeeded, "The eligible-completed granted profile should reload.")
	assert_true(_profile_round_trip_matches(reloaded.metadata.get("snapshot"), expected), "The granted (awarded + merged) state must survive a save-reload faithfully (int-coercion aware).")
	_cleanup()


func _eligible_death_awards_zero_merges_and_latches_first_death() -> void:
	# CASE 2 — Eligible + FAILED (death): award GRANTED but amount 0 (a death yields 0 currency this story — oath_shards
	# UNCHANGED, but the marker + event STILL fire, an eligible death IS a valid 0-award, NOT a reject); merge GRANTED (a
	# death can still have discovered content); first-death GRANTED (the FIRST death latches first_death_recorded + emits).
	# Then the granted profile SAVES + RELOADS with the withheld-currency + merged discoveries + set latch intact.
	_cleanup()
	var run: RunState = _failed_run(2, 5555, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 6  # a prior accumulated total — a death must NOT change it.

	# AWARD: granted, amount 0.
	var award: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute(run)
	assert_true(award.succeeded, "An eligible death resolves the award (a valid 0-award, NOT a reject).")
	assert_equal(award.metadata.get("amount"), 0, "A death awards 0 Oath Shards this story.")
	assert_equal(profile.oath_shards, 6, "A death must NOT change the Oath-Shard total (0 award).")
	assert_equal(profile.last_awarded_run_seed, "5555", "An eligible death still records the run identity (the marker fires).")
	assert_equal(award.events.size(), 1, "An eligible death STILL emits an honest 0-amount award event.")
	assert_equal((award.events[0] as DomainEvent).payload.get("amount"), 0, "The award event records the 0 amount.")

	# MERGE: granted (a death discovered content too).
	var discovery_events: Array = [DomainEvent.content_discovered(2, {"content_kind": "echo", "content_id": "echo_of_tide"})]
	var merge: ActionResult = MergeRunDiscoveriesCommand.new(profile, discovery_events, 3).execute(run)
	assert_true(merge.succeeded, "An eligible death must merge discoveries.")
	assert_true(profile.echoes.has("echo_of_tide"), "The death's discovery merges.")

	# FIRST-DEATH: granted (the FIRST death latches + emits).
	var first_death: ActionResult = RecordFirstDeathCommand.new(profile, 4).execute(run)
	assert_true(first_death.succeeded, "An eligible FIRST death must latch the first-death flag.")
	assert_true(profile.first_death_recorded, "The first death sets first_death_recorded.")
	assert_equal(first_death.events.size(), 1, "The first death emits exactly one first_death_recorded event.")

	# GRANTED-state SURVIVES a save-reload: oath_shards still 6 (withheld), the merged Echo, the set latch.
	var expected: Dictionary = profile.to_dictionary()
	var repository: ProfileRepository = ProfileRepository.new()
	assert_true(repository.write_profile(profile, TEST_PROFILE_PATH).succeeded, "The eligible-death granted profile should persist.")
	var reloaded: ActionResult = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true(reloaded.succeeded, "The eligible-death granted profile should reload.")
	var restored: ProfileSnapshot = reloaded.metadata.get("snapshot")
	assert_true(_profile_round_trip_matches(restored, expected), "The granted (0-award + merged + first-death) state must survive a save-reload faithfully (int-coercion aware).")
	assert_equal(restored.oath_shards, 6, "The withheld-currency total (0 award on a death) survives the reload.")
	assert_true(restored.first_death_recorded, "The set first-death latch survives the reload.")
	assert_true(restored.echoes.has("echo_of_tide"), "The death's merged discovery survives the reload.")
	_cleanup()


func _manual_seed_completed_run_denies_award_and_merge() -> void:
	# CASE 3 — Manual-seed + COMPLETED: award DENIED (run_not_meta_eligible, ZERO mutation, profile byte-identical); merge
	# DENIED (run_not_meta_eligible, ZERO mutation); first-death N/A (a completion is not a death). Each DENIED case leaves
	# the profile UNCHANGED from its pre-command state (no phantom grant persisted — proven via a save-reload too).
	_cleanup()
	var run: RunState = _completed_run(3, 7777, true)  # manual-seed completed.
	assert_false(run.meta_progression_eligible, "Setup: a manual-seed run is NOT meta-progression eligible.")
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "completed"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 9
	var profile_before: Dictionary = profile.to_dictionary()

	# AWARD DENIED.
	var award: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute(run)
	assert_true(award.is_error(), "A manual-seed completed run must DENY the award (FR28).")
	assert_equal(award.error_code, &"run_not_meta_eligible", "The award denies a manual-seed run with run_not_meta_eligible.")
	assert_false(award.has_events(), "A denied award emits NO event.")
	assert_equal(profile.to_dictionary(), profile_before, "A denied award leaves the profile byte-identical.")

	# MERGE DENIED.
	var discovery_events: Array = [DomainEvent.content_discovered(2, {"content_kind": "echo", "content_id": "echo_of_salt"})]
	var merge: ActionResult = MergeRunDiscoveriesCommand.new(profile, discovery_events, 3).execute(run)
	assert_true(merge.is_error(), "A manual-seed completed run must DENY the merge (FR28).")
	assert_equal(merge.error_code, &"run_not_meta_eligible", "The merge denies a manual-seed run with run_not_meta_eligible.")
	assert_false(merge.has_events(), "A denied merge emits NO event.")
	assert_equal(profile.to_dictionary(), profile_before, "A denied merge leaves the profile byte-identical.")

	# The DENIED profile persists UNCHANGED (no phantom grant persisted).
	var repository: ProfileRepository = ProfileRepository.new()
	assert_true(repository.write_profile(profile, TEST_PROFILE_PATH).succeeded, "The unchanged profile should persist.")
	var reloaded: ActionResult = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true(reloaded.succeeded, "The unchanged profile should reload.")
	assert_true(_profile_round_trip_matches(reloaded.metadata.get("snapshot"), profile_before), "A manual-seed completed run persists NO phantom grant (the profile equals its pre-command state).")
	_cleanup()


func _manual_seed_death_denies_award_and_merge_but_still_latches_first_death() -> void:
	# CASE 4 — Manual-seed + FAILED (death): the DIVERGENCE. award DENIED + merge DENIED (run_not_meta_eligible — FR28), yet
	# the first-death latch STILL records (the ELIGIBILITY-INDEPENDENT latch — Option A, human-ratified: a boolean narrative
	# latch grants ZERO Oath Shards/unlocks/mastery, so it does NOT violate FR28). This is the load-bearing cross-story
	# invariant. Then the profile (first-death set, currency/discoveries withheld) saves + reloads with exactly that state.
	_cleanup()
	var run: RunState = _failed_run(2, 8888, true)  # manual-seed death.
	assert_false(run.meta_progression_eligible, "Setup: a manual-seed death is NOT meta-progression eligible.")
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 2
	var profile_before_meta: Dictionary = profile.to_dictionary()

	# AWARD DENIED.
	var award: ActionResult = AwardMetaProgressCommand.new(profile, summary, 1).execute(run)
	assert_true(award.is_error(), "A manual-seed death must DENY the award (FR28).")
	assert_equal(award.error_code, &"run_not_meta_eligible", "The award denies a manual-seed death with run_not_meta_eligible.")
	assert_equal(profile.to_dictionary(), profile_before_meta, "A denied award leaves the profile byte-identical.")

	# MERGE DENIED.
	var discovery_events: Array = [DomainEvent.content_discovered(2, {"content_kind": "seal_fragment", "content_id": "seal_a"})]
	var merge: ActionResult = MergeRunDiscoveriesCommand.new(profile, discovery_events, 3).execute(run)
	assert_true(merge.is_error(), "A manual-seed death must DENY the merge (FR28).")
	assert_equal(merge.error_code, &"run_not_meta_eligible", "The merge denies a manual-seed death with run_not_meta_eligible.")
	assert_equal(profile.to_dictionary(), profile_before_meta, "A denied merge leaves the profile byte-identical.")

	# FIRST-DEATH STILL GRANTED (the divergence — the latch is NOT gated on eligibility).
	var first_death: ActionResult = RecordFirstDeathCommand.new(profile, 4).execute(run)
	assert_true(first_death.succeeded, "A manual-seed FIRST death STILL records (Option A — the latch is eligibility-INDEPENDENT).")
	assert_true(profile.first_death_recorded, "The manual-seed first death sets first_death_recorded (the line is available in a practice death).")
	assert_equal(first_death.events.size(), 1, "The manual-seed first death STILL emits the first-death event.")
	# It granted ZERO meta progression (the latch is a narrative marker, NOT progression — it must not violate FR28).
	assert_equal(profile.oath_shards, 2, "The first-death latch grants ZERO Oath Shards (unchanged from the pre-meta total).")
	assert_equal(profile.echoes.size(), 0, "The first-death latch grants ZERO Echoes.")
	assert_equal((profile.unlock_progress.get(UnlockProgressRules.SEAL_FRAGMENTS_KEY, []) as Array).size(), 0, "The first-death latch grants ZERO Seal Fragments.")
	assert_equal(profile.class_mastery, {}, "The first-death latch grants ZERO class mastery.")

	# The profile (ONLY the first-death latch set, currency + discoveries withheld) saves + reloads with exactly that state.
	var expected: Dictionary = profile.to_dictionary()
	var repository: ProfileRepository = ProfileRepository.new()
	assert_true(repository.write_profile(profile, TEST_PROFILE_PATH).succeeded, "The manual-seed-death profile should persist.")
	var reloaded: ActionResult = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true(reloaded.succeeded, "The manual-seed-death profile should reload.")
	var restored: ProfileSnapshot = reloaded.metadata.get("snapshot")
	assert_true(_profile_round_trip_matches(restored, expected), "The manual-seed-death profile (first-death set, currency/discoveries withheld) survives a save-reload faithfully (int-coercion aware).")
	assert_true(restored.first_death_recorded, "The set first-death latch survives the reload.")
	assert_equal(restored.oath_shards, 2, "No currency was granted to the manual-seed death (the total is unchanged).")
	assert_equal(restored.echoes.size(), 0, "No discoveries were merged for the manual-seed death.")
	_cleanup()


func _three_run_end_markers_are_order_independent() -> void:
	# THE THREE-MARKER ORDER-INDEPENDENCE invariant (8.4/8.5 ratified), GENERALIZED to award + merge + first-death together
	# (the per-command tests prove only the first-death marker's independence). The AWARD (last_awarded_run_seed), the MERGE
	# (unlock_progress["_last_merged_run_seed"]), and the FIRST-DEATH latch (first_death_recorded) are INDEPENDENT markers,
	# each separately idempotent per its own scope, so ANY caller order on the SAME eligible-death run produces an IDENTICAL
	# final profile. Run award->merge->first-death vs first-death->merge->award and assert the two final profiles match.
	_cleanup()

	# Order A: award -> merge -> first-death.
	var run_a: RunState = _failed_run(2, 4242, false)
	var summary_a: RunSummary = RunSummary.build(run_a, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	var discoveries_a: Array = [
		DomainEvent.content_discovered(2, {"content_kind": "echo", "content_id": "echo_of_salt"}),
		DomainEvent.content_discovered(3, {"content_kind": "seal_fragment", "content_id": "seal_a"})
	]
	var profile_a: ProfileSnapshot = ProfileSnapshot.new()
	profile_a.oath_shards = 4
	assert_true(AwardMetaProgressCommand.new(profile_a, summary_a, 1).execute(run_a).succeeded, "Order A: the award (0 on a death) resolves.")
	assert_true(MergeRunDiscoveriesCommand.new(profile_a, discoveries_a, 2).execute(run_a).succeeded, "Order A: the merge resolves.")
	assert_true(RecordFirstDeathCommand.new(profile_a, 3).execute(run_a).succeeded, "Order A: the first-death latches.")

	# Order B: first-death -> merge -> award (the SAME run identity + discoveries + starting profile).
	var run_b: RunState = _failed_run(2, 4242, false)
	var summary_b: RunSummary = RunSummary.build(run_b, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	var discoveries_b: Array = [
		DomainEvent.content_discovered(2, {"content_kind": "echo", "content_id": "echo_of_salt"}),
		DomainEvent.content_discovered(3, {"content_kind": "seal_fragment", "content_id": "seal_a"})
	]
	var profile_b: ProfileSnapshot = ProfileSnapshot.new()
	profile_b.oath_shards = 4
	assert_true(RecordFirstDeathCommand.new(profile_b, 1).execute(run_b).succeeded, "Order B: the first-death latches first.")
	assert_true(MergeRunDiscoveriesCommand.new(profile_b, discoveries_b, 2).execute(run_b).succeeded, "Order B: the merge resolves.")
	assert_true(AwardMetaProgressCommand.new(profile_b, summary_b, 3).execute(run_b).succeeded, "Order B: the award (0 on a death) resolves last.")

	# The two final profiles are IDENTICAL (order-independent — each marker is separately idempotent per its own scope).
	assert_equal(profile_a.to_dictionary(), profile_b.to_dictionary(), "award+merge+first-death in ANY caller order must produce an IDENTICAL final profile (independent markers).")
	# And that final state is the expected union (award marker + merge marker + first-death latch + merged discoveries).
	assert_equal(profile_a.oath_shards, 4, "A death awards 0 — the total is unchanged in both orders.")
	assert_equal(profile_a.last_awarded_run_seed, "4242", "The award marker is set in both orders.")
	assert_equal(String(profile_a.unlock_progress.get(MergeRunDiscoveriesCommand.LAST_MERGED_RUN_SEED_KEY)), "4242", "The merge marker is set in both orders.")
	assert_true(profile_a.first_death_recorded, "The first-death latch is set in both orders.")
	assert_true(profile_a.echoes.has("echo_of_salt"), "The Echo is merged in both orders.")
	assert_true((profile_a.unlock_progress.get(UnlockProgressRules.SEAL_FRAGMENTS_KEY) as Array).has("seal_a"), "The Seal Fragment is merged in both orders.")
	_cleanup()


func _spend_interleaved_with_run_end_markers_leaves_each_independent() -> void:
	# Story 11.6 (AC3 — caller-ordering safety): a SPEND interleaved with the FOUR run-end markers (award / merge / first-
	# death / first-victory) leaves each independent + correct, in ANY caller order. A spend reads/writes NONE of the four
	# markers (it touches only the applied-unlock flag + the spend ledger, both namespaced away). Run
	# award->spend->merge->first-victory vs first-victory->merge->spend->award on a COMPLETED eligible run + assert the two
	# final profiles are IDENTICAL.
	_cleanup()

	# Order A: award -> spend -> merge -> first-victory (a completed eligible run — a victory awards + can latch victory).
	var run_a: RunState = _completed_run(2, 4242, false)
	var summary_a: RunSummary = RunSummary.build(run_a, [DomainEvent.run_completed(1, {"outcome": "victory"})])
	var discoveries_a: Array = [DomainEvent.content_discovered(2, {"content_kind": "seal_fragment", "content_id": "seal_a"})]
	var profile_a: ProfileSnapshot = ProfileSnapshot.new()
	profile_a.oath_shards = 10  # enough to spend the necromancer unlock (3)
	assert_true(AwardMetaProgressCommand.new(profile_a, summary_a, 1).execute(run_a).succeeded, "Order A: the award resolves.")
	assert_true(SpendOathShardsCommand.new(profile_a, "necromancer", 2).execute(null).succeeded, "Order A: the spend resolves.")
	assert_true(MergeRunDiscoveriesCommand.new(profile_a, discoveries_a, 3).execute(run_a).succeeded, "Order A: the merge resolves.")
	assert_true(RecordFirstVictoryCommand.new(profile_a, 4).execute(run_a).succeeded, "Order A: the first-victory latches.")

	# Order B: first-victory -> merge -> spend -> award (the SAME run + discoveries + starting profile).
	var run_b: RunState = _completed_run(2, 4242, false)
	var summary_b: RunSummary = RunSummary.build(run_b, [DomainEvent.run_completed(1, {"outcome": "victory"})])
	var discoveries_b: Array = [DomainEvent.content_discovered(2, {"content_kind": "seal_fragment", "content_id": "seal_a"})]
	var profile_b: ProfileSnapshot = ProfileSnapshot.new()
	profile_b.oath_shards = 10
	assert_true(RecordFirstVictoryCommand.new(profile_b, 1).execute(run_b).succeeded, "Order B: the first-victory latches first.")
	assert_true(MergeRunDiscoveriesCommand.new(profile_b, discoveries_b, 2).execute(run_b).succeeded, "Order B: the merge resolves.")
	assert_true(SpendOathShardsCommand.new(profile_b, "necromancer", 3).execute(null).succeeded, "Order B: the spend resolves.")
	assert_true(AwardMetaProgressCommand.new(profile_b, summary_b, 4).execute(run_b).succeeded, "Order B: the award resolves last.")

	# The two final profiles are IDENTICAL (order-independent — the spend + each marker is separately idempotent per its
	# own scope, and the spend touches none of the four markers).
	assert_equal(profile_a.to_dictionary(), profile_b.to_dictionary(), "A spend interleaved with award+merge+first-victory in ANY order must produce an IDENTICAL final profile.")
	# The composed final state: the award raised the total (completed run: min(1+2,5)=3 -> 10+3=13), then the spend dropped
	# it by 3 (necromancer) -> 10; the applied-unlock flag is set; the spend ledger records 3; the four markers are all set.
	assert_equal(profile_a.oath_shards, 10, "award (+3) then spend (-3) nets to the starting 10.")
	assert_true(bool(profile_a.unlock_progress.get("necromancer_unlocked")), "The applied-unlock flag is set (spend applied).")
	assert_equal(MetaSpendRules.oath_shards_spent_in(profile_a.unlock_progress), 3, "The spend ledger records the spend.")
	assert_equal(profile_a.last_awarded_run_seed, "4242", "The award marker is untouched by the spend.")
	assert_equal(String(profile_a.unlock_progress.get(MergeRunDiscoveriesCommand.LAST_MERGED_RUN_SEED_KEY)), "4242", "The merge marker is untouched by the spend.")
	assert_true(profile_a.first_victory_recorded, "The first-victory latch is untouched by the spend.")
	assert_true((profile_a.unlock_progress.get(UnlockProgressRules.SEAL_FRAGMENTS_KEY) as Array).has("seal_a"), "The Seal Fragment merged independently of the spend.")
	_cleanup()


func _spend_then_persist_round_trips_the_applied_unlock() -> void:
	# Story 11.6 (AC3 — the spend state survives a real restart): SPEND, PERSIST through the repository, SIMULATE AN APP
	# RESTART (fresh repository), read back, and assert the lowered total + the applied-unlock flag + the spend ledger are
	# byte-identical after a REAL JSON file round-trip. A profile-aware HeroSelectViewModel built off the RELOADED profile
	# reports the formerly-locked class selectable (the end-to-end AC2 proof through the save layer).
	_cleanup()
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 8
	assert_true(SpendOathShardsCommand.new(profile, "necromancer", 1).execute(null).succeeded, "The spend should resolve before persisting.")
	var expected: Dictionary = profile.to_dictionary()

	var write_repository: ProfileRepository = ProfileRepository.new()
	assert_true(write_repository.write_profile(profile, TEST_PROFILE_PATH).succeeded, "The spent profile should persist.")

	# Simulate an app restart: a FRESH repository reads the file back.
	var read_repository: ProfileRepository = ProfileRepository.new()
	var read_result: ActionResult = read_repository.read_profile(TEST_PROFILE_PATH)
	assert_true(read_result.succeeded, "The spent profile should read back after a restart.")
	var restored: ProfileSnapshot = read_result.metadata.get("snapshot")
	# The lowered total + the applied-unlock flag + the spend ledger restore. The ledger is a nested int-in-dict, so a JSON
	# round-trip decodes it as a float (the SAME encoding artifact as class_mastery — {"x": 3} != {"x": 3.0} across JSON);
	# MetaSpendRules.oath_shards_spent_in int-coerces it, so the ledger read is faithful without a false failure (the 8.7
	# class_mastery lesson). `expected` documents the pre-restart shape.
	assert_true(expected.has("unlock_progress"), "Setup: the expected dict carries the spend state under unlock_progress.")
	assert_equal(restored.oath_shards, 5, "The lowered total survives (necromancer cost 3 -> 8 - 3 == 5).")
	assert_true(bool(restored.unlock_progress.get("necromancer_unlocked")), "The applied-unlock flag survives the restart.")
	assert_equal(MetaSpendRules.oath_shards_spent_in(restored.unlock_progress), 3, "The spend ledger survives the restart (int-coercion aware).")

	# End-to-end AC2 through the save layer: the reloaded profile drives a profile-aware HeroSelectViewModel that reports
	# the formerly-locked class SELECTABLE.
	var hero_select: HeroSelectViewModel = HeroSelectViewModel.new(ClassRepository.create_baseline_repository(), restored)
	assert_true(hero_select.is_class_selectable(&"necromancer"), "AC2 end-to-end: the reloaded spent profile makes necromancer selectable.")
	_cleanup()


func _snapshots_serialize_no_scene_node() -> void:
	# NFR15 (AC3 "no scene nodes serialized") — a STRUCTURAL guard: the save truth is a versioned domain snapshot of plain
	# serializable data (String/int/bool/Array/Dictionary), never a Node/Object/scene reference. Walk both the fully
	# populated ProfileSnapshot dict AND a RunSnapshot dict; assert every value is a JSON-primitive / Array / Dictionary
	# (no Object-typed value). This documents the invariant structurally; it is trivially true for the pure-dict design.
	var profile_dict: Dictionary = _fully_populated_profile().to_dictionary()
	assert_true(_is_json_compatible(profile_dict), "The ProfileSnapshot dict must contain only JSON-compatible primitives/arrays/dictionaries (no Object/Node — NFR15).")
	assert_false(_contains_object_value(profile_dict), "The ProfileSnapshot dict must contain NO Object/Node value (the save truth is a versioned domain snapshot).")

	# A RunSnapshot dict (the run autosave truth) is likewise pure serializable data.
	var run: RunState = _completed_run(2, 4242, false)
	var streams: RngStreamSet = RngStreamSet.new(4242)
	var compose_result: ActionResult = RunSnapshot.from_route_position(run, streams)
	assert_true(compose_result.succeeded, "A route-position run snapshot should compose for the NFR15 guard.")
	var run_dict: Dictionary = (compose_result.metadata.get("snapshot") as RunSnapshot).to_dictionary()
	assert_true(_is_json_compatible(run_dict), "The RunSnapshot dict must contain only JSON-compatible data (no Object/Node — NFR15).")
	assert_false(_contains_object_value(run_dict), "The RunSnapshot dict must contain NO Object/Node value.")


# ================================================================================================
# Fixtures + helpers
# ================================================================================================

# A ProfileSnapshot exercising EVERY field the 8.3/8.4/8.5 systems can set (AC1 — the fully-populated round-trip). The
# unlock_progress composite carries the Seal-Fragment set + a threshold flag + the dedicated merge marker (the 8.4 home);
# class_mastery is the separate top-level field; first_death_recorded is the 8.5 latch. Built by hand (no RNG) so the
# round-trip is deterministic.
func _fully_populated_profile() -> ProfileSnapshot:
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.profile_id = "player-one"
	profile.oath_shards = 12
	profile.last_awarded_run_seed = FULL_INT64_SEED
	profile.echoes = ["echo_of_salt", "echo_of_tide"]
	profile.unlock_progress = {
		UnlockProgressRules.SEAL_FRAGMENTS_KEY: ["seal_a", "seal_b"],
		"seal_gate_1_unlocked": true,
		MergeRunDiscoveriesCommand.LAST_MERGED_RUN_SEED_KEY: FULL_INT64_SEED
	}
	profile.class_mastery = {"warrior": 3}
	profile.first_death_recorded = true
	return profile


# A terminal RouteState with `cleared` cleared combat nodes (the 4.3/8.3 fixture idiom, mirroring the per-command tests).
func _cleared_route(cleared: int) -> RouteState:
	var nodes: Array[RouteNode] = []
	var cleared_ids: Array[String] = []
	var count: int = max(cleared, 1)
	for index: int in range(count):
		var node_id: String = "node-%d" % index
		var next_ids: Array[String] = []
		if index < count - 1:
			next_ids = ["node-%d" % (index + 1)]
		nodes.append(RouteNode.new(node_id, RouteNode.TYPE_COMBAT, index, RouteNode.REVEAL_CLEARED, next_ids))
		if index < cleared:
			cleared_ids.append(node_id)
	var current_id: String = cleared_ids[cleared_ids.size() - 1] if not cleared_ids.is_empty() else ""
	return RouteState.new(nodes, current_id, cleared_ids)


# A validated terminal COMPLETED run. meta_progression_eligible == not is_manual_seed (the RunState lockstep), so
# run.validate() passes for both the eligible and the manual-seed fixture.
func _completed_run(cleared: int, seed_value: int, is_manual_seed: bool) -> RunState:
	var run: RunState = RunState.new(RunState.PHASE_COMPLETED, seed_value, is_manual_seed, not is_manual_seed, _cleared_route(cleared))
	assert_true(run.validate().succeeded, "Setup: the completed run fixture should validate (the eligibility lockstep).")
	return run


# A validated terminal FAILED (death) run.
func _failed_run(cleared: int, seed_value: int, is_manual_seed: bool) -> RunState:
	var run: RunState = RunState.new(RunState.PHASE_FAILED, seed_value, is_manual_seed, not is_manual_seed, _cleared_route(cleared))
	assert_true(run.validate().succeeded, "Setup: the failed run fixture should validate (the eligibility lockstep).")
	assert_true(run.is_terminal(), "Setup: a failed run is terminal.")
	return run


# Compare a JSON-RELOADED ProfileSnapshot against an in-memory EXPECTED dict, int-coercion aware. JSON has no int/float
# distinction, so a class_mastery int VALUE decodes as a float on read (Godot's Dictionary == is type-strict on values —
# {"warrior": 3} != {"warrior": 3.0}). That is an EXPECTED encoding artifact of the round-trip, not data loss; the
# production code intentionally int-coerces class_mastery on use (int(profile.class_mastery.get(...)), the
# test_profile_snapshot.gd precedent). This helper normalizes the class_mastery values on both sides then compares the
# whole dict, so a faithful round-trip passes without a false int-vs-float failure. Every OTHER field round-trips as its
# JSON-native type (String / bool / int oath_shards / String arrays / the unlock_progress String-set + bool flags + String
# marker — none carry a nested int value in this matrix), so a direct compare is correct for them.
func _profile_round_trip_matches(actual: ProfileSnapshot, expected_dict: Dictionary) -> bool:
	var actual_dict: Dictionary = actual.to_dictionary()
	actual_dict["class_mastery"] = _int_normalized_counts(actual_dict.get("class_mastery", {}))
	var expected_normalized: Dictionary = expected_dict.duplicate(true)
	expected_normalized["class_mastery"] = _int_normalized_counts(expected_dict.get("class_mastery", {}))
	return actual_dict == expected_normalized


# Coerce every value of a per-class count dict to int (the JSON int->float normalization). Keys are class-id Strings.
func _int_normalized_counts(counts: Variant) -> Dictionary:
	var normalized: Dictionary = {}
	if not counts is Dictionary:
		return normalized
	for key: Variant in (counts as Dictionary).keys():
		normalized[key] = int((counts as Dictionary)[key])
	return normalized


# Read a file's raw text (for the separability no-cross-contamination byte comparison). Returns "" if absent.
func _read_raw(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file = null
	return text


# Remove the test save files + their .tmp/.bak siblings (the test_profile_repository.gd cleanup precedent). Called first
# + last so a run never leaves a stray user://test_*.json behind and never reads a prior run's file.
func _cleanup() -> void:
	var paths: Array[String] = []
	for base: String in [TEST_PROFILE_PATH, TEST_RUN_PATH]:
		paths.append(base)
		paths.append("%s.tmp" % base)
		paths.append("%s.bak" % base)
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		elif DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)


# NFR15 walk: every value in the dict tree is a JSON-compatible primitive / Array / Dictionary (the
# test_between_level_save.gd precedent).
func _is_json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item: Variant in value:
				if not _is_json_compatible(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value.keys():
				if typeof(key) != TYPE_STRING:
					return false
				if not _is_json_compatible(value[key]):
					return false
			return true
		_:
			return false


# NFR15 explicit no-Object guard: walk the dict tree and return true if ANY value is an Object (a Node/scene reference /
# live RefCounted). The save truth must carry none — the assertion documents the invariant structurally.
func _contains_object_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_OBJECT:
			return true
		TYPE_ARRAY:
			for item: Variant in value:
				if _contains_object_value(item):
					return true
			return false
		TYPE_DICTIONARY:
			for key: Variant in value.keys():
				if _contains_object_value(value[key]):
					return true
			return false
		_:
			return false
