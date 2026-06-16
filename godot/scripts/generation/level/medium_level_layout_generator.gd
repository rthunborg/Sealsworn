class_name MediumLevelLayoutGenerator
extends RefCounted

# Deterministic Medium (~14x12) tactical layout phase + AC2 readability validation (Epic 3,
# Story 3.3).
#
# SIBLING of SmallLevelLayoutGenerator: same fixed-draw-order discipline, same
# generate_layout / build_board_snapshot / fingerprint method surface, same border-ring +
# open-interior shape, same pure-serializable payload. The TWO deltas from the Small generator are:
#   (1) the wall_density decision (Task 3.3.4) — see "WALL_DENSITY DECISION" below; and
#   (2) the AC2 readability validation pass (Task 3.3.3) — see validate_readability().
#
# Turns a validated GenerationRequest + a resolved Medium LevelRecipeDefinition + an RngStreamSet
# into a deterministic, scene-free layout description (board dimensions, per-cell terrain, the
# entrance cell, the exit cell, and the interior blocker cells) and converts that into a board
# snapshot in the EXACT BoardState.to_snapshot() shape — validated through the STRICT
# BoardState.try_from_snapshot() / TacticalSnapshot path (validate-then-reject, never coerce; the
# Story 1.3 board-snapshot precedent set by 3.2).
#
# DATA-LAYER ONLY: this is a RefCounted service, NOT a Node. It produces pure serializable data
# (no BoardState/RefCounted/scene refs in the emitted layout/payload) so the result survives a real
# JSON.stringify/parse_string round-trip.
#
# AC1 DETERMINISM CONTRACT — the single most important rule (identical to 3.2):
#   A Medium layout is a pure deterministic function of (root seed, recipe, starting `level`-stream
#   state). EVERY layout-affecting random choice is drawn through GenerationRequest.draw_layout_int
#   / draw_layout_float, which route EXCLUSIVELY through RngStreamSet.STREAM_LEVEL. This generator
#   NEVER calls randi()/randf(), NEVER constructs a RandomNumberGenerator, and NEVER touches another
#   stream. The draw ORDER is fixed and documented below (FIXED DRAW ORDER). Reordering draws or
#   inserting an unrelated draw between two layout draws silently changes every approved fixture, so
#   the seed-regression test is the tripwire.
#
# FIXED DRAW ORDER (do not reorder — pinned fixtures depend on it):
#   1. blocker_count   : one draw_layout_int over [budget_min .. budget_max] (clamped to the
#                        available interior-floor candidate count). Drawn even when the band collapses
#                        to a single value, so the stream advances identically across recipes.
#   2. blocker_position: blocker_count draws, each a draw_layout_int over the *current* candidate
#                        list index (rejection-free shrinking pool). Each picked cell is removed from
#                        the candidate pool before the next draw so positions never collide.
#   3. wrinkle_kind    : (Story 3.4) min_tactical_wrinkles draws selecting a wrinkle kind from the
#                        recipe allowlist filtered to the v0-realizable subset (see
#                        TacticalWrinklePlacer). APPENDED after the blocker draws so existing blocker
#                        behaviour is preserved.
#   4. wrinkle_position: (Story 3.4) one draw per required wrinkle over the *remaining* candidate pool
#                        (the blocker pool after blockers were removed), so a wrinkle cell never
#                        collides with a blocker or another wrinkle cell.
#   5..9. enemy/reward  : (Story 3.5) enemy count -> enemy positions -> enemy kinds -> reward count ->
#                        reward positions, APPENDED after the wrinkle draws via the shared
#                        EntityRewardPlacer (the same placer the Small generator uses). Drawn from the
#                        residual candidate pool (the wrinkle pool after wrinkle cells are removed), so
#                        enemies/rewards never collide with a blocker, wrinkle, entrance, exit, corridor,
#                        or each other. ENEMIES become board entities; REWARDS become payload markers.
#                        Enemies/rewards do NOT change terrain, so the seed-regression terrain
#                        fingerprints stay stable (no re-pin).
# This is byte-identical to the Small generator's draw discipline; the two generators are siblings.
#
# WALL_DENSITY DECISION (Task 3.3.4 — carries the 3.2 deferred-work item; the deliberate, documented
# choice required by this story):
#   wall_density is INTENTIONALLY UNUSED for blocker-count derivation in v0, for BOTH the Small and
#   Medium generators. The blocker_budget_min..max band is the AUTHORITATIVE, recipe-driven bound on
#   how many interior blocker/wall cells are placed. Rationale: medium_combat_basic carries
#   wall_density = 0.28; the interior of a 14x12 board is (14-2)*(12-2) = 120 cells, so a density
#   target of round(0.28 * 120) ≈ 34 vastly exceeds the budget band max (8) and would clamp to a
#   CONSTANT 8 blockers for every seed — collapsing the seed-to-seed blocker-COUNT variety that AC1
#   ("meaningfully different layouts") relies on. Honoring density would therefore REDUCE divergence
#   while adding no readability value the band does not already give. Instead, AC2's "excessive
#   blockage" check (validate_readability) is the readability backstop that enforces the openness
#   bound — it is the AC2 readability bound, NOT wall_density, that guards "enough open space for
#   movement." This keeps Medium a true sibling of Small (identical draw semantics, no Small
#   re-pin). If a future story wants density-driven counts, it must widen the band or change the
#   readability model and re-pin the fingerprints deliberately.
#
# SCOPE (Stories 3.3 + 3.4): floor + wall(blocker) + entrance + exit on a Medium board, the three
# AC2 readability checks (excessive blockage / unreachable exit / unreadable first reveal), PLUS
# deterministic tactical-wrinkle placement (Story 3.4): choke_point / flank_route / blocker_cluster
# realized as interior WALL structure and hazard realized as HAZARD terrain (medium_combat_basic's
# realizable allowed kinds; reward_behind_danger is NOT realized — it needs a reward entity, Story 3.5).
# Medium is the FIRST generator to emit BoardCell.Terrain.HAZARD. Wrinkle WALL cells route through the
# SAME corridor-respecting candidate pool as blockers, and their count stays far below the AC2
# excessive-blockage bound. NO enemies/rewards (3.5 — entities[] stays EMPTY), NO full
# reachability/no-soft-lock/legal-placement validator + retry (3.6 — only the three AC2 checks below),
# NO manual-seed/batch CLI (3.7). difficulty_band is NOT a layout input and NOT an AC2-bound input
# (hard non-goal).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalWrinklePlacer = preload("res://scripts/generation/level/tactical_wrinkle_placer.gd")
const EntityRewardPlacer = preload("res://scripts/generation/level/entity_reward_placer.gd")

