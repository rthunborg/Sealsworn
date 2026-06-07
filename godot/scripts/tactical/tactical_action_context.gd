class_name TacticalActionContext
extends RefCounted

const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

var board: BoardState = null
var turn_state: TacticalTurnState = null
var rng_streams: RngStreamSet = null

func _init(
	new_board: BoardState = null,
	new_turn_state: TacticalTurnState = null,
	new_rng_streams: RngStreamSet = null
) -> void:
	board = new_board
	turn_state = new_turn_state
	rng_streams = new_rng_streams


func has_required_state() -> bool:
	return board != null and turn_state != null and rng_streams != null
