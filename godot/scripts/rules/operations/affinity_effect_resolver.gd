class_name AffinityEffectResolver
extends RefCounted

# Story 7.5 (FR57 — "affinities must alter tactical choices rather than only visuals") — THE FIRST OCCUPANT of the
# previously-empty `scripts/rules/operations/` directory. It is the NARROW affinity tactical-EFFECT resolver: a
# scene-free, deterministic, PURE-DOMAIN service that, GIVEN a built Epic-1 BoardState + a level's assigned affinity id
# (resolved through the 7.4 AffinityRepository), reads the affinity's RECORDED `tactical_rules` markers (7.4 data) and
# turns them into REAL, DETERMINISTIC, EXPLAINABLE tactical pressure.
#
# ⭐ THE PIVOTAL SCOPE DECISION (recorded in the story's Completion Notes) — exactly how far `operations/` opens:
#   - This is a NARROW AFFINITY-EFFECT resolver, NOT the generic RuleCondition / RuleTarget / RuleOperation evaluation
#     model, NOT a stacking/conflict/duration framework, and NOT the combat HOOK sites that fire EVERY trigger window
#     for ALL rule sources. Those remain the later/broader operations story's. `scripts/rules/conditions/` STAYS EMPTY
#     (no MVP affinity effect needs a condition primitive — the dispatch is a direct per-affinity branch).
#   - It is BOARD-SCOPED + CALLER-DRIVEN, NOT a run-flow wiring: the run orchestrator AUTO-RESOLVES combat (there is NO
#     live tactical play loop / live board in the run), so this resolver operates on a BoardState GIVEN an assigned
#     affinity (fully headless-testable) and is NEVER auto-wired into `_resolve_combat`/`run_to_completion`. The
#     "enter node -> instantiate board -> apply affinity effects -> play turns" call site is a later HUD/run-flow story.
#   - It is a PURE function of (board, affinity_id, repository): same inputs -> identical effects (the AC2 determinism +
#     the GDD line-225 seed-reproducibility invariant). It draws ZERO RNG (the v0 effects are deterministic — fixed
#     hazard cells + amounts, deterministic marks; if a future effect rolls it MUST draw the existing `combat` stream,
#     never randi/randf). It mutates ONLY the passed-in BoardState (a domain model) + returns effect view-data; it
#     touches NO scene node, NO Control, NO autoload-owned state, NO presentation (the 7.5.4 "no direct scene-state
#     mutation").
#
# WHAT IT COVERS (the 3 MVP affinities whose effects 7.5 owns — Scorched / Flooded-Conductive / Cursed; Darkness's
# effect is 7.6's, so its branch is a deliberate NO-OP here):
#   - SCORCHED (AC1): STAMPS fire-hazard cells onto the board as BoardCell.Terrain.HAZARD (the 3.4 contract — HAZARD is
#     board-valid, WALKABLE, sight-TRANSPARENT; only WALL blocks; the hazard's DANGER is THIS layer's job, resolved as
#     a DAMAGE_APPLIED event by AffinityHazardDamageCommand for an entity in a hazard cell). Hazard cells are chosen
#     DETERMINISTICALLY (a fixed predicate over eligible FLOOR + UNOCCUPIED cells — never an entity's spawn cell, so no
#     unavoidable damage; FAIR by construction).
#   - FLOODED/CONDUCTIVE (AC2, AC4): DETERMINISTICALLY MARKS conductive danger-zone cells + pathing-pressure cells as
#     board/preview DATA (NOT terrain — the marks are surfaced via the plan/preview, they do NOT change the terrain
#     enum). The electric interaction is a TRACKED MVP PLACEHOLDER (AC4): the conductive danger cue/visual/explanation
#     ids are DISTINCT-from-final (`_placeholder` marker) and logged for the Epic-10 readiness gate.
#   - CURSED (AC3): resolved THROUGH the rules kernel — NOT a board mutation here. cursed_affinity_rule_source() builds
#     a curse-like CurseDefinition the caller seats on the run's RulesResolver (register_curse), so the kernel "applies
#     the configured cursed pressure" + explains it via explain(window); the economy-side penalty applies through the
#     7.1 RiskEconomyState API (the caller's job — the resolver is a pure read, like RulesResolver). Cursed produces NO
#     board effect (no hazard/mark), so resolve_board_plan/apply_board_effects are NO-OPS for it.
#
# NEUTRAL / UNKNOWN: the neutral `none` (and an UNKNOWN/unassigned id — the 7.4 tactical_rules_for returns the EMPTY set
# fail-SAFE) produces NO effects (the 7.4 AC3 contract carried forward — a level with no affinity yields no affinity
# side effects). Darkness is a NO-OP branch (its live effect is 7.6).
#
# DIFFICULTY IS A HARD NON-GOAL (project-context): an affinity effect is authored, bounded tactical PRESSURE (hazard
# cells, a fixed DoT amount, a conductive danger mark, a curse penalty) surfaced HONESTLY — NEVER a hidden multiplier
# scaling enemy stats/HP/damage/rewards/RNG/run length.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CurseDefinition = preload("res://scripts/content/definitions/curse_definition.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const TacticalEntityState = preload("res://scripts/tactical/entities/tactical_entity_state.gd")

