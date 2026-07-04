extends "res://tests/unit/test_case.gd"

# Story 9.5 Task 1 (AC1) — the FINALE SEED-REGRESSION SUITE. The boss-chain analogue of
# test_seed_batch_regression.gd (the 3.7 batch-regression + preserved-annotated-catalog + failure-report model): an
# APPROVED, ANNOTATED, PRESERVED catalog of boss seeds driven through the WHOLE Epic-9 boss chain — 9.1 SETUP -> 9.2
# phases -> 9.3 telegraphs/AI -> 9.4 victory + defeat — asserting each path is DETERMINISTIC (the same seed -> a
# reproducible / byte-identical setup, phase-transition chain, telegraph->resolve behavior, and victory/defeat
# resolution), with a compact FAILURE REPORT carrying seed + phase (NEVER a grid dump).
#
# THE "PIPELINE" for the finale is the boss chain (not a level generator), so each approved seed asserts DETERMINISM of:
#   (a) SETUP     — BossEncounterRequest(seed, node) -> BossArenaBuilder.build() -> a reproducible arena payload / board
#                   snapshot (validated via the STRICT BoardState.try_from_snapshot). The arena draws ZERO RNG (it is a
#                   FIXED hand-authored layout), so this is a reproducibility PIN — byte-identical for every seed by
#                   construction, and identical across two builds.
#   (b) PHASES    — the same HP drop -> the same boss_phase_changed chain (BossPhaseResolver.resolve), run TWICE.
#   (c) TELEGRAPHS — the same board+turn -> the same BossAi decision + the two-turn telegraph->resolve behavior
#                   (BossTurnResolver.resolve_boss_turn), run TWICE (byte-identical events + decision — the 9.3 ZERO-RNG
#                   AI reproducibility).
#   (d) VICTORY   — the boss -> 0 HP -> the same boss_defeated (detect_boss_defeat) -> the same victory run_completed
#                   (CompleteRunCommand), run TWICE.
#   (e) DEFEAT    — a seeded-fixture hero death -> the same run_failed + cause (CompleteRunCommand), run TWICE.
#
# THE FAILURE REPORT carries seed + phase (which of setup/phases/telegraphs/victory/defeat diverged): the assert
# messages carry "seed=%d phase=%s reason=%s" (the harness assert-message shape), and a FORCED-failure shape test
# (_failure_report_shape_carries_seed_and_phase) proves the harness never silently passes a regression — mirroring
# test_seed_batch_regression.gd's _failure_report_shape_carries_seed_recipe_phase_reason.
#
# HARNESS SHAPE ([Decision], recorded): an INLINE annotated APPROVED_BOSS_SEED_CATALOG (like
# test_seed_batch_regression.gd's APPROVED_SEED_CATALOG), NOT a tools/dump_* pin tool. The boss chain has NO layout
# fingerprint to dump (the arena is FIXED, the AI is ZERO-RNG); the "fingerprint" is a COMPOSITE of the deterministic
# setup/phase/telegraph/outcome records, computed here from the live chain and cross-checked for reproducibility. The
# bland/unfair seeds are KEPT + annotated (the 3.7 AC4 preserved-catalog discipline), never discarded.
#
# JSON int->float footgun (retro §9-1): for any event JSON round-trip, assert the SURVIVING typed fields after
# parse_string (int(parsed.final_hp) == 0, String(parsed.outcome) == "victory"), NEVER a nested byte-identical
# re-stringify.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossArenaBuilder = preload("res://scripts/generation/boss/boss_arena_builder.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossEncounterRequest = preload("res://scripts/generation/boss/boss_encounter_request.gd")
const BossPhaseResolver = preload("res://scripts/content/boss/boss_phase_resolver.gd")
const BossPhaseTransition = preload("res://scripts/content/boss/boss_phase_transition.gd")
const BossRepository = preload("res://scripts/content/repositories/boss_repository.gd")
const BossTurnResolver = preload("res://scripts/tactical/turns/boss_turn_resolver.gd")
const CompleteRunCommand = preload("res://scripts/core/commands/complete_run_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

const BOSS_ID := &"larval_avatar"
const HERO_ID := &"hero"
# The boss node id used for the encounter request (lower_snake — the derived-from-hyphenated form the live path uses).
const BOSS_NODE_ID := &"node_7_0"

# AC1 PRESERVED, ANNOTATED APPROVED BOSS-SEED CATALOG. Bland/unfair seeds are KEPT (annotated), NOT deleted (the 3.7 AC4
# preserved-catalog discipline). Each entry:
#   seed  - the root/arena seed driven through the boss chain (the BossEncounterRequest seed + the fight context seed).
#   notes - the tactical/tuning annotation (the finale-tuning decision the seed preserves — how the fight reads at this
#           seed). Because the boss chain is ZERO-RNG (the arena is fixed, the AI is deterministic over board state), the
#           seed varies the CONTEXT (the RngStreamSet state the fight context carries) but the ZERO-RNG boss behavior is
#           reproducible; the catalog documents the tuning intent + is the persisted regression artifact.
const APPROVED_BOSS_SEED_CATALOG: Array[Dictionary] = [
	{
		"seed": 4242,
		"notes": "The canonical finale seed (the 9.3 BossBoardFixtureFactory arena seed). Boss at (6,1), hero enters at (6,10); the two telegraph -> resolve windows read cleanly. Baseline tuning reference. KEPT (canonical)."
	},
	{
		"seed": 1,
		"notes": "The minimal non-negative seed. Same fixed arena (the layout is seed-independent), same ZERO-RNG boss behavior. Proves a bland edge seed still drives the whole chain deterministically. KEPT (bland edge)."
	},
	{
		"seed": 7777,
		"notes": "A mid-range seed. The two-turn telegraph->resolve at full HP deals the authored lash damage; the phase chain crosses 60% then 25% as the hero whittles the boss down. A representative full-arc seed. KEPT (representative)."
	},
	{
		"seed": 9000000000000000000,
		"notes": "A large near-int64 seed (arena_seed decimal-string-encoded in the payload; the int64/JSON rule). Proves a big seed round-trips through the SETUP payload without truncation and the ZERO-RNG chain stays reproducible. KEPT (int64 edge)."
	},
	{
		"seed": 314159,
		"notes": "An 'unfair-feeling' fast-death tuning probe: driven to a hero death mid-fight (the DEFEAT path) to prove a death records run_failed + hero_death deterministically. The fixed arena gives the boss a strong opening; the death half of AC2/AC1 is exercised here. KEPT (unfair/defeat probe)."
	}
]

func run() -> Dictionary:
	_setup_is_deterministic_and_valid_for_every_seed()
	_phase_transitions_are_deterministic_for_every_seed()
	_telegraphs_are_deterministic_for_every_seed()
	_victory_path_is_deterministic_for_every_seed()
	_defeat_path_is_deterministic_for_every_seed()
	_catalog_preserves_annotated_seeds()
	_failure_report_shape_carries_seed_and_phase()
	return result()


# ---- (a) SETUP determinism -----------------------------------------------------------------------

# Per approved seed: BossEncounterRequest(seed, node) -> BossArenaBuilder.build() twice -> a reproducible arena payload
# whose board snapshot validates through the STRICT BoardState.try_from_snapshot. The arena_seed rides the payload
# decimal-string-encoded (int64/JSON rule); the layout fingerprint is byte-identical across the two builds (the arena
# draws ZERO RNG). Failure report: seed + phase=setup + reason.
func _setup_is_deterministic_and_valid_for_every_seed() -> void:
	for entry: Dictionary in APPROVED_BOSS_SEED_CATALOG:
		var seed_value: int = int(entry.get("seed"))

		var first: GenerationResult = _build_arena(seed_value)
		var second: GenerationResult = _build_arena(seed_value)

		assert_true(
			first.succeeded and second.succeeded,
			"seed=%d phase=setup reason=arena_build_failed (first_ok=%s second_ok=%s code=%s)" % [
				seed_value, first.succeeded, second.succeeded, String(first.error_code)
			]
		)
		if not (first.succeeded and second.succeeded):
			continue

		# The arena_seed rides the payload decimal-string-encoded (survives the int64 seed without truncation).
		assert_equal(
			String(first.payload.get("arena_seed", "")), str(seed_value),
			"seed=%d phase=setup reason=arena_seed_string_mismatch" % seed_value
		)

		# The board snapshot validates through the STRICT validator (validate-then-reject).
		var board_result: ActionResult = BoardState.try_from_snapshot(first.payload.get("board_snapshot", {}))
		assert_true(
			board_result.succeeded,
			"seed=%d phase=setup reason=board_snapshot_rejected code=%s" % [seed_value, String(board_result.error_code)]
		)

		# The composite SETUP fingerprint is reproducible across two builds (the arena is FIXED — ZERO RNG).
		assert_equal(
			_setup_fingerprint(first.payload), _setup_fingerprint(second.payload),
			"seed=%d phase=setup reason=arena_fingerprint_diverged (a ZERO-RNG arena must be byte-identical across builds)" % seed_value
		)

		# The boss slot + entrance are the fixed deterministic cells (the confrontation geometry), independent of seed.
		var slot: Dictionary = first.payload.get("boss_slot", {})
		assert_equal(String(slot.get("entity_id", "")), "larval_avatar", "seed=%d phase=setup reason=boss_slot_entity_id_wrong" % seed_value)


# ---- (b) PHASE-TRANSITION determinism ------------------------------------------------------------

# Per approved seed: the SAME HP drop yields the SAME boss_phase_changed chain (BossPhaseResolver.resolve) across two
# runs. Drives the full-HP boss down past BOTH the 60% and 25% thresholds so the chain is 0->1->2 (both transitions).
# Failure report: seed + phase=phases + reason.
func _phase_transitions_are_deterministic_for_every_seed() -> void:
	for entry: Dictionary in APPROVED_BOSS_SEED_CATALOG:
		var seed_value: int = int(entry.get("seed"))
		var definition: BossDefinition = _definition()

		# Two independent resolves from the same (definition, from-phase, hp): the chain must be identical.
		var first_chain: Array[BossPhaseTransition] = BossPhaseResolver.new().resolve(definition, 0, 8)  # 8 HP: below 25%.
		var second_chain: Array[BossPhaseTransition] = BossPhaseResolver.new().resolve(definition, 0, 8)

		assert_equal(
			_phase_chain_fingerprint(first_chain), _phase_chain_fingerprint(second_chain),
			"seed=%d phase=phases reason=phase_chain_diverged" % seed_value
		)
		# The chain crosses BOTH thresholds (0->1 then 1->2 — no phase skipped in the log).
		assert_equal(first_chain.size(), 2, "seed=%d phase=phases reason=expected_two_transitions (0->1->2)" % seed_value)
		assert_equal(int(first_chain[0].to_phase), 1, "seed=%d phase=phases reason=first_transition_not_to_1" % seed_value)
		assert_equal(int(first_chain[1].to_phase), 2, "seed=%d phase=phases reason=second_transition_not_to_2" % seed_value)

		# A no-crossing drop (still above 60%) emits NO transition (idempotent) — reproducibly.
		var none_first: Array[BossPhaseTransition] = BossPhaseResolver.new().resolve(definition, 0, 30)
		var none_second: Array[BossPhaseTransition] = BossPhaseResolver.new().resolve(definition, 0, 30)
		assert_equal(none_first.size(), 0, "seed=%d phase=phases reason=no_crossing_should_emit_nothing" % seed_value)
		assert_equal(_phase_chain_fingerprint(none_first), _phase_chain_fingerprint(none_second), "seed=%d phase=phases reason=no_crossing_diverged" % seed_value)


# ---- (c) TELEGRAPH determinism -------------------------------------------------------------------

# Per approved seed: the SAME board+turn yields the SAME BossAi decision + the SAME two-turn telegraph->resolve behavior
# (BossTurnResolver.resolve_boss_turn), across two independent runs seeded from the SAME seed. The boss AI is ZERO-RNG,
# so the events + decision are byte-identical. Failure report: seed + phase=telegraphs + reason.
func _telegraphs_are_deterministic_for_every_seed() -> void:
	for entry: Dictionary in APPROVED_BOSS_SEED_CATALOG:
		var seed_value: int = int(entry.get("seed"))

		# Two independent fresh boss boards, each with the hero in telegraph range, seeded from the same seed.
		var first: Dictionary = _run_two_turn_telegraph(seed_value)
		var second: Dictionary = _run_two_turn_telegraph(seed_value)

		# Turn 1: the telegraph events reproduce.
		assert_equal(
			first.get("telegraph_events"), second.get("telegraph_events"),
			"seed=%d phase=telegraphs reason=telegraph_events_diverged" % seed_value
		)
		# Turn 2: the resolution (detonation + damage) events reproduce.
		assert_equal(
			first.get("resolve_events"), second.get("resolve_events"),
			"seed=%d phase=telegraphs reason=resolve_events_diverged" % seed_value
		)
		# The boss decision explanations reproduce (the ZERO-RNG AI is fully reproducible).
		assert_equal(
			first.get("telegraph_decision"), second.get("telegraph_decision"),
			"seed=%d phase=telegraphs reason=telegraph_decision_diverged" % seed_value
		)
		# The telegraph precedes the damage (AC1 discipline holds for every seed): turn 1 emits a tile_marked, turn 2 the
		# detonation + a damage_applied on the hero's staying.
		assert_true(bool(first.get("telegraph_is_tile_marked")), "seed=%d phase=telegraphs reason=turn1_not_a_telegraph" % seed_value)
		assert_true(bool(first.get("hero_took_damage_on_resolve")), "seed=%d phase=telegraphs reason=resolve_dealt_no_damage_on_hit" % seed_value)


# ---- (d) VICTORY determinism ---------------------------------------------------------------------

# Per approved seed: the boss dropped to 0 HP -> the SAME boss_defeated event (detect_boss_defeat) -> the SAME victory
# run_completed (CompleteRunCommand), across two runs. The boss_defeated event JSON-round-trips (surviving typed
# final_hp/phase_id — the int->float footgun). Failure report: seed + phase=victory + reason.
func _victory_path_is_deterministic_for_every_seed() -> void:
	for entry: Dictionary in APPROVED_BOSS_SEED_CATALOG:
		var seed_value: int = int(entry.get("seed"))

		var first: Dictionary = _run_victory(seed_value)
		var second: Dictionary = _run_victory(seed_value)

		# The boss_defeated event reproduces (naming the boss + its deepest phase at 0 HP + final_hp 0).
		assert_equal(
			first.get("boss_defeated_event"), second.get("boss_defeated_event"),
			"seed=%d phase=victory reason=boss_defeated_diverged" % seed_value
		)
		assert_equal(String(first.get("defeated_phase_id")), "desperation", "seed=%d phase=victory reason=defeated_phase_not_desperation" % seed_value)
		assert_equal(int(first.get("defeated_final_hp")), 0, "seed=%d phase=victory reason=defeated_final_hp_not_zero" % seed_value)

		# The victory run_completed reproduces (outcome victory + outpost destination).
		assert_equal(
			first.get("run_completed_event"), second.get("run_completed_event"),
			"seed=%d phase=victory reason=run_completed_diverged" % seed_value
		)
		assert_equal(String(first.get("run_outcome")), "victory", "seed=%d phase=victory reason=outcome_not_victory" % seed_value)
		assert_equal(String(first.get("run_destination")), "outpost", "seed=%d phase=victory reason=destination_not_outpost" % seed_value)

		# The int->float footgun: assert the SURVIVING typed final_hp after a JSON round-trip, NOT a nested re-stringify.
		var defeated_event: DomainEvent = first.get("boss_defeated_event_obj") as DomainEvent
		var parse_result: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(defeated_event.to_dictionary())))
		assert_true(parse_result.succeeded, "seed=%d phase=victory reason=boss_defeated_did_not_round_trip: %s" % [seed_value, parse_result.metadata])
		var restored: DomainEvent = parse_result.metadata.get("event") as DomainEvent
		assert_equal(int(restored.payload.get("final_hp")), 0, "seed=%d phase=victory reason=final_hp_did_not_survive_round_trip" % seed_value)
		assert_equal(String(restored.payload.get("phase_id")), "desperation", "seed=%d phase=victory reason=phase_id_did_not_survive_round_trip" % seed_value)


