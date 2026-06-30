extends "res://tests/unit/test_case.gd"

# Story 7.6 Task 5 (AC1 "according to definition", AC2) — the scene-free DARKNESS READ / EXPLAINABILITY surface. These
# prove DarknessReadView is the PURE, explainable, exact-key Darkness read (the AffinityViewModel / 7.5
# AffinityPreviewQuery posture):
#   - EXPLAINABLE (AC1): a Darkness level surfaces the reduced radius + the baseline radius + memory_uncertain + the
#     readable honest explanation + the non-color cue ids.
#   - NEUTRAL / non-Darkness: a legal NO-DARKNESS-EFFECT read (the SAME MODAL_KEYS set, has_darkness == false, the
#     reduced radius == baseline, memory_uncertain == false, EMPTY cue_ids) — a valid readable answer.
#   - EXACT KEYS: every projection has the EXACT MODAL_KEYS set (a key never silently appears/vanishes).
#   - PURE: repeated reads are byte-identical; the read draws no RNG, mutates nothing, emits no events.
#   - NON-COLOR (AC2): every cue id the Darkness read surfaces has a non-color accessibility mapping.
#   - It is its OWN surface (NOT routed through AffinityPreviewQuery — the hazard preview; Darkness has no hazard cells).

const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const DarknessReadView = preload("res://scripts/ui/view_models/darkness_read_view.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const TacticalAccessibilityModel = preload("res://scripts/ui/view_models/tactical_accessibility_model.gd")
const TacticalVisibilityQuery = preload("res://scripts/tactical/fog/tactical_visibility_query.gd")

func run() -> Dictionary:
	_darkness_read_is_explainable()
	_darkness_read_surfaces_non_color_cues()
	_neutral_and_non_darkness_read_is_a_legal_no_effect_answer()
	_every_projection_has_the_exact_modal_keys()
	_read_is_pure_repeated_reads_identical()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _view() -> DarknessReadView:
	return DarknessReadView.new(AffinityRepository.create_baseline_repository())


func _sorted_keys(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key: Variant in data.keys():
		result.append(String(key))
	result.sort()
	return result


# ---- explainability (AC1) ------------------------------------------------------------------------

func _darkness_read_is_explainable() -> void:
	var modal: Dictionary = _view().project_darkness(&"darkness")
	assert_equal(modal.get("has_darkness"), true, "AC1: the Darkness read reports the Darkness effect is present.")
	assert_equal(String(modal.get("affinity_id")), "darkness", "AC1: the read identifies the affinity.")
	assert_equal(int(modal.get("baseline_radius")), TacticalVisibilityQuery.DEFAULT_LINE_OF_SIGHT_RADIUS, "AC1: the read surfaces the baseline radius (so the reduction is readable as a delta).")
	assert_true(int(modal.get("reduced_radius")) < int(modal.get("baseline_radius")), "AC1: the read surfaces the reduced radius (below baseline).")
	assert_true(int(modal.get("reduced_radius")) >= DarknessVisibilityLayer.DARKNESS_RADIUS_FLOOR, "AC1: the reduced radius respects the fairness floor.")
	assert_equal(modal.get("memory_uncertain"), true, "AC2: the read surfaces the memory-uncertainty state.")
	assert_false(String(modal.get("explanation", "")).is_empty(), "AC1: the read surfaces a readable explanation.")
	# The explanation carries the honest GDD-guardrail language (uncertainty, not an unavoidable ambush).
	var explanation: String = String(modal.get("explanation"))
	assert_true(explanation.to_lower().contains("unavoidable"), "AC1: the explanation carries the honest 'no unavoidable damage' guardrail language.")


func _darkness_read_surfaces_non_color_cues() -> void:
	var modal: Dictionary = _view().project_darkness(&"darkness")
	var cue_ids: Array = modal.get("cue_ids", [])
	assert_false(cue_ids.is_empty(), "AC1: the Darkness read surfaces at least one cue id.")
	for cue_id_value: Variant in cue_ids:
		assert_true(TacticalAccessibilityModel.has_non_color_channel(String(cue_id_value)), "AC2: the Darkness read cue '%s' must have a non-color accessibility mapping." % String(cue_id_value))
	assert_true(cue_ids.has(DarknessVisibilityLayer.CUE_DARKNESS_REDUCED_VISIBILITY), "The read surfaces the reduced-visibility cue.")
	assert_true(cue_ids.has(DarknessVisibilityLayer.CUE_DARKNESS_MEMORY_UNCERTAIN), "The read surfaces the memory-uncertainty cue.")


# ---- neutral / non-Darkness ----------------------------------------------------------------------

func _neutral_and_non_darkness_read_is_a_legal_no_effect_answer() -> void:
	for affinity_id: StringName in [AffinityDefinition.AFFINITY_NONE, &"scorched", &"flooded_conductive", &"cursed", &"unknown_id"]:
		var modal: Dictionary = _view().project_darkness(affinity_id)
		assert_equal(modal.get("has_darkness"), false, "%s: the read reports NO Darkness effect." % String(affinity_id))
		assert_equal(int(modal.get("reduced_radius")), int(modal.get("baseline_radius")), "%s: no reduction (reduced == baseline)." % String(affinity_id))
		assert_equal(modal.get("memory_uncertain"), false, "%s: no memory uncertainty." % String(affinity_id))
		assert_true((modal.get("cue_ids", []) as Array).is_empty(), "%s: no Darkness cue ids." % String(affinity_id))
		assert_false(String(modal.get("explanation", "")).is_empty(), "%s: still a readable (neutral) explanation." % String(affinity_id))


# ---- exact keys ----------------------------------------------------------------------------------

func _every_projection_has_the_exact_modal_keys() -> void:
	var expected: Array[String] = DarknessReadView.MODAL_KEYS.duplicate()
	expected.sort()
	for affinity_id: StringName in [&"darkness", AffinityDefinition.AFFINITY_NONE, &"scorched", &"unknown_id"]:
		var modal: Dictionary = _view().project_darkness(affinity_id)
		assert_equal(_sorted_keys(modal), expected, "%s: the projection has the EXACT MODAL_KEYS set (a key never silently appears/vanishes)." % String(affinity_id))


# ---- purity --------------------------------------------------------------------------------------

func _read_is_pure_repeated_reads_identical() -> void:
	var view: DarknessReadView = _view()
	var first: Dictionary = view.project_darkness(&"darkness")
	var second: Dictionary = view.project_darkness(&"darkness")
	assert_equal(first, second, "AC1: repeated Darkness reads are byte-identical (the read is pure).")
	# Mutating a returned copy must not affect a fresh read (no shared references leak out).
	first["reduced_radius"] = 99
	(first.get("cue_ids", []) as Array).clear()
	var third: Dictionary = view.project_darkness(&"darkness")
	assert_equal(int(third.get("reduced_radius")), DarknessVisibilityLayer.DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS, "The read returns fresh data (a mutated copy does not corrupt a later read).")
	assert_false((third.get("cue_ids", []) as Array).is_empty(), "The read returns fresh cue ids each call.")
