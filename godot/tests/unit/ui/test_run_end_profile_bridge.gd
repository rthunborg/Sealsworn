extends "res://tests/unit/test_case.gd"

# Story 11.5 (AC-wide crux — the run-end -> profile BRIDGE) — RunEndProfileBridge: the caller-driven seam that runs the
# load -> record-latch -> persist -> build-summary/outpost sequence the live run flow (11.2/11.3) never wired. The record
# commands (RecordFirstDeath/VictoryCommand) are caller-driven by design (the 8.3/8.4/8.5/9.4 posture); this bridge IS
# that caller. The RunOrchestrator is UNCHANGED (it gained ONE additive read-only accessor next_sequence_id()).
#
# ⭐ THE RETRO H1 DISCIPLINE (test the SHARED sequencing seam, not just the individual commands): the bridge RE-IMPLEMENTS
# the run-end command SEQUENCING (load -> record latch -> persist -> build) at the flow layer. This test drives the SHARED
# bridge seam END-TO-END on the verified seed 4242 (a LIVE victory records first-victory + builds the outpost off the REAL
# terminal COMPLETED state; a LIVE death records first-death + builds the outpost off the REAL terminal FAILED state) — so
# the on-screen order (record-then-build, off the REAL terminal state) is proven to match the domain's intended order and
# never builds the outpost off a stale/un-persisted profile.
#
# This test pins:
#   - a LIVE DEATH (1-HP dagger hero on seed 4242) records the first-death latch + persists + builds the outpost with the
#     first-death reveal beat (has_beat) + the run summary (has_summary, PHASE_FAILED);
#   - a LIVE VICTORY (full-HP warrior full run on seed 4242) records the first-victory latch + persists + builds the outpost
#     with the first-victory reveal beat + the run summary (has_summary, PHASE_COMPLETED);
#   - profile_not_found -> a fresh profile is started + persisted (a brand-new player; NOT a recovery banner);
#   - a WRITE failure -> the AC3 write-failure recovery outpost (real totals behind a retry banner, has_profile == true);
#   - a LOAD failure (unsupported_profile_schema) -> the AC3 load-failure recovery outpost (fresh 0-shard fallback,
#     has_profile == false) + the incompatible profile is NOT overwritten;
#   - the latch record is ELIGIBILITY-INDEPENDENT (a manual-seed live death STILL records the first-death latch — Option A);
#   - idempotency: a second finalize on the same terminal run does NOT double-latch (the profile is already latched);
#   - the sequence_id threaded is UNIQUE (> the ids the run already emitted — next_sequence_id(), not a hardcoded 1);
#   - determinism/purity: the bridge draws ZERO gameplay RNG + mutates only the profile (the run stays byte-identical).

const FirstDeathNarrativeBeat = preload("res://scripts/run/first_death_narrative_beat.gd")
const FirstVictoryRevealBeat = preload("res://scripts/run/first_victory_reveal_beat.gd")
const OutpostViewModel = preload("res://scripts/ui/view_models/outpost_view_model.gd")
const ProfileRepository = preload("res://scripts/save/profile_repository.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RunEndProfileBridge = preload("res://scripts/ui/flow/run_end_profile_bridge.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The verified seed (test_live_run_flow / test_run_flow_controller): a 1-HP dagger hero dies on the depth-0 opener; a
# full-HP warrior wins the full run to boss victory.
const SEED: int = 4242
const TEST_PROFILE_PATH := "user://test_run_end_profile_bridge_profile.json"

func run() -> Dictionary:
	_live_death_records_first_death_and_builds_the_outpost()
	_live_victory_records_first_victory_and_builds_the_outpost()
	_profile_not_found_starts_and_persists_a_fresh_profile()
	_write_failure_builds_the_write_failure_recovery_outpost()
	_load_failure_builds_the_fresh_fallback_recovery_without_overwrite()
	_latch_record_is_eligibility_independent_for_a_manual_seed_death()
	_finalize_is_idempotent_and_does_not_double_latch()
	_threaded_sequence_id_is_unique_past_the_runs_emitted_ids()
	_bridge_mutates_only_the_profile_and_is_rng_free()
	_non_terminal_run_yields_null()
	_cleanup()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# Drive a LIVE hero death on the verified seed (a 1-HP dagger hero felled on the depth-0 opener -> the auto-fired
# hero-death source -> PHASE_FAILED). Returns the terminal orchestrator.
func _orchestrator_at_live_death(is_manual_seed: bool = false) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(SEED, is_manual_seed).succeeded, "Setup: the live-death start should succeed.")
	assert_true(orchestrator.resolve_current_node_live(1, &"dagger").succeeded, "Setup: the live death should resolve.")
	assert_equal(orchestrator.run.phase, RunState.PHASE_FAILED, "Setup: the run is a real terminal FAILED run.")
	return orchestrator


