class_name PerformanceBudgetReport
extends RefCounted

# Story 10.1 (AC3, AC5) — the LOCAL/OFFLINE PERFORMANCE-BUDGET measurement report. A build-profile-gated,
# in-memory recorder that captures each measured performance value, compares it to its project-context
# budget, and emits an ACTIONABLE diagnostic (system + subject + measured + budget + delta + pass/fail) so
# a headless/desktop run or a later on-device pass can READ which budgets held and which missed. It is the
# performance-budget analogue of LocalTimingRecorder (scripts/diagnostics/local_timing_recorder.gd) and
# BossAttemptDiagnostics (scripts/diagnostics/boss_attempt_diagnostics.gd): its `enabled` is
# `new_enabled and OS.is_debug_build()` (INERT in a release build — the debug/cheat-tools-inert-in-
# production rule, AC5), it accumulates records in-memory, and it exposes records() (a defensive deep copy).
#
# WHY IT EXISTS (Story 10.1): the four MVP performance budgets are project-context law (§ Performance
# Rules) — generated level load < 3 s (NFR4), UI preview response < 100 ms (NFR5), selection response
# < 100 ms (NFR5), stable 60 FPS where feasible / 30 FPS acceptable lower-end (NFR6). Before Story 10.1
# there was no reusable seam that MEASURES a value against one of these budgets and reports an actionable
# miss. This report is that seam: the headless/desktop measurement harness (tools/dump_performance_budgets.gd)
# feeds it real wall-clock measurements (LevelGenerator.generate load time, the Epic1MicroCombatScenario
# command/LoS/turn timings) and prints the report; a later physical-device pass can feed it the on-device
# frame/latency numbers the same way.
#
# ⭐ IT IS A PURE OBSERVER — LOCAL/OFFLINE, ZERO SIDE EFFECTS. It introduces ZERO telemetry / network /
# cloud / account / file-persist dependency (NFR11 no-live-service + the TelemetrySink-stays-local rule).
# It draws ZERO RNG, MUTATES NOTHING (not the run, not the board, not a save), emits NO DomainEvent, and
# adds NO save key. It does NOT tune the game (difficulty is a HARD non-goal): it OBSERVES measured values
# and compares them to fixed budgets; it changes no gameplay outcome, RNG stream, schema, or fingerprint.
#
# HOME ([Decision]): scripts/diagnostics/ — alongside local_timing_recorder.gd + boss_attempt_diagnostics.gd,
# the sibling build-profile-gated local recorders. A DEDICATED RefCounted (NOT a Node/scene/autoload —
# Story 10.1 adds NO new autoload and NO shipped scene) so the record shape is self-documenting and the
# dev-build gate is explicit.

# ---- Canonical MVP performance budgets (project-context § Performance Rules; epics.md NFR4/NFR5/NFR6) ----
# Stated in milliseconds so a wall-clock / frame-time measurement compares directly. These are the ceilings
# the build must stay AT-OR-BELOW; a value strictly greater than the budget is a miss.

# Generated level load < 3 s (NFR4). Source: LevelGenerator.generate (the bounded-retry pipeline, worst
# case <= MAX_GENERATION_ATTEMPTS = 8, kept inside this budget by design).
const BUDGET_LEVEL_LOAD_MS: float = 3000.0

# UI preview response < 100 ms (NFR5). Source: the tactical preview view-models / command bridge (pure reads).
const BUDGET_PREVIEW_RESPONSE_MS: float = 100.0

# Selection / inspect response < 100 ms (NFR5). Same surface (selection/inspect intent).
const BUDGET_SELECTION_RESPONSE_MS: float = 100.0

# Stable 60 FPS where feasible (16.6667 ms/frame) / 30 FPS acceptable lower-end (33.3333 ms/frame) (NFR6).
# Frame stability is an ON-DEVICE render-profiler concern (a headless run has no render frame loop) — these
# constants exist so an on-device pass compares a sampled frame time to the same ceiling this seam defines.
const BUDGET_FRAME_60FPS_MS: float = 1000.0 / 60.0
const BUDGET_FRAME_30FPS_MS: float = 1000.0 / 30.0