# The recorded tactical_rules marker ids (7.4) this resolver reads, per affinity. They MUST match
# AffinityRepository._baseline_definitions(); a marker's PRESENCE gates the corresponding effect (a fail-safe read — if
# 7.4 ever drops a marker, the effect simply does not fire rather than crashing).
const MARKER_FIRE_HAZARD_CELLS := "fire_hazard_cells"
const MARKER_BURNING_TERRAIN_SPREAD := "burning_terrain_spread"
const MARKER_WATER_ELECTRIC_INTERACTION := "water_electric_interaction"
const MARKER_DANGER_ZONE_MARKING := "danger_zone_marking"
const MARKER_PATHING_PRESSURE := "pathing_pressure"

# The MVP affinity ids whose effects 7.5 owns (Darkness is 7.6's — a deliberate NO-OP).
const AFFINITY_SCORCHED := &"scorched"
const AFFINITY_FLOODED_CONDUCTIVE := &"flooded_conductive"
const AFFINITY_CURSED := &"cursed"

# --- Cue ids surfaced into previews/logs (the accessibility/cue vocabulary; mirrored in
# TacticalAccessibilityModel._CUE_CATALOG so each carries a NON-COLOR channel — the Epic-2 color-independence contract).
# The Scorched hazard cue + the Flooded pathing cue are FINAL ids; the conductive-danger cue is a TRACKED MVP
# PLACEHOLDER (AC4) — its id carries the `_placeholder` marker so the Epic-10 readiness pass can tell it from a final id.
const CUE_SCORCHED_HAZARD := "affinity_scorched_hazard"
const CUE_CONDUCTIVE_DANGER_PLACEHOLDER := "affinity_conductive_danger_placeholder"
const CUE_PATHING_PRESSURE := "affinity_pathing_pressure"

# AC4 — the Flooded electric-interaction PLACEHOLDER visual/explanation ids (DISTINCT-from-final; `_placeholder`
# marker). The live water/electric interaction is the Epic-10 readiness item; these are tracked in deferred-work.md.
const VISUAL_CONDUCTIVE_DANGER_PLACEHOLDER := "affinity_conductive_danger_placeholder_vfx"
const EXPLANATION_CONDUCTIVE_DANGER_PLACEHOLDER := "Conductive danger zone (MVP placeholder): standing here risks an electric interaction when current flows — placeholder pending the final water/electric effect."

# The Cursed-affinity curse-like rule source markers. The curse_source identifies the SOURCE (AC3) — a lower_snake
# marker derived from the affinity id. It declares the LEVEL_ENTERED window (the Cursed pressure bites as the affected
# level is entered — the 7.2 for_cursed_reward precedent, a fixed valid RuleTrigger window; v0 is RESOLVE+EXPLAIN).
const CURSED_AFFINITY_CURSE_SOURCE := &"affinity_cursed"


# THE PURE-READ PLAN (no mutation, no RNG, no events): given a board + an assigned affinity id, return the DETERMINISTIC
# affinity effect PLAN — which cells the affinity affects + the non-color cues + a readable explanation. This is the
# single source of truth for "which cells" that BOTH apply_board_effects (the mutation) and AffinityPreviewQuery (the
# explainability surface) consume, so the preview can never disagree with the applied effect. Neutral/unknown/Cursed/
# Darkness -> an empty plan (has_effects == false). The returned dictionary is freshly built each call (no shared refs).
func resolve_board_plan(board: BoardState, affinity_id: StringName, repository: AffinityRepository) -> Dictionary:
	var plan: Dictionary = _empty_plan(affinity_id)
	if board == null or not board.has_cells():
		return plan
	var markers: Dictionary = _marker_ids_for(affinity_id, repository)
	if markers.is_empty():
		# Neutral `none` / unknown / unassigned id, OR an affinity with no readable markers -> no board effects (AC3).
		return plan

	match affinity_id:
		AFFINITY_SCORCHED:
			_plan_scorched(board, markers, plan)
		AFFINITY_FLOODED_CONDUCTIVE:
			_plan_flooded(board, markers, plan)
		_:
			# Cursed routes through the rules kernel (no board effect); Darkness is 7.6's (NO-OP). Every other id has no
			# 7.5 board effect.
			pass
	return plan


