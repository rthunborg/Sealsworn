class_name DarknessVisibilityLayer
extends RefCounted

# Story 7.6 (FR58 — "Darkness must create uncertainty through visibility or memory pressure without unavoidable damage
# from unseen space") — THE NEW HOME for the Darkness affinity's EFFECT. It is a scene-free, deterministic, PURE-DOMAIN
# VISIBILITY/MEMORY-PRESSURE layer that, GIVEN a built Epic-1 BoardState + a level's assigned affinity id (resolved
# through the 7.4 AffinityRepository), reads the Darkness RECORDED `tactical_rules` markers (the 7.4 data —
# `reduced_visibility`/`hidden_threats`/`fog_memory_pressure`) and turns them into a REAL, DETERMINISTIC, EXPLAINABLE
# reduced line-of-sight radius + an explicit memory-uncertainty surface.
#
# ⭐ THE PIVOTAL ARCHITECTURAL DECISION (recorded in the story's Completion Notes): Darkness's effect is a
# VISIBILITY/FOG/MEMORY effect, NOT a board-cell HAZARD effect. This layer is DELIBERATELY SEPARATE from the 7.5
# AffinityEffectResolver.resolve_board_plan / AffinityPreviewQuery (the BOARD-CELL HAZARD layer — Scorched stamps
# HAZARD terrain, Flooded marks conductive/pathing CELLS). Darkness shapes how FAR / WHAT the hero can SEE (the LoS
# radius) and how reliable EXPLORED MEMORY is — a fundamentally different KIND. The hazard resolver's Darkness branch
# stays a deliberate NO-OP (the two existing tests `test_affinity_effect_resolver.gd::_darkness_is_a_no_op_in_7_5` +
# `test_affinity_preview_query.gd` darkness branch stay green BY CONSTRUCTION — Darkness's effect lives HERE, not there).
#
# ⭐ HOMED IN `scripts/tactical/fog/` (the visibility-domain home, alongside TacticalVisibilityQuery) rather than
# `scripts/rules/operations/` (the hazard-effect home) — the placement most faithful to the visibility-domain nature of
# the effect. `scripts/rules/conditions/` STAYS EMPTY (no condition primitive needed — the dispatch is a direct
# per-affinity check).
#
# WHAT IT IS:
#   - is_darkness(affinity_id, repository) -> true iff the affinity is Darkness AND carries the reduced-visibility marker
#     (a fail-SAFE read — if 7.4 ever drops the marker, Darkness simply has no effect rather than crashing). Neutral /
#     Scorched / Flooded / Cursed / unknown / unassigned -> false.
#   - reduced_radius_for(affinity_id, repository, baseline_radius) -> the Darkness-reduced LoS radius (an AUTHORED,
#     BOUNDED reduction: DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS = 2 from the baseline 4; never 0, never below the fairness
#     floor of 1). Neutral / non-Darkness -> the baseline radius unchanged. The reduction is content/pressure, NOT a
#     hidden difficulty scalar (the difficulty hard non-goal).
#   - calculate_visible_cells(query, board, origin, affinity_id, repository) -> reuses the EXISTING
#     TacticalVisibilityQuery.calculate_visible_cells by PASSING the reduced radius (does NOT fork a parallel LoS
#     algorithm). A Darkness level's visible set is the LoS set computed at the reduced radius.
#   - visible_facts_for_cell(query, board, cell, affinity_id, repository) -> wraps the EXISTING
#     TacticalVisibilityQuery.visible_facts_for_cell and, for Darkness, ADDITIVELY annotates a `memory`-state cell as
#     STALE/UNCERTAIN (fog_memory_pressure) WITHOUT touching the `visible` (authoritative) branch or the `hidden` branch,
#     and WITHOUT mutating stored BoardCell / snapshot state (a READ-layer annotation only). Neutral / non-Darkness ->
#     the byte-identical neutral facts (the existing Epic-1 contract is never changed for non-Darkness).
#
# WHAT IT IS NOT:
#   - It owns NO domain truth, submits NO command, draws ZERO RNG, and mutates NOTHING — not a scene node, not a Control,
#     not autoload-owned state, not presentation, and (the AC2 honest reading) not stored board/snapshot state. Same
#     (board, affinity_id) -> identical reduced radius + identical visible set + identical memory annotation (the AC1/AC3
#     determinism + the GDD seed-reproducibility invariant). v0 Darkness is FULLY DETERMINISTIC — a fixed authored
#     reduced radius + a deterministic memory flag. If a FUTURE Darkness effect rolls, it MUST draw the EXISTING `combat`
#     stream (never randi/randf/a fresh RandomNumberGenerator/cosmetic).
#   - It is NOT a board-cell hazard layer (no HAZARD stamp, no terrain mutation) and NOT a generation-pipeline change
#     (it operates POST-generation on a built board — the generator stays affinity-blind, every seed-regression
#     fingerprint byte-identical).
#
# DIFFICULTY IS A HARD NON-GOAL (project-context): the reduced radius + memory uncertainty is authored, bounded tactical
# PRESSURE surfaced HONESTLY — NEVER a hidden multiplier scaling enemy stats/HP/damage/rewards/RNG/run length.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")

