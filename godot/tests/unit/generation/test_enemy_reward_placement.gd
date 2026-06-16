extends "res://tests/unit/test_case.gd"

# Story 3.5 — Enemy and Reward Placement.
#
# Focused AC1/AC2/AC3/AC4 coverage for the deterministic enemy + reward placement added to BOTH layout
# generators (via the shared EntityRewardPlacer):
#   AC1 — enemies placed on valid unoccupied non-entrance/exit/wall/blocker/wrinkle cells, count within
#         enemy_budget_min..max, no two enemies collide, every enemy cell reachable from the entrance
#         over non-WALL cells (independent 4-neighbour BFS); the budget clamp engages for a high-budget
#         recipe; enemies resolved through the EnemyRepository boundary.
#   AC2 — every intended reward reachable from the entrance; an UNREACHABLE intended reward FAILS
#         validate_reward_reachability with compact diagnostics (hand-built candidate); a reward behind
#         danger (adjacent to/on a HAZARD) is flagged `optional`, a mandatory reward is not; an optional
#         reward is still reachable; Small (allow_reward_behind_danger = false) never places a
#         behind-danger reward.
#   AC3 — same seed+recipe reproduces identical placements (enemies + rewards) for both sizes; ALL
#         placement draws advance ONLY the `level` stream (stream isolation incl. rewards/loot); placement
#         diverges across seeds (>= 2 distinct); cosmetic/combat/rewards/loot noise does not perturb it.
#   AC4 — the enemy-bearing board rides the STRICT BoardState.try_from_snapshot + TacticalSnapshot
#         from_domain/parse path + a real JSON round-trip with enemies present, and the restored board
#         reads the enemies back (occupant invariant: blocking enemies re-derive occupant_id); the payload
#         is pure serializable data (not a Node; JSON-clean); placement mutates no live tactical state.
#
# Headless / scene-free. Builds boards + snapshots in-memory only (no user:// writes). Uses INDEPENDENT
# floods/checks (not the generator's helpers) so the test verifies behaviour rather than re-asserting the
# implementation against itself.

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
const EntityRewardPlacer = preload("res://scripts/generation/level/entity_reward_placer.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")

const SMALL_WIDTH: int = 8
const SMALL_HEIGHT: int = 8
const MEDIUM_WIDTH: int = 14
const MEDIUM_HEIGHT: int = 12

# INDEPENDENT 4-neighbour offsets for the reachability floods used by the AC1/AC2 assertions.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

func run() -> Dictionary:
	# AC1 — enemy placement legality + budget + reachability
	_small_enemy_count_within_budget()
	_medium_enemy_count_within_budget()
	_enemies_never_on_entrance_exit_wall_blocker_wrinkle_small()
	_enemies_never_on_entrance_exit_wall_blocker_wrinkle_medium()
	_enemies_never_collide_small()
	_enemies_never_collide_medium()
	_every_enemy_cell_reachable_from_entrance_small()
	_every_enemy_cell_reachable_from_entrance_medium()
	_enemy_entities_are_valid_and_resolved_through_repository()
	_enemy_budget_clamps_to_candidate_count()
	# AC2 — reward placement + reachability + optional flag
	_reward_count_within_band_small()
	_reward_count_within_band_medium()
	_every_reward_reachable_from_entrance()
	_unreachable_reward_fails_validation_with_compact_diagnostics()
	_reachable_reward_passes_validation()
	_behind_danger_reward_is_flagged_optional()
	_mandatory_reward_is_not_optional()
	_optional_reward_is_still_reachable()
	_small_never_places_behind_danger_reward()
	# AC3 — determinism + stream isolation + divergence
	_same_seed_reproduces_identical_placement_small()
	_same_seed_reproduces_identical_placement_medium()
	_placement_draws_only_from_level_stream()
	_cosmetic_combat_reward_loot_noise_does_not_perturb_placement()
	_placement_diverges_across_seeds()
	# AC4 — phase output / strict path / no live mutation
	_enemy_board_rides_strict_try_from_snapshot()
	_enemy_board_survives_real_json_transport()
	_enemy_board_rides_strict_tactical_snapshot_path()
	_occupant_invariant_blocking_enemies_re_derive_occupant()
	_payload_is_pure_serializable_data()
	return result()


# ---- shared helpers --------------------------------------------------------------------------

func _small_recipe() -> LevelRecipeDefinition:
	return LevelRecipeRepository.create_baseline_repository().get_recipe(&"small_combat_basic")


func _medium_recipe() -> LevelRecipeDefinition:
	return LevelRecipeRepository.create_baseline_repository().get_recipe(&"medium_combat_basic")


func _enemy_repository() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


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


func _cell_vec(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.get("x")), int(data.get("y")))


func _enemy_cell(enemy: Dictionary) -> Vector2i:
	var position: Dictionary = enemy.get("position")
	return Vector2i(int(position.get("x")), int(position.get("y")))