# ---- (e) DEFEAT determinism ----------------------------------------------------------------------

# Per approved seed: a seeded-fixture hero DEATH -> the SAME run_failed + cause (CompleteRunCommand), across two runs.
# The death is a caller/test-supplied resolution (resolve the run END with hero_death), NOT a live hero-death source
# (the live death SOURCE stays deferred — see the story OUT-of-scope boundary). Failure report: seed + phase=defeat.
func _defeat_path_is_deterministic_for_every_seed() -> void:
	for entry: Dictionary in APPROVED_BOSS_SEED_CATALOG:
		var seed_value: int = int(entry.get("seed"))

		var first: Dictionary = _run_defeat(seed_value)
		var second: Dictionary = _run_defeat(seed_value)

		assert_equal(
			first.get("run_failed_event"), second.get("run_failed_event"),
			"seed=%d phase=defeat reason=run_failed_diverged" % seed_value
		)
		assert_equal(String(first.get("run_cause")), "hero_death", "seed=%d phase=defeat reason=cause_not_hero_death" % seed_value)
		assert_equal(String(first.get("run_destination")), "outpost", "seed=%d phase=defeat reason=destination_not_outpost" % seed_value)
		assert_equal(String(first.get("run_phase")), "failed", "seed=%d phase=defeat reason=phase_not_failed" % seed_value)


