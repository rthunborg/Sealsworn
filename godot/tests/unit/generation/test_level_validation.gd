extends "res://tests/unit/test_case.gd"

# Story 3.6 — Comprehensive Level Validation (AC1 + AC3).
#
# Covers the comprehensive LevelValidator that runs every FR36 / Story-3.6 fairness check over a BUILT
# candidate (layout dict + validated BoardState + reward markers) and emits a structured pass/fail report:
#   AC1 — a CLEAN generated candidate (approved Small + Medium seeds) PASSES the full validator; a hand-
#         built candidate failing EACH named check fails with that check's STABLE lower-snake code and
#         COMPACT diagnostics (counts/coordinates — never a full grid dump). The validator is a PURE query
#         (draws no RNG, mutates nothing) and is SIZE-AGNOSTIC (the same checks run for Small + Medium).
#   AC3 — known-bad fixtures fail for the EXPECTED reason; known-good fixtures pass. Each bad fixture is
#         built to isolate its target check (e.g. for unsafe_first_reveal the exit stays reachable so it
#         is not accidentally tripping unreachable_exit), mirroring the Medium AC2 isolation discipline.
#
# The entity-aware checks (no-soft-lock, enemy-placement reachability, mandatory-reward reachability) are
# driven by hand-built candidates that ring/pinch a target with blocking entities, verified against an
# INDEPENDENT entity-aware flood (NOT the validator's own helper) so the test verifies BEHAVIOUR rather
# than re-asserting the implementation against itself (the 3.5 test_enemy_reward_placement.gd pattern).
#
# Headless / scene-free. Builds boards + candidates in-memory only (no user:// writes).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")
const LevelValidator = preload("res://scripts/generation/level/level_validator.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")

const SMALL_WIDTH: int = 8
const SMALL_HEIGHT: int = 8
const MEDIUM_WIDTH: int = 14
const MEDIUM_HEIGHT: int = 12

# INDEPENDENT 4-neighbour offsets for the reachability floods used by the AC1/AC3 assertions.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

func run() -> Dictionary:
	# AC1/AC3 — clean candidates pass (both sizes, several seeds)
	_clean_small_candidate_passes_full_validator()
	_clean_medium_candidate_passes_full_validator()
	_validator_is_size_agnostic_passes_both()
	# AC1 — pure-query: the validator advances no RNG stream
	_validator_draws_no_rng()
	# AC1/AC3 — each named check fails for a hand-built candidate with the expected code
	_unreachable_exit_fails_with_code()
	_soft_lock_detected_fails_when_exit_ringed_by_entities()
	_required_gate_present_fails_for_synthetic_gate_on_path()
	_no_gate_passes_by_construction_for_v0_candidate()
	_required_gate_off_path_passes()
	_illegal_enemy_placement_fails_on_entrance()
	_illegal_enemy_placement_fails_on_exit()
	_illegal_enemy_placement_fails_when_enemy_sealed()
	_unreachable_mandatory_reward_fails_when_ringed_by_entities()
	_optional_reward_terrain_sealed_fails()
	_optional_reward_guarded_by_entity_still_passes()
	_excessive_blockage_fails_with_code()
	_unreadable_first_reveal_fails_with_code()
	_unsafe_first_reveal_fails_on_hazard_entrance()
	_adjacent_enemy_passes_first_reveal()
	_adjacent_hazard_passes_first_reveal()
	# AC1 — first-failure short-circuit + compact pass report
	_first_failure_short_circuits_in_fixed_order()
	_pass_report_is_compact_no_grid_dump()
	# AC1 — structural guards
	_missing_board_is_rejected_structurally()
	_malformed_shape_is_rejected_structurally()
	return result()


# ---- shared helpers --------------------------------------------------------------------------

func _enemy_repository() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


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


# Build a CLEAN generated Small candidate (layout + validated BoardState + rewards) for the given seed.
func _small_candidate(root_seed: int) -> Dictionary:
	var request: GenerationRequest = _small_request(root_seed)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()
	var layout: Dictionary = generator.generate_layout(request, _small_recipe(), streams, _enemy_repository()).metadata.get("layout")
	var board: BoardState = generator.build_board_snapshot(layout).metadata.get("board")
	return {"layout": layout, "board": board, "rewards": layout.get("rewards", [])}


