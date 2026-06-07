extends "res://tests/unit/test_case.gd"

const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const PrototypeEnemyAi = preload("res://scripts/ai/prototype_enemy_ai.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")

func run() -> Dictionary:
	_melee_enemy_attacks_when_cardinally_adjacent()
	_melee_enemy_approaches_one_authoritative_step_without_visibility_dependency()
	_blocked_melee_enemy_waits_with_reason_without_rng()
	_ash_seer_marks_visible_player_without_immediate_damage()
	_ash_seer_due_mark_detonates_before_new_mark()
	_ai_decisions_are_reproducible_from_same_seed_and_state()
	return result()


func _melee_enemy_attacks_when_cardinally_adjacent() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_adjacent_melee()
	var streams: RngStreamSet = RngStreamSet.new(123)
	var before_rng: Dictionary = streams.to_snapshot()
	var decision: Variant = _ai().decide(board, board.get_entity(&"enemy_iron"), &"hero", [], 1)

	assert_equal(decision.action_id, &"attack", "Adjacent Iron Cultist should choose attack.")
	assert_equal(decision.target_entity_id, &"hero", "Adjacent attack should target the player.")
	assert_equal(decision.score, 100, "Adjacent attack should have deterministic top score.")
	assert_true(decision.reasons.has("adjacent_cardinal"), "Adjacent attack should explain the cardinal threat.")
	assert_equal(streams.to_snapshot(), before_rng, "Prototype enemy AI must not consume RNG.")


func _melee_enemy_approaches_one_authoritative_step_without_visibility_dependency() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_approach()
	board.get_cell(Vector2i(3, 2)).visible = false
	board.get_cell(Vector2i(3, 2)).explored = false

	var decision: Variant = _ai().decide(board, board.get_entity(&"enemy_iron"), &"hero", [], 1)

	assert_equal(decision.action_id, &"move", "Non-adjacent Iron Cultist should approach if a path exists.")
	assert_equal(decision.from_cell, Vector2i(4, 2), "Approach should record source cell.")
	assert_equal(decision.to_cell, Vector2i(3, 2), "Enemy pathing should use board truth, not player visibility flags.")
	assert_true(decision.reasons.has("shortest_path"), "Approach should explain shortest-path selection.")


func _blocked_melee_enemy_waits_with_reason_without_rng() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_blocked_approach()
	var streams: RngStreamSet = RngStreamSet.new(456)
	var before_rng: Dictionary = streams.to_snapshot()

	var decision: Variant = _ai().decide(board, board.get_entity(&"enemy_iron"), &"hero", [], 1)

	assert_equal(decision.action_id, &"wait", "Blocked Iron Cultist should wait.")
	assert_equal(decision.wait_reason, &"blocked", "Blocked wait should expose a stable reason.")
	assert_true(decision.reasons.has("no_legal_approach"), "Blocked wait should explain why no approach was legal.")
	assert_equal(streams.to_snapshot(), before_rng, "Wait decisions must not consume RNG.")


func _ash_seer_marks_visible_player_without_immediate_damage() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_mark()
	var decision: Variant = _ai().decide(board, board.get_entity(&"enemy_seer"), &"hero", [], 1)

	assert_equal(decision.action_id, &"mark", "Ash Seer with LoS and range should mark.")
	assert_equal(decision.target_entity_id, &"hero", "Ash Seer mark should target the player.")
	assert_equal(decision.target_cell, Vector2i(1, 2), "Ash Seer should mark the player's current tile.")
	assert_equal(decision.score, 80, "Ash Seer mark should use deterministic scoring.")
	assert_true(decision.reasons.has("line_of_sight"), "Ash Seer mark should explain line of sight.")


func _ash_seer_due_mark_detonates_before_new_mark() -> void:
	var board: BoardState = BoardFixtureFactory.enemy_turn_ash_seer_detonation_hit()
	var pending: Array[Dictionary] = [_pending_mark(Vector2i(1, 2), 2)]

	var decision: Variant = _ai().decide(board, board.get_entity(&"enemy_seer"), &"hero", pending, 2)

	assert_equal(decision.action_id, &"detonate", "Due Ash Seer marks should detonate before creating a new mark.")
	assert_equal(decision.target_cell, Vector2i(1, 2), "Detonation should preserve the marked cell.")
	assert_equal(decision.score, 120, "Due detonation should outrank new marks.")
	assert_true(decision.reasons.has("due_mark"), "Detonation should explain the due mark.")


func _ai_decisions_are_reproducible_from_same_seed_and_state() -> void:
	var first_board: BoardState = BoardFixtureFactory.enemy_turn_approach()
	var second_board: BoardState = BoardState.from_snapshot(first_board.to_snapshot())
	var first_decision: Variant = _ai().decide(first_board, first_board.get_entity(&"enemy_iron"), &"hero", [], 1)
	var second_decision: Variant = _ai().decide(second_board, second_board.get_entity(&"enemy_iron"), &"hero", [], 1)

	assert_equal(first_decision.to_dictionary(), second_decision.to_dictionary(), "Same seed and board state should reproduce enemy AI decisions and explanations.")


func _ai() -> PrototypeEnemyAi:
	return PrototypeEnemyAi.new(EnemyRepository.create_baseline_repository())


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