# INDEPENDENT 4-neighbour flood over non-WALL cells (HAZARD/FLOOR/ENTRANCE/EXIT walkable). Returns a
# visited set keyed by Vector2i. Deliberately NOT the generator/placer flood so reachability is verified
# rather than re-asserted against the implementation.
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


# Build a Medium layout for a seed known to place at least one OPTIONAL (behind-danger) reward. Searches
# a deterministic seed range so the test is robust to the exact draw values (mirrors the hazard probe in
# test_tactical_wrinkle_placement.gd).
func _medium_layout_with_optional_reward() -> Dictionary:
	for seed_value: int in range(1, 200):
		var layout: Dictionary = _medium_layout(seed_value)
		for reward_value: Variant in (layout.get("rewards") as Array):
			if bool((reward_value as Dictionary).get("optional")):
				return layout
	assert_true(false, "Expected at least one Medium seed in the probe range to place an optional (behind-danger) reward.")
	return _medium_layout(1)


# ---- AC1: enemy placement legality + budget + reachability ------------------------------------

func _small_enemy_count_within_budget() -> void:
	var recipe: LevelRecipeDefinition = _small_recipe()
	for seed_value: int in [1, 2, 3, 101, 202, 303, 1001, 5005]:
		var enemies: Array = _small_layout(seed_value, recipe).get("enemies")
		assert_true(
			enemies.size() >= recipe.enemy_budget_min and enemies.size() <= recipe.enemy_budget_max,
			"AC1: Small enemy count %d (seed %d) must fall within the recipe budget band [%d..%d]." % [enemies.size(), seed_value, recipe.enemy_budget_min, recipe.enemy_budget_max]
		)


func _medium_enemy_count_within_budget() -> void:
	var recipe: LevelRecipeDefinition = _medium_recipe()
	for seed_value: int in [1, 2, 3, 101, 202, 303, 1001, 5005]:
		var enemies: Array = _medium_layout(seed_value, recipe).get("enemies")
		assert_true(
			enemies.size() >= recipe.enemy_budget_min and enemies.size() <= recipe.enemy_budget_max,
			"AC1: Medium enemy count %d (seed %d) must fall within the recipe budget band [%d..%d]." % [enemies.size(), seed_value, recipe.enemy_budget_min, recipe.enemy_budget_max]
		)


func _enemies_never_on_entrance_exit_wall_blocker_wrinkle_small() -> void:
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 5005]:
		_assert_enemies_on_legal_cells(_small_layout(seed_value), seed_value, "Small")


func _enemies_never_on_entrance_exit_wall_blocker_wrinkle_medium() -> void:
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 4004, 5005]:
		_assert_enemies_on_legal_cells(_medium_layout(seed_value), seed_value, "Medium")


func _assert_enemies_on_legal_cells(layout: Dictionary, seed_value: int, label: String) -> void:
	# AC1: no enemy on the entrance, exit, a WALL/blocker, or a wrinkle cell. The enemy cell terrain must
	# be FLOOR or HAZARD (HAZARD is occupiable). Blockers + wrinkles are WALL/HAZARD overlays drawn from
	# the SAME pool, so an enemy can never land on one — assert it independently.
	var entrance: Vector2i = _cell_vec(layout.get("entrance"))
	var exit_cell: Vector2i = _cell_vec(layout.get("exit"))
	var wrinkle_cells: Dictionary = {}
	for wrinkle_value: Variant in (layout.get("wrinkles") as Array):
		var wrinkle: Dictionary = wrinkle_value
		wrinkle_cells[Vector2i(int(wrinkle.get("x")), int(wrinkle.get("y")))] = true
	var blocker_cells: Dictionary = {}
	for blocker_value: Variant in (layout.get("blockers") as Array):
		var blocker: Dictionary = blocker_value
		blocker_cells[Vector2i(int(blocker.get("x")), int(blocker.get("y")))] = true

	for enemy_value: Variant in (layout.get("enemies") as Array):
		var cell: Vector2i = _enemy_cell(enemy_value)
		assert_false(cell == entrance, "AC1: %s enemy must never start on the entrance (seed %d)." % [label, seed_value])
		assert_false(cell == exit_cell, "AC1: %s enemy must never start on the exit (seed %d)." % [label, seed_value])
		assert_false(wrinkle_cells.has(cell), "AC1: %s enemy must never start on a wrinkle cell (seed %d, cell %s)." % [label, seed_value, cell])
		assert_false(blocker_cells.has(cell), "AC1: %s enemy must never start on a blocker cell (seed %d, cell %s)." % [label, seed_value, cell])
		var terrain: int = _terrain_at(layout, cell.x, cell.y)
		assert_true(
			terrain == BoardCell.Terrain.FLOOR or terrain == BoardCell.Terrain.HAZARD,
			"AC1: %s enemy must start on FLOOR or HAZARD terrain (never WALL/ENTRANCE/EXIT); got terrain %d at %s (seed %d)." % [label, terrain, cell, seed_value]
		)


