extends "res://tests/unit/test_case.gd"

# Story 11.5 (AC1/AC3/AC4 — the scene-level render-decision test) — OutpostRenderView: the fail-closed RefCounted
# render-decision seam the outpost_presenter reads. Per the Epic-11 scene-free-harness constraint (the runner has NO
# SceneTree — DO NOT write SceneTree tests), the AC1/AC3's scene-level assertions are satisfied by a RefCounted
# render-decision test + the scene-load compile guardrail covering outpost.tscn (test_run_flow_scenes_load.gd). This test
# proves the presenter's render DECISIONS branch correctly on the pinned OutpostViewModel / recovery_state / summary keys.
#
# This is the Epic-8 T4 "previously untested loaded-profile + recovery combination" scene-level test: the VM path is
# unit-tested in test_outpost_view_model.gd, but no SCENE renders it — this asserts the OUTPOST PRESENTER's render seam
# correctly branches on recovery_state and renders the loaded-profile real-totals-behind-retry surface (vs the fresh
# 0-shard fallback), and that the retry affordance is reachable.
#
# It pins:
#   AC3 — the recovery-mode branch: none (healthy) / load_failure (fresh 0-shard fallback, has_profile == false) /
#     write_failure (real totals behind retry, has_profile == true); the retry affordance is offered ONLY on the
#     write-failure mode; each mode carries a distinct text note (a non-color channel).
#   AC4 — the manual-seed warning is a READOUT of the summary's is_manual_seed flag (a manual-seed run shows it; a
#     normal-seed run shows none; a fresh session with no summary shows none); the G3 coupling (Option A) reads the AWARDED
#     total from the profile (oath_shards) while the summary's oath_shards_earned STAYS 0/not_yet_supported (the honest
#     "not yet tallied" note).
#   AC1/AC2/FR64 — the reveal beats render on their has_beat gate; the deferred named spaces carry an EXPLICIT deferred
#     marker; the start-descent affordance is available even with both beats absent (off the critical path); an absent
#     run summary renders "no just-ended run", not a zeroed sheet.

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const FirstDeathNarrativeBeat = preload("res://scripts/run/first_death_narrative_beat.gd")
const FirstVictoryRevealBeat = preload("res://scripts/run/first_victory_reveal_beat.gd")
const OutpostRenderView = preload("res://scripts/ui/view_models/outpost_render_view.gd")
const OutpostViewModel = preload("res://scripts/ui/view_models/outpost_view_model.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")

func run() -> Dictionary:
	# AC3 — the recovery-mode branch (the Epic-8 T4 scene-level test)
	_healthy_profile_is_no_recovery_mode()
	_load_failure_is_the_fresh_fallback_mode_no_retry()
	_write_failure_is_the_real_totals_behind_retry_mode()
	_recovery_modes_carry_distinct_text_notes()
	# AC4 — the manual-seed warning + the G3 coupling
	_manual_seed_run_shows_the_no_progression_warning()
	_normal_seed_run_shows_no_warning()
	_fresh_session_with_no_summary_shows_no_warning()
	_g3_awarded_total_reads_the_profile_summary_stays_zero_not_yet_tallied()
	# AC1/AC2/FR64 — reveal beats, deferred spaces, off-critical-path
	_reveal_beats_render_on_their_has_beat_gate()
	_deferred_named_spaces_carry_an_explicit_marker()
	_start_descent_is_available_with_both_beats_absent()
	_absent_run_summary_renders_no_just_ended_run()
	_render_view_is_a_pure_read()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _populated_profile() -> ProfileSnapshot:
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.oath_shards = 12
	profile.echoes = ["echo_of_salt"]
	profile.unlock_progress = {"seal_fragments": ["seal_a"]}
	profile.class_mastery = {"warrior": 3}
	profile.first_death_recorded = true
	return profile


