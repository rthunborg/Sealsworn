extends "res://tests/unit/test_case.gd"

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

func run() -> Dictionary:
	_fixture_boards_are_valid_and_scene_independent()
	_fixtures_cover_required_board_shapes()
	_fixtures_are_deterministic()
	return result()


func _fixture_boards_are_valid_and_scene_independent() -> void:
	var fixtures: Array[BoardState] = [
		BoardFixtureFactory.one_by_one(),
		BoardFixtureFactory.edge_corner_movement(),
		BoardFixtureFactory.blocked_cell(),
		BoardFixtureFactory.occupied_cell(),
		BoardFixtureFactory.disconnected_cells(),
		BoardFixtureFactory.line_of_sight_blockers(),
		BoardFixtureFactory.deterministic_actor_placement(),
		BoardFixtureFactory.los_open_radius(),
		BoardFixtureFactory.los_blocker_lane(),
		BoardFixtureFactory.los_corner_peeking(),
		BoardFixtureFactory.los_diagonal_line(),
		BoardFixtureFactory.los_edge_origin(),
		BoardFixtureFactory.los_movement_update_memory()
	]

	for board: BoardState in fixtures:
		var board_variant: Variant = board
		var restore_result: ActionResult = BoardState.try_from_snapshot(board.to_snapshot())

		assert_false(board_variant is Node, "Board fixtures should be scene-independent domain state.")
		assert_true(board.has_cells(), "Fixture boards should contain cells.")
		assert_true(restore_result.succeeded, "Fixture board snapshots should restore cleanly.")


func _fixtures_cover_required_board_shapes() -> void:
	var one_by_one: BoardState = BoardFixtureFactory.one_by_one()
	assert_equal(one_by_one.width, 1, "1x1 fixture should have width 1.")
	assert_equal(one_by_one.height, 1, "1x1 fixture should have height 1.")
	assert_equal(one_by_one.occupant_at(Vector2i.ZERO), &"hero", "1x1 fixture should include deterministic actor placement.")

	var edge_corner: BoardState = BoardFixtureFactory.edge_corner_movement()
	assert_equal(edge_corner.get_cell(Vector2i(0, 0)).terrain, BoardCell.Terrain.ENTRANCE, "Edge/corner fixture should mark a corner entrance.")
	assert_equal(edge_corner.get_cell(Vector2i(2, 2)).terrain, BoardCell.Terrain.EXIT, "Edge/corner fixture should mark the opposite corner exit.")
	assert_false(edge_corner.in_bounds(Vector2i(3, 2)), "Edge/corner fixture should expose board boundaries.")

	var blocked: BoardState = BoardFixtureFactory.blocked_cell()
	assert_true(blocked.can_occupy(Vector2i(1, 1)).is_error(), "Blocked-cell fixture should reject occupancy on the wall.")
	assert_equal(blocked.can_occupy(Vector2i(1, 1)).error_code, &"terrain_blocks_occupancy", "Blocked-cell fixture should use terrain blocking.")

	var occupied: BoardState = BoardFixtureFactory.occupied_cell()
	assert_equal(occupied.occupant_at(Vector2i(1, 1)), &"enemy_1", "Occupied-cell fixture should include an occupied enemy cell.")

	var disconnected: BoardState = BoardFixtureFactory.disconnected_cells()
	assert_true(disconnected.get_cell(Vector2i(1, 0)).terrain_blocks_occupancy(), "Disconnected fixture should include blocker column top.")
	assert_true(disconnected.get_cell(Vector2i(1, 1)).terrain_blocks_occupancy(), "Disconnected fixture should include blocker column middle.")
	assert_true(disconnected.get_cell(Vector2i(1, 2)).terrain_blocks_occupancy(), "Disconnected fixture should include blocker column bottom.")

	var line_of_sight: BoardState = BoardFixtureFactory.line_of_sight_blockers()
	assert_true(line_of_sight.get_cell(Vector2i(1, 1)).blocks_line_of_sight(), "Line-of-sight fixture should include a LoS blocker.")
	assert_true(line_of_sight.get_cell(Vector2i(2, 1)).blocks_line_of_sight(), "Line-of-sight fixture should include multiple LoS blockers.")

	var deterministic_actors: BoardState = BoardFixtureFactory.deterministic_actor_placement()
	assert_equal(deterministic_actors.occupant_at(Vector2i(0, 0)), &"hero", "Actor fixture should place the hero deterministically.")
	assert_equal(deterministic_actors.occupant_at(Vector2i(2, 0)), &"enemy_1", "Actor fixture should place enemy_1 deterministically.")
	assert_equal(deterministic_actors.occupant_at(Vector2i(3, 2)), &"enemy_2", "Actor fixture should place enemy_2 deterministically.")

	var open_radius: BoardState = BoardFixtureFactory.los_open_radius()
	assert_equal(open_radius.width, 9, "Open-radius LoS fixture should have enough width for radius 4.")
	assert_equal(open_radius.height, 9, "Open-radius LoS fixture should have enough height for radius 4.")
	assert_equal(open_radius.occupant_at(Vector2i(4, 4)), &"hero", "Open-radius LoS fixture should place the hero at the center.")
	assert_true(BoardFixtureFactory.expected_los_open_radius_cells().has(Vector2i(4, 4)), "Open-radius expected cells should include the origin.")
	assert_equal(BoardFixtureFactory.expected_los_open_radius_cells().size(), 49, "Open-radius fixture should lock the squared-radius cell count.")

	var blocker_lane: BoardState = BoardFixtureFactory.los_blocker_lane()
	assert_equal(blocker_lane.occupant_at(Vector2i(1, 2)), &"hero", "Blocker-lane LoS fixture should place the hero in the lane.")
	assert_true(blocker_lane.get_cell(Vector2i(3, 2)).blocks_line_of_sight(), "Blocker-lane LoS fixture should include a visible blocker.")

	var corner_peeking: BoardState = BoardFixtureFactory.los_corner_peeking()
	assert_true(corner_peeking.get_cell(Vector2i(1, 0)).blocks_line_of_sight(), "Corner-peeking LoS fixture should block one side of the corner.")
	assert_true(corner_peeking.get_cell(Vector2i(0, 1)).blocks_line_of_sight(), "Corner-peeking LoS fixture should block the other side of the corner.")

	var diagonal_line: BoardState = BoardFixtureFactory.los_diagonal_line()
	assert_true(diagonal_line.get_cell(Vector2i(2, 2)).blocks_line_of_sight(), "Diagonal LoS fixture should include a blocker on the diagonal line.")

	var edge_origin: BoardState = BoardFixtureFactory.los_edge_origin()
	assert_equal(edge_origin.occupant_at(Vector2i.ZERO), &"hero", "Edge-origin LoS fixture should place the hero at the origin.")
	assert_equal(BoardFixtureFactory.expected_los_edge_origin_cells().size(), 17, "Edge-origin expected cells should lock clipped radius count.")

	var memory_update: BoardState = BoardFixtureFactory.los_movement_update_memory()
	assert_equal(memory_update.occupant_at(Vector2i.ZERO), &"hero", "Movement-memory LoS fixture should start the hero at the origin.")
	assert_true(memory_update.in_bounds(Vector2i(4, 4)), "Movement-memory LoS fixture should include a never-seen corner candidate.")


