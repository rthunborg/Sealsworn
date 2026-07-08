class_name InteractiveCombatSession
extends RefCounted

# The SCENE-FREE, STEP-DRIVEN LIVE-COMBAT SESSION (Story 12.1, AC1/AC2/AC3/AC4) — the interactive counterpart of
# LiveCombatResolver. LiveCombatResolver resolves a generated combat level in ONE atomic call (a scripted focus-fire
# hero loop to a terminal CombatOutcomeState); this session holds a LIVE fight in progress ACROSS taps, driving ONE
# player action per tap (the human replaces the scripted driver for on-screen play). It is the ON-SCREEN driver; the
# LiveCombatResolver auto-resolve loop stays the headless/proof driver (byte-identical, untouched).
#
# ⭐ IT REUSES THE SAME BUILDING BLOCKS LiveCombatResolver COMPOSES — it does NOT fork a parallel combat loop, and it
# owns NO gameplay decision a command/resolver does not:
#   - the board is restored through the STRICT BoardState.try_from_snapshot (the 1.3 validate-then-reject),
#   - the affinity board effect is applied on the built board BEFORE hero placement (the SAME
#     AffinityEffectResolver.apply_board_effects call the resolver uses — a neutral `none` / null repo is a no-op,
#     byte-identical to the plain live combat),
#   - the hero is placed at the generated ENTRANCE cell (generation places enemies only),
#   - each COMMITTED player action goes through TacticalCommandBridge / TacticalAttackCommitFlow (the ONE submission
#     seam — AC2 "no parallel combat path"; the first attack tap PREVIEWS/arms, the second COMMITS),
#   - the enemy phase runs via EnemyTurnResolver.resolve_after_player_action after each committed action (AC3),
#   - the Scorched DoT ticks (AffinityHazardDamageCommand) gated on the affinity PLAN (resolve_board_plan's
#     scorched_hazard_cells — the 11.4 L1 discipline, NOT the apply's stamped-diff) once per entity per round at the
#     end of its own action, and
#   - CombatOutcomeState is re-evaluated via CombatOutcomeEvaluator after each action (a terminal VICTORY/DEFEAT is
#     the session's stop signal — AC4).
#
# ⭐ RNG DISCIPLINE (AC4): the session draws gameplay RNG ONLY through the injected run-level RngStreamSet, on the
# `combat` stream (via AttackCommand's existing draws — the default sword hero draws ZERO combat RNG). It NEVER calls
# randi/randf, constructs a fresh RandomNumberGenerator, or opens a new RNG stream. The affinity apply + the Scorched
# DoT are ZERO-RNG.
#
# ⭐ FAIL-CLOSED (AC2): an invalid/rejected player intent surfaces the command's own ActionResult / disabled-result
# reason (never a crash, never a fabricated outcome) and mutates nothing — a rejected action does NOT advance the turn
# and the enemy phase does not run. A terminal CombatOutcomeState (VICTORY/DEFEAT) is the stop signal; taps after a
# terminal outcome are rejected `session_terminal`.
#
# ⭐ EPHEMERAL: the in-node fight state is NOT saved (the 23-key RunSnapshot gate stays 23; there is no in-node fight
# save). The hero loadout is DRIVER-SUPPLIED (DEFAULT_HERO_HP 60 / sword by default).
#
# ⭐ STORY 12.2 (AC1/AC3/AC4) — the CLASS-KIT LOADOUT is now threaded in: begin(...) additively accepts the loadout
# hero_support (the class off-hand — warrior shield / pyromancer tome / ranger none). The session STORES it and applies
# it the way a hero carries ONE off-hand: the hero's OWN attacks (tap_attack) carry it as the ATTACKER support (a
# pyromancer tome adds its +1 staff bonus), and it is seated on the enemy resolver as the DEFENDER support so an INCOMING
# enemy attack on the hero rolls the seeded shield_block on the `combat` stream (a warrior shield protects its OWNER —
# the hero-defense seam). The hero's shield NEVER lands on the enemy the hero strikes. The block / bonus is the
# INTENTIONAL, seeded, reproducible AC4 change on the CLASS path (re-pin any live-combat fixture it moves). The DEFAULT
# (null support / the neutral SUPPORT_NONE) is the byte-identical no-support path — it never carries a `combat` draw, so
# the neutral default / auto-resolve / generator paths stay byte-identical.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityEffectResolver = preload("res://scripts/rules/operations/affinity_effect_resolver.gd")
const AffinityHazardDamageCommand = preload("res://scripts/core/commands/affinity_hazard_damage_command.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatOutcomeEvaluator = preload("res://scripts/tactical/outcomes/combat_outcome_evaluator.gd")
const CombatOutcomeState = preload("res://scripts/tactical/outcomes/combat_outcome_state.gd")
const CommandBridgeResult = preload("res://scripts/ui/command_bridge/command_bridge_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const EnemyTurnResolver = preload("res://scripts/tactical/turns/enemy_turn_resolver.gd")
const LiveCombatResolver = preload("res://scripts/run/live_combat_resolver.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const SupportDefinition = preload("res://scripts/content/definitions/support_definition.gd")
const TacticalActionContext = preload("res://scripts/tactical/tactical_action_context.gd")
const TacticalAttackCommitFlow = preload("res://scripts/ui/view_models/tactical_attack_commit_flow.gd")
const TacticalCommandBridge = preload("res://scripts/ui/command_bridge/tactical_command_bridge.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

# The hero identity mirrors LiveCombatResolver (the ONE hero the run flow places at the entrance).
const HERO_ID := LiveCombatResolver.HERO_ID
const HERO_FACTION := LiveCombatResolver.HERO_FACTION
const HERO_MOVE_BUDGET: int = LiveCombatResolver.HERO_MOVE_BUDGET

var _enemy_repository: EnemyRepository = null
var _weapon_repository: WeaponRepository = null
# The command bridge (the ONE submission seam — validates before mutation) + the two-step attack commit flow (arm ->
# confirm), the SAME contracts the tactical board presenter uses. The session OWNS the commit flow so a confirm tap
# that actually commits is detectable (to then run the enemy phase).
var _command_bridge: TacticalCommandBridge = TacticalCommandBridge.new()
var _commit_flow: TacticalAttackCommitFlow = TacticalAttackCommitFlow.new()

# The live fight state (set by begin(); null before). The board + turn state are the LIVE, mutated-in-place inputs the
# hosting shell RENDERS.
var _board: BoardState = null
var _turn_state: TacticalTurnState = null
var _context: TacticalActionContext = null
var _enemy_resolver: EnemyTurnResolver = null
var _outcome_state: CombatOutcomeState = null
var _weapon: WeaponDefinition = null
# Story 12.2 (AC3) — the hero's class-kit loadout support (the off-hand — shield/tome; null for the neutral SUPPORT_NONE
# or a kit-less run). Set by begin(); used as the hero's ATTACKER support on tap_attack (a tome bonus) AND seated on the
# enemy resolver as the DEFENDER support (a shield block on incoming enemy attacks — the hero-defense seam). Null keeps
# the tap loop byte-identical to the plain (no-support) session.
var _loadout_support: SupportDefinition = null
var _event_log: Array[DomainEvent] = []
var _affinity_id: StringName = AffinityDefinition.AFFINITY_NONE
# Whether the live board carries Scorched HAZARD cells (derived from the affinity EFFECT PLAN — the 11.4 L1 discipline,
# NOT the apply's stamped-diff), gating the per-turn Scorched DoT tick. False on a neutral / non-Scorched board (the
# tick is never even entered — byte-identical to the plain live loop).
var _scorched_hazard_active: bool = false
var _begun: bool = false

func _init(enemy_repository: EnemyRepository = null, weapon_repository: WeaponRepository = null) -> void:
	_enemy_repository = enemy_repository if enemy_repository != null else EnemyRepository.create_baseline_repository()
	_weapon_repository = weapon_repository if weapon_repository != null else WeaponRepository.create_baseline_repository()


# Begin the live fight from a generated level payload (the SAME inputs LiveCombatResolver.resolve takes). Restores the
# board, applies the affinity board effect BEFORE hero placement, places the hero at the entrance, and evaluates the
# STARTING board (a degenerate zero-enemy board begins already victorious). Returns ok with the live board + turn state
# + outcome for the render, or a structured error (a rejected board restore / affinity apply / hero placement / unknown
# weapon) with ZERO partial state. Idempotent-guarded: a second begin() rejects `session_already_begun`.
func begin(
	board_snapshot: Dictionary,
	entrance: Dictionary,
	streams: RngStreamSet,
	hero_hp: int = LiveCombatResolver.DEFAULT_HERO_HP,
	hero_weapon_id: StringName = LiveCombatResolver.DEFAULT_HERO_WEAPON,
	affinity_id: StringName = AffinityDefinition.AFFINITY_NONE,
	affinity_repository: AffinityRepository = null,
	hero_support: SupportDefinition = null
) -> ActionResult:
	if _begun:
		return _error(&"session_already_begun")
	if streams == null:
		return _error(&"invalid_streams")

	# Restore the live board through the STRICT validator (never restore a corrupt board).
	var board_result: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	if board_result.is_error():
		return _error(&"invalid_board_snapshot", {"inner_error_code": String(board_result.error_code)})
	var board: BoardState = board_result.metadata.get("board") as BoardState

	# Apply the affinity's BOARD EFFECT onto the restored board BEFORE the hero is placed (Scorched stamps HAZARD cells;
	# Flooded/Cursed/Darkness/neutral stamp nothing). The SAME AffinityEffectResolver.apply_board_effects the resolver
	# uses — a null repo / the neutral `none` id is a no-op, byte-identical to the plain live path. The Scorched-DoT gate
	# is derived from the affinity EFFECT PLAN (resolve_board_plan's scorched_hazard_cells — the 11.4 L1 discipline).
	_affinity_id = affinity_id
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

	# Story 12.2 (AC3) — validate the class-kit loadout support up front (fail-closed on a malformed support, exactly as
	# AttackCommand would reject it) so a bad support never silently degrades mid-fight. A null support (SUPPORT_NONE /
	# kit-less run) is the byte-identical no-support path.
	if hero_support != null:
		var support_validation: ActionResult = hero_support.validate()
		if support_validation.is_error():
			return _error(&"invalid_loadout_support", {
				"support_id": String(hero_support.support_id),
				"inner_error_code": String(support_validation.error_code)
			})
	_loadout_support = hero_support

	# Place the hero at the generated ENTRANCE cell. Clamp HP to a valid positive value (a 0/negative hero is born dead).
	var entrance_cell: Vector2i = Vector2i(int(entrance.get("x", 0)), int(entrance.get("y", 0)))
	var resolved_hp: int = maxi(1, hero_hp)
	var hero: TacticalEntityState = TacticalEntityState.new(
		HERO_ID, TacticalEntityState.EntityType.PLAYER, HERO_FACTION, entrance_cell, resolved_hp, resolved_hp, true, HERO_ID
	)
	var place_result: ActionResult = board.place_entity_for_setup(hero)
	if place_result.is_error():
		return _error(&"hero_placement_failed", {"inner_error_code": String(place_result.error_code)})
	# Full visibility for the headless drive (fog does not decide the outcome; the evaluator reads HP only). The scene's
	# fog/visibility read is a presentation concern — the domain outcome is HP-only, exactly as LiveCombatResolver does.
	for board_cell: BoardCell in board.cells():
		board_cell.visible = true
		board_cell.explored = true

	_board = board
	_weapon = weapon
	_turn_state = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, HERO_ID)
	_context = TacticalActionContext.new(_board, _turn_state, streams, [])
	# Story 12.2 (AC3 — the hero-defense seam): the seated loadout support is the DEFENDER support on the enemy phase — a
	# warrior shield engages the seeded shield_block roll on INCOMING enemy attacks (it protects its OWNER on screen). A
	# null loadout support keeps the enemy phase byte-identical to the plain (no-support) session.
	_enemy_resolver = EnemyTurnResolver.new(_enemy_repository, HERO_ID, _loadout_support)
	_outcome_state = CombatOutcomeState.new()
	_event_log = []
	_begun = true

	# Evaluate the STARTING board (a degenerate zero-enemy level is already a victory; never enter the tap loop needing a
	# hero action for an already-decided board).
	var initial_eval: ActionResult = _evaluate()
	if initial_eval.is_error():
		return initial_eval

	return ActionResult.ok([], {
		"board": _board,
		"turn_state": _turn_state,
		"affinity_id": String(_affinity_id),
		"outcome": String(_outcome_state.state_id),
		"is_terminal": _outcome_state.is_terminal()
	})


# --- reads (the hosting shell RENDERS these; the domain owns the state) ----------------------------

func board() -> BoardState:
	return _board


func turn_state() -> TacticalTurnState:
	return _turn_state


func context() -> TacticalActionContext:
	return _context


func outcome_state() -> CombatOutcomeState:
	return _outcome_state


func hero_weapon() -> WeaponDefinition:
	return _weapon


# Story 12.2 (AC3) — the stored class-kit loadout support (or null for the no-support path). A pure read for the
# presenter / tests; the session owns the seated support the taps inherit.
func loadout_support() -> SupportDefinition:
	return _loadout_support


func event_log() -> Array[DomainEvent]:
	return _event_log


func is_terminal() -> bool:
	return _outcome_state != null and _outcome_state.is_terminal()


func is_victory() -> bool:
	return _outcome_state != null and _outcome_state.state_id == CombatOutcomeState.STATE_VICTORY


func is_defeat() -> bool:
	return _outcome_state != null and _outcome_state.state_id == CombatOutcomeState.STATE_DEFEAT


# The current attack commit-flow state (the presenter binds this to the confirm/cancel region — the two-step FR11 UX).
func commit_flow_state() -> Dictionary:
	return _commit_flow.to_dictionary()


# --- the tap seam (ONE player action per tap through the EXISTING command-bridge / commit-flow contracts) ---

# Submit a MOVE tap: drive ONE MoveCommand through the command bridge (validate-before-mutation). On a COMMITTED move
# the enemy phase runs (the resolve-then-advance per-action seam); a rejected move surfaces the command's own reason
# and mutates nothing (fail-closed, no turn advance, no enemy phase). Returns the ActionResult so the shell/test reads
# the outcome.
func submit_move(target_cell: Vector2i, movement_budget: int = -1) -> ActionResult:
	if not _begun:
		return _error(&"session_not_begun")
	if is_terminal():
		return _error(&"session_terminal")
	# A pending attack preview is cleared when the player switches to a move tap (the presentation-flow reset).
	_commit_flow.clear_for_non_attack_tile(target_cell)

	var intent: Dictionary = {
		"intent_id": "move",
		"actor_id": String(HERO_ID),
		"target_cell": target_cell
	}
	if movement_budget > 0:
		intent["movement_budget"] = movement_budget
	var move_result: ActionResult = _command_bridge.execute_intent(_context, intent)
	if move_result.is_error():
		# Fail-closed: the command's own reason surfaces; ZERO mutation, no turn advance, no enemy phase.
		return move_result
	for event: DomainEvent in move_result.events:
		_event_log.append(event)
	return _resolve_after_committed_action(move_result)


# Submit an ATTACK tap through the TWO-STEP commit flow: the first tap ARMS attack_preview; a second tap on the SAME
# target/weapon/actor CONFIRMS (executes through the bridge). On a CONFIRMED-and-EXECUTED attack the enemy phase runs.
# The FIRST (arming) tap mutates NOTHING and does not advance the turn (AC2/FR11). Returns the commit-flow result.
func tap_attack(
	target_cell: Vector2i,
	attacker_support: SupportDefinition = null,
	defender_support: SupportDefinition = null
):
	if not _begun:
		return _commit_flow.clear_for_mode_switch(&"session_not_begun")
	if is_terminal():
		return _commit_flow.clear_for_mode_switch(&"session_terminal")

	# Story 12.2 (AC3) — default the ATTACKER support to the stored class-kit loadout support when the caller does not
	# override (the on-screen shell / the scripted proof driver pass none and inherit the seated class off-hand). The
	# hero's OWN attack carries the support only in the ATTACKER slot: a pyromancer tome adds its +1 staff bonus. The
	# DEFENDER slot is the ENEMY the hero strikes (no support by default) — the hero's shield NEVER protects the enemy; it
	# protects the HERO on the enemy phase (seated on _enemy_resolver as the defender support — the hero-defense seam). A
	# null loadout support keeps this byte-identical to the plain no-support tap.
	var resolved_attacker_support: SupportDefinition = attacker_support if attacker_support != null else _loadout_support
	var flow_result = _commit_flow.tap_attack_target(
		_context, HERO_ID, target_cell, _weapon, resolved_attacker_support, defender_support, _command_bridge
	)
	# A COMMITTED attack (the second confirming tap that executed through the bridge) advances the turn -> run the enemy
	# phase. An arm/cancel/reject does not (the fight is untouched).
	if flow_result != null and flow_result.submitted:
		var command_result = flow_result.command_result
		if command_result != null and command_result.succeeded:
			for event: DomainEvent in command_result.events:
				_event_log.append(event)
			_resolve_after_committed_action(command_result)
	return flow_result


# Cancel the pending attack preview (zero mutation).
func cancel_attack():
	return _commit_flow.cancel()


# Submit an INSPECT tap (metadata-only through the bridge — no mutation, no turn advance). Returns the CommandBridgeResult.
func inspect(target_cell: Vector2i) -> CommandBridgeResult:
	if not _begun:
		return CommandBridgeResult.disabled_result(&"inspect", &"session_not_begun", "session_not_begun")
	return _command_bridge.build_command(_context, {
		"intent_id": "inspect",
		"target_cell": target_cell
	})


# --- the per-action resolve-then-advance sequence (mirrors LiveCombatResolver._drive_hero_turn, step-driven) ---

# After a COMMITTED player action resolves, run the SAME post-action sequence the auto-resolve driver runs: tick the
# hero's Scorched DoT (if it ends its action on a hazard cell), run the enemy phase via EnemyTurnResolver, tick the
# enemies' Scorched DoT, then re-evaluate the outcome. A DoT death / a hero death ends the turn immediately (do not
# drive the enemy AI at a corpse — the outer _evaluate catches STATE_DEFEAT, the board death source). Returns the
# player command's result on success, or a structured error surfaced from the enemy phase / DoT.
func _resolve_after_committed_action(player_result: ActionResult) -> ActionResult:
	# Scorched DoT: tick the hero if it now ENDS the action on a Scorched HAZARD cell. ZERO on a neutral board.
	var hero_dot: ActionResult = _tick_scorched_dot(HERO_ID)
	if hero_dot.is_error():
		return hero_dot
	var hero_after_dot: TacticalEntityState = _board.get_entity(HERO_ID)
	if hero_after_dot == null or hero_after_dot.is_dead():
		# The hero burned to death — do NOT run the enemy phase against a corpse; the outer _evaluate reads the 0-HP
		# board -> STATE_DEFEAT (the board death source).
		var dot_death_eval: ActionResult = _evaluate()
		if dot_death_eval.is_error():
			return dot_death_eval
		return player_result

	# The enemy phase (EnemyTurnResolver — the enemies advance + strike). It reads the player result's advances_turn.
	var enemy_result: ActionResult = _enemy_resolver.resolve_after_player_action(_context, player_result)
	if enemy_result.is_error():
		return _error(&"enemy_turn_failed", {"inner_error_code": String(enemy_result.error_code)})
	for event: DomainEvent in enemy_result.events:
		_event_log.append(event)

	# Scorched DoT for the enemies that ended the phase on a hazard cell (each entity ticks once per round at the end of
	# its own action, so no entity double-ticks). ZERO on a neutral board.
	var enemy_dot: ActionResult = _tick_scorched_dot_enemies()
	if enemy_dot.is_error():
		return enemy_dot

	# Re-evaluate the outcome (a terminal VICTORY/DEFEAT is the session's stop signal).
	var eval: ActionResult = _evaluate()
	if eval.is_error():
		return eval
	return player_result


# Tick the Scorched burning DoT for a SINGLE entity if it occupies a HAZARD cell (the 11.4 discipline). A no-op when the
# Scorched hazard is not active, the entity is gone/dead, or it is not on a HAZARD cell (the command rejects
# `target_not_in_hazard`). ZERO RNG. A genuine command execution error surfaces structurally; a validate-rejection is
# the expected no-tick.
func _tick_scorched_dot(entity_id: StringName) -> ActionResult:
	if not _scorched_hazard_active:
		return ActionResult.ok([])
	var entity: TacticalEntityState = _board.get_entity(entity_id)
	if entity == null or entity.is_dead():
		return ActionResult.ok([])
	var occupied: BoardCell = _board.get_cell(entity.position)
	if occupied == null or occupied.terrain != BoardCell.Terrain.HAZARD:
		return ActionResult.ok([])
	var tick: ActionResult = AffinityHazardDamageCommand.new(entity_id).execute(_board)
	if tick.is_error():
		# A validate-rejection (`target_not_in_hazard` after a race) is a benign no-tick; the command is
		# validate-then-mutate so there is no fabricated tick / partial state.
		return ActionResult.ok([])
	for event: DomainEvent in tick.events:
		_event_log.append(event)
	return ActionResult.ok(tick.events)


# Tick the Scorched DoT for every living ENEMY on a HAZARD cell (after the enemy phase). Iterates a stable board-order
# copy so the tick order is deterministic. A no-op when the Scorched hazard is not active.
func _tick_scorched_dot_enemies() -> ActionResult:
	if not _scorched_hazard_active:
		return ActionResult.ok([])
	for entity: TacticalEntityState in _board.entities():
		if entity.entity_type != TacticalEntityState.EntityType.ENEMY or entity.is_dead():
			continue
		var tick: ActionResult = _tick_scorched_dot(entity.entity_id)
		if tick.is_error():
			return tick
	return ActionResult.ok([])


# Evaluate the board for a terminal outcome (hero 0 HP -> defeat; all enemies dead -> victory) and fold the outcome
# event into the log. A pure read of HP over the board (the Epic-1 CombatOutcomeEvaluator).
func _evaluate() -> ActionResult:
	var eval: ActionResult = CombatOutcomeEvaluator.new(HERO_ID).evaluate(_board, _outcome_state, _event_log)
	if eval.is_error():
		return _error(&"outcome_evaluation_failed", {"inner_error_code": String(eval.error_code)})
	for event: DomainEvent in eval.events:
		_event_log.append(event)
	return ActionResult.ok(eval.events)


func _error(code: StringName, metadata: Dictionary = {}) -> ActionResult:
	var result_metadata: Dictionary = {"command": "interactive_combat_session"}
	for key: Variant in metadata.keys():
		result_metadata[key] = metadata[key]
	return ActionResult.error(code, result_metadata)
