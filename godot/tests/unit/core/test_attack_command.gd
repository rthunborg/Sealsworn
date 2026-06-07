extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const AttackPreviewContractMatrix = preload("res://tests/fixtures/tactical/attack_preview_contract_matrix.gd")
const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalSnapshot = preload("res://scripts/save/snapshots/tactical_snapshot.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

func run() -> Dictionary:
	_successful_attack_emits_attack_and_damage_events()
	_successful_attack_events_replay_to_matching_board_snapshot()
	_damage_clamps_to_zero_without_death_or_victory_events()
	_invalid_attack_cases_do_not_mutate()
	_preview_contract_target_legality_reasons_match_command()
	_tome_bonus_applies_after_adjacency_modifiers()
	_shield_armor_and_block_use_combat_rng()
	_axe_and_mace_procs_use_combat_rng_only_when_target_survives()
	_crossbow_knockback_applies_or_records_blocked_outcome()
	return result()


func _successful_attack_emits_attack_and_damage_events() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var streams: RngStreamSet = RngStreamSet.new(1001)
	var context: TacticalActionContext = _context(board, streams)
	var result_value: ActionResult = _command(&"sword", Vector2i(2, 1)).execute(context)

	assert_true(result_value.succeeded, "Legal sword attack should succeed.")
	assert_equal(result_value.events.size(), 2, "Base attacks should emit attack and damage events.")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.ENTITY_ATTACKED, "First attack event should record the committed attack.")
	assert_equal(result_value.events[1].event_type, DomainEvent.Type.DAMAGE_APPLIED, "Second attack event should apply damage.")
	assert_equal(result_value.events[0].sequence_id + 1, result_value.events[1].sequence_id, "Attack event sequence ids should be contiguous.")
	assert_equal(result_value.events[0].payload.get("target_entity_id"), "enemy_1", "Attack event should include visible target id.")
	assert_equal(result_value.events[0].payload.get("expected_base_damage"), 4, "Attack event should copy preview expected damage.")
	assert_equal(result_value.events[1].payload.get("amount"), 4, "Damage event should record final damage.")
	assert_equal(board.get_entity(&"enemy_1").current_hp, 6, "Successful attack should reduce target HP through BoardState event application.")
	assert_equal(result_value.metadata.get("advances_turn"), true, "Successful attacks should tell future turn flow to advance.")
	assert_equal(result_value.metadata.get("reason"), "valid", "Successful attacks should preserve valid reason metadata.")
	assert_equal(result_value.metadata.get("final_damage"), 4, "Result metadata should expose final damage.")


func _successful_attack_events_replay_to_matching_board_snapshot() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_survive_board()
	var replay_board: BoardState = BoardState.from_snapshot(board.to_snapshot())
	var streams: RngStreamSet = RngStreamSet.new(2026)
	var context: TacticalActionContext = _context(board, streams)

	var result_value: ActionResult = _command(&"sword", Vector2i(2, 1)).execute(context)
	var replay_result: ActionResult = replay_board.apply_events(result_value.events)

	assert_true(result_value.succeeded, "Valid attack should succeed before replay.")
	assert_true(replay_result.succeeded, "BoardState should replay attack command events.")
	assert_equal(replay_board.to_snapshot(), board.to_snapshot(), "Replayed attack events should reproduce the command-mutated board snapshot.")


func _damage_clamps_to_zero_without_death_or_victory_events() -> void:
	var board: BoardState = BoardFixtureFactory.attack_command_kill_board()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(99))

	var result_value: ActionResult = _command(&"sword", Vector2i(2, 1)).execute(context)

	assert_true(result_value.succeeded, "Legal lethal attack should succeed.")
	assert_equal(board.get_entity(&"enemy_1").current_hp, 0, "Damage should clamp target HP at zero.")
	assert_equal(result_value.events.size(), 2, "Lethal attacks should not add death/victory events in this story.")
	for event: DomainEvent in result_value.events:
		assert_false(String(DomainEvent.id_for_type(event.event_type)).contains("death"), "Story 1.9 should not emit death events.")
		assert_false(String(DomainEvent.id_for_type(event.event_type)).contains("victory"), "Story 1.9 should not emit victory events.")


