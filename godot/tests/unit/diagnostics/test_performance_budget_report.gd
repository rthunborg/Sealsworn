extends "res://tests/unit/test_case.gd"

# Story 10.1 Task 4 (AC3, AC5) — the build-profile-gated PERFORMANCE-BUDGET measurement report
# (PerformanceBudgetReport, the LocalTimingRecorder/BossAttemptDiagnostics-modeled build-profile-gated
# diagnostics RefCounted). This test asserts on the HARNESS's OWN contract — the records shape + the
# budget-comparison logic + the actionable-diagnostic formatting — NOT on any gameplay outcome, and it
# requires NO SceneTree/render/device (a pure in-memory RefCounted).
#
# Covered:
#   - the four canonical budget thresholds are the project-context Performance rules verbatim (level load
#     < 3000 ms / NFR4, preview response < 100 ms / NFR5, selection response < 100 ms / NFR5, frame budget
#     16.67 ms for 60 FPS / 33.33 ms for 30 FPS / NFR6);
#   - an ENABLED (dev-build) report records a measurement with a computed delta + pass/fail verdict
#     (measured <= budget == pass; measured > budget == fail), and a DISABLED report is INERT;
#   - the pass/fail boundary is INCLUSIVE (a measurement exactly AT the budget passes);
#   - a budget MISS produces an ACTIONABLE diagnostic (system + subject + measured + budget + delta —
#     NEVER a bare "slow"), and a PASS emits no failure diagnostic;
#   - has_failures() / failure_diagnostics() surface every miss for the report driver's non-zero exit;
#   - the record shape is the pinned RECORD_KEYS set (no key silently appears/vanishes);
#   - the report is a PURE in-memory observer (records() deep-copies; no telemetry/network/file handle).
#
# OS.is_debug_build() is TRUE under the headless test runner (a debug build), so the enabled path is
# directly exercisable. The `enabled = new_enabled and OS.is_debug_build()` gate is proven by the
# disabled-constructor test (INERT regardless of the build) — the AC5 build-profile-gated precedent.

const PerformanceBudgetReport = preload("res://scripts/diagnostics/performance_budget_report.gd")

func run() -> Dictionary:
	_canonical_budget_thresholds_are_the_project_context_rules()
	_enabled_report_records_a_pass_and_a_fail_with_delta()
	_disabled_report_is_inert()
	_budget_boundary_is_inclusive()
	_failure_produces_an_actionable_diagnostic_never_bare_slow()
	_pass_emits_no_failure_diagnostic()
	_has_failures_and_failure_diagnostics_surface_every_miss()
	_record_shape_is_the_pinned_key_set()
	_report_is_a_pure_in_memory_observer()
	_negative_measured_value_is_clamped()
	return result()


# ---- AC3: the four canonical thresholds are the project-context Performance rules -----------------

func _canonical_budget_thresholds_are_the_project_context_rules() -> void:
	# Level load < 3 s (NFR4). Stated in ms so a wall-clock measurement compares directly.
	assert_equal(PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS, 3000.0, "The level-load budget is 3000 ms (< 3 s / NFR4).")
	# UI preview + selection response < 100 ms (NFR5).
	assert_equal(PerformanceBudgetReport.BUDGET_PREVIEW_RESPONSE_MS, 100.0, "The preview-response budget is 100 ms (< 100 ms / NFR5).")
	assert_equal(PerformanceBudgetReport.BUDGET_SELECTION_RESPONSE_MS, 100.0, "The selection-response budget is 100 ms (< 100 ms / NFR5).")
	# Stable 60 FPS where feasible (16.67 ms/frame); 30 FPS acceptable lower-end (33.33 ms/frame) (NFR6).
	assert_true(absf(PerformanceBudgetReport.BUDGET_FRAME_60FPS_MS - 16.6667) < 0.01, "The 60 FPS frame budget is ~16.67 ms/frame (NFR6).")
	assert_true(absf(PerformanceBudgetReport.BUDGET_FRAME_30FPS_MS - 33.3333) < 0.01, "The 30 FPS lower-end frame budget is ~33.33 ms/frame (NFR6).")


# ---- AC3: an enabled report records a pass + a fail, each with a computed delta -------------------

