extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AiDecision = preload("res://scripts/ai/ai_decision.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyCommandAdapter = preload("res://scripts/tactical/turns/enemy_command_adapter.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const EnemyTurnResolver = preload("res://scripts/tactical/turns/enemy_turn_resolver.gd")
const PendingTelegraphState = preload("res://scripts/tactical/turns/pending_telegraph_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

func run() -> Dictionary:
	_invalid_player_result_does_not_resolve_or_mutate()
	_success_without_advancing_turn_does_not_resolve_or_mutate()
	_resolver_rejects_non_player_phase_without_mutation()
	_enemy_resolution_sequences_alive_enemies_in_stable_order()
	_adjacent_iron_cultist_attacks_through_domain_events()
	_iron_cultist_approaches_one_legal_cardinal_step()
	_gate_brute_blocks_occupancy_and_cannot_overlap()
	_missing_enemy_definition_waits_with_serializable_event()
	_enemy_move_adapter_rejects_non_cardinal_teleport()
	_ash_seer_marks_without_immediate_damage()
	_ash_seer_due_mark_detonates_or_expires_deterministically()
	_ash_seer_detonation_rejects_invalid_pending_marks_without_mutation()
	_enemy_events_replay_pending_telegraph_state()
	_blocked_enemy_waits_without_board_rng_or_pending_mutation()
	_same_seed_resolution_reproduces_events_pending_state_and_explanations()
	return result()


func _invalid_player_result_does_not_resolve_or_mutate() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_adjacent_melee()
	var streams: RngStreamSet = RngStreamSet.new(100)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var pending: Array[Dictionary] = []
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending)
	var before: Dictionary = _snapshot_dictionary(board, streams, turn_state, pending, [])

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, ActionResult.error(&"invalid_movement"))

	assert_true(result_value.succeeded, "Resolver should no-op after invalid player commands.")
	assert_equal(result_value.events.size(), 0, "Invalid player commands should not emit enemy events.")
	assert_equal(result_value.metadata.get("resolved"), false, "Resolver metadata should record no enemy phase.")
	assert_equal(_snapshot_dictionary(board, streams, turn_state, pending, []), before, "Invalid player commands must not mutate board, turn, RNG, or pending telegraphs.")


func _success_without_advancing_turn_does_not_resolve_or_mutate() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_adjacent_melee()
	var streams: RngStreamSet = RngStreamSet.new(101)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var pending: Array[Dictionary] = []
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending)
	var before: Dictionary = _snapshot_dictionary(board, streams, turn_state, pending, [])

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, ActionResult.ok([], {"advances_turn": false}))

	assert_true(result_value.succeeded, "Resolver should no-op after successful commands that do not advance turn.")
	assert_equal(result_value.events.size(), 0, "Non-advancing player commands should not emit enemy events.")
	assert_equal(result_value.metadata.get("resolved"), false, "Resolver metadata should record no enemy phase.")
	assert_equal(_snapshot_dictionary(board, streams, turn_state, pending, []), before, "Non-advancing player commands must not mutate tactical state.")


func _resolver_rejects_non_player_phase_without_mutation() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_adjacent_melee()
	var streams: RngStreamSet = RngStreamSet.new(110)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.ENEMY_RESOLVING, &"enemy_iron")
	var pending: Array[Dictionary] = []
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending)
	var before: Dictionary = _snapshot_dictionary(board, streams, turn_state, pending, [])

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, _advancing_player_result())

	assert_true(result_value.is_error(), "Resolver should reject enemy-phase re-entry.")
	assert_equal(result_value.metadata.get("reason"), "invalid_turn_phase", "Resolver should explain invalid phase re-entry.")
	assert_equal(_snapshot_dictionary(board, streams, turn_state, pending, []), before, "Invalid phase should not mutate board, turn, RNG, or pending telegraphs.")