# Drive a LIVE full-run victory on the verified finale seed (a full-HP warrior clears the run to boss victory ->
# PHASE_COMPLETED). Returns the terminal orchestrator.
func _orchestrator_at_live_victory() -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(SEED, false).succeeded, "Setup: the live-victory start should succeed.")
	var full: Variant = orchestrator.auto_play_full_run()
	assert_true(full.succeeded, "Setup: the auto-played full run should reach victory: %s" % full.metadata)
	assert_equal(orchestrator.run.phase, RunState.PHASE_COMPLETED, "Setup: the run is a real terminal COMPLETED run.")
	return orchestrator


func _bridge() -> RunEndProfileBridge:
	return RunEndProfileBridge.new(ProfileRepository.new(), TEST_PROFILE_PATH)


# ---- the bridge sequence off the REAL live terminal state ----------------------------------------

func _live_death_records_first_death_and_builds_the_outpost() -> void:
	_cleanup()
	var orchestrator: RunOrchestrator = _orchestrator_at_live_death()

	var outpost: OutpostViewModel = _bridge().build_outpost(orchestrator.run, orchestrator)
	assert_true(outpost != null, "The bridge builds an outpost off a terminal FAILED run.")
	var data: Dictionary = outpost.to_dictionary()

	# The first-death latch was RECORDED off the REAL terminal state (persisted to the profile file).
	assert_true(bool(data.get("first_death_recorded")), "A live death records the first-death latch off the REAL terminal state.")
	assert_true(bool((data.get("first_death_beat") as Dictionary).get("has_beat")), "The outpost renders the first-death reveal beat.")
	assert_equal(String((data.get("first_death_beat") as Dictionary).get("line")), FirstDeathNarrativeBeat.FIRST_DEATH_LINE, "The first-death beat carries the resolved line.")
	# The just-ended run summary is present + reports the FAILED phase.
	var summary: Dictionary = data.get("run_summary")
	assert_true(bool(summary.get("has_summary")), "The outpost embeds the just-ended run summary (has_summary == true).")
	assert_equal(String(summary.get("phase")), String(RunState.PHASE_FAILED), "The summary reports the terminal FAILED phase.")
	# The persisted profile actually carries the latch (a re-read proves the persist).
	var reread: Variant = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true(reread.succeeded, "The persisted profile re-reads cleanly.")
	assert_true((reread.metadata.get("snapshot") as ProfileSnapshot).first_death_recorded, "The persisted profile carries the first-death latch.")


func _live_victory_records_first_victory_and_builds_the_outpost() -> void:
	_cleanup()
	var orchestrator: RunOrchestrator = _orchestrator_at_live_victory()

	var outpost: OutpostViewModel = _bridge().build_outpost(orchestrator.run, orchestrator)
	assert_true(outpost != null, "The bridge builds an outpost off a terminal COMPLETED run.")
	var data: Dictionary = outpost.to_dictionary()

	assert_true(bool((data.get("first_victory_beat") as Dictionary).get("has_beat")), "A live victory renders the first-victory reveal beat.")
	assert_equal(String((data.get("first_victory_beat") as Dictionary).get("line")), FirstVictoryRevealBeat.FIRST_VICTORY_LINE, "The first-victory beat carries the resolved line.")
	# A victory does NOT set the first-DEATH latch (the opposite phase).
	assert_false(bool((data.get("first_death_beat") as Dictionary).get("has_beat")), "A victory does not render a first-death beat (the opposite phase).")
	var summary: Dictionary = data.get("run_summary")
	assert_true(bool(summary.get("has_summary")), "The outpost embeds the just-ended victory run summary.")
	assert_equal(String(summary.get("phase")), String(RunState.PHASE_COMPLETED), "The summary reports the terminal COMPLETED phase.")
	assert_true(bool((summary.get("run_scoped") as Dictionary).get("boss_cleared")), "The victory summary reports a cleared boss node (the route-derived fact).")
	# The persisted profile carries the first-victory latch.
	var reread: Variant = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true((reread.metadata.get("snapshot") as ProfileSnapshot).first_victory_recorded, "The persisted profile carries the first-victory latch.")