func _enemies_never_collide_small() -> void:
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 5005]:
		_assert_no_enemy_collision(_small_layout(seed_value), seed_value, "Small")


func _enemies_never_collide_medium() -> void:
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 4004, 5005]:
		_assert_no_enemy_collision(_medium_layout(seed_value), seed_value, "Medium")


func _assert_no_enemy_collision(layout: Dictionary, seed_value: int, label: String) -> void:
	var seen: Dictionary = {}
	var seen_ids: Dictionary = {}
	for enemy_value: Variant in (layout.get("enemies") as Array):
		var enemy: Dictionary = enemy_value
		var cell: Vector2i = _enemy_cell(enemy)
		assert_false(seen.has(cell), "AC1: two %s enemies must never occupy the same cell (seed %d, cell %s)." % [label, seed_value, cell])
		seen[cell] = true
		var entity_id: String = String(enemy.get("entity_id"))
		assert_false(seen_ids.has(entity_id), "AC1: %s enemy ids must be unique (seed %d, id %s)." % [label, seed_value, entity_id])
		seen_ids[entity_id] = true


func _every_enemy_cell_reachable_from_entrance_small() -> void:
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 5005]:
		_assert_enemies_reachable(_small_layout(seed_value), seed_value, "Small")


func _every_enemy_cell_reachable_from_entrance_medium() -> void:
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 4004, 5005]:
		_assert_enemies_reachable(_medium_layout(seed_value), seed_value, "Medium")


func _assert_enemies_reachable(layout: Dictionary, seed_value: int, label: String) -> void:
	# AC1 "no enemy starts on ... an unreachable required cell": every enemy cell must be in the
	# entrance-reachable region over non-WALL cells (independent BFS).
	var reachable: Dictionary = _flood_non_wall(layout, _cell_vec(layout.get("entrance")))
	for enemy_value: Variant in (layout.get("enemies") as Array):
		var cell: Vector2i = _enemy_cell(enemy_value)
		assert_true(reachable.has(cell), "AC1: every %s enemy cell must be reachable from the entrance over non-WALL cells (seed %d, cell %s)." % [label, seed_value, cell])


func _enemy_entities_are_valid_and_resolved_through_repository() -> void:
	# AC1/AC3: each placed enemy is a valid TacticalEntityState with entity_type ENEMY, full HP from the
	# definition, and a definition_id that resolves THROUGH the EnemyRepository boundary (never a
	# hardcoded/raw value). Validate each entity and confirm its definition exists in the repository.
	var repository: EnemyRepository = _enemy_repository()
	var layout: Dictionary = _medium_layout(2024)
	var enemies: Array = layout.get("enemies")
	assert_true(enemies.size() > 0, "AC1: the Medium layout must place enemies for the entity-validity probe.")
	for enemy_value: Variant in enemies:
		var enemy: Dictionary = enemy_value
		var parse_result: ActionResult = TacticalEntityState.try_from_dictionary(enemy)
		assert_true(parse_result.succeeded, "AC1: each placed enemy must be a valid TacticalEntityState. Error: %s" % parse_result.metadata)
		var entity: TacticalEntityState = parse_result.metadata.get("entity")
		assert_equal(entity.entity_type, TacticalEntityState.EntityType.ENEMY, "AC1: a placed enemy must be entity_type ENEMY.")
		assert_true(String(entity.faction) != "", "AC1: a placed enemy must have a non-empty faction.")
		var definition_id: StringName = entity.definition_id
		assert_true(repository.has_enemy(definition_id), "AC1: the enemy definition_id '%s' must resolve through the EnemyRepository boundary." % String(definition_id))
		var definition = repository.get_enemy(definition_id)
		assert_equal(entity.max_hp, definition.max_hp, "AC1: a placed enemy's max_hp must come from the resolved definition.")
		assert_equal(entity.current_hp, definition.max_hp, "AC1: a placed enemy must start at full HP (current_hp == max_hp).")
		assert_equal(entity.blocks_movement, definition.blocks_movement, "AC1: a placed enemy's blocks_movement must come from the resolved definition.")


