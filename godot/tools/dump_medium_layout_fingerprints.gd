extends SceneTree

# One-shot dev tool: dump approved-seed fingerprints for medium_combat_basic so the seed-regression
# test can pin them. NOT a test (lives under tools/, not auto-discovered). Run via:
#   godot --headless --path C:\Sealsworn\godot --script res://tools/dump_medium_layout_fingerprints.gd

const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")

func _init() -> void:
	var seeds: Array[int] = [1001, 2002, 3003, 4004, 5005]
	var recipe = LevelRecipeRepository.create_baseline_repository().get_recipe(&"medium_combat_basic")
	for seed_value: int in seeds:
		var request := GenerationRequest.new(
			seed_value, &"node_1", &"combat", &"medium_combat_basic",
			GenerationRequest.SIZE_MEDIUM, GenerationRequest.DIFFICULTY_STANDARD,
			GenerationRequest.AFFINITY_NONE, {}
		)
		var streams := RngStreamSet.new(request.level_seed())
		var generator := MediumLevelLayoutGenerator.new()
		var layout = generator.generate_layout(request, recipe, streams).metadata.get("layout")
		print("SEED %d => %s" % [seed_value, MediumLevelLayoutGenerator.fingerprint(layout)])
	quit()
