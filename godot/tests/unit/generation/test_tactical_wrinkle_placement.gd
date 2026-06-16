extends "res://tests/unit/test_case.gd"

# Story 3.4 — Tactical Wrinkles, Blockers, and Hazards.
#
# Focused AC1/AC2/AC3 coverage for the deterministic tactical-wrinkle placement added to BOTH layout
# generators (via the shared TacticalWrinklePlacer):
#   AC1 — at least min_tactical_wrinkles wrinkles placed for each combat recipe; placed kinds recorded
#         in diagnostics and a subset of the recipe allowlist; selection is deterministic and drawn
#         ONLY from the `level` stream (stream isolation); the FIRST HAZARD emission lands correctly.
#   AC2 — entrance->exit progress remains possible with wrinkles present (reachable over non-WALL
#         cells, the mandatory path is FLOOR/HAZARD/ENTRANCE/EXIT only — no class/weapon/item gate);
#         wrinkle WALL cells never touch the corridor/entrance/exit; HAZARD is walkable.
#   AC3 — the hazard rides the strict BoardState.try_from_snapshot + TacticalSnapshot.from_domain/parse
#         path + a real JSON round-trip, and the restored hazard cell still reads HAZARD.
#
# Headless / scene-free. Builds boards + snapshots in-memory only (no user:// writes).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")
const TacticalWrinklePlacer = preload("res://scripts/generation/level/tactical_wrinkle_placer.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

const SMALL_WIDTH: int = 8
const SMALL_HEIGHT: int = 8
const MEDIUM_WIDTH: int = 14
const MEDIUM_HEIGHT: int = 12

# Fixed 4-neighbour offsets for the independent reachability flood used by the AC2 assertions. An
# INDEPENDENT flood (not the generator's _flood_reachable) so the test verifies reachability rather
# than re-asserting the implementation against itself.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

func run() -> Dictionary:
	# AC1 — wrinkle placement + diagnostics
	_small_recipe_places_at_least_minimum_wrinkles()
	_medium_recipe_places_at_least_minimum_wrinkles()
	_placed_kinds_are_subset_of_recipe_allowlist()
	_diagnostics_record_wrinkle_kinds_and_count_small()
	_diagnostics_record_wrinkle_kinds_and_count_medium()
	_realizable_kind_filter_excludes_reward_behind_danger()
	_no_wrinkle_recipe_places_no_wrinkles_and_advances_no_extra_draws()
	_wrinkle_draws_only_from_level_stream()
	_cosmetic_combat_noise_does_not_perturb_wrinkles()
	_same_seed_reproduces_identical_wrinkles()
	_non_realizable_allowlist_fails_loud()
	# AC1 — first HAZARD emission
	_medium_can_emit_hazard_terrain()
	_hazard_cell_is_walkable_and_sight_transparent()
	# AC2 — reachability + no gate, with wrinkles present
	_entrance_reaches_exit_over_non_wall_with_wrinkles_small()
	_entrance_reaches_exit_over_non_wall_with_wrinkles_medium()
	_mandatory_path_is_floor_or_hazard_only_no_gate()
	_wrinkle_wall_cells_never_touch_corridor_entrance_exit()
	_approved_medium_layouts_still_pass_readability_with_wrinkles()
	# AC3 — hazard is loadable, serializable, mirror-able domain data
	_hazard_board_rides_strict_try_from_snapshot()
	_hazard_board_survives_real_json_transport()
	_hazard_board_rides_strict_tactical_snapshot_path()
	return result()


# ---- shared helpers --------------------------------------------------------------------------

func _small_recipe() -> LevelRecipeDefinition:
	return LevelRecipeRepository.create_baseline_repository().get_recipe(&"small_combat_basic")


func _medium_recipe() -> LevelRecipeDefinition:
	return LevelRecipeRepository.create_baseline_repository().get_recipe(&"medium_combat_basic")


func _small_request(root_seed: int) -> GenerationRequest:
	return GenerationRequest.new(
		root_seed, &"node_1", &"combat", &"small_combat_basic",
		GenerationRequest.SIZE_SMALL, GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE, {}
	)


func _medium_request(root_seed: int) -> GenerationRequest:
	return GenerationRequest.new(
		root_seed, &"node_1", &"combat", &"medium_combat_basic",
		GenerationRequest.SIZE_MEDIUM, GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE, {}
	)


func _enemy_repository() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


func _small_layout(root_seed: int, recipe: LevelRecipeDefinition = null) -> Dictionary:
	var request: GenerationRequest = _small_request(root_seed)
	var resolved: LevelRecipeDefinition = recipe if recipe != null else _small_recipe()
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, resolved, streams, _enemy_repository())
	assert_true(layout_result.succeeded, "Small layout generation should succeed. Error: %s" % layout_result.metadata)
	return layout_result.metadata.get("layout")