# Build a CLEAN generated Medium candidate for the given seed.
func _medium_candidate(root_seed: int) -> Dictionary:
	var request: GenerationRequest = _medium_request(root_seed)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var layout: Dictionary = generator.generate_layout(request, _medium_recipe(), streams, _enemy_repository()).metadata.get("layout")
	var board: BoardState = generator.build_board_snapshot(layout).metadata.get("board")
	return {"layout": layout, "board": board, "rewards": layout.get("rewards", [])}


# Build a base "open" Medium terrain grid (border ring = WALL, interior = FLOOR, entrance/exit on the
# central row). Mirrors the generator's construction so a hand-built candidate is a realistic layout.
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


func _terrain_at(terrain_grid: Array, x: int, y: int) -> int:
	return int((terrain_grid[y] as Array)[x])


# Build a layout dict (no entities) from a terrain grid.
func _layout_from_grid(terrain_grid: Array, rewards: Array = [], gates: Array = []) -> Dictionary:
	return {
		"width": MEDIUM_WIDTH,
		"height": MEDIUM_HEIGHT,
		"entrance": {"x": 1, "y": MEDIUM_HEIGHT / 2},
		"exit": {"x": MEDIUM_WIDTH - 2, "y": MEDIUM_HEIGHT / 2},
		"terrain": terrain_grid,
		"rewards": rewards,
		"gates": gates
	}


# Build a single blocking enemy entity dict at the given cell.
func _enemy_dict(entity_id: String, cell: Vector2i) -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_type": String(TacticalEntityState.ENTITY_TYPE_ENEMY),
		"faction": "labyrinth",
		"position": {"x": cell.x, "y": cell.y},
		"current_hp": 10,
		"max_hp": 10,
		"blocks_movement": true,
		"definition_id": "iron_cultist"
	}


# Build a BoardState from a terrain grid + entity dicts (sets occupant_id on each blocking entity's cell,
# matching the generator's build_board_snapshot occupant invariant). Asserts the board builds (so a test
# that wants an illegal-but-buildable placement knows the board itself is valid).
func _board_from_grid(terrain_grid: Array, entities: Array, allow_build_failure: bool = false) -> BoardState:
	var occupant_by_cell: Dictionary = {}
	for entity_value: Variant in entities:
		var entity: Dictionary = entity_value
		if bool(entity.get("blocks_movement", true)):
			var pos: Dictionary = entity.get("position")
			occupant_by_cell[Vector2i(int(pos.get("x")), int(pos.get("y")))] = String(entity.get("entity_id"))
	var cells: Array[Dictionary] = []
	for y: int in range(MEDIUM_HEIGHT):
		for x: int in range(MEDIUM_WIDTH):
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": _terrain_at(terrain_grid, x, y),
				"occupant_id": occupant_by_cell.get(Vector2i(x, y), ""),
				"explored": false,
				"visible": false
			})
	var snapshot: Dictionary = {
		"width": MEDIUM_WIDTH,
		"height": MEDIUM_HEIGHT,
		"next_sequence_id": 1,
		"cells": cells,
		"entities": entities.duplicate(true)
	}
	var build: ActionResult = BoardState.try_from_snapshot(snapshot)
	if not allow_build_failure:
		assert_true(build.succeeded, "Hand-built board must build through try_from_snapshot for the validator probe. Error: %s" % build.metadata)
	return build.metadata.get("board") as BoardState