func _enemy_resolution_sequences_alive_enemies_in_stable_order() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_multiple_ordering()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(102), [])

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, _advancing_player_result())
	var decisions: Array = result_value.metadata.get("decisions", [])

	assert_true(result_value.succeeded, "Enemy resolution should succeed for ordered melee enemies.")
	assert_equal(decisions.size(), 2, "Each alive enemy should receive one opportunity.")
	assert_equal(decisions[0].get("enemy_id"), "enemy_a", "Enemy order should use sorted entity ids.")
	assert_equal(decisions[1].get("enemy_id"), "enemy_b", "Enemy order should be stable across runs.")
	assert_equal(context.turn_state.phase, TacticalTurnState.Phase.PLAYER_PLANNING, "Enemy phase should return to player planning.")
	assert_equal(context.turn_state.active_actor_id, &"hero", "Enemy phase should restore the player as active actor.")


func _adjacent_iron_cultist_attacks_through_domain_events() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_adjacent_melee()
	var streams: RngStreamSet = RngStreamSet.new(103)
	var before_rng: Dictionary = streams.to_snapshot()
	var context: TacticalActionContext = _context(board, streams, [])

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, _advancing_player_result())
	var attack_event: DomainEvent = result_value.events[0]
	var damage_event: DomainEvent = result_value.events[1]

	assert_true(result_value.succeeded, "Adjacent Iron Cultist resolution should succeed.")
	assert_equal(result_value.events.size(), 2, "Adjacent melee should emit attack and damage events.")
	assert_equal(attack_event.event_type, DomainEvent.Type.ENTITY_ATTACKED, "Enemy attack should reuse domain attack events.")
	assert_equal(attack_event.actor_id, &"enemy_iron", "Enemy attack event should identify the enemy actor.")
	assert_equal(attack_event.payload.get("weapon_id"), "iron_cultist_melee", "Enemy attack should use a stable lower-snake source id.")
	assert_equal(damage_event.event_type, DomainEvent.Type.DAMAGE_APPLIED, "Enemy attack should apply deterministic damage.")
	assert_equal(damage_event.payload.get("amount"), 3, "Iron Cultist melee should deal 3 physical damage.")
	assert_equal(damage_event.payload.get("damage_type"), "physical", "Enemy damage should record physical damage metadata.")
	assert_equal(board.get_entity(&"hero").current_hp, 15, "Enemy damage should mutate HP only through BoardState events.")
	assert_equal(streams.to_snapshot(), before_rng, "Prototype enemy resolution must not consume RNG.")


func _iron_cultist_approaches_one_legal_cardinal_step() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_approach()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(104), [])

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, _advancing_player_result())

	assert_true(result_value.succeeded, "Iron Cultist approach should resolve.")
	assert_equal(result_value.events.size(), 1, "Approach should emit one movement event.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.ENTITY_MOVED, "Approach should use domain movement events.")
	assert_equal(board.get_entity(&"enemy_iron").position, Vector2i(3, 2), "Iron Cultist should move one cardinal step toward the player.")
	assert_equal(board.occupant_at(Vector2i(4, 2)), &"", "Approach should clear previous blocking occupancy.")
	assert_equal(board.occupant_at(Vector2i(3, 2)), &"enemy_iron", "Approach should set new blocking occupancy.")


func _gate_brute_blocks_occupancy_and_cannot_overlap() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_gate_brute_blocking()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(105), [])

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, _advancing_player_result())
	var decision: Dictionary = result_value.metadata.get("decisions", [])[0]

	assert_true(result_value.succeeded, "Blocked Gate Brute should resolve with a wait, not overlap.")
	assert_equal(board.get_entity(&"enemy_brute").max_hp, 12, "Gate Brute should have 12 HP in tactical state.")
	assert_equal(board.get_entity(&"enemy_brute").position, Vector2i(4, 2), "Gate Brute must not move into an occupied blocking cell.")
	assert_equal(board.occupant_at(Vector2i(3, 2)), &"enemy_blocker", "Existing blocker should remain in its cell.")
	assert_equal(decision.get("action_id"), "wait", "Blocked Gate Brute should wait.")
	assert_equal(decision.get("wait_reason"), "blocked", "Blocked Gate Brute wait should explain occupancy pressure.")


