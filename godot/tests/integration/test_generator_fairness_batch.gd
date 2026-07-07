extends "res://tests/unit/test_case.gd"

# Story 10.3 — the GENERATOR SOFT-LOCK + FAIRNESS BATCH harness (AC1–AC4). The generator-safety analog of
# 10.1 (performance) and 10.2 (seed determinism): a SINGLE headless BATCH driver that COMPOSES the two
# EXISTING validators over a SAMPLE of Small + Medium seeds (and each level's affinity), reports a per-seed
# PASS/FAIL with compact `seed + phase + reason` (+ `affinity` for the fairness half) diagnostics, applies
# the AC4 zero-tolerance + ≤ 1% bounded-retry-exhaustion readiness THRESHOLDS, flags out-of-threshold
# recipes/rules/retry-limits for tuning, and PRESERVES + TAGS every failing seed for reproduction.
#
# ⭐ THE #1 DISCIPLINE (mirrors 10.2's `_consolidated_pins_agree_with_live_canonical_sources`, 3.7/4.2's
# fingerprint cross-checks): this harness REUSES the two canonical validators — it does NOT fork a parallel
# soft-lock/fairness algorithm. The SINGLE canonical soft-lock/reachability/placement/reward/readability/
# safe-first-reveal check is `LevelValidator.validate(candidate)`; the SINGLE canonical affinity-fairness
# check is `DarknessFairnessQuery.check_board(...)`. This harness CALLS those and ASSERTS their verdicts over
# the batch. Where it needs the built candidate to feed `LevelValidator`, it reconstructs it from the
# `LevelGenerator.generate` payload the SAME way `test_seed_batch_regression.gd::_terrain_fingerprint_from_payload`
# does (plus `BoardState.try_from_snapshot(payload.board)` for the entity-aware board + `payload.rewards`) —
# it does NOT hand-build a parallel candidate shape.
#
# READ-ONLY over the generation domain: `LevelValidator.validate` + `DarknessFairnessQuery.check_board` are
# PURE (draw no RNG, mutate nothing); this harness draws no gameplay RNG beyond what `LevelGenerator.generate`
# + `RunOrchestrator.assign_affinity` already draw per seed. It re-pins NO terrain fingerprint (the fairness
# half only READS validator verdicts), changes NO generator/validator/RNG/save invariant, and adds NO new
# gameplay or fairness rule. The full headless suite stays green + byte-for-byte behaviorally unchanged.
#
# SAMPLE-SIZE HONESTY (the 10.1/10.2 posture): the batch drives the FULL approved shared catalog. Story 10.8
# EXPANDED it 5 -> 50 (50 Small + 50 Medium), COORDINATED with the 10.1 level-load harness + the 10.2
# consolidated suite (all three Epic-10 harnesses draw the SAME 50-seed catalog — never desynced), so the
# `50 Small / 50 Medium` MVP-readiness target is now MET (see the durable ledger
# `_bmad-output/planning-artifacts/generator-fairness-batch-readiness.md` §5). All 50 seeds PASS by
# construction on the unperturbed attempt 0; the fairness half re-pins NO terrain fingerprint (it only READS
# validator verdicts).
#
# SCOPE GUARDS (do NOT build here): no generator/layout/`LevelValidator`/`DarknessFairnessQuery`/RNG/
# `GenerationResult`-phase/fingerprint change; no affinity-driven GENERATION modifier (the affinity is assigned
# POST-generation onto an affinity-blind board — the shipped v0 posture); no Flooded electric-chain realization
# (that is 10.7's `_placeholder` item — this harness only REFLECTS the Flooded fairness verdict).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DarknessFairnessQuery = preload("res://scripts/generation/level/darkness_fairness_query.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const LevelValidator = preload("res://scripts/generation/level/level_validator.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

# ---- the batch sample (AC1/AC4) ------------------------------------------------------------------
#
# The SHARED Epic-10 generation seed catalog: the SAME 50 seeds the 10.1 level-load harness + the 10.2
# regression suite (+ the 3.7 batch) draw over, for BOTH baseline recipes. Story 10.8 EXPANDED it 5 -> 50
# (the original 5 preserved byte-identical + 45 appended), COORDINATED across all three Epic-10 harnesses
# (never desynced in isolation). These approved seeds PASS `LevelValidator` on the unperturbed attempt 0, so
# the zero-tolerance thresholds are MET by construction (failure rate 0%, attempts == 1).
const BATCH_SEEDS: Array[int] = [
	1001, 2002, 3003, 4004, 5005,
	1, 2, 3, 5, 7, 13, 42, 99, 123, 256,
	314, 512, 777, 1024, 1234, 2026, 2718, 3141, 4242, 5555,
	6006, 7007, 8008, 8675309, 9999, 12345, 31415, 55555, 65536, 77777,
	88888, 100003, 123456, 161803, 271828, 314159, 500009, 654321, 1000003, 1048576,
	2000003, 7777777, 16777216, 999999937, 123456789
]

# The two baseline recipes driven through the batch (the v0 Small + Medium recipes). A "recipe batch" for the
# AC3/AC4 failure-rate + retry-exhaustion threshold is one of these driven over BATCH_SEEDS.
const BATCH_RECIPES: Array[Dictionary] = [
	{"recipe_id": "small_combat_basic", "size_class": "small"},
	{"recipe_id": "medium_combat_basic", "size_class": "medium"}
]

# ---- the AC4 readiness thresholds (stated verbatim; asserted below) ------------------------------
#
# AC4 ZERO-TOLERANCE classes: 0 soft-locks, 0 mandatory class/item gates, 0 unreachable mandatory exits,
# 0 unreachable intended mandatory rewards, 0 unavoidable untelegraphed first-reveal punishments. Stated as
# the `LevelValidator` codes + the `DarknessFairnessQuery` reason that realize each class (the batch asserts
# ZERO of these across the sample — met by construction for the approved catalog).
const ZERO_TOLERANCE_CODES: Array[StringName] = [
	LevelValidator.CODE_SOFT_LOCK_DETECTED,        # 0 soft-locks
	LevelValidator.CODE_REQUIRED_GATE_PRESENT,     # 0 mandatory class/item gates
	LevelValidator.CODE_UNREACHABLE_EXIT,          # 0 unreachable mandatory exits
	LevelValidator.CODE_UNREACHABLE_REWARD,        # 0 unreachable intended mandatory rewards
	LevelValidator.CODE_UNSAFE_FIRST_REVEAL,       # 0 unavoidable untelegraphed first-reveal punishments
	LevelValidator.CODE_ILLEGAL_ENEMY_PLACEMENT    # 0 illegal placement (a precondition for solvability)
]

# AC4 bounded-retry-exhaustion threshold: ≤ 1% per recipe batch. `LevelGenerator.generate` retries up to
# MAX_GENERATION_ATTEMPTS (8) deterministically-perturbed candidates; an exhausting seed returns a structured
# error with attempts == 8. exhaustions / batch_size must stay at or below this ratio per recipe.
const MAX_RETRY_EXHAUSTION_RATE: float = 0.01

