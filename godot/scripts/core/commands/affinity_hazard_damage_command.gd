class_name AffinityHazardDamageCommand
extends "res://scripts/core/commands/game_command.gd"

# Story 7.5 (AC1, Scorched) — the validated tactical-effect command that RESOLVES Scorched fire-hazard / burning-terrain
# DAMAGE-OVER-TIME pressure through the EXISTING DAMAGE_APPLIED domain event. It is the board-scoped effect PRODUCER for
# an entity standing in a Scorched HAZARD cell: given a built BoardState + the affected entity id, it applies a FIXED,
# DETERMINISTIC hazard amount and emits the proven attack-command damage event shape (hp_before / hp_after / amount /
# final_damage / damage_type / max_hp), floored at 0.
#
# [Decision] (the Scorched DoT model) — DIRECT DAMAGE_APPLIED on occupancy (NOT a telegraphed TILE_MARKED ->
# MARKED_TILE_DETONATED pulse): the simplest, reuses the proven damage event end-to-end, and is fairness-testable. The
# hazard amount is a FIXED v0 constant (NO RNG roll — the AC2 determinism + the named-RNG "prefer a deterministic
# no-roll v0" guidance; if a future tuning pass rolls a variable amount it MUST draw the existing `combat` stream, never
# randi/randf). The amount is authored, bounded tactical CONTENT — NOT a hidden difficulty multiplier (difficulty is a
# hard non-goal).
#
# THE HAZARD-DAMAGE ACTOR ([Decision]): the affected entity is BOTH actor AND target — the entity is burned by the
# hazard cell it OCCUPIES (there is no separate "attacker"; a fire hazard is an environmental DoT). The board's
# DAMAGE_APPLIED validator requires a non-empty actor_id that resolves to a live board entity, which actor==target
# satisfies. damage_type is `burning` (a Scorched-specific marker; the CombatExplanationLog reads it into a "took N
# burning damage from <entity>" line).
#
# FAIRNESS (the GDD + the 3.6 safe-first-reveal spirit): a Scorched hazard is FAIR by construction — HAZARD is
# board-valid, WALKABLE, sight-TRANSPARENT (the 3.4 contract; only WALL blocks occupancy/LOS), so the player can SEE the
# hazard cell (it is previewable via AffinityPreviewQuery) and CHOOSES whether to enter. This command only RESOLVES the
# DoT for an entity already in a hazard cell; it never places unavoidable damage from an unseen position (that fairness
# discipline is enforced by construction here; Darkness's guardrail is 7.6's).
#
# THE RUN/TACTICAL COMMAND IDIOM (game_command.gd; the CreateBoardCommand / AttackCommand model): validate-then-mutate,
# ZERO partial state + ZERO events on reject, build the event AFTER the HP arithmetic, ZERO RNG. It takes a BoardState
# DIRECTLY (a board operation, like CreateBoardCommand — NOT a TacticalActionContext player-turn action; there is no
# turn-state phase to gate, since a hazard tick is environmental, not a planned player action). The sequence id is
# derived from board.next_sequence_id() (the board-command convention).

const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

# The Scorched hazard DoT damage_type marker (a lower_snake id the explanation log reads).
const DAMAGE_TYPE_BURNING := &"burning"

# The hazard SOURCE marker (lower_snake) — there is no weapon; this names the Scorched fire-hazard as the damage source
# in the DAMAGE_APPLIED payload's required `weapon_id` field (kept round-trip-safe against the strict payload validator).
const HAZARD_SOURCE_ID := &"scorched_hazard"

# The fixed v0 Scorched hazard-tick amount (authored, bounded content — NOT a difficulty scalar; NO RNG). A single tick
# of standing in a Scorched fire-hazard cell. Kept a small constant so the effect is deterministic + fairness-testable.
const DEFAULT_HAZARD_AMOUNT: int = 2

var target_entity_id: StringName = &""
var hazard_amount: int = DEFAULT_HAZARD_AMOUNT

