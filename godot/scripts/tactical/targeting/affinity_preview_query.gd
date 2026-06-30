class_name AffinityPreviewQuery
extends RefCounted

# Story 7.5 (AC1 "explainable in previews", AC2 "critical danger information is not color-only") — the affinity-aware
# PREVIEW surface: a sibling to AttackPreviewQuery that, GIVEN a built BoardState + a level's assigned affinity id,
# returns the affinity-affected cells (Scorched hazard cells, Flooded conductive danger-zone + pathing-pressure cells)
# + their NON-COLOR cues + a readable explanation, so the player can READ the affinity's tactical pressure BEFORE
# committing a move.
#
# WHY A SIBLING (not threaded into AttackPreviewQuery): AttackPreviewQuery.preview_target_cell answers "can THIS weapon
# hit THIS target cell" (it requires a live aligned/visible attack target). The affinity preview answers a different
# question — "what affinity hazards/danger zones are on this board" — which is board-wide, target-independent. Keeping
# it a separate pure query leaves the weapon-attack preview's existing contract byte-stable (no regression to the Epic-1
# attack-preview surface) while adding the affinity explainability AC1 demands.
#
# IT IS PURE (the Epic-1 attack-preview contract — "repeated previews from the same snapshot return the same result"):
# NO mutation (it does NOT stamp hazards — it reads the SAME deterministic plan AffinityEffectResolver.resolve_board_plan
# produces, so the preview can never disagree with the applied effect), NO RNG, NO events. The accessibility mapping for
# each cue lives in TacticalAccessibilityModel._CUE_CATALOG (keyed by cue_id), the canonical color-independence audit
# driver — every affinity cue carries a non-color (shape/icon/label/pattern/text) channel there (AC2).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AffinityEffectResolver = preload("res://scripts/rules/operations/affinity_effect_resolver.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")

# Build the affinity preview for a board + assigned affinity id. Returns a structured ActionResult (succeeded) whose
# metadata carries the affinity-affected cells + the non-color cues + the explanation. A null/empty board is the only
# error path (a real board with a neutral/unknown/Cursed/Darkness affinity returns a legal, EMPTY-effect preview — there
# is no affinity pressure to show, which is itself a valid, readable answer).
func preview_board(board: BoardState, affinity_id: StringName, repository: AffinityRepository) -> ActionResult:
	if board == null or not board.has_cells():
		return ActionResult.error(&"invalid_affinity_preview", {
			"reason": "invalid_board",
			"affinity_id": String(affinity_id)
		})

	var plan: Dictionary = AffinityEffectResolver.new().resolve_board_plan(board, affinity_id, repository)
	var warnings: Array[Dictionary] = _warning_entries(plan)
	var cues: Array[Dictionary] = _cue_entries(plan)

	return ActionResult.ok([], {
		"kind": "affinity_preview",
		"affinity_id": String(affinity_id),
		"has_effects": bool(plan.get("has_effects", false)),
		"hazard_cells": _copy_cells(plan.get("scorched_hazard_cells", [])),
		"conductive_danger_cells": _copy_cells(plan.get("conductive_danger_cells", [])),
		"pathing_pressure_cells": _copy_cells(plan.get("pathing_pressure_cells", [])),
		"warnings": warnings,
		"cues": cues,
		"cue_ids": _cue_ids(cues),
		"explanation": String(plan.get("explanation", ""))
	})


# The danger/warning entries (the AttackPreviewQuery.warnings shape — {id, text}) derived from the plan's cues. A
# preview WARNING surfaces each affinity danger readably BEFORE commitment.
func _warning_entries(plan: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cue_value: Variant in plan.get("cues", []):
		if not cue_value is Dictionary:
			continue
		var cue: Dictionary = cue_value
		result.append({
			"id": String(cue.get("id", "")),
			"text": String(cue.get("text", ""))
		})
	return result


# The full cue entries (carry the cue_id used to look up the non-color accessibility channel, the severity, the
# placeholder flag, and the readable text). Copied so the caller can never mutate the plan's cue dictionaries.
func _cue_entries(plan: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cue_value: Variant in plan.get("cues", []):
		if not cue_value is Dictionary:
			continue
		result.append((cue_value as Dictionary).duplicate(true))
	return result


func _cue_ids(cues: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for cue: Dictionary in cues:
		var cue_id: String = String(cue.get("cue_id", ""))
		if not cue_id.is_empty():
			result.append(cue_id)
	return result


func _copy_cells(cells: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not cells is Array:
		return result
	for cell_value: Variant in (cells as Array):
		if cell_value is Dictionary:
			result.append((cell_value as Dictionary).duplicate(true))
	return result
