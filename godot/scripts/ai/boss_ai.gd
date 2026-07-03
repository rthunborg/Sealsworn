class_name BossAi
extends RefCounted

# The Larval Avatar BOSS AI (Story 9.3, FR63, AC3) — the boss analogue of PrototypeEnemyAi. Given the live boss board
# entity + the BossDefinition, it SCORES only the ACTIVE phase's legal actions (BossDefinition.legal_action_ids for the
# phase recomputed from the boss's current HP) with FIXED integer scores and returns the highest-scoring choice as an
# AiDecision-shaped DTO carrying a stable `score` + a `reasons` array + the chosen boss ability's telegraph/damage/
# explanation in metadata (so the combat explanation log can name the ability — AC4). It is a PURE READ over
# (board, boss_entity, player_id, pending_telegraphs, turn_number, definition): it draws ZERO RNG (no randi/randf/fresh
# RandomNumberGenerator), runs NO commands, and mutates NOTHING — same inputs -> the same decision (AC3's "reproducible
# for the same seed and state" is pure determinism, NOT a seeded roll). Distinct scores are authored so ties never
# occur; a two-damaging-ability phase breaks the tie deterministically by HIGHER damage then declaration order.
#
# THE ADAPTER ACTION IDS it emits (mirroring PrototypeEnemyAi's attack/move/mark/detonate/wait vocabulary, but boss-
# shaped): `resolve` (a DUE boss telegraph detonates — score 120, the highest, so pending danger resolves first),
# `telegraph` (the major dangerous ability telegraphs the player's cell this turn — score 80), `move` (skitter, a
# zero-damage reposition one cardinal step toward the player — score 50), `wait` (nothing legal — score 0). The chosen
# BOSS ability id (lash / skitter / corrupt_mark / frenzied_lash / corrupt_flood) rides `metadata.action_id` so the
# adapter can resolve its telegraph_text/damage/damage_type/explanation and the log can name it. The one-turn response
# window (AC1) is the SAME due_turn == created_turn + 1 gap the Ash Seer uses — realized by the boss adapter, NFR10
# forbids a real-time timer.

