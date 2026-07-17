class_name WaitCommand
extends "res://scripts/core/commands/game_command.gd"

# Story 14.1 (AC2/AC4) — the WAIT / pass-turn tactical command: the F1 turn-advance BACKSTOP. Corpse-clearing
# restores movement past dead bodies; Wait guarantees a turn can ALWAYS advance even when the hero is boxed in
# with no legal move or attack (so a run can never permanently soft-lock mid-fight). Structurally mirrors
# move_command.gd: validate-before-mutate, returns ActionResult, emits ONE append-only past-tense domain event
# (hero_waited), board-applies it (so the board's _next_sequence_id advances past it — a non-applied wait event
# would collide sequence ids with the first enemy-phase event), and reports advances_turn: true so the enemy
# phase runs. It draws ZERO RNG (no stream, no draw site).

const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

# The lower_snake wait reasons the hero_waited payload may carry (mirrors the enemy_waited reason vocabulary).
const REASON_VOLUNTARY := &"voluntary"
const REASON_NO_LEGAL_ACTION := &"no_legal_action"

var actor_id: StringName = &""
var reason: StringName = REASON_VOLUNTARY

func _init(new_actor_id: StringName = &"", new_reason: StringName = REASON_VOLUNTARY) -> void:
	command_id = &"wait"
	actor_id = new_actor_id
	reason = new_reason


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

	return ActionResult.ok()


func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var context: TacticalActionContext = state as TacticalActionContext
	# ZERO RNG: a wait draws nothing. The event is board-applied so _next_sequence_id advances past it (no
	# sequence-id collision with the following enemy-phase events).
	var event: DomainEvent = DomainEvent.hero_waited(
		context.board.next_sequence_id(),
		actor_id,
		reason
	)

	var apply_result: ActionResult = context.board.apply_events([event])
	if apply_result.is_error():
		return apply_result

	return ActionResult.ok([event], {
		"advances_turn": true,
		"reason": String(reason)
	})


func _invalid(reason_code: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason_code)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_wait", result_metadata)