func _fixtures_are_deterministic() -> void:
	assert_equal(
		BoardFixtureFactory.one_by_one().to_snapshot(),
		BoardFixtureFactory.one_by_one().to_snapshot(),
		"1x1 fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.edge_corner_movement().to_snapshot(),
		BoardFixtureFactory.edge_corner_movement().to_snapshot(),
		"Edge/corner fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.blocked_cell().to_snapshot(),
		BoardFixtureFactory.blocked_cell().to_snapshot(),
		"Blocked-cell fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.occupied_cell().to_snapshot(),
		BoardFixtureFactory.occupied_cell().to_snapshot(),
		"Occupied-cell fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.disconnected_cells().to_snapshot(),
		BoardFixtureFactory.disconnected_cells().to_snapshot(),
		"Disconnected fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.line_of_sight_blockers().to_snapshot(),
		BoardFixtureFactory.line_of_sight_blockers().to_snapshot(),
		"Line-of-sight fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.deterministic_actor_placement().to_snapshot(),
		BoardFixtureFactory.deterministic_actor_placement().to_snapshot(),
		"Actor placement fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.los_open_radius().to_snapshot(),
		BoardFixtureFactory.los_open_radius().to_snapshot(),
		"Open-radius LoS fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.los_blocker_lane().to_snapshot(),
		BoardFixtureFactory.los_blocker_lane().to_snapshot(),
		"Blocker-lane LoS fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.los_corner_peeking().to_snapshot(),
		BoardFixtureFactory.los_corner_peeking().to_snapshot(),
		"Corner-peeking LoS fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.los_diagonal_line().to_snapshot(),
		BoardFixtureFactory.los_diagonal_line().to_snapshot(),
		"Diagonal LoS fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.los_edge_origin().to_snapshot(),
		BoardFixtureFactory.los_edge_origin().to_snapshot(),
		"Edge-origin LoS fixture should serialize deterministically."
	)
	assert_equal(
		BoardFixtureFactory.los_movement_update_memory().to_snapshot(),
		BoardFixtureFactory.los_movement_update_memory().to_snapshot(),
		"Movement-memory LoS fixture should serialize deterministically."
	)
