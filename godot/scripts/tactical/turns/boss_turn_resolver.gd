class_name BossTurnResolver
extends RefCounted

# The Larval Avatar boss TURN driver + the LIVE phase re-resolution seam (Story 9.3, FR63, AC2/AC3; closes 9.2 review
# Low #1). It is the boss analogue of EnemyTurnResolver: on the boss's turn it runs the BossAi -> the BossCommandAdapter
# on a SIMULATION COPY of the context (the _copy_context_for_simulation discipline — resolve on the copy, validate the
# events against PendingTelegraphState, apply to the real board, then apply to the real pending telegraphs, then sync
# the turn state). The boss NEVER mutates the board/entity/turn state directly — every change flows through
# board.apply_events (AC2).
#
# THE LIVE PHASE SEAM (closing 9.2 Low #1): after the boss's HP CHANGES (in 9.3 the damage-TO-the-boss source is the
# player/test, applied to the board before this call), resolve_phase_transitions() calls 9.2's BossPhaseResolver.resolve
# live and emits ONE boss_phase_changed DomainEvent per returned transition (from each transition.to_payload()). Those
# are SYSTEM events (no actor, no board mutation — board.apply_events would reject them), so they are appended to the
# returned event stream / log, NOT applied to the board. The boss's current_phase_index is RECOMPUTED from HP (no stored
# phase state — the 23-key RunSnapshot gate stays 23).
#
# LIVE-LOOP BOUNDARY (recorded, Story 9.3 scope): this driver resolves the boss's turn behavior driven by EXPLICIT test
# turns. It does NOT auto-wire the boss fight into run_to_completion, does NOT auto-play the encounter to victory/death,
# and does NOT add a player-death -> PHASE_FAILED or a boss-defeat -> run-victory call site (that + the victory reveal
# is Story 9.4). Dropping the boss to 0 HP in a test is a tactical death of the entity, not the run-victory wiring.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AiDecision = preload("res://scripts/ai/ai_decision.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossAi = preload("res://scripts/ai/boss_ai.gd")
const BossCommandAdapter = preload("res://scripts/tactical/turns/boss_command_adapter.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossPhaseResolver = preload("res://scripts/content/boss/boss_phase_resolver.gd")
const BossPhaseTransition = preload("res://scripts/content/boss/boss_phase_transition.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PendingTelegraphState = preload("res://scripts/tactical/turns/pending_telegraph_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

var _boss_definition: BossDefinition = null
var _boss_entity_id: StringName = &"larval_avatar"
var _player_id: StringName = &"hero"
var _ai: BossAi = BossAi.new()
var _adapter: BossCommandAdapter = BossCommandAdapter.new()
var _phase_resolver: BossPhaseResolver = BossPhaseResolver.new()

func _init(
	new_boss_definition: BossDefinition = null,
	new_boss_entity_id: StringName = &"larval_avatar",
	new_player_id: StringName = &"hero"
) -> void:
	_boss_definition = new_boss_definition
	_boss_entity_id = new_boss_entity_id
	_player_id = new_player_id


# Resolve the boss's turn: BossAi -> BossCommandAdapter on a SIMULATION copy, validate against PendingTelegraphState,
# apply to the real board + pending telegraphs, then sync the turn state. Returns the boss action's events + the decision
# in metadata. Mirrors EnemyTurnResolver.resolve_after_player_action's simulate-then-apply discipline (single boss
# entity, driven by an explicit test turn — no player-result gate).
func resolve_boss_turn(context: TacticalActionContext) -> ActionResult:
	if context == null or not context.has_required_state():
		return _invalid(&"invalid_context")
	if _boss_definition == null:
		return _invalid(&"missing_boss_definition")

	var boss: TacticalEntityState = context.board.get_entity(_boss_entity_id)
	if boss == null:
		return _invalid(&"missing_boss_entity", {"boss_entity_id": String(_boss_entity_id)})

	var simulation_context: TacticalActionContext = _copy_context_for_simulation(context)
	if simulation_context == null:
		return _invalid(&"invalid_context_copy")

	simulation_context.turn_state.phase = TacticalTurnState.Phase.ENEMY_RESOLVING
	simulation_context.turn_state.active_actor_id = boss.entity_id

	var decision: AiDecision = _ai.decide(
		simulation_context.board,
		boss,
		_player_id,
		simulation_context.pending_telegraphs,
		simulation_context.turn_state.turn_number,
		_boss_definition
	)
	var adapter_result: ActionResult = _adapter.apply_decision(simulation_context, decision, _boss_definition)
	if adapter_result.is_error():
		return adapter_result

	var events: Array[DomainEvent] = adapter_result.events
	var pending_validation: ActionResult = PendingTelegraphState.validate_events(context.pending_telegraphs, events)
	if pending_validation.is_error():
		return pending_validation
	var apply_result: ActionResult = context.board.apply_events(events)
	if apply_result.is_error():
		return apply_result
	var pending_result: ActionResult = PendingTelegraphState.apply_events(context.pending_telegraphs, events)
	if pending_result.is_error():
		return pending_result

	# Advance to the next turn and return control to the player (the enemy-turn convention). Driven by an explicit test
	# turn — no auto-loop.
	context.turn_state.turn_number += 1
	context.turn_state.phase = TacticalTurnState.Phase.PLAYER_PLANNING
	context.turn_state.active_actor_id = _player_id
	return ActionResult.ok(events, {
		"resolved": true,
		"decision": decision.to_dictionary(),
		"active_phase_index": int(decision.metadata.get("active_phase_index", _active_phase_index(boss.current_hp)))
	})


# The LIVE phase re-resolution seam (closing 9.2 Low #1): after the boss's HP changes (player/test damage already
# applied to the board), re-resolve the phase from the boss's CURRENT HP and emit ONE boss_phase_changed event per
# returned transition (from each transition.to_payload()). `previous_phase_index` is the boss's phase BEFORE the HP
# change (the caller tracks it, or passes the recomputed pre-damage phase). The boss_phase_changed events are SYSTEM
# events (no board mutation) — they are returned in the event stream / log, NOT board-applied. Returns the events +
# the new active phase index + `next_sequence_id_after` (the first free id past this step) in metadata. PURE over the
# resolver (ZERO RNG).
#
# SEQUENCE-ID SEAM CONTRACT (Story 9.3 review Round 1, Med finding — addresses the 9.4 stream-merge seam): these
# boss_phase_changed events are system events that this method does NOT board-apply, so `context.board`'s
# `_next_sequence_id` is NOT advanced by them (only `apply_events` advances it). Within 9.3 the ids are
# log-ordering-only and benign. BUT a caller (Story 9.4's run-to-completion loop) that INTERLEAVES these
# phase-change events with board-applied action events into ONE ordered append-only log MUST reserve the id range:
# pass an explicit `sequence_id_base` (>= 0) that does not collide with any id a board-applied event will consume,
# and use the returned `next_sequence_id_after` as the reserved cursor for whatever it appends next. When
# `sequence_id_base < 0` (the 9.3 default) the base falls back to `context.board.next_sequence_id()` — correct for
# 9.3's non-interleaved, driven-by-explicit-test-turns usage, but a caller that merges streams MUST NOT rely on
# that fallback.
func resolve_phase_transitions(
	context: TacticalActionContext,
	previous_phase_index: int,
	sequence_id_base: int = -1
) -> ActionResult:
	if context == null or not context.has_required_state():
		return _invalid(&"invalid_context")
	if _boss_definition == null:
		return _invalid(&"missing_boss_definition")

	var boss: TacticalEntityState = context.board.get_entity(_boss_entity_id)
	if boss == null:
		return _invalid(&"missing_boss_entity", {"boss_entity_id": String(_boss_entity_id)})

	var transitions: Array[BossPhaseTransition] = _phase_resolver.resolve(_boss_definition, previous_phase_index, boss.current_hp)
	var events: Array[DomainEvent] = []
	# The boss_phase_changed events are system events (not board-applied); sequence them monotonically from the
	# caller-reserved base (>= 0) when interleaving streams, else from the board's current next sequence id. See the
	# SEQUENCE-ID SEAM CONTRACT above.
	var sequence_id: int = sequence_id_base if sequence_id_base >= 0 else context.board.next_sequence_id()
	for transition: BossPhaseTransition in transitions:
		var event: DomainEvent = DomainEvent.boss_phase_changed(sequence_id, transition.to_payload())
		events.append(event)
		sequence_id += 1

	return ActionResult.ok(events, {
		"transition_count": transitions.size(),
		"previous_phase_index": previous_phase_index,
		"active_phase_index": _active_phase_index(boss.current_hp),
		# The first free sequence id past this step — a stream-merging caller uses this as its reserved cursor.
		"next_sequence_id_after": sequence_id
	})


# Recompute the boss's active phase index for a given HP (no stored phase state — the RECOMMENDED posture).
func active_phase_index_for_hp(current_hp: int) -> int:
	return _active_phase_index(current_hp)


func _active_phase_index(current_hp: int) -> int:
	return _phase_resolver.active_phase_index(_boss_definition, current_hp)


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


func _invalid(reason: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"reason": String(reason)}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(&"invalid_boss_turn_resolution", result_metadata)
