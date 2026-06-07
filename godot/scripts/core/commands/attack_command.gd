class_name AttackCommand
extends "res://scripts/core/commands/game_command.gd"

const AttackPreviewQuery = preload("res://scripts/tactical/targeting/attack_preview_query.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")

const PROC_THRESHOLD: float = 0.35
const DAMAGE_TYPE_PHYSICAL := &"physical"

var actor_id: StringName = &""
var target_cell: Vector2i = Vector2i.ZERO
var weapon: WeaponDefinition = null
var attacker_support: SupportDefinition = null
var defender_support: SupportDefinition = null

func _init(
	new_actor_id: StringName = &"",
	new_target_cell: Vector2i = Vector2i.ZERO,
	new_weapon: WeaponDefinition = null,
	new_attacker_support: SupportDefinition = null,
	new_defender_support: SupportDefinition = null
) -> void:
	command_id = &"attack"
	actor_id = new_actor_id
	target_cell = new_target_cell
	weapon = new_weapon
	attacker_support = new_attacker_support
	defender_support = new_defender_support


func validate(state: Variant) -> ActionResult:
	if not state is TacticalActionContext:
		return _invalid(&"invalid_context")

	var context: TacticalActionContext = state as TacticalActionContext
	if not context.has_required_state():
		return _invalid(&"invalid_context")

	var weapon_validation: ActionResult = _validate_weapon()
	if weapon_validation.is_error():
		return weapon_validation

	var attacker_support_validation: ActionResult = _validate_support(attacker_support, &"attacker_support")
	if attacker_support_validation.is_error():
		return attacker_support_validation
	var defender_support_validation: ActionResult = _validate_support(defender_support, &"defender_support")
	if defender_support_validation.is_error():
		return defender_support_validation

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

	var preview: ActionResult = AttackPreviewQuery.new().preview_target_cell(board, actor_id, target_cell, weapon)
	if preview.is_error():
		return _invalid(StringName(str(preview.metadata.get("reason", "invalid_target"))), preview.metadata)
	return ActionResult.ok([], preview.metadata)


func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var context: TacticalActionContext = state as TacticalActionContext
	var board: BoardState = context.board
	var actor: TacticalEntityState = board.get_entity(actor_id)
	var target_entity_id: StringName = StringName(str(validation.metadata.get("target_entity_id", "")))
	var target: TacticalEntityState = board.get_entity(target_entity_id)
	if actor == null or target == null:
		return _invalid(&"invalid_context")

	var preview_metadata: Dictionary = validation.metadata.duplicate(true)
	var base_damage: int = int(preview_metadata.get("expected_base_damage", 0))
	var support_bonus_damage: int = _support_bonus_damage()
	var damage_before_defense: int = base_damage + support_bonus_damage
	var armor_reduction: int = _armor_reduction(damage_before_defense)
	var post_armor_damage: int = max(0, damage_before_defense - armor_reduction)
	var block_succeeded: bool = false
	var rng_draws: Array[Dictionary] = []

	if _support_id(defender_support) == SupportDefinition.SUPPORT_SHIELD:
		var block_result: ActionResult = context.rng_streams.rand_float(
			RngStreamSet.STREAM_COMBAT,
			{
				"command": "attack",
				"effect_id": "shield_block",
				"actor_id": String(actor_id),
				"target_entity_id": String(target_entity_id)
			}
		)
		if block_result.is_error():
			return block_result
		block_succeeded = float(block_result.metadata.get("value", 1.0)) <= defender_support.block_chance
		rng_draws.append(_combat_draw_metadata(
			block_result.metadata,
			&"shield_block",
			defender_support.block_chance,
			block_succeeded
		))

	var final_damage: int = post_armor_damage
	if block_succeeded:
		final_damage = int(floor(float(post_armor_damage) * 0.5))
	final_damage = max(1, final_damage)

	var hp_before: int = target.current_hp
	var hp_after: int = max(0, hp_before - final_damage)
	var next_sequence_id: int = board.next_sequence_id()
	var events: Array[DomainEvent] = []
	events.append(DomainEvent.entity_attacked(
		next_sequence_id,
		actor_id,
		target_entity_id,
		target_cell,
		weapon.weapon_id,
		_attack_event_payload(preview_metadata)
	))
	events.append(DomainEvent.damage_applied(
		next_sequence_id + events.size(),
		actor_id,
		target_entity_id,
		final_damage,
		hp_before,
		hp_after,
		target.max_hp,
		_damage_event_payload(
			base_damage,
			support_bonus_damage,
			armor_reduction,
			block_succeeded,
			rng_draws,
			final_damage
		)
	))

	var target_survives: bool = hp_after > 0
	if target_survives:
		_append_proc_events(context, target_entity_id, events, rng_draws)
		_append_knockback_event(board, actor, target, events, preview_metadata)

	var apply_result: ActionResult = board.apply_events(events)
	if apply_result.is_error():
		return apply_result

	var metadata: Dictionary = preview_metadata.duplicate(true)
	metadata["advances_turn"] = true
	metadata["attacker_support_id"] = String(_support_id(attacker_support))
	metadata["defender_support_id"] = String(_support_id(defender_support))
	metadata["base_damage"] = base_damage
	metadata["support_bonus_damage"] = support_bonus_damage
	metadata["armor_reduction"] = armor_reduction
	metadata["block_succeeded"] = block_succeeded
	metadata["final_damage"] = final_damage
	metadata["damage_type"] = String(DAMAGE_TYPE_PHYSICAL)
	metadata["rng_draws"] = rng_draws.duplicate(true)
	if not metadata.has("knockback_succeeded") and weapon.weapon_id == &"crossbow":
		metadata["knockback_succeeded"] = false
		metadata["knockback_blocked_reason"] = "target_defeated" if not target_survives else "not_attempted"
	return ActionResult.ok(events, metadata)


