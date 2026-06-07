class_name PrototypeEnemyAi
extends RefCounted

const AiDecision = preload("res://scripts/ai/ai_decision.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const EnemyDefinition = preload("res://scripts/content/definitions/enemy_definition.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalLineQuery = preload("res://scripts/tactical/targeting/tactical_line_query.gd")
const TacticalPathQuery = preload("res://scripts/tactical/movement/tactical_path_query.gd")

var _enemy_repository: EnemyRepository = null

func _init(new_enemy_repository: EnemyRepository = null) -> void:
	_enemy_repository = new_enemy_repository


func decide(
	board: BoardState,
	enemy: TacticalEntityState,
	player_id: StringName,
	pending_telegraphs: Array[Dictionary],
	turn_number: int
) -> AiDecision:
	if board == null or enemy == null:
		return _wait(&"", &"", &"invalid_context", ["invalid_context"])
	if enemy.is_dead():
		return _wait(enemy.entity_id, enemy.definition_id, &"dead", ["dead_enemy"])

	var definition: EnemyDefinition = null
	if _enemy_repository != null:
		definition = _enemy_repository.get_enemy(enemy.definition_id)
	if definition == null:
		return _wait(enemy.entity_id, enemy.definition_id, &"invalid_definition", ["missing_enemy_definition"])

	match definition.behavior_id:
		EnemyDefinition.BEHAVIOR_MELEE_PRESSURE:
			return _decide_melee_pressure(board, enemy, player_id, definition)
		EnemyDefinition.BEHAVIOR_SEER_MARK:
			return _decide_seer_mark(board, enemy, player_id, definition, pending_telegraphs, turn_number)
		_:
			return _wait(enemy.entity_id, definition.enemy_id, &"invalid_definition", ["unsupported_behavior"])


func _decide_melee_pressure(
	board: BoardState,
	enemy: TacticalEntityState,
	player_id: StringName,
	definition: EnemyDefinition
) -> AiDecision:
	var player: TacticalEntityState = board.get_entity(player_id)
	if player == null or player.is_dead():
		return _wait(enemy.entity_id, definition.enemy_id, &"missing_target", ["missing_player_target"])

	var distance: int = _manhattan_distance(enemy.position, player.position)
	if distance <= definition.melee_range and _is_cardinally_aligned(enemy.position, player.position):
		return AiDecision.new(
			enemy.entity_id,
			definition.enemy_id,
			&"attack",
			100,
			["adjacent_cardinal", "physical_damage"],
			player.entity_id,
			enemy.position,
			enemy.position,
			player.position,
			&"",
			{
				"damage": definition.melee_damage,
				"damage_type": String(definition.melee_damage_type),
				"action_id": "attack"
			}
		)

	var path_result: ActionResult = TacticalPathQuery.new().approach_path_to_adjacent_target(board, enemy.entity_id, player.entity_id)
	if path_result.is_error():
		var reason: StringName = StringName(str(path_result.metadata.get("reason", "blocked")))
		if reason == &"occupied" or reason == &"unreachable":
			reason = &"blocked"
		return _wait(enemy.entity_id, definition.enemy_id, reason, ["no_legal_approach"])

	var next_step: Vector2i = _cell_from_metadata(path_result.metadata.get("next_step", {}))
	var target_cell: Vector2i = _cell_from_metadata(path_result.metadata.get("target_cell", {}))
	return AiDecision.new(
		enemy.entity_id,
		definition.enemy_id,
		&"move",
		50,
		["shortest_path"],
		player.entity_id,
		enemy.position,
		next_step,
		target_cell,
		&"",
		{
			"movement_cost": 1,
			"path_cost": int(path_result.metadata.get("movement_cost", 0)),
			"action_id": "move"
		}
	)


func _decide_seer_mark(
	board: BoardState,
	enemy: TacticalEntityState,
	player_id: StringName,
	definition: EnemyDefinition,
	pending_telegraphs: Array[Dictionary],
	turn_number: int
) -> AiDecision:
	var player: TacticalEntityState = board.get_entity(player_id)
	if player == null or player.is_dead():
		return _wait(enemy.entity_id, definition.enemy_id, &"missing_target", ["missing_player_target"])

	var due_mark: Dictionary = _due_mark_for_enemy(enemy.entity_id, pending_telegraphs, turn_number)
	if not due_mark.is_empty():
		var marked_cell: Vector2i = _cell_from_metadata(due_mark.get("marked_cell", {}))
		return AiDecision.new(
			enemy.entity_id,
			definition.enemy_id,
			&"detonate",
			120,
			["due_mark"],
			StringName(str(due_mark.get("target_entity_id", String(player.entity_id)))),
			enemy.position,
			enemy.position,
			marked_cell,
			&"",
			due_mark.duplicate(true)
		)

	var distance: int = _manhattan_distance(enemy.position, player.position)
	if distance > definition.mark_range:
		return _wait(enemy.entity_id, definition.enemy_id, &"out_of_range", ["target_out_of_range"])
	if definition.requires_line_of_sight and not TacticalLineQuery.has_line_of_sight(board, enemy.position, player.position):
		return _wait(enemy.entity_id, definition.enemy_id, &"no_line_of_sight", ["line_of_sight_blocked"])

	return AiDecision.new(
		enemy.entity_id,
		definition.enemy_id,
		&"mark",
		80,
		["line_of_sight", "delayed_detonation"],
		player.entity_id,
		enemy.position,
		enemy.position,
		player.position,
		&"",
		{
			"mark_range": definition.mark_range,
			"damage": definition.detonation_damage,
			"damage_type": String(definition.detonation_damage_type),
			"action_id": "mark"
		}
	)


func _due_mark_for_enemy(
	enemy_id: StringName,
	pending_telegraphs: Array[Dictionary],
	turn_number: int
) -> Dictionary:
	for telegraph: Dictionary in pending_telegraphs:
		if String(telegraph.get("kind", "")) != "ash_seer_mark":
			continue
		if String(telegraph.get("source_entity_id", "")) != String(enemy_id):
			continue
		if String(telegraph.get("status", "pending")) != "pending":
			continue
		if int(telegraph.get("due_turn_number", 0)) > turn_number:
			continue
		return telegraph.duplicate(true)
	return {}


func _wait(
	enemy_id: StringName,
	definition_id: StringName,
	wait_reason: StringName,
	reasons: Array[String]
) -> AiDecision:
	return AiDecision.new(
		enemy_id,
		definition_id,
		&"wait",
		0,
		reasons,
		&"",
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		wait_reason,
		{
			"wait_reason": String(wait_reason),
			"action_id": "wait"
		}
	)


func _manhattan_distance(first: Vector2i, second: Vector2i) -> int:
	return abs(first.x - second.x) + abs(first.y - second.y)


func _is_cardinally_aligned(first: Vector2i, second: Vector2i) -> bool:
	return first.x == second.x or first.y == second.y


func _cell_from_metadata(value: Variant) -> Vector2i:
	if not value is Dictionary:
		return Vector2i(-1, -1)
	var cell_data: Dictionary = value
	return Vector2i(int(cell_data.get("x", -1)), int(cell_data.get("y", -1)))