func _medium_layout(root_seed: int, recipe: LevelRecipeDefinition = null) -> Dictionary:
	var request: GenerationRequest = _medium_request(root_seed)
	var resolved: LevelRecipeDefinition = recipe if recipe != null else _medium_recipe()
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, resolved, streams, _enemy_repository())
	assert_true(layout_result.succeeded, "Medium layout generation should succeed. Error: %s" % layout_result.metadata)
	return layout_result.metadata.get("layout")


func _terrain_at(layout: Dictionary, x: int, y: int) -> int:
	var terrain_grid: Array = layout.get("terrain")
	return int((terrain_grid[y] as Array)[x])


# Independent 4-neighbour flood over non-WALL cells (HAZARD/FLOOR/ENTRANCE/EXIT walkable). Returns a
# visited set keyed by Vector2i.
func _flood_non_wall(layout: Dictionary, origin: Vector2i) -> Dictionary:
	var width: int = int(layout.get("width"))
	var height: int = int(layout.get("height"))
	var visited: Dictionary = {}
	if _terrain_at(layout, origin.x, origin.y) == BoardCell.Terrain.WALL:
		return visited
	var frontier: Array[Vector2i] = [origin]
	visited[origin] = true
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for offset: Vector2i in NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = current + offset
			if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= width or neighbour.y >= height:
				continue
			if visited.has(neighbour):
				continue
			if _terrain_at(layout, neighbour.x, neighbour.y) == BoardCell.Terrain.WALL:
				continue
			visited[neighbour] = true
			frontier.append(neighbour)
	return visited


func _cell_vec(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.get("x")), int(data.get("y")))


# Build a Medium layout for a seed that is known to contain at least one hazard wrinkle. Searches a
# small deterministic seed range so the test is robust to the exact draw values.
func _medium_layout_with_hazard() -> Dictionary:
	for seed_value: int in [4004, 5005, 1, 2, 3, 7, 11, 13, 42, 99]:
		var layout: Dictionary = _medium_layout(seed_value)
		if _layout_has_hazard(layout):
			return layout
	assert_true(false, "Expected at least one Medium seed in the probe range to place a hazard wrinkle.")
	return _medium_layout(4004)


func _layout_has_hazard(layout: Dictionary) -> bool:
	var width: int = int(layout.get("width"))
	var height: int = int(layout.get("height"))
	for y: int in range(height):
		for x: int in range(width):
			if _terrain_at(layout, x, y) == BoardCell.Terrain.HAZARD:
				return true
	return false


# ---- AC1: wrinkle placement + diagnostics -----------------------------------------------------

func _small_recipe_places_at_least_minimum_wrinkles() -> void:
	var recipe: LevelRecipeDefinition = _small_recipe()
	for seed_value: int in [1, 2, 3, 101, 202, 303, 1001, 5005]:
		var layout: Dictionary = _small_layout(seed_value, recipe)
		var wrinkles: Array = layout.get("wrinkle_kinds")
		assert_true(
			wrinkles.size() >= recipe.min_tactical_wrinkles,
			"AC1: a combat Small recipe must place at least min_tactical_wrinkles (%d) wrinkles (seed %d placed %d)." % [recipe.min_tactical_wrinkles, seed_value, wrinkles.size()]
		)