# INDEPENDENT entity-aware 4-neighbour flood over non-WALL AND non-blocking-entity cells (the entrance is
# always traversable). Deliberately NOT the validator's helper.
func _flood_entity_aware(terrain_grid: Array, blocking_cells: Dictionary, origin: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	if _terrain_at(terrain_grid, origin.x, origin.y) == BoardCell.Terrain.WALL:
		return visited
	var frontier: Array[Vector2i] = [origin]
	visited[origin] = true
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for offset: Vector2i in NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = current + offset
			if neighbour.x < 0 or neighbour.y < 0 or neighbour.x >= MEDIUM_WIDTH or neighbour.y >= MEDIUM_HEIGHT:
				continue
			if visited.has(neighbour):
				continue
			if _terrain_at(terrain_grid, neighbour.x, neighbour.y) == BoardCell.Terrain.WALL:
				continue
			if blocking_cells.has(neighbour):
				continue
			visited[neighbour] = true
			frontier.append(neighbour)
	return visited


# ---- AC1/AC3: clean candidates pass -----------------------------------------------------------

func _clean_small_candidate_passes_full_validator() -> void:
	var validator: LevelValidator = LevelValidator.new()
	for seed_value: int in [1001, 2002, 3003, 4004, 5005, 12345]:
		var validation: ActionResult = validator.validate(_small_candidate(seed_value))
		assert_true(validation.succeeded, "AC1: a clean generated Small candidate (seed %d) must PASS the full validator. Error: %s" % [seed_value, validation.metadata])


func _clean_medium_candidate_passes_full_validator() -> void:
	var validator: LevelValidator = LevelValidator.new()
	for seed_value: int in [1001, 2002, 3003, 4004, 5005, 12345]:
		var validation: ActionResult = validator.validate(_medium_candidate(seed_value))
		assert_true(validation.succeeded, "AC1: a clean generated Medium candidate (seed %d) must PASS the full validator. Error: %s" % [seed_value, validation.metadata])


func _validator_is_size_agnostic_passes_both() -> void:
	# AC1: the SAME validator instance passes both an 8x8 Small and a 14x12 Medium clean candidate (size-
	# agnostic — Small gets the full pass even though it has no validator of its own).
	var validator: LevelValidator = LevelValidator.new()
	assert_true(validator.validate(_small_candidate(777)).succeeded, "AC1: the validator must pass an 8x8 Small candidate (size-agnostic).")
	assert_true(validator.validate(_medium_candidate(777)).succeeded, "AC1: the validator must pass a 14x12 Medium candidate (size-agnostic).")


func _validator_draws_no_rng() -> void:
	# AC1: the validator is a PURE query — running it must advance NO RNG stream. Generate a candidate with
	# a tracked stream set, snapshot the draw indexes, run the validator, and assert the draw indexes are
	# unchanged.
	var request: GenerationRequest = _medium_request(31337)
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()
	var layout: Dictionary = generator.generate_layout(request, _medium_recipe(), streams, _enemy_repository()).metadata.get("layout")
	var board: BoardState = generator.build_board_snapshot(layout).metadata.get("board")

	var before: Dictionary = streams.to_snapshot().get("streams")
	var validator: LevelValidator = LevelValidator.new()
	validator.validate({"layout": layout, "board": board, "rewards": layout.get("rewards", [])})
	var after: Dictionary = streams.to_snapshot().get("streams")
	for stream_name: StringName in RngStreamSet.required_streams():
		assert_equal(
			int(after.get(String(stream_name)).get("draw_index")),
			int(before.get(String(stream_name)).get("draw_index")),
			"AC1: the validator must not advance the %s stream (pure query)." % String(stream_name)
		)


# ---- AC1/AC3: each named check fails for a hand-built candidate --------------------------------

func _unreachable_exit_fails_with_code() -> void:
	# (a) unreachable_exit: a full interior WALL column partitions entrance from exit. Sparse enough to pass
	# excessive-blockage first, so unreachable_exit is the reported failure.
	var terrain_grid: Array = _open_medium_grid()
	for y: int in range(1, MEDIUM_HEIGHT - 1):
		_set_terrain(terrain_grid, 6, y, BoardCell.Terrain.WALL)
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, [])
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC3: an exit-walled candidate must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_UNREACHABLE_EXIT, "AC3: an exit-walled candidate must use the unreachable_exit code.")
	assert_true(validation.metadata.has("entrance"), "unreachable_exit diagnostics must report the entrance.")
	assert_true(validation.metadata.has("exit"), "unreachable_exit diagnostics must report the exit.")
	assert_false(validation.metadata.has("terrain"), "diagnostics must stay compact (no grid dump).")


