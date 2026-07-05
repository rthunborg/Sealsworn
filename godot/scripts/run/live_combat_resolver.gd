class_name LiveCombatResolver
extends RefCounted

# The SCENE-FREE LIVE COMBAT DRIVER (Story 11.2, AC1) — the generalized Epic1MicroCombatScenario for a RUN NODE. It
# resolves a combat / elite-combat level node from REAL tactical play on the board (a deterministic scripted hero driving
# player commands through the tactical command stack, enemy turns through the existing EnemyTurnResolver) to a TERMINAL
# CombatOutcomeState (STATE_VICTORY / STATE_DEFEAT), instead of the v0 `_resolve_combat` auto-resolve-to-success.
#
# ⭐ IT WIRES THE EXISTING SEAMS; IT DOES NOT FORK A PARALLEL COMBAT LOOP. It composes the SAME building blocks the
# Epic-1 micro-combat scenario composes (`scripts/tactical/scenarios/epic_1_micro_combat_scenario.gd`) — a live BoardState,
# a TacticalActionContext, MoveCommand/AttackCommand through the board, EnemyTurnResolver.resolve_after_player_action, and
# CombatOutcomeEvaluator — but generalized so ANY generated combat board resolves deterministically to a board outcome.
# The DIFFERENCE from the Epic-1 scenario is only the GENERALIZATION (any board, any enemy set, a bounded scripted hero
# loop), not a new combat rule.
#
# ⭐ IT IS A SCENE-FREE RefCounted DOMAIN DRIVER (the `run`/tactical seam). NO get_tree/get_node, NO autoload, NO scene, NO
# presenter. The HUD that RENDERS this fight is Story 11.3; 11.2 builds the scene-free loop 11.3 will drive from taps. The
# scripted hero here stands in for the human/HUD player exactly as Epic1MicroCombatScenario's scripted path does.
#
# ⭐ RNG DISCIPLINE (AC4 — the determinism guard): the loop draws gameplay RNG ONLY through the run-level RngStreamSet
# handed in, on the `combat` stream (an attack proc / a shield block — via AttackCommand's existing draws). It NEVER calls
# randi/randf/constructs a fresh RandomNumberGenerator. The DEFAULT hero weapon (`sword`) has NO proc and carries NO
# shield, so a default live fight draws ZERO `combat` RNG — keeping the live loop from perturbing any stream the
# non-live / auto-resolve simulation path advances (the additive, opt-in posture). A caller that arms the hero with a
# proc weapon (axe/mace) draws the `combat` stream deterministically (reproducible from the seed/state).
#
# ⭐ THE HERO LOADOUT IS DRIVER-SUPPLIED (documented scope boundary): 11.2 wires the run-combat SEAM, not the class-kit ->
# combat loadout (that is a later story). The hero's starting HP + weapon are supplied by the caller (a strong sword hero
# by default). This mirrors how test_finale_full_run.gd supplies the hero for the boss fight. The hero is placed at the
# generated level's ENTRANCE cell (the run-flow hero-placement seam — generation places enemies only, never the hero).
#
# ⭐ IT ALWAYS TERMINATES: the scripted hero attacks any in-range enemy else approaches the nearest one; a bounded round
# cap (MAX_ROUNDS) guards against a non-progressing board. On the cap the resolver returns a structured
# `live_combat_did_not_resolve` error (fail-loud) rather than a fabricated outcome — a caller treats it as a hard combat
# error (no partial run progression), exactly like a generation failure. For the tuned driver loadouts a fixed seed
# reaches a real terminal outcome well within the cap.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatOutcomeEvaluator = preload("res://scripts/tactical/outcomes/combat_outcome_evaluator.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const EnemyTurnResolver = preload("res://scripts/tactical/turns/enemy_turn_resolver.gd")
const MoveCommand = preload("res://scripts/core/commands/move_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalPathQuery = preload("res://scripts/tactical/movement/tactical_path_query.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

const HERO_ID := &"hero"
const HERO_FACTION := &"player"
# The default driver hero loadout (a strong melee `sword` hero — reliable adjacent damage, no proc, so a default live
# fight draws ZERO `combat` RNG and perturbs no stream). HP is high enough to out-trade the baseline enemy budget on any
# generated Small/Medium board while the focus-fire hero closes and kills enemies one at a time. Caller-overridable (a
# weak/low-HP hero drives a real board DEFEAT — the live hero-death source, AC2). `sword` is melee (attack_range 1,
# TARGETING_ADJACENT_CARDINAL) so once the hero is adjacent it always connects — no line-of-sight/alignment stall the
# ranged weapons (staff/bow) hit against a non-moving seer.
const DEFAULT_HERO_HP: int = 60
const DEFAULT_HERO_WEAPON := &"sword"
# The hero's per-turn movement budget when approaching (the MoveCommand baseline). Kept modest so the fight reads as a
# real advance-and-strike, not a teleport.
const HERO_MOVE_BUDGET: int = 3
# Bounded round cap (a generous guard). Each round is one hero action + one enemy phase; a Small/Medium board with the
# baseline enemy budget resolves in a handful of rounds. On the cap the resolver fails loud (never a fabricated outcome).
const MAX_ROUNDS: int = 64

var _enemy_repository: EnemyRepository = null
var _weapon_repository: WeaponRepository = null
# The hero's CURRENTLY-LOCKED target (a deterministic focus-fire discipline). The scripted hero commits to ONE enemy
# until it is dead before re-picking, so it never OSCILLATES between two equidistant enemies (which would stall the loop
# without ever closing on either). Re-picked (to the nearest living enemy) only when the locked target dies / vanishes.
var _locked_target_id: StringName = &""

func _init(enemy_repository: EnemyRepository = null, weapon_repository: WeaponRepository = null) -> void:
	_enemy_repository = enemy_repository if enemy_repository != null else EnemyRepository.create_baseline_repository()
	_weapon_repository = weapon_repository if weapon_repository != null else WeaponRepository.create_baseline_repository()


# Resolve a hero weapon through the repository boundary (validated weapons only; null on a miss). Exposed so a caller
# (the boss auto-play) can resolve the same driver loadout without re-implementing the lookup.
func hero_weapon(weapon_id: StringName) -> WeaponDefinition:
	return _weapon_repository.get_weapon(weapon_id)


# Drive ONE hero action against a SPECIFIC target entity (Story 11.2 — the boss auto-play reuses the scripted-hero
# discipline against the single boss target). Attack the target if the AttackCommand accepts it from here (in range +
# aligned), else step one cardinal cell toward it (approach). Does NOT run any enemy/boss phase — the caller sequences
# the opponent's turn (the boss auto-play runs BossTurnResolver.resolve_boss_turn after this). Returns the hero action's
# events (a benign no-op ok if the hero is momentarily stuck — the caller's round loop + cap handles a stall). This is
# the SAME hero AI the level-combat loop uses (attack-in-range-else-approach), generalized to one caller-named target.
func drive_hero_step_against(context: TacticalActionContext, weapon: WeaponDefinition, target_id: StringName) -> ActionResult:
	var board: BoardState = context.board
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	var target: TacticalEntityState = board.get_entity(target_id)
	if hero == null or hero.is_dead() or target == null or target.is_dead():
		return ActionResult.ok([], {"acted": false})

	# Attack if the command accepts the target from the hero's current position; else approach one cardinal step.
	var attack: AttackCommand = AttackCommand.new(HERO_ID, target.position, weapon)
	if attack.validate(context).succeeded:
		var attack_result: ActionResult = attack.execute(context)
		if attack_result.is_error():
			return _error(&"hero_command_failed", {"inner_error_code": String(attack_result.error_code)})
		# Return the hero to PLAYER_PLANNING (AttackCommand does not advance the turn state itself; the caller runs the
		# opponent turn next, which expects PLAYER_PLANNING with the hero active — matching the enemy-resolver contract).
		context.turn_state.phase = TacticalTurnState.Phase.PLAYER_PLANNING
		context.turn_state.active_actor_id = HERO_ID
		return ActionResult.ok(attack_result.events, {"acted": true, "action": "attack"})

	var approach: ActionResult = TacticalPathQuery.new().approach_path_to_adjacent_target(board, HERO_ID, target_id)
	if approach.is_error():
		return ActionResult.ok([], {"acted": false, "reason": String(approach.error_code)})
	var next_step: Dictionary = approach.metadata.get("next_step", {})
	var step_cell: Vector2i = Vector2i(int(next_step.get("x", hero.position.x)), int(next_step.get("y", hero.position.y)))
	if step_cell == hero.position:
		return ActionResult.ok([], {"acted": false})
	var move: MoveCommand = MoveCommand.new(HERO_ID, step_cell, HERO_MOVE_BUDGET)
	var move_result: ActionResult = move.execute(context)
	if move_result.is_error():
		return _error(&"hero_command_failed", {"inner_error_code": String(move_result.error_code)})
	context.turn_state.phase = TacticalTurnState.Phase.PLAYER_PLANNING
	context.turn_state.active_actor_id = HERO_ID
	return ActionResult.ok(move_result.events, {"acted": true, "action": "move"})


# Resolve a live combat from a generated level payload's board snapshot to a TERMINAL CombatOutcomeState. `board_snapshot`
# is generation.payload["board"] (the board snapshot — NOT payload.level_seed, the seed string). `entrance` is
# generation.payload["entrance"] (the {x,y} hero-placement cell). `streams` is the RUN-LEVEL RngStreamSet (the ONLY RNG
# source — the `combat` stream). `hero_hp` / `hero_weapon_id` are the driver-supplied loadout (a strong sword hero by
# default; a weak/low-HP hero drives a real board DEFEAT). Returns ok with metadata carrying the terminal outcome
# (`outcome` == victory/defeat), the live board, the event log, and the round count — or a structured error (a rejected
# board restore / an unresolved fight / a driver step failure) with ZERO partial progression.
func resolve(
	board_snapshot: Dictionary,
	entrance: Dictionary,
	streams: RngStreamSet,
	hero_hp: int = DEFAULT_HERO_HP,
	hero_weapon_id: StringName = DEFAULT_HERO_WEAPON
) -> ActionResult:
	if streams == null:
		return _error(&"invalid_streams")
	# Restore the live board through the STRICT validator (the 1.3 validate-then-reject — never restore a corrupt board).
	var board_result: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	if board_result.is_error():
		return _error(&"invalid_board_snapshot", {"inner_error_code": String(board_result.error_code)})
	var board: BoardState = board_result.metadata.get("board") as BoardState

	# Resolve the hero weapon through the repository boundary (validated weapons only; fail-closed on a miss).
	var weapon: WeaponDefinition = _weapon_repository.get_weapon(hero_weapon_id)
	if weapon == null:
		return _error(&"unknown_hero_weapon", {"weapon_id": String(hero_weapon_id)})

	# Place the hero at the generated ENTRANCE cell (generation places enemies only; the run flow places the hero). Clamp
	# HP to a valid positive value (a 0/negative hero would be born dead).
	var entrance_cell: Vector2i = Vector2i(int(entrance.get("x", 0)), int(entrance.get("y", 0)))
	var resolved_hp: int = maxi(1, hero_hp)
	var hero: TacticalEntityState = TacticalEntityState.new(
		HERO_ID, TacticalEntityState.EntityType.PLAYER, HERO_FACTION, entrance_cell, resolved_hp, resolved_hp, true, HERO_ID
	)
	var place_result: ActionResult = board.place_entity_for_setup(hero)
	if place_result.is_error():
		return _error(&"hero_placement_failed", {"inner_error_code": String(place_result.error_code)})
	# Full visibility (headless drive — fog does not decide the outcome; the CombatOutcomeEvaluator reads HP only).
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true

	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, HERO_ID)
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, [])
	var enemy_resolver: EnemyTurnResolver = EnemyTurnResolver.new(_enemy_repository, HERO_ID)
	var outcome_state: CombatOutcomeState = CombatOutcomeState.new()
	var event_log: Array[DomainEvent] = []

	# Evaluate the STARTING board (a degenerate zero-enemy level is already a victory; never enter the loop needing a
	# hero action for an already-decided board).
	var initial_eval: ActionResult = _evaluate(board, outcome_state, event_log)
	if initial_eval.is_error():
		return initial_eval
	var rounds: int = 0
	while not outcome_state.is_terminal() and rounds < MAX_ROUNDS:
		rounds += 1
		var step: ActionResult = _drive_hero_turn(context, weapon, enemy_resolver, event_log)
		if step.is_error():
			return step
		var eval: ActionResult = _evaluate(board, outcome_state, event_log)
		if eval.is_error():
			return eval

	if not outcome_state.is_terminal():
		# Fail loud: the scripted hero could not force a terminal board within the bound. Never fabricate an outcome.
		return _error(&"live_combat_did_not_resolve", {"rounds": rounds})

	return ActionResult.ok(event_log, {
		"outcome": String(outcome_state.state_id),
		"is_victory": outcome_state.state_id == CombatOutcomeState.STATE_VICTORY,
		"is_defeat": outcome_state.state_id == CombatOutcomeState.STATE_DEFEAT,
		"rounds": rounds,
		"board": board,
		"outcome_state": outcome_state.to_dictionary()
	})


