extends "res://tests/unit/test_case.gd"

# Story 12.1 (AC1/AC2/AC3/AC4) — InteractiveCombatSession: the SCENE-FREE, STEP-DRIVEN live-combat session that
# holds a live fight in progress ACROSS taps. It is the interactive counterpart of LiveCombatResolver (the one-shot
# scripted-hero driver): it REUSES the same building blocks (board restore via BoardState.try_from_snapshot, the
# affinity board effect applied BEFORE hero placement, hero placement at the generated entrance, ONE player action
# per tap through TacticalCommandBridge, EnemyTurnResolver.resolve_after_player_action for the enemy phase, the
# Scorched DoT gated on the affinity PLAN, and CombatOutcomeEvaluator after each action) but driven by explicit tap
# intents instead of a scripted focus-fire loop.
#
# Covers:
#   - AC2 — a scripted sequence of move/attack tap intents drives a generated combat board to a real board VICTORY
#           (all enemies dead, hero alive), and to a real board DEFEAT (hero at 0 HP) with a weak hero.
#   - AC2 — the two-step attack commit (first tap PREVIEWS/arms, second confirming tap COMMITS through the bridge).
#   - AC2 — an INVALID tap intent is a fail-closed no-mutation reject (the command's own reason surfaces; the board
#           is byte-identical, the turn does not advance, the enemy phase does not run).
#   - AC3 — the enemy phase runs via EnemyTurnResolver after each COMMITTED action (a committed move/attack advances
#           the turn; the enemy turn number climbs).
#   - AC4 — the terminal outcome is read from CombatOutcomeState (VICTORY/DEFEAT), and the session draws gameplay RNG
#           ONLY through the injected run-level streams (the default sword hero draws ZERO combat RNG).
#   - inspect is a metadata-only read (no mutation, no turn advance).
#   - a rejected board snapshot / an unknown hero weapon surface structured errors from begin().

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const AttackPreviewQuery = preload("res://scripts/tactical/targeting/attack_preview_query.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const InteractiveCombatSession = preload("res://scripts/run/interactive_combat_session.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalPathQuery = preload("res://scripts/tactical/movement/tactical_path_query.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

const HERO_ID := &"hero"
# The 11.2 verified seed whose depth-0 Small combat board a strong sword hero clears / a 1-HP hero loses.
const VICTORY_SEED: int = 4242
# A bounded step cap for the scripted TAP driver (mirrors LiveCombatResolver.MAX_ROUNDS discipline — a stalled test
# board fails the assertion rather than hanging).
const MAX_TAP_STEPS: int = 64

func run() -> Dictionary:
	_scripted_taps_drive_a_generated_board_to_victory()
	_two_step_attack_first_tap_arms_second_tap_commits()
	_weak_hero_taps_reach_a_real_board_defeat()
	_invalid_move_tap_is_a_fail_closed_no_mutation_reject()
	_committed_action_runs_the_enemy_phase_via_the_resolver()
	_inspect_is_metadata_only_no_mutation()
	_default_hero_draws_zero_combat_rng_across_the_tap_loop()
	_begin_rejects_a_corrupt_board_snapshot()
	_begin_rejects_an_unknown_hero_weapon()
	_zero_enemy_board_begins_already_victorious()
	# Story 12.2 — the class-kit loadout support threads through the tap loop.
	_loadout_shield_support_engages_the_shield_block_combat_roll_through_the_tap_loop()
	_null_loadout_support_keeps_the_tap_attack_byte_identical()
	_begin_rejects_a_malformed_loadout_support()
	# Story 14.1 — the Wait/pass-turn backstop + corpse-walkability.
	_wait_tap_advances_the_turn_and_runs_the_enemy_phase()
	_corpse_cell_becomes_walkable_mid_fight()
	_wait_is_rejected_before_begin_and_after_terminal()
	return result()


# ---- AC2: a scripted tap sequence drives the board to a real VICTORY ------------------------------

func _scripted_taps_drive_a_generated_board_to_victory() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	assert_true(generation.succeeded, "Setup: seed %d should generate a Small combat level." % VICTORY_SEED)

	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	var begin: ActionResult = session.begin(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED)
	)
	assert_true(begin.succeeded, "The session should begin: %s" % begin.metadata)
	assert_false(session.is_terminal(), "A real combat board is not terminal at the start.")

	_drive_scripted_taps_to_terminal(session)
	assert_true(session.is_terminal(), "The scripted taps should drive the fight to a terminal outcome.")
	assert_true(session.is_victory(), "A strong sword hero drives the tap loop to a real board VICTORY.")
	assert_equal(String(session.outcome_state().state_id), CombatOutcomeState.STATE_VICTORY, "The terminal outcome_state is victory (read from CombatOutcomeState).")
	assert_equal(_living_enemy_count(session.board()), 0, "A live victory leaves ZERO living enemies on the board.")
	assert_true(session.board().get_entity(HERO_ID).is_alive(), "The hero survives a tap-driven victory.")