func _terminal_run(phase: StringName, seed_value: int, is_manual_seed: bool) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_CLEARED, [])
	var route: RouteState = RouteState.new([start, boss], "node-1-0", ["node-0-0", "node-1-0"])
	var economy: RiskEconomyState = RiskEconomyState.new(25, 0, 2, 1, not is_manual_seed, [])
	return RunState.new(phase, seed_value, is_manual_seed, not is_manual_seed, route, &"", null, null, null, null, economy)


# ---- AC3: the recovery-mode branch (the Epic-8 T4 scene-level test) -------------------------------

func _healthy_profile_is_no_recovery_mode() -> void:
	# A healthy real profile -> no recovery banner (the normal surface renders).
	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile()))
	assert_false(view.is_recovery(), "A healthy real profile is NOT in a recovery mode.")
	assert_equal(view.recovery_mode(), OutpostRenderView.RECOVERY_MODE_NONE, "A healthy profile is recovery mode 'none'.")
	assert_false(view.has_retry_affordance(), "A healthy profile offers no retry affordance.")


func _load_failure_is_the_fresh_fallback_mode_no_retry() -> void:
	# AC3 profile-LOAD failure (unsupported_profile_schema / profile_open_failed / profile_parse_failed): the fresh 0-shard
	# fallback (has_profile == false). The recover action IS the fresh start — NO write to retry.
	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.for_recovery(&"unsupported_profile_schema"))
	assert_true(view.is_recovery(), "A load-failure surface IS in a recovery mode.")
	assert_equal(view.recovery_mode(), OutpostRenderView.RECOVERY_MODE_LOAD_FAILURE, "A recovery WITHOUT a loaded profile is the LOAD-failure fresh-fallback mode.")
	assert_equal(view.recovery_code(), "unsupported_profile_schema", "The load-failure carries its structured code.")
	assert_false(view.has_retry_affordance(), "A load-failure fresh fallback offers NO retry (the recover action is the fresh start).")


func _write_failure_is_the_real_totals_behind_retry_mode() -> void:
	# AC3 profile-WRITE failure (the Epic-8 T4 combination): a profile_save_* code WITH the intact loaded profile -> the
	# REAL totals behind a retry banner (has_profile == true, real oath_shards). The retry affordance IS reachable. This is
	# the "previously untested loaded-profile + recovery combination" at the render-decision layer.
	var loaded: ProfileSnapshot = _populated_profile()  # oath_shards == 12
	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.for_recovery(&"profile_save_replace_failed", loaded))
	assert_true(view.is_recovery(), "A write-failure surface IS in a recovery mode.")
	assert_equal(view.recovery_mode(), OutpostRenderView.RECOVERY_MODE_WRITE_FAILURE, "A recovery WITH a loaded profile is the WRITE-failure real-totals mode.")
	assert_equal(view.recovery_code(), "profile_save_replace_failed", "The write-failure carries its structured code.")
	assert_true(view.has_retry_affordance(), "The write-failure mode offers a REACHABLE retry affordance (re-attempt the write).")
	# ⭐ The REAL totals show (NOT a false 0-shard surface) — the whole point of the Epic-8 T4 combination.
	assert_equal(view.awarded_oath_shards(), 12, "The write-failure recovery renders the REAL Oath-Shard total (12), NOT a false 0.")


func _recovery_modes_carry_distinct_text_notes() -> void:
	# AC3 / appendix §13.5: each recovery mode carries a DISTINCT text note (a non-color channel) so "could not load" reads
	# differently from "could not save — retry".
	var load_view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.for_recovery(&"unsupported_profile_schema"))
	var write_view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.for_recovery(&"profile_save_replace_failed", _populated_profile()))
	assert_false(load_view.recovery_note().is_empty(), "The load-failure mode carries a text note.")
	assert_false(write_view.recovery_note().is_empty(), "The write-failure mode carries a text note.")
	assert_true(load_view.recovery_note() != write_view.recovery_note(), "The two recovery modes read DIFFERENTLY (distinct text notes — a non-color channel).")
	# A healthy profile has no note.
	assert_true(OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile())).recovery_note().is_empty(), "A healthy profile carries no recovery note.")


