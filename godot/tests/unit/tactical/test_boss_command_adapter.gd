extends "res://tests/unit/test_case.gd"

# Story 9.3 Task 4 — BossCommandAdapter (the narrow adapter: boss actions become EXISTING events, never a direct
# mutation, AC2/AC4). Covers: `telegraph` emits a tile_marked event + adds a pending telegraph + does NOT damage this
# turn (AC1); `resolve` on a HIT emits marked_tile_detonated + damage_applied whose payload names the boss ability
# (AC4); `resolve` on an AVOIDED telegraph emits detonation only, NO damage; `move` (skitter) emits entity_moved;
# `wait` emits enemy_waited; the boss path mutates the board ONLY via apply_events (a pre/post snapshot comparison is
# unchanged on a rejected/no-op path); an unsupported action id is rejected; a malformed non-cardinal move is rejected
# without mutation.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AiDecision = preload("res://scripts/ai/ai_decision.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossBoardFixtureFactory = preload("res://tests/fixtures/tactical/boss_board_fixture_factory.gd")
const BossCommandAdapter = preload("res://scripts/tactical/turns/boss_command_adapter.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PendingTelegraphState = preload("res://scripts/tactical/turns/pending_telegraph_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

func run() -> Dictionary:
	_telegraph_marks_without_immediate_damage()
	_resolution_hit_applies_damage_naming_the_ability()
	_resolution_avoided_emits_no_damage()
	_skitter_emits_entity_moved()
	_wait_emits_enemy_waited()
	_unsupported_action_is_rejected_without_mutation()
	_malformed_move_is_rejected_without_mutation()
	return result()


func _telegraph_marks_without_immediate_damage() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var pending: Array[Dictionary] = []
	var context: TacticalActionContext = _context(board, RngStreamSet.new(200), pending, 1)
	var hero_hp_before: int = board.get_entity(&"hero").current_hp
	var decision: AiDecision = _telegraph_decision(Vector2i(6, 4), "lash", 6, "physical")

	var result_value: ActionResult = _adapter().apply_decision(context, decision, _definition())

	assert_true(result_value.succeeded, "A boss telegraph should resolve.")
	assert_equal(result_value.events.size(), 1, "A telegraph should emit one tile-marked event (no damage this turn).")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.TILE_MARKED, "A telegraph should emit a tile_marked event.")
	assert_equal(board.get_entity(&"hero").current_hp, hero_hp_before, "A telegraph must not apply immediate damage (AC1).")
	assert_equal(pending.size(), 1, "A telegraph should store one pending telegraph.")
	assert_equal(pending[0].get("kind"), PendingTelegraphState.KIND_LARVAL_AVATAR_TELEGRAPH, "The pending telegraph uses the boss telegraph kind.")
	assert_equal(int(pending[0].get("due_turn_number", 0)), int(pending[0].get("created_turn_number", 0)) + 1, "The response window is a one-turn gap (AC1).")
	assert_equal(pending[0].get("marked_cell"), {"x": 6, "y": 4}, "The telegraph marks the player's current cell.")
	assert_equal(String(pending[0].get("boss_action_id", "")), "lash", "The pending telegraph records the boss ability id.")


