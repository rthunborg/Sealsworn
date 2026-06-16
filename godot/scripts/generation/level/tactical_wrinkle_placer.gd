class_name TacticalWrinklePlacer
extends RefCounted

# Deterministic tactical-wrinkle placement shared by BOTH layout generators (Epic 3, Story 3.4).
#
# SIBLING-KEEPER: SmallLevelLayoutGenerator and MediumLevelLayoutGenerator are siblings (same fixed
# draw order, same shrinking-pool selection, same fingerprint format). Wrinkle placement is the same
# logic for both, so it lives here as a small shared RefCounted helper rather than being copy-pasted.
# It is intentionally NOT a general wrinkle framework — it realizes ONLY the four v0-terrain-expressible
# wrinkle kinds and nothing else.
#
# WHAT THIS STORY PLACES (AC1): at least `min_tactical_wrinkles` readable tactical wrinkles per combat
# recipe, drawn deterministically from the recipe's `allowed_wrinkle_kinds` allowlist FILTERED to the
# v0-realizable subset, realized as EXISTING BoardCell.Terrain values:
#   - choke_point / blocker_cluster / flank_route -> a WALL cell (interior structure / cover shaping),
#   - hazard                                       -> a HAZARD cell (walkable + sight-transparent).
# Each placed wrinkle's kind is recorded so the caller can surface it in generation diagnostics.
#
# WHAT THIS STORY DOES NOT DO (scope guards):
#   - enemy_formation / reward_behind_danger : need entities/rewards -> Story 3.5 (NOT realized here).
#   - door / affinity_placeholder / risky_side_branch : need a feature subsystem -> later/Epic 7.
#   - hazard DANGER (standing-on-hazard damage / telegraphs) : rules-kernel concern -> a later story.
# A HAZARD cell here is readable domain TERRAIN only; it is walkable and does not block line of sight
# (BoardCell.terrain_blocks_occupancy()/blocks_line_of_sight() are true ONLY for WALL), which is exactly
# why entrance->exit progress (AC2) stays possible with a hazard present.
#
# AC1 DETERMINISM CONTRACT (identical in spirit to the blocker draws): every wrinkle-affecting random
# choice (which kinds, which cells) is drawn through GenerationRequest.draw_layout_int, which routes
# EXCLUSIVELY through RngStreamSet.STREAM_LEVEL. NEVER randi()/randf(), NEVER a RandomNumberGenerator,
# NEVER another stream. The wrinkle draws are APPENDED AFTER the generator's existing blocker draws in
# a FIXED, documented order so the existing blocker behaviour is preserved and the re-pinned
# fingerprints are reproducible.
#
# FIXED WRINKLE DRAW ORDER (appended after blocker count + blocker positions):
#   3. wrinkle_kind     : for each of the `min_tactical_wrinkles` required wrinkles, one
#                         draw_layout_int over [0 .. realizable_kinds.size()-1] selecting a kind from
#                         the realizable allowlist (with replacement; a kind may repeat).
#   4. wrinkle_position : for each required wrinkle, one draw_layout_int over the *current* candidate
#                         list index (rejection-free shrinking pool shared with the blockers so a
#                         wrinkle cell never collides with a blocker or another wrinkle cell).
#
# CORRIDOR/ENTRANCE/EXIT SAFETY (AC2): wrinkle cells are drawn from the SAME candidate pool the
# blockers use, which already excludes the reserved central corridor row + the entrance + the exit.
# So a WALL wrinkle can never wall off the mandatory path, and a HAZARD wrinkle can never land on the
# safe mandatory route (an unavoidable hazard on the only path would be an unfair start).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")

# The v0-terrain-realizable wrinkle kinds, in a CANONICAL fixed order. Filtering the recipe allowlist
# against this list (preserving THIS order) keeps kind selection deterministic and independent of the
# order the recipe happens to list its kinds in. Any recipe kind NOT in this set is non-realizable in
# v0 and is skipped (see select_realizable_kinds + the file header scope guards).
const REALIZABLE_KINDS: Array[StringName] = [
	LevelRecipeDefinition.WRINKLE_CHOKE_POINT,
	LevelRecipeDefinition.WRINKLE_FLANK_ROUTE,
	LevelRecipeDefinition.WRINKLE_BLOCKER_CLUSTER,
	LevelRecipeDefinition.WRINKLE_HAZARD
]


# Filter a recipe's allowed_wrinkle_kinds down to the v0-realizable subset, preserving REALIZABLE_KINDS
# order (NOT the recipe's listing order) so selection is deterministic across recipes that list the
# same kinds differently. A kind only appears once even if the recipe lists it twice.
static func select_realizable_kinds(allowed_wrinkle_kinds: Array) -> Array[StringName]:
	var allowed_lookup: Dictionary = {}
	for kind_value: Variant in allowed_wrinkle_kinds:
		allowed_lookup[StringName(str(kind_value))] = true
	var realizable: Array[StringName] = []
	for kind: StringName in REALIZABLE_KINDS:
		if allowed_lookup.has(kind):
			realizable.append(kind)
	return realizable