func _missing_enemy_definition_waits_with_serializable_event() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_missing_definition_id()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(111), [])

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, _advancing_player_result())
	var wait_event: DomainEvent = result_value.events[0]
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(wait_event.to_dictionary())

	assert_true(result_value.succeeded, "Missing enemy definitions should resolve as deterministic waits instead of corrupting enemy phase.")
	assert_equal(wait_event.event_type, DomainEvent.Type.ENEMY_WAITED, "Missing enemy definitions should emit a readable wait event.")
	assert_false(wait_event.payload.has("enemy_definition_id"), "Wait events should omit invalid empty definition ids.")
	assert_true(parse_result.succeeded, "Wait events emitted for missing definitions must remain serializable.")
	assert_equal(context.turn_state.phase, TacticalTurnState.Phase.PLAYER_PLANNING, "Missing definition fallback should still restore player planning.")


func _enemy_move_adapter_rejects_non_cardinal_teleport() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_approach()
	var streams: RngStreamSet = RngStreamSet.new(112)
	var pending: Array[Dictionary] = []
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.ENEMY_RESOLVING, &"enemy_iron")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending)
	var before: Dictionary = _snapshot_dictionary(board, streams, turn_state, pending, [])
	var decision: AiDecision = AiDecision.new(
		&"enemy_iron",
		&"iron_cultist",
		&"move",
		50,
		["malformed_move"],
		&"hero",
		Vector2i(4, 2),
		Vector2i(0, 0),
		Vector2i(1, 2),
		&"",
		{"action_id": "move"}
	)

	var result_value: ActionResult = EnemyCommandAdapter.new().apply_decision(
		context,
		decision,
		EnemyRepository.create_baseline_repository().get_enemy(&"iron_cultist")
	)

	assert_true(result_value.is_error(), "Enemy command adapter should reject non-cardinal teleport moves.")
	assert_equal(result_value.metadata.get("reason"), "invalid_move_step", "Teleport rejection should identify invalid movement step.")
	assert_equal(_snapshot_dictionary(board, streams, turn_state, pending, []), before, "Rejected adapter movement must not mutate tactical state.")