func _enemy_budget_clamps_to_candidate_count() -> void:
	# AC1 budget clamp (closes the Story 3.2-deferred unexercised clamp): a recipe whose enemy budget far
	# exceeds the available candidate cells must clamp the placed count to the candidate count WITHOUT
	# error (mirrors the blocker-count clamp). Build a Small recipe with a huge enemy budget and assert
	# the placed count is bounded by the available cells (well below the budget max) and no error occurs.
	var huge_budget_recipe: LevelRecipeDefinition = LevelRecipeDefinition.new(
		&"small_huge_enemy_budget", LevelRecipeDefinition.SIZE_SMALL, true, 0.1,
		2, 5, 500, 1000, 0, 0, false, 1,
		[LevelRecipeDefinition.WRINKLE_CHOKE_POINT],
		"Small arena with an enemy budget far exceeding available cells (test recipe for the clamp)."
	)
	assert_true(huge_budget_recipe.validate().succeeded, "The huge-enemy-budget test recipe should validate.")
	var layout: Dictionary = _small_layout(909, huge_budget_recipe)
	var enemies: Array = layout.get("enemies")
	# The Small interior (excluding the border ring, the reserved corridor row, entrance, exit, blockers,
	# and the wrinkle) is far below 500, so the count must be clamped to the available cells.
	assert_true(enemies.size() > 0, "AC1: the clamp recipe must still place enemies (clamped to available cells).")
	assert_true(enemies.size() < huge_budget_recipe.enemy_budget_max, "AC1: a budget exceeding available cells must clamp the placed count below the budget max (placed %d)." % enemies.size())
	# No collisions even at the clamp ceiling (the shrinking pool guarantees this).
	_assert_no_enemy_collision(layout, 909, "Small-clamp")
	_assert_enemies_on_legal_cells(layout, 909, "Small-clamp")


# ---- AC2: reward placement + reachability + optional flag -------------------------------------

func _reward_count_within_band_small() -> void:
	var recipe: LevelRecipeDefinition = _small_recipe()
	for seed_value: int in [1, 2, 3, 101, 202, 303, 1001, 5005]:
		var rewards: Array = _small_layout(seed_value, recipe).get("rewards")
		# small_combat_basic reward_count band is 0..1 (zero allowed). A behind-danger reward is skipped
		# for Small (allow_reward_behind_danger = false), so the placed count is <= the drawn count <= max.
		assert_true(
			rewards.size() >= 0 and rewards.size() <= recipe.reward_count_max,
			"AC2: Small reward count %d (seed %d) must be within [0..%d]." % [rewards.size(), seed_value, recipe.reward_count_max]
		)


func _reward_count_within_band_medium() -> void:
	var recipe: LevelRecipeDefinition = _medium_recipe()
	for seed_value: int in [1, 2, 3, 101, 202, 303, 1001, 5005]:
		var rewards: Array = _medium_layout(seed_value, recipe).get("rewards")
		assert_true(
			rewards.size() >= recipe.reward_count_min and rewards.size() <= recipe.reward_count_max,
			"AC2: Medium reward count %d (seed %d) must fall within the recipe band [%d..%d]." % [rewards.size(), seed_value, recipe.reward_count_min, recipe.reward_count_max]
		)


func _every_reward_reachable_from_entrance() -> void:
	# AC2: every intended reward cell is reachable from the entrance over non-WALL cells (independent BFS),
	# for both sizes across seeds. Generated rewards are reachable by construction.
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 5005]:
		var small_layout: Dictionary = _small_layout(seed_value)
		var small_reachable: Dictionary = _flood_non_wall(small_layout, _cell_vec(small_layout.get("entrance")))
		for reward_value: Variant in (small_layout.get("rewards") as Array):
			var cell: Vector2i = Vector2i(int((reward_value as Dictionary).get("x")), int((reward_value as Dictionary).get("y")))
			assert_true(small_reachable.has(cell), "AC2: every Small reward must be reachable from the entrance (seed %d, cell %s)." % [seed_value, cell])
	for seed_value: int in [1, 2, 3, 7, 13, 1001, 3003, 4004, 5005]:
		var medium_layout: Dictionary = _medium_layout(seed_value)
		var medium_reachable: Dictionary = _flood_non_wall(medium_layout, _cell_vec(medium_layout.get("entrance")))
		for reward_value: Variant in (medium_layout.get("rewards") as Array):
			var cell: Vector2i = Vector2i(int((reward_value as Dictionary).get("x")), int((reward_value as Dictionary).get("y")))
			assert_true(medium_reachable.has(cell), "AC2: every Medium reward must be reachable from the entrance (seed %d, cell %s)." % [seed_value, cell])


