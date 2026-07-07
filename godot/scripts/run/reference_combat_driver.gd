class_name ReferenceCombatDriver
extends RefCounted

# Story 12.2 (AC2 — retro T2) — the STRENGTHENED, LoS-AWARE REFERENCE COMBAT DRIVER: the WINNABILITY PROOF HARNESS.
# It is the retro-T2 answer to "a human cannot yet WIN an arbitrary generated fight": a stronger scripted hero than
# the pure focus-fire LiveCombatResolver driver, able to clear an approved combat seed with the CLASS-KIT loadout (all
# three MVP classes at baseline_hp 18) where the naive focus-fire driver DIES (the 11.3 lesson — the focus-fire hero
# closes to melee and eats ash-seer detonations / stacked melee, and provably dies at 18 HP on the live walk).
#
# ⭐ IT IS A HEADLESS PROOF HARNESS, NOT A SHIPPED ON-SCREEN LOOP. On screen the HUMAN drives the hero via the 12-1
# InteractiveCombatSession tap loop (the human is presumed to play at least as well as this reference driver). This
# driver exists ONLY to PROVE, in a headless test, that a legal line of play wins each approved seed for each class.
#
# ⭐ IT REUSES THE SAME BUILDING BLOCKS LiveCombatResolver COMPOSES — it does NOT fork a parallel combat rule: the board
# is restored through the STRICT BoardState.try_from_snapshot (the 1.3 validate-then-reject), the affinity board effect
# is applied on the built board BEFORE hero placement (the SAME AffinityEffectResolver.apply_board_effects), the hero is
# placed at the generated ENTRANCE cell, every hero action is a real MoveCommand / AttackCommand through the tactical
# stack, the enemy phase runs via EnemyTurnResolver.resolve_after_player_action, the Scorched DoT ticks
# (AffinityHazardDamageCommand) gated on the affinity PLAN (the 11.4 L1 discipline), and CombatOutcomeState is
# re-evaluated via CombatOutcomeEvaluator after each action. The DIFFERENCE from LiveCombatResolver is ONLY the hero's
# TARGETING POLICY (LoS/range-aware + detonation-dodging), not a new combat rule. LiveCombatResolver.resolve(...) stays
# BYTE-IDENTICAL (the auto-resolve / hands-off proof path is untouched — this is a SIBLING driver).
#
# ⭐ THE HERO POLICY (the crux that makes 18 HP winnable):
#   1. DODGE ASH-SEER DETONATIONS — a seer marks the hero's tile (due next enemy phase) and detonates it ONLY if the
#      hero is STILL on that tile. The dominant death at 18 HP is a stationary hero eating repeated 4-damage marks. So
#      the hero NEVER ends a turn on a currently-marked tile (a HARD constraint on the end cell). A mobile hero takes
#      ZERO seer damage.
#   2. RANGED classes (staff/bow, attack_range >= 2) — open fire from range and KITE: shoot the lowest-HP aligned enemy
#      in range with a clear line, prefer firing from distance >= 2 (avoiding the adjacency damage penalty), and keep
#      >= 2 chebyshev from any LIVE MELEE enemy so the melee body cannot reach adjacency next turn (melee move budget is
#      1). Against a seers-only remainder (no melee threat) it stops kiting and just lines up the shot.
#   3. MELEE classes (sword, attack_range 1) — COMMIT to the nearest LIVE MELEE enemy (accept its melee damage to close
#      and kill it), then mop up the stationary seers for free (dodging every mark). It avoids being adjacent to MORE
#      than the one committed melee enemy (never voluntarily surrounded).
#
# ⭐ RNG DISCIPLINE (AC4 — the determinism guard): the driver draws gameplay RNG ONLY through the injected run-level
# RngStreamSet, on the `combat` stream (via AttackCommand's existing draws — the shield_block roll / a proc weapon). It
# NEVER calls randi/randf, constructs a fresh RandomNumberGenerator, or opens a new stream. A hero with NO support and a
# no-proc weapon (the ranger bow / a plain sword) draws ZERO `combat` RNG. A warrior shield (defender_support) engages
# the seeded shield_block roll; a pyromancer tome (attacker_support) adds the +1 staff bonus — the INTENTIONAL,
# reproducible AC4 change on the CLASS path. The support is threaded into BOTH AttackCommand slots (a hero carries ONE
# off-hand): the tome activates only in the attacker slot, the shield only in the defender slot; each is a legal no-op
# in the other slot.
#
# ⭐ IT ALWAYS TERMINATES: a bounded round cap (MAX_ROUNDS) guards a non-progressing board. On the cap it returns a
# structured `live_combat_did_not_resolve` (fail-loud) carrying the round count — a caller treats an unwinnable seed as
# a hard combat error (no fabricated outcome), exactly like the LiveCombatResolver auto-resolve driver. On an approved
# seed it reaches a real terminal outcome well within the cap.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityEffectResolver = preload("res://scripts/rules/operations/affinity_effect_resolver.gd")
const AffinityHazardDamageCommand = preload("res://scripts/core/commands/affinity_hazard_damage_command.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const AttackCommand = preload("res://scripts/core/commands/attack_command.gd")
const AttackPreviewQuery = preload("res://scripts/tactical/targeting/attack_preview_query.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatOutcomeEvaluator = preload("res://scripts/tactical/outcomes/combat_outcome_evaluator.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyDefinition = preload("res://scripts/content/definitions/enemy_definition.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const EnemyTurnResolver = preload("res://scripts/tactical/turns/enemy_turn_resolver.gd")
const LiveCombatResolver = preload("res://scripts/run/live_combat_resolver.gd")
const MoveCommand = preload("res://scripts/core/commands/move_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

# The hero identity mirrors LiveCombatResolver (the ONE hero the run flow places at the entrance).
const HERO_ID := LiveCombatResolver.HERO_ID
const HERO_FACTION := LiveCombatResolver.HERO_FACTION
const HERO_MOVE_BUDGET: int = LiveCombatResolver.HERO_MOVE_BUDGET
const MAX_ROUNDS: int = LiveCombatResolver.MAX_ROUNDS

# A cell that is unreachable / off-board (the sentinel a scorer returns when no legal move exists).
const NO_CELL := Vector2i(-1, -1)

var _enemy_repository: EnemyRepository = null
var _weapon_repository: WeaponRepository = null
var _scorched_hazard_active: bool = false

func _init(enemy_repository: EnemyRepository = null, weapon_repository: WeaponRepository = null) -> void:
	_enemy_repository = enemy_repository if enemy_repository != null else EnemyRepository.create_baseline_repository()
	_weapon_repository = weapon_repository if weapon_repository != null else WeaponRepository.create_baseline_repository()


# Resolve a live combat from a generated level payload's board snapshot to a TERMINAL CombatOutcomeState, driving the
# STRENGTHENED LoS-aware hero. Same signature shape as LiveCombatResolver.resolve, with the class-kit `hero_support` as
# an ADDITIVE trailing param (null = the neutral no-support path). Returns ok with { outcome, is_victory, is_defeat,
# rounds, board, outcome_state } — or a structured error (a rejected board restore / affinity apply / unknown weapon /
# unresolved fight) with ZERO partial progression.
func resolve(
	board_snapshot: Dictionary,
	entrance: Dictionary,
	streams: RngStreamSet,
	hero_hp: int = LiveCombatResolver.DEFAULT_HERO_HP,
	hero_weapon_id: StringName = LiveCombatResolver.DEFAULT_HERO_WEAPON,
	hero_support: SupportDefinition = null,
	affinity_id: StringName = AffinityDefinition.AFFINITY_NONE,
	affinity_repository: AffinityRepository = null
) -> ActionResult:
	if streams == null:
		return _error(&"invalid_streams")

	# Restore the live board through the STRICT validator (never restore a corrupt board — the 1.3 validate-then-reject).
	var board_result: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	if board_result.is_error():
		return _error(&"invalid_board_snapshot", {"inner_error_code": String(board_result.error_code)})
	var board: BoardState = board_result.metadata.get("board") as BoardState

	# Apply the affinity BOARD EFFECT onto the restored board BEFORE hero placement (the SAME AffinityEffectResolver the
	# resolver / session use — a null repo / neutral `none` id is a no-op, byte-identical to the plain live path). The
	# Scorched-DoT gate is derived from the effect PLAN (the 11.4 L1 discipline).
	_scorched_hazard_active = false
	if affinity_repository != null and String(affinity_id) != String(AffinityDefinition.AFFINITY_NONE):
		var resolver: AffinityEffectResolver = AffinityEffectResolver.new()
		var plan: Dictionary = resolver.resolve_board_plan(board, affinity_id, affinity_repository)
		_scorched_hazard_active = not (plan.get("scorched_hazard_cells", []) as Array).is_empty()
		var apply_result: ActionResult = resolver.apply_board_effects(board, affinity_id, affinity_repository)
		if apply_result.is_error():
			return _error(&"affinity_effect_failed", {
				"affinity_id": String(affinity_id),
				"inner_error_code": String(apply_result.error_code)
			})

	# Resolve the hero weapon through the repository boundary (validated weapons only; fail-closed on a miss).
	var weapon: WeaponDefinition = _weapon_repository.get_weapon(hero_weapon_id)
	if weapon == null:
		return _error(&"unknown_hero_weapon", {"weapon_id": String(hero_weapon_id)})

	# Validate the loadout support up front (fail-closed on a malformed support). A null support is the no-support path.
	if hero_support != null:
		var support_validation: ActionResult = hero_support.validate()
		if support_validation.is_error():
			return _error(&"invalid_loadout_support", {
				"support_id": String(hero_support.support_id),
				"inner_error_code": String(support_validation.error_code)
			})

	# Place the hero at the generated ENTRANCE cell (generation places enemies only). Clamp HP to a valid positive value.
	var entrance_cell: Vector2i = Vector2i(int(entrance.get("x", 0)), int(entrance.get("y", 0)))
	var resolved_hp: int = maxi(1, hero_hp)
	var hero: TacticalEntityState = TacticalEntityState.new(
		HERO_ID, TacticalEntityState.EntityType.PLAYER, HERO_FACTION, entrance_cell, resolved_hp, resolved_hp, true, HERO_ID
	)
	var place_result: ActionResult = board.place_entity_for_setup(hero)
	if place_result.is_error():
		return _error(&"hero_placement_failed", {"inner_error_code": String(place_result.error_code)})
	# Full visibility (headless drive — fog does not decide the outcome; the evaluator reads HP only).
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true

	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, HERO_ID)
	# The pending-telegraph list is SHARED with the context so the seer marks are visible to the detonation-dodge policy.
	var pending_telegraphs: Array[Dictionary] = []
	var context: TacticalActionContext = TacticalActionContext.new(board, turn_state, streams, pending_telegraphs)
	var enemy_resolver: EnemyTurnResolver = EnemyTurnResolver.new(_enemy_repository, HERO_ID)
	var outcome_state: CombatOutcomeState = CombatOutcomeState.new()
	var event_log: Array[DomainEvent] = []
	var is_ranged: bool = weapon.attack_range >= 2

	# Evaluate the STARTING board (a degenerate zero-enemy level is already a victory).
	var initial_eval: ActionResult = _evaluate(board, outcome_state, event_log)
	if initial_eval.is_error():
		return initial_eval
	var rounds: int = 0
	while not outcome_state.is_terminal() and rounds < MAX_ROUNDS:
		rounds += 1
		var step: ActionResult = _drive_hero_turn(context, weapon, hero_support, is_ranged, enemy_resolver, event_log)
		if step.is_error():
			return step
		var eval: ActionResult = _evaluate(board, outcome_state, event_log)
		if eval.is_error():
			return eval

	if not outcome_state.is_terminal():
		# Fail loud: the strengthened hero could not force a terminal board within the bound (an unwinnable seed). Never
		# fabricate an outcome — a caller treats it as a hard combat error for triage (the AC2 fail-loud).
		return _error(&"live_combat_did_not_resolve", {"rounds": rounds})

	return ActionResult.ok(event_log, {
		"outcome": String(outcome_state.state_id),
		"is_victory": outcome_state.state_id == CombatOutcomeState.STATE_VICTORY,
		"is_defeat": outcome_state.state_id == CombatOutcomeState.STATE_DEFEAT,
		"rounds": rounds,
		"board": board,
		"outcome_state": outcome_state.to_dictionary()
	})


# Drive ONE hero turn: (1) choose the best END cell (dodge marks; kite/commit per weapon), move there if it differs from
# the current cell; (2) attack the best in-range aligned enemy from the resulting position. Then tick the hero's Scorched
# DoT, run the enemy phase, tick the enemies' DoT — the SAME post-action sequence LiveCombatResolver runs.
func _drive_hero_turn(
	context: TacticalActionContext,
	weapon: WeaponDefinition,
	hero_support: SupportDefinition,
	is_ranged: bool,
	enemy_resolver: EnemyTurnResolver,
	event_log: Array[DomainEvent]
) -> ActionResult:
	var board: BoardState = context.board
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null or hero.is_dead():
		return ActionResult.ok([])

	var marked_cells: Dictionary = _marked_cells(context)

	# (1) Reposition toward the best end cell (a HARD mark-dodge constraint; kite for ranged, commit for melee).
	var dest: Vector2i = _best_end_cell(board, weapon, is_ranged, marked_cells)
	if dest != NO_CELL and dest != hero.position:
		var move: MoveCommand = MoveCommand.new(HERO_ID, dest, HERO_MOVE_BUDGET)
		var move_result: ActionResult = move.execute(context)
		if move_result.is_error():
			return _error(&"hero_command_failed", {"inner_error_code": String(move_result.error_code)})
		for event: DomainEvent in move_result.events:
			event_log.append(event)
		context.turn_state.phase = TacticalTurnState.Phase.PLAYER_PLANNING
		context.turn_state.active_actor_id = HERO_ID
		hero = board.get_entity(HERO_ID)
		if hero == null or hero.is_dead():
			return ActionResult.ok([])

	# (2) Attack the best in-range aligned enemy from the (possibly new) position.
	var target: TacticalEntityState = _best_attackable_enemy(board, weapon)
	if target != null:
		var attack: AttackCommand = AttackCommand.new(HERO_ID, target.position, weapon, hero_support, hero_support)
		if attack.validate(context).succeeded:
			var attack_result: ActionResult = attack.execute(context)
			if attack_result.is_error():
				return _error(&"hero_command_failed", {"inner_error_code": String(attack_result.error_code)})
			for event: DomainEvent in attack_result.events:
				event_log.append(event)
			context.turn_state.phase = TacticalTurnState.Phase.PLAYER_PLANNING
			context.turn_state.active_actor_id = HERO_ID

	# Scorched DoT after the hero's action (the 11.4 discipline; ZERO on a neutral board). A DoT death ends the turn
	# before the enemy phase (do not drive the enemy AI at a corpse — the outer _evaluate catches STATE_DEFEAT).
	var hero_dot: ActionResult = _tick_scorched_dot(board, HERO_ID, event_log)
	if hero_dot.is_error():
		return hero_dot
	var hero_after_dot: TacticalEntityState = board.get_entity(HERO_ID)
	if hero_after_dot == null or hero_after_dot.is_dead():
		return ActionResult.ok([])

	# The enemy phase (the enemies advance + strike + mark/detonate). The hero always advanced its turn (moved and/or
	# attacked); if it did neither (fully boxed with no attack), synthesize an advancing result so the enemies still act.
	var player_result: ActionResult = ActionResult.ok([], {"advances_turn": true})
	var enemy_result: ActionResult = enemy_resolver.resolve_after_player_action(context, player_result)
	if enemy_result.is_error():
		return _error(&"enemy_turn_failed", {"inner_error_code": String(enemy_result.error_code)})
	for event: DomainEvent in enemy_result.events:
		event_log.append(event)

	# Scorched DoT for the enemies that ended the phase on a hazard cell (each entity ticks once per round).
	var enemy_dot: ActionResult = _tick_scorched_dot_enemies(board, event_log)
	if enemy_dot.is_error():
		return enemy_dot
	return ActionResult.ok([])


# The set of cells CURRENTLY marked for detonation (a seer mark due on the upcoming enemy phase). The hero must not END
# its turn on any of these (standing on a marked cell = a detonation hit).
func _marked_cells(context: TacticalActionContext) -> Dictionary:
	var out: Dictionary = {}
	for telegraph: Dictionary in context.pending_telegraphs:
		var marked_cell: Dictionary = telegraph.get("marked_cell", {})
		out[Vector2i(int(marked_cell.get("x", -99)), int(marked_cell.get("y", -99)))] = true
	return out


# Choose the best cell for the hero to END its turn on this round. A HARD mark-dodge penalty; then a weapon-appropriate
# policy (ranged: shoot + kite; melee: commit to the nearest melee enemy). Returns the hero's current cell if no move
# improves on it (the caller then just attacks in place).
func _best_end_cell(board: BoardState, weapon: WeaponDefinition, is_ranged: bool, marked_cells: Dictionary) -> Vector2i:
	var hero: TacticalEntityState = board.get_entity(HERO_ID)
	if hero == null:
		return NO_CELL
	var origin: Vector2i = hero.position
	var melee_enemies: Array[TacticalEntityState] = _live_melee_enemies(board)
	var reachable: Array[Vector2i] = _reachable_cells(board, origin)
	var best_cell: Vector2i = origin
	var best_score: int = -(1 << 50)
	for cell: Vector2i in reachable:
		var score: int = 0
		if is_ranged:
			score = _score_ranged_cell(board, cell, weapon, melee_enemies, marked_cells)
		else:
			score = _score_melee_cell(board, cell, weapon, melee_enemies, marked_cells)
		if score > best_score:
			best_score = score
			best_cell = cell
	return best_cell


# Score a candidate cell for a RANGED hero: reward being able to shoot (prefer a low-HP target from distance >= 2), and
# — while a live melee body exists — keep >= 2 chebyshev from it (kite). Against a seers-only remainder, distance is
# irrelevant (seers do not move/melee), so the hero just lines up the shot.
func _score_ranged_cell(
	board: BoardState,
	cell: Vector2i,
	weapon: WeaponDefinition,
	melee_enemies: Array[TacticalEntityState],
	marked_cells: Dictionary
) -> int:
	var scratch: BoardState = _relocate_scratch(board, cell)
	if scratch == null:
		return -(1 << 49)
	var target: TacticalEntityState = _best_attackable_enemy(scratch, weapon)
	var can_attack: bool = target != null
	var score: int = 0
	if marked_cells.has(cell):
		score -= 100000
	if can_attack:
		score += 4000
		score += maxi(0, 300 - target.current_hp * 12)
		var attack_distance: int = absi(target.position.x - cell.x) + absi(target.position.y - cell.y)
		if attack_distance >= 2:
			score += 500
	else:
		score -= _alignment_cost(board, cell) * 60
	if not melee_enemies.is_empty():
		var distance_to_melee: int = _min_chebyshev(cell, melee_enemies)
		if distance_to_melee >= 2:
			score += 1000
		else:
			score -= 900
		score += mini(distance_to_melee, 4) * 25
	return score


# Score a candidate cell for a MELEE hero: COMMIT to the nearest live melee enemy (get adjacent to kill it), else the
# nearest enemy (a stationary seer to mop up). Reward being able to attack; penalize being adjacent to MORE than one
# melee enemy (avoid being surrounded).
func _score_melee_cell(
	board: BoardState,
	cell: Vector2i,
	weapon: WeaponDefinition,
	melee_enemies: Array[TacticalEntityState],
	marked_cells: Dictionary
) -> int:
	var scratch: BoardState = _relocate_scratch(board, cell)
	if scratch == null:
		return -(1 << 49)
	var target: TacticalEntityState = _best_attackable_enemy(scratch, weapon)
	var can_attack: bool = target != null
	var score: int = 0
	if marked_cells.has(cell):
		score -= 100000
	if can_attack:
		score += 4000
		score += maxi(0, 300 - target.current_hp * 12)
	var commit_target: TacticalEntityState = _nearest_of(cell, melee_enemies)
	if commit_target == null:
		commit_target = _nearest_living_enemy(board, cell)
	if commit_target != null:
		var commit_distance: int = maxi(absi(commit_target.position.x - cell.x), absi(commit_target.position.y - cell.y))
		score -= commit_distance * 100
	var adjacent_melee: int = 0
	for enemy: TacticalEntityState in melee_enemies:
		if maxi(absi(enemy.position.x - cell.x), absi(enemy.position.y - cell.y)) <= 1:
			adjacent_melee += 1
	if adjacent_melee > 1:
		score -= (adjacent_melee - 1) * 900
	return score


# The steps to get ONTO some live enemy's row or column (a firing-line proxy) from `cell` — min over enemies of
# min(|dx|,|dy|). Used to pull a ranged hero with no current shot toward a firing line.
func _alignment_cost(board: BoardState, cell: Vector2i) -> int:
	var best: int = 1 << 30
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or not entity.is_alive():
			continue
		var cost: int = mini(absi(entity.position.x - cell.x), absi(entity.position.y - cell.y))
		if cost < best:
			best = cost
	return best if best < (1 << 30) else 0


# The best in-range aligned enemy the AttackCommand preview accepts from the hero's CURRENT position (lowest HP first —
# finish wounded enemies). Uses the AttackPreviewQuery as the acceptance oracle so the driver never submits an attack
# the command rejects.
func _best_attackable_enemy(board: BoardState, weapon: WeaponDefinition) -> TacticalEntityState:
	var best: TacticalEntityState = null
	var best_hp: int = 1 << 30
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or entity.is_dead():
			continue
		if AttackPreviewQuery.new().preview_target_cell(board, HERO_ID, entity.position, weapon).succeeded:
			if entity.current_hp < best_hp:
				best_hp = entity.current_hp
				best = entity
	return best


# The cells the hero can reach within HERO_MOVE_BUDGET cardinal steps (a bounded BFS over occupiable cells, including
# the origin so "stay put" is always a candidate).
func _reachable_cells(board: BoardState, origin: Vector2i) -> Array[Vector2i]:
	var reachable: Array[Vector2i] = [origin]
	var visited: Dictionary = {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var cursor: int = 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		var depth: int = int(visited[current])
		if depth >= HERO_MOVE_BUDGET:
			continue
		for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next_cell: Vector2i = current + direction
			if visited.has(next_cell):
				continue
			if not board.in_bounds(next_cell):
				continue
			if not board.can_occupy(next_cell, HERO_ID).succeeded:
				continue
			visited[next_cell] = depth + 1
			queue.append(next_cell)
			reachable.append(next_cell)
	return reachable


# A SCRATCH copy of the board with the hero relocated to `cell` (a pure read for the "can I shoot from here?" scoring —
# it never mutates the live board). Restores via the strict snapshot round-trip, moves the hero, refreshes visibility.
func _relocate_scratch(board: BoardState, cell: Vector2i) -> BoardState:
	var restore: ActionResult = BoardState.try_from_snapshot(board.to_snapshot())
	if restore.is_error():
		return null
	var scratch: BoardState = restore.metadata.get("board") as BoardState
	var hero: TacticalEntityState = scratch.get_entity(HERO_ID)
	if hero == null:
		return null
	var old_cell: BoardCell = scratch.get_cell(hero.position)
	if old_cell != null:
		old_cell.occupant_id = &""
	hero.position = cell
	var new_cell: BoardCell = scratch.get_cell(cell)
	if new_cell != null:
		new_cell.occupant_id = HERO_ID
	for board_cell: BoardCell in scratch.cells():
		board_cell.visible = true
	return scratch


# The live enemies whose definition carries a melee attack (iron_cultist / gate_brute — the moving melee bodies). The
# ash_seer has melee_range 0 (it only marks from range), so it is NOT a melee threat for the kite/commit logic.
func _live_melee_enemies(board: BoardState) -> Array[TacticalEntityState]:
	var out: Array[TacticalEntityState] = []
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or not entity.is_alive():
			continue
		var definition: EnemyDefinition = _enemy_repository.get_enemy(entity.definition_id)
		if definition != null and definition.melee_range > 0:
			out.append(entity)
	return out


func _min_chebyshev(cell: Vector2i, entities: Array[TacticalEntityState]) -> int:
	var best: int = 1 << 30
	for entity: TacticalEntityState in entities:
		var distance: int = maxi(absi(entity.position.x - cell.x), absi(entity.position.y - cell.y))
		if distance < best:
			best = distance
	return best if best < (1 << 30) else 0


func _nearest_of(cell: Vector2i, group: Array[TacticalEntityState]) -> TacticalEntityState:
	var best: TacticalEntityState = null
	var best_distance: int = 1 << 30
	for entity: TacticalEntityState in group:
		var distance: int = maxi(absi(entity.position.x - cell.x), absi(entity.position.y - cell.y))
		if distance < best_distance:
			best_distance = distance
			best = entity
	return best


func _nearest_living_enemy(board: BoardState, cell: Vector2i) -> TacticalEntityState:
	var best: TacticalEntityState = null
	var best_distance: int = 1 << 30
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or not entity.is_alive():
			continue
		var distance: int = maxi(absi(entity.position.x - cell.x), absi(entity.position.y - cell.y))
		if distance < best_distance:
			best_distance = distance
			best = entity
	return best


# Story 11.4 (AC1) — tick the Scorched burning DoT for a SINGLE entity if it occupies a HAZARD cell (the 11.4 discipline,
# reused verbatim from LiveCombatResolver). ZERO on a neutral / non-Scorched board.
func _tick_scorched_dot(board: BoardState, entity_id: StringName, event_log: Array[DomainEvent]) -> ActionResult:
	if not _scorched_hazard_active:
		return ActionResult.ok([])
	var entity: TacticalEntityState = board.get_entity(entity_id)
	if entity == null or entity.is_dead():
		return ActionResult.ok([])
	var occupied: BoardCell = board.get_cell(entity.position)
	if occupied == null or occupied.terrain != BoardCell.Terrain.HAZARD:
		return ActionResult.ok([])
	var tick: ActionResult = AffinityHazardDamageCommand.new(entity_id).execute(board)
	if tick.is_error():
		return ActionResult.ok([])
	for event: DomainEvent in tick.events:
		event_log.append(event)
	return ActionResult.ok(tick.events)


func _tick_scorched_dot_enemies(board: BoardState, event_log: Array[DomainEvent]) -> ActionResult:
	if not _scorched_hazard_active:
		return ActionResult.ok([])
	for entity: TacticalEntityState in board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or entity.is_dead():
			continue
		var tick: ActionResult = _tick_scorched_dot(board, entity.entity_id, event_log)
		if tick.is_error():
			return tick
	return ActionResult.ok([])


func _evaluate(board: BoardState, outcome_state: CombatOutcomeState, event_log: Array[DomainEvent]) -> ActionResult:
	var eval: ActionResult = CombatOutcomeEvaluator.new(HERO_ID).evaluate(board, outcome_state, event_log)
	if eval.is_error():
		return _error(&"outcome_evaluation_failed", {"inner_error_code": String(eval.error_code)})
	for event: DomainEvent in eval.events:
		event_log.append(event)
	return ActionResult.ok(eval.events)


func _error(code: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"command": "reference_combat_driver"}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(code, result_metadata)
