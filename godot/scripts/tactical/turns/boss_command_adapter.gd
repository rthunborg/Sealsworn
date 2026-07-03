class_name BossCommandAdapter
extends RefCounted

# The NARROW Larval Avatar boss command ADAPTER (Story 9.3, FR63, AC2/AC4) — the boss analogue of EnemyCommandAdapter.
# It `match`es the boss decision's adapter action id and turns the chosen boss action into the SAME EXISTING DomainEvents
# applied through board.apply_events — the boss logic NEVER mutates BoardState / TacticalEntityState / TacticalTurnState
# directly (AC2). Every emitted event carries the boss ability's `explanation` + `action_id` (+ score/reasons) so the
# combat explanation log can name the ability that hit the player (AC4).
#
# THE MAPPING (all through existing events — NO new event, NO direct mutation):
#   - `telegraph`  -> a tile_marked event this turn (adds a pending larval_avatar_telegraph via PendingTelegraphState;
#                     due_turn == created_turn + 1, the one-turn response window — NFR10 forbids a real-time timer).
#                     NO damage this turn (the telegraph precedes the damage — AC1).
#   - `resolve`    -> a marked_tile_detonated event (+ a damage_applied on a HIT — the player still on the marked cell;
#                     an `avoided` outcome + NO damage if the player moved off — the Ash Seer avoided precedent).
#   - `move`       -> an entity_moved event (skitter — one cardinal step toward the player).
#   - `wait`       -> an enemy_waited event (the deterministic no-op fallback).
# The boss telegraph reuses the PendingTelegraphState pending vocabulary under the DISTINCT larval_avatar_telegraph kind
# (the record honestly names the boss ability system, not an Ash Seer mark). The damage_applied payload mirrors the
# EnemyCommandAdapter._damage_payload shape (weapon_id/base_damage/final_damage/damage_type/explanation).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AiDecision = preload("res://scripts/ai/ai_decision.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PendingTelegraphState = preload("res://scripts/tactical/turns/pending_telegraph_state.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

func apply_decision(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: BossDefinition
) -> ActionResult:
	if context == null or not context.has_required_state() or decision == null:
		return _invalid(&"invalid_context")

	match decision.action_id:
		&"telegraph":
			return _apply_telegraph(context, decision, definition)
		&"resolve":
			return _apply_resolution(context, decision, definition)
		&"move":
			return _apply_move(context, decision, definition)
		&"wait":
			return _apply_wait(context, decision, definition)
		_:
			return _invalid(&"unsupported_action", {"action_id": String(decision.action_id)})


