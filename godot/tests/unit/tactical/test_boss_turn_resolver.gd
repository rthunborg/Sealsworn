extends "res://tests/unit/test_case.gd"

# Story 9.3 Task 5 — BossTurnResolver (the simulate-then-apply boss turn + the LIVE phase re-resolution seam,
# AC1/AC2/AC3/AC4; closes 9.2 review Low #1). Covers: the boss turn resolves through the simulate-then-apply discipline
# (the source is untouched until the events apply); the major dangerous ability emits a TELEGRAPH this turn BEFORE any
# damage (AC1), with a one-turn response window; a two-turn telegraph -> resolve applies deterministic damage naming the
# ability when the hero stays (AC4); an ESCAPED telegraph resolves avoided with NO damage; the live boss-HP drop across
# a 9.2 threshold re-resolves the phase and emits boss_phase_changed from the resolver's transition.to_payload() which
# validates + JSON-round-trips (closes 9.2 Low #1); the live boss entity's definition_id == the 9.1 slot id
# "larval_avatar" (the Task-8 cross-check); the same state reproduces the same events + decision (AC3).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossBoardFixtureFactory = preload("res://tests/fixtures/tactical/boss_board_fixture_factory.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossEncounterRequest = preload("res://scripts/generation/boss/boss_encounter_request.gd")
const BossTurnResolver = preload("res://scripts/tactical/turns/boss_turn_resolver.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PendingTelegraphState = preload("res://scripts/tactical/turns/pending_telegraph_state.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

func run() -> Dictionary:
	_boss_turn_telegraphs_before_any_damage()
	_two_turn_telegraph_then_resolve_applies_damage_naming_the_ability()
	_escaped_telegraph_resolves_avoided_with_no_damage()
	_live_hp_drop_emits_boss_phase_changed_from_the_resolver()
	_multi_threshold_hp_drop_emits_a_chain_of_phase_changes()
	_no_threshold_crossing_emits_no_phase_change()
	_live_boss_entity_fills_the_nine_one_slot_id()
	_boss_turn_is_reproducible_from_same_state()
	_lethal_hit_emits_boss_defeated_naming_the_boss_and_phase()
	_non_lethal_hit_emits_no_boss_defeated()
	_boss_defeated_event_round_trips()
	_sequence_id_seam_threads_a_shared_counter_across_interleaved_streams()
	return result()


func _boss_turn_telegraphs_before_any_damage() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var pending: Array[Dictionary] = []
	var context: TacticalActionContext = _context(board, RngStreamSet.new(300), pending, 1)
	var hero_hp_before: int = board.get_entity(&"hero").current_hp

	var result_value: ActionResult = _resolver().resolve_boss_turn(context)

	assert_true(result_value.succeeded, "The boss turn should resolve.")
	assert_equal(result_value.events.size(), 1, "The boss's opening turn emits one telegraph event (no damage).")
	assert_equal(result_value.events[0].event_type, DomainEvent.Type.TILE_MARKED, "The major dangerous ability telegraphs first (AC1).")
	assert_equal(board.get_entity(&"hero").current_hp, hero_hp_before, "The telegraph turn must not damage the hero (AC1 — telegraph before damage).")
	assert_equal(pending.size(), 1, "The telegraph stores one pending telegraph.")
	assert_equal(int(pending[0].get("due_turn_number", 0)), int(pending[0].get("created_turn_number", 0)) + 1, "The response window is a one-turn gap (AC1).")
	assert_equal(context.turn_state.turn_number, 2, "The boss turn advances the turn counter.")
	assert_equal(context.turn_state.phase, TacticalTurnState.Phase.PLAYER_PLANNING, "The boss turn returns control to the player.")


func _two_turn_telegraph_then_resolve_applies_damage_naming_the_ability() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var pending: Array[Dictionary] = []
	var context: TacticalActionContext = _context(board, RngStreamSet.new(301), pending, 1)

	# Turn 1: the boss telegraphs the hero's cell.
	var telegraph_result: ActionResult = _resolver().resolve_boss_turn(context)
	assert_true(telegraph_result.succeeded, "Turn 1 (telegraph) should resolve.")
	assert_equal(telegraph_result.events[0].event_type, DomainEvent.Type.TILE_MARKED, "Turn 1 emits the telegraph.")
	assert_equal(board.get_entity(&"hero").current_hp, 18, "Turn 1 deals no damage.")

	# Turn 2: the hero STAYED on the marked cell -> the telegraph resolves as a hit, damage lands.
	var resolve_result: ActionResult = _resolver().resolve_boss_turn(context)
	assert_true(resolve_result.succeeded, "Turn 2 (resolution) should resolve.")
	assert_equal(resolve_result.events[0].event_type, DomainEvent.Type.MARKED_TILE_DETONATED, "Turn 2 detonates the telegraph.")
	assert_equal(resolve_result.events[0].payload.get("outcome"), "hit", "The hero stayed on the marked cell -> hit.")
	assert_equal(resolve_result.events[1].event_type, DomainEvent.Type.DAMAGE_APPLIED, "A hit applies damage on the resolution turn.")
	assert_true(String(resolve_result.events[1].payload.get("explanation", "")).contains("lash"), "The damage explanation names the boss ability (AC4).")
	assert_equal(board.get_entity(&"hero").current_hp, 12, "The resolved lash deals 6 damage (18 - 6).")
	assert_equal(pending.size(), 0, "The resolved telegraph is cleared from pending.")


func _escaped_telegraph_resolves_avoided_with_no_damage() -> void:
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var pending: Array[Dictionary] = []
	var context: TacticalActionContext = _context(board, RngStreamSet.new(302), pending, 1)

	# Turn 1: the boss telegraphs (6,4).
	_resolver().resolve_boss_turn(context)
	assert_equal(pending.size(), 1, "Turn 1 stores the telegraph.")

	# The hero ESCAPES: move it off the marked cell (simulate the player's turn between telegraph and resolution).
	_move_hero(board, Vector2i(6, 4), Vector2i(7, 4))

	# Turn 2: the boss resolves the telegraph, but the hero is gone -> avoided, no damage.
	var resolve_result: ActionResult = _resolver().resolve_boss_turn(context)
	assert_true(resolve_result.succeeded, "Turn 2 (resolution after escape) should resolve.")
	assert_equal(resolve_result.events[0].event_type, DomainEvent.Type.MARKED_TILE_DETONATED, "Turn 2 still detonates the telegraph.")
	assert_equal(resolve_result.events[0].payload.get("outcome"), "avoided", "The escaped hero yields an avoided outcome.")
	assert_equal(resolve_result.events.size(), 1, "An avoided resolution emits no damage event.")
	assert_equal(board.get_entity(&"hero").current_hp, 18, "An escaped telegraph deals no damage.")
	assert_equal(pending.size(), 0, "The avoided telegraph is cleared from pending.")


func _live_hp_drop_emits_boss_phase_changed_from_the_resolver() -> void:
	# The boss starts at full HP (phase 0). A player/test hit drops it below the 60% threshold (36 * 0.6 = 21.6 -> 21).
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(303), [], 1)
	var previous_phase: int = _resolver().active_phase_index_for_hp(36)
	assert_equal(previous_phase, 0, "A full-HP boss is in phase 0 before the hit.")

	# Apply the player/test damage to the boss through a board event (dropping it to 20 HP -> phase 1).
	_damage_boss(board, 16)
	assert_equal(board.get_entity(&"larval_avatar").current_hp, 20, "The boss dropped to 20 HP (below the 60% threshold).")

	var result_value: ActionResult = _resolver().resolve_phase_transitions(context, previous_phase)

	assert_true(result_value.succeeded, "The live phase re-resolution should succeed.")
	assert_equal(result_value.events.size(), 1, "Crossing exactly one threshold emits one boss_phase_changed.")
	var event: DomainEvent = result_value.events[0]
	assert_equal(event.event_type, DomainEvent.Type.BOSS_PHASE_CHANGED, "The live seam emits a boss_phase_changed event.")
	assert_equal(int(event.payload.get("from_phase")), 0, "The change is from phase 0.")
	assert_equal(int(event.payload.get("to_phase")), 1, "The change is to phase 1 (adaptation).")
	assert_equal(String(event.payload.get("phase_id")), "adaptation", "The entered phase id rides the event.")
	assert_equal(int(result_value.metadata.get("active_phase_index", -1)), 1, "The boss is now in phase 1.")

	# Closes 9.2 Low #1: the resolver -> boss_phase_changed -> validate -> JSON round-trip loop, end to end.
	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parse_result.succeeded, "The live boss_phase_changed event must validate + JSON-round-trip: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(int(restored.payload.get("to_phase")), 1, "to_phase must survive the round-trip as an int.")
	assert_equal(String(restored.payload.get("phase_id")), "adaptation", "phase_id must survive the round-trip.")


