class_name DarknessReadView
extends RefCounted

# Story 7.6 (AC1 "according to definition", AC2 explainability) — the scene-free DARKNESS READ / EXPLAINABILITY surface.
# It is the thin presentation contract the (future) affinity badge / inspect-panel SCENE reads to communicate a Darkness
# level's effect: the reduced LoS radius, the memory-uncertainty state, the readable honest explanation (the GDD
# guardrail language — "reduced visibility + uncertain memory create uncertainty, never an unavoidable ambush"), and the
# non-color cue id(s).
#
# It is the direct sibling of AffinityViewModel (7.4) / the 7.5 AffinityPreviewQuery neutral posture: same scene-free
# RefCounted DTO, same EXACT pinned key contract (MODAL_KEYS — a key never silently appears/vanishes), same fail-closed
# discipline. It is the Darkness-specific read; it is DELIBERATELY NOT routed through AffinityPreviewQuery.preview_board
# (that is the HAZARD-cell preview — Darkness has NO hazard cells, and the existing test_affinity_preview_query.gd
# darkness branch MUST stay green). Darkness's read is its own surface.
#
# WHAT IT IS:
#   - project_darkness(affinity_id) -> a Dictionary keyed by MODAL_KEYS surfacing, for a Darkness level: has_darkness ==
#     true, the reduced_radius (the AUTHORED bounded LoS reduction), the baseline_radius (FR5 4 — so the reduction is
#     readable as a delta), memory_uncertain == true (fog_memory_pressure surfaces stale/uncertain memory), the readable
#     explanation, and the cue_ids (the two FINAL non-color Darkness cue ids).
#   - For NEUTRAL `none` / Scorched / Flooded / Cursed / unknown / unassigned -> the legal NO-DARKNESS-EFFECT projection:
#     the SAME MODAL_KEYS set, has_darkness == false, reduced_radius == baseline_radius (no reduction), memory_uncertain
#     == false, EMPTY cue_ids, and a neutral explanation. A valid, readable answer (the 7.5 AffinityPreviewQuery neutral
#     posture — "no Darkness pressure to show" is itself a legal result), NEVER a crash, NEVER a half-entry.
#
# WHAT IT IS NOT:
#   - It owns NO domain truth, submits NO command, draws ZERO RNG, and mutates NOTHING — a PURE read (repeated reads are
#     byte-identical, the 7.5 AffinityPreviewQuery contract). It does NOT APPLY the Darkness effect (the reduced radius is
#     applied via DarknessVisibilityLayer.calculate_visible_cells; the fairness check is DarknessFairnessQuery) — this
#     surface only DESCRIBES it.
#   - It is a RefCounted DTO — NOT a Control, NOT a Node, NOT a .tscn / scene / presenter / shader (UI-scene-last; the
#     real affinity badge + the darkness VFX/lighting are a later HUD/asset story). This is the data contract.

const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")

# The EXACT top-level key set of every projection (the MODAL_KEYS exact-key discipline — the AffinityViewModel /
# CursedRewardViewModel precedent; a test pins this). has_darkness gates whether the Darkness fields are meaningful.
const MODAL_KEYS: Array[String] = [
	"has_darkness",
	"affinity_id",
	"baseline_radius",
	"reduced_radius",
	"memory_uncertain",
	"explanation",
	"cue_ids"
]

# The honest GDD-guardrail explanation for a Darkness level (the AC1 "according to definition" + the GDD lines 507-512
# fairness language). Surfaced verbatim so the HUD/inspect surface communicates the uncertainty-not-ambush guarantee.
const DARKNESS_EXPLANATION := "Darkness: reduced visibility shrinks how far you can see and your explored memory grows uncertain — stay cautious and scout. It creates uncertainty, never an unavoidable ambush: no unseen space deals you unavoidable damage."
const NEUTRAL_EXPLANATION := "This level carries no Darkness effect: line of sight and explored memory are at their baseline reliability."

var _affinity_repository: AffinityRepository = null
var _layer: DarknessVisibilityLayer = null

func _init(new_affinity_repository: AffinityRepository = null) -> void:
	# Default to the baseline affinity repository (the AffinityViewModel injection posture; tests inject a fixture repo).
	_affinity_repository = new_affinity_repository if new_affinity_repository != null else AffinityRepository.create_baseline_repository()
	_layer = DarknessVisibilityLayer.new()


# Project a level's assigned affinity id into the EXACT-MODAL_KEYS Darkness read. A Darkness level surfaces the reduced
# radius + memory uncertainty + explanation + cue ids; any non-Darkness id projects the legal no-Darkness-effect modal
# (fail-closed). PURE read: no RNG, no mutation, no events; repeated reads are identical.
func project_darkness(affinity_id: StringName) -> Dictionary:
	var baseline_radius: int = TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS
	if not _layer.is_darkness(affinity_id, _affinity_repository):
		return _no_darkness_modal(affinity_id, baseline_radius)

	return {
		"has_darkness": true,
		"affinity_id": String(affinity_id),
		"baseline_radius": baseline_radius,
		"reduced_radius": _layer.reduced_radius_for(affinity_id, _affinity_repository, baseline_radius),
		"memory_uncertain": true,
		"explanation": DARKNESS_EXPLANATION,
		"cue_ids": [
			DarknessVisibilityLayer.CUE_DARKNESS_REDUCED_VISIBILITY,
			DarknessVisibilityLayer.CUE_DARKNESS_MEMORY_UNCERTAIN
		]
	}


# The legal NO-DARKNESS-EFFECT projection (neutral / Scorched / Flooded / Cursed / unknown / unassigned): the SAME
# MODAL_KEYS set, has_darkness == false, the reduced radius EQUAL to the baseline (no reduction), memory_uncertain ==
# false, EMPTY cue_ids, a neutral explanation. A valid readable answer, NEVER a crash.
func _no_darkness_modal(affinity_id: StringName, baseline_radius: int) -> Dictionary:
	return {
		"has_darkness": false,
		"affinity_id": String(affinity_id),
		"baseline_radius": baseline_radius,
		"reduced_radius": baseline_radius,
		"memory_uncertain": false,
		"explanation": NEUTRAL_EXPLANATION,
		"cue_ids": []
	}