func _unreachable_reward_fails_validation_with_compact_diagnostics() -> void:
	# AC2: an UNREACHABLE intended reward must FAIL validate_reward_reachability with a structured
	# `unreachable_reward` error carrying COMPACT diagnostics (the offending reward coordinate + the
	# reachable-cell count) — never a full grid dump. The generated rewards are reachable by construction,
	# so the failure path is exercised via a hand-built malformed candidate (a reward walled off in a
	# pocket the entrance cannot reach), mirroring the Medium AC2 hand-built-candidate pattern.
	var terrain_grid: Array = _open_medium_grid()
	# Wall off the bottom-right interior corner into a sealed 1-cell pocket at (12,10): surround it.
	_set_terrain(terrain_grid, 11, 10, BoardCell.Terrain.WALL)
	_set_terrain(terrain_grid, 12, 9, BoardCell.Terrain.WALL)
	# (12,10) is bounded by the border ring on the right + bottom and the two WALL cells above/left.
	var layout: Dictionary = {
		"width": MEDIUM_WIDTH,
		"height": MEDIUM_HEIGHT,
		"entrance": {"x": 1, "y": MEDIUM_HEIGHT / 2},
		"exit": {"x": MEDIUM_WIDTH - 2, "y": MEDIUM_HEIGHT / 2},
		"terrain": terrain_grid
	}
	var sealed_reward: Array = [{"x": 12, "y": 10, "optional": false}]
	# Sanity: the sealed pocket is genuinely unreachable via an independent flood.
	var reachable: Dictionary = _flood_non_wall(layout, Vector2i(1, MEDIUM_HEIGHT / 2))
	assert_false(reachable.has(Vector2i(12, 10)), "Probe setup: the sealed pocket (12,10) must be unreachable from the entrance.")

	var validation: ActionResult = EntityRewardPlacer.validate_reward_reachability(layout, sealed_reward)
	assert_true(validation.is_error(), "AC2: an unreachable intended reward must FAIL reachability validation.")
	assert_equal(validation.error_code, &"unreachable_reward", "AC2: an unreachable reward must use the unreachable_reward code.")
	# Compact diagnostics: the offending reward coordinate + the reachable count; NOT a full grid dump.
	assert_true(validation.metadata.has("reward"), "AC2: unreachable_reward diagnostics must report the offending reward coordinate.")
	assert_true(validation.metadata.has("reachable_cell_count"), "AC2: unreachable_reward diagnostics must report the reachable-cell count.")
	assert_false(validation.metadata.has("terrain"), "AC2: diagnostics must stay compact (no full terrain grid dump).")


func _reachable_reward_passes_validation() -> void:
	# AC2: a reachable reward PASSES validate_reward_reachability. Place a reward on the open corridor row.
	var terrain_grid: Array = _open_medium_grid()
	var layout: Dictionary = {
		"width": MEDIUM_WIDTH,
		"height": MEDIUM_HEIGHT,
		"entrance": {"x": 1, "y": MEDIUM_HEIGHT / 2},
		"exit": {"x": MEDIUM_WIDTH - 2, "y": MEDIUM_HEIGHT / 2},
		"terrain": terrain_grid
	}
	var reachable_reward: Array = [{"x": 5, "y": MEDIUM_HEIGHT / 2, "optional": false}]
	var validation: ActionResult = EntityRewardPlacer.validate_reward_reachability(layout, reachable_reward)
	assert_true(validation.succeeded, "AC2: a reachable reward must PASS reachability validation. Error: %s" % validation.metadata)


func _behind_danger_reward_is_flagged_optional() -> void:
	# AC2: a reward placed behind danger (adjacent to / on a HAZARD) is flagged `optional`. Find a Medium
	# seed that places an optional reward, then confirm that reward cell is on/adjacent to a HAZARD.
	var layout: Dictionary = _medium_layout_with_optional_reward()
	var found_optional: bool = false
	for reward_value: Variant in (layout.get("rewards") as Array):
		var reward: Dictionary = reward_value
		if bool(reward.get("optional")):
			found_optional = true
			var cell: Vector2i = Vector2i(int(reward.get("x")), int(reward.get("y")))
			assert_true(_cell_on_or_adjacent_to_hazard(layout, cell), "AC2: an `optional` reward must be on/adjacent to a HAZARD cell (behind danger) (cell %s)." % cell)
	assert_true(found_optional, "AC2: the probed layout must contain an optional reward.")


func _mandatory_reward_is_not_optional() -> void:
	# AC2: a reward NOT behind danger is `optional = false`. Across many Medium seeds, every non-optional
	# reward must be neither on nor adjacent to a HAZARD cell.
	for seed_value: int in range(1, 60):
		var layout: Dictionary = _medium_layout(seed_value)
		for reward_value: Variant in (layout.get("rewards") as Array):
			var reward: Dictionary = reward_value
			var cell: Vector2i = Vector2i(int(reward.get("x")), int(reward.get("y")))
			if not bool(reward.get("optional")):
				assert_false(_cell_on_or_adjacent_to_hazard(layout, cell), "AC2: a non-optional reward must NOT be on/adjacent to a HAZARD (seed %d, cell %s)." % [seed_value, cell])
			else:
				assert_true(_cell_on_or_adjacent_to_hazard(layout, cell), "AC2: an optional reward must be on/adjacent to a HAZARD (seed %d, cell %s)." % [seed_value, cell])


func _optional_reward_is_still_reachable() -> void:
	# AC2: `optional` means "reachable but guarded/skippable", NOT "stranded". An optional reward must
	# still be reachable from the entrance.
	var layout: Dictionary = _medium_layout_with_optional_reward()
	var reachable: Dictionary = _flood_non_wall(layout, _cell_vec(layout.get("entrance")))
	for reward_value: Variant in (layout.get("rewards") as Array):
		var reward: Dictionary = reward_value
		if bool(reward.get("optional")):
			var cell: Vector2i = Vector2i(int(reward.get("x")), int(reward.get("y")))
			assert_true(reachable.has(cell), "AC2: an optional reward must still be reachable (not stranded) (cell %s)." % cell)