# Place the required tactical wrinkles deterministically and return a structured ActionResult.
#
# On success: ActionResult.ok([], {"wrinkles": [<wrinkle record>, ...]}) where each record is
#   {"kind": StringName, "cell": Vector2i, "terrain": int}
# in placement (draw) order. The caller realizes each record onto its terrain grid (terrain value at
# cell) and records the kinds in diagnostics. `consumer_prefix` namespaces the RNG draw context
# (e.g. "small_layout" / "medium_layout") so the two generators' draw contexts are distinguishable in
# diagnostics WITHOUT changing the draw values (context is not part of the RNG state advance).
#
# `candidate_pool` is the blocker candidate list AFTER the chosen blockers have been removed (the same
# shrinking pool the generator already maintains), so wrinkle cells never collide with blockers. It is
# duplicated internally; the caller's pool is not mutated.
#
# Behaviour:
#   - A recipe with min_tactical_wrinkles <= 0 (a non-combat / no-wrinkle recipe) places NO wrinkles
#     and draws NOTHING (the wrinkle draws are skipped so the stream advances identically for a
#     no-wrinkle recipe), returning an empty list.
#   - If no realizable kind is available (the recipe allows only non-v0-realizable kinds), the placer
#     returns a structured error — this never binds for the two baseline recipes (both expose
#     realizable kinds), but it fails LOUD rather than silently under-placing.
#   - If the shared candidate pool runs dry before the minimum is met (degenerate tiny board), it
#     places as many as it can and stops; the caller's count assertion (>= minimum) is the tripwire.
#     For the baseline 8x8/14x12 boards the pool is far larger than the minimum, so this never binds.
static func place_wrinkles(
	request: GenerationRequest,
	streams: RngStreamSet,
	recipe: LevelRecipeDefinition,
	candidate_pool: Array[Vector2i],
	consumer_prefix: String
) -> ActionResult:
	var minimum: int = recipe.min_tactical_wrinkles
	if minimum <= 0:
		return ActionResult.ok([], {"wrinkles": []})

	var realizable: Array[StringName] = select_realizable_kinds(recipe.allowed_wrinkle_kinds)
	if realizable.is_empty():
		return ActionResult.error(&"no_realizable_wrinkle_kind", {
			"reason": "recipe_allows_no_v0_realizable_wrinkle_kind",
			"min_tactical_wrinkles": minimum,
			"allowed_wrinkle_kinds": _to_string_array(recipe.allowed_wrinkle_kinds)
		})

	var pool: Array[Vector2i] = candidate_pool.duplicate()
	var placed: Array[Dictionary] = []
	for wrinkle_index: int in range(minimum):
		if pool.is_empty():
			break

		# FIXED WRINKLE DRAW #3: select a realizable kind (with replacement).
		var kind_draw: ActionResult = request.draw_layout_int(streams, 0, realizable.size() - 1, {
			"consumer": "%s_wrinkle_kind" % consumer_prefix,
			"wrinkle_index": wrinkle_index
		})
		if kind_draw.is_error():
			return kind_draw
		var kind: StringName = realizable[int(kind_draw.metadata.get("value"))]

		# FIXED WRINKLE DRAW #4: select a cell from the shared shrinking pool (no collisions).
		var cell_draw: ActionResult = request.draw_layout_int(streams, 0, pool.size() - 1, {
			"consumer": "%s_wrinkle_position" % consumer_prefix,
			"wrinkle_index": wrinkle_index
		})
		if cell_draw.is_error():
			return cell_draw
		var picked_index: int = int(cell_draw.metadata.get("value"))
		var cell: Vector2i = pool[picked_index]
		pool.remove_at(picked_index)

		placed.append({
			"kind": kind,
			"cell": cell,
			"terrain": _terrain_for_kind(kind)
		})

	return ActionResult.ok([], {"wrinkles": placed})


# Map a realizable wrinkle kind to the BoardCell.Terrain value that realizes it. The structural kinds
# (choke_point / blocker_cluster / flank_route) are expressed as interior WALL; hazard is HAZARD
# terrain (the first story to emit it). A non-realizable kind would never reach here (filtered out by
# select_realizable_kinds), but defaults to FLOOR rather than crashing if it somehow did.
static func _terrain_for_kind(kind: StringName) -> int:
	if kind == LevelRecipeDefinition.WRINKLE_HAZARD:
		return BoardCell.Terrain.HAZARD
	return BoardCell.Terrain.WALL


static func _to_string_array(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		result.append(String(value))
	return result