func _init(new_target_entity_id: StringName = &"", new_hazard_amount: int = DEFAULT_HAZARD_AMOUNT) -> void:
	command_id = &"affinity_hazard_damage"
	target_entity_id = new_target_entity_id
	hazard_amount = new_hazard_amount


func validate(state: Variant) -> ActionResult:
	if not state is BoardState:
		return _invalid(&"invalid_state_type")

	var board: BoardState = state as BoardState
	if not board.has_cells():
		return _invalid(&"board_not_created")
	if hazard_amount <= 0:
		return _invalid(&"invalid_hazard_amount", {"hazard_amount": hazard_amount})
	if target_entity_id == &"":
		return _invalid(&"invalid_target", {"target_entity_id": String(target_entity_id)})

	var target: TacticalEntityState = board.get_entity(target_entity_id)
	if target == null:
		return _invalid(&"missing_target", {"target_entity_id": String(target_entity_id)})
	if target.is_dead():
		return _invalid(&"dead_target", {"target_entity_id": String(target_entity_id)})

	var occupied_cell: BoardCell = board.get_cell(target.position)
	if occupied_cell == null:
		return _invalid(&"target_off_board", {"target_entity_id": String(target_entity_id)})
	if occupied_cell.terrain != BoardCell.Terrain.HAZARD:
		return _invalid(&"target_not_in_hazard", {
			"target_entity_id": String(target_entity_id),
			"x": target.position.x,
			"y": target.position.y,
			"terrain": occupied_cell.terrain
		})

	return ActionResult.ok([], {
		"target_entity_id": String(target_entity_id),
		"hazard_cell": _cell_metadata(target.position),
		"hazard_amount": hazard_amount
	})


func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var board: BoardState = state as BoardState
	var target: TacticalEntityState = board.get_entity(target_entity_id)
	if target == null:
		return _invalid(&"missing_target", {"target_entity_id": String(target_entity_id)})

	var hp_before: int = target.current_hp
	var final_damage: int = hazard_amount
	var hp_after: int = max(0, hp_before - final_damage)

	# Build the DAMAGE_APPLIED event AFTER the HP arithmetic (the validate-then-mutate idiom). actor == target: the
	# entity is harmed by the hazard cell it occupies (an environmental DoT, not an attacker's strike). The payload
	# carries the FULL damage-event field set so the event passes BOTH the board's in-memory apply_events validator AND
	# the strict DomainEvent.try_from_dictionary payload validator (round-trip-safe — the attack-command shape:
	# weapon_id / base_damage / support_bonus_damage / armor_reduction / block_succeeded / damage_type / rng_draws). The
	# `weapon_id` marker names the hazard SOURCE (scorched_hazard) — there is no weapon; rng_draws is EMPTY (ZERO RNG).
	var event: DomainEvent = DomainEvent.damage_applied(
		board.next_sequence_id(),
		target_entity_id,
		target_entity_id,
		final_damage,
		hp_before,
		hp_after,
		target.max_hp,
		{
			"weapon_id": String(HAZARD_SOURCE_ID),
			"base_damage": final_damage,
			"support_bonus_damage": 0,
			"armor_reduction": 0,
			"block_succeeded": false,
			"damage_type": String(DAMAGE_TYPE_BURNING),
			"rng_draws": [],
			"source": String(HAZARD_SOURCE_ID),
			"hazard_cell": _cell_metadata(target.position)
		}
	)

	var apply_result: ActionResult = board.apply_events([event])
	if apply_result.is_error():
		return apply_result

	return ActionResult.ok([event], {
		"target_entity_id": String(target_entity_id),
		"hazard_cell": _cell_metadata(target.position),
		"hp_before": hp_before,
		"hp_after": hp_after,
		"final_damage": final_damage,
		"damage_type": String(DAMAGE_TYPE_BURNING),
		"target_survives": hp_after > 0
	})


func _cell_metadata(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_affinity_hazard_damage", result_metadata)