# Medium v0 dimensions. The recipe size class is the source of size; a fixed 14x12 is acceptable for
# Medium v0 (story 3.3.2). The size is NOT jittered this story: a fixed footprint keeps the entrance
# and exit positions stable and the reserved-corridor construction guarantee trivially valid (height
# 12 is even, so corridor_row = 6 is strictly interior). A future story may derive a jittered Medium
# size from a `level`-stream draw if it wants variety — but it MUST keep corridor_row strictly
# interior and re-pin the fingerprints.
const MEDIUM_WIDTH: int = 14
const MEDIUM_HEIGHT: int = 12

# The board's first valid sequence id (BoardState.try_from_snapshot requires next_sequence_id > 0).
const INITIAL_SEQUENCE_ID: int = 1

# AC2 READABILITY BOUNDS (Task 3.3.3). These are READABILITY constants derived from "Medium is
# larger but must stay fair + readable" — NOT difficulty tiers (hard non-goal). They are the
# backstop AC2 enforces by rejection; the recipe blocker_budget_max should normally keep candidates
# well inside them.
#
# (a) Excessive blockage: reject if the fraction of INTERIOR cells (border ring excluded) that are
#     WALL exceeds this bound. The baseline band (max 8) over a 120-cell interior is ~0.067, far
#     below 0.35, so approved seeds pass by construction; a deliberately over-walled candidate is
#     rejected.
const MAX_INTERIOR_WALL_RATIO: float = 0.35
# (b) Unreachable exit: a pure 4-neighbour flood fill over non-WALL cells (see _flood_reachable).
# (c) Unreadable first reveal: the baseline line-of-sight radius is 4 tiles (FR5). We approximate the
#     "first reveal" as the count of non-WALL cells reachable from the entrance within Chebyshev
#     distance FIRST_REVEAL_RADIUS via a bounded flood (deterministic, scene-free). A "you spawn
#     boxed in" candidate yields too few and is rejected.
const FIRST_REVEAL_RADIUS: int = 4
const MIN_FIRST_REVEAL_CELLS: int = 8

# Fixed 4-neighbour offsets, iterated in this order for deterministic flood fills.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]