func _small_never_places_behind_danger_reward() -> void:
	# AC2: small_combat_basic has allow_reward_behind_danger = false, so a Small reward is never optional
	# (and never on/adjacent to a HAZARD — Small never emits HAZARD anyway). Probe many seeds.
	for seed_value: int in range(1, 80):
		var layout: Dictionary = _small_layout(seed_value)
		for reward_value: Variant in (layout.get("rewards") as Array):
			assert_false(bool((reward_value as Dictionary).get("optional")), "AC2: a Small reward must never be flagged optional (allow_reward_behind_danger = false) (seed %d)." % seed_value)


func _cell_on_or_adjacent_to_hazard(layout: Dictionary, cell: Vector2i) -> bool:
	var width: int = int(layout.get("width"))
	var height: int = int(layout.get("height"))
	if _terrain_at(layout, cell.x, cell.y) == BoardCell.Terrain.HAZARD:
		return true
	for offset: Vector2i in NEIGHBOUR_OFFSETS:
		var neighbour: Vector2i = cell + offset
		if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= width or neighbour.y >= height:
			continue
		if _terrain_at(layout, neighbour.x, neighbour.y) == BoardCell.Terrain.HAZARD:
			return true
	return false


# ---- AC3: determinism + stream isolation + divergence -----------------------------------------

func _same_seed_reproduces_identical_placement_small() -> void:
	# AC3: the same seed + recipe reproduces byte-identical enemies + rewards (compare the placed lists).
	var first: Dictionary = _small_layout(8675309)
	var second: Dictionary = _small_layout(8675309)
	assert_equal(first.get("enemies"), second.get("enemies"), "AC3: the same seed must reproduce identical Small enemy placement.")
	assert_equal(first.get("rewards"), second.get("rewards"), "AC3: the same seed must reproduce identical Small reward placement.")


func _same_seed_reproduces_identical_placement_medium() -> void:
	var first: Dictionary = _medium_layout(8675309)
	var second: Dictionary = _medium_layout(8675309)
	assert_equal(first.get("enemies"), second.get("enemies"), "AC3: the same seed must reproduce identical Medium enemy placement.")
	assert_equal(first.get("rewards"), second.get("rewards"), "AC3: the same seed must reproduce identical Medium reward placement.")


func _placement_draws_only_from_level_stream() -> void:
	# AC3: ALL placement draws (enemy count/positions/kinds, reward count/positions) advance ONLY the
	# `level` stream — never the rewards/loot/combat/cosmetic/map/events streams (the rewards/loot streams
	# are reserved for runtime resolution, Epic 6+, NOT generation placement).
	var request: GenerationRequest = _medium_request(31337)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var layout_result: ActionResult = generator.generate_layout(request, _medium_recipe(), streams, _enemy_repository())
	assert_true(layout_result.succeeded, "Medium generation should succeed for the placement stream-isolation probe.")
	assert_true((layout_result.metadata.get("layout").get("enemies") as Array).size() > 0, "The probe layout should have placed enemies (so placement draws ran).")

	var stream_states: Dictionary = streams.to_snapshot().get("streams")
	assert_true(int(stream_states.get(String(RngStreamSet.STREAM_LEVEL)).get("draw_index")) > 0, "Placement must consume level-stream draws.")
	for stream_name: StringName in RngStreamSet.required_streams():
		if stream_name == RngStreamSet.STREAM_LEVEL:
			continue
		assert_equal(
			int(stream_states.get(String(stream_name)).get("draw_index")),
			0,
			"AC3: enemy/reward placement must NOT touch the %s stream (level-stream-only contract; rewards/loot reserved for Epic 6 runtime resolution)." % String(stream_name)
		)


func _cosmetic_combat_reward_loot_noise_does_not_perturb_placement() -> void:
	# AC3 stream isolation: pre-advancing the cosmetic/combat/rewards/loot streams must NOT change the
	# placement (enemies + rewards). Generate clean vs noisy from the same seed and compare placement.
	var clean_request: GenerationRequest = _medium_request(24680)
	var noisy_request: GenerationRequest = _medium_request(24680)
	var clean_streams: RngStreamSet = RngStreamSet.new(clean_request.level_seed())
	var noisy_streams: RngStreamSet = RngStreamSet.new(noisy_request.level_seed())
	for noise_index: int in range(5):
		noisy_streams.rand_float(RngStreamSet.STREAM_COSMETIC, {"consumer": "ambient", "step": noise_index})
		noisy_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"consumer": "combat_noise", "step": noise_index})
		noisy_streams.rand_int(RngStreamSet.STREAM_REWARDS, 1, 6, {"consumer": "reward_noise", "step": noise_index})
		noisy_streams.rand_int(RngStreamSet.STREAM_LOOT, 1, 6, {"consumer": "loot_noise", "step": noise_index})

	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var clean_layout: Dictionary = generator.generate_layout(clean_request, _medium_recipe(), clean_streams, _enemy_repository()).metadata.get("layout")
	var noisy_layout: Dictionary = generator.generate_layout(noisy_request, _medium_recipe(), noisy_streams, _enemy_repository()).metadata.get("layout")
	assert_equal(clean_layout.get("enemies"), noisy_layout.get("enemies"), "AC3: cosmetic/combat/rewards/loot noise must not perturb the enemy placement.")
	assert_equal(clean_layout.get("rewards"), noisy_layout.get("rewards"), "AC3: cosmetic/combat/rewards/loot noise must not perturb the reward placement.")