func _medium_recipe_places_at_least_minimum_wrinkles() -> void:
	var recipe: LevelRecipeDefinition = _medium_recipe()
	for seed_value: int in [1, 2, 3, 101, 202, 303, 1001, 5005]:
		var layout: Dictionary = _medium_layout(seed_value, recipe)
		var wrinkles: Array = layout.get("wrinkle_kinds")
		assert_true(
			wrinkles.size() >= recipe.min_tactical_wrinkles,
			"AC1: a combat Medium recipe must place at least min_tactical_wrinkles (%d) wrinkles (seed %d placed %d)." % [recipe.min_tactical_wrinkles, seed_value, wrinkles.size()]
		)


func _placed_kinds_are_subset_of_recipe_allowlist() -> void:
	# AC1: a placed kind outside the recipe allowlist is a bug. Check both recipes across several seeds.
	var small_recipe: LevelRecipeDefinition = _small_recipe()
	var small_allowed: Dictionary = _allowed_lookup(small_recipe)
	for seed_value: int in [1, 2, 3, 4, 5, 1001, 2002, 3003]:
		for kind_value: Variant in (_small_layout(seed_value, small_recipe).get("wrinkle_kinds") as Array):
			assert_true(small_allowed.has(String(kind_value)), "AC1: Small placed wrinkle kind '%s' must be in the recipe allowlist (seed %d)." % [String(kind_value), seed_value])

	var medium_recipe: LevelRecipeDefinition = _medium_recipe()
	var medium_allowed: Dictionary = _allowed_lookup(medium_recipe)
	for seed_value: int in [1, 2, 3, 4, 5, 1001, 2002, 3003]:
		for kind_value: Variant in (_medium_layout(seed_value, medium_recipe).get("wrinkle_kinds") as Array):
			assert_true(medium_allowed.has(String(kind_value)), "AC1: Medium placed wrinkle kind '%s' must be in the recipe allowlist (seed %d)." % [String(kind_value), seed_value])


func _allowed_lookup(recipe: LevelRecipeDefinition) -> Dictionary:
	var lookup: Dictionary = {}
	for kind: StringName in recipe.allowed_wrinkle_kinds:
		lookup[String(kind)] = true
	return lookup


func _diagnostics_record_wrinkle_kinds_and_count_small() -> void:
	# AC1 verbatim: "the wrinkle type is recorded in generation diagnostics." Assert the success
	# diagnostics carry `wrinkles` (list of kinds) + `wrinkle_count`, alongside the existing keys.
	var result_value: GenerationResult = LevelGenerator.generate(_small_request(2024), LevelRecipeRepository.create_baseline_repository(), _enemy_repository())
	assert_true(result_value.succeeded, "Small generation should succeed. Error: %s" % result_value.diagnostics)
	assert_true(result_value.diagnostics.has("wrinkles"), "AC1: Small success diagnostics must record the placed wrinkle kinds.")
	assert_true(result_value.diagnostics.has("wrinkle_count"), "AC1: Small success diagnostics must record the wrinkle count.")
	var kinds: Array = result_value.diagnostics.get("wrinkles")
	assert_equal(int(result_value.diagnostics.get("wrinkle_count")), kinds.size(), "AC1: wrinkle_count must match the recorded kinds length.")
	assert_true(kinds.size() >= _small_recipe().min_tactical_wrinkles, "AC1: Small diagnostics wrinkle count must meet the recipe minimum.")
	# The existing diagnostics keys must be preserved.
	assert_true(result_value.diagnostics.has("phase"), "Existing `phase` diagnostic must be preserved.")
	assert_true(result_value.diagnostics.has("blocker_count"), "Existing `blocker_count` diagnostic must be preserved.")


func _diagnostics_record_wrinkle_kinds_and_count_medium() -> void:
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(2024), LevelRecipeRepository.create_baseline_repository(), _enemy_repository())
	assert_true(result_value.succeeded, "Medium generation should succeed. Error: %s" % result_value.diagnostics)
	assert_true(result_value.diagnostics.has("wrinkles"), "AC1: Medium success diagnostics must record the placed wrinkle kinds.")
	assert_true(result_value.diagnostics.has("wrinkle_count"), "AC1: Medium success diagnostics must record the wrinkle count.")
	var kinds: Array = result_value.diagnostics.get("wrinkles")
	assert_equal(int(result_value.diagnostics.get("wrinkle_count")), kinds.size(), "AC1: wrinkle_count must match the recorded kinds length.")
	assert_true(kinds.size() >= _medium_recipe().min_tactical_wrinkles, "AC1: Medium diagnostics wrinkle count must meet the recipe minimum.")
	assert_equal(result_value.diagnostics.get("phase"), String(GenerationResult.PHASE_VALIDATION), "Existing Medium `phase` diagnostic (validation) must be preserved.")