func _soft_lock_detected_fails_when_exit_ringed_by_entities() -> void:
	# (b) soft_lock_detected: the exit is TERRAIN-reachable but RINGED by blocking entities, so it is
	# unreachable AROUND them. Wall-free terrain (exit reachable over open terrain), then place blocking
	# enemies on the exit's open neighbours so the entity-aware flood cannot reach the exit cell or stand
	# adjacent to it. Verified with an independent entity-aware flood.
	var terrain_grid: Array = _open_medium_grid()
	var exit_cell: Vector2i = Vector2i(MEDIUM_WIDTH - 2, MEDIUM_HEIGHT / 2)
	# The exit's open 4-neighbours that are interior FLOOR: (11,6) left, (12,5) up, (12,7) down. (13,6) is
	# the border WALL. Ring those three with blocking enemies.
	var ring_cells: Array[Vector2i] = [Vector2i(11, 6), Vector2i(12, 5), Vector2i(12, 7)]
	var entities: Array = []
	var index: int = 0
	for cell: Vector2i in ring_cells:
		entities.append(_enemy_dict("enemy_%d" % index, cell))
		index += 1
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, entities)

	# Independent verification: the exit is terrain-reachable but NOT entity-aware reachable (sealed).
	var blocking: Dictionary = {}
	for cell: Vector2i in ring_cells:
		blocking[cell] = true
	var entity_reach: Dictionary = _flood_entity_aware(terrain_grid, blocking, Vector2i(1, MEDIUM_HEIGHT / 2))
	assert_false(entity_reach.has(exit_cell), "Probe setup: the exit must be sealed off by the entity ring (entity-aware).")
	# It must also be sealed from its neighbours (the ring cells themselves are the only adjacents).
	assert_false(entity_reach.has(Vector2i(11, 6)) or entity_reach.has(Vector2i(12, 5)) or entity_reach.has(Vector2i(12, 7)), "Probe setup: the exit's neighbours must also be blocked (occupied by the ring).")

	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC3: an exit ringed by blocking entities must FAIL the validator (soft-lock).")
	assert_equal(validation.error_code, LevelValidator.CODE_SOFT_LOCK_DETECTED, "AC3: an entity-sealed exit must use the soft_lock_detected code (terrain-reachable but entity-sealed).")


func _required_gate_present_fails_for_synthetic_gate_on_path() -> void:
	# (c) required_gate_present: a synthetic gate marker on the entrance-reachable mandatory path FAILS
	# (forward guardrail). Place a gate on an open corridor cell the entrance reaches.
	var terrain_grid: Array = _open_medium_grid()
	var gates: Array = [{"x": 5, "y": MEDIUM_HEIGHT / 2, "kind": "locked_door"}]
	var layout: Dictionary = _layout_from_grid(terrain_grid, [], gates)
	var board: BoardState = _board_from_grid(terrain_grid, [])
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC3: a synthetic gate on the mandatory path must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_REQUIRED_GATE_PRESENT, "AC3: a gate on the mandatory path must use the required_gate_present code.")
	assert_true(validation.metadata.has("gate"), "required_gate_present diagnostics must report the gate coordinate.")


func _no_gate_passes_by_construction_for_v0_candidate() -> void:
	# (c) the no-gate check PASSES by construction for a v0 candidate (no gates emitted). A clean Medium
	# candidate has no `gates` key, so the check is a no-op pass.
	var validator: LevelValidator = LevelValidator.new()
	var candidate: Dictionary = _medium_candidate(2024)
	assert_false(candidate.get("layout").has("gates"), "v0 generated candidates must NOT carry a gates marker (no gates realized).")
	assert_true(validator.validate(candidate).succeeded, "(c): a v0 candidate with no gates must pass the no-required-gate check by construction.")


func _required_gate_off_path_passes() -> void:
	# (c): a gate that is NOT on the entrance-reachable region does not block the mandatory path -> the
	# gate check passes (the unreachable cell cannot gate progress). Place a gate inside a sealed pocket.
	var terrain_grid: Array = _open_medium_grid()
	# Seal a 1-cell pocket at (12,10): wall (11,10) and (12,9); border ring covers right + bottom.
	_set_terrain(terrain_grid, 11, 10, BoardCell.Terrain.WALL)
	_set_terrain(terrain_grid, 12, 9, BoardCell.Terrain.WALL)
	var gates: Array = [{"x": 12, "y": 10, "kind": "locked_door"}]
	var layout: Dictionary = _layout_from_grid(terrain_grid, [], gates)
	var board: BoardState = _board_from_grid(terrain_grid, [])
	# The gate cell is unreachable, so the gate check passes; the candidate is otherwise clean (exit
	# reachable, no rewards). It should PASS the full validator.
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.succeeded, "(c): a gate off the mandatory path must not fail the no-required-gate check. Error: %s" % validation.metadata)