func _invalid_attack_cases_do_not_mutate() -> void:
	_assert_invalid_attack(
		"invalid contexts should fail before any board lookup",
		BoardFixtureFactory.attack_command_survive_board(),
		AttackCommand.new(&"hero", Vector2i(2, 1), _weapon(&"sword")),
		null,
		"invalid_context"
	)
	_assert_invalid_attack(
		"invalid weapons should fail before actor lookup",
		BoardFixtureFactory.attack_command_survive_board(),
		AttackCommand.new(&"hero", Vector2i(2, 1), WeaponDefinition.new()),
		_context(BoardFixtureFactory.attack_command_survive_board(), RngStreamSet.new(42)),
		"invalid_weapon"
	)
	_assert_invalid_attack(
		"invalid support definitions should fail before actor lookup",
		BoardFixtureFactory.attack_command_survive_board(),
		AttackCommand.new(&"hero", Vector2i(2, 1), _weapon(&"sword"), SupportDefinition.new()),
		_context(BoardFixtureFactory.attack_command_survive_board(), RngStreamSet.new(42)),
		"invalid_support"
	)
	_assert_invalid_command_reason(BoardFixtureFactory.attack_command_survive_board(), &"missing_actor", Vector2i(2, 1), &"sword", "invalid_actor")
	_assert_invalid_command_reason(BoardFixtureFactory.attack_preview_dead_actor(), &"hero", Vector2i(2, 1), &"sword", "dead_actor")
	_assert_invalid_command_reason_with_phase(BoardFixtureFactory.attack_command_survive_board(), TacticalTurnState.Phase.ENEMY_PLANNING, &"hero", Vector2i(2, 1), &"sword", "wrong_phase")
	_assert_invalid_command_reason_with_active_actor(BoardFixtureFactory.attack_command_survive_board(), &"enemy_1", &"hero", Vector2i(2, 1), &"sword", "wrong_phase")
	_assert_invalid_command_reason(BoardFixtureFactory.attack_command_survive_board(), &"hero", Vector2i(1, 1), &"sword", "same_cell")
	_assert_invalid_command_reason(BoardFixtureFactory.attack_command_survive_board(), &"hero", Vector2i(9, 9), &"sword", "out_of_bounds")


func _preview_contract_target_legality_reasons_match_command() -> void:
	for contract: Dictionary in AttackPreviewContractMatrix.baseline_cases():
		if String(contract.get("expected_reason", "")) == "valid":
			continue
		var board: BoardState = _contract_board(String(contract.get("fixture", "")))
		var weapon_id: StringName = contract.get("weapon_id")
		var target_cell: Vector2i = contract.get("target_cell")
		var expected_reason: String = String(contract.get("expected_reason"))
		var result_value: ActionResult = _command(weapon_id, target_cell).execute(_context(board, RngStreamSet.new(710)))

		assert_true(result_value.is_error(), "Command should reject preview-contract case %s." % contract.get("id"))
		assert_equal(result_value.error_code, &"invalid_attack", "Invalid attack commands should use the stable command error code.")
		assert_equal(result_value.metadata.get("reason"), expected_reason, "Command and preview reason should match for %s." % contract.get("id"))
		if expected_reason == "not_visible":
			assert_false(result_value.metadata.has("target_entity_id"), "Hidden or memory command failures must not expose target ids.")
			assert_false(result_value.metadata.has("target_faction"), "Hidden or memory command failures must not expose target faction.")
			assert_false(result_value.metadata.has("current_hp"), "Hidden or memory command failures must not expose target HP.")


func _tome_bonus_applies_after_adjacency_modifiers() -> void:
	var staff_board: BoardState = BoardFixtureFactory.attack_command_tome_staff()
	var wand_board: BoardState = BoardFixtureFactory.attack_command_tome_wand()

	var staff_result: ActionResult = _command(&"staff", Vector2i(2, 1), &"tome").execute(_context(staff_board, RngStreamSet.new(1)))
	var wand_result: ActionResult = _command(&"wand", Vector2i(2, 1), &"tome").execute(_context(wand_board, RngStreamSet.new(1)))

	assert_true(staff_result.succeeded, "Staff Tome attack should succeed.")
	assert_true(wand_result.succeeded, "Wand Tome attack should succeed.")
	assert_equal(staff_result.metadata.get("base_damage"), 2, "Staff adjacent base damage should be preview-adjusted before Tome.")
	assert_equal(staff_result.metadata.get("support_bonus_damage"), 1, "Tome should add one damage to Staff.")
	assert_equal(staff_result.metadata.get("final_damage"), 3, "Staff adjacent Tome attack should deal 3 damage.")
	assert_equal(wand_result.metadata.get("base_damage"), 2, "Wand base damage should remain 2 before Tome.")
	assert_equal(wand_result.metadata.get("support_bonus_damage"), 1, "Tome should add one damage to Wand.")
	assert_equal(wand_result.metadata.get("final_damage"), 3, "Wand Tome attack should deal 3 damage.")


