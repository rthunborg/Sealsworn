class_name EnemyTurnResolver
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AiDecision = preload("res://scripts/ai/ai_decision.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyCommandAdapter = preload("res://scripts/tactical/turns/enemy_command_adapter.gd")
const EnemyDefinition = preload("res://scripts/content/definitions/enemy_definition.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const PendingTelegraphState = preload("res://scripts/tactical/turns/pending_telegraph_state.gd")
const PrototypeEnemyAi = preload("res://scripts/ai/prototype_enemy_ai.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

var _enemy_repository: EnemyRepository = null
var _player_id: StringName = &"hero"
var _ai: PrototypeEnemyAi = null
var _adapter: EnemyCommandAdapter = null
# Story 12.2 (AC3 — the hero-defense seam): the seated player's loadout defender support (the class off-hand). When a
# shield, an enemy attack against the player engages the SAME seeded AttackCommand.roll_shield_block on the `combat`
# stream — the shield protects its OWNER. Null (the default) is the neutral no-defense case (byte-identical enemy phase).
var _player_defender_support: SupportDefinition = null

func _init(
	new_enemy_repository: EnemyRepository = null,
	new_player_id: StringName = &"hero",
	new_player_defender_support: SupportDefinition = null
) -> void:
	_enemy_repository = new_enemy_repository
	_player_id = new_player_id
	_player_defender_support = new_player_defender_support
	_ai = PrototypeEnemyAi.new(_enemy_repository)
	_adapter = EnemyCommandAdapter.new(new_player_id, new_player_defender_support)


func resolve_after_player_action(
	context: TacticalActionContext,
	player_result: ActionResult
) -> ActionResult:
	if context == null or not context.has_required_state():
		return _invalid(&"invalid_context")
	if player_result == null:
		return _no_resolution(&"missing_player_result")
	if player_result.is_error():
		return _no_resolution(&"player_command_failed")
	if not bool(player_result.metadata.get("advances_turn", false)):
		return _no_resolution(&"player_command_did_not_advance_turn")

	var previous_active_actor_id: StringName = context.turn_state.active_actor_id
	var resolved_player_id: StringName = _player_id
	if resolved_player_id == &"":
		resolved_player_id = previous_active_actor_id
	if context.turn_state.phase != TacticalTurnState.Phase.PLAYER_PLANNING:
		return _invalid(&"invalid_turn_phase", {
			"phase": String(TacticalTurnState.id_for_phase(context.turn_state.phase))
		})
	if resolved_player_id == &"" or previous_active_actor_id != resolved_player_id:
		return _invalid(&"invalid_active_actor", {
			"expected_actor_id": String(resolved_player_id),
			"actual_actor_id": String(previous_active_actor_id)
		})
	if _player_id == &"":
		_player_id = resolved_player_id

	var simulation_context: TacticalActionContext = _copy_context_for_simulation(context)
	if simulation_context == null:
		return _invalid(&"invalid_context_copy")
	var simulation_result: ActionResult = _resolve_enemy_phase_on_context(simulation_context, resolved_player_id)
	if simulation_result.is_error():
		return simulation_result

	var events: Array[DomainEvent] = simulation_result.events
	var pending_validation: ActionResult = PendingTelegraphState.validate_events(context.pending_telegraphs, events)
	if pending_validation.is_error():
		return pending_validation
	var apply_result: ActionResult = context.board.apply_events(events)
	if apply_result.is_error():
		return apply_result
	var pending_result: ActionResult = PendingTelegraphState.apply_events(context.pending_telegraphs, events)
	if pending_result.is_error():
		return pending_result

	# Story 12.2 (AC3 — the hero-defense seam): sync the simulation streams back to the run-level context. The enemy phase
	# draws RNG ONLY when a shielded hero is attacked (AttackCommand.roll_shield_block on the `combat` stream, on the
	# simulation copy). Restoring the copy's advanced state makes that a REAL, seeded, reproducible run-level `combat` draw
	# (never a throwaway simulation draw). When NO draw happened (the neutral no-shield enemy phase — every pre-12.2 caller,
	# the auto-resolve driver, the boss path) the copy is byte-identical to the original snapshot, so this restore is a
	# no-op and the run-level streams stay byte-identical.
	var streams_sync: ActionResult = context.rng_streams.try_restore(simulation_context.rng_streams.to_snapshot())
	if streams_sync.is_error():
		return _invalid(&"invalid_stream_sync", {"inner_error_code": String(streams_sync.error_code)})

	context.turn_state.turn_number = simulation_context.turn_state.turn_number
	context.turn_state.phase = simulation_context.turn_state.phase
	context.turn_state.active_actor_id = simulation_context.turn_state.active_actor_id
	return simulation_result


func _resolve_enemy_phase_on_context(context: TacticalActionContext, player_id: StringName) -> ActionResult:
	var board: BoardState = context.board

	var events: Array[DomainEvent] = []
	var decisions: Array[Dictionary] = []
	context.turn_state.phase = TacticalTurnState.Phase.ENEMY_PLANNING
	context.turn_state.active_actor_id = &""

	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY:
			continue
		if entity.is_dead():
			continue

		context.turn_state.phase = TacticalTurnState.Phase.ENEMY_RESOLVING
		context.turn_state.active_actor_id = entity.entity_id

		var decision: AiDecision = _ai.decide(
			board,
			entity,
			player_id,
			context.pending_telegraphs,
			context.turn_state.turn_number
		)
		var definition: EnemyDefinition = null
		if _enemy_repository != null:
			definition = _enemy_repository.get_enemy(entity.definition_id)
		var apply_result: ActionResult = _adapter.apply_decision(context, decision, definition)
		if apply_result.is_error():
			return apply_result
		for event: DomainEvent in apply_result.events:
			events.append(event)
		decisions.append(decision.to_dictionary())

	context.turn_state.turn_number += 1
	context.turn_state.phase = TacticalTurnState.Phase.PLAYER_PLANNING
	context.turn_state.active_actor_id = player_id
	return ActionResult.ok(events, {
		"resolved": true,
		"decisions": decisions,
		"enemy_count": decisions.size()
	})


func _copy_context_for_simulation(context: TacticalActionContext) -> TacticalActionContext:
	var board_result: ActionResult = BoardState.try_from_snapshot(context.board.to_snapshot())
	if board_result.is_error():
		return null
	var board_copy: BoardState = board_result.metadata.get("board") as BoardState

	var streams_copy: RngStreamSet = RngStreamSet.new(0)
	var streams_result: ActionResult = streams_copy.try_restore(context.rng_streams.to_snapshot())
	if streams_result.is_error():
		return null

	return TacticalActionContext.new(
		board_copy,
		context.turn_state.copy(),
		streams_copy,
		context.pending_telegraphs.duplicate(true)
	)


func _no_resolution(reason: StringName) -> ActionResult:
	return ActionResult.ok([], {
		"resolved": false,
		"reason": String(reason)
	})


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_enemy_turn_resolution", result_metadata)