func _ash_seer_marks_without_immediate_damage() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_mark()
	var pending: Array[Dictionary] = []
	var context: TacticalActionContext = _context(board, RngStreamSet.new(106), pending)
	var hero_hp_before: int = board.get_entity(&"hero").current_hp

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, _advancing_player_result())

	assert_true(result_value.succeeded, "Ash Seer mark should resolve.")
	assert_equal(result_value.events.size(), 1, "Marking should emit one readable mark event.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.TILE_MARKED, "Ash Seer should emit a tile-marked event.")
	assert_equal(board.get_entity(&"hero").current_hp, hero_hp_before, "Ash Seer mark should not apply immediate damage.")
	assert_equal(pending.size(), 1, "Ash Seer mark should store one pending telegraph.")
	assert_equal(pending[0].get("kind"), "ash_seer_mark", "Pending telegraph should use a serializable stable kind.")
	assert_equal(pending[0].get("marked_cell"), {"x": 1, "y": 2}, "Pending mark should record the player's current tile.")


func _ash_seer_due_mark_detonates_or_expires_deterministically() -> void:
	var hit_board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_detonation_hit()
	var avoided_board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_detonation_avoided()
	var hit_pending: Array[Dictionary] = [_pending_mark(Vector2i(1, 2), 2)]
	var avoided_pending: Array[Dictionary] = [_pending_mark(Vector2i(1, 2), 2)]

	var hit_context: TacticalActionContext = _context(hit_board, RngStreamSet.new(107), hit_pending, 2)
	var avoided_context: TacticalActionContext = _context(avoided_board, RngStreamSet.new(107), avoided_pending, 2)
	var hit_result: ActionResult = _resolver().resolve_after_player_action(hit_context, _advancing_player_result())
	var avoided_result: ActionResult = _resolver().resolve_after_player_action(avoided_context, _advancing_player_result())

	assert_true(hit_result.succeeded, "Due Ash Seer hit mark should resolve.")
	assert_equal(hit_result.events[0].event_type, DomainEvent.Type.MARKED_TILE_DETONATED, "Due mark should emit detonation before damage.")
	assert_equal(hit_result.events[1].event_type, DomainEvent.Type.DAMAGE_APPLIED, "Player on marked cell should take detonation damage.")
	assert_equal(hit_board.get_entity(&"hero").current_hp, 14, "Ash Seer detonation should deal 4 physical damage.")
	assert_equal(hit_pending.size(), 0, "Resolved hit marks should be removed from pending telegraphs.")
	assert_true(avoided_result.succeeded, "Due Ash Seer avoided mark should resolve.")
	assert_equal(avoided_result.events.size(), 1, "Avoided detonation should emit no damage event.")
	assert_equal(avoided_result.events[0].payload.get("outcome"), "avoided", "Avoided detonation should record readable outcome.")
	assert_equal(avoided_board.get_entity(&"hero").current_hp, 18, "Avoided detonation should not damage the player.")
	assert_equal(avoided_pending.size(), 0, "Avoided marks should be removed from pending telegraphs.")


func _ash_seer_detonation_rejects_invalid_pending_marks_without_mutation() -> void:
	var repository: EnemyRepository = EnemyRepository.create_baseline_repository()
	var adapter: EnemyCommandAdapter = EnemyCommandAdapter.new()
	var early_pending: Array[Dictionary] = [_pending_mark(Vector2i(1, 2), 3)]
	var early_board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_detonation_hit()
	var early_streams: RngStreamSet = RngStreamSet.new(113)
	var early_turn_state: TacticalTurnState = TacticalTurnState.new(2, TacticalTurnState.Phase.ENEMY_RESOLVING, &"enemy_seer")
	var early_context: TacticalActionContext = TacticalActionContext.new(early_board, early_turn_state, early_streams, early_pending)
	var early_before: Dictionary = _snapshot_dictionary(early_board, early_streams, early_turn_state, early_pending, [])
	var early_decision: AiDecision = _detonation_decision(early_pending[0])

	var early_result: ActionResult = adapter.apply_decision(early_context, early_decision, repository.get_enemy(&"ash_seer"))

	assert_true(early_result.is_error(), "Ash Seer detonation should reject marks before their due turn.")
	assert_equal(early_result.metadata.get("reason"), "mark_not_due", "Early detonation should identify mark timing.")
	assert_equal(_snapshot_dictionary(early_board, early_streams, early_turn_state, early_pending, []), early_before, "Early detonation must not mutate board or pending marks.")

	var source_pending: Array[Dictionary] = [_pending_mark(Vector2i(1, 2), 2)]
	source_pending[0]["source_entity_id"] = "other_seer"
	var source_board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_detonation_hit()
	var source_streams: RngStreamSet = RngStreamSet.new(114)
	var source_turn_state: TacticalTurnState = TacticalTurnState.new(2, TacticalTurnState.Phase.ENEMY_RESOLVING, &"enemy_seer")
	var source_context: TacticalActionContext = TacticalActionContext.new(source_board, source_turn_state, source_streams, source_pending)
	var source_before: Dictionary = _snapshot_dictionary(source_board, source_streams, source_turn_state, source_pending, [])
	var source_decision: AiDecision = _detonation_decision(source_pending[0])

	var source_result: ActionResult = adapter.apply_decision(source_context, source_decision, repository.get_enemy(&"ash_seer"))

	assert_true(source_result.is_error(), "Ash Seer detonation should reject marks from another source.")
	assert_equal(source_result.metadata.get("reason"), "source_mismatch", "Source mismatch should be explicit.")
	assert_equal(_snapshot_dictionary(source_board, source_streams, source_turn_state, source_pending, []), source_before, "Source mismatch must not mutate board or pending marks.")

	var status_pending: Array[Dictionary] = [_pending_mark(Vector2i(1, 2), 2)]
	status_pending[0]["status"] = "resolved"
	var status_board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_detonation_hit()
	var status_streams: RngStreamSet = RngStreamSet.new(115)
	var status_turn_state: TacticalTurnState = TacticalTurnState.new(2, TacticalTurnState.Phase.ENEMY_RESOLVING, &"enemy_seer")
	var status_context: TacticalActionContext = TacticalActionContext.new(status_board, status_turn_state, status_streams, status_pending)
	var status_before: Dictionary = _snapshot_dictionary(status_board, status_streams, status_turn_state, status_pending, [])
	var status_decision: AiDecision = _detonation_decision(status_pending[0])

	var status_result: ActionResult = adapter.apply_decision(status_context, status_decision, repository.get_enemy(&"ash_seer"))

	assert_true(status_result.is_error(), "Ash Seer detonation should reject non-pending marks.")
	assert_equal(status_result.metadata.get("reason"), "invalid_status", "Status mismatch should reject the pending mark before mutation.")
	assert_equal(_snapshot_dictionary(status_board, status_streams, status_turn_state, status_pending, []), status_before, "Invalid mark status must not mutate board or pending marks.")


func _enemy_events_replay_pending_telegraph_state() -> void:
	var mark_board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_mark()
	var mark_replay_board: BoardState = BoardState.from_snapshot(mark_board.to_snapshot())
	var mark_pending: Array[Dictionary] = []
	var mark_context: TacticalActionContext = _context(mark_board, RngStreamSet.new(116), mark_pending)

	var mark_result: ActionResult = _resolver().resolve_after_player_action(mark_context, _advancing_player_result())
	var replay_pending: Array[Dictionary] = []
	var replay_board_result: ActionResult = mark_replay_board.apply_events(mark_result.events)
	var replay_pending_result: ActionResult = PendingTelegraphState.apply_events(replay_pending, mark_result.events)

	assert_true(mark_result.succeeded, "Mark resolution should succeed before replay.")
	assert_true(replay_board_result.succeeded, "Mark events should replay on a copied board.")
	assert_true(replay_pending_result.succeeded, "Mark events should replay into pending telegraph state.")
	assert_equal(mark_replay_board.to_snapshot(), mark_board.to_snapshot(), "Replayed mark events should reproduce board sequence state.")
	assert_equal(replay_pending, mark_pending, "Replayed mark events should reproduce pending telegraph state.")

	var hit_board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_detonation_hit()
	var hit_replay_board: BoardState = BoardState.from_snapshot(hit_board.to_snapshot())
	var hit_pending: Array[Dictionary] = [_pending_mark(Vector2i(1, 2), 2)]
	var hit_replay_pending: Array[Dictionary] = hit_pending.duplicate(true)
	var hit_context: TacticalActionContext = _context(hit_board, RngStreamSet.new(117), hit_pending, 2)

	var hit_result: ActionResult = _resolver().resolve_after_player_action(hit_context, _advancing_player_result())
	var hit_board_replay_result: ActionResult = hit_replay_board.apply_events(hit_result.events)
	var hit_pending_replay_result: ActionResult = PendingTelegraphState.apply_events(hit_replay_pending, hit_result.events)

	assert_true(hit_result.succeeded, "Detonation resolution should succeed before replay.")
	assert_true(hit_board_replay_result.succeeded, "Detonation events should replay on a copied board.")
	assert_true(hit_pending_replay_result.succeeded, "Detonation events should replay pending mark removal.")
	assert_equal(hit_replay_board.to_snapshot(), hit_board.to_snapshot(), "Replayed detonation events should reproduce board HP and sequence state.")
	assert_equal(hit_replay_pending, hit_pending, "Replayed detonation events should reproduce pending telegraph removal.")


func _blocked_enemy_waits_without_board_rng_or_pending_mutation() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_blocked_approach()
	var streams: RngStreamSet = RngStreamSet.new(108)
	var pending: Array[Dictionary] = []
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending)
	var before_rng: Dictionary = streams.to_snapshot()

	var result_value: ActionResult = _resolver().resolve_after_player_action(context, _advancing_player_result())
	var decision: Dictionary = result_value.metadata.get("decisions", [])[0]

	assert_true(result_value.succeeded, "Blocked enemy should resolve as a deterministic wait.")
	assert_equal(result_value.events.size(), 1, "Blocked enemy should emit one wait event.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.ENEMY_WAITED, "Blocked enemy should emit readable wait event.")
	assert_equal(decision.get("action_id"), "wait", "Blocked decision should be recorded.")
	assert_equal(decision.get("wait_reason"), "blocked", "Blocked decision should expose reason.")
	assert_equal(streams.to_snapshot(), before_rng, "Blocked wait must not consume RNG.")
	assert_equal(pending.size(), 0, "Blocked wait must not mutate pending telegraphs.")


func _same_seed_resolution_reproduces_events_pending_state_and_explanations() -> void:
	var first_board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_mark()
	var second_board: BoardState = BoardState.from_snapshot(first_board.to_snapshot())
	var first_pending: Array[Dictionary] = []
	var second_pending: Array[Dictionary] = []
	var first_context: TacticalActionContext = _context(first_board, RngStreamSet.new(109), first_pending)
	var second_context: TacticalActionContext = _context(second_board, RngStreamSet.new(109), second_pending)

	var first_result: ActionResult = _resolver().resolve_after_player_action(first_context, _advancing_player_result())
	var second_result: ActionResult = _resolver().resolve_after_player_action(second_context, _advancing_player_result())

	assert_true(first_result.succeeded, "First deterministic resolution should succeed.")
	assert_true(second_result.succeeded, "Second deterministic resolution should succeed.")
	assert_equal(_event_dictionaries(first_result.events), _event_dictionaries(second_result.events), "Same seed and state should reproduce enemy events.")
	assert_equal(first_pending, second_pending, "Same seed and state should reproduce pending telegraph state.")
	assert_equal(first_result.metadata.get("decisions"), second_result.metadata.get("decisions"), "Same seed and state should reproduce decision explanations.")


func _resolver() -> EnemyTurnResolver:
	return EnemyTurnResolver.new(EnemyRepository.create_baseline_repository(), &"hero")


func _context(
	board: BoardState,
	streams: RngStreamSet,
	pending: Array[Dictionary],
	turn_number: int = 1
) -> TacticalActionContext:
	var turn_state: TacticalTurnState = TacticalTurnState.new(turn_number, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	return TacticalActionContext.new(board, turn_state, streams, pending)


func _advancing_player_result() -> ActionResult:
	return ActionResult.ok([], {"advances_turn": true})


func _pending_mark(marked_cell: Vector2i, due_turn_number: int) -> Dictionary:
	return {
		"telegraph_id": "ash_seer_mark:enemy_seer:2",
		"kind": "ash_seer_mark",
		"source_entity_id": "enemy_seer",
		"target_entity_id": "hero",
		"marked_cell": {"x": marked_cell.x, "y": marked_cell.y},
		"created_turn_number": 1,
		"due_turn_number": due_turn_number,
		"damage": 4,
		"damage_type": "physical",
		"status": "pending"
	}


func _detonation_decision(mark: Dictionary) -> AiDecision:
	return AiDecision.new(
		&"enemy_seer",
		&"ash_seer",
		&"detonate",
		120,
		["due_mark"],
		StringName(str(mark.get("target_entity_id", "hero"))),
		Vector2i(5, 2),
		Vector2i(5, 2),
		Vector2i(int(mark.get("marked_cell", {}).get("x", -1)), int(mark.get("marked_cell", {}).get("y", -1))),
		&"",
		mark.duplicate(true)
	)


func _snapshot_dictionary(
	board: BoardState,
	streams: RngStreamSet,
	turn_state: TacticalTurnState,
	pending: Array[Dictionary],
	event_log: Array[DomainEvent]
) -> Dictionary:
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams, turn_state.to_dictionary(), pending, event_log)
	assert_true(result_value.succeeded, "Test helper should export a tactical snapshot.")
	var snapshot: TacticalSnapshot = result_value.metadata.get("snapshot") as TacticalSnapshot
	return snapshot.to_dictionary()


func _event_dictionaries(events: Array[DomainEvent]) -> Array[Dictionary]:
	var result_value: Array[Dictionary] = []
	for event: DomainEvent in events:
		result_value.append(event.to_dictionary())
	return result_value
