extends "res://tests/unit/test_case.gd"

# Story 3.7 — Batch seed-regression harness (AC3 + AC4) + the preserved approved-seed catalog.
#
# This is the FIRST LevelGenerator.generate(...)-LEVEL seed-regression in the codebase. It closes the
# 3.6 Round 1 deferred Low: the 3.2/3.3 seed-regression tests call generate_layout(...) DIRECTLY,
# bypassing the comprehensive validator + bounded retry, so there was no integration-level proof that
# the validator never silently perturbs a baseline candidate (attempts == 1) and no full-generate
# terrain pin. This harness drives the approved Small + Medium seed catalog through the FULL pipeline
# (LevelGenerator.generate) and asserts, per seed:
#   AC3 (a) validation status is STABLE: succeeded == true, diagnostics.validated == true,
#           diagnostics.attempts == 1 (the approved seeds all pass validation on the UNPERTURBED attempt 0).
#   AC3 (b) the compact TERRAIN fingerprint (reconstructed from the generate payload board) matches the
#           pinned value AND agrees with the value the seed-regression test pins via generate_layout —
#           a mismatch between the two is a BUG, not a re-pin (the loader/batch harness only READS the
#           pipeline; attempt 0 is unperturbed, so the terrain is byte-identical with NO re-pin).
#   AC3 failure reporting: on a (non-expected) generation failure, the assert message carries seed +
#           recipe_id + failed_phase + reason from the GenerationResult (compact; NO grid dump).
#   AC4: the approved seed catalog is preserved AS DATA with bland/unfair seeds KEPT and ANNOTATED
#        (the `notes` field per seed) rather than silently discarded. The per-seed tactical-decision
#        notes from the AC4 review pass are recorded in the story Completion Notes; the batch coverage
#        proving those seeds still load deterministically IS the persisted regression artifact.
#
# DELIBERATE-UPDATE CONTRACT (mirrors the seed-regression test headers): the pinned terrain fingerprints
# here change ONLY with an INTENTIONAL generator/recipe change re-pinned in the SAME PR (regenerate via
# tools/dump_seed_batch_report.gd / the existing dump_*_layout_fingerprints.gd). They MUST NEVER be
# updated silently to make a drifting test pass. For the overlapping approved seeds the values here are
# the SAME ones pinned in test_small_level_layout_seed_regression.gd /
# test_medium_level_layout_seed_regression.gd (the divergence assertion below enforces that agreement).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")

