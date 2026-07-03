extends "res://tests/unit/test_case.gd"

# Story 9.3 Task 2 — BossAi (the pure, phase-constrained utility scorer, AC3). Covers: the boss scores ONLY the ACTIVE
# phase's legal actions (recomputed from HP); different HP -> a different phase -> a different chosen ability (the 9.2
# phase-0/1/2 sets differ); a damaging ability TELEGRAPHS when in range + LoS (score 80); a far boss SKITTERS
# (approaches, score 50); a due telegraph RESOLVES first (score 120); a phase with two damaging abilities picks the
# HIGHER-damage one (the major dangerous ability); the decision carries a score + reasons + the ability's telegraph/
# damage metadata (explainable); ZERO RNG is drawn; and the same inputs -> the same decision (reproducibility).

const AiDecision = preload("res://scripts/ai/ai_decision.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossAi = preload("res://scripts/ai/boss_ai.gd")
const BossBoardFixtureFactory = preload("res://tests/fixtures/tactical/boss_board_fixture_factory.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const PendingTelegraphState = preload("res://scripts/tactical/turns/pending_telegraph_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")

# HP anchors on the 36-HP baseline: phase 0 at full (36), phase 1 at 60% (<= 21), phase 2 at 25% (<= 9).
const PHASE1_HP := 20
const PHASE2_HP := 8

func run() -> Dictionary:
	_boss_in_range_telegraphs_the_major_ability()
	_boss_scores_only_active_phase_legal_actions()
	_phase_one_prefers_higher_damage_lash_over_corrupt_mark()
	_phase_two_prefers_frenzied_lash_over_corrupt_flood()
	_far_boss_skitters_toward_the_player()
	_due_telegraph_resolves_before_a_new_action()
	_boss_waits_when_no_target()
	_ai_draws_zero_rng()
	_decisions_are_reproducible_from_same_state()
	return result()


func _boss_in_range_telegraphs_the_major_ability() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var decision: AiDecision = _decide(board, [], 1)

	assert_equal(decision.action_id, &"telegraph", "An in-range boss should telegraph its major dangerous ability.")
	assert_equal(decision.score, BossAi.SCORE_TELEGRAPH, "A telegraph should use the deterministic telegraph score.")
	assert_equal(String(decision.metadata.get("boss_action_id")), "lash", "Phase 0 in range should telegraph the lash.")
	assert_equal(decision.target_cell, Vector2i(6, 4), "The telegraph should mark the player's current cell.")
	assert_true(decision.reasons.has("major_dangerous_ability"), "The telegraph should explain it is a major dangerous ability.")
	assert_false(String(decision.metadata.get("telegraph_text", "")).strip_edges().is_empty(), "The decision should carry the ability's telegraph text.")
	assert_true(int(decision.metadata.get("damage", 0)) > 0, "A telegraphed ability should carry positive damage.")
	assert_equal(int(decision.metadata.get("active_phase_index", -1)), 0, "A full-HP boss should be in phase 0.")


func _boss_scores_only_active_phase_legal_actions() -> void:
	# At full HP (phase 0) the boss telegraphs `lash`; at phase-1 HP it telegraphs the phase-1 `lash` (8 dmg, not the
	# phase-0 6-dmg lash) — proving the AI reads the ACTIVE phase's action set, not a fixed one. corrupt_mark/skitter
	# from other phases are never chosen out of phase.
	var phase0_board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var phase1_board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range(PHASE1_HP)
	var phase0_decision: AiDecision = _decide(phase0_board, [], 1)
	var phase1_decision: AiDecision = _decide(phase1_board, [], 1)

	assert_equal(int(phase0_decision.metadata.get("active_phase_index", -1)), 0, "Full HP is phase 0.")
	assert_equal(int(phase1_decision.metadata.get("active_phase_index", -1)), 1, "60%-HP boss is phase 1.")
	assert_equal(int(phase0_decision.metadata.get("damage", 0)), 6, "Phase 0 lash deals the phase-0 damage (6).")
	assert_equal(int(phase1_decision.metadata.get("damage", 0)), 8, "Phase 1 lash deals the phase-1 damage (8) — the active phase's action set.")


func _phase_one_prefers_higher_damage_lash_over_corrupt_mark() -> void:
	# Phase 1 legal set = {lash (8), corrupt_mark (5)}. The AI picks the HIGHER-damage lash as the major dangerous ability.
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range(PHASE1_HP)
	var decision: AiDecision = _decide(board, [], 1)

	assert_equal(decision.action_id, &"telegraph", "Phase 1 in range should telegraph.")
	assert_equal(String(decision.metadata.get("boss_action_id")), "lash", "Phase 1 should pick the higher-damage lash over corrupt_mark.")
	assert_equal(int(decision.metadata.get("damage", 0)), 8, "The chosen phase-1 ability is the 8-damage lash.")


func _phase_two_prefers_frenzied_lash_over_corrupt_flood() -> void:
	# Phase 2 legal set = {frenzied_lash (11), corrupt_flood (7)}. The AI picks frenzied_lash (highest damage).
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range(PHASE2_HP)
	var decision: AiDecision = _decide(board, [], 1)

	assert_equal(int(decision.metadata.get("active_phase_index", -1)), 2, "25%-HP boss is phase 2.")
	assert_equal(String(decision.metadata.get("boss_action_id")), "frenzied_lash", "Phase 2 should pick frenzied_lash (highest damage).")
	assert_equal(int(decision.metadata.get("damage", 0)), 11, "The chosen phase-2 ability is the 11-damage frenzied_lash.")


func _far_boss_skitters_toward_the_player() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_far()
	var decision: AiDecision = _decide(board, [], 1)

	assert_equal(decision.action_id, &"move", "A far boss should skitter (approach) instead of telegraphing.")
	assert_equal(decision.score, BossAi.SCORE_MOVE, "A skitter should use the deterministic move score.")
	assert_equal(String(decision.metadata.get("boss_action_id")), "skitter", "The phase-0 movement ability is skitter.")
	assert_equal(decision.from_cell, BossBoardFixtureFactory.boss_slot_cell(), "The skitter should start at the boss slot.")
	assert_equal(decision.to_cell, Vector2i(6, 2), "The skitter should step one cardinal step toward the player.")
	assert_true(decision.reasons.has("skitter"), "The move should explain it is a skitter.")


func _due_telegraph_resolves_before_a_new_action() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var pending: Array[Dictionary] = [_pending_telegraph(Vector2i(6, 4), 2)]
	var decision: AiDecision = _decide(board, pending, 2)

	assert_equal(decision.action_id, &"resolve", "A due boss telegraph should resolve before a new telegraph.")
	assert_equal(decision.score, BossAi.SCORE_RESOLVE, "Resolving a due telegraph should outrank a new telegraph.")
	assert_equal(decision.target_cell, Vector2i(6, 4), "The resolution should target the marked cell.")
	assert_true(decision.reasons.has("due_telegraph"), "The resolution should explain the due telegraph.")


func _boss_waits_when_no_target() -> void:
	# No hero on the board (removed) -> no target -> the boss waits deterministically.
	var board: BoardState = _arena_board_without_hero()
	var decision: AiDecision = _decide(board, [], 1)

	assert_equal(decision.action_id, &"wait", "A boss with no player target should wait.")
	assert_equal(decision.score, BossAi.SCORE_WAIT, "A wait uses the zero score.")
	assert_equal(decision.wait_reason, &"missing_target", "The wait should explain the missing target.")


func _ai_draws_zero_rng() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var streams: RngStreamSet = RngStreamSet.new(777)
	var before_rng: Dictionary = streams.to_snapshot()

	_decide(board, [], 1)

	assert_equal(streams.to_snapshot(), before_rng, "The boss AI must not consume RNG (reproducibility is pure determinism).")


func _decisions_are_reproducible_from_same_state() -> void:
	var first_board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var second_board: BoardState = BoardState.from_snapshot(first_board.to_snapshot())
	var first_decision: AiDecision = _decide(first_board, [], 1)
	var second_decision: AiDecision = _decide(second_board, [], 1)

	assert_equal(first_decision.to_dictionary(), second_decision.to_dictionary(), "Same board and state should reproduce the boss decision and explanation.")


# ---- helpers -------------------------------------------------------------------------------------

func _decide(board: BoardState, pending: Array[Dictionary], turn_number: int) -> AiDecision:
	return BossAi.new().decide(board, board.get_entity(&"larval_avatar"), &"hero", pending, turn_number, _definition())


func _definition() -> BossDefinition:
	return BossBoardFixtureFactory.boss_definition()


func _arena_board_without_hero() -> BoardState:
	# The arena board with only the boss (no hero placed).
	var board: BoardState = BossBoardFixtureFactory.boss_arena(Vector2i(6, 4))
	var snapshot: Dictionary = board.to_snapshot()
	var filtered_entities: Array = []
	for entity_snapshot: Variant in snapshot.get("entities", []):
		if String((entity_snapshot as Dictionary).get("entity_id", "")) != "hero":
			filtered_entities.append(entity_snapshot)
	snapshot["entities"] = filtered_entities
	# Clear the hero's occupant from its cell so the snapshot restores cleanly.
	for cell_snapshot: Variant in snapshot.get("cells", []):
		if String((cell_snapshot as Dictionary).get("occupant_id", "")) == "hero":
			(cell_snapshot as Dictionary)["occupant_id"] = ""
	return BoardState.from_snapshot(snapshot)


func _pending_telegraph(marked_cell: Vector2i, due_turn_number: int) -> Dictionary:
	return {
		"telegraph_id": "larval_avatar_telegraph:larval_avatar:1",
		"kind": PendingTelegraphState.KIND_LARVAL_AVATAR_TELEGRAPH,
		"source_entity_id": "larval_avatar",
		"target_entity_id": "hero",
		"boss_action_id": "lash",
		"marked_cell": {"x": marked_cell.x, "y": marked_cell.y},
		"created_turn_number": 1,
		"due_turn_number": due_turn_number,
		"damage": 6,
		"damage_type": "physical",
		"status": "pending"
	}