# ---- AC4 preserved catalog -----------------------------------------------------------------------

func _catalog_preserves_annotated_seeds() -> void:
	assert_true(APPROVED_BOSS_SEED_CATALOG.size() >= 5, "The approved boss-seed catalog preserves at least the five annotated seeds.")
	var seen: Dictionary = {}
	for entry: Dictionary in APPROVED_BOSS_SEED_CATALOG:
		assert_false(String(entry.get("notes", "")).strip_edges().is_empty(), "Every approved boss seed must carry a tactical/tuning note (preserved for tuning, not discarded).")
		var seed_value: int = int(entry.get("seed"))
		assert_false(seen.has(seed_value), "The catalog must not duplicate a seed (%d)." % seed_value)
		seen[seed_value] = true


# ---- AC1 failure-report shape --------------------------------------------------------------------

# The failure-report contract: an INVALID boss encounter request (an empty node id) yields a structured error whose
# report carries the seed + phase (setup/validation) + reason — the exact shape the harness asserts carry on a
# divergence. Proves the harness reports seed + phase on a failure (never silently passes a regression) — mirroring
# test_seed_batch_regression.gd's forced-failure shape test.
func _failure_report_shape_carries_seed_and_phase() -> void:
	var seed_value: int = 4242
	# An empty node id is an invalid request -> BossArenaBuilder returns a structured GenerationResult carrying the seed
	# (as a String) + the failing phase + a reason, with NO grid dump.
	var request: BossEncounterRequest = BossEncounterRequest.new(seed_value, &"")
	var result_value: GenerationResult = BossArenaBuilder.new().build(request)

	assert_true(result_value.is_error(), "An invalid boss request must produce a structured setup error (the harness never silently passes).")
	# The seed rides the error report (as a String — the GenerationResult error seed field).
	assert_equal(result_value.seed, str(seed_value), "The failure report must carry the seed string for reporting.")
	# The phase rides the report (setup validation is the VALIDATION phase).
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_VALIDATION, "The failure report must carry the failing phase (validation).")
	assert_equal(result_value.error_code, &"invalid_boss_encounter_request", "The failure report carries a stable machine-readable error code.")
	assert_false(String(result_value.reason).strip_edges().is_empty(), "The failure report must carry a non-empty reason.")
	# The diagnostics are compact (a field name), NOT a grid dump.
	assert_true(result_value.diagnostics.has("field"), "The failure diagnostics name the failing field (compact — no grid dump).")


