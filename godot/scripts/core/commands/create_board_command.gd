class_name CreateBoardCommand
extends "res://scripts/core/commands/game_command.gd"

const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

var width: int = 0
var height: int = 0

func _init(new_width: int = 0, new_height: int = 0) -> void:
	command_id = &"create_board"
	width = new_width
	height = new_height


func validate(state: Variant) -> ActionResult:
	if not state is BoardState:
		return ActionResult.error(&"invalid_state_type")

	var board_state: BoardState = state as BoardState
	if width <= 0 or height <= 0:
		return ActionResult.error(&"invalid_board_size")
	if board_state.has_cells():
		return ActionResult.error(&"board_already_created")

	return ActionResult.ok()


func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var board_state: BoardState = state as BoardState
	var event: DomainEvent = DomainEvent.board_created(
		board_state.next_sequence_id(),
		width,
		height
	)
	var apply_result: ActionResult = board_state.apply_events([event])
	if apply_result.is_error():
		return apply_result
	return ActionResult.ok([event])