# THE BOARD MUTATION (PURE DOMAIN — mutates ONLY the passed-in BoardState; no RNG, no scene, no autoload): stamp the
# affinity's board effects onto the built board. Only SCORCHED mutates the board (it stamps fire-hazard cells as
# BoardCell.Terrain.HAZARD). Flooded's conductive/pathing marks are board/preview DATA (NOT terrain) — they are surfaced
# via resolve_board_plan, not stamped, so apply_board_effects leaves a Flooded board's terrain UNTOUCHED. Cursed/
# Darkness/neutral mutate nothing. Returns metadata listing exactly what was stamped (idempotent: re-stamping a cell
# that is already HAZARD is a no-op). Fail-closed: a stamp that the board rejects aborts WITHOUT partial mutation.
func apply_board_effects(board: BoardState, affinity_id: StringName, repository: AffinityRepository) -> ActionResult:
	if board == null or not board.has_cells():
		return ActionResult.error(&"invalid_affinity_board", {"affinity_id": String(affinity_id)})

	var plan: Dictionary = resolve_board_plan(board, affinity_id, repository)
	var hazard_cells: Array = plan.get("scorched_hazard_cells", [])
	if hazard_cells.is_empty():
		# Neutral / Flooded (data-only) / Cursed / Darkness / unknown: nothing to stamp.
		return ActionResult.ok([], {
			"affinity_id": String(affinity_id),
			"stamped_hazard_cells": [],
			"has_effects": bool(plan.get("has_effects", false))
		})

	# Stage-validate every stamp BEFORE mutating so a reject leaves the board byte-identical (validate-then-mutate). A
	# cell already HAZARD needs no stamp; any other eligible cell is stamped to HAZARD via the board's setup setter.
	# (hazard_cells is the plan's SERIALIZED {x, y} dict list — resolve_board_plan returns serialized cells.)
	var stamped: Array[Dictionary] = []
	for cell_value: Variant in hazard_cells:
		if not cell_value is Dictionary:
			continue
		var cell: Vector2i = Vector2i(int((cell_value as Dictionary).get("x")), int((cell_value as Dictionary).get("y")))
		var existing: BoardCell = board.get_cell(cell)
		if existing == null:
			return ActionResult.error(&"invalid_affinity_hazard_cell", {
				"affinity_id": String(affinity_id),
				"x": cell.x,
				"y": cell.y
			})
		if existing.terrain == BoardCell.Terrain.HAZARD:
			continue
		var stamp_result: ActionResult = board.set_cell_terrain_for_setup(cell, BoardCell.Terrain.HAZARD)
		if stamp_result.is_error():
			return stamp_result
		stamped.append({"x": cell.x, "y": cell.y})

	return ActionResult.ok([], {
		"affinity_id": String(affinity_id),
		"stamped_hazard_cells": stamped,
		"has_effects": true
	})


# AC3 (Cursed) — build the curse-like rule source the CALLER seats on the run's RulesResolver (register_curse) so the
# rules kernel "applies the configured cursed pressure" + explains it via explain(window). This mirrors the 7.2
# CurseDefinition.for_cursed_reward precedent (a registered effect resolving + EXPLAINING through a trigger window; v0
# is RESOLVE+EXPLAIN-only — it surfaces the pressure, it does NOT mutate a combat HP/damage number here). Returns null
# for a non-Cursed affinity (neutral/Scorched/Flooded/Darkness/unknown seat NO Cursed rule source). The economy-side
# penalty (a curse-count increment) is applied by the caller through the 7.1 RiskEconomyState API — NOT here (the
# resolver, like RulesResolver, is a PURE READ: no RNG, no command, no economy mutation).
static func cursed_affinity_rule_source(affinity_id: StringName, repository: AffinityRepository = null) -> CurseDefinition:
	if affinity_id != AFFINITY_CURSED:
		return null
	var display_name: String = "Cursed"
	if repository != null:
		var definition: AffinityDefinition = repository.get_affinity(affinity_id)
		if definition != null and not definition.display_name.strip_edges().is_empty():
			display_name = definition.display_name
	return load("res://scripts/content/definitions/curse_definition.gd").new(
		StringName("curse_" + String(CURSED_AFFINITY_CURSE_SOURCE)),
		CURSED_AFFINITY_CURSE_SOURCE,
		display_name,
		[RuleTrigger.LEVEL_ENTERED],
		"Cursed affinity (%s): corrupted oath-law presses on this level — its curse penalty is felt when the level is entered (resolved and explained through the rules kernel before it bites)." % String(CURSED_AFFINITY_CURSE_SOURCE)
	)