# ---- AC4: the manual-seed warning + the G3 coupling ----------------------------------------------

func _manual_seed_run_shows_the_no_progression_warning() -> void:
	# AC4 / FR28: a manual-seed terminal run's summary reports is_manual_seed == true (meta_progression_eligible == false in
	# lockstep) and the render surfaces the "manual seed — no meta progression earned" warning (a READOUT of the flag).
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, 4242, true)  # manual seed
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	assert_true(summary.is_manual_seed, "Setup: the summary reports the manual seed.")
	assert_false(summary.meta_progression_eligible, "Setup: the manual-seed summary is meta-ineligible (the lockstep).")

	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile(), summary))
	assert_true(view.shows_manual_seed_warning(), "A manual-seed run surfaces the no-progression warning.")
	assert_false(view.manual_seed_warning_line().is_empty(), "The manual-seed warning carries a labeled line (text, not color-only).")


func _normal_seed_run_shows_no_warning() -> void:
	# AC4: a NORMAL-seed run shows NO manual-seed warning.
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, 4242, false)  # normal seed
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "victory"})])
	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile(), summary))
	assert_false(view.shows_manual_seed_warning(), "A normal-seed run shows NO manual-seed warning.")
	assert_true(view.manual_seed_warning_line().is_empty(), "A normal-seed run has no warning line.")


func _fresh_session_with_no_summary_shows_no_warning() -> void:
	# AC4: a fresh session with no just-ended run (has_summary == false) shows no manual-seed warning.
	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile()))
	assert_false(view.shows_manual_seed_warning(), "A fresh session (no summary) shows no manual-seed warning.")


func _g3_awarded_total_reads_the_profile_summary_stays_zero_not_yet_tallied() -> void:
	# AC4 (the G3 coupling — Option A, the honest as-is): the AWARDED Oath-Shard total is the PROFILE's (oath_shards == 12);
	# the summary's oath_shards_earned STAYS 0 + is named in not_yet_supported, so the render shows an honest "not yet
	# tallied" note rather than wiring the summary field to a non-zero value.
	var run: RunState = _terminal_run(RunState.PHASE_COMPLETED, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_completed(1, {"outcome": "victory"})])
	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile(), summary))

	assert_equal(view.awarded_oath_shards(), 12, "The AWARDED total reads the PROFILE (oath_shards == 12) — the G3 Option A outpost-level readout.")
	assert_equal(view.summary_oath_shards_earned(), 0, "RunSummary.profile_meta.oath_shards_earned STAYS 0 (the not_yet_supported contract — NOT wired non-zero).")
	assert_true(view.summary_oath_shards_not_yet_tallied(), "The summary's Oath-Shards-earned field is a not-yet-supported placeholder (the honest 'not yet tallied' note).")


# ---- AC1/AC2/FR64: reveal beats, deferred spaces, off-critical-path -------------------------------

func _reveal_beats_render_on_their_has_beat_gate() -> void:
	# AC2: each reveal beat renders iff its has_beat gate is true. A death outpost renders the first-death line; a victory
	# outpost renders the first-victory line; the opposite beat is absent.
	var death_view: OutpostRenderView = OutpostRenderView.from_view_model(
		OutpostViewModel.new(_populated_profile(), null, FirstDeathNarrativeBeat.for_first_death())
	)
	assert_true(death_view.shows_first_death_beat(), "A present first-death beat renders.")
	assert_equal(death_view.first_death_line(), FirstDeathNarrativeBeat.FIRST_DEATH_LINE, "The first-death line is the resolved prose.")
	assert_false(death_view.shows_first_victory_beat(), "The first-victory beat is absent on a death outpost.")

	var victory_view: OutpostRenderView = OutpostRenderView.from_view_model(
		OutpostViewModel.new(_populated_profile(), null, null, FirstVictoryRevealBeat.for_first_victory())
	)
	assert_true(victory_view.shows_first_victory_beat(), "A present first-victory beat renders.")
	assert_equal(victory_view.first_victory_line(), FirstVictoryRevealBeat.FIRST_VICTORY_LINE, "The first-victory line is the resolved prose.")
	assert_false(victory_view.shows_first_death_beat(), "The first-death beat is absent on a victory outpost.")