func run() -> Dictionary:
	# AC1 — batch generator validation over the Small + Medium sample.
	_batch_generate_passes_with_stable_status_and_compact_report()
	_batch_direct_validate_confirms_every_zero_tolerance_code_clear()
	_forced_failure_shape_carries_seed_phase_reason_and_exhausts_bounded_retry()
	# AC2 — affinity / Darkness fairness over the batch.
	_batch_darkness_fairness_verdict_recorded_for_every_generated_board()
	_batch_fairness_verdict_asserted_for_every_implemented_affinity()
	_assigned_affinity_fairness_reflects_the_query_verdict()
	_unseen_hazard_fails_and_seen_hazard_passes_reflecting_the_query()
	# AC3/AC4 — failure-rate threshold, tuning flag, failing-seed preservation, zero-tolerance thresholds.
	_zero_tolerance_and_retry_exhaustion_thresholds_hold_for_the_approved_catalog()
	_threshold_breach_flags_recipe_rule_retry_limit_and_preserves_failing_seed()
	_real_darkness_finding_flags_recipe_rule_and_preserves_failing_seeds()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _recipes() -> LevelRecipeRepository:
	return LevelRecipeRepository.create_baseline_repository()


func _enemies() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


func _affinity_repository() -> AffinityRepository:
	return AffinityRepository.create_baseline_repository()


func _request_for(seed_value: int, recipe: Dictionary) -> GenerationRequest:
	var size_class: StringName = StringName(String(recipe.get("size_class")))
	return GenerationRequest.new(
		seed_value, &"node_1", &"combat", StringName(String(recipe.get("recipe_id"))),
		size_class, GenerationRequest.DIFFICULTY_STANDARD, GenerationRequest.AFFINITY_NONE, {}
	)


# Reconstruct the built candidate ({layout, board, rewards}) from a GenerationResult payload the SAME way
# test_seed_batch_regression.gd reconstructs the terrain (row-major terrain grid from the board snapshot
# cells) PLUS BoardState.try_from_snapshot(payload.board) for the entity-aware board + payload.rewards for the
# reward markers. This is the candidate LevelValidator.validate consumes — NOT a hand-built parallel shape.
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

	# The entity-aware board from the SAME strict parser the generator uses (validate-then-reject).
	var build: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	var board: BoardState = null
	if build.succeeded:
		board = build.metadata.get("board") as BoardState

	return {
		"layout": layout,
		"board": board,
		"rewards": payload.get("rewards", [])
	}


# The compact failure line every batch assert carries (seed + phase + reason — NEVER a grid/board dump). For
# a generate failure the phase/reason come from GenerationResult.failed_phase/reason; for a direct-validate
# failure the phase comes from LevelValidator.phase_for_code(code) and the reason from the metadata.
func _generate_failure_line(seed_value: int, recipe_id: String, generation: GenerationResult) -> String:
	return "seed=%d recipe=%s phase=%s reason=%s (code=%s)" % [
		seed_value, recipe_id,
		String(generation.failed_phase), String(generation.reason), String(generation.error_code)
	]


func _validate_failure_line(seed_value: int, recipe_id: String, validation: ActionResult) -> String:
	return "seed=%d recipe=%s phase=%s reason=%s (code=%s)" % [
		seed_value, recipe_id,
		String(LevelValidator.phase_for_code(validation.error_code)),
		String(validation.metadata.get("reason", "")),
		String(validation.error_code)
	]


# Build a BoardState from a terrain grid + optional enemy entities (the 7.6 test's hand-built-candidate
# pattern — mirror build_board_snapshot's occupant invariant so a blocking entity's cell carries its
# occupant_id). Used ONLY to exercise the DarknessFairnessQuery FAIL branch (a hand-built unseen hazard) —
# NEVER to feed LevelValidator over a batch level (those come from the real generate payload).
func _board_from_grid(width: int, height: int, terrain_grid: Array, entities: Array = []) -> BoardState:
	var occupant_by_cell: Dictionary = {}
	for entity_value: Variant in entities:
		var entity: Dictionary = entity_value
		if bool(entity.get("blocks_movement", true)):
			var pos: Dictionary = entity.get("position")
			occupant_by_cell[Vector2i(int(pos.get("x")), int(pos.get("y")))] = String(entity.get("entity_id"))
	var cells: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": int((terrain_grid[y] as Array)[x]),
				"occupant_id": occupant_by_cell.get(Vector2i(x, y), ""),
				"explored": false,
				"visible": false
			})
	var snapshot: Dictionary = {
		"width": width,
		"height": height,
		"next_sequence_id": 1,
		"cells": cells,
		"entities": entities.duplicate(true)
	}
	var build: ActionResult = BoardState.try_from_snapshot(snapshot)
	assert_true(build.succeeded, "Setup: the hand-built fairness board should build. Error: %s" % build.metadata)
	return build.metadata.get("board") as BoardState


# An open WALL-ring grid with ENTRANCE central-left + EXIT central-right (the 7.6 fair-layout shape).
func _open_grid(width: int, height: int) -> Array:
	var corridor_row: int = height / 2
	var grid: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			var terrain: int = BoardCell.Terrain.FLOOR
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 1 and y == corridor_row:
				terrain = BoardCell.Terrain.ENTRANCE
			elif x == width - 2 and y == corridor_row:
				terrain = BoardCell.Terrain.EXIT
			row.append(terrain)
		grid.append(row)
	return grid


func _first_node(orchestrator: RunOrchestrator) -> RouteNode:
	var nodes: Array[RouteNode] = orchestrator.run.route.nodes()
	assert_true(nodes.size() >= 1, "A started run must have at least one route node.")
	return nodes[0]


