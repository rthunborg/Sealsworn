class_name SmallLevelLayoutGenerator
extends RefCounted

# Deterministic Small (~8x8) tactical layout phase (Epic 3, Story 3.2).
#
# Turns a validated GenerationRequest + a resolved Small LevelRecipeDefinition + an RngStreamSet
# into a deterministic, scene-free layout description (board dimensions, per-cell terrain, the
# entrance cell, the exit cell, and the interior blocker cells) and converts that into a board
# snapshot in the EXACT BoardState.to_snapshot() shape — which is then validated through the
# STRICT BoardState.try_from_snapshot() / TacticalSnapshot path (validate-then-reject, never
# coerce; the Story 1.3 board-snapshot precedent).
#
# DATA-LAYER ONLY: this is a RefCounted service, NOT a Node. It produces pure serializable data
# (no BoardState/RefCounted/scene refs in the emitted payload) so the result survives a real
# JSON.stringify/parse_string round-trip.
#
# AC1 DETERMINISM CONTRACT — the single most important rule:
#   A Small layout is a pure deterministic function of (root seed, recipe, starting `level`-stream
#   state). EVERY layout-affecting random choice is drawn through GenerationRequest.draw_layout_int
#   / draw_layout_float, which route EXCLUSIVELY through RngStreamSet.STREAM_LEVEL. This generator
#   NEVER calls randi()/randf(), NEVER constructs a RandomNumberGenerator, and NEVER touches another
#   stream. The draw ORDER is fixed and documented below (FIXED DRAW ORDER). Reordering draws or
#   inserting an unrelated draw between two layout draws silently changes every approved fixture, so
#   the seed-regression test is the tripwire.
#
# FIXED DRAW ORDER (do not reorder — pinned fixtures depend on it):
#   1. blocker_count   : one draw_layout_int over [budget_min .. budget_max] (clamped to the
#                        available interior-floor cell count). Drawn even when the band collapses to
#                        a single value, so the stream advances identically across recipes.
#   2. blocker_position: blocker_count draws, each a draw_layout_int over the *current* candidate
#                        list index (rejection-free shrinking pool). Each picked cell is removed
#                        from the candidate pool before the next draw so positions never collide.
#   3. wrinkle_kind    : (Story 3.4) min_tactical_wrinkles draws selecting a wrinkle kind from the
#                        recipe allowlist filtered to the v0-realizable subset (see
#                        TacticalWrinklePlacer). APPENDED after the blocker draws so existing blocker
#                        behaviour is preserved.
#   4. wrinkle_position: (Story 3.4) one draw per required wrinkle over the *remaining* candidate pool
#                        (the blocker pool after blockers were removed), so a wrinkle cell never
#                        collides with a blocker or another wrinkle cell.
#
# SCOPE (Stories 3.2 + 3.4): floor + wall(blocker) + entrance + exit on a Small board, PLUS
# deterministic tactical-wrinkle placement (Story 3.4): choke_point / blocker_cluster realized as
# interior WALL structure (small_combat_basic's allowed kinds). NO Medium layouts (3.3), NO
# enemies/rewards (3.5 — entities[] stays EMPTY), NO formal reachability validator + retry (3.6 —
# only the minimal fairness guardrail below), NO manual-seed/batch CLI (3.7). hazard / flank_route are
# realizable kinds but are NOT in the Small recipe's allowlist, so Small never emits HAZARD this story.
# difficulty_band is NOT a layout input (hard non-goal).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalWrinklePlacer = preload("res://scripts/generation/level/tactical_wrinkle_placer.gd")

# Small v0 dimensions. The recipe size class is the source of size; a fixed 8x8 is acceptable for
# Small v0 (story 3.2.2). The size is NOT jittered this story: a fixed footprint keeps the entrance
# and exit positions stable and the fairness guardrail (clear central corridor) trivially valid.
# A future story may derive a jittered Small size from a `level`-stream draw if it wants variety.
const SMALL_WIDTH: int = 8
const SMALL_HEIGHT: int = 8

# The board's first valid sequence id (BoardState.try_from_snapshot requires next_sequence_id > 0).
const INITIAL_SEQUENCE_ID: int = 1