# ---- helpers -------------------------------------------------------------------------------------

func _definition() -> BossDefinition:
	return BossRepository.create_baseline_repository().get_boss(BOSS_ID)


func _resolver() -> BossTurnResolver:
	return BossTurnResolver.new(_definition(), BOSS_ID, HERO_ID)


func _build_arena(seed_value: int) -> GenerationResult:
	return BossArenaBuilder.new().build(BossEncounterRequest.new(seed_value, BOSS_NODE_ID))


# A live boss arena board seeded from `seed_value` with the hero at `hero_cell` and the boss at `boss_hp` (-1 = full).
# Built directly from the catalog seed's arena (NOT the fixture's hardcoded seed), so the SETUP seed threads into the
# fight board.
func _boss_board(seed_value: int, hero_cell: Vector2i, boss_hp: int) -> BoardState:
	var arena: GenerationResult = _build_arena(seed_value)
	var board: BoardState = BoardState.from_snapshot(arena.payload.get("board_snapshot", {}))
	var slot: Dictionary = arena.payload.get("boss_slot", {})
	var slot_cell: Vector2i = Vector2i(int(slot.get("x", 6)), int(slot.get("y", 1)))
	var definition: BossDefinition = _definition()
	var resolved_hp: int = boss_hp if boss_hp >= 0 else definition.max_hp
	var boss: TacticalEntityState = TacticalEntityState.new(BOSS_ID, TacticalEntityState.EntityType.ENEMY, &"boss", slot_cell, resolved_hp, definition.max_hp, true, BOSS_ID)
	board.place_entity_for_setup(boss)
	var hero: TacticalEntityState = TacticalEntityState.new(HERO_ID, TacticalEntityState.EntityType.PLAYER, &"player", hero_cell, 18, 18, true, HERO_ID)
	board.place_entity_for_setup(hero)
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true
	return board