# The SINGLE live classifier for the Darkness fairness half over the batch — the one place the batch drives
# every (recipe, seed) through the REAL generator + DarknessFairnessQuery.check_board(..., &"darkness", ...)
# and CLASSIFIES the verdict. Returns a dict:
#   verdict_count       : how many levels got a verdict (must equal BATCH_SEEDS x BATCH_RECIPES = 50 Small + 50 Medium).
#   passes              : Array of {recipe_id, seed} that PASS the Darkness fairness check.
#   darkness_failures   : Array of preserved findings {recipe_id, seed(str), seed_int, affinity_id,
#                         fairness_reason, phase, hazard_cell?} for levels that FAIL under Darkness.
#   small_failures      : the subset of failures on the Small recipe (expected EMPTY — Small is all-FLOOR).
# It REFLECTS the query's verdict (does NOT re-derive the reachable-hazard-unseen predicate). Pure over the
# domain (the query + generate draw only what they already draw per seed).
func _classify_darkness_fairness_over_batch() -> Dictionary:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()
	var affinities: AffinityRepository = _affinity_repository()
	var query: DarknessFairnessQuery = DarknessFairnessQuery.new()

	var verdict_count: int = 0
	var passes: Array[Dictionary] = []
	var darkness_failures: Array[Dictionary] = []
	var small_failures: Array[Dictionary] = []

	for recipe: Dictionary in BATCH_RECIPES:
		var recipe_id: String = String(recipe.get("recipe_id"))
		var size_class: String = String(recipe.get("size_class"))
		for seed_value: int in BATCH_SEEDS:
			var generation: GenerationResult = LevelGenerator.generate(_request_for(seed_value, recipe), recipes, enemies)
			assert_true(generation.succeeded, "Fairness classify setup: seed=%d recipe=%s must generate. %s" % [seed_value, recipe_id, _generate_failure_line(seed_value, recipe_id, generation)])
			if not generation.succeeded:
				continue
			var seed_text: String = String(generation.payload.get("level_seed", str(seed_value)))
			var board: BoardState = BoardState.from_snapshot(generation.payload.get("board"))
			assert_true(board != null, "Fairness classify setup: seed=%d recipe=%s board must rehydrate." % [seed_value, recipe_id])

			var check: ActionResult = query.check_board(board, &"darkness", affinities, seed_text)
			verdict_count += 1
			if check.succeeded:
				passes.append({"recipe_id": recipe_id, "seed": seed_value})
			else:
				var finding: Dictionary = {
					"recipe_id": recipe_id,
					"seed": seed_text,
					"seed_int": seed_value,
					"affinity_id": String(check.metadata.get("affinity_id", "darkness")),
					"fairness_reason": String(check.metadata.get("fairness_reason", "")),
					"phase": String(check.metadata.get("phase", "")),
					"hazard_cell": check.metadata.get("hazard_cell", {})
				}
				darkness_failures.append(finding)
				if size_class == "small":
					small_failures.append(finding)

	return {
		"verdict_count": verdict_count,
		"passes": passes,
		"darkness_failures": darkness_failures,
		"small_failures": small_failures
	}


# ---- AC1: batch generator validation over Small + Medium seeds -----------------------------------

# AC1: drive the FULL shared Small + Medium catalog through the REAL generation + validation path
# (LevelGenerator.generate with the default LevelValidator) and assert, per seed: succeeded == true,
# diagnostics.validated == true, attempts == 1 (validated on the UNPERTURBED attempt 0). EVERY failure assert
# carries seed + phase + reason (compact, no grid dump). The per-candidate checks already exist in
# LevelValidator — AC1 BATCHES them under one reporting contract.
func _batch_generate_passes_with_stable_status_and_compact_report() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()

	for recipe: Dictionary in BATCH_RECIPES:
		var recipe_id: String = String(recipe.get("recipe_id"))
		for seed_value: int in BATCH_SEEDS:
			var generation: GenerationResult = LevelGenerator.generate(_request_for(seed_value, recipe), recipes, enemies)
			# AC1 failure reporting: the compact seed + phase + reason line (never a grid dump).
			assert_true(
				generation.succeeded,
				"AC1: batch generate FAILED for an approved seed. %s" % _generate_failure_line(seed_value, recipe_id, generation)
			)
			if not generation.succeeded:
				continue
			# Validation status STABLE: validated on the unperturbed attempt 0 (a perturbation would drift the
			# pinned terrain — the fingerprint invariant this batch protects).
			assert_true(
				bool(generation.diagnostics.get("validated", false)),
				"AC1: approved seed=%d recipe=%s must report validated == true (LevelValidator passed in-pipeline)." % [seed_value, recipe_id]
			)
			assert_equal(
				int(generation.diagnostics.get("attempts", -1)), 1,
				"AC1: approved seed=%d recipe=%s must pass on attempt 0 (attempts == 1) — a retry would perturb the terrain." % [seed_value, recipe_id]
			)
			assert_equal(
				String(generation.payload.get("level_seed", "")), str(seed_value),
				"AC1: approved seed=%d recipe=%s payload.level_seed must carry the seed string." % [seed_value, recipe_id]
			)


# AC1 (the zero-tolerance evidence): reconstruct the built candidate from the generate payload and run
# LevelValidator.validate DIRECTLY over it — the SAME validator the pipeline uses (no second algorithm) —
# asserting ActionResult.ok so the EXACT soft-lock/placement/reward/first-reveal codes are individually clear,
# not just that generate succeeded. The direct re-run is the AC1 belt-and-suspenders evidence per named check.
func _batch_direct_validate_confirms_every_zero_tolerance_code_clear() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()
	var validator: LevelValidator = LevelValidator.new()

	for recipe: Dictionary in BATCH_RECIPES:
		var recipe_id: String = String(recipe.get("recipe_id"))
		for seed_value: int in BATCH_SEEDS:
			var generation: GenerationResult = LevelGenerator.generate(_request_for(seed_value, recipe), recipes, enemies)
			assert_true(generation.succeeded, "AC1 setup: seed=%d recipe=%s must generate. %s" % [seed_value, recipe_id, _generate_failure_line(seed_value, recipe_id, generation)])
			if not generation.succeeded:
				continue

			var candidate: Dictionary = _candidate_from_payload(generation.payload)
			assert_true(candidate.get("board") != null, "AC1 setup: seed=%d recipe=%s board snapshot must rehydrate." % [seed_value, recipe_id])

			# The SAME LevelValidator the pipeline ran — the belt-and-suspenders re-run surfacing the exact clear
			# codes (unreachable_exit / illegal_enemy_placement / soft_lock_detected / required_gate_present /
			# unreachable_reward / excessive_blockage / unreadable_first_reveal / unsafe_first_reveal all clear).
			var validation: ActionResult = validator.validate(candidate)
			assert_true(
				validation.succeeded,
				"AC1: LevelValidator.validate must PASS for approved seed. %s" % _validate_failure_line(seed_value, recipe_id, validation)
			)
			# The pass report carries the AC1 named-check evidence (compact counts, never a grid dump): the exit is
			# reachable, mandatory rewards are counted, the entrance is safe (no unsafe_first_reveal / darkness code).
			assert_true(
				int(validation.metadata.get("terrain_reachable_cell_count", 0)) > 0,
				"AC1: seed=%d recipe=%s pass report must count reachable terrain (exit reachable)." % [seed_value, recipe_id]
			)
			assert_true(
				validation.metadata.has("mandatory_reward_count"),
				"AC1: seed=%d recipe=%s pass report must count mandatory rewards (reachable-reward evidence)." % [seed_value, recipe_id]
			)


