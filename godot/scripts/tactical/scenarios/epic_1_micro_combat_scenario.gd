class_name Epic1MicroCombatScenario
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatExplanationLog = preload("res://scripts/tactical/outcomes/combat_explanation_log.gd")
const CombatOutcomeEvaluator = preload("res://scripts/tactical/outcomes/combat_outcome_evaluator.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyDefinition = preload("res://scripts/content/definitions/enemy_definition.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const EnemyTurnResolver = preload("res://scripts/tactical/turns/enemy_turn_resolver.gd")
const LocalTimingRecorder = preload("res://scripts/diagnostics/local_timing_recorder.gd")
const MoveCommand = preload("res://scripts/core/commands/move_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

const HERO_ID := &"hero"
const IRON_ID := &"enemy_iron"
const SEER_ID := &"enemy_seer"
const SCENARIO_SEED: int = 11101

func run_win_path(enable_timing: bool = false) -> ActionResult:
	return _run_scripted_path(&"epic_1_micro_combat_win", [&"sword", &"sword", &"sword", &"staff", &"staff"], enable_timing)


func run_loss_path(enable_timing: bool = false) -> ActionResult:
	return _run_scripted_path(&"epic_1_micro_combat_loss", [&"dagger", &"dagger", &"dagger", &"dagger"], enable_timing)


func _run_scripted_path(
	scenario_id: StringName,
	weapon_plan: Array[StringName],
	enable_timing: bool
) -> ActionResult:
	var enemy_repository: EnemyRepository = EnemyRepository.create_baseline_repository()
	var weapon_repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	if enemy_repository == null or weapon_repository == null:
		return _invalid(&"missing_repository")

	var board_result: ActionResult = _create_board(enemy_repository)
	if board_result.is_error():
		return board_result
	var board: BoardState = board_result.metadata.get("board") as BoardState
	var streams: RngStreamSet = RngStreamSet.new(SCENARIO_SEED)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, HERO_ID)
	var pending_telegraphs: Array[Dictionary] = []
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending_telegraphs)
	var resolver: EnemyTurnResolver = EnemyTurnResolver.new(enemy_repository, HERO_ID)
	var outcome_state: CombatOutcomeState = CombatOutcomeState.new()
	var event_log: Array[DomainEvent] = []
	var weapons_used: Array[String] = []
	var timing: LocalTimingRecorder = LocalTimingRecorder.new(enable_timing)

	timing.begin(&"board_query")
	var enemy_count: int = _enemy_count(board)
	timing.end(&"board_query")

	var initial_visibility: ActionResult = _update_visibility(board, event_log, timing)
	if initial_visibility.is_error():
		return initial_visibility

	var move_result: ActionResult = _execute_player_command(
		context,
		MoveCommand.new(HERO_ID, Vector2i(1, 2)),
		resolver,
		event_log,
		timing
	)
	if move_result.is_error():
		return move_result

	var moved_visibility: ActionResult = _update_visibility(board, event_log, timing)
	if moved_visibility.is_error():
		return moved_visibility

	for weapon_id: StringName in weapon_plan:
		var target_id: StringName = IRON_ID if _is_alive(board, IRON_ID) else SEER_ID
		if not _is_alive(board, HERO_ID) or target_id == &"" or not _is_alive(board, target_id):
			break
		var target: TacticalEntityState = board.get_entity(target_id)
		var weapon: Variant = weapon_repository.get_weapon(weapon_id)
		if weapon == null:
			return _invalid(&"missing_weapon", {"weapon_id": String(weapon_id)})

		var attack_result: ActionResult = _execute_player_command(
			context,
			AttackCommand.new(HERO_ID, target.position, weapon),
			resolver,
			event_log,
			timing
		)
		if attack_result.is_error():
			return attack_result
		if not weapons_used.has(String(weapon_id)):
			weapons_used.append(String(weapon_id))
		if not _is_alive(board, HERO_ID) or _living_enemy_count(board) == 0:
			break

	timing.begin(&"outcome_evaluation")
	var outcome_result: ActionResult = CombatOutcomeEvaluator.new(HERO_ID).evaluate(board, outcome_state, event_log)
	timing.end(&"outcome_evaluation")
	if outcome_result.is_error():
		return outcome_result
	for event: DomainEvent in outcome_result.events:
		event_log.append(event)

	var explanation_entries: Array[Dictionary] = CombatExplanationLog.new().build_entries(event_log)
	return ActionResult.ok(event_log, {
		"scenario_id": String(scenario_id),
		"seed": SCENARIO_SEED,
		"outcome": String(outcome_state.state_id),
		"outcome_state": outcome_state.to_dictionary(),
		"board_snapshot": board.to_snapshot(),
		"pending_telegraphs": pending_telegraphs.duplicate(true),
		"explanation_entries": explanation_entries,
		"weapons_used": weapons_used,
		"enemy_count": enemy_count,
		"timing_records": timing.records()
	})