func _deferred_named_spaces_carry_an_explicit_marker() -> void:
	# AC1: the four named spaces each carry an EXPLICIT deferred marker (the visible-exception discipline — never silently
	# omitted).
	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile()))
	var markers: Array = view.named_space_markers()
	assert_equal(markers.size(), 4, "There are exactly the four GDD named spaces.")
	for marker_value: Variant in markers:
		var marker: Dictionary = marker_value
		assert_equal(String(marker.get("status")), "deferred", "Every v0 named space is deferred.")
		assert_true(bool(marker.get("is_deferred")), "The deferred marker is EXPLICIT (a boolean the presenter maps to a coming-soon icon/label).")
		assert_false(String(marker.get("display_name")).is_empty(), "Each named space carries its display name.")


func _start_descent_is_available_with_both_beats_absent() -> void:
	# AC1/AC2/FR64: the start-another-descent affordance is available even with BOTH reveal beats absent (off the critical
	# path — a null/dismissed beat NEVER blocks the outpost surface or a new descent).
	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile()))  # no beats
	assert_false(view.shows_first_death_beat(), "Both beats absent: no first-death beat.")
	assert_false(view.shows_first_victory_beat(), "Both beats absent: no first-victory beat.")
	assert_true(view.can_start_descent(), "The start-descent affordance is available with both beats absent (off the critical path — FR64).")


func _absent_run_summary_renders_no_just_ended_run() -> void:
	# AC1: with no just-ended run (a fresh session — has_summary == false) the render shows "no just-ended run", not a
	# zeroed summary sheet.
	var view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile()))
	assert_false(view.shows_run_summary(), "A fresh session renders no run summary (has_summary == false).")
	# A present summary renders.
	var run: RunState = _terminal_run(RunState.PHASE_FAILED, 4242, false)
	var summary: RunSummary = RunSummary.build(run, [DomainEvent.run_failed(1, {"cause": "hero_death"})])
	var summary_view: OutpostRenderView = OutpostRenderView.from_view_model(OutpostViewModel.new(_populated_profile(), summary))
	assert_true(summary_view.shows_run_summary(), "A just-ended run renders its summary (has_summary == true).")


func _render_view_is_a_pure_read() -> void:
	# The render view is a pure read of the projection: constructing it + reading it mutates nothing + is deterministic.
	# Building from the same VM twice yields identical decisions.
	var vm: OutpostViewModel = OutpostViewModel.new(_populated_profile())
	var first: OutpostRenderView = OutpostRenderView.from_view_model(vm)
	var second: OutpostRenderView = OutpostRenderView.from_view_model(vm)
	assert_equal(first.awarded_oath_shards(), second.awarded_oath_shards(), "Two render views from the same VM agree (deterministic pure read).")
	assert_equal(first.recovery_mode(), second.recovery_mode(), "Two render views from the same VM agree on the recovery mode.")
	# A null VM is fail-closed (every gate false).
	var empty: OutpostRenderView = OutpostRenderView.from_view_model(null)
	assert_false(empty.is_recovery(), "A null VM render view is fail-closed (no recovery).")
	assert_false(empty.shows_first_death_beat(), "A null VM render view shows no beats.")
	assert_false(empty.can_start_descent(), "A null VM render view is fail-closed (no start affordance without a projection).")