# Generate the deterministic Medium layout and return it as a structured ActionResult.
# On success: ActionResult.ok([], {"layout": <layout dict>}) where the layout dict is pure
# serializable data (see _build_layout). On failure: a structured ActionResult.error with a stable
# lower-snake code (the caller maps it onto a GenerationResult.error against PHASE_LAYOUT).
func generate_layout(request: GenerationRequest, recipe: LevelRecipeDefinition, streams: RngStreamSet, enemy_repository: EnemyRepository) -> ActionResult:
	if request == null:
		return ActionResult.error(&"invalid_layout_request", {"reason": "missing_request"})
	if recipe == null:
		return ActionResult.error(&"invalid_layout_recipe", {"reason": "missing_recipe"})
	if streams == null:
		return ActionResult.error(&"invalid_layout_streams", {"reason": "missing_streams"})
	if recipe.size_class != LevelRecipeDefinition.SIZE_MEDIUM:
		return ActionResult.error(&"unsupported_size_class_for_layout", {
			"size_class": String(recipe.size_class),
			"supported": String(LevelRecipeDefinition.SIZE_MEDIUM)
		})

	var width: int = MEDIUM_WIDTH
	var height: int = MEDIUM_HEIGHT

	# Entrance / exit are deterministic (NOT seed-randomized) interior cells on opposite interior
	# edges, both on the central row. CONSTRUCTION GUARANTEE (Story 3.6 owns the formal replacement):
	# keeping entrance/exit fixed + reserving the central row as a blocker-free corridor GUARANTEES
	# the entrance can reach the exit through floor cells regardless of blocker draws, so approved
	# seeds pass the AC2 reachability check by construction. Seed-to-seed divergence comes from the
	# interior blocker layout (AC1 second half). The AC2 reachability check (validate_readability) is
	# still implemented and tested — it is an AC, not optional — and is what would reject a malformed
	# (e.g. exit-walled) candidate fed straight into the validator.
	var corridor_row: int = height / 2
	var entrance: Vector2i = Vector2i(1, corridor_row)
	var exit_cell: Vector2i = Vector2i(width - 2, corridor_row)

	# Interior-floor candidate cells eligible to become a blocker: strictly inside the border ring,
	# excluding entrance, exit, and the entire central corridor row. Built in a FIXED row-major order
	# so the blocker-position draws are reproducible.
	var blocker_candidates: Array[Vector2i] = _blocker_candidate_cells(width, height, corridor_row, entrance, exit_cell)

	# FIXED DRAW #1: blocker count.
	var blocker_count_result: ActionResult = _draw_blocker_count(request, recipe, streams, blocker_candidates.size())
	if blocker_count_result.is_error():
		return blocker_count_result
	var blocker_count: int = int(blocker_count_result.metadata.get("blocker_count"))

	# FIXED DRAW #2..: blocker positions (shrinking-pool selection; no collisions, no rejection loop).
	var blockers_result: ActionResult = _draw_blocker_cells(request, streams, blocker_candidates, blocker_count)
	if blockers_result.is_error():
		return blockers_result
	var blocker_cells: Array[Vector2i] = blockers_result.metadata.get("blocker_cells")
	# The candidate pool AFTER the blockers were removed — wrinkle cells draw from this remaining pool
	# so a wrinkle never collides with a blocker (and the corridor/entrance/exit are already excluded).
	var remaining_pool: Array[Vector2i] = blockers_result.metadata.get("remaining_pool")

	# FIXED DRAW #3..#4: tactical-wrinkle placement (Story 3.4). Appended after the blocker draws via
	# the shared TacticalWrinklePlacer so both generators stay siblings. For medium_combat_basic this
	# places min_tactical_wrinkles (2) wrinkles from {choke_point, flank_route, blocker_cluster, hazard}
	# — WALL structure and/or HAZARD terrain. reward_behind_danger is excluded (Story 3.5).
	var wrinkles_result: ActionResult = TacticalWrinklePlacer.place_wrinkles(
		request, streams, recipe, remaining_pool, "medium_layout"
	)
	if wrinkles_result.is_error():
		return wrinkles_result
	# Untyped Array (not Array[Dictionary]): metadata is deep-copied through ActionResult.ok, which
	# returns a plain Array; re-narrowing to Array[Dictionary] would fail the strict assignment. Each
	# element is still a Dictionary (the placer guarantees that) and is iterated as one in _build_layout.
	var wrinkles: Array = wrinkles_result.metadata.get("wrinkles")

	# Build the terrain layout from blockers + wrinkles BEFORE placement so the reward behind-danger
	# check + reachability validation read the final terrain grid (incl. any HAZARD wrinkle). Enemies +
	# rewards do NOT change terrain, so building first keeps the fingerprint (terrain-only) stable.
	var layout: Dictionary = _build_layout(width, height, entrance, exit_cell, blocker_cells, wrinkles)

	# The candidate pool the placement step draws from: the wrinkle pool (= blocker pool after blockers)
	# with the placed wrinkle cells removed. Recomputed here (TacticalWrinklePlacer returns only its
	# wrinkles, not its residual pool) so enemies/rewards never collide with a blocker or wrinkle.
	var placement_pool: Array[Vector2i] = _remaining_after_wrinkles(remaining_pool, wrinkles)

	# FIXED PLACEMENT DRAW #5..#9: enemy + reward placement (Story 3.5). Appended after the wrinkle draws
	# via the shared EntityRewardPlacer so both generators stay siblings. Enemies are resolved through
	# the repository boundary (AC3) and emitted as board entities; rewards are payload markers.
	var placement_result: ActionResult = _place_entities_and_rewards(request, streams, recipe, enemy_repository, placement_pool, layout)
	if placement_result.is_error():
		return placement_result
	# Untyped Array per the Story 3.4 deep-copy trap (Array[Dictionary] does not survive ActionResult
	# metadata deep-copy; it returns a plain Array and crashes a strict re-typed receiver).
	var enemies: Array = placement_result.metadata.get("enemies")
	var rewards: Array = placement_result.metadata.get("rewards")
	var optional_reward_count: int = int(placement_result.metadata.get("optional_reward_count"))
	layout["enemies"] = enemies
	layout["rewards"] = rewards
	layout["optional_reward_count"] = optional_reward_count

	return ActionResult.ok([], {"layout": layout})


