class_name TacticalMovementQuery
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

const DEFAULT_MOVEMENT_BUDGET: int = 3
const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP
]

func validate_target(
	board: BoardState,
	actor_id: StringName,
	target_cell: Vector2i,
	movement_budget: int = DEFAULT_MOVEMENT_BUDGET
) -> ActionResult:
	if board == null:
		return _invalid(&"invalid_board")
	if movement_budget <= 0:
		return _invalid(&"invalid_budget", {"movement_budget": movement_budget})

	var actor: TacticalEntityState = board.get_entity(actor_id)
	if actor == null or actor_id == &"":
		return _invalid(&"invalid_actor", {"actor_id": String(actor_id)})
	if actor.is_dead():
		return _invalid(&"dead_actor", {"actor_id": String(actor_id)})
	if target_cell == actor.position:
		return _invalid(&"same_cell", _cell_metadata(target_cell))
	if not board.in_bounds(target_cell):
		return _invalid(&"out_of_bounds", _cell_metadata(target_cell))

	var target_board_cell: BoardCell = board.get_cell(target_cell)
	if target_board_cell == null:
		return _invalid(&"out_of_bounds", _cell_metadata(target_cell))
	if not target_board_cell.visible:
		return _invalid(&"not_visible", _cell_metadata(target_cell))
	if target_board_cell.terrain_blocks_occupancy():
		return _invalid(&"blocked", _cell_metadata(target_cell))
	if target_board_cell.occupant_id != &"" and target_board_cell.occupant_id != actor_id:
		var occupied_metadata: Dictionary = _cell_metadata(target_cell)
		occupied_metadata["occupant_id"] = String(target_board_cell.occupant_id)
		return _invalid(&"occupied", occupied_metadata)

	var path_result: Dictionary = _shortest_cardinal_path(board, actor.position, target_cell, actor_id)
	if not bool(path_result.get("found", false)):
		return _invalid(&"unreachable", _cell_metadata(target_cell))

	var path: Array[Vector2i] = path_result.get("path", [])
	var movement_cost: int = max(0, path.size() - 1)
	if movement_cost > movement_budget:
		var budget_metadata: Dictionary = _cell_metadata(target_cell)
		budget_metadata["movement_cost"] = movement_cost
		budget_metadata["movement_budget"] = movement_budget
		return _invalid(&"beyond_budget", budget_metadata)

	return ActionResult.ok([], {
		"reason": "valid",
		"movement_cost": movement_cost,
		"movement_budget": movement_budget,
		"path": _serialize_path(path)
	})


func _shortest_cardinal_path(
	board: BoardState,
	start_cell: Vector2i,
	target_cell: Vector2i,
	actor_id: StringName
) -> Dictionary:
	var queue: Array[Vector2i] = [start_cell]
	var visited: Dictionary = {start_cell: true}
	var came_from: Dictionary = {}
	var cursor: int = 0

	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		if current == target_cell:
			return {
				"found": true,
				"path": _reconstruct_path(came_from, start_cell, target_cell)
			}

		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var next_cell: Vector2i = current + direction
			if visited.has(next_cell):
				continue
			if not _is_step_passable(board, next_cell, actor_id):
				continue
			visited[next_cell] = true
			came_from[next_cell] = current
			queue.append(next_cell)

	return {
		"found": false,
		"path": []
	}


func _is_step_passable(board: BoardState, cell: Vector2i, actor_id: StringName) -> bool:
	if not board.in_bounds(cell):
		return false

	var board_cell: BoardCell = board.get_cell(cell)
	if board_cell == null:
		return false
	if board_cell.terrain_blocks_occupancy():
		return false
	if board_cell.occupant_id != &"" and board_cell.occupant_id != actor_id:
		return false
	return true


func _reconstruct_path(came_from: Dictionary, start_cell: Vector2i, target_cell: Vector2i) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = [target_cell]
	var current: Vector2i = target_cell
	while current != start_cell:
		current = came_from.get(current, start_cell)
		reversed_path.append(current)

	var path: Array[Vector2i] = []
	for index: int in range(reversed_path.size() - 1, -1, -1):
		path.append(reversed_path[index])
	return path


func _serialize_path(path: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Vector2i in path:
		result.append(_cell_metadata(cell))
	return result


func _cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_movement", result_metadata)
