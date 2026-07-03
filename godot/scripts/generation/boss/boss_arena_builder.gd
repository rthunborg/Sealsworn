class_name BossArenaBuilder
extends RefCounted

# The boss ARENA setup (Story 9.1, AC2) — the deterministic finale-level-snapshot producer. Given a validated
# BossEncounterRequest it builds the Larval Avatar encounter's level SNAPSHOT: a board snapshot (bounded arena
# with a WALL border + a FLOOR interior + an ENTRANCE cell), a deterministic player-start cell, a designated
# boss-entity SLOT, and finale-constraint markers. It is the boss sibling of the level pipeline's
# build_board_snapshot, but it produces a boss ARENA (NOT a combat level) and draws ZERO RNG.
#
# DETERMINISM (AC2): the arena is a FIXED, hand-authored deterministic layout — byte-identical for EVERY
# (root_seed, boss node id) by construction (the strongest determinism guarantee; it draws NO RNG, so nothing
# can diverge). The arena_seed rides the payload for provenance/reproducibility only. Whether the arena is
# fixed or seed-stable was the [Decision]; a fixed layout is the most defensible deterministic choice for the
# single MVP boss and keeps 9.1's setup off every RNG stream (no fingerprint surface at all).
#
# THE BOSS ENTITY is Story 9.2 — this builder reserves the boss-entity SLOT as an abstract MARKER
# (boss_slot: {x, y, entity_id, definition_id, is_placeholder}), mirroring how rewards are {x,y,optional}
# markers rather than board entities. The board `entities` array is EMPTY — 9.1 authors NO boss HP/stats
# (TacticalEntityState.validate() requires max_hp > 0, which WOULD be a real stat block). 9.2 attaches the
# real Larval Avatar definition at boss_slot.entity_id.
#
# PAYLOAD IS PURE SERIALIZABLE DATA (the level-pipeline rule): the emitted payload is a plain dict (a board
# snapshot dict + entrance/player_start/boss_slot + finale_constraints + arena_seed) that survives a JSON
# round-trip — NEVER a live BoardState/RefCounted. The built board snapshot is validated through the STRICT
# BoardState.try_from_snapshot (validate-then-reject; a malformed cell is a setup bug — surface the validator
# error, never coerce). A validation/finalize failure returns a structured GenerationResult (seed + phase +
# reason + compact diagnostics, NEVER a grid dump) — AC3.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const BossEncounterRequest = preload("res://scripts/generation/boss/boss_encounter_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")

# The fixed boss-arena footprint (a 12x12 walled arena — a confrontation room, not a corridor level). The
# even footprint mirrors the level pipeline's even-height convention. The interior (1..width-2, 1..height-2)
# is FLOOR; the border is WALL.
const ARENA_WIDTH := 12
const ARENA_HEIGHT := 12

# The board snapshot's starting sequence id (mirrors the level pipeline's INITIAL_SEQUENCE_ID / a fresh
# board's next_sequence_id == 1; try_from_snapshot rejects <= 0).
const INITIAL_SEQUENCE_ID := 1

# The stable finale-constraint markers the arena carries (AC2 "any finale constraints"). They are DATA-only
# descriptors a later live boss loop (9.3/9.4) reads — they gate no domain state here. `is_terminal_encounter`
# records that the boss arena has NO forward exit (the run ENDS here on victory, 9.4 — never a route advance);
# `boss_required` records that defeating the boss is the MVP victory condition (FR31); `no_reward_placement`
# records that a boss arena places NO generic rewards (the boss is the objective, not a loot node).
const FINALE_CONSTRAINTS := {
	"is_terminal_encounter": true,
	"boss_required": true,
	"no_reward_placement": true
}


