class_name DarknessFairnessQuery
extends RefCounted

# Story 7.6 (FR58 — "Darkness must create uncertainty ... WITHOUT unavoidable damage from unseen space") — THE FAIRNESS
# GUARDRAIL, the heart of the story (the "without unavoidable damage from unseen space" half of AC1 + all of AC3). It is
# a BOARD-SCOPED, AFFINITY-AWARE fairness check that, GIVEN a BUILT Epic-1 BoardState + a level's assigned Darkness
# affinity + the Darkness-reduced LoS radius, asserts "no unavoidable damage from unseen space" AT THE REDUCED RADIUS,
# and FAILS LOUD with a stable fairness reason code + the seed + the phase (AC3).
#
# ⭐ THE DECISION (recorded in the story's Completion Notes): this is a NEW affinity-aware fairness QUERY, NOT a
# LevelValidator wiring change. It EXTENDS the LevelValidator SAFE-FIRST-REVEAL v0 SEMANTIC (the entrance not on HAZARD /
# not entity-occupied — which already cites FR5/FR58) and ADDS the Darkness-reduced-radius reasoning. It is BOARD-SCOPED
# + CALLER-DRIVEN (runs over a BUILT board POST-generation — the 7.5 posture): it does NOT change the generator's RNG
# draw order, does NOT re-pin ANY seed-regression fingerprint, and does NOT alter how LevelValidator wires into the
# generation success path (LevelValidator's neutral validate(candidate) path stays byte-identical; this is a separate,
# additive, affinity-gated query). The generator is affinity-blind in v0 — the affinity is assigned POST-generation by
# the orchestrator (the 7.4 contract), so a Darkness-aware fairness check belongs at the board/query layer, not in the
# generation pipeline.
#
# ⭐ THE FR58 RISK DARKNESS INTRODUCES (the key thing this guards): the baseline LevelValidator reasons that a threat
# ADJACENT to the entrance is FAIR because the baseline LoS radius (4, FR5) reveals it on spawn. But if Darkness REDUCES
# the radius, a damage source that WAS seen at radius 4 may be UNSEEN at the reduced radius — re-opening exactly the
# "unavoidable damage from unseen space" FR58 forbids. So this check re-asserts the no-unavoidable-unseen-damage
# guarantee AT THE DARKNESS-REDUCED radius.
#
# THE v0 UNAVOIDABLE-DAMAGE SOURCE = a HAZARD cell. The Small recipe is all-FLOOR (the Scorched hazard is stamped
# POST-generation onto a built board; a generated Small Darkness board has NO hazards). The MEDIUM recipe, however,
# BAKES wrinkle-phase `Terrain.HAZARD` cells into some seeds (the 3.4 hazard wrinkle — part of the pinned Medium
# terrain fingerprint, e.g. seeds 4004/5005), so a generated Medium Darkness board CAN carry reachable hazards. Under
# the moving-LoS predicate below those reachable hazards are FAIR (necessarily seen-before-contact). The FAIL branch is
# driven by a genuinely-unfair config: the entrance itself forced-damaged/occupied (predicate (a)), or a future
# sight-BLOCKING hazard / forced-teleport movement that could drop the hero onto a hazard with no see-first step. THE
# FAIRNESS PREDICATE:
#   (a) SAFE FIRST REVEAL at the reduced radius: the entrance cell is NOT HAZARD and no entity occupies the entrance
#       (the LevelValidator semantic — the player is not spawned ON forced damage / ON an enemy).
#   (b) NO UNSEEN-BEFORE-CONTACT HAZARD at the reduced radius (Story 10.8 — strengthened from static-from-entrance to
#       MOVING reduced-radius LoS / "seen-before-contact"): every HAZARD cell that is REACHABLE (the hero could
#       walk onto it under stepwise 4-neighbour movement) must be LINE-OF-SIGHT VISIBLE at the DARKNESS-REDUCED radius
#       from at least one reachable 4-neighbour "step-from" cell — i.e. the hero necessarily SEES the hazard from the
#       cell they would stand on the turn BEFORE they could step onto it. A reachable hazard the hero could reach WITHOUT
#       ever seeing it first is "damage from unseen space" -> FAIL `darkness_unseen_hazard`. This replaces the v0
#       static-from-ENTRANCE question ("is the hazard seen from spawn?") with the fair moving-LoS question ("is the
#       hazard seen from some reachable step-from cell before contact?").
#
#       ⭐ WHY THIS IS SOUND UNDER THE v0 BOARD FACTS (cite these — a future reviewer must see WHY the check passes every
#       reachable v0 hazard while staying genuinely re-trippable): (1) HAZARD is WALKABLE + SIGHT-TRANSPARENT —
#       `BoardCell.blocks_line_of_sight()` is true ONLY for `Terrain.WALL` (board_cell.gd:33-34), so a hazard never
#       occludes a line and is itself steppable. (2) Any REACHABLE hazard has at least one reachable 4-neighbour
#       step-from cell — reachability IS a 4-neighbour terrain flood (`_flood_terrain`), so the flood arrived at the
#       hazard via one such neighbour. (3) From a step-from cell the hazard is at squared distance 1, WITHIN the reduced
#       radius (floor 1). (4) LoS between two 4-ADJACENT cells can NEVER be occluded — `TacticalLineQuery.blocking_cells`
#       inspects only the INTERIOR line cells (`range(1, max(1, line.size() - 1))`, tactical_line_query.gd:63), and an
#       adjacent line `[origin, target]` has NO interior cell, so `has_line_of_sight` is true unconditionally. Therefore
#       every reachable v0 hazard is seen-before-contact => PASS. The check is NOT hard-coded PASS: it actually walks the
#       reachable region and tests LoS from each reachable step-from cell, so a FUTURE sight-blocking hazard (a hazard
#       that DID occlude), or a hazard with NO reachable 4-neighbour step-from cell (a forced-teleport-only landing),
#       would find NO seen-before-contact step and FAIL LOUD `darkness_unseen_hazard`.
#       (A hazard that is SEALED — terrain-unreachable from the entrance — cannot be stepped on, so it is not an
#       unseen-damage source; it does not fail this check.)
#
# FAIL LOUD (AC3): the failure ActionResult carries a stable lower-snake `fairness_reason` code, the `seed` (a String —
# the int64 decimal-string discipline; the level seed is already a String), and a `phase` (reuse
# LevelValidator.phase_for_code -> `validation`). COMPACT diagnostics (counts/coords — NEVER a grid dump, the
# LevelValidator discipline). PASS carries compact counts (reduced radius, hazard count, visible-from-entrance count).
#
# PURE QUERY (the LevelValidator / snapshot precedent): draws NO RNG, runs NO commands, mutates nothing. Same
# (board, affinity, seed) -> identical verdict (the AC3 determinism + seed-reproducibility invariant).
#
# SCOPE GUARDS (do NOT build here): no generator/generation-pipeline change; no seed-regression re-pin; no new RNG
# stream / event / save key; no live combat loop / turn simulation / enemy AI (a STATIC board-scoped check — it does not
# play turns); no HAZARD-blocks-movement change (HAZARD stays walkable + sight-transparent, the 3.4 contract). It checks
# fairness; it does not REPAIR an unfair board (that would be a generation-modifier concern).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const LevelValidator = preload("res://scripts/generation/level/level_validator.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")
const TacticalLineQuery = preload("res://scripts/tactical/targeting/tactical_line_query.gd")