func _realizable_kind_filter_excludes_reward_behind_danger() -> void:
	# reward_behind_danger is in the medium_combat_basic allowlist but is NOT v0-realizable (needs a
	# reward entity, Story 3.5). It must NEVER be a placed kind this story.
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1001, 2002, 3003, 4004, 5005]:
		for kind_value: Variant in (_medium_layout(seed_value).get("wrinkle_kinds") as Array):
			assert_false(
				String(kind_value) == String(LevelRecipeDefinition.WRINKLE_REWARD_BEHIND_DANGER),
				"reward_behind_danger must NOT be realized this story (Story 3.5 owns reward entities) (seed %d)." % seed_value
			)
	# And the placer's filter directly excludes it while keeping the realizable kinds.
	var realizable: Array[StringName] = TacticalWrinklePlacer.select_realizable_kinds(_medium_recipe().allowed_wrinkle_kinds)
	assert_false(realizable.has(LevelRecipeDefinition.WRINKLE_REWARD_BEHIND_DANGER), "select_realizable_kinds must exclude reward_behind_danger.")
	assert_true(realizable.has(LevelRecipeDefinition.WRINKLE_HAZARD), "select_realizable_kinds must keep hazard.")
	assert_true(realizable.has(LevelRecipeDefinition.WRINKLE_CHOKE_POINT), "select_realizable_kinds must keep choke_point.")


func _no_wrinkle_recipe_places_no_wrinkles_and_advances_no_extra_draws() -> void:
	# A non-combat recipe with min_tactical_wrinkles = 0 places NO wrinkles and the placer draws
	# nothing extra. Build a no-wrinkle Small recipe and compare its level-stream draw count to a
	# blocker-equivalent recipe to confirm the wrinkle draws are skipped (stream advances identically
	# to a no-wrinkle run).
	var no_wrinkle_recipe: LevelRecipeDefinition = LevelRecipeDefinition.new(
		&"small_no_wrinkle", LevelRecipeDefinition.SIZE_SMALL, true, 0.1,
		0, 0, 2, 4, 0, 1, false, 0, [], "Small non-combat arena with no wrinkle requirement (test recipe).", false
	)
	assert_true(no_wrinkle_recipe.validate().succeeded, "The no-wrinkle test recipe should validate.")
	var layout: Dictionary = _small_layout(909, no_wrinkle_recipe)
	assert_equal((layout.get("wrinkle_kinds") as Array).size(), 0, "A recipe with min_tactical_wrinkles = 0 must place no wrinkles.")

	# Direct placer probe: min 0 => no draws advance the level stream.
	var request: GenerationRequest = _small_request(909)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var candidate_pool: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 3)]
	var before: int = _level_draw_index(streams)
	var placer_result: ActionResult = TacticalWrinklePlacer.place_wrinkles(request, streams, no_wrinkle_recipe, candidate_pool, "small_layout")
	assert_true(placer_result.succeeded, "place_wrinkles should succeed for a no-wrinkle recipe.")
	assert_equal(_level_draw_index(streams), before, "A no-wrinkle recipe must NOT advance the level stream (wrinkle draws skipped).")


func _level_draw_index(streams: RngStreamSet) -> int:
	var stream_states: Dictionary = streams.to_snapshot().get("streams")
	return int(stream_states.get(String(RngStreamSet.STREAM_LEVEL)).get("draw_index"))