# TELEGRAPH: mark the player's current cell for a delayed boss ability. Emits a tile_marked event carrying the boss
# ability's telegraph_text/damage/damage_type/explanation, adds the pending telegraph (due == created + 1), and does
# NOT damage this turn (AC1 — the telegraph precedes the damage).
func _apply_telegraph(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: BossDefinition
) -> ActionResult:
	if definition == null:
		return _apply_wait(context, _wait_decision(decision, &"invalid_definition"), null)

	var board: BoardState = context.board
	var boss: TacticalEntityState = board.get_entity(decision.enemy_id)
	var target: TacticalEntityState = board.get_entity(decision.target_entity_id)
	if boss == null or target == null:
		return _invalid(&"invalid_actor")
	if boss.is_dead() or target.is_dead():
		return _invalid(&"dead_actor")

	var boss_action_id: String = String(decision.metadata.get("boss_action_id", ""))
	var damage: int = int(decision.metadata.get("damage", 0))
	if damage <= 0:
		# A telegraph MUST carry positive damage (the pending-mark validator rejects <= 0). A zero-damage ability is a
		# reposition, not a telegraph — a decision mismatch, fall back to a deterministic wait.
		return _apply_wait(context, _wait_decision(decision, &"non_damaging_telegraph"), definition)
	var damage_type: String = String(decision.metadata.get("damage_type", "physical"))
	var telegraph_text: String = String(decision.metadata.get("telegraph_text", ""))
	var explanation: String = String(decision.metadata.get("explanation", ""))

	var sequence_id: int = board.next_sequence_id()
	var telegraph_id: String = "%s:%s:%s" % [PendingTelegraphState.KIND_LARVAL_AVATAR_TELEGRAPH, String(decision.enemy_id), sequence_id]
	var created_turn: int = context.turn_state.turn_number
	var due_turn: int = created_turn + 1
	var event: DomainEvent = DomainEvent.tile_marked(
		sequence_id,
		decision.enemy_id,
		decision.target_entity_id,
		decision.target_cell,
		telegraph_id,
		{
			"kind": PendingTelegraphState.KIND_LARVAL_AVATAR_TELEGRAPH,
			"source_entity_id": String(decision.enemy_id),
			"boss_definition_id": String(definition.boss_id),
			"boss_action_id": boss_action_id,
			"created_turn_number": created_turn,
			"due_turn_number": due_turn,
			"damage": damage,
			"damage_type": damage_type,
			"status": PendingTelegraphState.STATUS_PENDING,
			"action_id": String(decision.action_id),
			"score": decision.score,
			"reasons": decision.reasons.duplicate(),
			"telegraph_text": telegraph_text,
			"explanation": _telegraph_explanation(definition, boss_action_id, telegraph_text, decision.target_cell)
		}
	)
	var pending_validation: ActionResult = PendingTelegraphState.validate_events(context.pending_telegraphs, [event])
	if pending_validation.is_error():
		return pending_validation
	var apply_result: ActionResult = _apply_events(board, [event], decision)
	if apply_result.is_error():
		return apply_result
	var pending_result: ActionResult = PendingTelegraphState.apply_events(context.pending_telegraphs, [event])
	if pending_result.is_error():
		return pending_result
	var pending_index: int = PendingTelegraphState.pending_mark_index(context.pending_telegraphs, telegraph_id)
	if pending_index >= 0:
		apply_result.metadata["pending_telegraph"] = context.pending_telegraphs[pending_index].duplicate(true)
	return apply_result


# RESOLVE: detonate a DUE boss telegraph. Emits a marked_tile_detonated event (+ a damage_applied on a HIT — the player
# still on the marked cell). An `avoided` outcome + NO damage if the player escaped. The damage_applied explanation
# names the boss ability (AC4).
func _apply_resolution(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: BossDefinition
) -> ActionResult:
	if definition == null:
		return _apply_wait(context, _wait_decision(decision, &"invalid_definition"), null)

	var board: BoardState = context.board
	var mark_index: int = PendingTelegraphState.pending_mark_index(context.pending_telegraphs, String(decision.metadata.get("telegraph_id", "")))
	if mark_index < 0:
		return _apply_wait(context, _wait_decision(decision, &"missing_telegraph"), definition)

	var mark: Dictionary = context.pending_telegraphs[mark_index]
	var mark_validation: ActionResult = _validate_due_telegraph(context, decision, mark)
	if mark_validation.is_error():
		return mark_validation

	var target_entity_id: StringName = StringName(str(mark.get("target_entity_id", String(decision.target_entity_id))))
	var target: TacticalEntityState = board.get_entity(target_entity_id)
	if target == null:
		return _apply_wait(context, _wait_decision(decision, &"missing_target"), definition)

	var marked_cell: Vector2i = _cell_from_metadata(mark.get("marked_cell", {}))
	var damage: int = int(mark.get("damage", 0))
	var damage_type: String = String(mark.get("damage_type", "physical"))
	var boss_action_id: String = String(mark.get("boss_action_id", ""))
	var hit: bool = target.position == marked_cell
	var outcome: StringName = &"hit" if hit else &"avoided"
	var first_sequence_id: int = board.next_sequence_id()
	var events: Array[DomainEvent] = [
		DomainEvent.marked_tile_detonated(
			first_sequence_id,
			decision.enemy_id,
			target_entity_id,
			marked_cell,
			String(mark.get("telegraph_id", "")),
			outcome,
			{
				"damage": damage,
				"damage_type": damage_type,
				"boss_action_id": boss_action_id,
				"action_id": String(decision.action_id),
				"score": decision.score,
				"reasons": decision.reasons.duplicate(),
				"explanation": _resolution_explanation(definition, boss_action_id, hit, marked_cell)
			}
		)
	]
	if hit:
		var hp_before: int = target.current_hp
		var hp_after: int = max(0, hp_before - damage)
		events.append(DomainEvent.damage_applied(
			first_sequence_id + 1,
			decision.enemy_id,
			target_entity_id,
			damage,
			hp_before,
			hp_after,
			target.max_hp,
			_damage_payload(
				definition,
				boss_action_id,
				damage,
				damage_type,
				_damage_explanation(definition, boss_action_id, target_entity_id, damage, damage_type)
			)
		))

	var pending_validation: ActionResult = PendingTelegraphState.validate_events(context.pending_telegraphs, events)
	if pending_validation.is_error():
		return pending_validation
	var apply_result: ActionResult = _apply_events(board, events, decision)
	if apply_result.is_error():
		return apply_result
	var pending_result: ActionResult = PendingTelegraphState.apply_events(context.pending_telegraphs, events)
	if pending_result.is_error():
		return pending_result
	apply_result.metadata["resolution_outcome"] = String(outcome)
	return apply_result