# Build the deterministic boss ARENA level snapshot from a validated BossEncounterRequest. Returns a
# GenerationResult: ok(payload) on success (the payload is the pure serializable arena snapshot), or
# error(phase, code, reason, seed, diagnostics) on an invalid request / a board-snapshot validation failure
# (AC3 — structured, no grid dump). Draws ZERO RNG.
func build(request: BossEncounterRequest) -> GenerationResult:
	# (1) The request must validate before we build anything (AC3 — a bad request is a structured error, not a
	# built-then-rejected arena). Surface the request's field error verbatim under the VALIDATION phase.
	if request == null:
		return GenerationResult.error(
			GenerationResult.PHASE_VALIDATION,
			&"invalid_boss_encounter_request",
			&"null_request",
			"",
			{"reason": "null_request"}
		)
	var request_validation: ActionResult = request.validate()
	if request_validation.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_VALIDATION,
			&"invalid_boss_encounter_request",
			&"invalid_request_field",
			str(request.arena_seed()),
			{
				"node_id": String(request.node_id),
				"field": String(request_validation.metadata.get("field", ""))
			}
		)

	# (2) The fixed deterministic geometry: the ENTRANCE is bottom-center of the interior (the player enters
	# there); the player START cell IS the entrance (the run-loop places the hero at the entrance); the boss
	# SLOT is top-center of the interior (opposite the entrance — the arena confrontation geometry). All are
	# computed from the fixed footprint, so they are byte-identical for every seed.
	var entrance: Vector2i = _entrance_cell()
	var player_start: Vector2i = entrance
	var boss_slot_cell: Vector2i = _boss_slot_cell()

	# (3) Build the board snapshot (a WALL border + a FLOOR interior + the single ENTRANCE cell). The boss slot
	# is NOT stamped onto the board terrain (it stays FLOOR) and NO entity occupies it — the boss is an abstract
	# SLOT marker in the payload (9.2 attaches the real entity), so the board `entities` array is EMPTY.
	var board_snapshot: Dictionary = _build_board_snapshot(entrance)

	# (4) STRICT validate-then-reject through BoardState.try_from_snapshot (the Story 1.3 precedent). A failure
	# here is a builder defect — surface the validator error under the FINALIZE phase with compact diagnostics
	# (dimensions + the failing validator code + coords), NEVER a grid dump (AC3).
	var board_validation: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	if board_validation.is_error():
		var diagnostics: Dictionary = {
			"width": ARENA_WIDTH,
			"height": ARENA_HEIGHT,
			"validator_code": String(board_validation.error_code)
		}
		# Carry the validator's compact coord/count metadata (x/y/terrain/counts) WITHOUT dumping the grid.
		for key: String in ["x", "y", "terrain", "occupant_id", "expected_cell_count", "actual_cell_count"]:
			if board_validation.metadata.has(key):
				diagnostics[key] = board_validation.metadata.get(key)
		return GenerationResult.error(
			GenerationResult.PHASE_FINALIZE,
			&"invalid_boss_arena_snapshot",
			&"board_snapshot_rejected",
			str(request.arena_seed()),
			diagnostics
		)

	# (5) Assemble the PURE serializable payload (AC2). Everything is a plain dict/int/String surviving a JSON
	# round-trip. arena_seed is a full int64 -> DECIMAL-STRING encoded (the int64/JSON rule — a raw JSON number
	# truncates beyond 2^53). The boss_slot is the reserved boss-entity marker (9.2 fills the definition).
	var payload: Dictionary = {
		"arena_seed": str(request.arena_seed()),
		"boss_node_id": String(request.node_id),
		"board_snapshot": board_snapshot,
		"entrance": {"x": entrance.x, "y": entrance.y},
		"player_start": {"x": player_start.x, "y": player_start.y},
		"boss_slot": {
			"x": boss_slot_cell.x,
			"y": boss_slot_cell.y,
			"entity_id": String(request.boss_entity_id),
			# The definition id 9.2 attaches the real Larval Avatar definition under. Kept equal to the entity
			# id in v0 (one boss). is_placeholder marks that NO real boss definition/stats exist yet (9.2 fills
			# them) — the visible-exception-marker discipline (never silently ship a real-looking boss).
			"definition_id": String(request.boss_entity_id),
			"is_placeholder": true
		},
		"finale_constraints": FINALE_CONSTRAINTS.duplicate(true)
	}

	var setup_diagnostics: Dictionary = {
		"arena_width": ARENA_WIDTH,
		"arena_height": ARENA_HEIGHT,
		"boss_entity_id": String(request.boss_entity_id)
	}
	return GenerationResult.ok(payload, setup_diagnostics)


# The deterministic ENTRANCE cell: bottom-center of the FLOOR interior (the last interior row, centered).
static func _entrance_cell() -> Vector2i:
	return Vector2i(ARENA_WIDTH / 2, ARENA_HEIGHT - 2)


# The deterministic boss-SLOT cell: top-center of the FLOOR interior (the first interior row, centered) —
# opposite the entrance. Distinct from the entrance/player-start by construction (different row).
static func _boss_slot_cell() -> Vector2i:
	return Vector2i(ARENA_WIDTH / 2, 1)


# Build the board snapshot cell array: a WALL border (row/col 0 and the last), a FLOOR interior, and the
# single ENTRANCE cell. No occupants (the boss is a payload SLOT marker, not a board entity), so every cell's
# occupant_id is "" and the entities array is empty. Row-major order (the level-pipeline convention).
static func _build_board_snapshot(entrance: Vector2i) -> Dictionary:
	var cells: Array[Dictionary] = []
	for y: int in range(ARENA_HEIGHT):
		for x: int in range(ARENA_WIDTH):
			var terrain: int = BoardCell.Terrain.FLOOR
			var is_border: bool = x == 0 or y == 0 or x == ARENA_WIDTH - 1 or y == ARENA_HEIGHT - 1
			if is_border:
				terrain = BoardCell.Terrain.WALL
			if x == entrance.x and y == entrance.y:
				terrain = BoardCell.Terrain.ENTRANCE
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": terrain,
				"occupant_id": "",
				"explored": false,
				"visible": false
			})

	return {
		"width": ARENA_WIDTH,
		"height": ARENA_HEIGHT,
		"next_sequence_id": INITIAL_SEQUENCE_ID,
		"cells": cells,
		"entities": []
	}