# ---- AC2: the two-step attack commit (first tap arms, second tap commits) -------------------------

func _two_step_attack_first_tap_arms_second_tap_commits() -> void:
	# Build a tiny board where the hero starts ADJACENT to a 1-HP enemy so a single sword attack kills it. The first
	# tap ARMS the attack preview (no mutation); the second tap on the SAME cell COMMITS (the enemy dies -> victory).
	var snapshot: Dictionary = _adjacent_duel_snapshot()
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	var begin: ActionResult = session.begin(snapshot, {"x": 1, "y": 1}, RngStreamSet.new(1))
	assert_true(begin.succeeded, "The duel session should begin: %s" % begin.metadata)
	assert_false(session.is_terminal(), "The duel is not terminal at the start (one living enemy).")

	var target: Vector2i = Vector2i(2, 1)
	var enemy_hp_before: int = session.board().get_entity(&"enemy_a").current_hp
	# First tap ARMS the preview — no mutation (the enemy is untouched, the fight is not terminal).
	var arm = session.tap_attack(target)
	assert_false(arm.submitted, "The FIRST attack tap only ARMS the preview (it does not submit).")
	assert_equal(session.board().get_entity(&"enemy_a").current_hp, enemy_hp_before, "The first (arming) tap mutates NOTHING (the enemy HP is unchanged).")
	assert_false(session.is_terminal(), "The first arming tap does not resolve the fight.")

	# Second tap on the SAME target COMMITS — the attack executes through the bridge, the 1-HP enemy dies -> victory.
	var commit = session.tap_attack(target)
	assert_true(commit.submitted, "The SECOND attack tap on the same target COMMITS (executes through the bridge).")
	assert_true(session.is_terminal() and session.is_victory(), "The committed attack kills the last enemy -> a real board VICTORY.")


# ---- AC2 (resolver half): a weak hero reaches a real board DEFEAT ---------------------------------

func _weak_hero_taps_reach_a_real_board_defeat() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	# A 1-HP dagger hero — the real enemy turns fell it on the board (a real DEFEAT), driven through the tap loop.
	var begin: ActionResult = session.begin(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED), 1, &"dagger"
	)
	assert_true(begin.succeeded, "The weak-hero session should begin: %s" % begin.metadata)

	_drive_scripted_taps_to_terminal(session)
	assert_true(session.is_terminal(), "The weak-hero tap loop should reach a terminal outcome.")
	assert_true(session.is_defeat(), "A 1-HP hero is DEFEATED by the real enemy turns (a real board DEFEAT).")
	assert_equal(String(session.outcome_state().state_id), CombatOutcomeState.STATE_DEFEAT, "The terminal outcome_state is defeat (read from CombatOutcomeState).")
	assert_true(session.board().get_entity(HERO_ID).is_dead(), "A live defeat leaves the hero DEAD (0 HP) on the board.")


# ---- AC2: an invalid tap is a fail-closed no-mutation reject --------------------------------------

func _invalid_move_tap_is_a_fail_closed_no_mutation_reject() -> void:
	var snapshot: Dictionary = _adjacent_duel_snapshot()
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	assert_true(session.begin(snapshot, {"x": 1, "y": 1}, RngStreamSet.new(1)).succeeded, "Setup: the duel session begins.")

	var board_before: Dictionary = session.board().to_snapshot()
	var turn_before: int = session.turn_state().turn_number
	# A move onto the WALL border cell (0,0) is illegal — the bridge/command reject it, no mutation, no turn advance.
	var result_value: ActionResult = session.submit_move(Vector2i(0, 0))
	assert_true(result_value.is_error(), "An illegal move tap is REJECTED (the command's own reason surfaces).")
	assert_equal(session.board().to_snapshot(), board_before, "A rejected move mutates NOTHING (the board is byte-identical).")
	assert_equal(session.turn_state().turn_number, turn_before, "A rejected move does NOT advance the turn (the enemy phase did not run).")
	assert_false(session.is_terminal(), "A rejected tap does not resolve the fight.")