# AC1/AC3: the FORCED-FAILURE shape — inject an ALWAYS-FAIL validator via LevelGenerator.generate's optional
# 4th `validator` param (the 3.6 test seam) so the harness can NEVER silently pass a soft-lock/fairness
# regression. Assert the GenerationResult.error carries seed + failed_phase + error_code + reason AND
# attempts == MAX_GENERATION_ATTEMPTS (bounded-retry EXHAUSTION), and that the failing seed is captured for
# preservation (the AC3 preserved-seed record).
func _forced_failure_shape_carries_seed_phase_reason_and_exhausts_bounded_retry() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()
	var always_fail: AlwaysFailValidator = AlwaysFailValidator.new()

	var seed_value: int = 1001
	var recipe: Dictionary = BATCH_RECIPES[0]
	var recipe_id: String = String(recipe.get("recipe_id"))
	var generation: GenerationResult = LevelGenerator.generate(_request_for(seed_value, recipe), recipes, enemies, always_fail)

	assert_true(generation.is_error(), "AC3: an always-fail validator must drive a generation FAILURE (the harness can never silently pass a regression).")
	# The failure carries the compact reporting contract: seed + failed_phase + error_code + reason.
	assert_equal(generation.seed, str(seed_value), "AC3: a forced failure carries the seed string for reporting.")
	assert_true(GenerationResult.is_known_phase(generation.failed_phase), "AC3: a forced failure carries a known GenerationResult phase.")
	assert_equal(generation.error_code, AlwaysFailValidator.FORCED_CODE, "AC3: the forced failure surfaces the injected validator's code (mapped through phase_for_code).")
	assert_false(String(generation.reason).strip_edges().is_empty(), "AC3: a forced failure carries a non-empty reason.")
	# BOUNDED-RETRY EXHAUSTION: an always-failing candidate burns all MAX_GENERATION_ATTEMPTS.
	assert_equal(
		int(generation.diagnostics.get("attempts", -1)), LevelGenerator.MAX_GENERATION_ATTEMPTS,
		"AC3: an always-fail validator exhausts the bounded retry (attempts == MAX_GENERATION_ATTEMPTS == %d)." % LevelGenerator.MAX_GENERATION_ATTEMPTS
	)

	# The failing seed is CAPTURED for preservation (the AC3 preserved-seed record — kept + annotated with the
	# failing phase/reason/recipe so it is reproducible; never silently discarded).
	var preserved: Dictionary = _preserved_seed_record(seed_value, recipe_id, generation)
	assert_equal(int(preserved.get("seed")), seed_value, "AC3: the preserved record carries the failing seed.")
	assert_equal(String(preserved.get("recipe_id")), recipe_id, "AC3: the preserved record carries the recipe for reproduction.")
	assert_false(String(preserved.get("phase")).is_empty(), "AC3: the preserved record carries the failing phase.")
	assert_false(String(preserved.get("reason")).is_empty(), "AC3: the preserved record carries the failing reason.")


# ---- AC2: affinity / Darkness fairness over the batch --------------------------------------------

# AC2: for each batch level, run DarknessFairnessQuery.check_board over the level's board with the DARKNESS
# affinity and RECORD the FR58 verdict (the check ran for every batch level — "a batch level whose affinity
# fairness is unchecked = AC2 not met"). ⭐ STORY 10.8 DELIBERATE FLIP: 10.3 recorded an HONEST FINDING here —
# the Medium tactical-wrinkle phase bakes HAZARD terrain into seeds 4004/5005, and under the v0
# static-from-ENTRANCE predicate those reachable hazards were UNSEEN at the Darkness-reduced radius (2) and so
# FAILED `darkness_unseen_hazard`. Story 10.8 STRENGTHENED predicate (b) to MOVING reduced-radius LoS
# (seen-before-contact): a reachable hazard is fair iff the hero necessarily SEES it from a reachable adjacent
# step-from cell before contact — which is true for EVERY reachable v0 hazard (hazards walkable +
# sight-transparent + reduced radius >= 1 + unoccludable adjacent LoS). So the generated-board Darkness
# classification now yields ZERO failures (Small AND Medium PASS); the batch's honest verdict becomes "generated
# Darkness boards meet the FR58 zero-tolerance bar." The forced/hand-built FAIL-path coverage (predicate (a) +
# AlwaysFailValidator) stays exercised below so the flag+preserve machinery is still proven.
func _batch_darkness_fairness_verdict_recorded_for_every_generated_board() -> void:
	var classification: Dictionary = _classify_darkness_fairness_over_batch()

	# The check produced a verdict for EVERY batch level (AC2 "unchecked = not met"): 50 Small + 50 Medium.
	assert_equal(
		int(classification.get("verdict_count")), BATCH_SEEDS.size() * BATCH_RECIPES.size(),
		"AC2: the Darkness fairness check must produce a verdict for every batch level (BATCH_SEEDS x BATCH_RECIPES)."
	)

	# Small levels are all-FLOOR -> every Small Darkness verdict PASSES (fair by construction).
	var small_failures: Array = classification.get("small_failures", [])
	assert_true(
		small_failures.is_empty(),
		"AC2: every Small Darkness level must pass the fairness check (Small is all-FLOOR). Failures: %s" % str(small_failures)
	)

	# Story 10.8: under the strengthened moving-LoS predicate the generated-board Darkness failure set is now EMPTY
	# (every reachable Medium hazard, incl. 4004/5005, is seen-before-contact -> PASS). The per-finding shape assertions
	# below stay but now iterate an empty set — if a FUTURE generator change ever bakes a genuinely
	# unseen-before-contact hazard (a sight-blocking hazard, which v0 has none of), this loop re-asserts the shape.
	for finding: Dictionary in classification.get("darkness_failures", []):
		assert_equal(String(finding.get("affinity_id")), "darkness", "AC2: a Darkness fairness failure is TAGGED by affinity (darkness).")
		assert_equal(String(finding.get("fairness_reason")), String(DarknessFairnessQuery.REASON_UNSEEN_HAZARD), "AC2: a generated Darkness fairness failure is the darkness_unseen_hazard FR58 class.")
		assert_false(String(finding.get("seed")).is_empty(), "AC2: a Darkness fairness failure carries the seed.")
		assert_equal(String(finding.get("phase")), "validation", "AC2: a Darkness fairness failure reports the validation phase.")
		assert_false(String(finding.get("recipe_id")).is_empty(), "AC2: a Darkness fairness failure carries the recipe (for reproduction/tuning).")

	# ⭐ STORY 10.8: the generated-board Darkness failure set is now EMPTY (Medium 4004/5005 flipped to PASS under
	# moving-LoS). If a future generator change bakes a genuinely unseen-before-contact hazard, this fails LOUD so the
	# readiness ledger is re-verified (no silent drift) — the same fail-loud tripwire, now guarding the ZERO-failure
	# invariant instead of the [4004,5005] set.
	var medium_darkness_fail_seeds: Array[int] = []
	for finding: Dictionary in classification.get("darkness_failures", []):
		medium_darkness_fail_seeds.append(int(finding.get("seed_int")))
	medium_darkness_fail_seeds.sort()
	assert_equal(
		medium_darkness_fail_seeds, [] as Array[int],
		"AC2 (Story 10.8): the generated-board Darkness fairness failures are now EMPTY — every reachable Medium hazard (incl. 4004/5005) is seen-before-contact under the strengthened moving-LoS predicate. A NON-empty set here means the generator baked a genuinely unseen-before-contact hazard; re-verify the readiness ledger, do NOT silence."
	)