# MOVE: skitter one cardinal step toward the player (the EnemyCommandAdapter._apply_move shape). Rejects a non-cardinal
# or non-unit step (a malformed decision) without mutating.
func _apply_move(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: BossDefinition
) -> ActionResult:
	if definition == null:
		return _apply_wait(context, _wait_decision(decision, &"invalid_definition"), null)

	var board: BoardState = context.board
	var boss: TacticalEntityState = board.get_entity(decision.enemy_id)
	if boss == null:
		return _invalid(&"invalid_actor")
	if boss.is_dead():
		return _invalid(&"dead_actor")
	if decision.to_cell == Vector2i(-1, -1) or decision.to_cell == boss.position:
		return _apply_wait(context, _wait_decision(decision, &"blocked"), definition)
	if decision.from_cell != Vector2i(-1, -1) and decision.from_cell != boss.position:
		return _invalid(&"from_cell_mismatch")
	if _manhattan_distance(boss.position, decision.to_cell) != 1 or not _is_cardinally_aligned(boss.position, decision.to_cell):
		return _invalid(&"invalid_move_step")

	var event: DomainEvent = DomainEvent.entity_moved(
		board.next_sequence_id(),
		boss.entity_id,
		boss.position,
		decision.to_cell,
		1,
		1
	)
	return _apply_events(board, [event], decision)


func _apply_wait(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: BossDefinition
) -> ActionResult:
	var board: BoardState = context.board
	var definition_id: String = String(decision.enemy_definition_id)
	if definition != null:
		definition_id = String(definition.boss_id)
	var wait_reason: StringName = decision.wait_reason
	if wait_reason == &"":
		wait_reason = StringName(str(decision.metadata.get("wait_reason", "blocked")))
	var payload: Dictionary = {
		"action_id": "wait",
		"score": decision.score,
		"reasons": decision.reasons.duplicate(),
		"explanation": "%s waited: %s." % [String(decision.enemy_id), String(wait_reason)]
	}
	if _is_lower_snake_id(definition_id):
		payload["boss_definition_id"] = definition_id
	var event: DomainEvent = DomainEvent.enemy_waited(board.next_sequence_id(), decision.enemy_id, wait_reason, payload)
	return _apply_events(board, [event], decision)


func _apply_events(board: BoardState, events: Array[DomainEvent], decision: AiDecision) -> ActionResult:
	var apply_result: ActionResult = board.apply_events(events)
	if apply_result.is_error():
		return apply_result
	return ActionResult.ok(events, {
		"decision": decision.to_dictionary()
	})