# ---- AC3: the enemy phase runs via EnemyTurnResolver after a committed action ---------------------

func _committed_action_runs_the_enemy_phase_via_the_resolver() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	assert_true(session.begin(generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED)).succeeded, "Setup: the session begins.")

	var turn_before: int = session.turn_state().turn_number
	# A committed hero action (a legal approach step toward the nearest enemy) advances the turn; the enemy phase runs
	# (EnemyTurnResolver bumps the turn number after resolving the enemy actions).
	var step: Vector2i = _next_approach_step(session.board())
	assert_true(step != Vector2i(-1, -1), "Setup: the hero has a legal approach step.")
	var result_value: ActionResult = session.submit_move(step)
	assert_true(result_value.succeeded, "A legal move tap commits: %s" % result_value.metadata)
	assert_true(session.turn_state().turn_number > turn_before, "A committed action runs the enemy phase (EnemyTurnResolver advances the turn number).")
	assert_equal(session.turn_state().phase, session.turn_state().Phase.PLAYER_PLANNING, "After the enemy phase the turn returns to PLAYER_PLANNING (the hero's next tap).")
	assert_equal(String(session.turn_state().active_actor_id), String(HERO_ID), "After the enemy phase the hero is active again.")


# ---- inspect is metadata-only ---------------------------------------------------------------------

func _inspect_is_metadata_only_no_mutation() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	assert_true(session.begin(generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED)).succeeded, "Setup: the session begins.")

	var board_before: Dictionary = session.board().to_snapshot()
	var turn_before: int = session.turn_state().turn_number
	var inspect = session.inspect(Vector2i(1, 1))
	assert_true(inspect.succeeded, "An inspect tap succeeds (a metadata-only read).")
	assert_equal(session.board().to_snapshot(), board_before, "Inspect mutates NOTHING (the board is byte-identical).")
	assert_equal(session.turn_state().turn_number, turn_before, "Inspect does NOT advance the turn.")


# ---- AC4: the default hero draws ZERO combat RNG across the tap loop ------------------------------

func _default_hero_draws_zero_combat_rng_across_the_tap_loop() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var streams: RngStreamSet = RngStreamSet.new(VICTORY_SEED)
	var before: Dictionary = streams.to_snapshot()
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	assert_true(session.begin(generation.payload.get("board", {}), generation.payload.get("entrance", {}), streams).succeeded, "Setup: the session begins.")
	_drive_scripted_taps_to_terminal(session)
	assert_true(session.is_victory(), "Setup: the default hero should win.")
	assert_equal(streams.to_snapshot(), before, "The default sword hero draws ZERO combat RNG across the tap loop (the injected stream set is unchanged).")


# ---- begin() error paths --------------------------------------------------------------------------

func _begin_rejects_a_corrupt_board_snapshot() -> void:
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	var begin: ActionResult = session.begin({"width": 3}, {"x": 0, "y": 0}, RngStreamSet.new(1))
	assert_true(begin.is_error(), "A corrupt board snapshot must be rejected (no fabricated session).")
	assert_equal(begin.error_code, &"invalid_board_snapshot", "A rejected board uses the stable invalid_board_snapshot code.")


func _begin_rejects_an_unknown_hero_weapon() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	var begin: ActionResult = session.begin(
		generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(1), 40, &"not_a_weapon"
	)
	assert_true(begin.is_error(), "An unknown hero weapon must be rejected.")
	assert_equal(begin.error_code, &"unknown_hero_weapon", "A missing weapon uses the stable unknown_hero_weapon code.")


func _zero_enemy_board_begins_already_victorious() -> void:
	# A degenerate board with NO enemies is already a victory at begin() (the evaluator's living_enemy_count == 0).
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	var begin: ActionResult = session.begin(_empty_board_snapshot(), {"x": 0, "y": 1}, RngStreamSet.new(1))
	assert_true(begin.succeeded, "A zero-enemy board should begin: %s" % begin.metadata)
	assert_true(session.is_terminal() and session.is_victory(), "A zero-enemy board begins already victorious (decided before any tap).")