# AC2: cover ALL FOUR implemented affinities + neutral `none` (AffinityRepository.BASELINE_AFFINITY_IDS) over a
# batch level so the batch demonstrably RAN the fairness check for every affinity, not just Darkness. Darkness
# is the reduced-radius affinity (the query's active branch — it PASSES for the all-FLOOR generated board);
# Scorched/Flooded/Cursed/neutral return the legal `not_a_darkness_level` PASS (no reduced radius to re-assert).
# A failure carries the affinity tag.
func _batch_fairness_verdict_asserted_for_every_implemented_affinity() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()
	var affinities: AffinityRepository = _affinity_repository()
	var query: DarknessFairnessQuery = DarknessFairnessQuery.new()

	# One representative batch level (the shared catalog's first Small seed) driven through the real generator.
	var generation: GenerationResult = LevelGenerator.generate(_request_for(1001, BATCH_RECIPES[0]), recipes, enemies)
	assert_true(generation.succeeded, "AC2 setup: representative level must generate.")
	var seed_text: String = String(generation.payload.get("level_seed", "1001"))
	var board: BoardState = BoardState.from_snapshot(generation.payload.get("board"))
	assert_true(board != null, "AC2 setup: representative board must rehydrate.")

	# Every implemented baseline affinity (+ neutral) has its fairness verdict asserted (the 10.2 affinity-sample
	# honesty posture: an affinity that surfaces in the sample MUST have its verdict asserted).
	for affinity_id: StringName in AffinityRepository.BASELINE_AFFINITY_IDS:
		var check: ActionResult = query.check_board(board, affinity_id, affinities, seed_text)
		assert_true(
			check.succeeded,
			"AC2: the fairness check must return a verdict for affinity=%s. seed=%s reason=%s" % [
				String(affinity_id), seed_text, String(check.metadata.get("fairness_reason", ""))
			]
		)
		if affinity_id == &"darkness":
			# Darkness is the reduced-radius affinity — the ACTIVE fairness branch (applicable; passes for all-FLOOR).
			assert_equal(check.metadata.get("darkness_fairness_applicable"), true, "AC2: Darkness is the reduced-radius affinity — the fairness check APPLIES.")
		else:
			# Scorched / Flooded-Conductive / Cursed / neutral `none`: the legal not_a_darkness_level PASS (no reduced
			# radius to re-assert). The batch REFLECTS this verdict (10.7 owns the Flooded electric-chain placeholder,
			# NOT 10.3 — Flooded has no FR58 unseen-hazard risk, so its fairness verdict is not_a_darkness_level).
			assert_equal(
				check.metadata.get("darkness_fairness_applicable"), false,
				"AC2: affinity=%s is not a reduced-radius affinity — the Darkness fairness check does not apply (legal not_a_darkness_level PASS)." % String(affinity_id)
			)
			assert_equal(String(check.metadata.get("reason", "")), "not_a_darkness_level", "AC2: a non-Darkness affinity reports the not_a_darkness_level pass reason.")


# AC2: assign the affinity via the 7.4 contract (RunOrchestrator.assign_affinity on the `map` stream) and run
# the fairness check over the ASSIGNED affinity for a real batch level — proving the batch reflects the query
# verdict for the affinity the run actually assigns (not a hand-picked id). REFLECTS the query verdict; does
# NOT re-derive a second fairness predicate.
func _assigned_affinity_fairness_reflects_the_query_verdict() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()
	var affinities: AffinityRepository = _affinity_repository()
	var query: DarknessFairnessQuery = DarknessFairnessQuery.new()

	for seed_value: int in BATCH_SEEDS:
		# Assign the affinity for this seed's first route node via the `map`-stream 7.4 contract.
		var orchestrator: RunOrchestrator = RunOrchestrator.new(null, null, null, null, null, affinities)
		assert_true(orchestrator.start(seed_value, false).succeeded, "AC2 setup: seed=%d run should start." % seed_value)
		var node: RouteNode = _first_node(orchestrator)
		var assign: ActionResult = orchestrator.assign_affinity(node)
		assert_true(assign.succeeded, "AC2 setup: seed=%d affinity assign should succeed: %s" % [seed_value, assign.metadata])
		var assigned_id: StringName = StringName(String(assign.metadata.get("affinity_id")))
		assert_true(AffinityRepository.BASELINE_AFFINITY_IDS.has(assigned_id), "AC2: the assigned affinity must be a real baseline id.")

		# Generate a level for the same seed + run the fairness check over the ASSIGNED affinity.
		var generation: GenerationResult = LevelGenerator.generate(_request_for(seed_value, BATCH_RECIPES[0]), recipes, enemies)
		assert_true(generation.succeeded, "AC2 setup: seed=%d level must generate." % seed_value)
		var seed_text: String = String(generation.payload.get("level_seed", str(seed_value)))
		var board: BoardState = BoardState.from_snapshot(generation.payload.get("board"))

		var check: ActionResult = query.check_board(board, assigned_id, affinities, seed_text)
		# The assigned-affinity fairness verdict PASSES: Darkness passes (all-FLOOR), the rest are not_a_darkness_level.
		assert_true(
			check.succeeded,
			"AC2: the fairness check over the ASSIGNED affinity must pass for a generated level. affinity=%s seed=%s phase=%s reason=%s" % [
				String(assigned_id), seed_text, String(check.metadata.get("phase", "")), String(check.metadata.get("fairness_reason", ""))
			]
		)
		# The verdict carries the affinity tag (AC2 "failures are tagged by affinity" — the tag is present on the
		# pass report too, so a failure would carry it).
		assert_equal(String(check.metadata.get("affinity_id", "")), String(assigned_id), "AC2: the fairness verdict is tagged with the assigned affinity id.")