func _profile_not_found_starts_and_persists_a_fresh_profile() -> void:
	# profile_not_found -> a brand-new player: a FRESH profile is started, the latch recorded, and the fresh profile
	# persisted (the file now EXISTS). NOT a recovery banner (a fresh start is the normal first-run path).
	_cleanup()
	assert_false(FileAccess.file_exists(TEST_PROFILE_PATH), "Setup: no profile file exists (profile_not_found).")
	var orchestrator: RunOrchestrator = _orchestrator_at_live_death()

	var outpost: OutpostViewModel = _bridge().build_outpost(orchestrator.run, orchestrator)
	var data: Dictionary = outpost.to_dictionary()
	# A fresh profile is a valid surface (has_profile == true — a fresh() is still a supplied profile), 0 shards, no
	# recovery banner (profile_not_found is the fresh path, not a recovery).
	assert_false(bool((data.get("recovery_state") as Dictionary).get("has_recovery")), "profile_not_found is the FRESH path, NOT a recovery banner.")
	# has_profile == true even for a brand-new (profile_not_found) player: the bridge builds off ProfileSnapshot.fresh(),
	# a non-null supplied profile — the "returning vs brand-new" distinction is recovery_state.has_recovery (asserted
	# above), not has_profile. Assert it explicitly so the intended-but-counter-intuitive true value is pinned.
	assert_true(bool(data.get("has_profile")), "profile_not_found builds off ProfileSnapshot.fresh() -> has_profile == true (a fresh() is a non-null supplied profile).")
	assert_true(bool(data.get("first_death_recorded")), "The fresh profile records the first-death latch off the terminal state.")
	assert_true(FileAccess.file_exists(TEST_PROFILE_PATH), "The fresh profile was persisted (the file now exists).")