# ---- Story 12.2 (AC3/AC4): the class-kit loadout support threads through the tap loop -------------

# The seated class-kit SHIELD support engages the seeded shield_block `combat` roll when an ENEMY attacks the hero on the
# TAP-driven path (the on-screen path carries the class off-hand; the shield protects its OWNER — the hero-defense seam).
# The session STORES the loadout support (begin's hero_support param) and seats it on the enemy resolver as the defender
# support — so a warrior's shield block chance is live on screen, exactly as the reference driver proves. The block roll
# is the INTENTIONAL, seeded AC4 class-path draw (drawn on the enemy phase, synced back to the injected run-level stream).
func _loadout_shield_support_engages_the_shield_block_combat_roll_through_the_tap_loop() -> void:
	# A hero ADJACENT to a durable (10-HP) iron_cultist, armed with the class SHIELD loadout. The hero attacks (does not
	# kill it), then the enemy phase runs and the adjacent cultist melee-attacks the SHIELDED hero -> the shield_block roll
	# fires on the `combat` stream (the shield protects its owner on incoming enemy hits).
	var snapshot: Dictionary = _durable_adjacent_duel_snapshot()
	var shield: SupportDefinition = SupportRepository.create_baseline_repository().get_support(&"shield")
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	var begin: ActionResult = session.begin(snapshot, {"x": 1, "y": 1}, RngStreamSet.new(4242), 18, &"sword", &"none", null, shield)
	assert_true(begin.succeeded, "The shield-loadout duel session should begin: %s" % begin.metadata)
	assert_equal(String(session.loadout_support().support_id), String(SupportDefinition.SUPPORT_SHIELD), "The session STORES the class-kit shield loadout support.")

	var target: Vector2i = Vector2i(2, 1)
	# Two taps: arm, then commit the sword attack. The committed attack advances the turn -> the enemy phase runs, and the
	# adjacent cultist attacks the shielded hero -> the shield_block roll engages (the hero-defense seam).
	session.tap_attack(target)
	session.tap_attack(target)
	# The incoming enemy attack against the shielded hero engaged a shield_block roll on the `combat` stream.
	assert_true(_shield_block_roll_count(session.event_log()) > 0, "An enemy attack against the class-shield hero engages the shield_block `combat` roll on the tap path (the shield protects its owner).")


# The DEFAULT (no loadout support) tap attack stays byte-identical to a session begun with an explicit null support —
# the neutral no-support path never carries a `combat` draw (the byte-identical AC4 default). Proven by the injected
# stream staying unchanged across a full default sword tap-victory.
func _null_loadout_support_keeps_the_tap_attack_byte_identical() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var streams: RngStreamSet = RngStreamSet.new(VICTORY_SEED)
	var before: Dictionary = streams.to_snapshot()
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	# begin with an explicit null loadout support (the default) — the no-support path.
	assert_true(session.begin(generation.payload.get("board", {}), generation.payload.get("entrance", {}), streams, 60, &"sword", &"none", null, null).succeeded, "Setup: the null-support session begins.")
	_drive_scripted_taps_to_terminal(session)
	assert_true(session.is_victory(), "Setup: the default sword hero should win.")
	assert_equal(streams.to_snapshot(), before, "A null loadout support keeps the tap loop byte-identical (ZERO combat RNG — the neutral no-support path).")


func _begin_rejects_a_malformed_loadout_support() -> void:
	# A malformed loadout support is rejected up front (fail-closed) — it never silently degrades to no-op mid-fight.
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var malformed: SupportDefinition = SupportDefinition.new(&"", 0, 0.0, 0, [], "")  # invalid support_id
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	var begin: ActionResult = session.begin(generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(1), 18, &"sword", &"none", null, malformed)
	assert_true(begin.is_error(), "A malformed loadout support must be rejected up front (fail-closed).")
	assert_equal(begin.error_code, &"invalid_loadout_support", "A malformed support uses the stable invalid_loadout_support code.")


# ---- Story 14.1: the Wait/pass-turn backstop + corpse-walkability -------------------------------