func _illegal_enemy_placement_fails_on_entrance() -> void:
	# (d) illegal_enemy_placement: an enemy ON the entrance cell is illegal. try_from_snapshot allows it
	# (entrance is FLOOR-class terrain, occupiable), so the validator's re-assertion is what catches it.
	var terrain_grid: Array = _open_medium_grid()
	var entrance: Vector2i = Vector2i(1, MEDIUM_HEIGHT / 2)
	var entities: Array = [_enemy_dict("enemy_0", entrance)]
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, entities)
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC3: an enemy on the entrance must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_ILLEGAL_ENEMY_PLACEMENT, "AC3: an enemy on the entrance must use the illegal_enemy_placement code.")
	assert_true(validation.metadata.has("entity_id"), "illegal_enemy_placement diagnostics must report the entity id.")
	assert_true(validation.metadata.has("cell"), "illegal_enemy_placement diagnostics must report the offending cell.")


func _illegal_enemy_placement_fails_on_exit() -> void:
	# (d): an enemy ON the exit cell is illegal.
	var terrain_grid: Array = _open_medium_grid()
	var exit_cell: Vector2i = Vector2i(MEDIUM_WIDTH - 2, MEDIUM_HEIGHT / 2)
	var entities: Array = [_enemy_dict("enemy_0", exit_cell)]
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, entities)
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC3: an enemy on the exit must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_ILLEGAL_ENEMY_PLACEMENT, "AC3: an enemy on the exit must use the illegal_enemy_placement code.")


func _illegal_enemy_placement_fails_when_enemy_sealed() -> void:
	# (d): an enemy sealed in a WALL pocket the player can never reach (nor stand adjacent to) is an
	# illegal/unfair placement. Seal a 1-cell pocket at (12,10) and put the enemy there.
	var terrain_grid: Array = _open_medium_grid()
	_set_terrain(terrain_grid, 11, 10, BoardCell.Terrain.WALL)
	_set_terrain(terrain_grid, 12, 9, BoardCell.Terrain.WALL)
	var sealed: Vector2i = Vector2i(12, 10)
	var entities: Array = [_enemy_dict("enemy_0", sealed)]
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, entities)
	# Independent verification: neither the sealed cell nor any open neighbour is entrance-reachable.
	var entity_reach: Dictionary = _flood_entity_aware(terrain_grid, {sealed: true}, Vector2i(1, MEDIUM_HEIGHT / 2))
	assert_false(entity_reach.has(sealed), "Probe setup: the sealed enemy cell must be unreachable.")
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC3: a sealed (unreachable) enemy must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_ILLEGAL_ENEMY_PLACEMENT, "AC3: a sealed enemy must use the illegal_enemy_placement code.")