# The Darkness affinity id (the 7.4 baseline; CONSUMED here, never re-authored).
const AFFINITY_DARKNESS := &"darkness"

# The recorded Darkness tactical_rules marker ids (7.4) this layer reads. They MUST match
# AffinityRepository._baseline_definitions(); a marker's PRESENCE gates the corresponding effect (a fail-safe read — if
# 7.4 ever drops a marker, the effect simply does not fire rather than crashing).
const MARKER_REDUCED_VISIBILITY := "reduced_visibility"
const MARKER_HIDDEN_THREATS := "hidden_threats"
const MARKER_FOG_MEMORY_PRESSURE := "fog_memory_pressure"

# The AUTHORED, BOUNDED Darkness reduced LoS radius (FR58 reduced_visibility). The baseline is FR5's radius 4
# (TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS); Darkness reduces it to 2 — a meaningful "you can see your
# neighbourhood but not far" reduction. It is AUTHORED content/pressure, deterministic, and bounded — NOT a difficulty
# scalar. The DARKNESS_RADIUS_FLOOR is the hard fairness minimum (>= 1) so the hero can ALWAYS see their own cell + its
# immediate ring; the reduced radius is clamped to never drop below it (a future smaller authored value still floors at 1).
const DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS: int = 2
const DARKNESS_RADIUS_FLOOR: int = 1

# --- Non-color cue ids (FINAL ids — Darkness is fully realized here, NOT a tracked placeholder like Flooded's electric
# interaction). The accessibility mapping for each lives in TacticalAccessibilityModel._CUE_CATALOG (keyed by cue id),
# the canonical color-independence audit driver — each carries a NON-COLOR channel (AC2 + the Epic-2 + 7.5 contract).
const CUE_DARKNESS_REDUCED_VISIBILITY := "affinity_darkness_reduced_visibility"
const CUE_DARKNESS_MEMORY_UNCERTAIN := "affinity_darkness_memory_uncertain"

# The stable visibility-state strings (mirror TacticalVisibilityQuery.visible_facts_for_cell). Kept local so this layer
# and any reader agree on the keys without a cross-class const dependency.
const STATE_HIDDEN := "hidden"
const STATE_MEMORY := "memory"
const STATE_VISIBLE := "visible"


# Is the Darkness EFFECT active for this affinity id? True iff the affinity is Darkness AND it carries the
# reduced_visibility marker (the fail-safe gate — the effect rides off the recorded 7.4 marker, so a content drop
# disables it rather than crashing). Neutral / Scorched / Flooded / Cursed / unknown / unassigned -> false.
func is_darkness(affinity_id: StringName, repository: AffinityRepository) -> bool:
	if affinity_id != AFFINITY_DARKNESS:
		return false
	return _markers_for(affinity_id, repository).has(MARKER_REDUCED_VISIBILITY)


# The Darkness-reduced line-of-sight radius. For an active Darkness affinity (the reduced_visibility marker present),
# return the AUTHORED reduced radius clamped to the fairness floor (>= 1). For neutral / non-Darkness (or a Darkness
# affinity missing the marker — fail-safe), return the baseline radius UNCHANGED. The baseline defaults to FR5's radius 4
# but is accepted as a parameter so a caller with a non-default LoS bound is honoured. Pure: no mutation, no RNG.
func reduced_radius_for(
	affinity_id: StringName,
	repository: AffinityRepository,
	baseline_radius: int = TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS
) -> int:
	if not is_darkness(affinity_id, repository):
		return baseline_radius
	# Clamp to the fairness floor so the reduced radius is never 0 (FR5/FR58 — the hero must always see their own
	# neighbourhood). The authored value (2) is already >= the floor; the clamp guards a future smaller authored value.
	return max(DARKNESS_RADIUS_FLOOR, DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS)


# AC1 — the Darkness reduced visible set. Reuses the EXISTING TacticalVisibilityQuery.calculate_visible_cells (the radius
# is already a parameter) by passing the Darkness-reduced radius. Does NOT fork a parallel LoS algorithm. For
# neutral / non-Darkness this is byte-identical to calling the query at the baseline radius. The `query` is injected
# (the caller owns the TacticalVisibilityQuery instance) so this layer adds no hidden dependency. Pure: no mutation, no
# RNG (the underlying query is itself a pure read).
func calculate_visible_cells(
	query: TacticalVisibilityQuery,
	board: BoardState,
	origin: Vector2i,
	affinity_id: StringName,
	repository: AffinityRepository
) -> ActionResult:
	if query == null:
		return ActionResult.error(&"invalid_darkness_visibility_query", {"reason": "missing_query"})
	var radius: int = reduced_radius_for(affinity_id, repository)
	return query.calculate_visible_cells(board, origin, radius)


