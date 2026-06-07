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


static func attack_preview_open_lane() -> BoardState:
	var board: BoardState = _new_board(6, 3)
	_place_entity(board, _player(&"hero", Vector2i(0, 1)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(3, 1)))
	_reveal_all(board)
	return board


static func attack_preview_adjacent_enemy() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	_place_entity(board, _player(&"hero", Vector2i(1, 1)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(2, 1)))
	_reveal_all(board)
	return board


static func attack_preview_blocked_lane() -> BoardState:
	var board: BoardState = _new_board(5, 3)
	_set_terrain(board, Vector2i(2, 1), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i(0, 1)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(4, 1)))
	_reveal_all(board)
	return board


static func attack_preview_entity_blocked_lane() -> BoardState:
	var board: BoardState = _new_board(5, 3)
	_place_entity(board, _player(&"hero", Vector2i(0, 1)))
	_place_entity(board, _enemy(&"blocker_1", Vector2i(2, 1)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(4, 1)))
	_reveal_all(board)
	return board


static func attack_preview_diagonal_enemy() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	_place_entity(board, _player(&"hero", Vector2i.ZERO))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(1, 1)))
	_reveal_all(board)
	return board


static func attack_preview_hidden_enemy() -> BoardState:
	var board: BoardState = _new_board(4, 3)
	_place_entity(board, _player(&"hero", Vector2i(0, 1)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(2, 1)))
	var hero_cell: BoardCell = board.get_cell(Vector2i(0, 1))
	hero_cell.visible = true
	hero_cell.explored = true
	return board


static func attack_preview_memory_enemy() -> BoardState:
	var board: BoardState = attack_preview_hidden_enemy()
	var target_cell: BoardCell = board.get_cell(Vector2i(2, 1))
	target_cell.visible = false
	target_cell.explored = true
	return board


static func attack_preview_friendly_target() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	_place_entity(board, _player(&"hero", Vector2i(1, 1)))
	_place_entity(board, _ally(&"ally_1", Vector2i(2, 1)))
	_reveal_all(board)
	return board


static func attack_preview_dead_target() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	_place_entity(board, _player(&"hero", Vector2i(1, 1)))
	_place_entity(board, _enemy_with_hp(&"enemy_1", Vector2i(2, 1), 0))
	_reveal_all(board)
	return board


static func attack_preview_dead_actor() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	_place_entity(board, _player_with_hp(&"hero", Vector2i(1, 1), 0))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(2, 1)))
	_reveal_all(board)
	return board


static func attack_preview_empty_target() -> BoardState:
	var board: BoardState = _new_board(4, 3)
	_place_entity(board, _player(&"hero", Vector2i(0, 1)))
	_reveal_all(board)
	return board


static func attack_command_kill_board() -> BoardState:
	var board: BoardState = _new_board(3, 3)
	_place_entity(board, _player(&"hero", Vector2i(1, 1)))
	_place_entity(board, _enemy_with_hp(&"enemy_1", Vector2i(2, 1), 3))
	_reveal_all(board)
	return board


static func attack_command_survive_board() -> BoardState:
	return attack_preview_adjacent_enemy()


static func attack_command_knockback_open() -> BoardState:
	var board: BoardState = _new_board(5, 3)
	_place_entity(board, _player(&"hero", Vector2i(0, 1)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(2, 1)))
	_reveal_all(board)
	return board


static func attack_command_knockback_blocked() -> BoardState:
	var board: BoardState = _new_board(4, 3)
	_set_terrain(board, Vector2i(3, 1), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i(0, 1)))
	_place_entity(board, _enemy(&"enemy_1", Vector2i(2, 1)))
	_reveal_all(board)
	return board


static func attack_command_shield_block() -> BoardState:
	return attack_preview_adjacent_enemy()


static func attack_command_shield_no_block() -> BoardState:
	return attack_preview_adjacent_enemy()


static func attack_command_tome_staff() -> BoardState:
	return attack_preview_adjacent_enemy()


static func attack_command_tome_wand() -> BoardState:
	return attack_preview_adjacent_enemy()


static func attack_command_proc() -> BoardState:
	return attack_preview_adjacent_enemy()


static func enemy_turn_adjacent_melee(enemy_definition_id: StringName = &"iron_cultist") -> BoardState:
	var board: BoardState = _new_board(5, 5)
	_place_entity(board, _player(&"hero", Vector2i(2, 2)))
	_place_entity(board, _enemy_from_definition(&"enemy_iron", enemy_definition_id, Vector2i(3, 2), _enemy_hp(enemy_definition_id)))
	_reveal_all(board)
	return board


static func enemy_turn_approach(enemy_definition_id: StringName = &"iron_cultist") -> BoardState:
	var board: BoardState = _new_board(6, 5)
	_place_entity(board, _player(&"hero", Vector2i(1, 2)))
	_place_entity(board, _enemy_from_definition(&"enemy_iron", enemy_definition_id, Vector2i(4, 2), _enemy_hp(enemy_definition_id)))
	_reveal_all(board)
	return board