# AC2 READABILITY VALIDATION (Task 3.3.3) — the NEW requirement that separates 3.3 from 3.2.
# A generated (or hand-built) Medium candidate is checked against THREE named readability constraints
# and the FIRST failing check returns a structured ActionResult.error carrying COMPACT diagnostics
# (counts / ratios / coordinates — never a full grid dump). The caller (LevelGenerator) maps the
# error onto a GenerationResult.error against PHASE_VALIDATION. On success returns ActionResult.ok.
#
# This is a PURE query over the layout's terrain grid: it draws NO RNG and mutates nothing. WALL
# (= BoardCell.terrain_blocks_occupancy()) is the only "blocked / not walkable" predicate, so the
# generator's notion of walkable matches the board model exactly.
#
# SCOPE GUARD: exactly the three AC2-named checks (excessive blockage / unreachable exit / unreadable
# first reveal). NO legal-enemy-placement (no entities until 3.5), NO reachable-reward (no rewards
# until 3.5), NO general no-soft-lock / no-required-gate validator, NO bounded-retry engine — Story
# 3.6 owns the comprehensive validator + retry and will likely REPLACE this focused pass.
func validate_readability(layout: Dictionary) -> ActionResult:
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var terrain_grid: Array = layout.get("terrain", [])
	var entrance: Vector2i = _cell_from_dict(layout.get("entrance", {}))
	var exit_cell: Vector2i = _cell_from_dict(layout.get("exit", {}))

	if width <= 0 or height <= 0 or terrain_grid.size() != height:
		return ActionResult.error(&"invalid_layout_shape", {
			"width": width,
			"height": height,
			"terrain_rows": terrain_grid.size()
		})
	# Per-row width guard (closes the 3.3-deferred Low symmetric to build_board_snapshot): a hand-built
	# candidate with the right row COUNT but a short row would otherwise index out of bounds in the
	# interior-wall / flood / first-reveal scans. Reject it with the same structured code instead.
	for y: int in range(height):
		var shape_row: Array = terrain_grid[y]
		if shape_row.size() != width:
			return ActionResult.error(&"invalid_layout_shape", {
				"width": width,
				"height": height,
				"row_index": y,
				"row_width": shape_row.size()
			})

	# (a) EXCESSIVE BLOCKAGE: interior WALL ratio (border ring excluded) must stay within the bound.
	var interior_cell_count: int = max(0, (width - 2) * (height - 2))
	var interior_wall_count: int = _interior_wall_count(width, height, terrain_grid)
	if interior_cell_count > 0:
		var wall_ratio: float = float(interior_wall_count) / float(interior_cell_count)
		if wall_ratio > MAX_INTERIOR_WALL_RATIO:
			return ActionResult.error(&"excessive_blockage", {
				"reason": "interior_wall_ratio_exceeds_bound",
				"interior_wall_count": interior_wall_count,
				"interior_cell_count": interior_cell_count,
				"wall_ratio": wall_ratio,
				"max_wall_ratio": MAX_INTERIOR_WALL_RATIO
			})

	# (b) UNREACHABLE EXIT: 4-neighbour flood fill from the entrance over non-WALL cells must reach
	# the exit. Pure query (no RNG, no mutation). 4-neighbour matches the tactical movement model.
	var reachable: Dictionary = _flood_reachable(width, height, terrain_grid, entrance)
	if not reachable.has(exit_cell):
		return ActionResult.error(&"unreachable_exit", {
			"reason": "exit_not_reachable_from_entrance",
			"entrance": {"x": entrance.x, "y": entrance.y},
			"exit": {"x": exit_cell.x, "y": exit_cell.y},
			"reachable_cell_count": reachable.size()
		})

	# (c) UNREADABLE FIRST REVEAL: the entrance must be able to orient — the count of non-WALL cells
	# reachable within Chebyshev radius FIRST_REVEAL_RADIUS (baseline LoS radius, FR5) of the entrance
	# must meet a readable minimum. A "spawn boxed in" candidate yields too few and is rejected.
	var first_reveal_count: int = _first_reveal_cell_count(width, height, terrain_grid, entrance)
	if first_reveal_count < MIN_FIRST_REVEAL_CELLS:
		return ActionResult.error(&"unreadable_first_reveal", {
			"reason": "first_reveal_below_minimum",
			"entrance": {"x": entrance.x, "y": entrance.y},
			"first_reveal_count": first_reveal_count,
			"min_first_reveal_cells": MIN_FIRST_REVEAL_CELLS,
			"radius": FIRST_REVEAL_RADIUS
		})

	return ActionResult.ok([], {
		"interior_wall_count": interior_wall_count,
		"interior_cell_count": interior_cell_count,
		"reachable_cell_count": reachable.size(),
		"first_reveal_count": first_reveal_count
	})