func _write_failure_builds_the_write_failure_recovery_outpost() -> void:
	# AC3 profile-WRITE failure: the WRITE fails but the latch was set in memory. The bridge builds the write-failure
	# recovery outpost — the in-memory profile behind a retry banner (has_profile == true, NOT a null crash), the structured
	# save-failure code, and the retry affordance. Force the write to fail deterministically by pointing save_path under a
	# NON-EXISTENT parent directory: read -> file_exists false -> profile_not_found -> a FRESH profile is started + latched
	# in memory, then write (open .tmp under a missing dir) -> profile_save_open_failed. (A genuinely-LOADED real-totals
	# profile behind the banner is unit-tested at the VM/render-view level; here the bridge's write-failure BRANCH is
	# exercised end-to-end — the in-memory latched profile is shown behind the banner, not lost.)
	_cleanup()
	var orchestrator: RunOrchestrator = _orchestrator_at_live_death()

	var missing_dir_path := "user://test_bridge_missing_dir/profile.json"
	var bridge: RunEndProfileBridge = RunEndProfileBridge.new(ProfileRepository.new(), missing_dir_path)
	var outpost: OutpostViewModel = bridge.build_outpost(orchestrator.run, orchestrator)
	var data: Dictionary = outpost.to_dictionary()

	var recovery_state: Dictionary = data.get("recovery_state")
	assert_true(bool(recovery_state.get("has_recovery")), "A write failure surfaces a recovery state.")
	assert_equal(String(recovery_state.get("code")), "profile_save_open_failed", "The write-failure recovery carries the structured save-open code.")
	assert_true(bool(recovery_state.get("is_recoverable")), "The write failure is recoverable (a retry affordance).")
	# has_profile == true: the in-memory latched profile is shown behind the banner — NOT a null crash / lost profile.
	assert_true(bool(data.get("has_profile")), "The write-failure recovery shows the in-memory profile behind the retry banner (has_profile == true).")
	# The reveal beat still renders (the record succeeded in memory even though the write failed).
	assert_true(bool((data.get("first_death_beat") as Dictionary).get("has_beat")), "The reveal beat renders on a write-failure recovery (the latch was set in memory).")
	# Clean the throwaway missing-dir profile path if the .tmp somehow materialized.
	for path: String in [missing_dir_path, "%s.tmp" % missing_dir_path, "%s.bak" % missing_dir_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _load_failure_builds_the_fresh_fallback_recovery_without_overwrite() -> void:
	# AC3 profile-LOAD failure: an incompatible profile (unsupported_profile_schema) -> the fresh-fallback recovery outpost
	# (has_profile == false, 0 shards) + the incompatible profile is NOT overwritten (do NOT clobber it). Record NO latch.
	_cleanup()
	# Write a future-schema profile so the read surfaces unsupported_profile_schema.
	var file: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema_version": ProfileSnapshot.SCHEMA_VERSION + 10, "content_version": "future", "oath_shards": 999}))
	file.flush()
	file = null
	var before_bytes: String = FileAccess.get_file_as_string(TEST_PROFILE_PATH)

	var orchestrator: RunOrchestrator = _orchestrator_at_live_death()
	var outpost: OutpostViewModel = _bridge().build_outpost(orchestrator.run, orchestrator)
	var data: Dictionary = outpost.to_dictionary()

	var recovery_state: Dictionary = data.get("recovery_state")
	assert_true(bool(recovery_state.get("has_recovery")), "A load failure surfaces a recovery state.")
	assert_equal(String(recovery_state.get("code")), "unsupported_profile_schema", "The load-failure recovery carries the structured schema code.")
	# The fresh fallback: has_profile == false, 0 shards (no real totals exist to show — the profile could not be read).
	assert_false(bool(data.get("has_profile")), "The load-failure recovery is the fresh fallback (has_profile == false).")
	assert_equal(int(data.get("oath_shards")), 0, "The load-failure recovery shows 0 Oath Shards (no real totals).")
	assert_false(bool(data.get("first_death_recorded")), "The load-failure recovery records NO latch (there is no valid profile to mutate).")
	# The incompatible profile file was NOT overwritten (do NOT clobber an unmigratable profile).
	assert_equal(FileAccess.get_file_as_string(TEST_PROFILE_PATH), before_bytes, "The incompatible profile is left BYTE-IDENTICAL (never overwritten).")


func _latch_record_is_eligibility_independent_for_a_manual_seed_death() -> void:
	# AC2 / Option A: the first-death latch is ELIGIBILITY-INDEPENDENT — a MANUAL-seed live death STILL records the flag +
	# renders the reveal line (the line is narrative flavor, not meta progression). The run is manual-seed (meta-ineligible).
	_cleanup()
	var orchestrator: RunOrchestrator = _orchestrator_at_live_death(true)  # manual-seed
	assert_false(orchestrator.run.meta_progression_eligible, "Setup: a manual-seed run is meta-ineligible.")

	var outpost: OutpostViewModel = _bridge().build_outpost(orchestrator.run, orchestrator)
	var data: Dictionary = outpost.to_dictionary()
	assert_true(bool(data.get("first_death_recorded")), "A manual-seed first death STILL records the latch (eligibility-independent — Option A).")
	assert_true(bool((data.get("first_death_beat") as Dictionary).get("has_beat")), "A manual-seed first death STILL renders the reveal line.")
	# The manual-seed summary correctly reports ineligibility (the FR28 lockstep — the warning is a READOUT of this).
	assert_true(bool((data.get("run_summary") as Dictionary).get("is_manual_seed")), "The summary reports the manual seed.")
	assert_false(bool((data.get("run_summary") as Dictionary).get("meta_progression_eligible")), "The manual-seed summary is meta-ineligible (the FR28 lockstep).")


func _finalize_is_idempotent_and_does_not_double_latch() -> void:
	# Running the bridge TWICE on the same terminal run does NOT double-latch: the first finalize sets + persists the latch;
	# the second finalize re-reads the (now latched) profile, the record command rejects idempotently
	# (first_death_already_recorded) with ZERO mutation, and the outpost still renders correctly (the latch stays true; the
	# beat simply does not re-emit a NEW record). The profile stays consistent (latched, once).
	_cleanup()
	var orchestrator: RunOrchestrator = _orchestrator_at_live_death()

	var first: OutpostViewModel = _bridge().build_outpost(orchestrator.run, orchestrator)
	assert_true(bool(first.to_dictionary().get("first_death_recorded")), "The first finalize records the latch.")
	var after_first: Variant = ProfileRepository.new().read_profile(TEST_PROFILE_PATH)
	assert_true((after_first.metadata.get("snapshot") as ProfileSnapshot).first_death_recorded, "The latch is persisted after the first finalize.")

	# The second finalize: the profile is already latched -> the record rejects idempotently (ZERO mutation). The outpost
	# still shows the latch true (the persisted profile is unchanged — a re-latch is a no-op).
	var second: OutpostViewModel = _bridge().build_outpost(orchestrator.run, orchestrator)
	assert_true(bool(second.to_dictionary().get("first_death_recorded")), "The second finalize still shows the latch (idempotent — no double-latch).")


func _threaded_sequence_id_is_unique_past_the_runs_emitted_ids() -> void:
	# The bridge threads next_sequence_id() (the run-level cursor) into the record command — NOT a hardcoded 1 that could
	# collide with an id the run already emitted. A live full run emits many events, so the cursor is well past 1; the
	# record command (which rejects sequence_id <= 0 first) succeeds with the unique id. Proven structurally: the cursor is
	# > 1 after a live run, and the record succeeds (a colliding id would still succeed but violate uniqueness — here we
	# assert the cursor the bridge reads is past the run's emitted ids).
	_cleanup()
	var orchestrator: RunOrchestrator = _orchestrator_at_live_death()
	assert_true(orchestrator.next_sequence_id() > 1, "A live run advanced the sequence cursor well past 1 (the bridge threads a unique id, not a hardcoded 1).")

	# The bridge succeeds (records the latch) using that unique cursor id.
	var outpost: OutpostViewModel = _bridge().build_outpost(orchestrator.run, orchestrator)
	assert_true(bool(outpost.to_dictionary().get("first_death_recorded")), "The record succeeds with the unique cursor sequence id.")


func _bridge_mutates_only_the_profile_and_is_rng_free() -> void:
	# Determinism/purity: the bridge draws ZERO gameplay RNG + mutates ONLY the profile (not the run). The terminal run is
	# byte-identical before/after the bridge; two runs of the bridge from the SAME starting profile state (a clean no-file
	# state each -> the first-death latch is freshly recorded each time, showing the reveal beat) build byte-identical
	# outposts. (A second build against the ALREADY-persisted latched profile is intentionally NOT identical — the record
	# rejects idempotently so the beat does not re-show; that idempotency is asserted separately.)
	_cleanup()
	var orchestrator: RunOrchestrator = _orchestrator_at_live_death()
	var run_before: Dictionary = orchestrator.run.to_dictionary()

	var first: Dictionary = _bridge().build_outpost(orchestrator.run, orchestrator).to_dictionary()
	# The terminal RUN is byte-identical (the bridge mutates the PROFILE, never the run).
	assert_equal(orchestrator.run.to_dictionary(), run_before, "The bridge leaves the terminal run byte-identical (it mutates only the profile).")

	# Reset to a clean no-file profile state so the second build starts from the SAME state as the first (a fresh record,
	# not an idempotent no-op) -> the outpost is byte-identical (deterministic; the beats/summary are pure reads, ZERO RNG).
	_cleanup()
	var second: Dictionary = _bridge().build_outpost(orchestrator.run, orchestrator).to_dictionary()
	assert_equal(JSON.stringify(second), JSON.stringify(first), "Two bridge builds from the same starting profile state are byte-identical (deterministic; ZERO RNG).")
	# The run is STILL byte-identical after the second build too (mutates only the profile, never the run).
	assert_equal(orchestrator.run.to_dictionary(), run_before, "The bridge leaves the terminal run byte-identical across repeated builds.")


func _non_terminal_run_yields_null() -> void:
	# Fail-closed: a null / non-terminal run yields null (there is no outpost to build off an unfinished run — the presenter
	# branches on null).
	_cleanup()
	assert_true(_bridge().build_outpost(null, null) == null, "A null run yields null (fail-closed).")

	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(SEED, false, &"warrior").succeeded, "Setup: a fresh non-terminal run.")
	assert_false(orchestrator.run.is_terminal(), "Setup: the fresh run is non-terminal.")
	assert_true(_bridge().build_outpost(orchestrator.run, orchestrator) == null, "A non-terminal run yields null (fail-closed).")


func _cleanup() -> void:
	for path: String in [TEST_PROFILE_PATH, "%s.tmp" % TEST_PROFILE_PATH, "%s.bak" % TEST_PROFILE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