func _multi_threshold_hp_drop_emits_a_chain_of_phase_changes() -> void:
	# One big hit drops the boss from full (phase 0) to 8 HP (below BOTH 60% and 25%) -> a chain 0->1 then 1->2.
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(304), [], 1)
	_damage_boss(board, 28)
	assert_equal(board.get_entity(&"larval_avatar").current_hp, 8, "The boss dropped to 8 HP (below the 25% threshold).")

	var result_value: ActionResult = _resolver().resolve_phase_transitions(context, 0)

	assert_true(result_value.succeeded, "The multi-threshold re-resolution should succeed.")
	assert_equal(result_value.events.size(), 2, "A multi-threshold crossing emits one phase change per phase entered.")
	assert_equal(int(result_value.events[0].payload.get("to_phase")), 1, "The first change enters phase 1.")
	assert_equal(int(result_value.events[1].payload.get("to_phase")), 2, "The second change enters phase 2 (no phase skipped).")
	# The chain's sequence ids are monotonic + unique within the step.
	assert_equal(result_value.events[1].sequence_id, result_value.events[0].sequence_id + 1, "The phase-change chain uses monotonic sequence ids.")


func _no_threshold_crossing_emits_no_phase_change() -> void:
	# A hit that does NOT cross the next threshold (36 -> 30, still above 60% * 36 = 21.6) emits no phase change.
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(305), [], 1)
	_damage_boss(board, 6)
	assert_equal(board.get_entity(&"larval_avatar").current_hp, 30, "The boss is at 30 HP (still phase 0).")

	var result_value: ActionResult = _resolver().resolve_phase_transitions(context, 0)

	assert_true(result_value.succeeded, "A no-crossing re-resolution should still succeed.")
	assert_equal(result_value.events.size(), 0, "No threshold crossed -> no boss_phase_changed event.")
	assert_equal(int(result_value.metadata.get("active_phase_index", -1)), 0, "The boss is still in phase 0.")