func _resolution_hit_applies_damage_naming_the_ability() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var pending: Array[Dictionary] = [_pending_telegraph(Vector2i(6, 4), 2, "lash", 6, "physical")]
	var context: TacticalActionContext = _context(board, RngStreamSet.new(201), pending, 2)
	var decision: AiDecision = _resolve_decision(pending[0])

	var result_value: ActionResult = _adapter().apply_decision(context, decision, _definition())

	assert_true(result_value.succeeded, "A due telegraph resolution should resolve.")
	assert_equal(result_value.events.size(), 2, "A hit should emit detonation + damage events.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.MARKED_TILE_DETONATED, "The resolution should detonate before damage.")
	assert_equal(result_value.events[0].payload.get("outcome"), "hit", "The player on the marked cell is a hit.")
	assert_equal(result_value.events[1].event_type, DomainEvent.Type.DAMAGE_APPLIED, "A hit should apply damage.")
	assert_equal(result_value.events[1].payload.get("amount"), 6, "The resolved lash deals its authored 6 damage.")
	assert_equal(result_value.events[1].payload.get("damage_type"), "physical", "The damage records the ability's damage type.")
	assert_true(String(result_value.events[1].payload.get("explanation", "")).contains("lash"), "The damage explanation must name the boss ability (AC4).")
	assert_equal(board.get_entity(&"hero").current_hp, 12, "A hit should reduce hero HP through domain events (18 - 6).")
	assert_equal(pending.size(), 0, "A resolved telegraph should be removed from pending.")


func _resolution_avoided_emits_no_damage() -> void:
	# The hero moved OFF the marked cell (marked (6,4) but hero at (6,5)) -> avoided, no damage.
	var board: BoardState = BossBoardFixtureFactory.boss_arena(Vector2i(6, 5))
	var pending: Array[Dictionary] = [_pending_telegraph(Vector2i(6, 4), 2, "lash", 6, "physical")]
	var context: TacticalActionContext = _context(board, RngStreamSet.new(202), pending, 2)
	var hero_hp_before: int = board.get_entity(&"hero").current_hp
	var decision: AiDecision = _resolve_decision(pending[0])

	var result_value: ActionResult = _adapter().apply_decision(context, decision, _definition())

	assert_true(result_value.succeeded, "An avoided telegraph resolution should resolve.")
	assert_equal(result_value.events.size(), 1, "An avoided resolution emits detonation only (no damage).")
	assert_equal(result_value.events[0].payload.get("outcome"), "avoided", "A hero off the marked cell is an avoided outcome.")
	assert_equal(board.get_entity(&"hero").current_hp, hero_hp_before, "An avoided resolution must not damage the hero.")
	assert_equal(pending.size(), 0, "An avoided telegraph should still be removed from pending.")


func _skitter_emits_entity_moved() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_far()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(203), [], 1)
	var boss_cell: Vector2i = BossBoardFixtureFactory.boss_slot_cell()
	var decision: AiDecision = _move_decision(boss_cell, boss_cell + Vector2i(0, 1))

	var result_value: ActionResult = _adapter().apply_decision(context, decision, _definition())

	assert_true(result_value.succeeded, "A skitter should resolve.")
	assert_equal(result_value.events.size(), 1, "A skitter emits one movement event.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.ENTITY_MOVED, "A skitter uses the entity_moved event.")
	assert_equal(board.get_entity(&"larval_avatar").position, boss_cell + Vector2i(0, 1), "The boss should move one cardinal step through domain events.")


func _wait_emits_enemy_waited() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(204), [], 1)
	var decision: AiDecision = _wait_decision(&"no_legal_action")

	var result_value: ActionResult = _adapter().apply_decision(context, decision, _definition())

	assert_true(result_value.succeeded, "A boss wait should resolve.")
	assert_equal(result_value.events.size(), 1, "A wait emits one event.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.ENEMY_WAITED, "A wait uses the enemy_waited event.")
	assert_equal(result_value.events[0].payload.get("reason"), "no_legal_action", "The wait records its reason.")


func _unsupported_action_is_rejected_without_mutation() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var streams: RngStreamSet = RngStreamSet.new(205)
	var pending: Array[Dictionary] = []
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.ENEMY_RESOLVING, &"larval_avatar")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending)
	var before: Dictionary = _snapshot_dictionary(board, streams, turn_state, pending)
	var decision: AiDecision = AiDecision.new(&"larval_avatar", &"larval_avatar", &"lunge", 10, ["bogus"], &"hero")

	var result_value: ActionResult = _adapter().apply_decision(context, decision, _definition())

	assert_true(result_value.is_error(), "An unsupported boss action id should be rejected.")
	assert_equal(result_value.metadata.get("reason"), "unsupported_action", "The rejection should identify the unsupported action.")
	assert_equal(_snapshot_dictionary(board, streams, turn_state, pending), before, "A rejected action must not mutate tactical state (AC2).")


func _malformed_move_is_rejected_without_mutation() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_far()
	var streams: RngStreamSet = RngStreamSet.new(206)
	var pending: Array[Dictionary] = []
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.ENEMY_RESOLVING, &"larval_avatar")
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending)
	var before: Dictionary = _snapshot_dictionary(board, streams, turn_state, pending)
	var boss_cell: Vector2i = BossBoardFixtureFactory.boss_slot_cell()
	# A two-cell (non-unit) teleport is a malformed move.
	var decision: AiDecision = _move_decision(boss_cell, boss_cell + Vector2i(0, 2))

	var result_value: ActionResult = _adapter().apply_decision(context, decision, _definition())

	assert_true(result_value.is_error(), "A non-cardinal / non-unit boss move should be rejected.")
	assert_equal(result_value.metadata.get("reason"), "invalid_move_step", "The rejection should identify the invalid move step.")
	assert_equal(_snapshot_dictionary(board, streams, turn_state, pending), before, "A rejected move must not mutate tactical state (AC2).")


