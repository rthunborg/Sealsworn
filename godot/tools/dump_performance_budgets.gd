extends SceneTree

# One-shot dev/CI tool (Story 10.1, AC3): measure the HEADLESS/DESKTOP-measurable MVP performance budgets
# and print an ACTIONABLE report (system + subject + measured + budget + delta + PASS/FAIL) via the
# build-profile-gated PerformanceBudgetReport. This is the headless half of the Story 10.1 measurement
# harness; the on-device budgets (sustained 60/30 FPS frame stability, real-touch preview/selection
# latency) are recorded in device-tiers-and-performance-budgets.md as `availability gap ->
# physical-device measurement pass` notes (a headless run has no render frame loop / no touch input).
#
# WHAT IT MEASURES:
#   - LEVEL LOAD (NFR4, < 3000 ms): wall-clock (Time.get_ticks_usec delta) around LevelGenerator.generate
#     over a seed sample x {small_combat_basic, medium_combat_basic}. Compared to BUDGET_LEVEL_LOAD_MS.
#   - REPRESENTATIVE COMBAT STEP TIMINGS (proxy for the NFR5 < 100 ms preview/selection response — the
#     DOMAIN compute a real preview/selection drives): the per-step LocalTimingRecorder labels
#     (command_execution / line_of_sight_update) the Epic1MicroCombatScenario captures on a scripted win
#     path. The domain compute is headless-measurable; the on-device render-to-glass latency is a gap.
#
# HOW IT REUSES THE EXISTING SEAMS (retro §7 "reuse harnesses, don't rebuild"): it composes
# LevelGenerator.generate (level load), Epic1MicroCombatScenario.run_win_path(enable_timing=true) (the
# existing representative combat-timing driver + its LocalTimingRecorder labels), and feeds
# PerformanceBudgetReport (the Story 10.1 budget-comparison seam). It authors NO parallel timing primitive.
#
# NOT a test (lives under tools/, NOT auto-discovered by the headless runner; excluded from EVERY export
# preset via export_presets.cfg `exclude_filter` tools/** — AC5). DEBUG/manual tool: it grants NO
# progression, mutates no save/run/board state, draws no gameplay RNG beyond what generate/the scenario
# already draw, and writes NO `user://` artifact (it only prints). Build-profile-appropriate (a tools/
# SceneTree script, never shipped as gameplay). Run via PowerShell:
#   godot --headless --path C:\Sealsworn\godot --script res://tools/dump_performance_budgets.gd