func _wrinkle_draws_only_from_level_stream() -> void:
	# Every wrinkle-affecting draw must advance ONLY the level stream (stream isolation), exactly like
	# the blocker draws. Generate Medium (which uses both kind + position wrinkle draws) and assert no
	# non-level stream advanced.
	var request: GenerationRequest = _medium_request(31337)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, _medium_recipe(), streams, _enemy_repository())
	assert_true(layout_result.succeeded, "Medium generation should succeed for the stream-isolation probe.")
	assert_true((layout_result.metadata.get("layout").get("wrinkle_kinds") as Array).size() >= 2, "The probe layout should have placed wrinkles (so wrinkle draws ran).")

	var stream_states: Dictionary = streams.to_snapshot().get("streams")
	assert_true(int(stream_states.get(String(RngStreamSet.STREAM_LEVEL)).get("draw_index")) > 0, "Generation must consume level-stream draws.")
	for stream_name: StringName in RngStreamSet.required_streams():
		if stream_name == RngStreamSet.STREAM_LEVEL:
			continue
		assert_equal(
			int(stream_states.get(String(stream_name)).get("draw_index")),
			0,
			"Wrinkle + blocker draws must NOT touch the %s stream (level-stream-only contract)." % String(stream_name)
		)


func _cosmetic_combat_noise_does_not_perturb_wrinkles() -> void:
	# Pre-advancing cosmetic/combat streams must not change the wrinkle placement (stream isolation).
	var clean_request: GenerationRequest = _medium_request(24680)
	var noisy_request: GenerationRequest = _medium_request(24680)
	var clean_streams: RngStreamSet = RngStreamSet.new(clean_request.level_seed())
	var noisy_streams: RngStreamSet = RngStreamSet.new(noisy_request.level_seed())
	for noise_index: int in range(5):
		noisy_streams.rand_float(RngStreamSet.STREAM_COSMETIC, {"consumer": "ambient", "step": noise_index})
		noisy_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"consumer": "combat_noise", "step": noise_index})

	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var clean_layout: Dictionary = generator.generate_layout(clean_request, _medium_recipe(), clean_streams, _enemy_repository()).metadata.get("layout")
	var noisy_layout: Dictionary = generator.generate_layout(noisy_request, _medium_recipe(), noisy_streams, _enemy_repository()).metadata.get("layout")
	assert_equal(
		MediumLevelLayoutGenerator.fingerprint(noisy_layout),
		MediumLevelLayoutGenerator.fingerprint(clean_layout),
		"Cosmetic/combat noise must not perturb the wrinkle-bearing layout (stream isolation)."
	)
	assert_equal(clean_layout.get("wrinkles"), noisy_layout.get("wrinkles"), "Cosmetic/combat noise must not change the placed wrinkles.")


func _same_seed_reproduces_identical_wrinkles() -> void:
	# AC1 determinism: the same seed reproduces byte-identical wrinkles (kinds + cells) for both sizes.
	var small_first: Dictionary = _small_layout(8675309)
	var small_second: Dictionary = _small_layout(8675309)
	assert_equal(small_first.get("wrinkles"), small_second.get("wrinkles"), "AC1: the same seed must reproduce identical Small wrinkles.")
	var medium_first: Dictionary = _medium_layout(8675309)
	var medium_second: Dictionary = _medium_layout(8675309)
	assert_equal(medium_first.get("wrinkles"), medium_second.get("wrinkles"), "AC1: the same seed must reproduce identical Medium wrinkles.")


func _non_realizable_allowlist_fails_loud() -> void:
	# A combat recipe whose allowlist contains ONLY non-v0-realizable kinds (e.g. door) must fail LOUD
	# from the placer rather than silently under-place. (No baseline recipe is like this; this proves
	# the guard exists for a future recipe.)
	var door_only_recipe: LevelRecipeDefinition = LevelRecipeDefinition.new(
		&"small_door_only", LevelRecipeDefinition.SIZE_SMALL, true, 0.1,
		2, 4, 2, 4, 0, 1, false, 1, [LevelRecipeDefinition.WRINKLE_DOOR], "Small arena requiring only a non-realizable door wrinkle (test recipe)."
	)
	assert_true(door_only_recipe.validate().succeeded, "The door-only recipe should validate (door is a valid GDD kind).")
	var request: GenerationRequest = _small_request(123)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, door_only_recipe, streams, _enemy_repository())
	assert_true(layout_result.is_error(), "A recipe allowing only non-realizable wrinkle kinds must fail loud, not silently under-place.")
	assert_equal(layout_result.error_code, &"no_realizable_wrinkle_kind", "The non-realizable allowlist must surface the stable structured code.")