# Generate the deterministic Small layout and return it as a structured ActionResult.
# On success: ActionResult.ok([], {"layout": <layout dict>}) where the layout dict is pure
# serializable data (see _build_layout). On failure: a structured ActionResult.error with a stable
# lower-snake code (the caller maps it onto a GenerationResult.error against PHASE_LAYOUT).
func generate_layout(request: GenerationRequest, recipe: LevelRecipeDefinition, streams: RngStreamSet) -> ActionResult:
	if request == null:
		return ActionResult.error(&"invalid_layout_request", {"reason": "missing_request"})
	if recipe == null:
		return ActionResult.error(&"invalid_layout_recipe", {"reason": "missing_recipe"})
	if streams == null:
		return ActionResult.error(&"invalid_layout_streams", {"reason": "missing_streams"})
	if recipe.size_class != LevelRecipeDefinition.SIZE_SMALL:
		return ActionResult.error(&"unsupported_size_class_for_layout", {
			"size_class": String(recipe.size_class),
			"supported": String(LevelRecipeDefinition.SIZE_SMALL)
		})

	var width: int = SMALL_WIDTH
	var height: int = SMALL_HEIGHT

	# Entrance / exit are deterministic (not seed-randomized) interior cells on opposite interior
	# edges, both on the central row. SIMPLIFYING ASSUMPTION (for Story 3.6 to tighten): keeping
	# entrance/exit fixed + reserving the central row as a blocker-free corridor GUARANTEES the
	# entrance can reach the exit through floor cells regardless of blocker draws. Seed-to-seed
	# divergence comes from the interior blocker layout (AC1 second half), which is sufficient for
	# "meaningfully different layouts" while staying provably fair.
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
	# the shared TacticalWrinklePlacer so both generators stay siblings. For small_combat_basic this
	# places min_tactical_wrinkles (1) WALL-structure wrinkles (choke_point / blocker_cluster).
	var wrinkles_result: ActionResult = TacticalWrinklePlacer.place_wrinkles(
		request, streams, recipe, remaining_pool, "small_layout"
	)
	if wrinkles_result.is_error():
		return wrinkles_result
	# Untyped Array (not Array[Dictionary]): metadata is deep-copied through ActionResult.ok, which
	# returns a plain Array; re-narrowing to Array[Dictionary] would fail the strict assignment. Each
	# element is still a Dictionary (the placer guarantees that) and is iterated as one in _build_layout.
	var wrinkles: Array = wrinkles_result.metadata.get("wrinkles")

	var layout: Dictionary = _build_layout(width, height, entrance, exit_cell, blocker_cells, wrinkles)
	return ActionResult.ok([], {"layout": layout})


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

	var cells: Array[Dictionary] = []
	for y: int in range(height):
		var row: Array = terrain_grid[y]
		for x: int in range(width):
			cells.append({
				"position": {"x": x, "y": y},
				"terrain": int(row[x]),
				"occupant_id": "",
				"explored": false,
				"visible": false
			})

	var board_snapshot: Dictionary = {
		"width": width,
		"height": height,
		"next_sequence_id": INITIAL_SEQUENCE_ID,
		"cells": cells,
		"entities": []
	}

	# VALIDATE-then-reject through the strict path (Story 1.3 precedent). A failure here is a
	# generator defect; surface the validator error rather than silently fixing the snapshot.
	var validation: ActionResult = BoardState.try_from_snapshot(board_snapshot)
	if validation.is_error():
		return validation
	var board: BoardState = validation.metadata.get("board") as BoardState
	return ActionResult.ok([], {"board_snapshot": board_snapshot, "board": board})


# Stable fingerprint of a layout: a deterministic string over dimensions + row-major terrain grid +
# entrance + exit. Two byte-identical layouts share a fingerprint; any drift (terrain, entrance,
# exit, or dimensions) changes it. Used by the seed-regression test as the pinned-per-seed value.
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
			# Reserve the central corridor row as blocker-free (fairness guardrail — see above).
			continue
		for x: int in range(1, width - 1):
			var cell: Vector2i = Vector2i(x, y)
			if cell == entrance or cell == exit_cell:
				continue
			candidates.append(cell)
	return candidates


func _draw_blocker_count(request: GenerationRequest, recipe: LevelRecipeDefinition, streams: RngStreamSet, candidate_count: int) -> ActionResult:
	# WALL_DENSITY DECISION (Story 3.3.4, shared across both generators): recipe.wall_density is
	# INTENTIONALLY UNUSED for blocker-count derivation in v0. The blocker_budget_min..max band is the
	# authoritative count bound; honoring density would clamp to a constant count and collapse seed
	# divergence (see the WALL_DENSITY DECISION block in medium_level_layout_generator.gd). Small carries
	# no AC2 validator; Medium's AC2 excessive-blockage bound is the readability backstop.
	# A recipe with allow_blockers == false (or a zero budget) places NO interior blockers, and the
	# count draw is skipped so the stream is not advanced for a no-blocker recipe.
	if not recipe.allow_blockers or recipe.blocker_budget_max <= 0 or candidate_count <= 0:
		return ActionResult.ok([], {"blocker_count": 0})

	var minimum: int = max(0, recipe.blocker_budget_min)
	var maximum: int = recipe.blocker_budget_max
	# Never request more blockers than there are eligible interior cells (the corridor row + the
	# entrance/exit are already excluded from candidate_count).
	maximum = min(maximum, candidate_count)
	minimum = min(minimum, maximum)

	var draw: ActionResult = request.draw_layout_int(streams, minimum, maximum, {
		"consumer": "small_layout_blocker_count"
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
			"consumer": "small_layout_blocker_position",
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


func _build_layout(width: int, height: int, entrance: Vector2i, exit_cell: Vector2i, blocker_cells: Array[Vector2i], wrinkles: Array) -> Dictionary:
	var blocker_lookup: Dictionary = {}
	for cell: Vector2i in blocker_cells:
		blocker_lookup[cell] = true

	# Wrinkle terrain overlay (Story 3.4): cell -> terrain value. Wrinkle cells come from the
	# blocker-free remaining pool (corridor/entrance/exit already excluded), so they never overwrite
	# the entrance/exit/blockers/corridor. WALL-structure wrinkles add interior WALL; a hazard wrinkle
	# (not used by the Small recipe) would add HAZARD terrain.
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