# AC4 PRESERVED APPROVED-SEED CATALOG. Bland/unfair seeds are KEPT (annotated), NOT deleted. Each entry:
#   recipe_id   - the baseline recipe driven through the full pipeline
#   size_class  - small | medium (for the request)
#   fingerprint - the pinned TERRAIN fingerprint (SAME value as the 3.2/3.3 seed-regression fixtures for
#                 the overlapping seeds; a drift is an intentional re-pin only)
#   notes       - the AC4 tactical-decision annotation (movement / line-of-sight / risk-positioning).
#                 A "bland"/"unfair" seed is preserved here with a note rather than discarded.
#
# These are the SAME five seeds (1001/2002/3003/4004/5005) the 3.2/3.3 tests pin, for BOTH recipes — the
# documented shared catalog. The fingerprints are copied verbatim from those fixtures; the divergence
# assertion below cross-checks every value against the live generate_layout output so this catalog can
# never silently disagree with the seed-regression fixtures.
const APPROVED_SEED_CATALOG: Array[Dictionary] = [
	# --- small_combat_basic (8x8) ---
	{
		"recipe_id": "small_combat_basic", "size_class": "small", "seed": 1001,
		"fingerprint": "8x8|e1,4|x6,4|11111111/10000001/11000001/10000001/13000041/10010001/11000001/11111111",
		"notes": "Movement: open central corridor with a single interior wall pair (col 1 rows 2/6) creating a short cover step. LoS: the wall on row 2 col 1 + row 6 col 1 give partial sight breaks off the entrance. Risk: light cover; a fair, slightly bland warm-up arena. KEPT (bland-but-fair baseline)."
	},
	{
		"recipe_id": "small_combat_basic", "size_class": "small", "seed": 2002,
		"fingerprint": "8x8|e1,4|x6,4|11111111/10010001/10000001/10000001/13000041/11010001/10000001/11111111",
		"notes": "Movement: scattered interior walls (rows 1/5 col 3, row 5 col 1) offer a flank around the upper-left cover. LoS: the col-3 walls break a straight entrance->exit sightline. Risk: meaningful positioning choice between the open corridor and the walled flank. KEPT."
	},
	{
		"recipe_id": "small_combat_basic", "size_class": "small", "seed": 3003,
		"fingerprint": "8x8|e1,4|x6,4|11111111/10000001/10010011/11000001/13000041/11000001/10000001/11111111",
		"notes": "Movement: a thicker wall run on row 2 (cols 3 and 5-6) plus row 3 col 1 forms a small chamber. LoS: the row-2 cluster blocks the upper approach, rewarding a lower-corridor advance. Risk: a genuine choke around the upper-right wall pair. KEPT."
	},
	{
		"recipe_id": "small_combat_basic", "size_class": "small", "seed": 4004,
		"fingerprint": "8x8|e1,4|x6,4|11111111/10000001/10000001/10001101/13000041/11100001/10001001/11111111",
		"notes": "Movement: a blocker_cluster on row 3 (cols 4-5) and a left wall run on row 5 (cols 1-2) split the upper field. LoS: the row-3 cluster sits just above the corridor, creating a sightline break right on the main path. Risk: a clear cover/exposure trade approaching the exit. KEPT (good tactical variety)."
	},
	{
		"recipe_id": "small_combat_basic", "size_class": "small", "seed": 5005,
		"fingerprint": "8x8|e1,4|x6,4|11111111/10100011/10001001/10010011/13000041/10000001/10000001/11111111",
		"notes": "Movement: dense upper-half walls (rows 1-3) form a tight cover maze above the corridor. LoS: many short sight breaks; the lower half stays open for a clean advance. Risk: the richest Small seed for line-of-sight play; pick the open lane or the walled upper flank. KEPT."
	},
	# --- medium_combat_basic (14x12) ---
	{
		"recipe_id": "medium_combat_basic", "size_class": "medium", "seed": 1001,
		"fingerprint": "14x12|e1,6|x12,6|11111111111111/10000010000001/10000000000001/10000000000001/10000000000001/10010000100001/13000000000041/11000000000001/10100000000001/10000000000001/10000000000001/11111111111111",
		"notes": "Movement: a wide-open 14x12 field with a few scattered cover walls; long approach lanes both above and below the corridor. LoS: cover at row 5 (cols 2 and 7) gives a mid-field sightline break. Risk: long sightlines reward ranged positioning. Slightly sparse but fair. KEPT (open-but-fair)."
	},
	{
		"recipe_id": "medium_combat_basic", "size_class": "medium", "seed": 2002,
		"fingerprint": "14x12|e1,6|x12,6|11111111111111/10010000000001/10000010001101/10000000000001/10000010000001/10000000010001/13000000000041/10000000000001/10000000000101/11000100000001/10000000000001/11111111111111",
		"notes": "Movement: cover spread across both halves (row 2 cols 6 and 9-10, row 9 col 4) plus a flank-route gap; multiple advance routes. LoS: the row-2 cluster blocks a direct upper crossing. Risk: strong flank-vs-direct decision. KEPT (good variety)."
	},
	{
		"recipe_id": "medium_combat_basic", "size_class": "medium", "seed": 3003,
		"fingerprint": "14x12|e1,6|x12,6|11111111111111/10000000000001/10000000000001/10000000011001/10000000000101/10000000000001/13000000000041/10000000010101/10000010000001/10000000000011/11000000000001/11111111111111",
		"notes": "Movement: right-of-centre cover (rows 3/7 cols 10-11, row 4 col 11) shapes a guarded approach to the exit. LoS: the exit-side wall cluster breaks the final sightline. Risk: a clear risk-positioning choice near the exit. KEPT."
	},
	{
		"recipe_id": "medium_combat_basic", "size_class": "medium", "seed": 4004,
		"fingerprint": "14x12|e1,6|x12,6|11111111111111/10010000000001/11000000000001/10000000010001/10000000020001/10001000000001/13000000000041/10000000000001/10100000000001/10000000000001/10000000000011/11111111111111",
		"notes": "Movement: cover on both flanks plus a HAZARD cell (row 4 col 9, terrain value 2) introducing a true risk-positioning hazard. LoS: the left wall run (row 2 col 1) and mid-field cover break crossing lanes. Risk: the hazard pocket forces a real route trade-off. KEPT (excellent tactical variety — first hazard seed)."
	},
	{
		"recipe_id": "medium_combat_basic", "size_class": "medium", "seed": 5005,
		"fingerprint": "14x12|e1,6|x12,6|11111111111111/10000000000001/10000000002021/10000000000001/10000000000001/10000010000001/13000000000041/10000000000001/10000000000001/10000000000001/10100001000001/11111111111111",
		"notes": "Movement: a HAZARD pair on row 2 (cols 10 and 12, terrain value 2) plus scattered cover; the upper-right becomes a danger zone to route around. LoS: mid-field cover (row 5 col 6) plus the lower-left wall (row 10 cols 2 and 7). Risk: the hazard pair is the standout positioning decision. KEPT (strong hazard/risk seed)."
	}
]