# Drive ONE hero turn: attack an in-range aligned enemy if there is one, else approach the nearest enemy, else wait a
# beat (a no-op advance). Whatever the hero does, the enemy phase resolves after it (EnemyTurnResolver — the enemies
# advance + strike). The player command's events + the enemy phase's events are appended to the log (for the
# CombatOutcomeEvaluator's damage-cause attribution + the caller's diagnostics).
func _drive_hero_turn(
	context: TacticalActionContext,
	weapon: WeaponDefinition,
	enemy_resolver: EnemyTurnResolver,
	event_log: Array[DomainEvent]
) -> ActionResult:
	var board: BoardState = context.board
	var command: Variant = _choose_hero_command(board, weapon)
	if command == null:
		# No enemy reachable AND none in range (a stalled board) — advance the turn with a benign self-move (step in
		# place is invalid, so try any legal 1-cell move; if none, the enemies still get their phase via a wait-move).
		command = _fallback_move(board)
	if command == null:
		# Truly stuck (no legal hero move at all): resolve the enemy phase directly so the fight still progresses (the
		# enemies close/strike). Build a synthetic advancing player result so the resolver runs the enemy phase.
		return _resolve_enemy_phase_only(context, enemy_resolver, event_log)

	var command_result: ActionResult = command.execute(context)
	if command_result.is_error():
		return _error(&"hero_command_failed", {"inner_error_code": String(command_result.error_code)})
	for event: DomainEvent in command_result.events:
		event_log.append(event)

	var enemy_result: ActionResult = enemy_resolver.resolve_after_player_action(context, command_result)
	if enemy_result.is_error():
		return _error(&"enemy_turn_failed", {"inner_error_code": String(enemy_result.error_code)})
	for event: DomainEvent in enemy_result.events:
		event_log.append(event)
	return ActionResult.ok(command_result.events + enemy_result.events)