# Convert a layout dict (from generate_layout) into a board snapshot in the EXACT
# BoardState.to_snapshot() shape and VALIDATE it through the strict BoardState.try_from_snapshot().
# Returns ActionResult.ok([], {"board_snapshot": <dict>, "board": <BoardState>}) on success, or the
# validator's structured error verbatim on failure (a malformed cell is a generator bug, never
# coerced). The returned board_snapshot is pure serializable data; the BoardState is for in-process
# assertions only and must NOT be placed in the serializable payload.
func build_board_snapshot(layout: Dictionary) -> ActionResult:
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var terrain_grid: Array = layout.get("terrain", [])

	# Leading shape guard (closes the 3.2-deferred Low for this generator): a hand-built/malformed
	# layout whose declared width/height disagree with the terrain grid is rejected with a structured
	# error rather than indexing out of bounds and crashing.
	if width <= 0 or height <= 0 or terrain_grid.size() != height:
		return ActionResult.error(&"invalid_layout_shape", {
			"width": width,
			"height": height,
			"terrain_rows": terrain_grid.size()
		})

	# Story 3.5: the placed enemies (board entities) ride the snapshot's entities array. BoardState's
	# OCCUPANT INVARIANT (matching to_snapshot()): a blocking entity's CELL must declare the matching
	# occupant_id AND the entity must appear in the entities array; try_from_snapshot records the cell
	# occupant, strips the cell to "", and cross-checks it against the blocking entities (a missing or
	# mismatched cell occupant is REJECTED). So we set occupant_id on each blocking enemy's cell here.
	var entities: Array = layout.get("enemies", [])
	var occupant_by_cell: Dictionary = {}
	for entity_value: Variant in entities:
		var entity: Dictionary = entity_value
		if bool(entity.get("blocks_movement", true)):
			var entity_position: Dictionary = entity.get("position")
			occupant_by_cell[Vector2i(int(entity_position.get("x")), int(entity_position.get("y")))] = String(entity.get("entity_id"))

	var cells: Array[Dictionary] = []
	for y: int in range(height):
		var row: Array = terrain_grid[y]
		if row.size() != width:
			return ActionResult.error(&"invalid_layout_shape", {
				"width": width,
				"height": height,
				"row_index": y,
				"row_width": row.size()
			})
		for x: int in range(width):
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": int(row[x]),
				"occupant_id": occupant_by_cell.get(Vector2i(x, y), ""),
				"explored": false,
				"visible": false
			})

	var board_snapshot: Dictionary = {
		"width": width,
		"height": height,
		"next_sequence_id": INITIAL_SEQUENCE_ID,
		"cells": cells,
		"entities": entities.duplicate(true)
	}

	# VALIDATE-then-reject through the strict path (Story 1.3 precedent). A failure here is a
	# generator defect; surface the validator error rather than silently fixing the snapshot.
	var validation: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	if validation.is_error():
		return validation
	var board: BoardState = validation.metadata.get("board") as BoardState
	return ActionResult.ok([], {"board_snapshot": board_snapshot, "board": board})