func _shield_armor_and_block_use_combat_rng() -> void:
	var block_seed: int = _seed_for_threshold(0.5, true)
	var no_block_seed: int = _seed_for_threshold(0.5, false)
	var block_board: BoardState = BoardFixtureFactory.attack_command_shield_block()
	var no_block_board: BoardState = BoardFixtureFactory.attack_command_shield_no_block()
	var block_streams: RngStreamSet = RngStreamSet.new(block_seed)
	var no_block_streams: RngStreamSet = RngStreamSet.new(no_block_seed)
	var block_before: Dictionary = block_streams.to_snapshot()
	var no_block_before: Dictionary = no_block_streams.to_snapshot()

	var block_result: ActionResult = _command(&"sword", Vector2i(2, 1), &"none", &"shield").execute(_context(block_board, block_streams))
	var no_block_result: ActionResult = _command(&"sword", Vector2i(2, 1), &"none", &"shield").execute(_context(no_block_board, no_block_streams))

	assert_true(block_result.succeeded, "Shield block-seed attack should succeed.")
	assert_true(no_block_result.succeeded, "Shield no-block-seed attack should succeed.")
	assert_equal(block_result.metadata.get("armor_reduction"), 1, "Shield should reduce physical damage by armor first.")
	assert_equal(block_result.metadata.get("block_succeeded"), true, "Block seed should produce a successful shield block.")
	assert_equal(block_result.metadata.get("final_damage"), 1, "Shield block should floor half post-armor damage and keep minimum successful damage at one.")
	assert_equal(no_block_result.metadata.get("block_succeeded"), false, "No-block seed should produce a failed shield block.")
	assert_equal(no_block_result.metadata.get("final_damage"), 3, "Failed shield block should still apply armor reduction.")
	assert_equal((block_result.metadata.get("rng_draws", []) as Array).size(), 1, "Shield block should record one combat RNG draw.")
	assert_equal((block_result.metadata.get("rng_draws", []) as Array)[0].get("effect_id"), "shield_block", "Shield RNG draw should identify the effect.")
	_assert_only_combat_advanced(block_before, block_streams.to_snapshot(), 1, "Shield block should use only the combat RNG stream.")
	_assert_only_combat_advanced(no_block_before, no_block_streams.to_snapshot(), 1, "Shield no-block should use only the combat RNG stream.")


func _axe_and_mace_procs_use_combat_rng_only_when_target_survives() -> void:
	var success_seed: int = _seed_for_threshold(0.35, true)
	var failure_seed: int = _seed_for_threshold(0.35, false)
	var axe_board: BoardState = BoardFixtureFactory.attack_command_proc()
	var mace_board: BoardState = BoardFixtureFactory.attack_command_proc()
	var kill_board: BoardState = BoardFixtureFactory.attack_command_kill_board()
	var axe_streams: RngStreamSet = RngStreamSet.new(success_seed)
	var mace_streams: RngStreamSet = RngStreamSet.new(failure_seed)
	var kill_streams: RngStreamSet = RngStreamSet.new(success_seed)
	var kill_before: Dictionary = kill_streams.to_snapshot()

	var axe_result: ActionResult = _command(&"axe", Vector2i(2, 1)).execute(_context(axe_board, axe_streams))
	var mace_result: ActionResult = _command(&"mace", Vector2i(2, 1)).execute(_context(mace_board, mace_streams))
	var kill_result: ActionResult = _command(&"axe", Vector2i(2, 1)).execute(_context(kill_board, kill_streams))

	assert_true(axe_result.succeeded, "Axe proc attack should succeed.")
	assert_true(mace_result.succeeded, "Mace proc attack should succeed.")
	assert_equal(axe_result.events.size(), 3, "Successful Axe proc should emit a status event after damage.")
	assert_equal(axe_result.events[2].event_type, DomainEvent.Type.STATUS_EFFECT_APPLIED, "Axe success should emit a status effect event.")
	assert_equal(axe_result.events[2].payload.get("effect_id"), "bleed", "Axe success should apply bleed.")
	assert_equal(mace_result.events.size(), 2, "Failed Mace proc should not emit a status event.")
	assert_equal((mace_result.metadata.get("rng_draws", []) as Array)[0].get("effect_id"), "disorient", "Mace proc metadata should record disorient roll outcome.")
	assert_true(kill_result.succeeded, "Killing Axe attack should succeed.")
	assert_equal(kill_result.events.size(), 2, "Axe should not roll or emit bleed when target does not survive base damage.")
	assert_equal(kill_streams.to_snapshot(), kill_before, "Kill attacks should not advance combat RNG for skipped survive-only procs.")