# Stable lower-snake fairness reason codes (the LevelValidator stable-code discipline). These are the `fairness_reason`
# values an unfair Darkness board reports (AC3 "failures report ... fairness reason").
const REASON_ENTRANCE_ON_HAZARD := &"entrance_on_hazard"
const REASON_ENTITY_ON_ENTRANCE := &"entity_on_entrance"
const REASON_UNSEEN_HAZARD := &"darkness_unseen_hazard"
const REASON_INVALID_CANDIDATE := &"invalid_darkness_candidate"

# Fixed 4-neighbour offsets (matches LevelValidator.NEIGHBOUR_OFFSETS / the generators) for the deterministic terrain
# reachability flood used to decide whether a hazard cell is reachable (steppable) at all.
const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1)
]

# The fairness phase (AC3 "failures report ... phase"). Reuses the LevelValidator phase vocabulary — fairness validation
# maps to `validation` (the SAFE-FIRST-REVEAL semantic this extends already reports validation via
# LevelValidator.phase_for_code). Exposed as a constant + via phase() so a caller/test reads one source of truth.
const FAIRNESS_PHASE := &"validation"


# The fairness phase for a Darkness fairness verdict (AC3). Delegates to LevelValidator.phase_for_code for the
# safe-first-reveal codes (so the Darkness fairness phase agrees with the validator's existing first-reveal mapping) and
# returns `validation` for the Darkness-specific unseen-hazard code. Keeps ONE phase vocabulary across the fairness layer.
static func phase_for_reason(reason: StringName) -> StringName:
	match reason:
		REASON_ENTRANCE_ON_HAZARD, REASON_ENTITY_ON_ENTRANCE:
			# These ARE the LevelValidator unsafe_first_reveal cases — route through its mapping (-> validation).
			return LevelValidator.phase_for_code(LevelValidator.CODE_UNSAFE_FIRST_REVEAL)
		_:
			return FAIRNESS_PHASE