const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const Epic1MicroCombatScenario = preload("res://scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd")
const PerformanceBudgetReport = preload("res://scripts/diagnostics/performance_budget_report.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

# The seed sample the level-load measurement draws over. Kept compatible with the approved Small + Medium
# seed catalog the seed-batch report / regression suite (Story 10.2) use, so the two harnesses agree on
# which seeds a level-load number is reported for. Story 10.8: EXPANDED 5 -> 50 (coordinated with the 10.2
# consolidated suite + the 10.3 fairness batch — the three Epic-10 harnesses draw the SAME 50-seed catalog).
const LEVEL_LOAD_SEEDS: Array[int] = [
	1001, 2002, 3003, 4004, 5005,
	1, 2, 3, 5, 7, 13, 42, 99, 123, 256,
	314, 512, 777, 1024, 1234, 2026, 2718, 3141, 4242, 5555,
	6006, 7007, 8008, 8675309, 9999, 12345, 31415, 55555, 65536, 77777,
	88888, 100003, 123456, 161803, 271828, 314159, 500009, 654321, 1000003, 1048576,
	2000003, 7777777, 16777216, 999999937, 123456789
]

# Combat-step labels that stand in for the NFR5 preview/selection response (the domain compute a real
# preview/selection intent drives). line_of_sight_update ~ preview recompute; command_execution ~ commit.
const PREVIEW_PROXY_LABELS: Array[String] = ["line_of_sight_update", "command_execution"]

func _init() -> void:
	var report: PerformanceBudgetReport = PerformanceBudgetReport.new(true)
	if not report.enabled:
		# Only reachable in a NON-debug build (the gate). A release build is not a measurement context.
		print("PerformanceBudgetReport is disabled (non-debug build) — measurement is a dev/CI activity. Nothing measured.")
		quit(0)
		return

	print("=== Story 10.1 headless performance-budget report ===")
	print("(headless/desktop-measurable budgets only; on-device FPS + real-touch latency are availability gaps)")
	print("")

	_measure_level_load(report)
	_measure_representative_combat(report)

	print("")
	print("--- FULL REPORT (%d measurements) ---" % report.record_count())
	for record: Dictionary in report.records():
		print("  ", report.format_diagnostic(record))

	print("")
	if report.has_failures():
		print("RESULT: %d budget miss(es) — see FAIL lines above." % report.failure_count())
		# Non-zero exit so a CI wiring can fail on a regression. (A miss here is a MEASUREMENT signal for the
		# 10.6 readiness gate, not necessarily a hard build break — the gate decides.)
		quit(1)
	else:
		print("RESULT: all measured budgets PASS.")
		quit(0)


# LEVEL LOAD (NFR4): wall-clock around LevelGenerator.generate over the seed sample x {small, medium}.
func _measure_level_load(report: PerformanceBudgetReport) -> void:
	print("[level load < %.0f ms / NFR4]" % PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)
	var recipes: LevelRecipeRepository = LevelRecipeRepository.create_baseline_repository()
	var enemies: EnemyRepository = EnemyRepository.create_baseline_repository()

	for entry: Dictionary in [
		{"recipe_id": &"small_combat_basic", "size_class": GenerationRequest.SIZE_SMALL},
		{"recipe_id": &"medium_combat_basic", "size_class": GenerationRequest.SIZE_MEDIUM}
	]:
		var recipe_id: StringName = entry.get("recipe_id")
		var size_class: StringName = entry.get("size_class")
		for seed_value: int in LEVEL_LOAD_SEEDS:
			var request := GenerationRequest.new(
				seed_value, &"node_1", &"combat", recipe_id,
				size_class, GenerationRequest.DIFFICULTY_STANDARD,
				GenerationRequest.AFFINITY_NONE, {}
			)
			var start_usec: int = Time.get_ticks_usec()
			var generation: GenerationResult = LevelGenerator.generate(request, recipes, enemies)
			var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
			var subject: String = "seed=%d recipe=%s attempts=%d succeeded=%s" % [
				seed_value,
				String(recipe_id),
				int(generation.diagnostics.get("attempts", -1)),
				str(generation.succeeded)
			]
			report.record_measurement("level_generation", subject, elapsed_ms, PerformanceBudgetReport.BUDGET_LEVEL_LOAD_MS)


# REPRESENTATIVE COMBAT STEP TIMINGS (proxy for NFR5 preview/selection): run the scripted win path with
# timing enabled, then compare each per-step label to the < 100 ms preview/selection budget.
func _measure_representative_combat(report: PerformanceBudgetReport) -> void:
	print("[preview/selection response < %.0f ms / NFR5 — representative combat-step domain compute]" % PerformanceBudgetReport.BUDGET_PREVIEW_RESPONSE_MS)
	var scenario := Epic1MicroCombatScenario.new()
	var outcome: ActionResult = scenario.run_win_path(true)
	if outcome.is_error():
		print("  (representative combat run errored: ", String(outcome.error_code), " — no combat-step timings recorded)")
		return

	var timing_records: Array = outcome.metadata.get("timing_records", [])
	# Aggregate the worst (max) elapsed per label — the step's slowest observed compute is what a response
	# budget must accommodate. Compare each preview-proxy label to the preview/selection budget.
	var worst_by_label: Dictionary = {}
	for entry_value: Variant in timing_records:
		var entry: Dictionary = entry_value
		var label: String = String(entry.get("label", ""))
		var elapsed_ms: float = float(int(entry.get("elapsed_usec", 0))) / 1000.0
		worst_by_label[label] = maxf(float(worst_by_label.get(label, 0.0)), elapsed_ms)

	for label: String in PREVIEW_PROXY_LABELS:
		if worst_by_label.has(label):
			report.record_measurement(
				"tactical_step",
				"%s (worst of representative win path)" % label,
				float(worst_by_label.get(label)),
				PerformanceBudgetReport.BUDGET_PREVIEW_RESPONSE_MS
			)
