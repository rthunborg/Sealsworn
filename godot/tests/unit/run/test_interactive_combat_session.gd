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