# Check a BUILT Darkness board for FR58 fairness. `board` is the built BoardState (entrance carries Terrain.ENTRANCE).
# `affinity_id` is the level's assigned affinity (only Darkness is fairness-checked here). `repository` resolves the
# Darkness markers + the reduced radius. `seed` is the level seed (a String — carried verbatim into the failure report
# for AC3). `entrance` is the entrance cell (passed explicitly so the check does not assume how the caller stored it;
# if Vector2i(-1,-1) it is derived from the board's ENTRANCE terrain cell). Returns ActionResult.ok([], {<compact pass
# report>}) on a fair board, or ActionResult.error(&"darkness_fairness_violation", {fairness_reason, seed, phase, ...})
# on the FIRST violation (AC3). For a NEUTRAL / non-Darkness affinity the board is NOT fairness-checked here (there is no
# reduced radius to re-assert against) — it returns a legal `not_applicable` pass (a valid, readable answer).
func check_board(
	board: BoardState,
	affinity_id: StringName,
	repository: AffinityRepository,
	seed: String,
	entrance: Vector2i = Vector2i(-1, -1)
) -> ActionResult:
	if board == null or not board.has_cells():
		return _violation(REASON_INVALID_CANDIDATE, seed, {"reason_detail": "missing_or_empty_board"})

	var layer: DarknessVisibilityLayer = DarknessVisibilityLayer.new()
	# Neutral / non-Darkness: no Darkness reduced radius applies, so there is no Darkness-introduced unseen-damage risk
	# to re-assert. Report a legal not-applicable pass (the 7.5 neutral-posture: a valid empty answer, not an error).
	if not layer.is_darkness(affinity_id, repository):
		return ActionResult.ok([], {
			"affinity_id": String(affinity_id),
			"darkness_fairness_applicable": false,
			"reason": "not_a_darkness_level"
		})

	var resolved_entrance: Vector2i = entrance
	if resolved_entrance == Vector2i(-1, -1):
		resolved_entrance = _entrance_cell(board)
	if not board.in_bounds(resolved_entrance):
		return _violation(REASON_INVALID_CANDIDATE, seed, {"reason_detail": "entrance_out_of_bounds"})

	var reduced_radius: int = layer.reduced_radius_for(affinity_id, repository)

	# (a) SAFE FIRST REVEAL at the reduced radius — the entrance is not forced damage / not occupied (the LevelValidator
	# semantic, re-asserted here so the Darkness fairness verdict is self-contained for a direct caller).
	var entrance_cell: BoardCell = board.get_cell(resolved_entrance)
	if entrance_cell != null and entrance_cell.terrain == BoardCell.Terrain.HAZARD:
		return _violation(REASON_ENTRANCE_ON_HAZARD, seed, {
			"entrance": {"x": resolved_entrance.x, "y": resolved_entrance.y},
			"reduced_radius": reduced_radius
		})
	for entity: TacticalEntityState in board.entities():
		if entity.position == resolved_entrance:
			return _violation(REASON_ENTITY_ON_ENTRANCE, seed, {
				"entrance": {"x": resolved_entrance.x, "y": resolved_entrance.y},
				"entity_id": String(entity.entity_id),
				"reduced_radius": reduced_radius
			})

	# (b) NO UNSEEN-BEFORE-CONTACT HAZARD at the reduced radius (Story 10.8 — MOVING reduced-radius LoS). Every REACHABLE
	# hazard must be LoS-visible at the reduced radius from at least one reachable 4-neighbour "step-from" cell — the cell
	# the hero would stand on the turn BEFORE they could step onto the hazard. A reachable hazard the hero could reach
	# with NO such seen-before-contact step is "damage from unseen space" (FR58) -> FAIL. (See the class header proof:
	# under the v0 facts every reachable hazard has such a step, so this passes them all; it still FAILS LOUD for a future
	# sight-blocking hazard or a forced-teleport-only landing.)
	var terrain_reachable: Dictionary = _flood_terrain(board, resolved_entrance)
	var radius_squared: int = reduced_radius * reduced_radius
	var hazard_count: int = 0
	var seen_hazard_count: int = 0
	for board_cell: BoardCell in board.cells():
		if board_cell.terrain != BoardCell.Terrain.HAZARD:
			continue
		hazard_count += 1
		# A hazard cell the hero can never reach (sealed off by walls) cannot be stepped on -> not an unseen-damage
		# source. Only REACHABLE hazards matter for "unavoidable damage from unseen space".
		if not terrain_reachable.has(board_cell.position):
			continue
		# SEEN-BEFORE-CONTACT: is there a reachable 4-neighbour step-from cell from which the hazard is LoS-visible at the
		# reduced radius? If so, the hero necessarily sees the hazard the turn before they could step onto it -> fair.
		if not _seen_before_contact(board, board_cell.position, terrain_reachable, radius_squared):
			# A reachable hazard the hero could reach WITHOUT a see-first step — advance-blind damage from unseen space.
			# This is the exact FR58 violation the guardrail must still catch (a future sight-blocking hazard / forced
			# movement). FAIL LOUD with the offending hazard cell + compact diagnostics.
			return _violation(REASON_UNSEEN_HAZARD, seed, {
				"hazard_cell": {"x": board_cell.position.x, "y": board_cell.position.y},
				"entrance": {"x": resolved_entrance.x, "y": resolved_entrance.y},
				"reduced_radius": reduced_radius,
				"hazard_count": hazard_count
			})
		seen_hazard_count += 1

	# PASS — compact report (counts/coords only, never a grid dump; the LevelValidator discipline). Under the strengthened
	# semantics `reachable_seen_hazard_count` is the count of reachable hazards proven seen-before-contact.
	return ActionResult.ok([], {
		"affinity_id": String(affinity_id),
		"darkness_fairness_applicable": true,
		"seed": seed,
		"reduced_radius": reduced_radius,
		"entrance": {"x": resolved_entrance.x, "y": resolved_entrance.y},
		"hazard_count": hazard_count,
		"reachable_seen_hazard_count": seen_hazard_count
	})