func _execute_player_command(
	context: TacticalActionContext,
	command: Variant,
	resolver: EnemyTurnResolver,
	event_log: Array[DomainEvent],
	timing: LocalTimingRecorder
) -> ActionResult:
	timing.begin(&"command_execution")
	var command_result: ActionResult = command.execute(context)
	timing.end(&"command_execution")
	if command_result.is_error():
		return command_result
	for event: DomainEvent in command_result.events:
		event_log.append(event)

	timing.begin(&"enemy_turn_resolution")
	var enemy_result: ActionResult = resolver.resolve_after_player_action(context, command_result)
	timing.end(&"enemy_turn_resolution")
	if enemy_result.is_error():
		return enemy_result
	for event: DomainEvent in enemy_result.events:
		event_log.append(event)
	return ActionResult.ok(command_result.events + enemy_result.events)


func _update_visibility(
	board: BoardState,
	event_log: Array[DomainEvent],
	timing: LocalTimingRecorder
) -> ActionResult:
	timing.begin(&"line_of_sight_update")
	var visibility_result: ActionResult = TacticalVisibilityQuery.new().create_visibility_updated_event(board, HERO_ID)
	timing.end(&"line_of_sight_update")
	if visibility_result.is_error():
		return visibility_result
	var apply_result: ActionResult = board.apply_events(visibility_result.events)
	if apply_result.is_error():
		return apply_result
	for event: DomainEvent in visibility_result.events:
		event_log.append(event)
	return visibility_result


func _create_board(enemy_repository: EnemyRepository) -> ActionResult:
	var board: BoardState = BoardState.new()
	var create_result: ActionResult = CreateBoardCommand.new(6, 6).execute(board)
	if create_result.is_error():
		return create_result

	var terrain_results: Array[ActionResult] = [
		board.set_cell_terrain_for_setup(Vector2i(0, 2), BoardCell.Terrain.ENTRANCE),
		board.set_cell_terrain_for_setup(Vector2i(5, 5), BoardCell.Terrain.EXIT),
		board.set_cell_terrain_for_setup(Vector2i(3, 1), BoardCell.Terrain.WALL)
	]
	for terrain_result: ActionResult in terrain_results:
		if terrain_result.is_error():
			return terrain_result

	var iron_definition: EnemyDefinition = enemy_repository.get_enemy(&"iron_cultist")
	var seer_definition: EnemyDefinition = enemy_repository.get_enemy(&"ash_seer")
	if iron_definition == null or seer_definition == null:
		return _invalid(&"missing_enemy_definition")

	var placement_results: Array[ActionResult] = [
		board.place_entity_for_setup(TacticalEntityState.new(
			HERO_ID,
			TacticalEntityState.EntityType.PLAYER,
			&"player",
			Vector2i(0, 2),
			18,
			18,
			true
		)),
		board.place_entity_for_setup(_enemy_from_definition(IRON_ID, iron_definition, Vector2i(3, 2))),
		board.place_entity_for_setup(_enemy_from_definition(SEER_ID, seer_definition, Vector2i(1, 5)))
	]
	for placement_result: ActionResult in placement_results:
		if placement_result.is_error():
			return placement_result
	return ActionResult.ok([], {"board": board})


func _enemy_from_definition(
	entity_id: StringName,
	definition: EnemyDefinition,
	position: Vector2i
) -> TacticalEntityState:
	return TacticalEntityState.new(
		entity_id,
		TacticalEntityState.EntityType.ENEMY,
		&"enemy",
		position,
		definition.max_hp,
		definition.max_hp,
		definition.blocks_movement,
		definition.enemy_id
	)


func _is_alive(board: BoardState, entity_id: StringName) -> bool:
	var entity: TacticalEntityState = board.get_entity(entity_id)
	return entity != null and entity.is_alive()


func _living_enemy_count(board: BoardState) -> int:
	var count: int = 0
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type == TacticalEntityState.EntityType.ENEMY and entity.is_alive():
			count += 1
	return count


func _enemy_count(board: BoardState) -> int:
	var count: int = 0
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type == TacticalEntityState.EntityType.ENEMY:
			count += 1
	return count


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_micro_combat_scenario", result_metadata)