const AiDecision = preload("res://scripts/ai/ai_decision.gd")
const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossActionDefinition = preload("res://scripts/content/definitions/boss_action_definition.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossPhaseDefinition = preload("res://scripts/content/definitions/boss_phase_definition.gd")
const BossPhaseResolver = preload("res://scripts/content/boss/boss_phase_resolver.gd")
const PendingTelegraphState = preload("res://scripts/tactical/turns/pending_telegraph_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalLineQuery = preload("res://scripts/tactical/targeting/tactical_line_query.gd")
const TacticalPathQuery = preload("res://scripts/tactical/movement/tactical_path_query.gd")

# The Manhattan range within which the boss can telegraph a marked-tile danger on the player (it must also have line of
# sight). Beyond this the boss SKITTERS (approaches) to close the gap first — the readable "advance, then telegraph"
# behavior. A fixed authored constant (NOT a difficulty knob — difficulty is a hard non-goal).
const TELEGRAPH_RANGE := 6

# Fixed deterministic utility scores (mirroring PrototypeEnemyAi's fixed-score posture — reproducibility is pure
# determinism, NOT a roll). Distinct so ties never occur across action KINDS; within one phase a two-damaging-ability
# tie is broken by higher damage then declaration order.
const SCORE_RESOLVE := 120
const SCORE_TELEGRAPH := 80
const SCORE_MOVE := 50
const SCORE_WAIT := 0

var _phase_resolver: BossPhaseResolver = BossPhaseResolver.new()

# Decide the boss's action for this turn. `definition` is the BossDefinition (the 9.2 content read through
# BossRepository). The active phase is RECOMPUTED from `boss.current_hp` (no stored phase state). Returns an AiDecision
# with an adapter action id + a stable integer score + reasons + (for a telegraph/resolve) the boss ability metadata.
func decide(
	board: BoardState,
	boss: TacticalEntityState,
	player_id: StringName,
	pending_telegraphs: Array[Dictionary],
	turn_number: int,
	definition: BossDefinition
) -> AiDecision:
	if board == null or boss == null:
		return _wait(&"", &"", &"invalid_context", ["invalid_context"])
	if boss.is_dead():
		return _wait(boss.entity_id, boss.definition_id, &"dead", ["dead_boss"])
	if definition == null:
		return _wait(boss.entity_id, boss.definition_id, &"invalid_definition", ["missing_boss_definition"])

	var active_phase_index: int = _phase_resolver.active_phase_index(definition, boss.current_hp)
	var phase: BossPhaseDefinition = definition.get_phase(active_phase_index)
	if phase == null:
		return _wait(boss.entity_id, definition.boss_id, &"invalid_phase", ["missing_active_phase"], active_phase_index)

	var legal_action_ids: Array[StringName] = definition.legal_action_ids(active_phase_index)

	# (1) A DUE boss telegraph resolves FIRST (score 120) — pending danger lands before a new action (the Ash Seer
	# detonate-before-mark precedent). The player got their turn between the telegraph and now (the response window).
	var due_telegraph: Dictionary = _due_telegraph_for_boss(boss.entity_id, pending_telegraphs, turn_number)
	if not due_telegraph.is_empty():
		return _resolve_decision(boss, definition, active_phase_index, due_telegraph)

	var player: TacticalEntityState = board.get_entity(player_id)
	if player == null or player.is_dead():
		return _wait(boss.entity_id, definition.boss_id, &"missing_target", ["missing_player_target"], active_phase_index)

	# (2) A damaging ability TELEGRAPHS the player's cell (score 80) when in range + line of sight. If the phase offers
	# two damaging abilities, pick the highest-damage one (then declaration order) — the "major dangerous ability".
	var damaging_action: BossActionDefinition = _select_major_damaging_action(phase, legal_action_ids)
	if damaging_action != null:
		var distance: int = _manhattan_distance(boss.position, player.position)
		var has_los: bool = TacticalLineQuery.has_line_of_sight(board, boss.position, player.position)
		if distance <= TELEGRAPH_RANGE and has_los:
			return _telegraph_decision(boss, player, definition, active_phase_index, damaging_action)

	# (3) A MOVEMENT ability (skitter) approaches one cardinal step toward the player (score 50).
	if _has_movement_action(phase, legal_action_ids):
		var move_decision: AiDecision = _move_decision(board, boss, player, definition, active_phase_index, legal_action_ids, phase)
		if move_decision != null:
			return move_decision

	# (4) Nothing legal to do this turn — wait deterministically.
	return _wait(boss.entity_id, definition.boss_id, &"no_legal_action", ["no_legal_action"], active_phase_index)


# The DUE boss telegraph (a pending larval_avatar_telegraph whose due turn is at/past `turn_number`, sourced by this
# boss, still pending). Returns the pending dict copy or {} if none is due. The "is my telegraph due this turn?" read,
# mirroring PrototypeEnemyAi._due_mark_for_enemy.
func _due_telegraph_for_boss(
	boss_id: StringName,
	pending_telegraphs: Array[Dictionary],
	turn_number: int
) -> Dictionary:
	for telegraph: Dictionary in pending_telegraphs:
		if String(telegraph.get("kind", "")) != PendingTelegraphState.KIND_LARVAL_AVATAR_TELEGRAPH:
			continue
		if String(telegraph.get("source_entity_id", "")) != String(boss_id):
			continue
		if String(telegraph.get("status", "pending")) != PendingTelegraphState.STATUS_PENDING:
			continue
		if int(telegraph.get("due_turn_number", 0)) > turn_number:
			continue
		return telegraph.duplicate(true)
	return {}


# Pick the phase's MAJOR damaging ability: the legal action with damage > 0 that has the HIGHEST damage; ties broken by
# declaration order (the first-declared wins). Returns null if the phase has no damaging action (a pure-reposition
# phase). Deterministic — no RNG.
func _select_major_damaging_action(phase: BossPhaseDefinition, legal_action_ids: Array[StringName]) -> BossActionDefinition:
	var best: BossActionDefinition = null
	for action_id: StringName in legal_action_ids:
		var action: BossActionDefinition = phase.get_action(action_id)
		if action == null or action.damage <= 0:
			continue
		if best == null or action.damage > best.damage:
			best = action
	return best


func _has_movement_action(phase: BossPhaseDefinition, legal_action_ids: Array[StringName]) -> bool:
	for action_id: StringName in legal_action_ids:
		var action: BossActionDefinition = phase.get_action(action_id)
		if action != null and action.damage <= 0:
			return true
	return false


func _first_movement_action_id(phase: BossPhaseDefinition, legal_action_ids: Array[StringName]) -> StringName:
	for action_id: StringName in legal_action_ids:
		var action: BossActionDefinition = phase.get_action(action_id)
		if action != null and action.damage <= 0:
			return action.action_id
	return &""


# Build the RESOLVE decision (a due telegraph detonates). Carries the marked cell + the pending telegraph metadata (the
# adapter reads telegraph_id + damage + damage_type from it) so the resolution is deterministic + explainable.
func _resolve_decision(
	boss: TacticalEntityState,
	definition: BossDefinition,
	active_phase_index: int,
	due_telegraph: Dictionary
) -> AiDecision:
	var marked_cell: Vector2i = _cell_from_metadata(due_telegraph.get("marked_cell", {}))
	var metadata: Dictionary = due_telegraph.duplicate(true)
	metadata["boss_action_id"] = String(due_telegraph.get("boss_action_id", ""))
	metadata["active_phase_index"] = active_phase_index
	metadata["adapter_action"] = "resolve"
	return AiDecision.new(
		boss.entity_id,
		definition.boss_id,
		&"resolve",
		SCORE_RESOLVE,
		["due_telegraph", "boss_ability_resolves"],
		StringName(str(due_telegraph.get("target_entity_id", ""))),
		boss.position,
		boss.position,
		marked_cell,
		&"",
		metadata
	)


# Build the TELEGRAPH decision (a major dangerous ability marks the player's cell this turn; damage lands next turn if
# the player stays). Carries the chosen boss ability's telegraph_text / damage / damage_type / explanation so the
# adapter can emit an explainable pending telegraph (AC1/AC4).
func _telegraph_decision(
	boss: TacticalEntityState,
	player: TacticalEntityState,
	definition: BossDefinition,
	active_phase_index: int,
	action: BossActionDefinition
) -> AiDecision:
	return AiDecision.new(
		boss.entity_id,
		definition.boss_id,
		&"telegraph",
		SCORE_TELEGRAPH,
		["line_of_sight", "major_dangerous_ability", "delayed_resolution"],
		player.entity_id,
		boss.position,
		boss.position,
		player.position,
		&"",
		{
			"boss_action_id": String(action.action_id),
			"telegraph_text": action.telegraph_text,
			"damage": action.damage,
			"damage_type": String(action.damage_type),
			"explanation": action.explanation,
			"active_phase_index": active_phase_index,
			"adapter_action": "telegraph"
		}
	)


# Build the MOVE (skitter) decision — one cardinal step along the shortest approach to an adjacent-to-player cell,
# reusing TacticalPathQuery (the boss does NOT re-implement pathing). Returns null if no legal approach exists (the
# caller falls through to wait).
func _move_decision(
	board: BoardState,
	boss: TacticalEntityState,
	player: TacticalEntityState,
	definition: BossDefinition,
	active_phase_index: int,
	legal_action_ids: Array[StringName],
	phase: BossPhaseDefinition
) -> AiDecision:
	var path_result: ActionResult = TacticalPathQuery.new().approach_path_to_adjacent_target(board, boss.entity_id, player.entity_id)
	if path_result.is_error():
		return null
	var next_step: Vector2i = _cell_from_metadata(path_result.metadata.get("next_step", {}))
	var target_cell: Vector2i = _cell_from_metadata(path_result.metadata.get("target_cell", {}))
	if next_step == boss.position:
		return null
	return AiDecision.new(
		boss.entity_id,
		definition.boss_id,
		&"move",
		SCORE_MOVE,
		["shortest_path", "skitter"],
		player.entity_id,
		boss.position,
		next_step,
		target_cell,
		&"",
		{
			"boss_action_id": String(_first_movement_action_id(phase, legal_action_ids)),
			"movement_cost": 1,
			"path_cost": int(path_result.metadata.get("movement_cost", 0)),
			"active_phase_index": active_phase_index,
			"adapter_action": "move"
		}
	)


func _wait(
	boss_id: StringName,
	definition_id: StringName,
	wait_reason: StringName,
	reasons: Array[String],
	active_phase_index: int = -1
) -> AiDecision:
	var metadata: Dictionary = {
		"wait_reason": String(wait_reason),
		"adapter_action": "wait"
	}
	if active_phase_index >= 0:
		metadata["active_phase_index"] = active_phase_index
	return AiDecision.new(
		boss_id,
		definition_id,
		&"wait",
		SCORE_WAIT,
		reasons,
		&"",
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		Vector2i(-1, -1),
		wait_reason,
		metadata
	)


func _manhattan_distance(first: Vector2i, second: Vector2i) -> int:
	return abs(first.x - second.x) + abs(first.y - second.y)


func _cell_from_metadata(value: Variant) -> Vector2i:
	if not value is Dictionary:
		return Vector2i(-1, -1)
	var cell_data: Dictionary = value
	return Vector2i(int(cell_data.get("x", -1)), int(cell_data.get("y", -1)))