# Build the FIRST-violation failure ActionResult (AC3): a stable top-level error code with the fairness_reason + seed +
# phase + compact diagnostics in metadata. ONE top-level code per failure class (the run-command error-model discipline);
# the precise machine-readable reason is `fairness_reason`. The seed is carried verbatim as a String (the int64
# decimal-string discipline — the level seed is already a String, so no re-encoding is needed).
func _violation(reason: StringName, seed: String, diagnostics: Dictionary = {}) -> ActionResult:
	var metadata: Dictionary = {
		"fairness_reason": String(reason),
		"seed": seed,
		"phase": String(phase_for_reason(reason))
	}
	for key: Variant in diagnostics.keys():
		metadata[key] = diagnostics[key]
	return ActionResult.error(&"darkness_fairness_violation", metadata)


# The entrance cell, derived from the board's ENTRANCE terrain cell (used when the caller does not pass one explicitly).
# Returns Vector2i(-1,-1) if no ENTRANCE cell exists (a malformed candidate — surfaced as invalid_darkness_candidate).
func _entrance_cell(board: BoardState) -> Vector2i:
	for board_cell: BoardCell in board.cells():
		if board_cell.terrain == BoardCell.Terrain.ENTRANCE:
			return board_cell.position
	return Vector2i(-1, -1)