func run() -> Dictionary:
	_approved_catalog_passes_full_generate_with_stable_status_and_fingerprint()
	_catalog_fingerprints_agree_with_generate_layout()
	_catalog_covers_both_baseline_recipes_and_preserves_all_seeds()
	_failure_report_shape_carries_seed_recipe_phase_reason()
	return result()


func _recipes() -> LevelRecipeRepository:
	return LevelRecipeRepository.create_baseline_repository()


func _enemies() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


func _request_for(entry: Dictionary) -> GenerationRequest:
	var size_class: StringName = StringName(String(entry.get("size_class")))
	return GenerationRequest.new(
		int(entry.get("seed")), &"node_1", &"combat", StringName(String(entry.get("recipe_id"))),
		size_class, GenerationRequest.DIFFICULTY_STANDARD, GenerationRequest.AFFINITY_NONE, {}
	)


# AC3: every approved seed driven through the FULL pipeline passes validation on attempt 0 with a stable
# status (succeeded / validated == true / attempts == 1) AND reproduces the pinned terrain fingerprint
# reconstructed from the generate payload board. A failure reports seed + recipe + phase + reason.
func _approved_catalog_passes_full_generate_with_stable_status_and_fingerprint() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()

	for entry: Dictionary in APPROVED_SEED_CATALOG:
		var seed_value: int = int(entry.get("seed"))
		var recipe_id: String = String(entry.get("recipe_id"))
		var expected_fp: String = String(entry.get("fingerprint"))

		var request: GenerationRequest = _request_for(entry)
		var generation: GenerationResult = LevelGenerator.generate(request, recipes, enemies)

		# AC3 failure reporting: seed + recipe + phase + reason in the message (compact, no grid dump).
		assert_true(
			generation.succeeded,
			"Batch generate FAILED for approved seed=%d recipe=%s | failed_phase=%s | error_code=%s | reason=%s" % [
				seed_value, recipe_id, String(generation.failed_phase), String(generation.error_code), String(generation.reason)
			]
		)
		if not generation.succeeded:
			continue

		# Validation status STABLE: validated on the UNPERTURBED attempt 0.
		assert_true(bool(generation.diagnostics.get("validated", false)), "Approved seed=%d recipe=%s should be validated == true." % [seed_value, recipe_id])
		assert_equal(int(generation.diagnostics.get("attempts", -1)), 1, "Approved seed=%d recipe=%s must pass on attempt 0 (attempts == 1) — a perturbation would silently drift the terrain." % [seed_value, recipe_id])
		# The success-path seed transport is payload.level_seed (GenerationResult.seed is populated only
		# on the ERROR path — see the failure-report test below).
		assert_equal(String(generation.payload.get("level_seed", "")), str(seed_value), "Approved seed=%d recipe=%s payload.level_seed string mismatch." % [seed_value, recipe_id])

		# AC3 fingerprint stability via the FULL generate payload (the integration-level pin).
		var actual_fp: String = _terrain_fingerprint_from_payload(generation.payload)
		assert_equal(
			actual_fp, expected_fp,
			"Full-generate terrain fingerprint regression for seed=%d recipe=%s. If intentional, re-pin via tools/dump_seed_batch_report.gd AND the matching seed-regression fixture, and update the change log." % [seed_value, recipe_id]
		)