# Stable fingerprint of a layout: a deterministic string over dimensions + entrance + exit +
# row-major terrain grid. IDENTICAL format to SmallLevelLayoutGenerator.fingerprint so the two
# generators share a fingerprint vocabulary. Two byte-identical layouts share a fingerprint; any
# drift (terrain, entrance, exit, or dimensions) changes it. Used by the seed-regression test as the
# pinned-per-seed value.
static func fingerprint(layout: Dictionary) -> String:
	var width: int = int(layout.get("width", 0))
	var height: int = int(layout.get("height", 0))
	var terrain_grid: Array = layout.get("terrain", [])
	var entrance: Dictionary = layout.get("entrance", {})
	var exit_cell: Dictionary = layout.get("exit", {})

	var grid_parts: PackedStringArray = PackedStringArray()
	for y: int in range(height):
		var row: Array = terrain_grid[y]
		var row_parts: PackedStringArray = PackedStringArray()
		for x: int in range(width):
			row_parts.append(str(int(row[x])))
		grid_parts.append("".join(row_parts))

	return "%dx%d|e%d,%d|x%d,%d|%s" % [
		width,
		height,
		int(entrance.get("x", -1)),
		int(entrance.get("y", -1)),
		int(exit_cell.get("x", -1)),
		int(exit_cell.get("y", -1)),
		"/".join(grid_parts)
	]


func _blocker_candidate_cells(width: int, height: int, corridor_row: int, entrance: Vector2i, exit_cell: Vector2i) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for y: int in range(1, height - 1):
		if y == corridor_row:
			# Reserve the central corridor row as blocker-free (construction guarantee — see above).
			continue
		for x: int in range(1, width - 1):
			var cell: Vector2i = Vector2i(x, y)
			if cell == entrance or cell == exit_cell:
				continue
			candidates.append(cell)
	return candidates


func _draw_blocker_count(request: GenerationRequest, recipe: LevelRecipeDefinition, streams: RngStreamSet, candidate_count: int) -> ActionResult:
	# A recipe with allow_blockers == false (or a zero budget) places NO interior blockers, and the
	# count draw is skipped so the stream is not advanced for a no-blocker recipe.
	# wall_density is intentionally NOT read here (see WALL_DENSITY DECISION in the file header): the
	# budget band is the authoritative count bound for both the Small and Medium generators.
	if not recipe.allow_blockers or recipe.blocker_budget_max <= 0 or candidate_count <= 0:
		return ActionResult.ok([], {"blocker_count": 0})

	var minimum: int = max(0, recipe.blocker_budget_min)
	var maximum: int = recipe.blocker_budget_max
	# Never request more blockers than there are eligible interior cells (the corridor row + the
	# entrance/exit are already excluded from candidate_count).
	maximum = min(maximum, candidate_count)
	minimum = min(minimum, maximum)

	var draw: ActionResult = request.draw_layout_int(streams, minimum, maximum, {
		"consumer": "medium_layout_blocker_count"
	})
	if draw.is_error():
		return draw
	return ActionResult.ok([], {"blocker_count": int(draw.metadata.get("value"))})


func _draw_blocker_cells(request: GenerationRequest, streams: RngStreamSet, candidates: Array[Vector2i], blocker_count: int) -> ActionResult:
	var pool: Array[Vector2i] = candidates.duplicate()
	var chosen: Array[Vector2i] = []
	for selection_index: int in range(blocker_count):
		if pool.is_empty():
			break
		var draw: ActionResult = request.draw_layout_int(streams, 0, pool.size() - 1, {
			"consumer": "medium_layout_blocker_position",
			"selection_index": selection_index
		})
		if draw.is_error():
			return draw
		var picked_index: int = int(draw.metadata.get("value"))
		chosen.append(pool[picked_index])
		pool.remove_at(picked_index)
	# Return the remaining pool so the wrinkle placer can draw from the SAME shrinking candidate set
	# (corridor/entrance/exit already excluded), guaranteeing wrinkles never overlap blockers.
	return ActionResult.ok([], {"blocker_cells": chosen, "remaining_pool": pool})


# Recompute the candidate pool the enemy/reward placement step draws from: the wrinkle pool (= blocker
# pool after blockers were removed) minus the cells the wrinkles consumed. IDENTICAL to the Small
# generator's helper (the two generators are siblings). The wrinkle placer takes a copy and returns only
# its placed wrinkles, so the generator removes the wrinkle cells here. Order is preserved (row-major,
# blocker draws removed), so placement draws over a stable shrinking pool exactly like the blocker +
# wrinkle draws.
func _remaining_after_wrinkles(blocker_remaining_pool: Array[Vector2i], wrinkles: Array) -> Array[Vector2i]:
	var wrinkle_cells: Dictionary = {}
	for wrinkle: Dictionary in wrinkles:
		wrinkle_cells[wrinkle.get("cell")] = true
	var pool: Array[Vector2i] = []
	for cell: Vector2i in blocker_remaining_pool:
		if not wrinkle_cells.has(cell):
			pool.append(cell)
	return pool


