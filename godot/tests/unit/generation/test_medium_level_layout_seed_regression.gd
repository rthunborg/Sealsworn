extends "res://tests/unit/test_case.gd"

# Story 3.3 — Medium layout seed-regression fixtures (AC1 + AC3).
#
# Pins a small set of APPROVED root_seed fixtures for medium_combat_basic to a stable layout
# fingerprint. For each seed: generate twice and assert the two outputs are byte-identical
# (determinism), and assert the fingerprint matches the pinned EXPECTED value. A drift fails the
# test with the FAILING root_seed in the assert message (AC3 verbatim: "regressions include the
# failing seed in test output"). The test also asserts the approved seeds collectively produce more
# than one distinct layout (AC1: meaningful divergence). Headless / scene-free (AC3 second half).
#
# DELIBERATE-UPDATE CONTRACT: these pinned fingerprints change ONLY with an intentional generator or
# recipe change — and the story/PR that makes that change re-pins them here. They must NEVER be
# updated silently to make a drifting test pass. If a fingerprint drift is intentional, regenerate
# via tools/dump_medium_layout_fingerprints.gd and update both the value AND the change log.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")

# Approved seed -> expected layout fingerprint for medium_combat_basic. Generated 2026-06-16 via
# tools/dump_medium_layout_fingerprints.gd.
const APPROVED_FINGERPRINTS: Dictionary = {
	1001: "14x12|e1,6|x12,6|11111111111111/10000010000001/10000000000001/10000000000001/10000000000001/10010000000001/13000000000041/10000000000001/10100000000001/10000000000001/10000000000001/11111111111111",
	2002: "14x12|e1,6|x12,6|11111111111111/10010000000001/10000010001001/10000000000001/10000010000001/10000000010001/13000000000041/10000000000001/10000000000001/11000100000001/10000000000001/11111111111111",
	3003: "14x12|e1,6|x12,6|11111111111111/10000000000001/10000000000001/10000000011001/10000000000001/10000000000001/13000000000041/10000000010001/10000010000001/10000000000011/11000000000001/11111111111111",
	4004: "14x12|e1,6|x12,6|11111111111111/10010000000001/11000000000001/10000000010001/10000000000001/10001000000001/13000000000041/10000000000001/10100000000001/10000000000001/10000000000001/11111111111111",
	5005: "14x12|e1,6|x12,6|11111111111111/10000000000001/10000000000001/10000000000001/10000000000001/10000010000001/13000000000041/10000000000001/10000000000001/10000000000001/10100001000001/11111111111111"
}

func run() -> Dictionary:
	_approved_seeds_match_pinned_fingerprints()
	_approved_seeds_are_internally_deterministic()
	_approved_seeds_show_meaningful_divergence()
	return result()


func _recipe() -> LevelRecipeDefinition:
	return LevelRecipeRepository.create_baseline_repository().get_recipe(&"medium_combat_basic")


func _layout_for_seed(root_seed: int, recipe: LevelRecipeDefinition) -> Dictionary:
	var request: GenerationRequest = GenerationRequest.new(
		root_seed, &"node_1", &"combat", &"medium_combat_basic",
		GenerationRequest.SIZE_MEDIUM, GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE, {}
	)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, recipe, streams)
	assert_true(layout_result.succeeded, "Approved-seed %d should generate a Medium layout. Error: %s" % [root_seed, layout_result.metadata])
	return layout_result.metadata.get("layout")


func _approved_seeds_match_pinned_fingerprints() -> void:
	var recipe: LevelRecipeDefinition = _recipe()
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		var root_seed: int = int(seed_key)
		var expected: String = String(APPROVED_FINGERPRINTS[seed_key])
		var actual: String = MediumLevelLayoutGenerator.fingerprint(_layout_for_seed(root_seed, recipe))
		# AC3: the failing seed MUST appear in the assert message on a regression.
		assert_equal(actual, expected, "Medium layout fingerprint regression for root_seed=%d. If this change is intentional, re-pin via tools/dump_medium_layout_fingerprints.gd and update the change log." % root_seed)


func _approved_seeds_are_internally_deterministic() -> void:
	var recipe: LevelRecipeDefinition = _recipe()
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		var root_seed: int = int(seed_key)
		var first: Dictionary = _layout_for_seed(root_seed, recipe)
		var second: Dictionary = _layout_for_seed(root_seed, recipe)
		assert_equal(first, second, "Approved seed %d must reproduce a byte-identical Medium layout across two generations." % root_seed)


func _approved_seeds_show_meaningful_divergence() -> void:
	var distinct: Dictionary = {}
	for seed_key: Variant in APPROVED_FINGERPRINTS.keys():
		distinct[String(APPROVED_FINGERPRINTS[seed_key])] = true
	assert_true(distinct.size() >= 2, "Approved fixture seeds must produce at least two distinct Medium layouts (AC1 meaningful divergence).")