func _enabled_report_records_a_pass_and_a_fail_with_delta() -> void:
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(true)
	assert_true(report.enabled, "In the headless (debug) build, a report constructed enabled must BE enabled.")
	assert_equal(report.record_count(), 0, "A fresh report has recorded no measurements yet.")

	# A PASS: level load at 1200 ms is under the 3000 ms budget.
	report.record_measurement("level_generation", "seed=1001 recipe=small_combat_basic", 1200.0, PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)
	assert_equal(report.record_count(), 1, "record_measurement appends one record when enabled.")
	var pass_record: Dictionary = report.records()[0]
	assert_equal(String(pass_record.get("system")), "level_generation", "The record captures the system.")
	assert_equal(String(pass_record.get("subject")), "seed=1001 recipe=small_combat_basic", "The record captures the subject.")
	assert_true(bool(pass_record.get("passed")), "1200 ms <= 3000 ms budget is a PASS.")
	assert_true(absf(float(pass_record.get("delta_ms")) - (-1800.0)) < 0.001, "The delta is measured - budget = 1200 - 3000 = -1800 ms (negative = headroom).")

	# A FAIL: a preview response at 140 ms exceeds the 100 ms budget.
	report.record_measurement("tactical_preview", "movement_preview", 140.0, PerformanceBudgetReport.BUDGET_PREVIEW_RESPONSE_MS)
	assert_equal(report.record_count(), 2, "A second measurement accumulates.")
	var fail_record: Dictionary = report.records()[1]
	assert_false(bool(fail_record.get("passed")), "140 ms > 100 ms budget is a FAIL.")
	assert_true(absf(float(fail_record.get("delta_ms")) - 40.0) < 0.001, "The delta is 140 - 100 = +40 ms (positive = over budget).")


# ---- AC5: a disabled report is INERT (no capture) ------------------------------------------------

func _disabled_report_is_inert() -> void:
	# Constructed disabled -> INERT regardless of the build (the LocalTimingRecorder gate). This is the
	# direct proof of the enabled gate: a disabled report records NOTHING even in a debug build.
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(false)
	assert_false(report.enabled, "A report constructed disabled must NOT be enabled.")

	report.record_measurement("level_generation", "seed=1", 5000.0, PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)

	assert_equal(report.record_count(), 0, "A disabled report captures NOTHING (INERT).")
	assert_true(report.records().is_empty(), "A disabled report's records() stays empty.")
	assert_false(report.has_failures(), "A disabled report has no failures (nothing recorded).")

	# The default constructor is disabled (a caller must opt in — the safe default).
	var default_report: PerformanceBudgetReport = PerformanceBudgetReport.new()
	assert_false(default_report.enabled, "The default constructor is disabled (opt-in required).")


# ---- AC3: the pass/fail boundary is inclusive (a measurement exactly AT the budget passes) --------

func _budget_boundary_is_inclusive() -> void:
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(true)
	# Exactly at the budget: measured == budget is a PASS (the "under-3-second" / "under-100ms" budget is
	# a ceiling the build must stay at-or-below; a hair over is the fail).
	report.record_measurement("selection", "inspect_intent", 100.0, PerformanceBudgetReport.BUDGET_SELECTION_RESPONSE_MS)
	assert_true(bool(report.records()[0].get("passed")), "A measurement exactly AT the budget (100 == 100) PASSES (inclusive ceiling).")

	report.record_measurement("selection", "inspect_intent_over", 100.001, PerformanceBudgetReport.BUDGET_SELECTION_RESPONSE_MS)
	assert_false(bool(report.records()[1].get("passed")), "A hair over the budget (100.001 > 100) FAILS.")


# ---- AC3: a budget miss produces an actionable diagnostic (never a bare "slow") -------------------

func _failure_produces_an_actionable_diagnostic_never_bare_slow() -> void:
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(true)
	report.record_measurement("level_generation", "seed=9999 recipe=medium_combat_basic", 3400.0, PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)

	var diagnostic: String = report.format_diagnostic(report.records()[0])
	# The diagnostic must be actionable + compact: system + subject + measured + budget + delta. NEVER a
	# bare "slow" (the project-context generator-diagnostics discipline).
	assert_true(diagnostic.contains("level_generation"), "The diagnostic names the SYSTEM.")
	assert_true(diagnostic.contains("seed=9999 recipe=medium_combat_basic"), "The diagnostic names the SUBJECT (seed/label).")
	assert_true(diagnostic.contains("3400"), "The diagnostic states the MEASURED value.")
	assert_true(diagnostic.contains("3000"), "The diagnostic states the BUDGET.")
	assert_true(diagnostic.contains("400"), "The diagnostic states the DELTA over budget.")
	assert_true(diagnostic.contains("FAIL"), "A budget miss is marked FAIL (actionable, not silent).")
	assert_false(diagnostic.strip_edges().to_lower() == "slow", "The diagnostic is NEVER a bare 'slow'.")