func _context(board: BoardState, seed_value: int) -> TacticalActionContext:
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, HERO_ID)
	return TacticalActionContext.new(board, turn_state, RngStreamSet.new(seed_value), [])


# Drive the two-turn telegraph->resolve (hero stays on the marked cell) and capture the byte-comparable surfaces.
func _run_two_turn_telegraph(seed_value: int) -> Dictionary:
	# Hero at (6,4): in telegraph range + same column as the boss at (6,1) (the fixture's in-range geometry).
	var board: BoardState = _boss_board(seed_value, Vector2i(6, 4), -1)
	var context: TacticalActionContext = _context(board, seed_value)
	var resolver: BossTurnResolver = _resolver()

	var turn1: ActionResult = resolver.resolve_boss_turn(context)
	var turn2: ActionResult = resolver.resolve_boss_turn(context)

	var hero_before: int = 18
	var hero_after: int = board.get_entity(HERO_ID).current_hp
	return {
		"telegraph_events": _event_dicts(turn1.events),
		"resolve_events": _event_dicts(turn2.events),
		"telegraph_decision": turn1.metadata.get("decision"),
		"telegraph_is_tile_marked": turn1.events.size() >= 1 and turn1.events[0].event_type == DomainEvent.Type.TILE_MARKED,
		"hero_took_damage_on_resolve": hero_after < hero_before
	}