# Choose the hero's command for this turn: attack ANY in-range aligned living enemy the preview accepts (opportunistic —
# a wandering enemy that steps into range is struck), else FOCUS-FIRE the locked target (approach it by one cardinal step
# toward an adjacent cell). Returns null when the hero can neither attack nor approach the locked target (the caller
# falls back to a benign move / an enemy-only phase so the loop still progresses).
func _choose_hero_command(board: BoardState, weapon: WeaponDefinition) -> Variant:
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null or hero.is_dead():
		return null

	# 1) Opportunistic attack: the FIRST living enemy (board order) the AttackCommand would accept from here (aligned +
	# in range + reachable line). Board order is deterministic. This kills whatever wandered into range this turn.
	var attack_target: TacticalEntityState = _first_attackable_enemy(board, weapon)
	if attack_target != null:
		# Lock onto whatever we are hitting (so the follow-up approach chases the SAME enemy until it dies).
		_locked_target_id = attack_target.entity_id
		return AttackCommand.new(HERO_ID, attack_target.position, weapon)

	# 2) Focus-fire approach: pursue the LOCKED target (re-locking to the nearest living enemy if the lock is dead/gone),
	# stepping one cardinal cell toward a cell adjacent to it. Committing to one target prevents oscillation between two
	# equidistant enemies (the stall the naive "nearest each turn" driver hit).
	var target: TacticalEntityState = _resolve_locked_target(board)
	if target == null:
		return null
	var approach: ActionResult = TacticalPathQuery.new().approach_path_to_adjacent_target(board, HERO_ID, target.entity_id)
	if approach.is_error():
		# The locked target is momentarily unreachable (boxed in) — drop the lock so next turn re-locks to another enemy.
		_locked_target_id = &""
		return null
	var next_step: Dictionary = approach.metadata.get("next_step", {})
	var step_cell: Vector2i = Vector2i(int(next_step.get("x", hero.position.x)), int(next_step.get("y", hero.position.y)))
	if step_cell == hero.position:
		return null
	return MoveCommand.new(HERO_ID, step_cell, HERO_MOVE_BUDGET)