func _placement_diverges_across_seeds() -> void:
	# AC3 second half: different seeds produce meaningfully different placements. Fingerprint the placement
	# (enemies + rewards) for several seeds and assert at least two are distinct — independent of the
	# terrain fingerprint.
	var fingerprints: Dictionary = {}
	for seed_value: int in [11, 22, 33, 44, 55, 66, 77]:
		var layout: Dictionary = _medium_layout(seed_value)
		fingerprints[_placement_fingerprint(layout)] = true
	assert_true(fingerprints.size() >= 2, "AC3: different seeds must produce meaningfully different placements (got %d distinct)." % fingerprints.size())


func _placement_fingerprint(layout: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for enemy_value: Variant in (layout.get("enemies") as Array):
		var cell: Vector2i = _enemy_cell(enemy_value)
		parts.append("e%d,%d:%s" % [cell.x, cell.y, String((enemy_value as Dictionary).get("definition_id"))])
	for reward_value: Variant in (layout.get("rewards") as Array):
		var reward: Dictionary = reward_value
		parts.append("r%d,%d:%s" % [int(reward.get("x")), int(reward.get("y")), str(reward.get("optional"))])
	return "|".join(parts)


# ---- AC4: phase output / strict path / no live mutation ---------------------------------------

func _enemy_board_rides_strict_try_from_snapshot() -> void:
	# AC4: an enemy-bearing layout converts to a board snapshot in the EXACT to_snapshot() shape and
	# passes the STRICT BoardState.try_from_snapshot with enemies present (validate-then-reject). The
	# board is scene-independent domain state, not a Node.
	var layout: Dictionary = _medium_layout(2024)
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board_result: ActionResult = generator.build_board_snapshot(layout)
	assert_true(board_result.succeeded, "AC4: an enemy-bearing layout must convert through the strict validator. Error: %s" % board_result.metadata)
	var board_variant: Variant = board_result.metadata.get("board")
	assert_false(board_variant is Node, "AC4: the generated board must be scene-independent domain state, not a Node.")
	var board: BoardState = board_variant
	assert_equal(board.entity_count(), (layout.get("enemies") as Array).size(), "AC4: the strictly-validated board must carry exactly the placed enemies.")


func _enemy_board_survives_real_json_transport() -> void:
	# AC4: the enemy-bearing board snapshot survives a real JSON.stringify -> parse_string round-trip and
	# re-converts via the strict validator, with the enemies preserved.
	var layout: Dictionary = _medium_layout(98765)
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board_snapshot: Dictionary = generator.build_board_snapshot(layout).metadata.get("board_snapshot")

	var parsed: Variant = JSON.parse_string(JSON.stringify(board_snapshot))
	assert_true(parsed is Dictionary, "AC4: the enemy board snapshot must survive JSON stringify/parse as a dictionary.")
	var restore_result: ActionResult = BoardState.try_from_snapshot(parsed)
	assert_true(restore_result.succeeded, "AC4: the JSON-round-tripped enemy board must restore through the strict validator. Error: %s" % restore_result.metadata)
	var restored_board: BoardState = restore_result.metadata.get("board")
	assert_equal(restored_board.entity_count(), (layout.get("enemies") as Array).size(), "AC4: the JSON-round-tripped board must preserve the placed enemies.")


func _enemy_board_rides_strict_tactical_snapshot_path() -> void:
	# AC4: the enemy-bearing board must ride the SAME strict TacticalSnapshot from_domain -> JSON -> parse
	# path the save/resume layer uses, and the restored board must read the enemies back.
	var layout: Dictionary = _medium_layout(56789)
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board: BoardState = generator.build_board_snapshot(layout).metadata.get("board")
	var enemy_total: int = (layout.get("enemies") as Array).size()
	assert_true(enemy_total > 0, "AC4: the probe layout must place enemies for the TacticalSnapshot path.")
	var streams: RngStreamSet = RngStreamSet.new(56789)

	var snapshot_result: ActionResult = TacticalSnapshot.from_domain(board, streams)
	assert_true(snapshot_result.succeeded, "AC4: the enemy board must build a valid TacticalSnapshot through from_domain. Error: %s" % snapshot_result.metadata)
	var snapshot: TacticalSnapshot = snapshot_result.metadata.get("snapshot")

	var json_dict: Variant = JSON.parse_string(JSON.stringify(snapshot.to_dictionary()))
	assert_true(json_dict is Dictionary, "AC4: the enemy tactical snapshot must survive a JSON round-trip.")
	var parse_result: ActionResult = TacticalSnapshot.parse(json_dict)
	assert_true(parse_result.succeeded, "AC4: the enemy tactical snapshot must re-parse through the strict TacticalSnapshot.parse path. Error: %s" % parse_result.metadata)
	var restored_snapshot: TacticalSnapshot = parse_result.metadata.get("snapshot")
	var restored_board_result: ActionResult = BoardState.try_from_snapshot(restored_snapshot.board)
	assert_true(restored_board_result.succeeded, "AC4: the parsed snapshot's board must restore through the strict validator. Error: %s" % restored_board_result.metadata)
	var restored_board: BoardState = restored_board_result.metadata.get("board")
	assert_equal(restored_board.entity_count(), enemy_total, "AC4: the enemies must survive the strict TacticalSnapshot round-trip.")


func _occupant_invariant_blocking_enemies_re_derive_occupant() -> void:
	# AC4 occupant invariant: cells emit occupant_id "" and BoardState.try_from_snapshot RE-DERIVES
	# occupancy from blocking entities. A blocking enemy's cell must report that enemy as its occupant on
	# the restored board (entity_at / occupant_at), proving the entity list is the source of truth and the
	# board is internally consistent.
	var layout: Dictionary = _medium_layout(2024)
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var board: BoardState = generator.build_board_snapshot(layout).metadata.get("board")
	for enemy_value: Variant in (layout.get("enemies") as Array):
		var enemy: Dictionary = enemy_value
		if not bool(enemy.get("blocks_movement")):
			continue
		var cell: Vector2i = _enemy_cell(enemy)
		assert_equal(String(board.occupant_at(cell)), String(enemy.get("entity_id")), "AC4: a blocking enemy's cell must re-derive its occupant_id from the entity list (cell %s)." % cell)
		var occupant: TacticalEntityState = board.entity_at(cell)
		assert_true(occupant != null, "AC4: entity_at must resolve the blocking enemy at its cell (cell %s)." % cell)
		assert_equal(String(occupant.entity_id), String(enemy.get("entity_id")), "AC4: entity_at must return the placed enemy (cell %s)." % cell)


func _payload_is_pure_serializable_data() -> void:
	# AC4: the generation payload is pure serializable data (no scene nodes; JSON-clean), incl. the
	# `rewards` markers and the enemy-bearing board. The whole payload survives a JSON round-trip and the
	# embedded board re-validates.
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(2024), LevelRecipeRepository.create_baseline_repository(), _enemy_repository())
	assert_true(result_value.succeeded, "AC4: Medium generation should succeed for the payload-serializability probe. Error: %s" % result_value.diagnostics)
	assert_false(result_value.payload.get("board") is Node, "AC4: the payload board must be pure data, not a Node.")
	assert_true(result_value.payload.has("rewards"), "AC4: the payload must carry the `rewards` markers.")

	var json_text: String = JSON.stringify(result_value.payload)
	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary, "AC4: the full payload (board + rewards) must survive a JSON round-trip.")
	var json_payload: Dictionary = parsed
	var restore_result: ActionResult = BoardState.try_from_snapshot(json_payload.get("board"))
	assert_true(restore_result.succeeded, "AC4: the JSON-round-tripped payload board (with enemies) must restore through the strict validator. Error: %s" % restore_result.metadata)
	var restored_board: BoardState = restore_result.metadata.get("board")
	assert_true(restored_board.entity_count() > 0, "AC4: the round-tripped payload board must carry the placed enemies.")


# --- Hand-built candidate helpers (for the AC2 reward-reachability rejection test) -------------
# Build a base "open" Medium terrain grid (border ring = WALL, interior = FLOOR, entrance/exit on the
# central row), mirroring the generator's construction so a candidate is a realistic layout with
# specific cells overridden by the test.
func _open_medium_grid() -> Array:
	var corridor_row: int = MEDIUM_HEIGHT / 2
	var terrain_grid: Array = []
	for y: int in range(MEDIUM_HEIGHT):
		var row: Array = []
		for x: int in range(MEDIUM_WIDTH):
			var terrain: int = BoardCell.Terrain.FLOOR
			if x == 0 or y == 0 or x == MEDIUM_WIDTH - 1 or y == MEDIUM_HEIGHT - 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 1 and y == corridor_row:
				terrain = BoardCell.Terrain.ENTRANCE
			elif x == MEDIUM_WIDTH - 2 and y == corridor_row:
				terrain = BoardCell.Terrain.EXIT
			row.append(terrain)
		terrain_grid.append(row)
	return terrain_grid


func _set_terrain(terrain_grid: Array, x: int, y: int, terrain: int) -> void:
	(terrain_grid[y] as Array)[x] = terrain
