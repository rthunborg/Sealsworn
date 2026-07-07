extends SceneTree

# One-shot dev tool (Story 10.3; seed list expanded + fairness verdict updated by Story 10.8): dump the
# consolidated GENERATOR SOFT-LOCK + FAIRNESS batch report for the shared Small + Medium seed catalog — per
# recipe + seed, the LevelValidator (soft-lock/placement/reward/first-reveal) verdict PLUS the
# DarknessFairnessQuery (FR58) verdict under the Darkness affinity. Used to eyeball / reproduce the batch pinned
# in tests/integration/test_generator_fairness_batch.gd. NOTE (Story 10.8): the 10.3-recorded Darkness FR58
# finding on Medium seeds 4004 + 5005 (`darkness_unseen_hazard`) is RESOLVED — predicate (b) was strengthened to
# moving reduced-radius LoS (seen-before-contact), so those reachable hazards are now fair (seen from an adjacent
# step-from cell before contact) and every generated Darkness board reports `darkness_ok` (see the readiness
# ledger _bmad-output/planning-artifacts/generator-fairness-batch-readiness.md §4).
#
# NOT a test (lives under tools/, NOT auto-discovered by the headless runner; excluded from every export
# preset via the tools/** exclude_filter — it provably cannot ship). DEBUG/report tool: it grants NO
# progression and writes NO `user://` artifact (it only prints). It REUSES the two canonical validators
# (LevelValidator + DarknessFairnessQuery) — it forks NO parallel soft-lock/fairness algorithm. Run via
# PowerShell (the `godot` binary resolves via C:\Users\Rasmus\bin\godot.cmd):
#   godot --headless --path C:\Sealsworn\godot --script res://tools/dump_generator_fairness_report.gd

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DarknessFairnessQuery = preload("res://scripts/generation/level/darkness_fairness_query.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const LevelValidator = preload("res://scripts/generation/level/level_validator.gd")

func _init() -> void:
	# Story 10.8: the shared Small/Medium catalog expanded 5 -> 50 (the original 5 kept byte-identical + 45 appended).
	var seeds: Array[int] = [
		1001, 2002, 3003, 4004, 5005,
		1, 2, 3, 5, 7, 13, 42, 99, 123, 256,
		314, 512, 777, 1024, 1234, 2026, 2718, 3141, 4242, 5555,
		6006, 7007, 8008, 8675309, 9999, 12345, 31415, 55555, 65536, 77777,
		88888, 100003, 123456, 161803, 271828, 314159, 500009, 654321, 1000003, 1048576,
		2000003, 7777777, 16777216, 999999937, 123456789
	]
	var recipes := LevelRecipeRepository.create_baseline_repository()
	var enemies := EnemyRepository.create_baseline_repository()
	var affinities := AffinityRepository.create_baseline_repository()
	var validator := LevelValidator.new()
	var query := DarknessFairnessQuery.new()

	for entry: Dictionary in [
		{"recipe_id": &"small_combat_basic", "size_class": GenerationRequest.SIZE_SMALL},
		{"recipe_id": &"medium_combat_basic", "size_class": GenerationRequest.SIZE_MEDIUM}
	]:
		var recipe_id: StringName = entry.get("recipe_id")
		var size_class: StringName = entry.get("size_class")
		print("=== %s ===" % String(recipe_id))
		for seed_value: int in seeds:
			var request := GenerationRequest.new(
				seed_value, &"node_1", &"combat", recipe_id,
				size_class, GenerationRequest.DIFFICULTY_STANDARD,
				GenerationRequest.AFFINITY_NONE, {}
			)
			var generation: GenerationResult = LevelGenerator.generate(request, recipes, enemies)
			if not generation.succeeded:
				print("[FAIL] %s / seed %d: GENERATE phase=%s code=%s reason=%s" % [
					String(recipe_id), seed_value,
					String(generation.failed_phase), String(generation.error_code), String(generation.reason)
				])
				continue

			var validation_verdict: String = _validation_verdict(validator, generation.payload)
			var fairness_verdict: String = _fairness_verdict(query, affinities, generation.payload, str(seed_value))
			var overall: String = "PASS" if (validation_verdict == "ok" and fairness_verdict.begins_with("darkness_ok")) else "FLAG"
			print("[%s] %s / seed %d: validation=%s | %s" % [
				overall, String(recipe_id), seed_value, validation_verdict, fairness_verdict
			])
	quit()


# The LevelValidator verdict over the reconstructed candidate (the SAME validator the pipeline ran) — "ok" on
# pass, or the stable code + phase on a (belt-and-suspenders) failure.
func _validation_verdict(validator: LevelValidator, payload: Dictionary) -> String:
	var candidate: Dictionary = _candidate_from_payload(payload)
	if candidate.get("board") == null:
		return "invalid_candidate(board_rehydrate_failed)"
	var validation: ActionResult = validator.validate(candidate)
	if validation.succeeded:
		return "ok"
	return "%s(phase=%s)" % [String(validation.error_code), String(LevelValidator.phase_for_code(validation.error_code))]


# The DarknessFairnessQuery verdict under the Darkness affinity — "darkness_ok(hazards=N)" on pass, or the
# fairness reason + offending hazard cell on a FAIL (the FR58 finding surface).
func _fairness_verdict(query: DarknessFairnessQuery, affinities: AffinityRepository, payload: Dictionary, seed_text: String) -> String:
	var board: BoardState = BoardState.from_snapshot(payload.get("board"))
	if board == null:
		return "darkness_fairness(board_rehydrate_failed)"
	var check: ActionResult = query.check_board(board, &"darkness", affinities, seed_text)
	if check.succeeded:
		return "darkness_ok(hazards=%d, reachable_seen=%d)" % [
			int(check.metadata.get("hazard_count", 0)), int(check.metadata.get("reachable_seen_hazard_count", 0))
		]
	var hazard_cell: Dictionary = check.metadata.get("hazard_cell", {})
	return "darkness_FAIL:%s at (%s,%s) phase=%s" % [
		String(check.metadata.get("fairness_reason", "")),
		str(hazard_cell.get("x", "?")), str(hazard_cell.get("y", "?")),
		String(check.metadata.get("phase", ""))
	]


# Reconstruct the built candidate ({layout, board, rewards}) from a generate payload the SAME way the batch
# test does (no second candidate shape). Mirrors test_generator_fairness_batch.gd::_candidate_from_payload.
func _candidate_from_payload(payload: Dictionary) -> Dictionary:
	var board_snapshot: Dictionary = payload.get("board", {})
	var width: int = int(board_snapshot.get("width", 0))
	var height: int = int(board_snapshot.get("height", 0))
	var cells: Array = board_snapshot.get("cells", [])

	var terrain_grid: Array = []
	for _y: int in range(height):
		var row: Array = []
		row.resize(width)
		terrain_grid.append(row)
	for cell_value: Variant in cells:
		var cell: Dictionary = cell_value
		var position: Dictionary = cell.get("position", {})
		var x: int = int(position.get("x", -1))
		var y: int = int(position.get("y", -1))
		(terrain_grid[y] as Array)[x] = int(cell.get("terrain", 0))

	var layout: Dictionary = {
		"width": width,
		"height": height,
		"entrance": payload.get("entrance", {}),
		"exit": payload.get("exit", {}),
		"terrain": terrain_grid,
		"rewards": payload.get("rewards", [])
	}
	var build: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	var board: BoardState = null
	if build.succeeded:
		board = build.metadata.get("board") as BoardState
	return {"layout": layout, "board": board, "rewards": payload.get("rewards", [])}