# Place enemies + rewards via the shared EntityRewardPlacer (Story 3.5). IDENTICAL to the Small
# generator's helper except the consumer_prefix ("medium_layout"). Resolves the enemy definitions
# through the repository boundary (AC3 — a null/empty repository is a structured error, not a crash),
# draws enemies from the residual pool, then draws rewards from the pool the enemies left, then runs the
# focused AC2 reward-reachability validation. A Medium recipe allows behind-danger rewards, so a reward
# adjacent to a HAZARD wrinkle is flagged optional (not skipped).
func _place_entities_and_rewards(
	request: GenerationRequest,
	streams: RngStreamSet,
	recipe: LevelRecipeDefinition,
	enemy_repository: EnemyRepository,
	placement_pool: Array[Vector2i],
	layout: Dictionary
) -> ActionResult:
	var definitions: Array = []
	if recipe.enemy_budget_max > 0:
		var resolve_result: ActionResult = EntityRewardPlacer.resolve_placement_definitions(enemy_repository)
		if resolve_result.is_error():
			return resolve_result
		definitions = resolve_result.metadata.get("definitions")

	var enemies_result: ActionResult = EntityRewardPlacer.place_enemies(
		request, streams, recipe, definitions, placement_pool, "medium_layout"
	)
	if enemies_result.is_error():
		return enemies_result
	var enemies: Array = enemies_result.metadata.get("enemies")
	var reward_pool: Array[Vector2i] = enemies_result.metadata.get("remaining_pool")

	var rewards_result: ActionResult = EntityRewardPlacer.place_rewards(
		request, streams, recipe, reward_pool, layout.get("terrain", []), "medium_layout"
	)
	if rewards_result.is_error():
		return rewards_result
	var rewards: Array = rewards_result.metadata.get("rewards")
	var optional_reward_count: int = int(rewards_result.metadata.get("optional_count"))

	# AC2: every placed reward must be reachable from the entrance. A failure surfaces a structured error
	# the caller maps onto PHASE_VALIDATION (carrying the validator's compact diagnostics).
	var reachability: ActionResult = EntityRewardPlacer.validate_reward_reachability(layout, rewards)
	if reachability.is_error():
		return reachability

	return ActionResult.ok([], {
		"enemies": enemies,
		"rewards": rewards,
		"optional_reward_count": optional_reward_count
	})


func _build_layout(width: int, height: int, entrance: Vector2i, exit_cell: Vector2i, blocker_cells: Array[Vector2i], wrinkles: Array) -> Dictionary:
	var blocker_lookup: Dictionary = {}
	for cell: Vector2i in blocker_cells:
		blocker_lookup[cell] = true

	# Wrinkle terrain overlay (Story 3.4): cell -> terrain value. Wrinkle cells come from the
	# blocker-free remaining pool (corridor/entrance/exit already excluded), so they never overwrite
	# the entrance/exit/blockers/corridor. WALL-structure wrinkles add interior WALL; a hazard wrinkle
	# adds HAZARD terrain (walkable + sight-transparent), the first HAZARD this codebase emits.
	var wrinkle_terrain: Dictionary = {}
	for wrinkle: Dictionary in wrinkles:
		wrinkle_terrain[wrinkle.get("cell")] = int(wrinkle.get("terrain"))

	# Row-major terrain grid. Border ring = WALL; interior = FLOOR except entrance/exit/blockers and
	# wrinkle cells. Interior blockers are WALL terrain (BoardCell treats WALL as both movement- and
	# LoS-blocking). Structural wrinkles are also WALL; a hazard wrinkle is HAZARD (walkable).
	var terrain_grid: Array = []
	for y: int in range(height):
		var row: Array = []
		for x: int in range(width):
			var cell: Vector2i = Vector2i(x, y)
			row.append(_terrain_for_cell(cell, width, height, entrance, exit_cell, blocker_lookup, wrinkle_terrain))
		terrain_grid.append(row)

	var blocker_list: Array = []
	# Emit blockers in a stable row-major order (NOT draw order) so the serialized payload is
	# canonical and diff-friendly; the layout itself is already fully determined by draw order.
	# Wrinkle cells are NOT blockers — they are tracked separately (see wrinkle_records) so the
	# blocker budget diagnostic stays meaningful.
	for y: int in range(height):
		for x: int in range(width):
			var cell: Vector2i = Vector2i(x, y)
			if blocker_lookup.has(cell):
				blocker_list.append({"x": x, "y": y})

	# Compact wrinkle record (in placement / draw order): kind + cell. AC1 requires the placed wrinkle
	# KINDS to be recorded in diagnostics; the layout carries the record and the LevelGenerator lifts
	# the kinds + count into the success diagnostics.
	var wrinkle_records: Array = []
	var wrinkle_kinds: Array = []
	for wrinkle: Dictionary in wrinkles:
		var cell: Vector2i = wrinkle.get("cell")
		wrinkle_records.append({"kind": String(wrinkle.get("kind")), "x": cell.x, "y": cell.y})
		wrinkle_kinds.append(String(wrinkle.get("kind")))

	return {
		"width": width,
		"height": height,
		"entrance": {"x": entrance.x, "y": entrance.y},
		"exit": {"x": exit_cell.x, "y": exit_cell.y},
		"blockers": blocker_list,
		"wrinkles": wrinkle_records,
		"wrinkle_kinds": wrinkle_kinds,
		"terrain": terrain_grid
	}