# AC2 (the FR58 heart): the harness REFLECTS the query's verdict for both a FAIL and a PASS config. ⭐ STORY 10.8
# RE-SHAPE: the 10.3 FAIL half placed a reachable hazard "far down the corridor" (entrance-unseen) — that config is
# now a legitimate PASS under moving-LoS (the hero sees it from the adjacent step-from cell before contact). The FAIL
# half is re-shaped to a predicate-(a) config that STILL fails (HAZARD on the entrance cell — the retained v0
# unavoidable/no-see-first config). The harness does NOT re-implement the fairness predicate (the 11.4
# reflect-not-recompute discipline). Mirrors the 7.6 hand-built-candidate pattern (the ONLY place this harness
# hand-builds a board — a batch level's board always comes from the real generate payload).
func _unseen_hazard_fails_and_seen_hazard_passes_reflecting_the_query() -> void:
	var affinities: AffinityRepository = _affinity_repository()
	var query: DarknessFairnessQuery = DarknessFairnessQuery.new()

	# FAIL: HAZARD on the entrance cell (predicate (a) entrance_on_hazard — forced turn-1 damage, no see-first step).
	var fail_grid: Array = _open_grid(14, 12)
	var corridor_row: int = 12 / 2
	(fail_grid[corridor_row] as Array)[1] = BoardCell.Terrain.HAZARD
	var fail_board: BoardState = _board_from_grid(14, 12, fail_grid)
	var fail_check: ActionResult = query.check_board(fail_board, &"darkness", affinities, "10300001", Vector2i(1, corridor_row))
	assert_true(fail_check.is_error(), "AC2 (10.8): a genuinely-unfair Darkness board (entrance-on-hazard) FAILS the fairness check.")
	assert_equal(String(fail_check.metadata.get("fairness_reason")), String(DarknessFairnessQuery.REASON_ENTRANCE_ON_HAZARD), "AC2: the failure reports the entrance_on_hazard fairness reason (the retained predicate-(a) FAIL).")
	assert_equal(String(fail_check.metadata.get("seed")), "10300001", "AC2: the failure carries the seed.")
	assert_equal(String(fail_check.metadata.get("phase")), "validation", "AC2: the failure reports the validation phase.")
	assert_equal(String(fail_check.metadata.get("affinity_id", &"darkness")), "darkness", "AC2: the failure is TAGGED by affinity (darkness).")

	# PASS: a hazard adjacent to the entrance (distance 1 <= reduced radius 2, open LoS -> seen-before-contact). Seen =>
	# avoidable => the "critical danger is inspectable/telegraphed" half is satisfied by the query REFLECTING it.
	var pass_grid: Array = _open_grid(11, 11)
	var pass_corridor: int = 11 / 2
	(pass_grid[pass_corridor] as Array)[2] = BoardCell.Terrain.HAZARD
	var pass_board: BoardState = _board_from_grid(11, 11, pass_grid)
	var pass_check: ActionResult = query.check_board(pass_board, &"darkness", affinities, "10300002")
	assert_true(pass_check.succeeded, "AC2: a hazard SEEN at the reduced radius is fair (seen + avoidable). Error: %s" % pass_check.metadata)
	assert_equal(int(pass_check.metadata.get("reachable_seen_hazard_count")), 1, "AC2: the seen hazard is counted as reachable-and-seen (inspectable/telegraphed).")


# ---- AC3/AC4: thresholds, tuning flag, failing-seed preservation ---------------------------------

# AC4: STATE + ASSERT the zero-tolerance thresholds verbatim (0 soft-locks, 0 mandatory class/item gates, 0
# unreachable mandatory exits, 0 unreachable intended mandatory rewards, 0 illegal placement, 0 unsafe
# first-reveal at the BASELINE radius) AND the ≤ 1% bounded-retry-exhaustion-per-recipe-batch threshold, from
# ACTUAL live runs over each recipe batch. The GENERATION soft-lock/placement/reward/exit/gate/base-first-reveal
# classes are MET by construction for the approved catalog (every seed passes LevelValidator on the unperturbed
# attempt 0, attempts == 1, retry-exhaustion 0%).
#
# ⭐ THE FR58 DARKNESS-HALF EXCEPTION (the honest 10.6-gate finding): the "0 unavoidable untelegraphed
# first-reveal punishments" class ALSO covers the darkness_unseen_hazard FR58 half. That half is NOT zero for
# the current catalog — Medium seeds 4004 + 5005 bake HAZARD terrain that is unseen at the Darkness-reduced
# radius. The batch does NOT falsely assert zero here; it CLASSIFIES the finding (via the single live
# classifier), asserts the base classes hold, and hands the Darkness-half finding to 10.6 (the readiness ledger
# records it as a real gap under the Darkness affinity, gated at 10.6 — NOT a harness bug, NOT a silent pass).
func _zero_tolerance_and_retry_exhaustion_thresholds_hold_for_the_approved_catalog() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()
	var validator: LevelValidator = LevelValidator.new()

	for recipe: Dictionary in BATCH_RECIPES:
		var recipe_id: String = String(recipe.get("recipe_id"))
		var batch_size: int = 0
		var zero_tolerance_failures: int = 0
		var retry_exhaustions: int = 0

		for seed_value: int in BATCH_SEEDS:
			batch_size += 1
			var generation: GenerationResult = LevelGenerator.generate(_request_for(seed_value, recipe), recipes, enemies)

			# Retry-exhaustion: a seed that burned all MAX_GENERATION_ATTEMPTS is a bounded-retry exhaustion.
			if generation.is_error() and int(generation.diagnostics.get("attempts", -1)) >= LevelGenerator.MAX_GENERATION_ATTEMPTS:
				retry_exhaustions += 1
			# Any generation failure whose code is a zero-tolerance class counts as a zero-tolerance failure.
			if generation.is_error() and ZERO_TOLERANCE_CODES.has(generation.error_code):
				zero_tolerance_failures += 1
			if not generation.succeeded:
				continue

			# Direct-validate the built candidate: a zero-tolerance code from the direct re-run is a zero-tolerance
			# failure too (belt-and-suspenders — the pipeline already passed, so this is 0 for the approved catalog).
			var candidate: Dictionary = _candidate_from_payload(generation.payload)
			var validation: ActionResult = validator.validate(candidate)
			if validation.is_error() and ZERO_TOLERANCE_CODES.has(validation.error_code):
				zero_tolerance_failures += 1

		# AC4: the GENERATION zero-tolerance classes (soft-lock / gate / unreachable-exit / unreachable-reward /
		# illegal-placement / base unsafe-first-reveal) are ALL 0 across the recipe batch (met by construction).
		assert_equal(zero_tolerance_failures, 0, "AC4: recipe=%s must have ZERO soft-lock/gate/unreachable-exit/unreachable-reward/illegal-placement/base-first-reveal failures (generation zero-tolerance)." % recipe_id)
		# AC4: the bounded-retry-exhaustion rate stays at or below 1% per recipe batch.
		var exhaustion_rate: float = float(retry_exhaustions) / float(batch_size)
		assert_true(
			exhaustion_rate <= MAX_RETRY_EXHAUSTION_RATE,
			"AC4: recipe=%s bounded-retry-exhaustion rate %.4f must stay <= %.4f (%d exhaustions / %d seeds)." % [recipe_id, exhaustion_rate, MAX_RETRY_EXHAUSTION_RATE, retry_exhaustions, batch_size]
		)

	# AC4 (the FR58 Darkness-half readiness verdict — honest, not fabricated): classify the Darkness fairness half
	# live. ⭐ STORY 10.8 DELIBERATE FLIP: 10.3 recorded the Medium recipe NOT meeting the FR58 bar (seeds 4004/5005
	# unseen at the static-from-entrance radius). Story 10.8 strengthened predicate (b) to MOVING reduced-radius LoS —
	# every reachable hazard is seen-before-contact, so BOTH recipes now meet the FR58 zero-tolerance bar (0 failures).
	# The generated-catalog Darkness half MEETS final readiness on this axis.
	var classification: Dictionary = _classify_darkness_fairness_over_batch()
	assert_true(classification.get("small_failures", []).is_empty(), "AC4: the Small recipe meets the FR58 darkness_unseen_hazard zero-tolerance bar (0 failures).")
	var darkness_failure_count: int = (classification.get("darkness_failures", []) as Array).size()
	# Story 10.8: the count is now 0 (the moving-LoS predicate makes every reachable Medium hazard fair). Asserting it
	# is == 0 keeps the harness honest: if a future generator change bakes a genuinely unseen-before-contact hazard,
	# this fails LOUD so the ledger is re-verified.
	assert_equal(darkness_failure_count, 0, "AC4 (Story 10.8): the batch must surface ZERO generated-board Darkness fairness failures — every reachable Medium hazard (incl. 4004/5005) is seen-before-contact under the strengthened predicate. A non-zero here means the generator baked a genuinely unseen-before-contact hazard; re-verify the ledger, do NOT silence.")
	# The FR58 zero-tolerance bar for FINAL readiness IS now met by the current catalog (Darkness half) under moving-LoS.
	var final_readiness_fr58_darkness_met: bool = (darkness_failure_count == 0)
	assert_true(final_readiness_fr58_darkness_met, "AC4 (Story 10.8): the Darkness FR58 half MEETS the final zero-tolerance readiness bar for the current catalog — the strengthened moving-LoS predicate makes every reachable Medium hazard seen-before-contact.")