# --- per-affinity planning (PURE — no mutation, no RNG) --------------------------------------------

func _plan_scorched(board: BoardState, markers: Dictionary, plan: Dictionary) -> void:
	if not markers.has(MARKER_FIRE_HAZARD_CELLS) and not markers.has(MARKER_BURNING_TERRAIN_SPREAD):
		return
	var hazard_cells: Array[Vector2i] = _scorched_hazard_cells(board)
	if hazard_cells.is_empty():
		return
	plan["has_effects"] = true
	plan["scorched_hazard_cells"] = _serialize_cells(hazard_cells)
	plan["cues"] = [_scorched_hazard_cue(hazard_cells.size())]
	plan["explanation"] = "Scorched: %s fire-hazard cells deal burning damage-over-time to any unit that lingers in them — seen and avoidable; move decisively." % hazard_cells.size()


func _plan_flooded(board: BoardState, markers: Dictionary, plan: Dictionary) -> void:
	var has_conductive: bool = markers.has(MARKER_WATER_ELECTRIC_INTERACTION) or markers.has(MARKER_DANGER_ZONE_MARKING)
	var has_pathing: bool = markers.has(MARKER_PATHING_PRESSURE)
	if not has_conductive and not has_pathing:
		return

	var cues: Array[Dictionary] = []
	var explanation_parts: Array[String] = []

	if has_conductive:
		var conductive_cells: Array[Vector2i] = _flooded_conductive_cells(board)
		plan["conductive_danger_cells"] = _serialize_cells(conductive_cells)
		if not conductive_cells.is_empty():
			plan["has_effects"] = true
			cues.append(_conductive_danger_cue(conductive_cells.size()))
			explanation_parts.append("Flooded/Conductive: %s conductive danger-zone cells (MVP placeholder for the live water/electric interaction) risk an electric hit when current flows." % conductive_cells.size())

	if has_pathing:
		var pathing_cells: Array[Vector2i] = _flooded_pathing_cells(board)
		plan["pathing_pressure_cells"] = _serialize_cells(pathing_cells)
		if not pathing_cells.is_empty():
			plan["has_effects"] = true
			cues.append(_pathing_pressure_cue(pathing_cells.size()))
			explanation_parts.append("%s pathing-pressure cells reshape viable routes around the hazardous water." % pathing_cells.size())

	plan["cues"] = cues
	plan["explanation"] = _join_strings(explanation_parts, " ")


# --- deterministic cell selection (PURE — same board -> identical cells; NO RNG) -------------------
# The placement predicates are FIXED functions of the board (eligible FLOOR cells partitioned by a positional parity),
# so the same board always yields the same cells (the AC2 determinism + the seed-reproducibility invariant). FAIRNESS:
# hazard/danger cells are only ever eligible FLOOR cells that are NOT occupied by an entity (an entity is never burned
# on its own spawn cell -> no unavoidable damage from an unseen/forced position; HAZARD stays seen + avoidable).

func _scorched_hazard_cells(board: BoardState) -> Array[Vector2i]:
	# Scorched fire-hazard cells: eligible cells on the EVEN parity ((x + y) even). A sparse, seen, avoidable hazard
	# pattern — bounded (never the whole floor), fair (leaves the odd-parity floor safe), deterministic.
	var result: Array[Vector2i] = []
	for cell: Vector2i in _eligible_effect_cells(board):
		if (cell.x + cell.y) % 2 == 0:
			result.append(cell)
	return result


func _flooded_conductive_cells(board: BoardState) -> Array[Vector2i]:
	# Conductive danger-zone cells: eligible cells on the EVEN parity (the "water" cells where current pools). DATA-only
	# (a deterministic mark surfaced in the preview; NOT terrain). Tracked MVP placeholder (AC4).
	var result: Array[Vector2i] = []
	for cell: Vector2i in _eligible_effect_cells(board):
		if (cell.x + cell.y) % 2 == 0:
			result.append(cell)
	return result