func _crossbow_knockback_applies_or_records_blocked_outcome() -> void:
	var open_board: BoardState = BoardFixtureFactory.attack_command_knockback_open()
	var blocked_board: BoardState = BoardFixtureFactory.attack_command_knockback_blocked()

	var open_result: ActionResult = _command(&"crossbow", Vector2i(2, 1)).execute(_context(open_board, RngStreamSet.new(1)))
	var blocked_result: ActionResult = _command(&"crossbow", Vector2i(2, 1)).execute(_context(blocked_board, RngStreamSet.new(1)))

	assert_true(open_result.succeeded, "Crossbow open knockback should succeed.")
	assert_equal(open_result.events.size(), 3, "Open crossbow knockback should emit a knockback event after damage.")
	assert_equal(open_result.events[2].event_type, DomainEvent.Type.ENTITY_KNOCKED_BACK, "Crossbow open result should emit knockback.")
	assert_equal(open_board.get_entity(&"enemy_1").position, Vector2i(3, 1), "Crossbow knockback should move surviving targets one cell away.")
	assert_true(blocked_result.succeeded, "Crossbow blocked knockback should still resolve damage.")
	assert_equal(blocked_result.events.size(), 2, "Blocked crossbow knockback should not emit a movement event.")
	assert_equal(blocked_result.metadata.get("knockback_succeeded"), false, "Blocked crossbow metadata should record failed knockback.")
	assert_equal(blocked_result.metadata.get("knockback_blocked_reason"), "blocked", "Blocked crossbow metadata should explain the blocked outcome.")
	assert_equal(blocked_board.get_entity(&"enemy_1").position, Vector2i(2, 1), "Blocked knockback should not move the target.")


func _assert_invalid_command_reason(
	board: BoardState,
	actor_id: StringName,
	target_cell: Vector2i,
	weapon_id: StringName,
	expected_reason: String
) -> void:
	_assert_invalid_command_reason_with_phase(board, TacticalTurnState.Phase.PLAYER_PLANNING, actor_id, target_cell, weapon_id, expected_reason)


func _assert_invalid_command_reason_with_phase(
	board: BoardState,
	phase: int,
	actor_id: StringName,
	target_cell: Vector2i,
	weapon_id: StringName,
	expected_reason: String
) -> void:
	_assert_invalid_command_reason_with_active_actor(board, actor_id, actor_id, target_cell, weapon_id, expected_reason, phase)


func _assert_invalid_command_reason_with_active_actor(
	board: BoardState,
	active_actor_id: StringName,
	actor_id: StringName,
	target_cell: Vector2i,
	weapon_id: StringName,
	expected_reason: String,
	phase: int = TacticalTurnState.Phase.PLAYER_PLANNING
) -> void:
	var streams: RngStreamSet = RngStreamSet.new(42)
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, phase, active_actor_id)
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams)
	var event_log: Array[DomainEvent] = []
	var before: Dictionary = _tactical_snapshot_dictionary(board, streams, turn_state, event_log)
	var sequence_before: int = board.next_sequence_id()
	var rng_before: Dictionary = streams.to_snapshot()
	var command: Variant = AttackCommand.new(actor_id, target_cell, _weapon(weapon_id))

	var result_value: ActionResult = command.execute(context)

	assert_true(result_value.is_error(), "Invalid attack should reject %s." % expected_reason)
	assert_equal(result_value.error_code, &"invalid_attack", "Invalid attack should use stable command error.")
	assert_equal(result_value.metadata.get("reason"), expected_reason, "Invalid attack should expose stable reason.")
	assert_false(result_value.has_events(), "Invalid attack should not emit events.")
	assert_equal(_tactical_snapshot_dictionary(board, streams, turn_state, event_log), before, "Invalid attack %s should not mutate tactical snapshots." % expected_reason)
	assert_equal(board.next_sequence_id(), sequence_before, "Invalid attack %s should not advance board sequence ids." % expected_reason)
	assert_equal(streams.to_snapshot(), rng_before, "Invalid attack %s should not advance RNG streams." % expected_reason)