func _unreachable_mandatory_reward_fails_when_ringed_by_entities() -> void:
	# (e) unreachable_reward: a MANDATORY reward that is TERRAIN-reachable but RINGED by blocking entities
	# fails (entity-aware). This is the 3.5 terrain-only Low being closed: the placer's terrain-only check
	# would PASS this, but the comprehensive validator must FAIL it. Ring an interior reward cell with
	# blocking enemies on all four open neighbours.
	var terrain_grid: Array = _open_medium_grid()
	var reward_cell: Vector2i = Vector2i(7, 3)
	var ring: Array[Vector2i] = [Vector2i(6, 3), Vector2i(8, 3), Vector2i(7, 2), Vector2i(7, 4)]
	var entities: Array = []
	var index: int = 0
	for cell: Vector2i in ring:
		entities.append(_enemy_dict("enemy_%d" % index, cell))
		index += 1
	var rewards: Array = [{"x": reward_cell.x, "y": reward_cell.y, "optional": false}]
	var layout: Dictionary = _layout_from_grid(terrain_grid, rewards)
	var board: BoardState = _board_from_grid(terrain_grid, entities)

	# Independent verification: the reward cell is TERRAIN-reachable (open grid) but NOT entity-aware
	# reachable (ringed). This is exactly the gap the entity-aware check closes.
	var blocking: Dictionary = {}
	for cell: Vector2i in ring:
		blocking[cell] = true
	var terrain_reach: Dictionary = _flood_entity_aware(terrain_grid, {}, Vector2i(1, MEDIUM_HEIGHT / 2))
	assert_true(terrain_reach.has(reward_cell), "Probe setup: the reward must be TERRAIN-reachable (so the terrain-only check would pass).")
	var entity_reach: Dictionary = _flood_entity_aware(terrain_grid, blocking, Vector2i(1, MEDIUM_HEIGHT / 2))
	assert_false(entity_reach.has(reward_cell), "Probe setup: the reward must be ENTITY-AWARE unreachable (ringed by blocking enemies).")

	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": rewards})
	assert_true(validation.is_error(), "AC3 (closes 3.5 Low): a mandatory reward ringed by blocking entities must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_UNREACHABLE_REWARD, "AC3: an entity-sealed mandatory reward must use the unreachable_reward code.")
	assert_false(bool(validation.metadata.get("optional")), "the failing reward must be reported as mandatory (optional == false).")


func _optional_reward_terrain_sealed_fails() -> void:
	# (e): an OPTIONAL reward that is TERRAIN-sealed (walled into a pocket) still fails — optional means
	# "guarded/skippable", NOT "stranded behind a wall". Seal a pocket and put an optional reward there.
	var terrain_grid: Array = _open_medium_grid()
	_set_terrain(terrain_grid, 11, 10, BoardCell.Terrain.WALL)
	_set_terrain(terrain_grid, 12, 9, BoardCell.Terrain.WALL)
	var rewards: Array = [{"x": 12, "y": 10, "optional": true}]
	var layout: Dictionary = _layout_from_grid(terrain_grid, rewards)
	var board: BoardState = _board_from_grid(terrain_grid, [])
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": rewards})
	assert_true(validation.is_error(), "AC3: an optional reward sealed behind a wall must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_UNREACHABLE_REWARD, "AC3: a terrain-sealed optional reward must use the unreachable_reward code.")
	assert_true(bool(validation.metadata.get("optional")), "the failing optional reward must be reported as optional.")


func _optional_reward_guarded_by_entity_still_passes() -> void:
	# (e): an OPTIONAL reward that is TERRAIN-reachable but guarded by a blocking entity (not entity-aware
	# reachable) PASSES — the player may choose to skip it. This is the key distinction from a mandatory
	# reward. Ring an optional reward with entities but keep it terrain-reachable.
	var terrain_grid: Array = _open_medium_grid()
	var reward_cell: Vector2i = Vector2i(7, 3)
	var ring: Array[Vector2i] = [Vector2i(6, 3), Vector2i(8, 3), Vector2i(7, 2), Vector2i(7, 4)]
	var entities: Array = []
	var index: int = 0
	for cell: Vector2i in ring:
		entities.append(_enemy_dict("enemy_%d" % index, cell))
		index += 1
	var rewards: Array = [{"x": reward_cell.x, "y": reward_cell.y, "optional": true}]
	var layout: Dictionary = _layout_from_grid(terrain_grid, rewards)
	var board: BoardState = _board_from_grid(terrain_grid, entities)
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": rewards})
	# The exit is still entity-aware reachable (the ring is far from the corridor) and the optional reward
	# is terrain-reachable, so the candidate passes.
	assert_true(validation.succeeded, "AC3: an optional reward guarded by a blocking entity (but terrain-reachable) must PASS (skippable). Error: %s" % validation.metadata)


func _excessive_blockage_fails_with_code() -> void:
	# (f) excessive_blockage: a near-fully-walled interior trips the reused readability bound (0.35).
	var terrain_grid: Array = _open_medium_grid()
	for y: int in range(1, MEDIUM_HEIGHT - 1):
		if y == MEDIUM_HEIGHT / 2:
			continue
		for x: int in range(1, MEDIUM_WIDTH - 1):
			_set_terrain(terrain_grid, x, y, BoardCell.Terrain.WALL)
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, [])
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC3: an over-walled candidate must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_EXCESSIVE_BLOCKAGE, "AC3: an over-walled candidate must use the excessive_blockage code (reused readability bound).")
	assert_true(validation.metadata.has("wall_ratio"), "excessive_blockage diagnostics must report the offending ratio.")


