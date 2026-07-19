class_name TacticalRangeHighlightView
extends RefCounted

# Story 14.10 (AC2/AC3 — the F10 fix) — the PURE, SCENE-FREE MOVE-RANGE + ATTACK-RANGE highlight seam. Given the
# live board + the hero actor id + the hero weapon + the board VM `turn` slot, it returns the highlight cell sets
# the presenter draws as additive board-overlay ops (a distinct SHAPE channel per set — NFR9).
#
# ⭐ IT REUSES THE EXISTING QUERIES — it adds NO new domain query, no new BFS, no new traversal:
#   - MOVE-range: TacticalMovementQuery.validate_target(board, actor_id, cell, budget) per candidate cell, keeping
#     the cells it returns `valid` for. Candidates are pre-filtered to the Manhattan budget window around the actor
#     (a cheapness optimization — validate_target rejects the rest as `beyond_budget` anyway; every legal move is
#     inside that window because Manhattan distance is a lower bound on the cardinal path cost).
#   - ATTACK-range: AttackPreviewQuery.preview_target_cell(board, actor_id, cell, weapon) per occupant cell, keeping
#     the cells it returns `legal: true` for. A corpse returns dead_target / missing_target (its cell occupancy was
#     released on death) and is naturally EXCLUDED — a corpse is never highlighted as an attack target (the 14.2
#     corpse-tap-is-inspect rule). Friendly / out-of-range / not-aligned / blocked-line targets are excluded too.
#
# ⭐ IT IS A PURE READ. Both queries mutate nothing and draw ZERO RNG; board.get_entity / board.entities return
# COPIES, so nothing the seam touches perturbs the board. It mints NO event, adds NO board-VM key, and leaks NO
# live handle (FRESH plain-data {x,y} dicts). It is a RefCounted DTO — NOT a Control/Node/scene.
#
# ⭐ FAIL-CLOSED + TURN-GATED (AC2): highlights are computed ONLY when it is the player's PLANNING turn AND the hero
# is alive; otherwise has_highlights == false with empty sets and an honest `reason`. The pinned key set is
# IDENTICAL for the present and absent projections.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const TacticalMovementQuery = preload("res://scripts/tactical/movement/tactical_movement_query.gd")
const AttackPreviewQuery = preload("res://scripts/tactical/targeting/attack_preview_query.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")

# The EXACT top-level key set (the exact-key discipline — a key never silently appears/vanishes; a test pins it).
const VIEW_KEYS: Array[String] = [
	"has_highlights",
	"move_cells",
	"attack_cells",
	"reason"
]

# The default per-tap hero movement budget (the SAME budget the live move uses — the command bridge defaults an
# omitted movement_budget to MoveCommand.BASELINE_MOVEMENT_BUDGET, which equals this — so the highlight matches the
# actual legal move set).
const MOVEMENT_BUDGET := TacticalMovementQuery.DEFAULT_MOVEMENT_BUDGET

# The honest gate reasons (the ActionResult.reason discipline). `valid` means the highlights were computed for a
# live player-planning turn; the rest explain an empty projection.
const REASON_VALID := "valid"
const REASON_NOT_PLAYER_TURN := "not_player_turn"
const REASON_NO_ACTOR := "no_actor"
const REASON_DEAD_ACTOR := "dead_actor"
const REASON_NO_BOARD := "no_board"


# Project the move + attack highlight cell sets. A null board / a non-player-planning turn / a missing or dead
# actor projects the empty fact with the matching reason. `movement_budget <= 0` clamps to 1 (never a zero-budget
# query the movement query would reject). A FRESH dictionary each call; every cell is a plain {x,y} dict.
static func project(
	board: BoardState,
	actor_id: StringName,
	weapon: WeaponDefinition,
	turn: Dictionary = {},
	movement_budget: int = MOVEMENT_BUDGET
) -> Dictionary:
	if board == null:
		return _empty(REASON_NO_BOARD)
	# Turn-gate: only the player's PLANNING phase (the window the player can act in).
	if String(turn.get("phase", "")) != String(TacticalTurnState.PHASE_PLAYER_PLANNING):
		return _empty(REASON_NOT_PLAYER_TURN)
	if actor_id == &"":
		return _empty(REASON_NO_ACTOR)
	var actor: TacticalEntityState = board.get_entity(actor_id)
	if actor == null:
		return _empty(REASON_NO_ACTOR)
	if actor.is_dead():
		return _empty(REASON_DEAD_ACTOR)

	var budget: int = maxi(1, movement_budget)
	return {
		"has_highlights": true,
		"move_cells": _move_cells(board, actor_id, actor.position, budget),
		"attack_cells": _attack_cells(board, actor_id, weapon),
		"reason": REASON_VALID
	}


# The legal MOVE cells within the Manhattan budget window (reusing validate_target for the final legality call — no
# new traversal). Excludes the actor's own cell and any cell the query rejects (out-of-bounds / blocked / occupied /
# unreachable / beyond-budget / not-visible).
static func _move_cells(board: BoardState, actor_id: StringName, origin: Vector2i, budget: int) -> Array:
	var query: TacticalMovementQuery = TacticalMovementQuery.new()
	var cells: Array = []
	for dy: int in range(-budget, budget + 1):
		var remaining: int = budget - absi(dy)
		for dx: int in range(-remaining, remaining + 1):
			if dx == 0 and dy == 0:
				continue
			var cell: Vector2i = Vector2i(origin.x + dx, origin.y + dy)
			if not board.in_bounds(cell):
				continue
			var result: ActionResult = query.validate_target(board, actor_id, cell, budget)
			if result.succeeded and String(result.metadata.get("reason", "")) == "valid":
				cells.append(_cell(cell))
	return cells


# The legal ATTACK cells among the board occupants (reusing preview_target_cell for the final legality call — no new
# traversal). A null weapon yields no attack cells (defensive — a live fight always has a resolved weapon). A corpse
# is excluded by the query (dead_target / missing_target); a friendly / out-of-range / mis-aligned / blocked target
# is excluded too.
static func _attack_cells(board: BoardState, actor_id: StringName, weapon: WeaponDefinition) -> Array:
	if weapon == null:
		return []
	var query: AttackPreviewQuery = AttackPreviewQuery.new()
	var cells: Array = []
	for entity: TacticalEntityState in board.entities():
		if entity.entity_id == actor_id:
			continue
		var result: ActionResult = query.preview_target_cell(board, actor_id, entity.position, weapon)
		if result.succeeded and bool(result.metadata.get("legal", false)):
			cells.append(_cell(entity.position))
	return cells


static func _empty(reason: String) -> Dictionary:
	return {
		"has_highlights": false,
		"move_cells": [],
		"attack_cells": [],
		"reason": reason
	}


static func _cell(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}
