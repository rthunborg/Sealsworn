extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatOutcomeEvaluator = preload("res://scripts/tactical/outcomes/combat_outcome_evaluator.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_victory_emits_once_and_is_idempotent()
	_defeat_records_damage_cause()
	_defeat_takes_precedence_when_both_sides_dead()
	_active_combat_returns_no_outcome_without_mutation()
	_invalid_context_and_state_do_not_mutate()
	_rebuilt_outcome_state_prevents_duplicate_events()
	_victory_holds_after_corpse_clear_releases_enemy_cells()
	return result()


func _victory_emits_once_and_is_idempotent() -> void:
	var board: BoardState = BoardFixtureFactory.outcome_all_enemies_dead()
	var state: CombatOutcomeState = CombatOutcomeState.new()
	var event_log: Array[DomainEvent] = [
		_enemy_damage_event(40, &"enemy_seer", 4, 4, 0, 8),
		DomainEvent.enemy_waited(41, &"enemy_iron", &"blocked", _wait_payload())
	]

	var first_result: ActionResult = CombatOutcomeEvaluator.new().evaluate(board, state, event_log)
	var second_result: ActionResult = CombatOutcomeEvaluator.new().evaluate(board, state, event_log)

	assert_true(first_result.succeeded, "Victory evaluation should succeed.")
	assert_equal(first_result.events.size(), 1, "Victory evaluation should emit one outcome event.")
	assert_equal(first_result.events[0].event_type, DomainEvent.Type.LEVEL_VICTORY_REACHED, "Victory evaluation should emit a victory event.")
	assert_equal(first_result.events[0].sequence_id, 2, "Victory event should use the board's next sequence id.")
	assert_equal(first_result.events[0].payload.get("defeated_enemy_ids"), ["enemy_iron", "enemy_seer"], "Victory payload should record defeated enemies in stable order.")
	assert_equal(first_result.events[0].payload.get("cause_event_sequence_id"), 40, "Victory cause should prefer the latest defeated-enemy damage event.")
	assert_equal(state.state_id, CombatOutcomeState.STATE_VICTORY, "Victory evaluation should mutate only the outcome state after event application.")
	assert_equal(board.next_sequence_id(), 3, "Victory event should advance board sequence id once.")
	assert_true(second_result.succeeded, "Repeated terminal evaluation should succeed as an idempotent no-op.")
	assert_equal(second_result.events.size(), 0, "Repeated victory evaluation must not duplicate outcome events.")


func _defeat_records_damage_cause() -> void:
	var board: BoardState = BoardFixtureFactory.outcome_player_dead()
	var state: CombatOutcomeState = CombatOutcomeState.new()
	var event_log: Array[DomainEvent] = [
		DomainEvent.enemy_waited(12, &"enemy_iron", &"blocked", _wait_payload()),
		_player_damage_event(13, &"enemy_iron", 3, 3, 0)
	]

	var result_value: ActionResult = CombatOutcomeEvaluator.new().evaluate(board, state, event_log)
	var event: DomainEvent = result_value.events[0]

	assert_true(result_value.succeeded, "Defeat evaluation should succeed.")
	assert_equal(event.event_type, DomainEvent.Type.LEVEL_DEFEAT_REACHED, "Defeat evaluation should emit a defeat event.")
	assert_equal(event.payload.get("defeated_player_id"), "hero", "Defeat payload should identify the fallen player.")
	assert_equal(event.payload.get("cause_event_sequence_id"), 13, "Defeat payload should record the damage cause sequence.")
	assert_equal(event.payload.get("cause_event_id"), "damage_applied", "Defeat payload should record the cause event id.")
	assert_equal(event.payload.get("source_entity_id"), "enemy_iron", "Defeat payload should record the damaging source.")
	assert_equal(event.payload.get("damage_type"), "physical", "Defeat payload should record damage type.")
	assert_equal(event.payload.get("final_damage"), 3, "Defeat payload should record final damage.")
	assert_equal(state.state_id, CombatOutcomeState.STATE_DEFEAT, "Defeat evaluation should enter defeat state.")


func _defeat_takes_precedence_when_both_sides_dead() -> void:
	var board: BoardState = BoardFixtureFactory.outcome_both_sides_dead()
	var state: CombatOutcomeState = CombatOutcomeState.new()

	var result_value: ActionResult = CombatOutcomeEvaluator.new().evaluate(board, state, [_player_damage_event(9, &"enemy_seer", 4, 4, 0)])

	assert_true(result_value.succeeded, "Both-sides-dead evaluation should succeed.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.LEVEL_DEFEAT_REACHED, "Defeat should take precedence over victory.")
	assert_equal(state.state_id, CombatOutcomeState.STATE_DEFEAT, "Outcome state should record defeat precedence.")


func _active_combat_returns_no_outcome_without_mutation() -> void:
	var board: BoardState = BoardFixtureFactory.outcome_active_combat()
	var state: CombatOutcomeState = CombatOutcomeState.new()
	var before: Dictionary = board.to_snapshot()

	var result_value: ActionResult = CombatOutcomeEvaluator.new().evaluate(board, state, [])

	assert_true(result_value.succeeded, "Active combat should evaluate without error.")
	assert_equal(result_value.events.size(), 0, "Active combat should not emit outcome events.")
	assert_equal(result_value.metadata.get("outcome"), "active", "Active combat metadata should preserve active outcome.")
	assert_equal(state.state_id, CombatOutcomeState.STATE_ACTIVE, "Active combat should keep outcome state active.")
	assert_equal(board.to_snapshot(), before, "Active evaluation must not mutate board state.")


func _invalid_context_and_state_do_not_mutate() -> void:
	var board: BoardState = BoardFixtureFactory.outcome_all_enemies_dead()
	var invalid_state: CombatOutcomeState = CombatOutcomeState.new(&"finished")
	var before: Dictionary = board.to_snapshot()

	var null_board_result: ActionResult = CombatOutcomeEvaluator.new().evaluate(null, CombatOutcomeState.new(), [])
	var invalid_state_result: ActionResult = CombatOutcomeEvaluator.new().evaluate(board, invalid_state, [])

	assert_true(null_board_result.is_error(), "Outcome evaluation should reject missing boards.")
	assert_equal(null_board_result.error_code, &"invalid_outcome_evaluation", "Missing board should use a stable evaluator error.")
	assert_true(invalid_state_result.is_error(), "Outcome evaluation should reject invalid outcome state ids.")
	assert_equal(invalid_state_result.metadata.get("reason"), "invalid_outcome_state", "Invalid state diagnostics should be explicit.")
	assert_equal(board.to_snapshot(), before, "Invalid outcome evaluation must not mutate board state.")


func _rebuilt_outcome_state_prevents_duplicate_events() -> void:
	var board: BoardState = BoardFixtureFactory.outcome_all_enemies_dead()
	var state: CombatOutcomeState = CombatOutcomeState.new()
	var result_value: ActionResult = CombatOutcomeEvaluator.new().evaluate(board, state, [_enemy_damage_event(40, &"enemy_seer", 4, 4, 0, 8)])
	var state_snapshot: Dictionary = state.to_dictionary()
	var board_snapshot: Dictionary = board.to_snapshot()
	var restored_state_result: ActionResult = CombatOutcomeState.try_from_dictionary(state_snapshot)
	var restored_board: BoardState = BoardState.from_snapshot(board_snapshot)
	var restored_state: CombatOutcomeState = restored_state_result.metadata.get("outcome_state") as CombatOutcomeState

	var rebuilt_result: ActionResult = CombatOutcomeEvaluator.new().evaluate(restored_board, restored_state, result_value.events)

	assert_true(restored_state_result.succeeded, "Outcome state snapshots should parse.")
	assert_true(rebuilt_result.succeeded, "Rebuilt terminal outcome should evaluate cleanly.")
	assert_equal(rebuilt_result.events.size(), 0, "Rebuilt terminal outcome should not duplicate outcome events.")
	assert_equal(restored_state.state_id, CombatOutcomeState.STATE_VICTORY, "Restored outcome state should preserve victory.")


func _player_damage_event(sequence_id: int, actor_id: StringName, amount: int, hp_before: int, hp_after: int) -> DomainEvent:
	return DomainEvent.damage_applied(sequence_id, actor_id, &"hero", amount, hp_before, hp_after, 18, _damage_payload(amount))


func _enemy_damage_event(sequence_id: int, target_id: StringName, amount: int, hp_before: int, hp_after: int, max_hp: int) -> DomainEvent:
	return DomainEvent.damage_applied(sequence_id, &"hero", target_id, amount, hp_before, hp_after, max_hp, _damage_payload(amount))


func _damage_payload(amount: int) -> Dictionary:
	return {
		"weapon_id": "sword",
		"base_damage": amount,
		"support_bonus_damage": 0,
		"armor_reduction": 0,
		"block_succeeded": false,
		"final_damage": amount,
		"damage_type": "physical",
		"rng_draws": []
	}


func _wait_payload() -> Dictionary:
	return {
		"enemy_definition_id": "iron_cultist",
		"action_id": "wait",
		"score": 0,
		"reasons": ["blocked"],
		"explanation": "enemy_iron waited: blocked."
	}


# Story 14.1 (AC1): the win condition (zero LIVING enemies) is UNCHANGED by corpse-clear. After the last enemy dies
# via the real damage path (corpse-clear vacates its cell + flips blocks_movement false), the evaluator still emits
# victory, and the defeated_enemy_ids payload still lists the corpse (which stays in _entities).
func _victory_holds_after_corpse_clear_releases_enemy_cells() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_kill_board()
	assert_true(board.apply_events([DomainEvent.damage_applied(board.next_sequence_id(), &"hero", &"enemy_1", 3, 3, 0, 10, {})]).succeeded, "Setup: the last enemy dies (corpse-clear).")
	assert_equal(board.occupant_at(Vector2i(2, 1)), &"", "Setup: the corpse released its cell occupancy.")
	var state: CombatOutcomeState = CombatOutcomeState.new()
	var result_value: ActionResult = CombatOutcomeEvaluator.new(&"hero").evaluate(board, state, [])
	assert_true(result_value.succeeded, "Victory evaluation succeeds after corpse-clear.")
	assert_equal(result_value.events.size(), 1, "A single victory event is emitted.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.LEVEL_VICTORY_REACHED, "The win condition still fires with a corpse on the board.")
	assert_equal(result_value.events[0].payload.get("defeated_enemy_ids"), ["enemy_1"], "The corpse is still counted in the defeated_enemy_ids payload (it stays in _entities).")
	assert_equal(state.state_id, CombatOutcomeState.STATE_VICTORY, "The outcome state is victory.")