func _assert_invalid_attack(
	message: String,
	board: BoardState,
	command: Variant,
	context: Variant,
	expected_reason: String
) -> void:
	var observed_board: BoardState = board
	if context is TacticalActionContext and (context as TacticalActionContext).board != null:
		observed_board = (context as TacticalActionContext).board
	var before: Dictionary = observed_board.to_snapshot()
	var result_value: ActionResult = command.execute(context)

	assert_true(result_value.is_error(), message)
	assert_equal(result_value.error_code, &"invalid_attack", message)
	assert_equal(result_value.metadata.get("reason"), expected_reason, message)
	assert_false(result_value.has_events(), message)
	assert_equal(observed_board.to_snapshot(), before, "%s should not mutate board state." % message)


func _command(
	weapon_id: StringName,
	target_cell: Vector2i,
	attacker_support_id: StringName = &"none",
	defender_support_id: StringName = &"none"
) -> Variant:
	return AttackCommand.new(
		&"hero",
		target_cell,
		_weapon(weapon_id),
		_support(attacker_support_id),
		_support(defender_support_id)
	)


func _context(board: BoardState, streams: RngStreamSet) -> TacticalActionContext:
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	return TacticalActionContext.new(board, turn_state, streams)


func _weapon(weapon_id: StringName) -> WeaponDefinition:
	return WeaponRepository.create_baseline_repository().get_weapon(weapon_id)


func _support(support_id: StringName) -> SupportDefinition:
	return SupportRepository.create_baseline_repository().get_support(support_id)


func _contract_board(fixture_name: String) -> BoardState:
	match fixture_name:
		"attack_preview_open_lane":
			return BoardFixtureFactory.attack_preview_open_lane()
		"attack_preview_adjacent_enemy":
			return BoardFixtureFactory.attack_preview_adjacent_enemy()
		"attack_preview_blocked_lane":
			return BoardFixtureFactory.attack_preview_blocked_lane()
		"attack_preview_diagonal_enemy":
			return BoardFixtureFactory.attack_preview_diagonal_enemy()
		"attack_preview_empty_target":
			return BoardFixtureFactory.attack_preview_empty_target()
		"attack_preview_hidden_enemy":
			return BoardFixtureFactory.attack_preview_hidden_enemy()
		"attack_preview_memory_enemy":
			return BoardFixtureFactory.attack_preview_memory_enemy()
		"attack_preview_dead_target":
			return BoardFixtureFactory.attack_preview_dead_target()
		"attack_preview_friendly_target":
			return BoardFixtureFactory.attack_preview_friendly_target()
		_:
			return null


func _seed_for_threshold(threshold: float, should_succeed: bool) -> int:
	for seed: int in range(1, 512):
		var streams: RngStreamSet = RngStreamSet.new(seed)
		var roll_result: ActionResult = streams.rand_float(RngStreamSet.STREAM_COMBAT, {"test": "seed_search"})
		var roll_value: float = float(roll_result.metadata.get("value", 1.0))
		if (roll_value <= threshold) == should_succeed:
			return seed
	return -1


func _assert_only_combat_advanced(before: Dictionary, after: Dictionary, expected_combat_delta: int, message: String) -> void:
	for stream_name: StringName in RngStreamSet.required_streams():
		var stream_key: String = String(stream_name)
		var before_index: int = int(before.get("streams", {}).get(stream_key, {}).get("draw_index", -1))
		var after_index: int = int(after.get("streams", {}).get(stream_key, {}).get("draw_index", -1))
		if stream_name == RngStreamSet.STREAM_COMBAT:
			assert_equal(after_index, before_index + expected_combat_delta, message)
		else:
			assert_equal(after_index, before_index, message)


func _tactical_snapshot_dictionary(
	board: BoardState,
	streams: RngStreamSet,
	turn_state: TacticalTurnState,
	event_log: Array[DomainEvent]
) -> Dictionary:
	var result_value: ActionResult = TacticalSnapshot.from_domain(board, streams, turn_state.to_dictionary(), [], event_log)
	assert_true(result_value.succeeded, "Test helper should export a top-level tactical snapshot.")
	var snapshot: TacticalSnapshot = result_value.metadata.get("snapshot") as TacticalSnapshot
	return snapshot.to_dictionary()