func _append_proc_events(
	context: TacticalActionContext,
	target_entity_id: StringName,
	events: Array[DomainEvent],
	rng_draws: Array[Dictionary]
) -> void:
	var effect_id: StringName = &""
	match weapon.weapon_id:
		&"axe":
			effect_id = &"bleed"
		&"mace":
			effect_id = &"disorient"
		_:
			return

	var roll_result: ActionResult = context.rng_streams.rand_float(
		RngStreamSet.STREAM_COMBAT,
		{
			"command": "attack",
			"effect_id": String(effect_id),
			"actor_id": String(actor_id),
			"target_entity_id": String(target_entity_id)
		}
	)
	if roll_result.is_error():
		return

	var succeeded: bool = float(roll_result.metadata.get("value", 1.0)) <= PROC_THRESHOLD
	var draw_metadata: Dictionary = _combat_draw_metadata(roll_result.metadata, effect_id, PROC_THRESHOLD, succeeded)
	rng_draws.append(draw_metadata)
	if not succeeded:
		return

	events.append(DomainEvent.status_effect_applied(
		context.board.next_sequence_id() + events.size(),
		actor_id,
		target_entity_id,
		effect_id,
		{
			"weapon_id": String(weapon.weapon_id),
			"rng_draw": draw_metadata
		}
	))


func _append_knockback_event(
	board: BoardState,
	actor: TacticalEntityState,
	target: TacticalEntityState,
	events: Array[DomainEvent],
	preview_metadata: Dictionary
) -> void:
	if weapon.weapon_id != &"crossbow":
		return

	var step: Vector2i = _knockback_step(actor.position, target.position)
	var destination: Vector2i = target.position + step
	if board == null:
		preview_metadata["knockback_succeeded"] = false
		preview_metadata["knockback_blocked_reason"] = "invalid_board"
		return

	var occupy_result: ActionResult = board.can_occupy(destination, target.entity_id)
	if occupy_result.is_error():
		preview_metadata["knockback_succeeded"] = false
		preview_metadata["knockback_destination"] = _cell_metadata(destination)
		preview_metadata["knockback_blocked_reason"] = _knockback_reason(occupy_result)
		return

	preview_metadata["knockback_succeeded"] = true
	preview_metadata["knockback_destination"] = _cell_metadata(destination)
	events.append(DomainEvent.entity_knocked_back(
		board.next_sequence_id() + events.size(),
		actor_id,
		target.entity_id,
		target.position,
		destination,
		weapon.weapon_id,
		{"source_cell": _cell_metadata(actor.position)}
	))