func _live_boss_entity_fills_the_nine_one_slot_id() -> void:
	# The Task-8 cross-check: the live boss entity id == the 9.1 arena slot id == the 9.2 definition id == the request id.
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var boss: Variant = board.get_entity(&"larval_avatar")

	assert_true(boss != null, "The live boss entity must exist on the arena board.")
	assert_equal(String(boss.definition_id), "larval_avatar", "The live boss definition_id fills the 9.1 slot id.")
	assert_equal(String(BossEncounterRequest.BOSS_ENTITY_ID), "larval_avatar", "The 9.1 request slot id is larval_avatar.")
	assert_equal(String(BossDefinition.BOSS_ID), "larval_avatar", "The 9.2 definition id is larval_avatar.")
	assert_equal(boss.max_hp, 36, "The live boss max_hp comes from the BossDefinition (36).")
	assert_equal(boss.position, BossBoardFixtureFactory.boss_slot_cell(), "The live boss sits at the reserved boss slot.")


func _boss_turn_is_reproducible_from_same_state() -> void:
	var first_board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var second_board: BoardState = BoardState.from_snapshot(first_board.to_snapshot())
	var first_pending: Array[Dictionary] = []
	var second_pending: Array[Dictionary] = []
	var first_context: TacticalActionContext = _context(first_board, RngStreamSet.new(306), first_pending, 1)
	var second_context: TacticalActionContext = _context(second_board, RngStreamSet.new(306), second_pending, 1)

	var first_result: ActionResult = _resolver().resolve_boss_turn(first_context)
	var second_result: ActionResult = _resolver().resolve_boss_turn(second_context)

	assert_true(first_result.succeeded and second_result.succeeded, "Both deterministic boss turns should succeed.")
	assert_equal(_event_dictionaries(first_result.events), _event_dictionaries(second_result.events), "Same state should reproduce the boss's events.")
	assert_equal(first_pending, second_pending, "Same state should reproduce the pending telegraph state.")
	assert_equal(first_result.metadata.get("decision"), second_result.metadata.get("decision"), "Same state should reproduce the boss decision explanation.")


# ---- Story 9.4 (AC1): the boss-defeat detection seam ----------------------------------------------