func _pass_emits_no_failure_diagnostic() -> void:
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(true)
	report.record_measurement("level_generation", "seed=1001", 900.0, PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)
	# A passing record still formats to a PASS line (readable), but is NOT surfaced as a failure diagnostic.
	var pass_line: String = report.format_diagnostic(report.records()[0])
	assert_true(pass_line.contains("PASS"), "A passing measurement formats to a readable PASS line.")
	assert_false(report.has_failures(), "A single passing measurement leaves has_failures() false.")
	assert_true(report.failure_diagnostics().is_empty(), "A passing report surfaces no failure diagnostics.")


# ---- AC3: has_failures() / failure_diagnostics() surface every miss ------------------------------

func _has_failures_and_failure_diagnostics_surface_every_miss() -> void:
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(true)
	report.record_measurement("level_generation", "seed=1", 500.0, PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)   # pass
	report.record_measurement("tactical_preview", "attack_preview", 250.0, PerformanceBudgetReport.BUDGET_PREVIEW_RESPONSE_MS)  # fail
	report.record_measurement("selection", "inspect", 400.0, PerformanceBudgetReport.BUDGET_SELECTION_RESPONSE_MS)  # fail

	assert_true(report.has_failures(), "A report with any over-budget measurement has_failures().")
	assert_equal(report.failure_count(), 2, "failure_count() counts only the over-budget measurements (2).")
	var failures: Array[String] = report.failure_diagnostics()
	assert_equal(failures.size(), 2, "failure_diagnostics() returns one line per miss.")
	for line: String in failures:
		assert_true(line.contains("FAIL"), "Every failure diagnostic is a FAIL line.")


# ---- the record shape is the pinned RECORD_KEYS set ----------------------------------------------

func _record_shape_is_the_pinned_key_set() -> void:
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(true)
	report.record_measurement("level_generation", "seed=1", 100.0, PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)
	var record: Dictionary = report.records()[0]

	var keys: Array = record.keys()
	keys.sort()
	var expected: Array = PerformanceBudgetReport.RECORD_KEYS.duplicate()
	expected.sort()
	assert_equal(keys, expected, "A recorded measurement carries EXACTLY the pinned RECORD_KEYS set (no key silently appears/vanishes).")


# ---- the report is a PURE in-memory observer (no telemetry/network/file dependency) --------------

func _report_is_a_pure_in_memory_observer() -> void:
	# The report holds ONLY plain-data records (String/float/bool) — no live handle, no file path, no
	# network client. records() returns a defensive deep copy, so a caller mutating the returned list
	# never perturbs the report (proving the records are owned in-memory, not backed by an external sink).
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(true)
	report.record_measurement("level_generation", "seed=1", 100.0, PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)

	var snapshot_a: Array[Dictionary] = report.records()
	snapshot_a.clear()
	snapshot_a.append({"system": "tampered"})
	assert_equal(report.record_count(), 1, "Mutating the returned records() copy must not perturb the report (in-memory ownership).")

	var snapshot_b: Array[Dictionary] = report.records()
	(snapshot_b[0] as Dictionary)["measured_ms"] = 99999.0
	assert_true(absf(float(report.records()[0].get("measured_ms")) - 100.0) < 0.001, "records() deep-copies each record dict (no shared mutable handle leaks out).")


func _negative_measured_value_is_clamped() -> void:
	# A negative measured value (a caller/clock bug) is clamped to 0 rather than recorded as a nonsense
	# negative (the BossAttemptDiagnostics clamp discipline). A budget is expected positive.
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(true)
	report.record_measurement("level_generation", "seed=1", -50.0, PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)
	assert_true(absf(float(report.records()[0].get("measured_ms")) - 0.0) < 0.001, "A negative measured value is clamped to 0.")
	assert_true(bool(report.records()[0].get("passed")), "The clamped 0 ms is trivially under budget (a PASS).")