# AC3/AC4: PROVE the threshold -> flag -> preserve REPORTING path fires (the forced-failure shape). When an
# injected always-fail validator drives the recipe-batch failure rate above threshold, the harness FLAGS the
# relevant recipe / validation rule / retry limit (MAX_GENERATION_ATTEMPTS) for tuning AND PRESERVES the
# failing seed(s) as DATA (a preserved-seed list — kept + annotated with the failing phase/reason/recipe so it
# is reproducible; never silently discarded). The harness can never silently pass a regression.
func _threshold_breach_flags_recipe_rule_retry_limit_and_preserves_failing_seed() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()
	var always_fail: AlwaysFailValidator = AlwaysFailValidator.new()

	var recipe: Dictionary = BATCH_RECIPES[0]
	var recipe_id: String = String(recipe.get("recipe_id"))
	var batch_size: int = 0
	var retry_exhaustions: int = 0
	var preserved_seeds: Array[Dictionary] = []

	# Drive the recipe batch through the INJECTED always-fail validator: every seed exhausts the bounded retry.
	for seed_value: int in BATCH_SEEDS:
		batch_size += 1
		var generation: GenerationResult = LevelGenerator.generate(_request_for(seed_value, recipe), recipes, enemies, always_fail)
		if generation.is_error() and int(generation.diagnostics.get("attempts", -1)) >= LevelGenerator.MAX_GENERATION_ATTEMPTS:
			retry_exhaustions += 1
			preserved_seeds.append(_preserved_seed_record(seed_value, recipe_id, generation))

	# The rate is above threshold (100% exhaustion) -> the reporting path MUST fire.
	var exhaustion_rate: float = float(retry_exhaustions) / float(batch_size)
	assert_true(exhaustion_rate > MAX_RETRY_EXHAUSTION_RATE, "AC3 setup: the injected failure must drive the exhaustion rate above threshold.")

	# FLAG the relevant recipe / validation rule / retry limit for tuning (actionable, compact — the AC3 tuning flag).
	var tuning_flags: Array[Dictionary] = _tuning_flags_for_breach(recipe_id, exhaustion_rate)
	assert_false(tuning_flags.is_empty(), "AC3: a threshold breach must FLAG at least one recipe/rule/retry-limit for tuning (a breach that names nothing to tune = AC3 not met).")
	var flagged_targets: Array[String] = []
	for flag: Dictionary in tuning_flags:
		flagged_targets.append(String(flag.get("target")))
	assert_true(flagged_targets.has(recipe_id), "AC3: the failing recipe (%s) must be flagged for tuning." % recipe_id)
	assert_true(flagged_targets.has("MAX_GENERATION_ATTEMPTS"), "AC3: the retry limit (MAX_GENERATION_ATTEMPTS) must be flagged for tuning on a retry-exhaustion breach.")
	assert_true(flagged_targets.has("LevelValidator"), "AC3: the failing validation rule (LevelValidator) must be flagged for tuning.")

	# PRESERVE the failing seed(s) as DATA — kept + annotated with the failing phase/reason/recipe (reproducible).
	assert_equal(preserved_seeds.size(), BATCH_SEEDS.size(), "AC3: every failing seed in the batch must be preserved (none silently discarded).")
	for record: Dictionary in preserved_seeds:
		assert_true(BATCH_SEEDS.has(int(record.get("seed"))), "AC3: a preserved record carries a real failing seed.")
		assert_equal(String(record.get("recipe_id")), recipe_id, "AC3: a preserved record carries the recipe for reproduction.")
		assert_false(String(record.get("phase")).is_empty(), "AC3: a preserved record carries the failing phase.")
		assert_false(String(record.get("reason")).is_empty(), "AC3: a preserved record carries the failing reason.")
		assert_equal(int(record.get("attempts")), LevelGenerator.MAX_GENERATION_ATTEMPTS, "AC3: a preserved retry-exhaustion record carries the exhausted attempt count.")


