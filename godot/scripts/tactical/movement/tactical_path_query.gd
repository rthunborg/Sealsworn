class_name TacticalPathQuery
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP
]

func shortest_cardinal_path(
	board: BoardState,
	actor_id: StringName,
	target_cell: Vector2i
) -> ActionResult:
	if board == null:
		return _invalid(&"invalid_board")

	var actor: TacticalEntityState = board.get_entity(actor_id)
	if actor == null or actor_id == &"":
		return _invalid(&"invalid_actor", {"actor_id": String(actor_id)})
	if actor.is_dead():
		return _invalid(&"dead_actor", {"actor_id": String(actor_id)})
	if target_cell == actor.position:
		return _invalid(&"same_cell", _cell_metadata(target_cell))
	if not board.in_bounds(target_cell):
		return _invalid(&"out_of_bounds", _cell_metadata(target_cell))

	var occupancy_result: ActionResult = board.can_occupy(target_cell, actor_id)
	if occupancy_result.is_error():
		var reason: StringName = _occupancy_reason(occupancy_result)
		var metadata: Dictionary = _cell_metadata(target_cell)
		for key: Variant in occupancy_result.metadata.keys():
			metadata[key] = occupancy_result.metadata[key]
		return _invalid(reason, metadata)

	var path_result: Dictionary = _shortest_cardinal_path(board, actor.position, target_cell, actor_id)
	if not bool(path_result.get("found", false)):
		return _invalid(&"unreachable", _cell_metadata(target_cell))

	var path: Array[Vector2i] = path_result.get("path", [])
	return ActionResult.ok([], {
		"reason": "valid",
		"movement_cost": max(0, path.size() - 1),
		"path": _serialize_path(path)
	})


func approach_path_to_adjacent_target(
	board: BoardState,
	actor_id: StringName,
	target_entity_id: StringName
) -> ActionResult:
	if board == null:
		return _invalid(&"invalid_board")

	var actor: TacticalEntityState = board.get_entity(actor_id)
	var target: TacticalEntityState = board.get_entity(target_entity_id)
	if actor == null or actor_id == &"":
		return _invalid(&"invalid_actor", {"actor_id": String(actor_id)})
	if actor.is_dead():
		return _invalid(&"dead_actor", {"actor_id": String(actor_id)})
	if target == null or target_entity_id == &"":
		return _invalid(&"missing_target", {"target_entity_id": String(target_entity_id)})

	var candidates: Array[Vector2i] = []
	var blocked_candidates: int = 0
	for direction: Vector2i in CARDINAL_DIRECTIONS:
		var candidate: Vector2i = target.position + direction
		if not board.in_bounds(candidate):
			continue
		var occupancy_result: ActionResult = board.can_occupy(candidate, actor_id)
		if occupancy_result.is_error():
			blocked_candidates += 1
			continue
		candidates.append(candidate)

	if candidates.is_empty():
		return _invalid(&"blocked", {
			"target_entity_id": String(target_entity_id),
			"blocked_candidates": blocked_candidates
		})

	candidates.sort_custom(_sort_cells_by_position)
	var best_path: Array[Vector2i] = []
	var best_target: Vector2i = Vector2i.ZERO
	var best_cost: int = 0
	var found: bool = false
	for candidate: Vector2i in candidates:
		var path_result: Dictionary = _shortest_cardinal_path(board, actor.position, candidate, actor_id)
		if not bool(path_result.get("found", false)):
			continue
		var path: Array[Vector2i] = path_result.get("path", [])
		var cost: int = max(0, path.size() - 1)
		if not found or cost < best_cost or (cost == best_cost and _sort_cells_by_position(candidate, best_target)):
			found = true
			best_path = path
			best_target = candidate
			best_cost = cost

	if not found:
		return _invalid(&"unreachable", {
			"target_entity_id": String(target_entity_id)
		})

	return ActionResult.ok([], {
		"reason": "valid",
		"target_cell": _cell_metadata(best_target),
		"next_step": _cell_metadata(best_path[1]) if best_path.size() > 1 else _cell_metadata(actor.position),
		"movement_cost": best_cost,
		"path": _serialize_path(best_path)
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


func _occupancy_reason(result_value: ActionResult) -> StringName:
	if result_value.error_code == &"cell_out_of_bounds":
		return &"out_of_bounds"
	if result_value.error_code == &"cell_occupied":
		return &"occupied"
	return &"blocked"


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_path", result_metadata)


static func _sort_cells_by_position(first: Vector2i, second: Vector2i) -> bool:
	if first.y == second.y:
		return first.x < second.x
	return first.y < second.y
