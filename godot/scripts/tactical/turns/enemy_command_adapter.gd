class_name EnemyCommandAdapter
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AiDecision = preload("res://scripts/ai/ai_decision.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyDefinition = preload("res://scripts/content/definitions/enemy_definition.gd")
const PendingTelegraphState = preload("res://scripts/tactical/turns/pending_telegraph_state.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalLineQuery = preload("res://scripts/tactical/targeting/tactical_line_query.gd")

# Story 12.2 (AC3 — the hero-defense seam): the DEFENDING player's identity + its loadout defender support (the class
# off-hand). When an enemy attack resolves against THIS player id and the support is a shield, the SAME seeded
# AttackCommand.roll_shield_block runs on the `combat` stream (armor + block-halving protect the shield's OWNER). Both
# default to the neutral no-defense case (&"" / null) so every existing caller — the auto-resolve driver, the boss path,
# the direct adapter tests — stays BYTE-IDENTICAL (a null defender support draws NOTHING). Set by EnemyTurnResolver.
var _player_id: StringName = &""
var _player_defender_support: SupportDefinition = null

func _init(new_player_id: StringName = &"", new_player_defender_support: SupportDefinition = null) -> void:
	_player_id = new_player_id
	_player_defender_support = new_player_defender_support


func apply_decision(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: EnemyDefinition
) -> ActionResult:
	if context == null or not context.has_required_state() or decision == null:
		return _invalid(&"invalid_context")

	match decision.action_id:
		&"attack":
			return _apply_attack(context, decision, definition)
		&"move":
			return _apply_move(context, decision, definition)
		&"mark":
			return _apply_mark(context, decision, definition)
		&"detonate":
			return _apply_detonation(context, decision, definition)
		&"wait":
			return _apply_wait(context, decision, definition)
		_:
			return _invalid(&"unsupported_action", {"action_id": String(decision.action_id)})


func _apply_attack(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: EnemyDefinition
) -> ActionResult:
	if definition == null:
		return _apply_wait(context, _wait_decision(decision, &"invalid_definition"), null)

	var board: BoardState = context.board
	var actor: TacticalEntityState = board.get_entity(decision.enemy_id)
	var target: TacticalEntityState = board.get_entity(decision.target_entity_id)
	if actor == null or target == null:
		return _invalid(&"invalid_actor")
	if actor.is_dead() or target.is_dead():
		return _invalid(&"dead_actor")

	var distance: int = _manhattan_distance(actor.position, target.position)
	if distance > definition.melee_range or not _is_cardinally_aligned(actor.position, target.position):
		return _invalid(&"invalid_target")

	var base_damage: int = definition.melee_damage
	var source_id: StringName = definition.melee_source_id()

	# Story 12.2 (AC3 — the hero-defense seam): if THIS attack lands on the seated player and it carries a shield off-hand,
	# resolve the SAME defender-support finalization AttackCommand applies — the shield's armor reduces the raw hit, then
	# the SINGLE seeded AttackCommand.roll_shield_block (the `combat` stream) halves it on a block. The shield protects its
	# OWNER (the hero). The neutral case (no defender support / a non-hero target) is a ZERO-draw no-op that yields the
	# byte-identical damage the enemy always dealt. The block draw runs on the SIMULATION context's `combat` stream here;
	# EnemyTurnResolver syncs that advanced stream back to the run-level context so the roll is a real, seeded, reproducible
	# run-level `combat` draw (never a throwaway).
	var defender_support: SupportDefinition = _defender_support_for(target)
	var armor_reduction: int = _armor_reduction_for(defender_support, base_damage)
	var post_armor_damage: int = max(0, base_damage - armor_reduction)
	var block: ActionResult = AttackCommand.roll_shield_block(context.rng_streams, defender_support, actor.entity_id, target.entity_id)
	if block.is_error():
		return block
	var block_succeeded: bool = bool(block.metadata.get("block_succeeded", false))
	var block_draw: Dictionary = block.metadata.get("draw", {})
	var rng_draws: Array[Dictionary] = []
	if not block_draw.is_empty():
		rng_draws.append(block_draw)

	var damage: int = post_armor_damage
	if block_succeeded:
		damage = int(floor(float(post_armor_damage) * 0.5))
	# A neutral (unshielded) hit deals the raw melee_damage byte-for-byte; only a real shield floors the damage at >= 1.
	if defender_support != null:
		damage = max(1, damage)

	var hp_before: int = target.current_hp
	var hp_after: int = max(0, hp_before - damage)
	var first_sequence_id: int = board.next_sequence_id()
	var events: Array[DomainEvent] = [
		DomainEvent.entity_attacked(
			first_sequence_id,
			actor.entity_id,
			target.entity_id,
			target.position,
			source_id,
			_attack_payload(definition, decision, actor.position, target.position, distance)
		),
		DomainEvent.damage_applied(
			first_sequence_id + 1,
			actor.entity_id,
			target.entity_id,
			damage,
			hp_before,
			hp_after,
			target.max_hp,
			_attack_damage_payload(
				source_id,
				base_damage,
				damage,
				armor_reduction,
				block_succeeded,
				rng_draws,
				definition.melee_damage_type,
				_attack_explanation(definition, target.entity_id, damage)
			)
		)
	]
	return _apply_events(board, events, decision)


func _apply_move(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: EnemyDefinition
) -> ActionResult:
	if definition == null:
		return _apply_wait(context, _wait_decision(decision, &"invalid_definition"), null)

	var board: BoardState = context.board
	var actor: TacticalEntityState = board.get_entity(decision.enemy_id)
	if actor == null:
		return _invalid(&"invalid_actor")
	if actor.is_dead():
		return _invalid(&"dead_actor")
	if decision.to_cell == Vector2i(-1, -1) or decision.to_cell == actor.position:
		return _apply_wait(context, _wait_decision(decision, &"blocked"), definition)
	if decision.from_cell != Vector2i(-1, -1) and decision.from_cell != actor.position:
		return _invalid(&"from_cell_mismatch")
	if _manhattan_distance(actor.position, decision.to_cell) != 1 or not _is_cardinally_aligned(actor.position, decision.to_cell):
		return _invalid(&"invalid_move_step")

	var event: DomainEvent = DomainEvent.entity_moved(
		board.next_sequence_id(),
		actor.entity_id,
		actor.position,
		decision.to_cell,
		1,
		definition.move_budget
	)
	return _apply_events(board, [event], decision)


func _apply_mark(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: EnemyDefinition
) -> ActionResult:
	if definition == null:
		return _apply_wait(context, _wait_decision(decision, &"invalid_definition"), null)

	var board: BoardState = context.board
	var sequence_id: int = board.next_sequence_id()
	var telegraph_id: String = "ash_seer_mark:%s:%s" % [String(decision.enemy_id), sequence_id]
	var created_turn: int = context.turn_state.turn_number
	var due_turn: int = created_turn + 1
	var event: DomainEvent = DomainEvent.tile_marked(
		sequence_id,
		decision.enemy_id,
		decision.target_entity_id,
		decision.target_cell,
		telegraph_id,
		{
			"kind": PendingTelegraphState.KIND_ASH_SEER_MARK,
			"source_entity_id": String(decision.enemy_id),
			"enemy_definition_id": String(definition.enemy_id),
			"created_turn_number": created_turn,
			"due_turn_number": due_turn,
			"damage": definition.detonation_damage,
			"damage_type": String(definition.detonation_damage_type),
			"status": PendingTelegraphState.STATUS_PENDING,
			"action_id": String(decision.action_id),
			"score": decision.score,
			"reasons": decision.reasons.duplicate(),
			"explanation": "Ash Seer marked %s at (%s,%s) for delayed detonation." % [
				String(decision.target_entity_id),
				decision.target_cell.x,
				decision.target_cell.y
			]
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


func _apply_detonation(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: EnemyDefinition
) -> ActionResult:
	if definition == null:
		return _apply_wait(context, _wait_decision(decision, &"invalid_definition"), null)

	var board: BoardState = context.board
	var mark_index: int = PendingTelegraphState.pending_mark_index(context.pending_telegraphs, String(decision.metadata.get("telegraph_id", "")))
	if mark_index < 0:
		return _apply_wait(context, _wait_decision(decision, &"missing_mark"), definition)

	var mark: Dictionary = context.pending_telegraphs[mark_index]
	var mark_validation: ActionResult = _validate_due_mark_for_detonation(context, decision, definition, mark)
	if mark_validation.is_error():
		return mark_validation
	var target_entity_id: StringName = StringName(str(mark.get("target_entity_id", String(decision.target_entity_id))))
	var target: TacticalEntityState = board.get_entity(target_entity_id)
	if target == null:
		return _apply_wait(context, _wait_decision(decision, &"missing_target"), definition)

	var marked_cell: Vector2i = _cell_from_metadata(mark.get("marked_cell", {}))
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
				"damage": definition.detonation_damage,
				"damage_type": String(definition.detonation_damage_type),
				"action_id": String(decision.action_id),
				"score": decision.score,
				"reasons": decision.reasons.duplicate(),
				"explanation": "Ash Seer mark %s at (%s,%s)." % [
					"detonated" if hit else "expired avoided",
					marked_cell.x,
					marked_cell.y
				]
			}
		)
	]
	if hit:
		var hp_before: int = target.current_hp
		var hp_after: int = max(0, hp_before - definition.detonation_damage)
		events.append(DomainEvent.damage_applied(
			first_sequence_id + 1,
			decision.enemy_id,
			target_entity_id,
			definition.detonation_damage,
			hp_before,
			hp_after,
			target.max_hp,
			_damage_payload(
				&"ash_seer_detonation",
				definition.detonation_damage,
				definition.detonation_damage_type,
				"Ash Seer detonation dealt %s physical damage to %s." % [
					definition.detonation_damage,
					String(target_entity_id)
				]
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
	apply_result.metadata["detonation_outcome"] = String(outcome)
	return apply_result


func _apply_wait(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: EnemyDefinition
) -> ActionResult:
	var board: BoardState = context.board
	var definition_id: String = String(decision.enemy_definition_id)
	if definition != null:
		definition_id = String(definition.enemy_id)
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
		payload["enemy_definition_id"] = definition_id
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


func _attack_payload(
	definition: EnemyDefinition,
	decision: AiDecision,
	from_cell: Vector2i,
	target_cell: Vector2i,
	distance: int
) -> Dictionary:
	return {
		"enemy_definition_id": String(definition.enemy_id),
		"expected_base_damage": definition.melee_damage,
		"range": definition.melee_range,
		"distance": distance,
		"line_cells": _serialize_cells(TacticalLineQuery.supercover_line(from_cell, target_cell)),
		"blocker_cells": [],
		"blocker_ignored": false,
		"warnings": [],
		"effects": [],
		"action_id": String(decision.action_id),
		"score": decision.score,
		"reasons": decision.reasons.duplicate(),
		"explanation": _attack_explanation(definition, decision.target_entity_id, definition.melee_damage)
	}


func _damage_payload(
	source_id: StringName,
	damage: int,
	damage_type: StringName,
	explanation: String
) -> Dictionary:
	return {
		"weapon_id": String(source_id),
		"base_damage": damage,
		"support_bonus_damage": 0,
		"armor_reduction": 0,
		"block_succeeded": false,
		"final_damage": damage,
		"damage_type": String(damage_type),
		"rng_draws": [],
		"explanation": explanation
	}


# Story 12.2 (AC3 — the hero-defense seam) — the melee damage payload carrying the DEFENDER-side shield outcome (armor +
# block + the seeded rng_draws), mirroring AttackCommand's damage payload shape. Enemies carry no attacker support, so
# support_bonus_damage is always 0. For the neutral (unshielded) hit — armor_reduction 0, block_succeeded false, empty
# rng_draws, base_damage == final_damage — this is BYTE-IDENTICAL to the pre-12.2 _damage_payload output.
func _attack_damage_payload(
	source_id: StringName,
	base_damage: int,
	final_damage: int,
	armor_reduction: int,
	block_succeeded: bool,
	rng_draws: Array[Dictionary],
	damage_type: StringName,
	explanation: String
) -> Dictionary:
	return {
		"weapon_id": String(source_id),
		"base_damage": base_damage,
		"support_bonus_damage": 0,
		"armor_reduction": armor_reduction,
		"block_succeeded": block_succeeded,
		"final_damage": final_damage,
		"damage_type": String(damage_type),
		"rng_draws": rng_draws.duplicate(true),
		"explanation": explanation
	}


# The DEFENDER support for an enemy's target: the seated player's loadout shield when the target IS the seated player
# (the hero-defense seam), else null (a non-hero target, or no seated defender support — the neutral no-defense case).
func _defender_support_for(target: TacticalEntityState) -> SupportDefinition:
	if _player_defender_support == null or _player_id == &"":
		return null
	if target.entity_id != _player_id:
		return null
	return _player_defender_support


# The shield's flat armor reduction, clamped to the incoming damage (mirrors AttackCommand._armor_reduction). A null /
# non-shield support reduces nothing.
func _armor_reduction_for(defender_support: SupportDefinition, damage_before_defense: int) -> int:
	if defender_support == null:
		return 0
	return min(defender_support.armor, max(0, damage_before_defense))


func _attack_explanation(definition: EnemyDefinition, target_entity_id: StringName, damage: int) -> String:
	return "%s hit %s for %s physical damage." % [
		String(definition.enemy_id),
		String(target_entity_id),
		damage
	]


func _validate_due_mark_for_detonation(
	context: TacticalActionContext,
	decision: AiDecision,
	definition: EnemyDefinition,
	mark: Dictionary
) -> ActionResult:
	var base_validation: ActionResult = PendingTelegraphState.validate_pending_mark(mark)
	if base_validation.is_error():
		return _invalid(&"invalid_pending_mark", base_validation.metadata)
	if String(mark.get("source_entity_id", "")) != String(decision.enemy_id):
		return _invalid(&"source_mismatch", {"telegraph_id": String(mark.get("telegraph_id", ""))})
	if String(mark.get("status", "")) != PendingTelegraphState.STATUS_PENDING:
		return _invalid(&"invalid_mark_status", {"telegraph_id": String(mark.get("telegraph_id", ""))})
	if int(mark.get("due_turn_number", 0)) > context.turn_state.turn_number:
		return _invalid(&"mark_not_due", {
			"telegraph_id": String(mark.get("telegraph_id", "")),
			"due_turn_number": int(mark.get("due_turn_number", 0)),
			"turn_number": context.turn_state.turn_number
		})
	if int(mark.get("damage", 0)) != definition.detonation_damage:
		return _invalid(&"damage_mismatch", {"telegraph_id": String(mark.get("telegraph_id", ""))})
	if String(mark.get("damage_type", "")) != String(definition.detonation_damage_type):
		return _invalid(&"damage_type_mismatch", {"telegraph_id": String(mark.get("telegraph_id", ""))})
	return ActionResult.ok()


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


func _serialize_cells(cells: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Vector2i in cells:
		result.append(_cell_metadata(cell))
	return result


func _cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


func _cell_from_metadata(value: Variant) -> Vector2i:
	if not value is Dictionary:
		return Vector2i(-1, -1)
	var cell_data: Dictionary = value
	return Vector2i(int(cell_data.get("x", -1)), int(cell_data.get("y", -1)))


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_enemy_action", result_metadata)