func _unreadable_first_reveal_fails_with_code() -> void:
	# (g) unreadable_first_reveal: the entrance opens into a 1-wide tunnel (rows 5 and 7 walled near the
	# entrance) so too few cells are visible within the LoS radius. Exit stays reachable via the corridor.
	var terrain_grid: Array = _open_medium_grid()
	for x: int in range(1, 6):
		_set_terrain(terrain_grid, x, 5, BoardCell.Terrain.WALL)
		_set_terrain(terrain_grid, x, 7, BoardCell.Terrain.WALL)
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, [])
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC3: a boxed-in-first-reveal candidate must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_UNREADABLE_FIRST_REVEAL, "AC3: a boxed-in-first-reveal candidate must use the unreadable_first_reveal code.")


func _unsafe_first_reveal_fails_on_hazard_entrance() -> void:
	# (h) unsafe_first_reveal: the entrance cell carries HAZARD terrain (player spawned on a hazard). The
	# exit stays reachable and the interior is open, so the safe-first-reveal check is what trips.
	var terrain_grid: Array = _open_medium_grid()
	_set_terrain(terrain_grid, 1, MEDIUM_HEIGHT / 2, BoardCell.Terrain.HAZARD)
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, [])
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC3: an entrance on a hazard must FAIL the validator.")
	assert_equal(validation.error_code, LevelValidator.CODE_UNSAFE_FIRST_REVEAL, "AC3: an entrance on a hazard must use the unsafe_first_reveal code.")
	assert_equal(String(validation.metadata.get("reason")), "entrance_on_hazard", "the unsafe-first-reveal reason must identify the hazard entrance.")


func _adjacent_enemy_passes_first_reveal() -> void:
	# (h) SAFE-FIRST-REVEAL v0 SEMANTIC (documented decision): an enemy merely ADJACENT to the entrance is
	# PERMITTED (the baseline LoS radius 4 reveals it on spawn, so it is SEEN and fair — FR58 protects
	# against UNSEEN damage). The baseline generator legitimately places enemies adjacent to the entrance,
	# so this MUST pass (else attempt 0 would be re-rolled and the fingerprints would drift). Place a
	# blocking enemy orthogonally adjacent to the entrance and assert the candidate PASSES.
	var terrain_grid: Array = _open_medium_grid()
	var adjacent: Vector2i = Vector2i(1, MEDIUM_HEIGHT / 2 - 1)
	var entities: Array = [_enemy_dict("enemy_0", adjacent)]
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, entities)
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.succeeded, "(h): an enemy ADJACENT to the entrance must PASS (v0 semantic: visible within LoS radius 4 = fair). Error: %s" % validation.metadata)


func _adjacent_hazard_passes_first_reveal() -> void:
	# (h): a HAZARD cell merely ADJACENT to the entrance is likewise PERMITTED (visible on first reveal;
	# the baseline Medium generator can place a HAZARD wrinkle adjacent to the entrance). Only a HAZARD ON
	# the entrance is unsafe. Place a HAZARD adjacent to the entrance and assert the candidate PASSES.
	var terrain_grid: Array = _open_medium_grid()
	_set_terrain(terrain_grid, 1, MEDIUM_HEIGHT / 2 - 1, BoardCell.Terrain.HAZARD)
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, [])
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.succeeded, "(h): a HAZARD ADJACENT to the entrance (not ON it) must PASS (v0 semantic). Error: %s" % validation.metadata)


# ---- AC1: first-failure short-circuit + compact pass report ------------------------------------

