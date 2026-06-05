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
