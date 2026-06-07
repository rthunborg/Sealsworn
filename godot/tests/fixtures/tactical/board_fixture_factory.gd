class_name BoardFixtureFactory
extends RefCounted

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")

static func one_by_one() -> BoardState:
	var board: BoardState = _new_board(1, 1)
	_place_entity(board, _player(&"hero", Vector2i.ZERO))
	return board


static func edge_corner_movement() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	_set_terrain(board, Vector2i(0, 0), BoardCell.Terrain.ENTRANCE)
	_set_terrain(board, Vector2i(2, 2), BoardCell.Terrain.EXIT)
	_place_entity(board, _player(&"hero", Vector2i(0, 0)))
	return board


static func blocked_cell() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	_set_terrain(board, Vector2i(1, 1), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i(0, 0)))
	return board


static func occupied_cell() -> BoardState:
	var board: BoardState = _new_board(2, 2)
	_place_entity(board, _player(&"hero", Vector2i(0, 0)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(1, 1)))
	return board


static func disconnected_cells() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	for y: int in range(3):
		_set_terrain(board, Vector2i(1, y), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i(0, 1)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(2, 1)))
	return board


static func line_of_sight_blockers() -> BoardState:
	var board: BoardState = _new_board(4, 3)
	_set_terrain(board, Vector2i(1, 1), BoardCell.Terrain.WALL)
	_set_terrain(board, Vector2i(2, 1), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i(0, 1)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(3, 1)))
	return board


static func deterministic_actor_placement() -> BoardState:
	var board: BoardState = _new_board(4, 3)
	_set_terrain(board, Vector2i(0, 0), BoardCell.Terrain.ENTRANCE)
	_set_terrain(board, Vector2i(3, 2), BoardCell.Terrain.EXIT)
	_place_entity(board, _player(&"hero", Vector2i(0, 0)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(2, 0)))
	_place_entity(board, _enemy(&"enemy_2", Vector2i(3, 2)))
	return board


static func los_open_radius() -> BoardState:
	var board: BoardState = _new_board(9, 9)
	_place_entity(board, _player(&"hero", Vector2i(4, 4)))
	return board


static func los_blocker_lane() -> BoardState:
	var board: BoardState = _new_board(6, 5)
	_set_terrain(board, Vector2i(3, 2), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i(1, 2)))
	return board


static func los_corner_peeking() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	_set_terrain(board, Vector2i(1, 0), BoardCell.Terrain.WALL)
	_set_terrain(board, Vector2i(0, 1), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i.ZERO))
	return board


static func los_diagonal_line() -> BoardState:
	var board: BoardState = _new_board(5, 5)
	_set_terrain(board, Vector2i(2, 2), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i.ZERO))
	return board


static func los_edge_origin() -> BoardState:
	var board: BoardState = _new_board(5, 5)
	_place_entity(board, _player(&"hero", Vector2i.ZERO))
	return board


static func los_movement_update_memory() -> BoardState:
	var board: BoardState = _new_board(5, 5)
	_place_entity(board, _player(&"hero", Vector2i.ZERO))
	return board


static func expected_los_open_radius_cells() -> Array[Vector2i]:
	return _expected_open_radius_cells(9, 9, Vector2i(4, 4), 4)


static func expected_los_edge_origin_cells() -> Array[Vector2i]:
	return _expected_open_radius_cells(5, 5, Vector2i.ZERO, 4)


static func expected_los_blocker_lane_cells() -> Array[Vector2i]:
	return [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
		Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)
	]


static func expected_los_corner_peeking_cells() -> Array[Vector2i]:
	return [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, 1)
	]


static func expected_los_diagonal_line_cells() -> Array[Vector2i]:
	return [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
		Vector2i(0, 3), Vector2i(1, 3),
		Vector2i(0, 4)
	]


static func _new_board(new_width: int, new_height: int) -> BoardState:
	var board: BoardState = BoardState.new()
	var command: Variant = CreateBoardCommand.new(new_width, new_height)
	var result: ActionResult = command.execute(board)
	if result.is_error():
		push_error("Fixture board creation failed: %s" % String(result.error_code))
	return board


static func _set_terrain(board: BoardState, cell: Vector2i, terrain: int) -> void:
	var result: ActionResult = board.set_cell_terrain_for_setup(cell, terrain)
	if result.is_error():
		push_error("Fixture terrain setup failed: %s" % String(result.error_code))


static func _place_entity(board: BoardState, entity: TacticalEntityState) -> void:
	var result: ActionResult = board.place_entity_for_setup(entity)
	if result.is_error():
		push_error("Fixture entity setup failed: %s" % String(result.error_code))


static func _player(entity_id: StringName, position: Vector2i) -> TacticalEntityState:
	return TacticalEntityState.new(
		entity_id,
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		position,
		18,
		18,
		true
	)


static func _enemy(entity_id: StringName, position: Vector2i) -> TacticalEntityState:
	return TacticalEntityState.new(
		entity_id,
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		position,
		10,
		10,
		true
	)


static func _expected_open_radius_cells(board_width: int, board_height: int, origin: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var radius_squared: int = radius * radius
	for y: int in range(board_height):
		for x: int in range(board_width):
			var cell: Vector2i = Vector2i(x, y)
			if origin.distance_squared_to(cell) <= radius_squared:
				result.append(cell)
	return result
