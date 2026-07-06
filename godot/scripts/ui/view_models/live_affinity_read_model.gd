class_name LiveAffinityReadModel
extends RefCounted

# Story 11.4 (AC2 — the on-screen affinity read + treatment) — the scene-free IN-RUN AFFINITY READ aggregation. It is
# the thin fail-closed RefCounted READ surface the in-run HUD / inspect flow composes ALONGSIDE the TacticalBoardViewModel
# (the region -> slot map) to surface the ACTIVE affinity + its rule + its affected cells + its non-color cues on the
# on-screen board — the sibling of the G1 RunHudViewModel (11.3), same posture. It AGGREGATES the EXISTING per-affinity
# read surfaces (it does NOT re-implement or fork them):
#   - AffinityViewModel.project_affinity(id) -> the affinity id / display_name / explanation / is_neutral /
#     tactical_rules (RECORD-ONLY) / visual_tags (the art/cue hooks the treatment binds) — the "what affinity + its rule"
#     read (FR55, "visible before and during play").
#   - DarknessReadView.project_darkness(id) -> the reduced_radius / baseline_radius delta / memory_uncertain / the 2
#     FINAL Darkness cue ids — the Darkness visibility/memory pressure read (FR58).
#   - AffinityPreviewQuery.preview_board(board, id, repo) -> the affinity-affected cells (Scorched hazard cells / Flooded
#     conductive-danger + pathing-pressure marks) + their non-color cues + the readable explanation — the "which cells"
#     read the board/inspect surfaces (FR12/FR58 telegraphed danger). The board is OPTIONAL (between-levels there is no
#     live board, so the preview is the legal empty-effect read).
#
# ⭐ THE DARKNESS FAIRNESS VERDICT IS REFLECTED, NEVER RE-DERIVED (AC3 second half — the single-authority contract): the
# caller passes the DarknessFairnessQuery verdict metadata (the pass report's reduced_radius + hazard counts, or a
# failure's fairness_reason) and this model SURFACES it verbatim under `fairness`. It runs NO fairness reasoning of its
# own (it does not construct a DarknessFairnessQuery) — the query stays the single authority the HUD reflects.
#
# ⭐ IT IS A PURE READ. It mints NO event, consumes NO RNG (ZERO randi/randf/RandomNumberGenerator), mutates NOTHING (not
# the board, not the run, not any content), and leaks NO live handle (a FRESH plain-data dictionary each call — a
# mutation of a returned field never perturbs the source). It is a RefCounted DTO — NOT a Control/Node/scene. It mirrors
# the RunHudViewModel / RunEndOutcome exact-key + fail-closed + no-live-handle projection discipline VERBATIM. The
# `.tscn` affinity render/treatment is verified BY CONSTRUCTION + a code audit (it reads this model + submits nothing).
#
# ⭐ FAIL-CLOSED: a neutral `none` level (or an unresolved affinity id) surfaces the legal empty read (has_affinity ==
# false / has_darkness == false / an empty-effect preview / an empty fairness verdict) so the HUD renders "no affinity"
# rather than a crash or a half-badge. The pinned key set is IDENTICAL for the present and absent projections (a key
# never silently appears/vanishes) — the AffinityViewModel / DarknessReadView / RunHudViewModel exact-key discipline.

