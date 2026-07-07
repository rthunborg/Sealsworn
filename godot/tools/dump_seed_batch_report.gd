extends SceneTree

# One-shot dev tool (Story 3.7.4): dump the FULL LevelGenerator.generate(...) batch report for the
# approved Small + Medium seed catalog — per seed + recipe, the validation status (succeeded / attempts /
# validated) PLUS the compact TERRAIN fingerprint reconstructed from the generate payload board. Used to
# regenerate / eyeball the batch catalog pinned in tests/unit/generation/test_seed_batch_regression.gd.
#
# NOT a test (lives under tools/, NOT auto-discovered by the headless runner). DEBUG/manual-seed tool:
# it grants NO progression and writes NO `user://` artifact (it only prints). Build-profile-appropriate
# (a tools/ SceneTree script, never shipped as gameplay). Run via PowerShell:
#   godot --headless --path C:\Sealsworn\godot --script res://tools/dump_seed_batch_report.gd

const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")

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
			if generation.succeeded:
				print("SEED %d => succeeded=%s attempts=%d validated=%s | %s" % [
					seed_value,
					generation.succeeded,
					int(generation.diagnostics.get("attempts", -1)),
					bool(generation.diagnostics.get("validated", false)),
					_terrain_fingerprint_from_payload(generation.payload)
				])
			else:
				print("SEED %d => FAILED phase=%s code=%s reason=%s" % [
					seed_value,
					String(generation.failed_phase),
					String(generation.error_code),
					String(generation.reason)
				])
	quit()


# Reconstruct the layout-shaped dict from the generate payload board and compute the TERRAIN fingerprint
# via the existing static (no second format). Mirrors the batch test's reconstruction.
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