# AC2 — the Darkness-aware inspect/memory read. Wraps the EXISTING TacticalVisibilityQuery.visible_facts_for_cell and,
# for an active Darkness affinity, ADDITIVELY annotates a `memory`-state cell (explored-but-not-currently-visible) as
# STALE / UNCERTAIN (fog_memory_pressure) — a READ-LAYER annotation that does NOT mutate stored BoardCell / snapshot
# state, does NOT touch the `visible` (authoritative) branch (the live tactical truth stays byte-identical + reliable),
# and does NOT leak facts on a `hidden` cell (the Epic-1 fog contract). For neutral / non-Darkness the result is the
# byte-identical neutral fact the existing query returns (the Epic-1 visibility tests pin it — never changed).
#
# The annotation adds, on a `memory` cell under Darkness: `memory_uncertain: true`, `memory_certainty: "uncertain"`, and
# `uncertainty_cue_id: CUE_DARKNESS_MEMORY_UNCERTAIN`. The `authoritative: false` already on the memory branch is the
# structural guarantee AC2 relies on; this makes the uncertainty EXPLICIT + carries the non-color cue id. Pure.
func visible_facts_for_cell(
	query: TacticalVisibilityQuery,
	board: BoardState,
	cell: Vector2i,
	affinity_id: StringName,
	repository: AffinityRepository
) -> ActionResult:
	if query == null:
		return ActionResult.error(&"invalid_darkness_visibility_query", {"reason": "missing_query"})
	var base_result: ActionResult = query.visible_facts_for_cell(board, cell)
	if base_result.is_error():
		return base_result
	# Non-Darkness: return the existing query's result UNCHANGED (byte-identical neutral output — the Epic-1 contract).
	if not _is_memory_pressure_active(affinity_id, repository):
		return base_result

	# Darkness with fog_memory_pressure: annotate ONLY the `memory` state. The `visible` (authoritative) + `hidden`
	# branches are returned UNCHANGED — Darkness never distorts a currently-visible cell's facts, only flags how reliable
	# the MEMORY of an unseen cell is. Build a FRESH fact dict (never mutate the query's returned dict in place).
	var base_fact_value: Variant = base_result.metadata.get("fact", {})
	if not base_fact_value is Dictionary:
		return base_result
	var base_fact: Dictionary = base_fact_value
	if String(base_fact.get("visibility_state", "")) != STATE_MEMORY:
		# `visible` / `hidden`: the live truth (or the no-facts hidden cell) is untouched. Return as-is.
		return base_result

	var annotated_fact: Dictionary = base_fact.duplicate(true)
	annotated_fact["memory_uncertain"] = true
	annotated_fact["memory_certainty"] = "uncertain"
	annotated_fact["uncertainty_cue_id"] = CUE_DARKNESS_MEMORY_UNCERTAIN
	return ActionResult.ok([], {"fact": annotated_fact})


# Whether the fog_memory_pressure effect is active (Darkness AND the fog-memory-pressure marker present — the fail-safe
# gate). Drives the memory-uncertainty annotation in visible_facts_for_cell.
func _is_memory_pressure_active(affinity_id: StringName, repository: AffinityRepository) -> bool:
	if affinity_id != AFFINITY_DARKNESS:
		return false
	return _markers_for(affinity_id, repository).has(MARKER_FOG_MEMORY_PRESSURE)


# Resolve the affinity's recorded tactical_rules marker ids into a presence set ({rule_id: true}). Reads through the 7.4
# AffinityRepository.tactical_rules_for (the AC3 PURE-READ neutral query surface — returns the EMPTY set for the neutral
# `none` AND for an unknown/unassigned id, fail-SAFE). A null repository yields an empty set (defensive — the caller
# resolves through the fail-closed repo). Mirrors AffinityEffectResolver._marker_ids_for (the 7.5 marker-reading shape).
func _markers_for(affinity_id: StringName, repository: AffinityRepository) -> Dictionary:
	if repository == null:
		return {}
	var markers: Dictionary = {}
	for rule_value: Variant in repository.tactical_rules_for(affinity_id):
		if not rule_value is Dictionary:
			continue
		var rule: Dictionary = rule_value
		var rule_id: String = String(rule.get(AffinityDefinition.RULE_ID_KEY, ""))
		if not rule_id.is_empty():
			markers[rule_id] = true
	return markers