func _validate_weapon() -> ActionResult:
	if weapon == null:
		return _invalid(&"invalid_weapon")
	var validation: ActionResult = weapon.validate()
	if validation.is_error():
		return _invalid(&"invalid_weapon", {
			"weapon_id": String(weapon.weapon_id),
			"source_error_code": String(validation.error_code),
			"source_metadata": validation.metadata.duplicate(true)
		})
	return ActionResult.ok()


func _validate_support(support: SupportDefinition, field_name: StringName) -> ActionResult:
	if support == null:
		return ActionResult.ok()
	var validation: ActionResult = support.validate()
	if validation.is_error():
		return _invalid(&"invalid_support", {
			"field": String(field_name),
			"support_id": String(support.support_id),
			"source_error_code": String(validation.error_code),
			"source_metadata": validation.metadata.duplicate(true)
		})
	return ActionResult.ok()


func _support_bonus_damage() -> int:
	if attacker_support == null:
		return 0
	if attacker_support.supports_bonus_for_weapon(weapon.weapon_id):
		return attacker_support.bonus_damage
	return 0


func _armor_reduction(damage_before_defense: int) -> int:
	if defender_support == null:
		return 0
	return min(defender_support.armor, max(0, damage_before_defense))


func _support_id(support: SupportDefinition) -> StringName:
	if support == null:
		return SupportDefinition.SUPPORT_NONE
	return support.support_id


func _attack_event_payload(preview_metadata: Dictionary) -> Dictionary:
	return {
		"actor_id": String(actor_id),
		"expected_base_damage": int(preview_metadata.get("expected_base_damage", 0)),
		"range": int(preview_metadata.get("range", 0)),
		"distance": int(preview_metadata.get("distance", 0)),
		"line_cells": preview_metadata.get("line_cells", []).duplicate(true),
		"blocker_cells": preview_metadata.get("blocker_cells", []).duplicate(true),
		"blocker_ignored": bool(preview_metadata.get("blocker_ignored", false)),
		"warnings": preview_metadata.get("warnings", []).duplicate(true),
		"effects": preview_metadata.get("effects", []).duplicate(true),
		"explanation": String(preview_metadata.get("explanation", ""))
	}


func _damage_event_payload(
	base_damage: int,
	support_bonus_damage: int,
	armor_reduction: int,
	block_succeeded: bool,
	rng_draws: Array[Dictionary],
	final_damage: int
) -> Dictionary:
	return {
		"weapon_id": String(weapon.weapon_id),
		"attacker_support_id": String(_support_id(attacker_support)),
		"defender_support_id": String(_support_id(defender_support)),
		"base_damage": base_damage,
		"support_bonus_damage": support_bonus_damage,
		"armor_reduction": armor_reduction,
		"block_succeeded": block_succeeded,
		"final_damage": final_damage,
		"damage_type": String(DAMAGE_TYPE_PHYSICAL),
		"rng_draws": rng_draws.duplicate(true)
	}


func _combat_draw_metadata(
	rng_metadata: Dictionary,
	effect_id: StringName,
	threshold: float,
	succeeded: bool
) -> Dictionary:
	return {
		"stream_name": String(RngStreamSet.STREAM_COMBAT),
		"draw_index": int(rng_metadata.get("draw_index", -1)),
		"roll_value": float(rng_metadata.get("value", 1.0)),
		"threshold": threshold,
		"effect_id": String(effect_id),
		"succeeded": succeeded
	}


func _knockback_step(origin: Vector2i, target: Vector2i) -> Vector2i:
	var delta: Vector2i = target - origin
	return Vector2i(_sign(delta.x), _sign(delta.y))


func _knockback_reason(result_value: ActionResult) -> String:
	if result_value.error_code == &"cell_out_of_bounds":
		return "out_of_bounds"
	if result_value.error_code == &"cell_occupied":
		return "occupied"
	return "blocked"


func _sign(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 0


func _cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_attack", result_metadata)