# ---- helpers -------------------------------------------------------------------------------------

func _adapter() -> BossCommandAdapter:
	return BossCommandAdapter.new()


func _definition() -> BossDefinition:
	return BossBoardFixtureFactory.boss_definition()


func _context(board: BoardState, streams: RngStreamSet, pending: Array[Dictionary], turn_number: int) -> TacticalActionContext:
	var turn_state: TacticalTurnState = TacticalTurnState.new(turn_number, TacticalTurnState.Phase.ENEMY_RESOLVING, &"larval_avatar")
	return TacticalActionContext.new(board, turn_state, streams, pending)


func _telegraph_decision(marked_cell: Vector2i, boss_action_id: String, damage: int, damage_type: String) -> AiDecision:
	return AiDecision.new(
		&"larval_avatar",
		&"larval_avatar",
		&"telegraph",
		80,
		["major_dangerous_ability"],
		&"hero",
		BossBoardFixtureFactory.boss_slot_cell(),
		BossBoardFixtureFactory.boss_slot_cell(),
		marked_cell,
		&"",
		{
			"boss_action_id": boss_action_id,
			"telegraph_text": "The Larval Avatar coils.",
			"damage": damage,
			"damage_type": damage_type,
			"explanation": "Telegraphed ability.",
			"adapter_action": "telegraph"
		}
	)


func _resolve_decision(pending_telegraph: Dictionary) -> AiDecision:
	var marked_cell: Dictionary = pending_telegraph.get("marked_cell", {})
	var metadata: Dictionary = pending_telegraph.duplicate(true)
	metadata["adapter_action"] = "resolve"
	return AiDecision.new(
		&"larval_avatar",
		&"larval_avatar",
		&"resolve",
		120,
		["due_telegraph"],
		StringName(str(pending_telegraph.get("target_entity_id", "hero"))),
		BossBoardFixtureFactory.boss_slot_cell(),
		BossBoardFixtureFactory.boss_slot_cell(),
		Vector2i(int(marked_cell.get("x", -1)), int(marked_cell.get("y", -1))),
		&"",
		metadata
	)


func _move_decision(from_cell: Vector2i, to_cell: Vector2i) -> AiDecision:
	return AiDecision.new(
		&"larval_avatar",
		&"larval_avatar",
		&"move",
		50,
		["skitter"],
		&"hero",
		from_cell,
		to_cell,
		Vector2i(6, 9),
		&"",
		{"boss_action_id": "skitter", "adapter_action": "move"}
	)


func _wait_decision(reason: StringName) -> AiDecision:
	return AiDecision.new(
		&"larval_avatar",
		&"larval_avatar",
		&"wait",
		0,
		["no_legal_action"],
		&"",
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		reason,
		{"wait_reason": String(reason), "adapter_action": "wait"}
	)


func _pending_telegraph(marked_cell: Vector2i, due_turn_number: int, boss_action_id: String, damage: int, damage_type: String) -> Dictionary:
	return {
		"telegraph_id": "larval_avatar_telegraph:larval_avatar:1",
		"kind": PendingTelegraphState.KIND_LARVAL_AVATAR_TELEGRAPH,
		"source_entity_id": "larval_avatar",
		"target_entity_id": "hero",
		"boss_action_id": boss_action_id,
		"marked_cell": {"x": marked_cell.x, "y": marked_cell.y},
		"created_turn_number": 1,
		"due_turn_number": due_turn_number,
		"damage": damage,
		"damage_type": damage_type,
		"status": "pending"
	}


func _snapshot_dictionary(board: BoardState, streams: RngStreamSet, turn_state: TacticalTurnState, pending: Array[Dictionary]) -> Dictionary:
	var empty_log: Array[DomainEvent] = []
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams, turn_state.to_dictionary(), pending, empty_log)
	assert_true(result_value.succeeded, "Test helper should export a tactical snapshot.")
	var snapshot: TacticalSnapshot = result_value.metadata.get("snapshot") as TacticalSnapshot
	return snapshot.to_dictionary()
