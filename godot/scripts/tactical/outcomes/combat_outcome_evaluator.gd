class_name CombatOutcomeEvaluator
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

var primary_player_id: StringName = &"hero"

func _init(new_primary_player_id: StringName = &"hero") -> void:
	primary_player_id = new_primary_player_id


func evaluate(
	board: BoardState,
	outcome_state: CombatOutcomeState,
	event_log: Array[DomainEvent] = []
) -> ActionResult:
	if board == null or outcome_state == null:
		return _invalid(&"invalid_context")
	var state_validation: ActionResult = outcome_state.validate()
	if state_validation.is_error():
		return _invalid(&"invalid_outcome_state", state_validation.metadata)
	if outcome_state.is_terminal():
		return ActionResult.ok([], {
			"outcome": String(outcome_state.state_id),
			"already_terminal": true
		})

	var living_player_count: int = _living_count(board, TacticalEntityState.EntityType.PLAYER)
	var living_enemy_count: int = _living_count(board, TacticalEntityState.EntityType.ENEMY)
	var primary_player: TacticalEntityState = board.get_entity(primary_player_id)
	var primary_player_dead: bool = primary_player != null and primary_player.is_dead()

	if living_player_count == 0 or primary_player_dead:
		return _apply_defeat(board, outcome_state, event_log)
	if living_enemy_count == 0:
		return _apply_victory(board, outcome_state, event_log, living_player_count)

	return ActionResult.ok([], {
		"outcome": String(CombatOutcomeState.STATE_ACTIVE),
		"living_player_count": living_player_count,
		"remaining_enemy_count": living_enemy_count
	})


func _apply_victory(
	board: BoardState,
	outcome_state: CombatOutcomeState,
	event_log: Array[DomainEvent],
	living_player_count: int
) -> ActionResult:
	var defeated_enemy_ids: Array[String] = _defeated_enemy_ids(board)
	var cause: DomainEvent = _victory_cause(event_log, defeated_enemy_ids)
	var cause_sequence_id: int = 0
	if cause != null:
		cause_sequence_id = cause.sequence_id
	var event: DomainEvent = DomainEvent.level_victory_reached(
		board.next_sequence_id(),
		living_player_count,
		0,
		defeated_enemy_ids,
		cause_sequence_id,
		"All enemies were defeated."
	)
	return _apply_outcome_event(board, outcome_state, event)


func _apply_defeat(
	board: BoardState,
	outcome_state: CombatOutcomeState,
	event_log: Array[DomainEvent]
) -> ActionResult:
	var defeated_player_id: StringName = _defeated_player_id(board)
	if defeated_player_id == &"":
		defeated_player_id = primary_player_id
	var cause: Dictionary = _defeat_cause(event_log, defeated_player_id)
	var event: DomainEvent = DomainEvent.level_defeat_reached(
		board.next_sequence_id(),
		defeated_player_id,
		int(cause.get("cause_event_sequence_id", 0)),
		StringName(str(cause.get("cause_event_id", "unknown"))),
		StringName(str(cause.get("source_entity_id", ""))),
		StringName(str(cause.get("damage_type", "unknown"))),
		int(cause.get("final_damage", 0)),
		String(cause.get("explanation", "Hero fell."))
	)
	return _apply_outcome_event(board, outcome_state, event)


func _apply_outcome_event(
	board: BoardState,
	outcome_state: CombatOutcomeState,
	event: DomainEvent
) -> ActionResult:
	var apply_result: ActionResult = board.apply_events([event])
	if apply_result.is_error():
		return apply_result
	var state_result: ActionResult = outcome_state.apply_outcome_event(event)
	if state_result.is_error():
		return _invalid(&"invalid_outcome_state", state_result.metadata)
	return ActionResult.ok([event], {
		"outcome": String(outcome_state.state_id),
		"outcome_state": outcome_state.to_dictionary()
	})


func _victory_cause(event_log: Array[DomainEvent], defeated_enemy_ids: Array[String]) -> DomainEvent:
	var latest_defeat_damage: DomainEvent = null
	for event: DomainEvent in event_log:
		if event == null or event.event_type != DomainEvent.Type.DAMAGE_APPLIED:
			continue
		if not defeated_enemy_ids.has(String(event.payload.get("target_entity_id", ""))):
			continue
		if latest_defeat_damage == null or event.sequence_id > latest_defeat_damage.sequence_id:
			latest_defeat_damage = event
	if latest_defeat_damage != null:
		return latest_defeat_damage
	return _latest_relevant_event(event_log)


func _defeat_cause(event_log: Array[DomainEvent], defeated_player_id: StringName) -> Dictionary:
	var latest_damage: DomainEvent = null
	for event: DomainEvent in event_log:
		if event == null or event.event_type != DomainEvent.Type.DAMAGE_APPLIED:
			continue
		if String(event.payload.get("target_entity_id", "")) != String(defeated_player_id):
			continue
		if latest_damage == null or event.sequence_id > latest_damage.sequence_id:
			latest_damage = event
	if latest_damage != null:
		return {
			"cause_event_sequence_id": latest_damage.sequence_id,
			"cause_event_id": String(DomainEvent.id_for_type(latest_damage.event_type)),
			"source_entity_id": String(latest_damage.actor_id),
			"damage_type": String(latest_damage.payload.get("damage_type", "unknown")),
			"final_damage": int(latest_damage.payload.get("final_damage", latest_damage.payload.get("amount", 0))),
			"explanation": "Hero fell after %s dealt %s %s damage." % [
				String(latest_damage.actor_id),
				int(latest_damage.payload.get("final_damage", latest_damage.payload.get("amount", 0))),
				String(latest_damage.payload.get("damage_type", "unknown"))
			]
		}

	var latest_event: DomainEvent = _latest_relevant_event(event_log)
	if latest_event == null:
		return {
			"cause_event_sequence_id": 0,
			"cause_event_id": "unknown",
			"source_entity_id": "",
			"damage_type": "unknown",
			"final_damage": 0,
			"explanation": "Hero fell."
		}
	return {
		"cause_event_sequence_id": latest_event.sequence_id,
		"cause_event_id": String(DomainEvent.id_for_type(latest_event.event_type)),
		"source_entity_id": String(latest_event.actor_id),
		"damage_type": String(latest_event.payload.get("damage_type", "unknown")),
		"final_damage": int(latest_event.payload.get("final_damage", latest_event.payload.get("damage", 0))),
		"explanation": "Hero fell after %s." % String(DomainEvent.id_for_type(latest_event.event_type))
	}


func _latest_relevant_event(event_log: Array[DomainEvent]) -> DomainEvent:
	var latest: DomainEvent = null
	for event: DomainEvent in event_log:
		if event == null:
			continue
		if latest == null or event.sequence_id > latest.sequence_id:
			latest = event
	return latest


func _living_count(board: BoardState, entity_type: int) -> int:
	var count: int = 0
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type == entity_type and entity.is_alive():
			count += 1
	return count


func _defeated_enemy_ids(board: BoardState) -> Array[String]:
	var ids: Array[String] = []
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type == TacticalEntityState.EntityType.ENEMY and entity.is_dead():
			ids.append(String(entity.entity_id))
	ids.sort()
	return ids


func _defeated_player_id(board: BoardState) -> StringName:
	var fallback: StringName = &""
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.PLAYER:
			continue
		if fallback == &"":
			fallback = entity.entity_id
		if entity.entity_id == primary_player_id and entity.is_dead():
			return entity.entity_id
		if entity.is_dead():
			fallback = entity.entity_id
	return fallback


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_outcome_evaluation", result_metadata)
