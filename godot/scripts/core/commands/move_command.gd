class_name MoveCommand
extends "res://scripts/core/commands/game_command.gd"

const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalMovementQuery = preload("res://scripts/tactical/movement/tactical_movement_query.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

const BASELINE_MOVEMENT_BUDGET: int = 3

var actor_id: StringName = &""
var target_cell: Vector2i = Vector2i.ZERO
var movement_budget: int = BASELINE_MOVEMENT_BUDGET

func _init(
	new_actor_id: StringName = &"",
	new_target_cell: Vector2i = Vector2i.ZERO,
	new_movement_budget: int = BASELINE_MOVEMENT_BUDGET
) -> void:
	command_id = &"move"
	actor_id = new_actor_id
	target_cell = new_target_cell
	movement_budget = new_movement_budget


func validate(state: Variant) -> ActionResult:
	if not state is TacticalActionContext:
		return _invalid(&"invalid_context")

	var context: TacticalActionContext = state as TacticalActionContext
	if not context.has_required_state():
		return _invalid(&"invalid_context")

	var board: BoardState = context.board
	var actor: TacticalEntityState = board.get_entity(actor_id)
	if actor == null or actor_id == &"":
		return _invalid(&"invalid_actor", {"actor_id": String(actor_id)})
	if actor.is_dead():
		return _invalid(&"dead_actor", {"actor_id": String(actor_id)})
	if context.turn_state.phase != TacticalTurnState.Phase.PLAYER_PLANNING:
		return _invalid(&"wrong_phase", {
			"phase": String(TacticalTurnState.id_for_phase(context.turn_state.phase))
		})
	if context.turn_state.active_actor_id != actor_id:
		return _invalid(&"wrong_phase", {
			"active_actor_id": String(context.turn_state.active_actor_id),
			"actor_id": String(actor_id)
		})

	var query: TacticalMovementQuery = TacticalMovementQuery.new()
	return query.validate_target(board, actor_id, target_cell, movement_budget)


func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var context: TacticalActionContext = state as TacticalActionContext
	var actor: TacticalEntityState = context.board.get_entity(actor_id)
	var movement_cost: int = int(validation.metadata.get("movement_cost", 0))
	var event: DomainEvent = DomainEvent.entity_moved(
		context.board.next_sequence_id(),
		actor_id,
		actor.position,
		target_cell,
		movement_cost,
		movement_budget
	)

	var apply_result: ActionResult = context.board.apply_events([event])
	if apply_result.is_error():
		return apply_result

	var metadata: Dictionary = {
		"advances_turn": true,
		"movement_cost": movement_cost,
		"movement_budget": movement_budget
	}
	if validation.metadata.has("path"):
		metadata["path"] = validation.metadata.get("path")
	return ActionResult.ok([event], metadata)


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_movement", result_metadata)