# A wait tap commits (advances_turn) and runs the enemy phase (the turn number climbs) — the F1 backstop.
func _wait_tap_advances_the_turn_and_runs_the_enemy_phase() -> void:
	var generation: GenerationResult = _generate_small_combat(VICTORY_SEED)
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	assert_true(session.begin(generation.payload.get("board", {}), generation.payload.get("entrance", {}), RngStreamSet.new(VICTORY_SEED)).succeeded, "Setup: the session begins.")
	var turn_before: int = session.turn_state().turn_number
	var result_value: ActionResult = session.submit_wait()
	assert_true(result_value.succeeded, "A wait tap commits: %s" % result_value.metadata)
	assert_equal(result_value.metadata.get("advances_turn"), true, "A wait advances the turn (the enemy phase runs).")
	assert_true(session.turn_state().turn_number > turn_before, "A committed wait runs the enemy phase (EnemyTurnResolver advances the turn number).")
	assert_equal(session.turn_state().phase, session.turn_state().Phase.PLAYER_PLANNING, "After the enemy phase the turn returns to PLAYER_PLANNING.")
	assert_true(_has_hero_waited(session.event_log()), "The wait tap appends a hero_waited event to the log.")


# The F1 CORE: a hero boxed in by walls + a live enemy can act again once the enemy dies — the vacated corpse cell
# becomes a legal move. A second enemy is walled off so the fight continues (this is mid-fight, not a victory).
func _corpse_cell_becomes_walkable_mid_fight() -> void:
	var session: InteractiveCombatSession = InteractiveCombatSession.new()
	assert_true(session.begin(_boxed_by_corpse_snapshot(), {"x": 1, "y": 1}, RngStreamSet.new(7)).succeeded, "Setup: the boxed-corpse session begins.")
	var corpse_cell: Vector2i = Vector2i(2, 1)
	assert_false(session.board().can_occupy(corpse_cell, HERO_ID).succeeded, "Before the kill the live enemy blocks the hero's only non-wall neighbor (the boxed-in F1 state).")
	# Kill the adjacent enemy (arm + commit). The enemy dies; the walled-off second enemy keeps the fight going.
	session.tap_attack(corpse_cell)
	session.tap_attack(corpse_cell)
	assert_false(session.is_terminal(), "A walled-off second enemy keeps the fight going after the first kill.")
	assert_true(session.board().can_occupy(corpse_cell, HERO_ID).succeeded, "The death cell becomes walkable after corpse-clearing (the F1 fix).")
	assert_equal(session.board().occupant_at(corpse_cell), &"", "The corpse cell no longer holds a blocking occupant.")
	var corpse: TacticalEntityState = session.board().get_entity(&"enemy_a")
	assert_true(corpse != null and corpse.is_dead(), "The dead enemy STAYS on the board (a corpse, hp 0).")
	var move_result: ActionResult = session.submit_move(corpse_cell)
	assert_true(move_result.succeeded, "The boxed-in hero can now move onto the vacated corpse cell (a previously-illegal move is legal): %s" % move_result.metadata)
	assert_equal(session.board().get_entity(HERO_ID).position, corpse_cell, "The hero now stands on the former corpse cell (co-located with the corpse).")


# A wait fails closed before begin (session_not_begun) and after a terminal outcome (session_terminal) — zero mutation.
func _wait_is_rejected_before_begin_and_after_terminal() -> void:
	var unbegun: InteractiveCombatSession = InteractiveCombatSession.new()
	var before_begin: ActionResult = unbegun.submit_wait()
	assert_true(before_begin.is_error(), "A wait before begin is rejected.")
	assert_equal(before_begin.error_code, &"session_not_begun", "A pre-begin wait uses the session_not_begun code.")
	var duel: InteractiveCombatSession = InteractiveCombatSession.new()
	assert_true(duel.begin(_adjacent_duel_snapshot(), {"x": 1, "y": 1}, RngStreamSet.new(1)).succeeded, "Setup: the duel begins.")
	duel.tap_attack(Vector2i(2, 1))
	duel.tap_attack(Vector2i(2, 1))
	assert_true(duel.is_terminal() and duel.is_victory(), "Setup: the duel is won (a terminal outcome).")
	var after_terminal: ActionResult = duel.submit_wait()
	assert_true(after_terminal.is_error(), "A wait after a terminal outcome is rejected.")
	assert_equal(after_terminal.error_code, &"session_terminal", "A post-terminal wait uses the session_terminal code.")


