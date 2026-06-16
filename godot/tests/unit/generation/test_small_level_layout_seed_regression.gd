extends "res://tests/unit/test_case.gd"

# Story 3.2 — Small layout seed-regression fixtures (AC1 + AC3).
#
# Pins a small set of APPROVED root_seed fixtures for small_combat_basic to a stable layout
# fingerprint. For each seed: generate twice and assert the two outputs are byte-identical
# (determinism), and assert the fingerprint matches the pinned EXPECTED value. A drift fails the
# test with the FAILING root_seed in the assert message (AC3 verbatim: "regressions include the
# failing seed in test output"). The test also asserts the approved seeds collectively produce
# more than one distinct layout (AC1: meaningful divergence).
#
# DELIBERATE-UPDATE CONTRACT: these pinned fingerprints change ONLY with an intentional generator
# or recipe change — and the story/PR that makes that change re-pins them here. They must NEVER be
# updated silently to make a drifting test pass. If a fingerprint drift is intentional, regenerate
# via tools/dump_small_layout_fingerprints.gd and update both the value AND the change log.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")

# Approved seed -> expected layout fingerprint for small_combat_basic. RE-PINNED 2026-06-16 for
# Story 3.4 (tactical-wrinkle placement): the terrain grid now carries the placed wrinkle cells, so
# every approved-seed fingerprint drifted from the 3.2 values. This is a DELIBERATE generator change
# re-pinned in the same PR via tools/dump_small_layout_fingerprints.gd (see the Change Log). Small's
# recipe (small_combat_basic) allows only choke_point + blocker_cluster, both realized as interior
# WALL structure, so the Small fingerprints gain extra WALL (`1`) cells but NEVER a HAZARD (`2`) cell.
#
# Story 3.5 (enemy + reward placement) does NOT re-pin these: enemies are board ENTITIES and rewards
# are payload MARKERS — neither touches the terrain grid the fingerprint serializes. The fingerprints
# staying GREEN with NO change is itself the regression tripwire that placement did not perturb terrain
# or the blocker/wrinkle draw order (the placement draws are APPENDED after the wrinkle draws).
const APPROVED_FINGERPRINTS: Dictionary = {
	1001: "8x8|e1,4|x6,4|11111111/10000001/11000001/10000001/13000041/10010001/11000001/11111111",
	2002: "8x8|e1,4|x6,4|11111111/10010001/10000001/10000001/13000041/11010001/10000001/11111111",
	3003: "8x8|e1,4|x6,4|11111111/10000001/10010011/11000001/13000041/11000001/10000001/11111111",
	4004: "8x8|e1,4|x6,4|11111111/10000001/10000001/10001101/13000041/11100001/10001001/11111111",
	5005: "8x8|e1,4|x6,4|11111111/10100011/10001001/10010011/13000041/10000001/10000001/11111111"
}

func run() -> Dictionary:
	_approved_seeds_match_pinned_fingerprints()
	_approved_seeds_are_internally_deterministic()
	_approved_seeds_show_meaningful_divergence()
	return result()


func _recipe() -> LevelRecipeDefinition:
	return LevelRecipeRepository.create_baseline_repository().get_recipe(&"small_combat_basic")


func _layout_for_seed(root_seed: int, recipe: LevelRecipeDefinition) -> Dictionary:
	var request: GenerationRequest = GenerationRequest.new(
		root_seed, &"node_1", &"combat", &"small_combat_basic",
		GenerationRequest.SIZE_SMALL, GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE, {}
	)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, recipe, streams, EnemyRepository.create_baseline_repository())
	assert_true(layout_result.succeeded, "Approved-seed %d should generate a Small layout. Error: %s" % [root_seed, layout_result.metadata])
	return layout_result.metadata.get("layout")


func _approved_seeds_match_pinned_fingerprints() -> void:
	var recipe: LevelRecipeDefinition = _recipe()
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		var root_seed: int = int(seed_key)
		var expected: String = String(APPROVED_FINGERPRINTS[seed_key])
		var actual: String = SmallLevelLayoutGenerator.fingerprint(_layout_for_seed(root_seed, recipe))
		# AC3: the failing seed MUST appear in the assert message on a regression.
		assert_equal(actual, expected, "Small layout fingerprint regression for root_seed=%d. If this change is intentional, re-pin via tools/dump_small_layout_fingerprints.gd and update the change log." % root_seed)


func _approved_seeds_are_internally_deterministic() -> void:
	var recipe: LevelRecipeDefinition = _recipe()
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		var root_seed: int = int(seed_key)
		var first: Dictionary = _layout_for_seed(root_seed, recipe)
		var second: Dictionary = _layout_for_seed(root_seed, recipe)
		assert_equal(first, second, "Approved seed %d must reproduce a byte-identical layout across two generations." % root_seed)


func _approved_seeds_show_meaningful_divergence() -> void:
	var distinct: Dictionary = {}
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		distinct[String(APPROVED_FINGERPRINTS[seed_key])] = true
	assert_true(distinct.size() >= 2, "Approved fixture seeds must produce at least two distinct layouts (AC1 meaningful divergence).")