# AC3: the catalog fingerprints AGREE with the live generate_layout output (the SAME path + values the
# 3.2/3.3 seed-regression tests pin). This is the explicit cross-check that the full-generate pin (above)
# and the layout-level pin (the seed-regression fixtures) can never silently diverge — a mismatch is a BUG.
func _catalog_fingerprints_agree_with_generate_layout() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()

	for entry: Dictionary in APPROVED_SEED_CATALOG:
		var seed_value: int = int(entry.get("seed"))
		var recipe_id: String = String(entry.get("recipe_id"))
		var size_class: String = String(entry.get("size_class"))
		var expected_fp: String = String(entry.get("fingerprint"))

		var request: GenerationRequest = _request_for(entry)
		var recipe: LevelRecipeDefinition = recipes.get_recipe(StringName(recipe_id))
		assert_true(recipe != null, "Catalog recipe %s must resolve." % recipe_id)
		var streams: RngStreamSet = RngStreamSet.new(request.level_seed())

		var layout: Dictionary
		var layout_fp: String
		if size_class == "small":
			var small_gen: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
			var small_result: ActionResult = small_gen.generate_layout(request, recipe, streams, enemies)
			assert_true(small_result.succeeded, "generate_layout should succeed for Small seed=%d." % seed_value)
			layout = small_result.metadata.get("layout")
			layout_fp = SmallLevelLayoutGenerator.fingerprint(layout)
		else:
			var medium_gen: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
			var medium_result: ActionResult = medium_gen.generate_layout(request, recipe, streams, enemies)
			assert_true(medium_result.succeeded, "generate_layout should succeed for Medium seed=%d." % seed_value)
			layout = medium_result.metadata.get("layout")
			layout_fp = MediumLevelLayoutGenerator.fingerprint(layout)

		# The catalog value MUST equal the live generate_layout fingerprint (agreement with the
		# seed-regression fixtures, which pin this same path/value).
		assert_equal(layout_fp, expected_fp, "Catalog fingerprint for seed=%d recipe=%s must AGREE with generate_layout (a mismatch is a bug, not a re-pin)." % [seed_value, recipe_id])
		# And the full-generate payload fingerprint MUST equal the generate_layout fingerprint (the two
		# pinning paths converge — closes the 3.6 deferred Low's full-vs-layout pin gap).
		var generation: GenerationResult = LevelGenerator.generate(request, recipes, enemies)
		assert_true(generation.succeeded, "Cross-check generate should succeed for seed=%d recipe=%s." % [seed_value, recipe_id])
		assert_equal(_terrain_fingerprint_from_payload(generation.payload), layout_fp, "Full-generate payload terrain must equal generate_layout terrain for seed=%d recipe=%s." % [seed_value, recipe_id])