# A 6x3 board where the hero (entrance 1,1) is boxed by walls + a 1-HP enemy_a at (2,1); a second enemy_b at (4,1) is
# walled off (divider wall at (3,1)) so it cannot reach the hero and the fight continues after the first kill.
func _boxed_by_corpse_snapshot() -> Dictionary:
	var width: int = 6
	var height: int = 3
	var enemy_a: Dictionary = {"entity_id": "enemy_a", "entity_type": "enemy", "faction": "labyrinth", "position": {"x": 2, "y": 1}, "current_hp": 1, "max_hp": 1, "blocks_movement": true, "definition_id": "iron_cultist"}
	var enemy_b: Dictionary = {"entity_id": "enemy_b", "entity_type": "enemy", "faction": "labyrinth", "position": {"x": 4, "y": 1}, "current_hp": 10, "max_hp": 10, "blocks_movement": true, "definition_id": "iron_cultist"}
	var cells: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			var terrain: int = BoardCell.Terrain.FLOOR
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 3 and y == 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 1 and y == 1:
				terrain = BoardCell.Terrain.ENTRANCE
			var occupant: String = ""
			if x == 2 and y == 1:
				occupant = "enemy_a"
			elif x == 4 and y == 1:
				occupant = "enemy_b"
			cells.append({"position": {"x": x, "y": y}, "terrain": terrain, "occupant_id": occupant, "explored": true, "visible": true})
	return {"width": width, "height": height, "next_sequence_id": 1, "cells": cells, "entities": [enemy_a, enemy_b]}


func _has_hero_waited(events: Array) -> bool:
	for event_value: Variant in events:
		if event_value is DomainEvent and (event_value as DomainEvent).event_type == DomainEvent.Type.HERO_WAITED:
			return true
	return false

# ---- helpers -------------------------------------------------------------------------------------

# Drive the session to a terminal outcome with a scripted tap sequence: attack the first attackable enemy (arm then
# commit — the two-step flow), else approach the nearest enemy by one cardinal step. This mirrors the LiveCombatResolver
# scripted-hero discipline but routes EVERY action through the session's TAP API (submit_move / tap_attack) — proving
# the tap loop reaches the same terminal outcomes the auto-resolver reaches.
func _drive_scripted_taps_to_terminal(session: InteractiveCombatSession) -> void:
	var steps: int = 0
	while not session.is_terminal() and steps < MAX_TAP_STEPS:
		steps += 1
		var board: BoardState = session.board()
		var attack_target: TacticalEntityState = _first_attackable_enemy(board, session.hero_weapon())
		if attack_target != null:
			# The two-step commit: arm, then confirm on the SAME target.
			session.tap_attack(attack_target.position)
			session.tap_attack(attack_target.position)
			continue
		var step: Vector2i = _next_approach_step(board)
		if step == Vector2i(-1, -1):
			# No attack, no approach — a benign legal step so the enemy phase still runs (avoid a stalled loop).
			step = _any_legal_step(board)
		if step == Vector2i(-1, -1):
			break
		session.submit_move(step)


func _first_attackable_enemy(board: BoardState, weapon) -> TacticalEntityState:
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null or hero.is_dead():
		return null
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or entity.is_dead():
			continue
		var preview: ActionResult = AttackPreviewQuery.new().preview_target_cell(board, HERO_ID, entity.position, weapon)
		if preview.succeeded:
			return entity
	return null


func _next_approach_step(board: BoardState) -> Vector2i:
	var target: TacticalEntityState = _nearest_living_enemy(board)
	if target == null:
		return Vector2i(-1, -1)
	var approach: ActionResult = TacticalPathQuery.new().approach_path_to_adjacent_target(board, HERO_ID, target.entity_id)
	if approach.is_error():
		return Vector2i(-1, -1)
	var next_step: Dictionary = approach.metadata.get("next_step", {})
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	var step_cell: Vector2i = Vector2i(int(next_step.get("x", hero.position.x)), int(next_step.get("y", hero.position.y)))
	if step_cell == hero.position:
		return Vector2i(-1, -1)
	return step_cell


func _any_legal_step(board: BoardState) -> Vector2i:
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null or hero.is_dead():
		return Vector2i(-1, -1)
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var destination: Vector2i = hero.position + direction
		if board.can_occupy(destination, HERO_ID).succeeded:
			return destination
	return Vector2i(-1, -1)