# Deterministic 4-neighbour TERRAIN flood from `origin` over non-WALL cells (IDENTICAL walkability to
# LevelValidator._flood_terrain — only WALL blocks; HAZARD is walkable, the 3.4 contract). Returns a visited set
# (Vector2i -> true). Pure query — decides whether a hazard cell is reachable (steppable) at all.
func _flood_terrain(board: BoardState, origin: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	if not board.in_bounds(origin):
		return visited
	var origin_cell: BoardCell = board.get_cell(origin)
	if origin_cell == null or origin_cell.terrain == BoardCell.Terrain.WALL:
		return visited
	var frontier: Array[Vector2i] = [origin]
	visited[origin] = true
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for offset: Vector2i in NEIGHBOUR_OFFSETS:
			var neighbour: Vector2i = current + offset
			if visited.has(neighbour):
				continue
			if not board.in_bounds(neighbour):
				continue
			var neighbour_cell: BoardCell = board.get_cell(neighbour)
			if neighbour_cell == null or neighbour_cell.terrain == BoardCell.Terrain.WALL:
				continue
			visited[neighbour] = true
			frontier.append(neighbour)
	return visited


# Story 10.8 — the MOVING reduced-radius LoS "seen-before-contact" predicate for ONE reachable hazard. Returns true iff
# there exists at least one reachable 4-neighbour "step-from" cell of `hazard` from which the hazard is LINE-OF-SIGHT
# VISIBLE at the reduced radius (squared distance <= `radius_squared` AND `has_line_of_sight`). The step-from cell is the
# cell the hero would stand on the turn before they could step onto the hazard, so a hazard seen from ANY such cell is
# necessarily seen before contact -> fair. Walks the reachable step-from cells and ACTUALLY tests LoS (not a hard-coded
# PASS), so a future sight-blocking hazard (LoS occluded) or a hazard with NO reachable 4-neighbour step-from cell
# (forced-teleport-only landing) returns false and the caller FAILS LOUD. Pure terrain/LoS read (no RNG, no mutation).
#
# Under the v0 facts this is always true for a reachable hazard: reachability arrived via a reachable 4-neighbour, that
# neighbour is at squared distance 1 (<= the reduced radius, floor 1), and LoS between 4-adjacent cells is unoccludable
# (the adjacent supercover line has no interior cell) — see the class header proof.
func _seen_before_contact(board: BoardState, hazard: Vector2i, terrain_reachable: Dictionary, radius_squared: int) -> bool:
	for offset: Vector2i in NEIGHBOUR_OFFSETS:
		var step_from: Vector2i = hazard + offset
		# The step-from cell must be a cell the hero can actually stand on the turn before contact: reachable terrain.
		if not terrain_reachable.has(step_from):
			continue
		# From that step-from cell, is the hazard within the reduced radius AND LoS-visible (unoccluded)? If so, the hero
		# necessarily sees the hazard before they could step onto it -> seen-before-contact.
		if step_from.distance_squared_to(hazard) > radius_squared:
			continue
		if TacticalLineQuery.has_line_of_sight(board, step_from, hazard):
			return true
	return false