# The currently-locked target if it is still living, else re-lock to the nearest living enemy (and return it). Returns
# null when no enemy lives (a decided board — the caller stops).
func _resolve_locked_target(board: BoardState) -> TacticalEntityState:
	if _locked_target_id != &"":
		var locked: TacticalEntityState = board.get_entity(_locked_target_id)
		if locked != null and locked.is_alive() and locked.entity_type == TacticalEntityState.EntityType.ENEMY:
			return locked
	var nearest: TacticalEntityState = _nearest_living_enemy(board)
	_locked_target_id = nearest.entity_id if nearest != null else &""
	return nearest


# The first living enemy (board order) the attack preview would ACCEPT from the hero's current position with this weapon
# (aligned + within attack_range + line reachable). Uses the AttackCommand's own validate() as the acceptance oracle so
# the driver never submits an attack the command rejects.
func _first_attackable_enemy(board: BoardState, weapon: WeaponDefinition) -> TacticalEntityState:
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or entity.is_dead():
			continue
		# A throwaway context probe: build the AttackCommand and check it validates against a PLAYER_PLANNING turn with
		# the hero active. The real context is PLAYER_PLANNING with the hero active by construction, so this mirrors it.
		var probe: TacticalActionContext = _probe_context(board)
		var command: AttackCommand = AttackCommand.new(HERO_ID, entity.position, weapon)
		if command.validate(probe).succeeded:
			return entity
	return null