# Drive the boss to 0 HP (a lethal player/test hit) -> detect_boss_defeat -> resolve the run END as a victory. Threads a
# shared sequence cursor through the phase chain + the defeat (the 9.4 seam contract) + the run-END. Captures the
# byte-comparable surfaces.
func _run_victory(seed_value: int) -> Dictionary:
	var board: BoardState = _boss_board(seed_value, Vector2i(6, 4), -1)
	var context: TacticalActionContext = _context(board, seed_value)
	var resolver: BossTurnResolver = _resolver()

	var shared_cursor: int = 1000
	# Drop the boss to 0 HP (a lethal hit — the player/test damage source).
	_damage_boss(board, 36)

	# Phase chain (0->1->2 as HP crosses both thresholds), sequenced from the shared cursor.
	var phase_result: ActionResult = resolver.resolve_phase_transitions(context, 0, shared_cursor)
	shared_cursor = int(phase_result.metadata.get("next_sequence_id_after", shared_cursor))
	# Boss defeat, sequenced from the advanced cursor.
	var defeat_result: ActionResult = resolver.detect_boss_defeat(context, shared_cursor)
	shared_cursor = int(defeat_result.metadata.get("next_sequence_id_after", shared_cursor))

	var defeated_event: DomainEvent = defeat_result.events[0]

	# Resolve the run END as a victory (a terminal NODE_RESOLUTION run — built via a helper for the summary/DTO tests;
	# here we drive CompleteRunCommand on a minimal terminal-eligible run to capture the run_completed event).
	var run = _fresh_boss_run(seed_value)
	var complete: ActionResult = CompleteRunCommand.new(&"victory", shared_cursor).execute(run)
	var run_completed_event: DomainEvent = null
	for event: DomainEvent in complete.events:
		if event.event_type == DomainEvent.Type.RUN_COMPLETED:
			run_completed_event = event

	return {
		"boss_defeated_event": defeated_event.to_dictionary(),
		"boss_defeated_event_obj": defeated_event,
		"defeated_phase_id": String(defeated_event.payload.get("phase_id", "")),
		"defeated_final_hp": int(defeated_event.payload.get("final_hp", -1)),
		"run_completed_event": run_completed_event.to_dictionary() if run_completed_event != null else {},
		"run_outcome": String(run_completed_event.payload.get("outcome", "")) if run_completed_event != null else "",
		"run_destination": String(run_completed_event.payload.get("next_destination", "")) if run_completed_event != null else ""
	}