func _nearest_living_enemy(board: BoardState) -> TacticalEntityState:
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null:
		return null
	var best: TacticalEntityState = null
	var best_distance: int = 1 << 30
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or entity.is_dead():
			continue
		var distance: int = maxi(absi(entity.position.x - hero.position.x), absi(entity.position.y - hero.position.y))
		if distance < best_distance:
			best_distance = distance
			best = entity
	return best


func _living_enemy_count(board: BoardState) -> int:
	var count: int = 0
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type == TacticalEntityState.EntityType.ENEMY and entity.is_alive():
			count += 1
	return count


func _generate_small_combat(seed_value: int) -> GenerationResult:
	var request: GenerationRequest = GenerationRequest.new(seed_value, &"node_1_0", &"combat", &"small_combat_basic", GenerationRequest.SIZE_SMALL)
	return LevelGenerator.generate(request, LevelRecipeRepository.create_baseline_repository(), EnemyRepository.create_baseline_repository())


# A tiny 4x3 board: WALL border, entrance(1,1), a 1-HP enemy adjacent at (2,1). A single sword attack kills it.
func _adjacent_duel_snapshot() -> Dictionary:
	var width: int = 4
	var height: int = 3
	var enemy: Dictionary = {
		"entity_id": "enemy_a",
		"entity_type": "enemy",
		"faction": "labyrinth",
		"position": {"x": 2, "y": 1},
		"current_hp": 1,
		"max_hp": 1,
		"blocks_movement": true,
		"definition_id": "iron_cultist"
	}
	var cells: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			var terrain: int = BoardCell.Terrain.FLOOR
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 1 and y == 1:
				terrain = BoardCell.Terrain.ENTRANCE
			var occupant: String = "enemy_a" if (x == 2 and y == 1) else ""
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": terrain,
				"occupant_id": occupant,
				"explored": true,
				"visible": true
			})
	return {
		"width": width,
		"height": height,
		"next_sequence_id": 1,
		"cells": cells,
		"entities": [enemy]
	}


func _empty_board_snapshot() -> Dictionary:
	var board: BoardState = BoardState.new()
	var create_result: ActionResult = load("res://scripts/core/commands/create_board_command.gd").new(3, 3).execute(board)
	assert_true(create_result.succeeded, "Setup: the empty board should build.")
	return board.to_snapshot()


# A tiny 4x3 board: WALL border, entrance(1,1), a DURABLE 10-HP iron_cultist adjacent at (2,1). A single sword hit does
# not kill it, so it survives the hero's attack and melee-attacks the SHIELDED hero on the enemy phase — engaging the
# shield_block roll on the hero's DEFENDER support (the shield protects its owner on incoming hits — the hero-defense seam).
func _durable_adjacent_duel_snapshot() -> Dictionary:
	var width: int = 4
	var height: int = 3
	var enemy: Dictionary = {
		"entity_id": "enemy_a",
		"entity_type": "enemy",
		"faction": "labyrinth",
		"position": {"x": 2, "y": 1},
		"current_hp": 10,
		"max_hp": 10,
		"blocks_movement": true,
		"definition_id": "iron_cultist"
	}
	var cells: Array[Dictionary] = []
	for y: int in range(height):
		for x: int in range(width):
			var terrain: int = BoardCell.Terrain.FLOOR
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				terrain = BoardCell.Terrain.WALL
			elif x == 1 and y == 1:
				terrain = BoardCell.Terrain.ENTRANCE
			var occupant: String = "enemy_a" if (x == 2 and y == 1) else ""
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": terrain,
				"occupant_id": occupant,
				"explored": true,
				"visible": true
			})
	return {
		"width": width,
		"height": height,
		"next_sequence_id": 1,
		"cells": cells,
		"entities": [enemy]
	}


# The number of shield_block `combat`-stream rolls recorded in a session's event log (the warrior off-hand signal).
func _shield_block_roll_count(events: Array) -> int:
	var count: int = 0
	for event_value: Variant in events:
		if not event_value is DomainEvent:
			continue
		var event: DomainEvent = event_value
		for draw_value: Variant in event.payload.get("rng_draws", []):
			if String((draw_value as Dictionary).get("effect_id", "")) == "shield_block":
				count += 1
	return count