# The nearest living enemy by Chebyshev distance (ties broken by board order — deterministic).
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


# A benign 1-cell legal move for the hero (used when no enemy is in range and no approach path exists), so the turn still
# advances and the enemy phase runs. Returns null if the hero cannot legally move at all.
func _fallback_move(board: BoardState) -> Variant:
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null or hero.is_dead():
		return null
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var destination: Vector2i = hero.position + direction
		if board.can_occupy(destination, HERO_ID).succeeded:
			return MoveCommand.new(HERO_ID, destination, HERO_MOVE_BUDGET)
	return null


# Resolve ONLY the enemy phase (when the hero has no legal action at all) by synthesizing a minimal advancing player
# result so EnemyTurnResolver runs the enemies (they close + strike). This keeps a fully-boxed-in hero fight progressing
# toward a terminal board (the enemies eventually reach + kill it, or a stalemate hits the cap and fails loud).
func _resolve_enemy_phase_only(
	context: TacticalActionContext,
	enemy_resolver: EnemyTurnResolver,
	event_log: Array[DomainEvent]
) -> ActionResult:
	var synthetic_player_result: ActionResult = ActionResult.ok([], {"advances_turn": true})
	var enemy_result: ActionResult = enemy_resolver.resolve_after_player_action(context, synthetic_player_result)
	if enemy_result.is_error():
		return _error(&"enemy_turn_failed", {"inner_error_code": String(enemy_result.error_code)})
	for event: DomainEvent in enemy_result.events:
		event_log.append(event)
	return ActionResult.ok(enemy_result.events)


# A PLAYER_PLANNING context over the SAME live board (for the attack-acceptance probe). Shares the board + streams by
# reference; the probe only reads (validate()), it never executes.
func _probe_context(board: BoardState) -> TacticalActionContext:
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, HERO_ID)
	return TacticalActionContext.new(board, turn_state, RngStreamSet.new(0), [])


# Evaluate the board for a terminal outcome (hero 0 HP -> defeat; all enemies dead -> victory) and fold the outcome event
# into the log. A pure read of HP over the board (the Epic-1 CombatOutcomeEvaluator).
func _evaluate(board: BoardState, outcome_state: CombatOutcomeState, event_log: Array[DomainEvent]) -> ActionResult:
	var eval: ActionResult = CombatOutcomeEvaluator.new(HERO_ID).evaluate(board, outcome_state, event_log)
	if eval.is_error():
		return _error(&"outcome_evaluation_failed", {"inner_error_code": String(eval.error_code)})
	for event: DomainEvent in eval.events:
		event_log.append(event)
	return ActionResult.ok(eval.events)


func _error(code: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"command": "live_combat_resolver"}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(code, result_metadata)