# AC4: the catalog covers BOTH baseline recipes and PRESERVES every approved seed (none discarded).
func _catalog_covers_both_baseline_recipes_and_preserves_all_seeds() -> void:
	var small_seeds: Dictionary = {}
	var medium_seeds: Dictionary = {}
	for entry: Dictionary in APPROVED_SEED_CATALOG:
		# Every entry must carry an AC4 tactical-decision annotation (preserved, not discarded).
		assert_false(String(entry.get("notes", "")).strip_edges().is_empty(), "Every catalog seed must carry an AC4 tactical-decision note (preserved for tuning).")
		var recipe_id: String = String(entry.get("recipe_id"))
		if recipe_id == "small_combat_basic":
			small_seeds[int(entry.get("seed"))] = true
		elif recipe_id == "medium_combat_basic":
			medium_seeds[int(entry.get("seed"))] = true

	# The shared catalog: the SAME five seeds the 3.2/3.3 fixtures pin, for BOTH recipes.
	for seed_value: int in [1001, 2002, 3003, 4004, 5005]:
		assert_true(small_seeds.has(seed_value), "Small catalog must preserve approved seed %d." % seed_value)
		assert_true(medium_seeds.has(seed_value), "Medium catalog must preserve approved seed %d." % seed_value)
	assert_equal(small_seeds.size(), 5, "Small catalog should hold exactly the five approved seeds.")
	assert_equal(medium_seeds.size(), 5, "Medium catalog should hold exactly the five approved seeds.")


# AC3 failure-report shape: when a seed DOES fail generation (forced here with an unknown recipe so the
# harness never silently passes a regression), the error result carries seed + recipe + failed_phase +
# reason — the exact fields the batch assert message reports. This proves the reporting contract without
# relying on an actually-bad approved seed.
func _failure_report_shape_carries_seed_recipe_phase_reason() -> void:
	var recipes: LevelRecipeRepository = _recipes()
	var enemies: EnemyRepository = _enemies()
	var request: GenerationRequest = GenerationRequest.new(
		1001, &"node_1", &"combat", &"unregistered_recipe",
		GenerationRequest.SIZE_SMALL, GenerationRequest.DIFFICULTY_STANDARD, GenerationRequest.AFFINITY_NONE, {}
	)
	var generation: GenerationResult = LevelGenerator.generate(request, recipes, enemies)

	assert_true(generation.is_error(), "An unregistered recipe must produce a generation error.")
	# seed (String), failed_phase, error_code, reason are all present and machine-readable.
	assert_equal(generation.seed, "1001", "A failure must carry the seed string for reporting.")
	assert_equal(generation.failed_phase, GenerationResult.PHASE_RECIPE, "An unknown-recipe failure is in the recipe phase.")
	assert_equal(generation.error_code, &"unknown_level_recipe", "An unknown-recipe failure carries the unknown_level_recipe code.")
	assert_false(String(generation.reason).strip_edges().is_empty(), "A failure must carry a non-empty reason for reporting.")
	# The recipe id is recoverable for the report (from the request, or diagnostics.recipe_id when present).
	assert_equal(String(request.recipe_id), "unregistered_recipe", "The recipe id must be recoverable for the failure report.")


# Reconstruct the layout-shaped dict (width/height/terrain/entrance/exit) from a GenerationResult
# payload board snapshot and compute the TERRAIN fingerprint via the EXISTING static (no second format).
# Enemies are board ENTITIES on FLOOR cells, so the reconstructed terrain grid equals the layout terrain
# the seed-regression tests pin.
func _terrain_fingerprint_from_payload(payload: Dictionary) -> String:
	var board: Dictionary = payload.get("board", {})
	var width: int = int(board.get("width", 0))
	var height: int = int(board.get("height", 0))
	var cells: Array = board.get("cells", [])

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
		"terrain": terrain_grid
	}
	return SmallLevelLayoutGenerator.fingerprint(layout)