func _first_failure_short_circuits_in_fixed_order() -> void:
	# AC1: when MULTIPLE checks would fail, the validator reports the FIRST in the fixed order. Build a
	# candidate that is BOTH exit-walled (a, first) AND over-blocked (f, later): the reported failure must
	# be unreachable_exit, NOT excessive_blockage. We wall a single column to break reachability without
	# over-blocking; then ALSO wall enough to exceed the ratio. unreachable_exit must win.
	var terrain_grid: Array = _open_medium_grid()
	# Over-block the interior (would trip excessive_blockage) but also fully partition with the corridor
	# walled too, so the exit is unreachable. Wall the ENTIRE interior except the entrance's immediate cell.
	for y: int in range(1, MEDIUM_HEIGHT - 1):
		for x: int in range(2, MEDIUM_WIDTH - 1):
			_set_terrain(terrain_grid, x, y, BoardCell.Terrain.WALL)
	# Now (1,*) interior column is open but the exit (12,6) is walled off and unreachable.
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var board: BoardState = _board_from_grid(terrain_grid, [])
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "AC1: the multi-failure candidate must fail.")
	assert_equal(validation.error_code, LevelValidator.CODE_UNREACHABLE_EXIT, "AC1: the FIRST check in the fixed order (unreachable_exit) must short-circuit before excessive_blockage.")
	# Confirm the check order constant declares unreachable_exit before excessive_blockage.
	var order: Array[StringName] = LevelValidator.check_order()
	assert_true(order.find(LevelValidator.CODE_UNREACHABLE_EXIT) < order.find(LevelValidator.CODE_EXCESSIVE_BLOCKAGE), "AC1: the documented check order must run unreachable_exit before excessive_blockage.")


func _pass_report_is_compact_no_grid_dump() -> void:
	# AC1: the PASS report carries compact counts (mirroring validate_readability) and NEVER a grid dump.
	var validation: ActionResult = LevelValidator.new().validate(_medium_candidate(2024))
	assert_true(validation.succeeded, "the clean candidate must pass for the report probe.")
	assert_true(validation.metadata.has("terrain_reachable_cell_count"), "the pass report must carry the terrain-reachable count.")
	assert_true(validation.metadata.has("entity_reachable_cell_count"), "the pass report must carry the entity-aware reachable count.")
	assert_true(validation.metadata.has("interior_wall_count"), "the pass report must carry the interior wall count.")
	assert_true(validation.metadata.has("first_reveal_count"), "the pass report must carry the first-reveal count.")
	assert_true(validation.metadata.has("entity_count"), "the pass report must carry the entity count.")
	assert_true(validation.metadata.has("reward_count"), "the pass report must carry the reward count.")
	assert_false(validation.metadata.has("terrain"), "the pass report must stay compact (no terrain grid dump).")


# ---- AC1: structural guards -------------------------------------------------------------------

func _missing_board_is_rejected_structurally() -> void:
	# A candidate missing its BoardState is rejected structurally, not crashed.
	var terrain_grid: Array = _open_medium_grid()
	var layout: Dictionary = _layout_from_grid(terrain_grid)
	var validation: ActionResult = LevelValidator.new().validate({"layout": layout, "board": null, "rewards": []})
	assert_true(validation.is_error(), "A candidate with no board must be rejected structurally.")
	assert_equal(validation.error_code, LevelValidator.CODE_INVALID_CANDIDATE, "A missing board must use the invalid_candidate code.")


func _malformed_shape_is_rejected_structurally() -> void:
	# A candidate whose declared dimensions disagree with the terrain grid is rejected structurally.
	var board: BoardState = _board_from_grid(_open_medium_grid(), [])
	var malformed_layout: Dictionary = {
		"width": MEDIUM_WIDTH,
		"height": MEDIUM_HEIGHT,
		"entrance": {"x": 1, "y": MEDIUM_HEIGHT / 2},
		"exit": {"x": MEDIUM_WIDTH - 2, "y": MEDIUM_HEIGHT / 2},
		"terrain": []
	}
	var validation: ActionResult = LevelValidator.new().validate({"layout": malformed_layout, "board": board, "rewards": []})
	assert_true(validation.is_error(), "A malformed-shape candidate must be rejected structurally, not crash.")
	assert_equal(validation.error_code, LevelValidator.CODE_INVALID_CANDIDATE, "A malformed-shape candidate must use the invalid_candidate code.")