const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const AffinityViewModel = preload("res://scripts/ui/view_models/affinity_view_model.gd")
const AffinityPreviewQuery = preload("res://scripts/tactical/targeting/affinity_preview_query.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const DarknessReadView = preload("res://scripts/ui/view_models/darkness_read_view.gd")

# The EXACT top-level key set (pinned by test — the RunHudViewModel.DICTIONARY_KEYS exact-key discipline). A key never
# silently appears/vanishes; the present and absent projections carry the SAME set. has_affinity gates whether the
# affinity fields are meaningful; is_neutral surfaces the no-affinity case; has_effects gates the preview cells.
const DICTIONARY_KEYS: Array[String] = [
	"has_affinity",
	"is_neutral",
	"affinity_id",
	"display_name",
	"explanation",
	"tactical_rules",
	"visual_tags",
	"darkness",
	"preview",
	"cue_ids",
	"fairness"
]

var _affinity_repository: AffinityRepository = null
var _affinity_view_model: AffinityViewModel = null
var _darkness_read_view: DarknessReadView = null

func _init(new_affinity_repository: AffinityRepository = null) -> void:
	# Default to the baseline affinity repository (the RunHudViewModel / AffinityViewModel injection posture; tests inject
	# a fixture repository). Share the ONE repository across the composed read surfaces (never build a second baseline).
	_affinity_repository = new_affinity_repository if new_affinity_repository != null else AffinityRepository.create_baseline_repository()
	_affinity_view_model = AffinityViewModel.new(_affinity_repository)
	_darkness_read_view = DarknessReadView.new(_affinity_repository)


# Project the active affinity read from (affinity_id, the OPTIONAL live board, the OPTIONAL fairness verdict). `board` is
# the live BoardState during a fight (so the preview surfaces the affected cells) — null between levels (the legal empty
# preview). `fairness_verdict` is the DarknessFairnessQuery verdict metadata (reflected verbatim under `fairness`; empty
# when there is none). A neutral / unresolved id projects the fail-closed empty read. PURE: no RNG, no mutation.
func project(affinity_id: StringName, board: BoardState = null, fairness_verdict: Dictionary = {}) -> Dictionary:
	var affinity: Dictionary = _affinity_view_model.project_affinity(affinity_id)
	var darkness: Dictionary = _darkness_read_view.project_darkness(affinity_id)
	var preview: Dictionary = _preview(affinity_id, board)

	# The union of every non-color cue id the affinity surfaces (the preview cues + the Darkness cues) — the single
	# non-color-channel list the HUD/inspect binds (each id maps to a TacticalAccessibilityModel._CUE_CATALOG channel).
	var cue_ids: Array[String] = []
	for cue_id_value: Variant in preview.get("cue_ids", []):
		var cue_id: String = String(cue_id_value)
		if not cue_id.is_empty() and not cue_ids.has(cue_id):
			cue_ids.append(cue_id)
	for cue_id_value: Variant in darkness.get("cue_ids", []):
		var cue_id: String = String(cue_id_value)
		if not cue_id.is_empty() and not cue_ids.has(cue_id):
			cue_ids.append(cue_id)

	return {
		"has_affinity": bool(affinity.get("has_affinity", false)) and not bool(affinity.get("is_neutral", false)),
		"is_neutral": bool(affinity.get("is_neutral", false)),
		"affinity_id": String(affinity.get("affinity_id", "")),
		"display_name": String(affinity.get("display_name", "")),
		"explanation": String(affinity.get("explanation", "")),
		# RECORD-ONLY tactical rule data (a FRESH copy — no live handle leaks; a mutation never perturbs the source VM).
		"tactical_rules": _copy_dict_list(affinity.get("tactical_rules", [])),
		"visual_tags": _copy_string_list(affinity.get("visual_tags", [])),
		# The Darkness read (reduced/baseline radius delta + memory uncertainty + the 2 cue ids) — a FRESH copy.
		"darkness": darkness.duplicate(true),
		# The affinity-affected cells + cues + explanation (the "which cells" board/inspect read) — a FRESH copy.
		"preview": preview.duplicate(true),
		"cue_ids": cue_ids,
		# The DarknessFairnessQuery verdict REFLECTED verbatim (AC3 single-authority — never re-derived here) — FRESH copy.
		"fairness": fairness_verdict.duplicate(true)
	}


# The affinity-affected-cells preview. With a live board, reads AffinityPreviewQuery.preview_board (the SAME resolver
# plan the applied effect consumes — the preview can never disagree). Without a board (between levels) OR on a preview
# error, returns the legal empty-effect preview (has_effects == false, empty cell lists) — the fail-closed read.
func _preview(affinity_id: StringName, board: BoardState) -> Dictionary:
	if board == null or not board.has_cells():
		return _empty_preview(affinity_id)
	var preview_result = AffinityPreviewQuery.new().preview_board(board, affinity_id, _affinity_repository)
	if preview_result.is_error():
		return _empty_preview(affinity_id)
	return {
		"has_effects": bool(preview_result.metadata.get("has_effects", false)),
		"hazard_cells": _copy_dict_list(preview_result.metadata.get("hazard_cells", [])),
		"conductive_danger_cells": _copy_dict_list(preview_result.metadata.get("conductive_danger_cells", [])),
		"pathing_pressure_cells": _copy_dict_list(preview_result.metadata.get("pathing_pressure_cells", [])),
		"cues": _copy_dict_list(preview_result.metadata.get("cues", [])),
		"cue_ids": _copy_string_list(preview_result.metadata.get("cue_ids", [])),
		"explanation": String(preview_result.metadata.get("explanation", ""))
	}


func _empty_preview(affinity_id: StringName) -> Dictionary:
	return {
		"has_effects": false,
		"hazard_cells": [],
		"conductive_danger_cells": [],
		"pathing_pressure_cells": [],
		"cues": [],
		"cue_ids": [],
		"explanation": ""
	}


func _copy_dict_list(values: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not values is Array:
		return result
	for value: Variant in (values as Array):
		if value is Dictionary:
			result.append((value as Dictionary).duplicate(true))
	return result


func _copy_string_list(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if not values is Array:
		return result
	for value: Variant in (values as Array):
		result.append(String(value))
	return result