# The exact key set of each recorded measurement (the LocalTimingRecorder / BossAttemptDiagnostics record-
# shape discipline — a key never silently appears/vanishes). Kept as a const so a consumer + a test pin it.
const RECORD_KEYS: Array[String] = [
	"system",
	"subject",
	"measured_ms",
	"budget_ms",
	"delta_ms",
	"passed"
]

# Whether the report actually records (dev build only — the LocalTimingRecorder gate VERBATIM). In a
# release build `enabled` is forced false regardless of the constructor argument, so the report is INERT.
var enabled: bool = false
var _records: Array[Dictionary] = []

func _init(new_enabled: bool = false) -> void:
	enabled = new_enabled and OS.is_debug_build()


# Record ONE measurement against its budget (AC3). Inert when disabled/release (records nothing). Draws
# ZERO RNG, mutates nothing external. `measured_ms` is clamped to >= 0 (a negative is a caller/clock bug;
# clamp rather than record a nonsense negative — the BossAttemptDiagnostics clamp discipline). `delta_ms`
# is measured - budget (negative = headroom, positive = over budget); `passed` is measured <= budget (an
# INCLUSIVE ceiling — a value exactly AT the budget passes, a hair over fails).
func record_measurement(system: String, subject: String, measured_ms: float, budget_ms: float) -> void:
	if not enabled:
		return
	var clamped_measured: float = maxf(0.0, measured_ms)
	_records.append({
		"system": system,
		"subject": subject,
		"measured_ms": clamped_measured,
		"budget_ms": budget_ms,
		"delta_ms": clamped_measured - budget_ms,
		"passed": clamped_measured <= budget_ms
	})


# Format ONE record as an actionable, compact diagnostic (AC3): system + subject + measured + budget +
# delta + PASS/FAIL. NEVER a bare "slow" (the project-context generator-diagnostics discipline: report the
# actionable facts, never a raw dump / an opaque label). A PASS formats to a readable PASS line; a FAIL is
# marked FAIL and states the over-budget delta so a human/CI knows exactly what to fix and by how much.
func format_diagnostic(record: Dictionary) -> String:
	var passed: bool = bool(record.get("passed", false))
	var verdict: String = "PASS" if passed else "FAIL"
	var measured: float = float(record.get("measured_ms", 0.0))
	var budget: float = float(record.get("budget_ms", 0.0))
	var delta: float = float(record.get("delta_ms", 0.0))
	# Present the delta as an explicit over/under-budget number so the miss is self-documenting.
	var delta_label: String = "%+.2f ms vs budget" % delta
	return "[%s] %s / %s: measured=%.2f ms budget=%.2f ms delta=%s" % [
		verdict,
		String(record.get("system", "")),
		String(record.get("subject", "")),
		measured,
		budget,
		delta_label
	]


# True when ANY recorded measurement is over budget (the report driver's non-zero-exit / fail-loud signal).
func has_failures() -> bool:
	for record: Dictionary in _records:
		if not bool(record.get("passed", false)):
			return true
	return false


# The number of over-budget measurements (a convenience read).
func failure_count() -> int:
	var count: int = 0
	for record: Dictionary in _records:
		if not bool(record.get("passed", false)):
			count += 1
	return count


# Every over-budget measurement as an actionable FAIL diagnostic line (AC3) — what a report driver prints
# and exits non-zero on. Empty when no measurement missed its budget.
func failure_diagnostics() -> Array[String]:
	var lines: Array[String] = []
	for record: Dictionary in _records:
		if not bool(record.get("passed", false)):
			lines.append(format_diagnostic(record))
	return lines


# The recorded measurements (a defensive deep copy — the LocalTimingRecorder.records() shape). Empty when
# the report is disabled/release (nothing was recorded) or when no measurement has been recorded yet.
func records() -> Array[Dictionary]:
	return _records.duplicate(true)


# The number of recorded measurements (a convenience read; equals records().size()).
func record_count() -> int:
	return _records.size()
