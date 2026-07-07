extends SceneTree

# One-shot dev tool: dump approved-seed fingerprints for medium_combat_basic so the seed-regression
# test can pin them. NOT a test (lives under tools/, not auto-discovered). Run via:
#   godot --headless --path C:\Sealsworn\godot --script res://tools/dump_medium_layout_fingerprints.gd

const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")

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
	var recipe = LevelRecipeRepository.create_baseline_repository().get_recipe(&"medium_combat_basic")
	# Story 3.5: generate_layout now needs the enemy repository (enemies are placed). The fingerprint is
	# TERRAIN-ONLY, so enemies/rewards do NOT change the printed value — this tool's output is unchanged.
	var enemy_repository := EnemyRepository.create_baseline_repository()
	for seed_value: int in seeds:
		var request := GenerationRequest.new(
			seed_value, &"node_1", &"combat", &"medium_combat_basic",
			GenerationRequest.SIZE_MEDIUM, GenerationRequest.DIFFICULTY_STANDARD,
			GenerationRequest.AFFINITY_NONE, {}
		)
		var streams := RngStreamSet.new(request.level_seed())
		var generator := MediumLevelLayoutGenerator.new()
		var layout = generator.generate_layout(request, recipe, streams, enemy_repository).metadata.get("layout")
		print("SEED %d => %s" % [seed_value, MediumLevelLayoutGenerator.fingerprint(layout)])
	quit()