# ---- AC1: first HAZARD emission ---------------------------------------------------------------

func _medium_can_emit_hazard_terrain() -> void:
	# Medium's recipe allows the hazard kind; over a small deterministic seed range at least one seed
	# must place a HAZARD cell (the FIRST HAZARD this codebase emits). This proves hazards are reachable
	# via the seed space, not merely theoretically allowed.
	var layout: Dictionary = _medium_layout_with_hazard()
	assert_true(_layout_has_hazard(layout), "AC1: a Medium layout must be able to emit a HAZARD terrain cell.")


func _hazard_cell_is_walkable_and_sight_transparent() -> void:
	# CRITICAL HAZARD nuance: a HAZARD cell is walkable + sight-transparent at the board level (only
	# WALL blocks). Build the board from a hazard-bearing layout and assert the hazard cell's
	# terrain_blocks_occupancy()/blocks_line_of_sight() are BOTH false.
	var layout: Dictionary = _medium_layout_with_hazard()
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board: BoardState = generator.build_board_snapshot(layout).metadata.get("board")
	var hazard_cell: Vector2i = _first_hazard_cell(layout)
	var cell: BoardCell = board.get_cell(hazard_cell)
	assert_equal(cell.terrain, BoardCell.Terrain.HAZARD, "The hazard cell must carry HAZARD terrain on the board.")
	assert_false(cell.terrain_blocks_occupancy(), "AC2/AC3: a HAZARD cell must be walkable (terrain_blocks_occupancy false).")
	assert_false(cell.blocks_line_of_sight(), "A HAZARD cell must be sight-transparent (blocks_line_of_sight false).")


func _first_hazard_cell(layout: Dictionary) -> Vector2i:
	var width: int = int(layout.get("width"))
	var height: int = int(layout.get("height"))
	for y: int in range(height):
		for x: int in range(width):
			if _terrain_at(layout, x, y) == BoardCell.Terrain.HAZARD:
				return Vector2i(x, y)
	assert_true(false, "Expected the layout to contain a hazard cell.")
	return Vector2i(-1, -1)


# ---- AC2: reachability + no gate, with wrinkles present ---------------------------------------

func _entrance_reaches_exit_over_non_wall_with_wrinkles_small() -> void:
	# AC2: with wrinkles placed, the entrance still reaches the exit over non-WALL (walkable, incl.
	# HAZARD) cells. Independent flood over several Small seeds.
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 5005]:
		var layout: Dictionary = _small_layout(seed_value)
		var reachable: Dictionary = _flood_non_wall(layout, _cell_vec(layout.get("entrance")))
		assert_true(reachable.has(_cell_vec(layout.get("exit"))), "AC2: entrance must reach exit over non-WALL cells with wrinkles present (Small seed %d)." % seed_value)


func _entrance_reaches_exit_over_non_wall_with_wrinkles_medium() -> void:
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 4004, 5005]:
		var layout: Dictionary = _medium_layout(seed_value)
		var reachable: Dictionary = _flood_non_wall(layout, _cell_vec(layout.get("entrance")))
		assert_true(reachable.has(_cell_vec(layout.get("exit"))), "AC2: entrance must reach exit over non-WALL cells with wrinkles present (Medium seed %d)." % seed_value)


func _mandatory_path_is_floor_or_hazard_only_no_gate() -> void:
	# AC2 part 3 (no required class/weapon/item gate): the entrance->exit path exists over
	# FLOOR/HAZARD/ENTRANCE/EXIT cells only — never through a WALL and never requiring an item/key.
	# v0 has no doors/keys/locks, so the only progress requirement is walkable terrain. Reconstruct a
	# path on a hazard-bearing layout and assert every cell on it is one of those terrains.
	var layout: Dictionary = _medium_layout_with_hazard()
	var entrance: Vector2i = _cell_vec(layout.get("entrance"))
	var exit_cell: Vector2i = _cell_vec(layout.get("exit"))
	var path: Array[Vector2i] = _shortest_path_non_wall(layout, entrance, exit_cell)
	assert_true(path.size() > 0, "AC2: a walkable entrance->exit path must exist on a hazard-bearing layout.")
	for step: Vector2i in path:
		var terrain: int = _terrain_at(layout, step.x, step.y)
		assert_true(
			terrain == BoardCell.Terrain.FLOOR
				or terrain == BoardCell.Terrain.HAZARD
				or terrain == BoardCell.Terrain.ENTRANCE
				or terrain == BoardCell.Terrain.EXIT,
			"AC2: every mandatory-path cell must be FLOOR/HAZARD/ENTRANCE/EXIT (no gate); got terrain %d at (%d,%d)." % [terrain, step.x, step.y]
		)