func _lethal_hit_emits_boss_defeated_naming_the_boss_and_phase() -> void:
	# Story 9.4 (AC1): a damaging event drops the boss to 0 HP -> detect_boss_defeat detects is_dead() and emits ONE
	# boss_defeated event naming the boss + its active phase at defeat (desperation, the deepest phase at 0 HP) + final_hp 0.
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(310), [], 1)
	assert_true(board.get_entity(&"larval_avatar").is_alive(), "Setup: the boss starts alive.")

	# Drop the boss to 0 HP (a lethal player/test hit).
	_damage_boss(board, 36)
	assert_true(board.get_entity(&"larval_avatar").is_dead(), "The boss is dead at 0 HP.")

	var result_value: ActionResult = _resolver().detect_boss_defeat(context)

	assert_true(result_value.succeeded, "The boss-defeat detection should succeed.")
	assert_true(bool(result_value.metadata.get("boss_defeated")), "The seam must report the boss as defeated.")
	assert_equal(result_value.events.size(), 1, "A lethal hit emits exactly one boss_defeated event.")
	var event: DomainEvent = result_value.events[0]
	assert_equal(event.event_type, DomainEvent.Type.BOSS_DEFEATED, "The seam emits a boss_defeated event.")
	assert_equal(String(event.payload.get("boss_entity_id")), "larval_avatar", "The boss_defeated event names the Larval Avatar.")
	assert_equal(String(event.payload.get("phase_id")), "desperation", "The boss died in its deepest phase (desperation, at 0 HP).")
	assert_equal(int(event.payload.get("final_hp")), 0, "The boss_defeated final_hp is 0 (a defeat).")
	assert_equal(String(event.actor_id), "", "boss_defeated is a system event with no actor (the boss is the subject).")


func _non_lethal_hit_emits_no_boss_defeated() -> void:
	# Story 9.4 (AC1): a NON-lethal hit leaves the boss alive -> detect_boss_defeat emits NOTHING (an empty event list; the
	# caller checks metadata.boss_defeated == false).
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(311), [], 1)
	_damage_boss(board, 10)  # 36 -> 26, still alive
	assert_true(board.get_entity(&"larval_avatar").is_alive(), "The boss survives a non-lethal hit.")

	var result_value: ActionResult = _resolver().detect_boss_defeat(context)

	assert_true(result_value.succeeded, "The boss-defeat detection should still succeed for a survivor.")
	assert_false(bool(result_value.metadata.get("boss_defeated")), "A non-lethal hit must NOT report the boss as defeated.")
	assert_equal(result_value.events.size(), 0, "A non-lethal hit emits NO boss_defeated event.")


func _boss_defeated_event_round_trips() -> void:
	# The boss_defeated event validates + JSON-round-trips (the int→float footgun: assert the SURVIVING typed final_hp after
	# parse_string, NOT a nested re-stringify).
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(312), [], 1)
	_damage_boss(board, 40)  # clamp to 0
	var result_value: ActionResult = _resolver().detect_boss_defeat(context)
	assert_equal(result_value.events.size(), 1, "Setup: a lethal hit emits boss_defeated.")
	var event: DomainEvent = result_value.events[0]

	var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parse_result.succeeded, "The boss_defeated event must validate + JSON-round-trip: %s" % parse_result.metadata)
	var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
	assert_equal(int(restored.payload.get("final_hp")), 0, "final_hp must survive the round-trip as an int (the int→float footgun).")
	assert_equal(String(restored.payload.get("phase_id")), "desperation", "phase_id must survive the round-trip.")