static func enemy_turn_blocked_approach() -> BoardState:
	var board: BoardState = _new_board(5, 5)
	_place_entity(board, _player(&"hero", Vector2i(2, 2)))
	_place_entity(board, _enemy_from_definition(&"enemy_iron", &"iron_cultist", Vector2i(2, 4), 10))
	_place_entity(board, _enemy_from_definition(&"blocker_left", &"gate_brute", Vector2i(1, 2), 12, 0))
	_place_entity(board, _enemy_from_definition(&"blocker_right", &"gate_brute", Vector2i(3, 2), 12, 0))
	_place_entity(board, _enemy_from_definition(&"blocker_up", &"gate_brute", Vector2i(2, 1), 12, 0))
	_place_entity(board, _enemy_from_definition(&"blocker_down", &"gate_brute", Vector2i(2, 3), 12, 0))
	_reveal_all(board)
	return board


static func enemy_turn_multiple_ordering() -> BoardState:
	var board: BoardState = _new_board(7, 5)
	_place_entity(board, _player(&"hero", Vector2i(3, 2)))
	_place_entity(board, _enemy_from_definition(&"enemy_b", &"iron_cultist", Vector2i(4, 2), 10))
	_place_entity(board, _enemy_from_definition(&"enemy_a", &"iron_cultist", Vector2i(2, 2), 10))
	_reveal_all(board)
	return board


static func enemy_turn_gate_brute_blocking() -> BoardState:
	var board: BoardState = _new_board(5, 5)
	_set_terrain(board, Vector2i(2, 1), BoardCell.Terrain.WALL)
	_set_terrain(board, Vector2i(3, 1), BoardCell.Terrain.WALL)
	_set_terrain(board, Vector2i(4, 1), BoardCell.Terrain.WALL)
	_set_terrain(board, Vector2i(2, 3), BoardCell.Terrain.WALL)
	_set_terrain(board, Vector2i(3, 3), BoardCell.Terrain.WALL)
	_set_terrain(board, Vector2i(4, 3), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i(1, 2)))
	_place_entity(board, _enemy_from_definition(&"enemy_brute", &"gate_brute", Vector2i(4, 2), 12))
	_place_entity(board, _enemy_from_definition(&"enemy_blocker", &"iron_cultist", Vector2i(3, 2), 10, 0))
	_reveal_all(board)
	return board


static func enemy_turn_missing_definition_id() -> BoardState:
	var board: BoardState = _new_board(5, 5)
	_place_entity(board, _player(&"hero", Vector2i(1, 2)))
	_place_entity(board, _enemy_from_definition(&"enemy_unknown", &"", Vector2i(3, 2), 10))
	_reveal_all(board)
	return board


static func enemy_turn_ash_seer_mark() -> BoardState:
	var board: BoardState = _new_board(7, 5)
	_place_entity(board, _player(&"hero", Vector2i(1, 2)))
	_place_entity(board, _enemy_from_definition(&"enemy_seer", &"ash_seer", Vector2i(5, 2), 8))
	_reveal_all(board)
	return board


static func enemy_turn_ash_seer_detonation_hit() -> BoardState:
	return enemy_turn_ash_seer_mark()


static func enemy_turn_ash_seer_detonation_avoided() -> BoardState:
	var board: BoardState = _new_board(7, 5)
	_place_entity(board, _player(&"hero", Vector2i(1, 1)))
	_place_entity(board, _enemy_from_definition(&"enemy_seer", &"ash_seer", Vector2i(5, 2), 8))
	_reveal_all(board)
	return board


static func enemy_turn_ash_seer_no_los_wait() -> BoardState:
	var board: BoardState = _new_board(7, 5)
	_set_terrain(board, Vector2i(3, 2), BoardCell.Terrain.WALL)
	_place_entity(board, _player(&"hero", Vector2i(1, 2)))
	_place_entity(board, _enemy_from_definition(&"enemy_seer", &"ash_seer", Vector2i(5, 2), 8))
	_reveal_all(board)
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


static func _player_with_hp(entity_id: StringName, position: Vector2i, current_hp: int) -> TacticalEntityState:
	return TacticalEntityState.new(
		entity_id,
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		position,
		current_hp,
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


static func _enemy_with_hp(entity_id: StringName, position: Vector2i, current_hp: int) -> TacticalEntityState:
	return TacticalEntityState.new(
		entity_id,
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		position,
		current_hp,
		10,
		true
	)


static func _enemy_from_definition(
	entity_id: StringName,
	definition_id: StringName,
	position: Vector2i,
	max_hp: int,
	current_hp: int = -1
) -> TacticalEntityState:
	var resolved_current_hp: int = current_hp
	if resolved_current_hp < 0:
		resolved_current_hp = max_hp
	var entity: TacticalEntityState = TacticalEntityState.new(
		entity_id,
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		position,
		resolved_current_hp,
		max_hp,
		true
	)
	entity.definition_id = definition_id
	return entity


static func _enemy_hp(definition_id: StringName) -> int:
	match definition_id:
		&"gate_brute":
			return 12
		&"ash_seer":
			return 8
		_:
			return 10


static func _ally(entity_id: StringName, position: Vector2i) -> TacticalEntityState:
	return TacticalEntityState.new(
		entity_id,
		TacticalEntityState.EntityType.PLAYER,
		&"player",
		position,
		18,
		18,
		true
	)


static func _reveal_all(board: BoardState) -> void:
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true


static func _expected_open_radius_cells(board_width: int, board_height: int, origin: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var radius_squared: int = radius * radius
	for y: int in range(board_height):
		for x: int in range(board_width):
			var cell: Vector2i = Vector2i(x, y)
			if origin.distance_squared_to(cell) <= radius_squared:
				result.append(cell)
	return result