# BFS shortest path over non-WALL cells (returns the cell sequence entrance..exit, or empty if none).
func _shortest_path_non_wall(layout: Dictionary, origin: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var width: int = int(layout.get("width"))
	var height: int = int(layout.get("height"))
	var came_from: Dictionary = {}
	var frontier: Array[Vector2i] = [origin]
	came_from[origin] = origin
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		if current == goal:
			break
		for offset: Vector2i in NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = current + offset
			if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= width or neighbour.y >= height:
				continue
			if came_from.has(neighbour):
				continue
			if _terrain_at(layout, neighbour.x, neighbour.y) == BoardCell.Terrain.WALL:
				continue
			came_from[neighbour] = current
			frontier.append(neighbour)
	if not came_from.has(goal):
		return []
	var path: Array[Vector2i] = []
	var node: Vector2i = goal
	while node != origin:
		path.push_front(node)
		node = came_from[node]
	path.push_front(origin)
	return path


func _wrinkle_wall_cells_never_touch_corridor_entrance_exit() -> void:
	# AC2 part 1: WALL wrinkle cells must never land on the entrance, exit, or the reserved corridor
	# row (they route through the same candidate discipline as blockers). Also confirm HAZARD wrinkles
	# stay off those cells (the corridor is the safe mandatory route).
	for seed_value: int in [1, 2, 3, 4, 5, 1001, 2002, 3003, 4004, 5005]:
		var layout: Dictionary = _medium_layout(seed_value)
		var entrance: Vector2i = _cell_vec(layout.get("entrance"))
		var exit_cell: Vector2i = _cell_vec(layout.get("exit"))
		var corridor_row: int = entrance.y
		for wrinkle_value: Variant in (layout.get("wrinkles") as Array):
			var wrinkle: Dictionary = wrinkle_value
			var cell: Vector2i = Vector2i(int(wrinkle.get("x")), int(wrinkle.get("y")))
			assert_false(cell == entrance, "AC2: a wrinkle must never land on the entrance (seed %d)." % seed_value)
			assert_false(cell == exit_cell, "AC2: a wrinkle must never land on the exit (seed %d)." % seed_value)
			assert_false(cell.y == corridor_row, "AC2: a wrinkle must never land on the reserved corridor row (seed %d, cell %s)." % [seed_value, cell])


func _approved_medium_layouts_still_pass_readability_with_wrinkles() -> void:
	# AC2: with wrinkles placed, approved-seed Medium layouts still pass all three readability checks
	# (the wrinkle WALL count stays far below the 0.35 interior bound; the corridor stays open).
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	for seed_value: int in [1001, 2002, 3003, 4004, 5005, 12345, 1, 2, 3]:
		var layout: Dictionary = _medium_layout(seed_value)
		var validation: ActionResult = generator.validate_readability(layout)
		assert_true(validation.succeeded, "AC2: an approved-seed Medium layout (seed %d) must still pass readability with wrinkles present. Error: %s" % [seed_value, validation.metadata])


# ---- AC3: hazard is loadable, serializable, mirror-able domain data ----------------------------

func _hazard_board_rides_strict_try_from_snapshot() -> void:
	# AC3 part 1: a hazard-bearing layout converts to a board snapshot in the EXACT to_snapshot() shape
	# and passes the STRICT BoardState.try_from_snapshot with the hazard cell present (HAZARD is a valid
	# terrain). Story 3.5: the Medium board now carries placed enemies (entities no longer empty).
	var layout: Dictionary = _medium_layout_with_hazard()
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board_result: ActionResult = generator.build_board_snapshot(layout)
	assert_true(board_result.succeeded, "AC3: a hazard-bearing layout must convert through the strict validator. Error: %s" % board_result.metadata)
	var board_variant: Variant = board_result.metadata.get("board")
	assert_false(board_variant is Node, "AC3: the generated board must be scene-independent domain state, not a Node.")
	var board: BoardState = board_variant
	assert_true(board.entity_count() > 0, "Story 3.5: the generated Medium board must now carry placed enemies.")
	var hazard_cell: Vector2i = _first_hazard_cell(layout)
	assert_equal(board.get_cell(hazard_cell).terrain, BoardCell.Terrain.HAZARD, "AC3: the hazard cell must read HAZARD terrain on the strictly-validated board.")


func _hazard_board_survives_real_json_transport() -> void:
	# AC3 part 2: the hazard-bearing board snapshot survives a real JSON.stringify -> parse_string
	# round-trip and re-converts via the strict validator, with the hazard cell preserved.
	var layout: Dictionary = _medium_layout_with_hazard()
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board_snapshot: Dictionary = generator.build_board_snapshot(layout).metadata.get("board_snapshot")

	var parsed: Variant = JSON.parse_string(JSON.stringify(board_snapshot))
	assert_true(parsed is Dictionary, "AC3: the hazard board snapshot must survive JSON stringify/parse as a dictionary.")
	var restore_result: ActionResult = BoardState.try_from_snapshot(parsed)
	assert_true(restore_result.succeeded, "AC3: the JSON-round-tripped hazard board snapshot must restore through the strict validator. Error: %s" % restore_result.metadata)
	var restored_board: BoardState = restore_result.metadata.get("board")
	var hazard_cell: Vector2i = _first_hazard_cell(layout)
	assert_equal(restored_board.get_cell(hazard_cell).terrain, BoardCell.Terrain.HAZARD, "AC3: the restored hazard cell must still read HAZARD after the real JSON round-trip.")


func _hazard_board_rides_strict_tactical_snapshot_path() -> void:
	# AC3 part 2 (continued): the hazard-bearing board must ride the SAME strict TacticalSnapshot
	# from_domain -> JSON -> parse path the save/resume layer uses, and the restored board's hazard cell
	# must still read HAZARD.
	var layout: Dictionary = _medium_layout_with_hazard()
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board: BoardState = generator.build_board_snapshot(layout).metadata.get("board")
	var streams: RngStreamSet = RngStreamSet.new(56789)

	var snapshot_result: ActionResult = TacticalSnapshot.from_domain(board, streams)
	assert_true(snapshot_result.succeeded, "AC3: the hazard board must build a valid TacticalSnapshot through from_domain. Error: %s" % snapshot_result.metadata)
	var snapshot: TacticalSnapshot = snapshot_result.metadata.get("snapshot")

	var json_dict: Variant = JSON.parse_string(JSON.stringify(snapshot.to_dictionary()))
	assert_true(json_dict is Dictionary, "AC3: the hazard tactical snapshot must survive a JSON round-trip.")
	var parse_result: ActionResult = TacticalSnapshot.parse(json_dict)
	assert_true(parse_result.succeeded, "AC3: the hazard tactical snapshot must re-parse through the strict TacticalSnapshot.parse path. Error: %s" % parse_result.metadata)
	# parse() returns the validated TacticalSnapshot; its `board` dict is the strictly-validated board
	# snapshot. Re-validate it to read the restored hazard cell terrain.
	var restored_snapshot: TacticalSnapshot = parse_result.metadata.get("snapshot")
	var restored_board_result: ActionResult = BoardState.try_from_snapshot(restored_snapshot.board)
	assert_true(restored_board_result.succeeded, "AC3: the parsed snapshot's board must restore through the strict validator. Error: %s" % restored_board_result.metadata)
	var restored_board: BoardState = restored_board_result.metadata.get("board")
	var hazard_cell: Vector2i = _first_hazard_cell(layout)
	assert_equal(restored_board.get_cell(hazard_cell).terrain, BoardCell.Terrain.HAZARD, "AC3: the hazard cell must still read HAZARD after the strict TacticalSnapshot round-trip.")