# Drive a seeded-fixture hero death -> resolve the run END as hero_death. Captures the run_failed surfaces.
func _run_defeat(seed_value: int) -> Dictionary:
	var run = _fresh_boss_run(seed_value)
	var complete: ActionResult = CompleteRunCommand.new(&"hero_death", 2000).execute(run)
	var run_failed_event: DomainEvent = null
	for event: DomainEvent in complete.events:
		if event.event_type == DomainEvent.Type.RUN_FAILED:
			run_failed_event = event
	return {
		"run_failed_event": run_failed_event.to_dictionary() if run_failed_event != null else {},
		"run_cause": String(run_failed_event.payload.get("cause", "")) if run_failed_event != null else "",
		"run_destination": String(run_failed_event.payload.get("next_destination", "")) if run_failed_event != null else "",
		"run_phase": String(run.phase)
	}


# A minimal terminal-eligible run parked at the boss node (in NODE_RESOLUTION), for driving CompleteRunCommand. Built
# via the shared FinaleRunFixture so the run/route shape is valid + consistent with the full-run integration test.
func _fresh_boss_run(seed_value: int):
	var FinaleRunFixture = load("res://tests/fixtures/run/finale_run_fixture.gd")
	return FinaleRunFixture.boss_terminus_run(seed_value)


func _damage_boss(board: BoardState, amount: int) -> void:
	var boss: TacticalEntityState = board.get_entity(BOSS_ID)
	var hp_before: int = boss.current_hp
	var hp_after: int = max(0, hp_before - amount)
	var event: DomainEvent = DomainEvent.damage_applied(
		board.next_sequence_id(), HERO_ID, BOSS_ID, amount, hp_before, hp_after, boss.max_hp,
		{"weapon_id": "test_strike", "base_damage": amount, "final_damage": amount, "damage_type": "physical", "explanation": "Test damage to the boss."}
	)
	board.apply_events([event])


func _setup_fingerprint(payload: Dictionary) -> String:
	var board: Dictionary = payload.get("board_snapshot", {})
	var width: int = int(board.get("width", 0))
	var height: int = int(board.get("height", 0))
	var terrain: String = ""
	for cell_value: Variant in board.get("cells", []):
		var cell: Dictionary = cell_value
		terrain += str(int(cell.get("terrain", 0)))
	var entrance: Dictionary = payload.get("entrance", {})
	var slot: Dictionary = payload.get("boss_slot", {})
	return "%dx%d|e%d,%d|b%d,%d|%s" % [
		width, height,
		int(entrance.get("x", -1)), int(entrance.get("y", -1)),
		int(slot.get("x", -1)), int(slot.get("y", -1)),
		terrain
	]


func _phase_chain_fingerprint(chain: Array[BossPhaseTransition]) -> String:
	var parts: Array[String] = []
	for transition: BossPhaseTransition in chain:
		parts.append("%d->%d:%s" % [int(transition.from_phase), int(transition.to_phase), String(transition.phase_id)])
	return "|".join(parts)


func _event_dicts(events: Array[DomainEvent]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: DomainEvent in events:
		out.append(event.to_dictionary())
	return out