func _wait_decision(decision: AiDecision, reason: StringName) -> AiDecision:
	return AiDecision.new(
		decision.enemy_id,
		decision.enemy_definition_id,
		&"wait",
		0,
		["adapter_fallback"],
		&"",
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		reason,
		{"wait_reason": String(reason)}
	)


func _validate_due_telegraph(
	context: TacticalActionContext,
	decision: AiDecision,
	mark: Dictionary
) -> ActionResult:
	var base_validation: ActionResult = PendingTelegraphState.validate_pending_mark(mark)
	if base_validation.is_error():
		return _invalid(&"invalid_pending_telegraph", base_validation.metadata)
	if String(mark.get("kind", "")) != PendingTelegraphState.KIND_LARVAL_AVATAR_TELEGRAPH:
		return _invalid(&"invalid_kind", {"telegraph_id": String(mark.get("telegraph_id", ""))})
	if String(mark.get("source_entity_id", "")) != String(decision.enemy_id):
		return _invalid(&"source_mismatch", {"telegraph_id": String(mark.get("telegraph_id", ""))})
	if String(mark.get("status", "")) != PendingTelegraphState.STATUS_PENDING:
		return _invalid(&"invalid_telegraph_status", {"telegraph_id": String(mark.get("telegraph_id", ""))})
	if int(mark.get("due_turn_number", 0)) > context.turn_state.turn_number:
		return _invalid(&"telegraph_not_due", {
			"telegraph_id": String(mark.get("telegraph_id", "")),
			"due_turn_number": int(mark.get("due_turn_number", 0)),
			"turn_number": context.turn_state.turn_number
		})
	return ActionResult.ok()


func _damage_payload(
	definition: BossDefinition,
	boss_action_id: String,
	damage: int,
	damage_type: String,
	explanation: String
) -> Dictionary:
	return {
		"weapon_id": _damage_source_id(definition, boss_action_id),
		"base_damage": damage,
		"support_bonus_damage": 0,
		"armor_reduction": 0,
		"block_succeeded": false,
		"final_damage": damage,
		"damage_type": damage_type,
		"boss_action_id": boss_action_id,
		"rng_draws": [],
		"explanation": explanation
	}


func _damage_source_id(definition: BossDefinition, boss_action_id: String) -> String:
	if _is_lower_snake_id(boss_action_id):
		return "%s_%s" % [String(definition.boss_id), boss_action_id]
	return String(definition.boss_id)


func _telegraph_explanation(definition: BossDefinition, boss_action_id: String, telegraph_text: String, marked_cell: Vector2i) -> String:
	if not telegraph_text.strip_edges().is_empty():
		return telegraph_text
	return "%s telegraphs %s at (%s,%s)." % [String(definition.boss_id), boss_action_id, marked_cell.x, marked_cell.y]


func _resolution_explanation(definition: BossDefinition, boss_action_id: String, hit: bool, marked_cell: Vector2i) -> String:
	return "%s %s %s at (%s,%s)." % [
		String(definition.boss_id),
		boss_action_id,
		"resolved" if hit else "expired avoided",
		marked_cell.x,
		marked_cell.y
	]


func _damage_explanation(definition: BossDefinition, boss_action_id: String, target_entity_id: StringName, damage: int, damage_type: String) -> String:
	return "%s %s dealt %s %s damage to %s." % [
		String(definition.boss_id),
		boss_action_id,
		damage,
		damage_type,
		String(target_entity_id)
	]


func _manhattan_distance(first: Vector2i, second: Vector2i) -> int:
	return abs(first.x - second.x) + abs(first.y - second.y)


func _is_cardinally_aligned(first: Vector2i, second: Vector2i) -> bool:
	return first.x == second.x or first.y == second.y


func _is_lower_snake_id(value: String) -> bool:
	if value.is_empty():
		return false
	if value != value.to_lower():
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false
	return true


func _cell_from_metadata(value: Variant) -> Vector2i:
	if not value is Dictionary:
		return Vector2i(-1, -1)
	var cell_data: Dictionary = value
	return Vector2i(int(cell_data.get("x", -1)), int(cell_data.get("y", -1)))


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_boss_action", result_metadata)