func _terrain_for_cell(cell: Vector2i, width: int, height: int, entrance: Vector2i, exit_cell: Vector2i, blocker_lookup: Dictionary, wrinkle_terrain: Dictionary) -> int:
	if cell == entrance:
		return BoardCell.Terrain.ENTRANCE
	if cell == exit_cell:
		return BoardCell.Terrain.EXIT
	if cell.x == 0 or cell.y == 0 or cell.x == width - 1 or cell.y == height - 1:
		return BoardCell.Terrain.WALL
	if blocker_lookup.has(cell):
		return BoardCell.Terrain.WALL
	if wrinkle_terrain.has(cell):
		return int(wrinkle_terrain[cell])
	return BoardCell.Terrain.FLOOR


# Count interior (border-ring-excluded) cells whose terrain is WALL. Used by the excessive-blockage
# check. Border cells are always WALL by construction and are NOT readability blockers, so they are
# excluded from the interior ratio.
func _interior_wall_count(width: int, height: int, terrain_grid: Array) -> int:
	var count: int = 0
	for y: int in range(1, height - 1):
		var row: Array = terrain_grid[y]
		for x: int in range(1, width - 1):
			if int(row[x]) == BoardCell.Terrain.WALL:
				count += 1
	return count


# Deterministic 4-neighbour flood fill from `origin` over non-WALL cells. Returns a Dictionary used
# as a visited set (Vector2i -> true). Pure query: no RNG, no mutation. Neighbours are visited in the
# fixed NEIGHBOUR_OFFSETS order. If the origin itself is a WALL or out of bounds, the result is empty.
func _flood_reachable(width: int, height: int, terrain_grid: Array, origin: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	if not _in_bounds(width, height, origin) or _is_wall(terrain_grid, origin):
		return visited

	var frontier: Array[Vector2i] = [origin]
	visited[origin] = true
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for offset: Vector2i in NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = current + offset
			if not _in_bounds(width, height, neighbour):
				continue
			if visited.has(neighbour):
				continue
			if _is_wall(terrain_grid, neighbour):
				continue
			visited[neighbour] = true
			frontier.append(neighbour)
	return visited


# Count non-WALL cells reachable from `origin` within Chebyshev distance FIRST_REVEAL_RADIUS via a
# bounded 4-neighbour flood. Approximates the "first reveal" (baseline LoS radius, FR5) without a
# scene/LoS service: a boxed-in entrance yields a tiny count. Pure query; deterministic.
func _first_reveal_cell_count(width: int, height: int, terrain_grid: Array, origin: Vector2i) -> int:
	if not _in_bounds(width, height, origin) or _is_wall(terrain_grid, origin):
		return 0

	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [origin]
	visited[origin] = true
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for offset: Vector2i in NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = current + offset
			if not _in_bounds(width, height, neighbour):
				continue
			if visited.has(neighbour):
				continue
			if _is_wall(terrain_grid, neighbour):
				continue
			if _chebyshev_distance(origin, neighbour) > FIRST_REVEAL_RADIUS:
				continue
			visited[neighbour] = true
			frontier.append(neighbour)
	return visited.size()


static func _chebyshev_distance(first: Vector2i, second: Vector2i) -> int:
	return max(absi(first.x - second.x), absi(first.y - second.y))


static func _in_bounds(width: int, height: int, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


static func _is_wall(terrain_grid: Array, cell: Vector2i) -> bool:
	var row: Array = terrain_grid[cell.y]
	return int(row[cell.x]) == BoardCell.Terrain.WALL


static func _cell_from_dict(data: Dictionary) -> Vector2i:
	return Vector2i(int(data.get("x", -1)), int(data.get("y", -1)))