func _sequence_id_seam_threads_a_shared_counter_across_interleaved_streams() -> void:
	# Story 9.4 Task 8 (closes the 9.3 review Round-1 Med): 9.4 INTERLEAVES the boss phase-change events + the boss_defeated
	# event into ONE ordered append-only log. The seam contract (from 9.3) requires threading a shared monotonic
	# sequence_id_base cursor: pass an explicit base >= 0 to resolve_phase_transitions AND detect_boss_defeat, and thread the
	# returned next_sequence_id_after cursor. This test drives a big lethal hit (crossing BOTH phase thresholds AND killing
	# the boss), merges the phase-change chain + the boss_defeat into one stream via the shared cursor, and asserts EVERY
	# sequence id is UNIQUE (no duplicate ids — the bug the seam contract prevents).
	var board: BoardState = BossBoardFixtureFactory.boss_arena_hero_in_range()
	var context: TacticalActionContext = _context(board, RngStreamSet.new(313), [], 1)
	var resolver: BossTurnResolver = _resolver()

	# The shared monotonic run-level counter the merging caller owns (mirrors RunOrchestrator._next_sequence_id).
	var shared_cursor: int = 100

	# One big hit drops the boss from full (phase 0) to 0 HP -> a phase-change chain 0->1->2 THEN a boss_defeat.
	_damage_boss(board, 36)
	assert_true(board.get_entity(&"larval_avatar").is_dead(), "Setup: the boss is dead (a lethal hit past both thresholds).")

	# Stream 1: the phase-change chain, sequenced from the shared cursor. Thread the returned cursor forward.
	var phase_result: ActionResult = resolver.resolve_phase_transitions(context, 0, shared_cursor)
	assert_true(phase_result.succeeded, "The phase re-resolution should succeed.")
	shared_cursor = int(phase_result.metadata.get("next_sequence_id_after", shared_cursor))

	# Stream 2: the boss_defeat, sequenced from the ADVANCED shared cursor (no collision with the phase-change ids).
	var defeat_result: ActionResult = resolver.detect_boss_defeat(context, shared_cursor)
	assert_true(defeat_result.succeeded, "The boss-defeat detection should succeed.")
	shared_cursor = int(defeat_result.metadata.get("next_sequence_id_after", shared_cursor))

	# Merge both streams into ONE ordered log and assert every sequence id is UNIQUE (the seam contract's guarantee).
	var merged: Array[DomainEvent] = []
	merged.append_array(phase_result.events)
	merged.append_array(defeat_result.events)
	assert_true(merged.size() >= 3, "The merged stream should carry the phase-change chain (0->1, 1->2) + the boss_defeat (>= 3 events).")

	var seen_ids: Dictionary = {}
	for event: DomainEvent in merged:
		assert_false(seen_ids.has(event.sequence_id), "Every merged sequence id must be UNIQUE (no duplicate ids — the 9.3 Med closed): id %d repeated." % event.sequence_id)
		seen_ids[event.sequence_id] = true

	# The ids are monotonic + contiguous from the base (100, 101, 102 for the chain+defeat), and the cursor advanced past all.
	assert_equal(phase_result.events[0].sequence_id, 100, "The first phase-change event uses the shared base id (100).")
	assert_true(shared_cursor > merged[merged.size() - 1].sequence_id, "The threaded cursor advances PAST the last emitted id (the reserved-cursor contract).")


# ---- helpers -------------------------------------------------------------------------------------

func _resolver() -> BossTurnResolver:
	return BossTurnResolver.new(_definition(), &"larval_avatar", &"hero")


func _definition() -> BossDefinition:
	return BossBoardFixtureFactory.boss_definition()


func _context(board: BoardState, streams: RngStreamSet, pending: Array[Dictionary], turn_number: int) -> TacticalActionContext:
	var turn_state: TacticalTurnState = TacticalTurnState.new(turn_number, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	return TacticalActionContext.new(board, turn_state, streams, pending)


# Apply damage to the boss through a board damage_applied event (the player/test damage source — 9.3 does not build the
# live player-attack call site). Uses the hero as the actor (a real board entity) so the event validates.
func _damage_boss(board: BoardState, amount: int) -> void:
	var boss: Variant = board.get_entity(&"larval_avatar")
	var hp_before: int = boss.current_hp
	var hp_after: int = max(0, hp_before - amount)
	var event: DomainEvent = DomainEvent.damage_applied(
		board.next_sequence_id(),
		&"hero",
		&"larval_avatar",
		amount,
		hp_before,
		hp_after,
		boss.max_hp,
		{
			"weapon_id": "test_strike",
			"base_damage": amount,
			"final_damage": amount,
			"damage_type": "physical",
			"explanation": "Test damage to the boss."
		}
	)
	var apply_result: ActionResult = board.apply_events([event])
	assert_true(apply_result.succeeded, "Test boss damage should apply: %s" % apply_result.metadata)


func _move_hero(board: BoardState, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var event: DomainEvent = DomainEvent.entity_moved(board.next_sequence_id(), &"hero", from_cell, to_cell, 1, 1)
	var apply_result: ActionResult = board.apply_events([event])
	assert_true(apply_result.succeeded, "Test hero move should apply: %s" % apply_result.metadata)


func _event_dictionaries(events: Array[DomainEvent]) -> Array[Dictionary]:
	var result_value: Array[Dictionary] = []
	for event: DomainEvent in events:
		result_value.append(event.to_dictionary())
	return result_value