func _flooded_pathing_cells(board: BoardState) -> Array[Vector2i]:
	# Pathing-pressure cells: eligible cells on the ODD parity (the constrained dry lanes between the conductive water).
	# DATA-only (a deterministic mark surfaced in the preview; NOT terrain).
	var result: Array[Vector2i] = []
	for cell: Vector2i in _eligible_effect_cells(board):
		if (cell.x + cell.y) % 2 == 1:
			result.append(cell)
	return result


# The eligible base set: in-row-major order, every WALKABLE, sight-TRANSPARENT cell (FLOOR or already-HAZARD — the two
# terrains an affinity effect may apply to; HAZARD is included so the plan is IDEMPOTENT across apply_board_effects: a
# preview AFTER stamping reports the SAME cells as before, and re-applying is a no-op) that is NOT occupied by an entity.
# WALL/ENTRANCE/EXIT and entity-occupied cells are excluded (structure + fairness preserved — an entity is never burned
# on its own spawn cell). board.cells() returns a row-major-sorted copy, so the result order is deterministic.
func _eligible_effect_cells(board: BoardState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for board_cell: BoardCell in board.cells():
		if board_cell.terrain != BoardCell.Terrain.FLOOR and board_cell.terrain != BoardCell.Terrain.HAZARD:
			continue
		if board_cell.is_occupied():
			continue
		if board.entity_at(board_cell.position) != null:
			continue
		result.append(board_cell.position)
	return result


# --- marker reading (PURE) ------------------------------------------------------------------------

# Resolve the affinity's recorded tactical_rules marker ids into a presence set ({rule_id: true}). Reads through the
# 7.4 AffinityRepository.tactical_rules_for (the AC3 PURE-READ neutral query surface — returns the EMPTY set for the
# neutral `none` AND for an unknown/unassigned id, fail-SAFE). An empty/unresolved set yields an empty dictionary -> no
# effects (AC3). A null repository yields an empty set (defensive — the caller resolves through the fail-closed repo).
func _marker_ids_for(affinity_id: StringName, repository: AffinityRepository) -> Dictionary:
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


# --- cue builders (each carries a stable id + a non-color cue id + readable text; the accessibility mapping lives in
# TacticalAccessibilityModel._CUE_CATALOG keyed by the cue id) ------------------------------------

func _scorched_hazard_cue(cell_count: int) -> Dictionary:
	return {
		"id": CUE_SCORCHED_HAZARD,
		"cue_id": CUE_SCORCHED_HAZARD,
		"severity": "danger",
		"is_placeholder": false,
		"text": "Scorched fire hazard: %s cells deal burning damage if you linger; seen and avoidable." % cell_count
	}


func _conductive_danger_cue(cell_count: int) -> Dictionary:
	# AC4 — the conductive danger cue is a TRACKED MVP PLACEHOLDER: its cue id, visual id, and explanation are
	# DISTINCT-from-final (`_placeholder` marker) so the Epic-10 readiness pass can tell placeholder from final.
	return {
		"id": CUE_CONDUCTIVE_DANGER_PLACEHOLDER,
		"cue_id": CUE_CONDUCTIVE_DANGER_PLACEHOLDER,
		"visual_id": VISUAL_CONDUCTIVE_DANGER_PLACEHOLDER,
		"severity": "danger",
		"is_placeholder": true,
		"text": EXPLANATION_CONDUCTIVE_DANGER_PLACEHOLDER + " (%s cells)" % cell_count
	}


func _pathing_pressure_cue(cell_count: int) -> Dictionary:
	return {
		"id": CUE_PATHING_PRESSURE,
		"cue_id": CUE_PATHING_PRESSURE,
		"severity": "warning",
		"is_placeholder": false,
		"text": "Flooded pathing pressure: %s cells constrain viable routes around the water." % cell_count
	}


# --- helpers --------------------------------------------------------------------------------------

func _empty_plan(affinity_id: StringName) -> Dictionary:
	return {
		"affinity_id": String(affinity_id),
		"has_effects": false,
		"scorched_hazard_cells": [],
		"conductive_danger_cells": [],
		"pathing_pressure_cells": [],
		"cues": [] as Array[Dictionary],
		"explanation": ""
	}


func _serialize_cells(cells: Array[Vector2i]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cell: Vector2i in cells:
		result.append({"x": cell.x, "y": cell.y})
	return result


func _join_strings(parts: Array[String], separator: String) -> String:
	var result: String = ""
	for index: int in range(parts.size()):
		if index > 0:
			result += separator
		result += parts[index]
	return result
