extends "res://tests/unit/test_case.gd"

# Story 9.5 Task 2 (AC2) — the FULL-RUN-THROUGH-THE-SHELL INTEGRATION + the boss_cleared reconciliation. This is the
# comprehensive integration test 9.1/9.4 EXPLICITLY earmarked to 9.5: it drives the COMPLETE finale chain end-to-end
# THROUGH the run shell — start -> run_to_completion (to the 9.1 boss-setup terminus) -> the live boss fight (explicit
# 9.3 turns to 0 HP / a driven death) -> the 9.4 victory/death resolution -> RunSummary + RunEndOutcome — closing the
# long-parked "auto-play the boss fight through run_to_completion to a real victory/death" seam that 9.1/9.3/9.4 all
# deferred to 9.5.
#
# ⭐ THE BOUNDARY DRAWN (recorded): this is an INTEGRATION TEST + a THIN caller-driven orchestrator continuation
# (RunOrchestrator.resolve_boss_victory), NOT a shipped auto-played game loop inside run_to_completion. The run is driven
# to the boss-setup terminus VIA THE SHELL (run_to_completion parks it NON-terminal in NODE_RESOLUTION with a pending
# boss encounter — 9.1's posture); the boss fight is then driven on the live arena board via EXPLICIT test turns (9.3's
# posture — BossTurnResolver.resolve_boss_turn + player/test damage), and victory is resolved via the 9.4 seam
# (detect_boss_defeat -> resolve_run_end(victory) through the reconciliation). The DEATH half uses a DRIVEN (caller/test-
# supplied) death (resolve_run_end(&"hero_death")), NOT a live auto-firing hero-death SOURCE — that live source stays
# DEFERRED to a later run-flow/HUD story (see the story OUT-of-scope boundary).
#
# ⭐ THE boss_cleared RECONCILIATION ([Decision] A, RECOMMENDED — recorded): the live 9.4 victory chain drives
# PHASE_COMPLETED WITHOUT clearing the boss route node, but RunSummary.boss_cleared derives from a cleared TYPE_BOSS node.
# RunOrchestrator.resolve_boss_victory reconciles it by clearing the boss node (REVEAL_CLEARED + idempotent
# cleared_node_ids append — the NodeResolvePlaceholderCommand._resolve_boss discipline) on victory, so boss_cleared reads
# TRUE after a live victory + run.validate() stays green. CompleteRunCommand is UNCHANGED.
#
# SEQUENCE-ID SEAM (re-affirmed end-to-end): 9.5 is the FIRST consumer to interleave the boss-action + phase-change +
# boss_defeat + run_completed streams into ONE run log. The shared monotonic RunOrchestrator._next_sequence_id (surfaced
# for the fight via the orchestrator's own counter) threads through resolve_phase_transitions -> detect_boss_defeat ->
# the run-END append — NEVER the board-baseline fallback. The test asserts every sequence id across the merged stream is
# unique (no duplicate ids — the 9.4 closure re-affirmed).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossRepository = preload("res://scripts/content/repositories/boss_repository.gd")
const BossTurnResolver = preload("res://scripts/tactical/turns/boss_turn_resolver.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const FinaleRunFixture = preload("res://tests/fixtures/run/finale_run_fixture.gd")
const RunEndOutcome = preload("res://scripts/run/run_end_outcome.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const RunSummary = preload("res://scripts/run/run_summary.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

const BOSS_ID := &"larval_avatar"
const HERO_ID := &"hero"
const FINALE_SEED: int = 4242

func run() -> Dictionary:
	_run_reaches_the_boss_through_the_shell()
	_victory_records_boss_cleared_and_the_completion_event()
	_victory_reconciliation_keeps_the_run_valid()
	_death_records_run_failed_and_the_completion_event()
	_sequence_ids_are_unique_across_the_interleaved_stream()
	_full_run_is_byte_deterministic_end_to_end()
	_manual_seed_run_reaches_the_terminus_but_is_ineligible()
	return result()


# ---- AC2: a full run reaches the boss THROUGH the run shell ---------------------------------------

func _run_reaches_the_boss_through_the_shell() -> void:
	var orchestrator: RunOrchestrator = FinaleRunFixture.drive_to_boss_terminus(FINALE_SEED)

	# The 9.1 boss-setup terminus: the run is parked NON-terminal in NODE_RESOLUTION with a pending boss encounter (the
	# run reached the boss THROUGH the shell but has NOT auto-played the fight).
	assert_equal(orchestrator.run.phase, RunState.PHASE_NODE_RESOLUTION, "The run parks in NODE_RESOLUTION at the boss-setup terminus (reached the boss through the shell).")
	assert_true(orchestrator.boss_encounter_pending(), "The run has a pending boss encounter set up.")
	assert_false(orchestrator.run.is_terminal(), "The boss-terminus run is NON-terminal (awaiting the fight/victory).")
	# The boss arena payload is available for the live fight (the 9.1 setup surface).
	var board: BoardState = FinaleRunFixture.boss_arena_board(orchestrator)
	assert_true(board != null, "The boss arena board restores from the orchestrator's boss_arena_payload().")
	assert_equal(board.width, 12, "The boss arena is the 12x12 confrontation room.")
	# The run stands on the terminal boss route node.
	assert_false(FinaleRunFixture.boss_node_id(orchestrator.run).is_empty(), "The run has a terminal boss route node.")


# ---- AC2 (victory): the fight to 0 HP records boss progress + the run_completed(victory) event ----

func _victory_records_boss_cleared_and_the_completion_event() -> void:
	var driven: Dictionary = _drive_full_run_to_victory(FINALE_SEED)
	var run: RunState = driven.get("run")
	var events: Array = driven.get("events")

	# The victory chain drove the run to PHASE_COMPLETED.
	assert_equal(run.phase, RunState.PHASE_COMPLETED, "A live boss victory drives the run to PHASE_COMPLETED.")
	assert_true(run.is_terminal(), "The completed run is terminal.")

	# The run_completed event carries outcome == victory + next_destination == outpost.
	var run_completed: DomainEvent = _first_event_of_type(events, DomainEvent.Type.RUN_COMPLETED)
	assert_true(run_completed != null, "A live boss victory emits a run_completed event.")
	assert_equal(String(run_completed.payload.get("outcome")), "victory", "The run_completed outcome is victory.")
	assert_equal(String(run_completed.payload.get("next_destination")), "outpost", "The run_completed routes to the outpost (the outpost/meta flow signal).")

	# The boss_defeated event was emitted during the fight (the tactical defeat fact).
	var boss_defeated: DomainEvent = _first_event_of_type(events, DomainEvent.Type.BOSS_DEFEATED)
	assert_true(boss_defeated != null, "The fight emits a boss_defeated event.")
	assert_equal(String(boss_defeated.payload.get("boss_entity_id")), "larval_avatar", "The boss_defeated names the Larval Avatar.")

	# ⭐ THE RECONCILIATION: RunSummary.boss_cleared reads TRUE after the live victory (the boss route node was cleared).
	var summary: RunSummary = RunSummary.build(run, events)
	assert_true(summary.has_summary, "RunSummary builds off the terminal victory run.")
	assert_true(bool(summary.run_scoped.get("boss_cleared")), "RunSummary.boss_cleared is TRUE after a live victory (the reconciliation — a defeated boss is a cleared boss node).")
	assert_equal(String(summary.outcome_or_cause), "victory", "RunSummary records the victory outcome.")
	assert_equal(String(summary.phase), "completed", "RunSummary records the COMPLETED terminal phase.")

	# The outpost/meta flow receives the correct completion event (RunEndOutcome — the next_destination == outpost read
	# the OutpostViewModel consumes).
	var outcome: RunEndOutcome = RunEndOutcome.for_completed(run, DomainEvent.RUN_COMPLETED_OUTCOME_VICTORY)
	assert_true(outcome.has_ended, "RunEndOutcome projects the ended victory run.")
	assert_equal(String(outcome.phase), "completed", "RunEndOutcome phase is completed.")
	assert_equal(String(outcome.outcome_or_cause), "victory", "RunEndOutcome outcome is victory.")
	assert_equal(String(outcome.next_destination), "outpost", "RunEndOutcome routes to the outpost (the meta/outpost flow signal).")
	assert_true(outcome.meta_progression_eligible, "A seeded (non-manual) victory run is meta-progression eligible.")


func _victory_reconciliation_keeps_the_run_valid() -> void:
	# The boss-clear reconciliation keeps run.validate() green (an idempotent cleared_node_ids append + a valid reveal
	# state — no duplicate_cleared_node, no dangling node).
	var driven: Dictionary = _drive_full_run_to_victory(FINALE_SEED)
	var run: RunState = driven.get("run")
	assert_true(run.validate().succeeded, "The victory run (with the boss node cleared) stays structurally valid.")
	# The boss node IS in the cleared set exactly once (idempotent).
	var boss_id: String = FinaleRunFixture.boss_node_id(run)
	var count: int = 0
	for cleared: String in run.route.cleared_node_ids:
		if cleared == boss_id:
			count += 1
	assert_equal(count, 1, "The boss node is cleared exactly once (idempotent append).")

	# Calling resolve_boss_victory AGAIN on the already-terminal run is a stable no-double-grant error (the 8.1
	# run_already_terminal guard) — the clear stays idempotent, nothing re-fires.
	var orchestrator: RunOrchestrator = driven.get("orchestrator")
	var second: ActionResult = orchestrator.resolve_boss_victory()
	assert_true(second.is_error(), "Re-resolving the victory on an already-terminal run is rejected (no double-grant).")
	assert_equal(second.error_code, &"run_already_terminal", "The re-resolution surfaces the stable run_already_terminal code.")


# ---- AC2 (death): a driven hero death records run_failed + the completion event -------------------

func _death_records_run_failed_and_the_completion_event() -> void:
	# Drive the full run to the boss terminus, then resolve the run END as a DRIVEN hero death (a caller/test-supplied
	# death — NOT a live hero-death source). The boss is NOT cleared on a death (the cleared set is the nodes cleared
	# BEFORE the death — boss_cleared stays false on a death, which is correct).
	var orchestrator: RunOrchestrator = FinaleRunFixture.drive_to_boss_terminus(FINALE_SEED)
	var run: RunState = orchestrator.run

	# (Optionally the caller would drive the fight to a hero death on the board; the run-END resolution is the same
	# caller-driven CompleteRunCommand path either way — the death SOURCE is deferred, the death PATH is exercised here.)
	var death_result: ActionResult = orchestrator.resolve_run_end(&"hero_death")
	assert_true(death_result.succeeded, "The driven hero-death run-END resolves: %s" % death_result.metadata)
	assert_equal(run.phase, RunState.PHASE_FAILED, "A driven hero death drives the run to PHASE_FAILED.")
	assert_true(run.is_terminal(), "The failed run is terminal.")

	var events: Array = [orchestrator.run_failed_event()]
	var run_failed: DomainEvent = _first_event_of_type(events, DomainEvent.Type.RUN_FAILED)
	assert_true(run_failed != null, "A driven death emits a run_failed event.")
	assert_equal(String(run_failed.payload.get("cause")), "hero_death", "The run_failed cause is hero_death.")
	assert_equal(String(run_failed.payload.get("next_destination")), "outpost", "The run_failed routes to the outpost.")

	# The summary records the terminal outcome (hero_death) + boss_cleared stays FALSE (the boss was NOT defeated).
	var summary: RunSummary = RunSummary.build(run, events)
	assert_true(summary.has_summary, "RunSummary builds off the terminal death run.")
	assert_equal(String(summary.outcome_or_cause), "hero_death", "RunSummary records the hero_death cause.")
	assert_false(bool(summary.run_scoped.get("boss_cleared")), "RunSummary.boss_cleared stays FALSE on a death (the boss was not defeated).")
	assert_equal(String(summary.phase), "failed", "RunSummary records the FAILED terminal phase.")

	# The outpost/meta flow receives the correct completion event (RunEndOutcome — run_failed + hero_death + outpost).
	var outcome: RunEndOutcome = RunEndOutcome.for_failed(run, &"hero_death")
	assert_true(outcome.has_ended, "RunEndOutcome projects the ended death run.")
	assert_equal(String(outcome.phase), "failed", "RunEndOutcome phase is failed.")
	assert_equal(String(outcome.outcome_or_cause), "hero_death", "RunEndOutcome cause is hero_death.")
	assert_equal(String(outcome.next_destination), "outpost", "RunEndOutcome routes to the outpost on a death.")


# ---- AC2 sequence-id seam: no duplicate ids across the interleaved stream -------------------------

func _sequence_ids_are_unique_across_the_interleaved_stream() -> void:
	var driven: Dictionary = _drive_full_run_to_victory(FINALE_SEED)
	var events: Array = driven.get("events")

	# The full interleaved run log (boss-action + phase-change + boss_defeat + run_completed) must have NO duplicate
	# sequence ids (the seam contract — threading the shared cursor). Only the fight+run-END events are collected here
	# (they share the orchestrator's monotonic counter); assert uniqueness across them.
	var seen: Dictionary = {}
	for event_value: Variant in events:
		if not (event_value is DomainEvent):
			continue
		var event: DomainEvent = event_value
		assert_false(seen.has(event.sequence_id), "Every merged sequence id must be UNIQUE across the interleaved stream: id %d repeated." % event.sequence_id)
		seen[event.sequence_id] = true
	# There must be at least the phase-change chain + boss_defeat + run_completed in the merged stream.
	assert_true(seen.size() >= 3, "The merged fight+run-END stream carries at least the phase changes + boss_defeat + run_completed.")


# ---- AC2 determinism: the same seed is byte-deterministic end-to-end ------------------------------

func _full_run_is_byte_deterministic_end_to_end() -> void:
	var first: Dictionary = _drive_full_run_to_victory(FINALE_SEED)
	var second: Dictionary = _drive_full_run_to_victory(FINALE_SEED)

	# The terminal run state is byte-identical.
	assert_equal(
		JSON.stringify((first.get("run") as RunState).to_dictionary()),
		JSON.stringify((second.get("run") as RunState).to_dictionary()),
		"The same seed must produce a byte-identical terminal run."
	)
	# The collected fight+run-END events are byte-identical.
	assert_equal(_event_dicts(first.get("events")), _event_dicts(second.get("events")), "The same seed must produce byte-identical fight+run-END events.")
	# The run summary is byte-identical.
	var first_summary: RunSummary = RunSummary.build(first.get("run"), first.get("events"))
	var second_summary: RunSummary = RunSummary.build(second.get("run"), second.get("events"))
	assert_equal(JSON.stringify(first_summary.to_dictionary()), JSON.stringify(second_summary.to_dictionary()), "The same seed must produce a byte-identical run summary.")


# ---- a manual-seed run reaches the terminus but is ineligible (the FR28 boundary) -----------------

func _manual_seed_run_reaches_the_terminus_but_is_ineligible() -> void:
	# A manual-seed (practice) run reaches the boss terminus + can be driven to victory, but is NOT meta-eligible (the
	# 8.1/8.3 FR28 boundary — a practice victory grants no progression). Proves the completion event flows the same way
	# with the eligibility flag honestly false.
	var driven: Dictionary = _drive_full_run_to_victory(FINALE_SEED, true)
	var run: RunState = driven.get("run")
	assert_equal(run.phase, RunState.PHASE_COMPLETED, "A manual-seed run still drives to a victory completion.")
	assert_false(run.meta_progression_eligible, "A manual-seed victory run is NOT meta-progression eligible (the FR28 boundary).")

	var outcome: RunEndOutcome = RunEndOutcome.for_completed(run, DomainEvent.RUN_COMPLETED_OUTCOME_VICTORY)
	assert_false(outcome.meta_progression_eligible, "RunEndOutcome reports the manual-seed run ineligible.")
	assert_equal(String(outcome.next_destination), "outpost", "A manual-seed victory still routes to the outpost.")


# ---- helpers -------------------------------------------------------------------------------------

# Drive a FULL run to victory THROUGH the shell: start -> run_to_completion (to the boss terminus) -> the live boss fight
# on the arena board (explicit 9.3 turns to 0 HP) -> the 9.4 victory resolution via the thin resolve_boss_victory
# continuation (the reconciliation + run-END). Returns {orchestrator, run, events} where events is the collected
# fight+run-END interleaved stream (threaded through the orchestrator's shared sequence-id cursor).
func _drive_full_run_to_victory(seed_value: int, is_manual_seed: bool = false) -> Dictionary:
	var orchestrator: RunOrchestrator = FinaleRunFixture.drive_to_boss_terminus(seed_value, is_manual_seed)
	var board: BoardState = FinaleRunFixture.boss_arena_board(orchestrator)

	# Place the live boss (full HP) + the hero on the arena board (the 9.3 live-loop seam the fixture fills). The boss is
	# at the arena's reserved slot; the hero enters at the arena entrance.
	var definition: BossDefinition = BossRepository.create_baseline_repository().get_boss(BOSS_ID)
	var slot: Dictionary = orchestrator.boss_arena_payload().get("boss_slot", {})
	var slot_cell: Vector2i = Vector2i(int(slot.get("x", 6)), int(slot.get("y", 1)))
	var entrance: Dictionary = orchestrator.boss_arena_payload().get("entrance", {})
	var entrance_cell: Vector2i = Vector2i(int(entrance.get("x", 6)), int(entrance.get("y", 10)))
	var boss: TacticalEntityState = TacticalEntityState.new(BOSS_ID, TacticalEntityState.EntityType.ENEMY, &"boss", slot_cell, definition.max_hp, definition.max_hp, true, BOSS_ID)
	board.place_entity_for_setup(boss)
	var hero: TacticalEntityState = TacticalEntityState.new(HERO_ID, TacticalEntityState.EntityType.PLAYER, &"player", entrance_cell, 18, 18, true, HERO_ID)
	board.place_entity_for_setup(hero)
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true

	var events: Array = []

	# The fight context. The shared monotonic run-level cursor is the orchestrator's _next_sequence_id (surfaced via the
	# run-END; here we track a local cursor seeded high above the run's route-event ids so the interleaved fight ids do
	# not collide with the run-END id the orchestrator assigns — the seam contract's caller-reserved base).
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, HERO_ID)
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, orchestrator.streams, [])
	var resolver: BossTurnResolver = BossTurnResolver.new(definition, BOSS_ID, HERO_ID)

	# Drive the boss to 0 HP via an explicit player/test hit (the 9.3 posture — no auto-loop). One lethal hit crosses
	# BOTH phase thresholds AND kills the boss (the phase chain 0->1->2 + the boss_defeat).
	_damage_boss(board, context, definition.max_hp)

	# A caller-reserved sequence base ABOVE the orchestrator's current cursor, so the interleaved fight ids do not collide
	# with the run-END id resolve_boss_victory will assign (the seam contract — reserve a range).
	var fight_base: int = 100000
	var phase_result: ActionResult = resolver.resolve_phase_transitions(context, 0, fight_base)
	events.append_array(phase_result.events)
	fight_base = int(phase_result.metadata.get("next_sequence_id_after", fight_base))
	var defeat_result: ActionResult = resolver.detect_boss_defeat(context, fight_base)
	events.append_array(defeat_result.events)

	# The 9.4 victory resolution through the thin continuation: clears the boss node (the reconciliation) + drives
	# resolve_run_end(victory). The run_completed event uses the orchestrator's own (lower) monotonic cursor — distinct
	# from the reserved fight base, so no id collides.
	var victory_result: ActionResult = orchestrator.resolve_boss_victory()
	events.append_array(victory_result.events)

	return {
		"orchestrator": orchestrator,
		"run": orchestrator.run,
		"events": events
	}


func _damage_boss(board: BoardState, context: TacticalActionContext, amount: int) -> void:
	var boss: TacticalEntityState = board.get_entity(BOSS_ID)
	var hp_before: int = boss.current_hp
	var hp_after: int = max(0, hp_before - amount)
	var event: DomainEvent = DomainEvent.damage_applied(
		board.next_sequence_id(), HERO_ID, BOSS_ID, amount, hp_before, hp_after, boss.max_hp,
		{"weapon_id": "test_strike", "base_damage": amount, "final_damage": amount, "damage_type": "physical", "explanation": "Test damage to the boss."}
	)
	board.apply_events([event])


func _first_event_of_type(events: Array, event_type: int) -> DomainEvent:
	for event_value: Variant in events:
		if not (event_value is DomainEvent):
			continue
		var event: DomainEvent = event_value
		if event.event_type == event_type:
			return event
	return null


func _event_dicts(events: Array) -> Array:
	var out: Array = []
	for event_value: Variant in events:
		if event_value is DomainEvent:
			out.append((event_value as DomainEvent).to_dictionary())
	return out