# AC3/AC4 (the flag+preserve MACHINERY, exercised by a HAND-BUILT unfair board): ⭐ STORY 10.8 RE-POINT — 10.3
# exercised this path via the REAL Medium 4004/5005 `darkness_unseen_hazard` findings, but the strengthened
# moving-LoS predicate makes every generated Darkness board PASS (that finding set is now empty). The AC3
# flag+preserve machinery must STILL be proven, so this re-points to a HAND-BUILT genuinely-unfair Darkness board
# (predicate (a): HAZARD on the entrance cell — the retained v0 unavoidable/no-see-first config). It drives the
# query's verbatim FAIL, FLAGS the relevant recipe class + the FR58 validation rule for tuning, and PRESERVES the
# failing finding as annotated DATA. The machinery is unchanged; only the finding SOURCE moved from a (now-passing)
# generated seed to a hand-built unfair board — so the flag+preserve path is never silently dropped.
func _real_darkness_finding_flags_recipe_rule_and_preserves_failing_seeds() -> void:
	var affinities: AffinityRepository = _affinity_repository()
	var query: DarknessFairnessQuery = DarknessFairnessQuery.new()

	# A hand-built genuinely-unfair Darkness board: HAZARD on the entrance cell (predicate (a) entrance_on_hazard — the
	# retained v0 FAIL config now that reachable non-entrance hazards are fair under moving-LoS).
	var grid: Array = _open_grid(14, 12)
	var corridor_row: int = 12 / 2
	(grid[corridor_row] as Array)[1] = BoardCell.Terrain.HAZARD  # HAZARD on the entrance cell (1, corridor).
	var board: BoardState = _board_from_grid(14, 12, grid)
	var check: ActionResult = query.check_board(board, &"darkness", affinities, "10800001", Vector2i(1, corridor_row))
	assert_true(check.is_error(), "AC3 (10.8): a hand-built predicate-(a) unfair Darkness board FAILS (the retained genuinely-unfair config).")

	# Build the preserved finding from the query's verbatim failure (tagged with a representative recipe class so the
	# flag+preserve machinery is exercised exactly as it was for the real generated finding).
	var findings: Array = [{
		"recipe_id": "medium_combat_basic",
		"seed": String(check.metadata.get("seed", "")),
		"affinity_id": String(check.metadata.get("affinity_id", "darkness")),
		"fairness_reason": String(check.metadata.get("fairness_reason", "")),
		"phase": String(check.metadata.get("phase", "")),
		"entrance": check.metadata.get("entrance", {})
	}]

	# FLAG the relevant recipe class + the FR58 validation rule for tuning (the same machinery, unchanged).
	var tuning_flags: Array[Dictionary] = _fairness_tuning_flags_for(findings)
	assert_false(tuning_flags.is_empty(), "AC3: the Darkness fairness breach must FLAG at least one recipe/rule for tuning.")
	var flagged_targets: Array[String] = []
	for flag: Dictionary in tuning_flags:
		flagged_targets.append(String(flag.get("target")))
	assert_true(flagged_targets.has("medium_combat_basic"), "AC3: the recipe class is flagged for tuning.")
	assert_true(flagged_targets.has("DarknessFairnessQuery"), "AC3: the FR58 fairness rule (DarknessFairnessQuery) must be named as the failing validation rule.")

	# PRESERVE the failing finding as DATA — kept + annotated (affinity + reason + phase + recipe + compact
	# diagnostics) so it is reproducible (the 3.7 preserved-catalog discipline; never silently discarded).
	for finding: Dictionary in findings:
		assert_false(String(finding.get("seed")).is_empty(), "AC3: a preserved Darkness finding carries the seed.")
		assert_equal(String(finding.get("affinity_id")), "darkness", "AC3: a preserved Darkness finding is tagged by affinity.")
		assert_false(String(finding.get("fairness_reason")).is_empty(), "AC3: a preserved Darkness finding carries the fairness reason.")
		assert_equal(String(finding.get("fairness_reason")), String(DarknessFairnessQuery.REASON_ENTRANCE_ON_HAZARD), "AC3: the hand-built finding is the predicate-(a) entrance_on_hazard config.")
		assert_false(String(finding.get("phase")).is_empty(), "AC3: a preserved Darkness finding carries the phase.")
		assert_false(String(finding.get("recipe_id")).is_empty(), "AC3: a preserved Darkness finding carries the recipe.")
		assert_false((finding.get("entrance", {}) as Dictionary).is_empty(), "AC3: a preserved Darkness finding carries the offending cell (compact, reproducible).")


# Build the AC3 tuning flags for a Darkness FR58 fairness breach (name the failing recipe(s) + the FR58
# validation rule — actionable, compact). The recipe(s) come from the live findings; the rule is the
# DarknessFairnessQuery reduced-radius predicate under the Darkness affinity.
func _fairness_tuning_flags_for(findings: Array) -> Array[Dictionary]:
	var flags: Array[Dictionary] = []
	var seen_recipes: Dictionary = {}
	for finding_value: Variant in findings:
		var finding: Dictionary = finding_value
		var recipe_id: String = String(finding.get("recipe_id"))
		if not seen_recipes.has(recipe_id):
			seen_recipes[recipe_id] = true
			flags.append({"target": recipe_id, "kind": "recipe", "reason": "hazard_wrinkle_unseen_under_darkness_reduced_radius"})
	flags.append({"target": "DarknessFairnessQuery", "kind": "validation_rule", "reason": "reachable_hazard_unseen_at_darkness_reduced_radius", "affinity": "darkness"})
	return flags


# Build the AC3 preserved-seed record (kept + annotated with the failing phase/reason/recipe/attempts so the
# failing seed is REPRODUCIBLE — the 3.7 AC4 preserved-catalog discipline). Data only, no grid dump.
func _preserved_seed_record(seed_value: int, recipe_id: String, generation: GenerationResult) -> Dictionary:
	return {
		"seed": seed_value,
		"recipe_id": recipe_id,
		"phase": String(generation.failed_phase),
		"reason": String(generation.reason),
		"error_code": String(generation.error_code),
		"attempts": int(generation.diagnostics.get("attempts", -1))
	}


# Build the AC3 tuning flags for a threshold breach (name the recipe + the failing validation rule + the retry
# limit — actionable, compact). A retry-exhaustion breach implicates the retry limit (MAX_GENERATION_ATTEMPTS),
# the failing validation rule (LevelValidator — the validator that never passed), AND the recipe itself.
func _tuning_flags_for_breach(recipe_id: String, exhaustion_rate: float) -> Array[Dictionary]:
	var flags: Array[Dictionary] = []
	flags.append({"target": recipe_id, "kind": "recipe", "reason": "retry_exhaustion_rate_above_threshold", "rate": exhaustion_rate})
	flags.append({"target": "LevelValidator", "kind": "validation_rule", "reason": "candidate_never_validated_within_bound"})
	flags.append({"target": "MAX_GENERATION_ATTEMPTS", "kind": "retry_limit", "reason": "bounded_retry_exhausted", "value": LevelGenerator.MAX_GENERATION_ATTEMPTS})
	return flags


# ---- test seam: the always-fail validator (the 3.6 optional 4th `validator` param) ----------------
#
# Injected via LevelGenerator.generate(request, recipes, enemies, validator) to exercise the bounded-retry
# EXHAUSTION + the AC3 threshold -> flag -> preserve reporting path WITHOUT a genuinely-bad approved seed. It
# quacks the LevelValidator surface (validate(candidate) -> ActionResult) and ALWAYS returns a stable failure
# code (mapped by phase_for_code onto a GenerationResult phase). This is the 3.6 test seam, unchanged.
class AlwaysFailValidator:
	const ActionResultInner = preload("res://scripts/core/results/action_result.gd")
	# A stable zero-tolerance code so the forced failure maps onto a real GenerationResult phase via
	# LevelValidator.phase_for_code (soft_lock_detected -> pathing) — proving the reporting path for a
	# zero-tolerance class, not just any error.
	const FORCED_CODE := &"soft_lock_detected"

	func validate(_candidate: Dictionary) -> ActionResultInner:
		return ActionResultInner.error(FORCED_CODE, {"reason": "forced_always_fail_for_batch_threshold_test"})
