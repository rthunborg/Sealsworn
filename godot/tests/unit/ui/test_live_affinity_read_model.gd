extends "res://tests/unit/test_case.gd"

# Story 11.4 (AC2) — LiveAffinityReadModel: the scene-free IN-RUN AFFINITY READ aggregation the on-screen HUD/inspect
# composes to surface the active affinity + its rule + its affected cells + its non-color cues (the sibling of the G1
# RunHudViewModel). It AGGREGATES the EXISTING read surfaces (AffinityViewModel + DarknessReadView + AffinityPreviewQuery)
# and REFLECTS the DarknessFairnessQuery verdict (never re-derives one). Covers:
#   - the EXACT pinned key contract (the present + absent projections carry the SAME set — a key never appears/vanishes).
#   - fail-closed neutral: a neutral `none` / unresolved id projects the legal empty read (has_affinity == false, an
#     empty-effect preview) — the HUD renders "no affinity", not a crash / half-badge.
#   - a Scorched read surfaces the affinity id/display-name/rule + the affected hazard cells + the non-color cue ids.
#   - a Darkness read surfaces the reduced-radius delta + memory-uncertainty + the 2 Darkness cue ids.
#   - the Darkness fairness verdict is REFLECTED verbatim (the AC3 single-authority — the model runs NO fairness of its
#     own).
#   - PURE: repeated reads are byte-identical; the returned dict is a fresh copy (no live handle leak).

const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const BoardCell = preload("res://scripts/tactical/board/board_cell.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CreateBoardCommand = preload("res://scripts/core/commands/create_board_command.gd")
const DarknessVisibilityLayer = preload("res://scripts/tactical/fog/darkness_visibility_layer.gd")
const LiveAffinityReadModel = preload("res://scripts/ui/view_models/live_affinity_read_model.gd")

func run() -> Dictionary:
	_present_and_absent_projections_share_the_exact_key_set()
	_neutral_is_the_fail_closed_empty_read()
	_scorched_read_surfaces_the_affinity_rule_and_affected_cells()
	_darkness_read_surfaces_the_reduced_radius_and_memory_uncertainty()
	_fairness_verdict_is_reflected_verbatim()
	_read_is_pure_and_returns_a_fresh_copy()
	return result()


# ---- the exact-key contract ----------------------------------------------------------------------

func _present_and_absent_projections_share_the_exact_key_set() -> void:
	var model: LiveAffinityReadModel = LiveAffinityReadModel.new(AffinityRepository.create_baseline_repository())
	var present: Dictionary = model.project(&"scorched", _combat_board())
	var absent: Dictionary = model.project(AffinityDefinition.AFFINITY_NONE)
	_assert_exact_keys(present, "a present (Scorched) read")
	_assert_exact_keys(absent, "an absent (neutral) read")
	assert_equal(present.keys().size(), LiveAffinityReadModel.DICTIONARY_KEYS.size(), "The present read has EXACTLY the pinned key count.")
	assert_equal(absent.keys().size(), LiveAffinityReadModel.DICTIONARY_KEYS.size(), "The absent read has EXACTLY the pinned key count.")


func _assert_exact_keys(projection: Dictionary, label: String) -> void:
	for key: String in LiveAffinityReadModel.DICTIONARY_KEYS:
		assert_true(projection.has(key), "%s must carry the pinned key `%s`." % [label, key])
	for key_value: Variant in projection.keys():
		assert_true(LiveAffinityReadModel.DICTIONARY_KEYS.has(String(key_value)), "%s must not carry the extra key `%s` (exact-key discipline)." % [label, key_value])


# ---- fail-closed neutral -------------------------------------------------------------------------

func _neutral_is_the_fail_closed_empty_read() -> void:
	var model: LiveAffinityReadModel = LiveAffinityReadModel.new(AffinityRepository.create_baseline_repository())
	# Neutral `none`: has_affinity false, is_neutral true, an empty-effect preview, no darkness, no cues.
	var neutral: Dictionary = model.project(AffinityDefinition.AFFINITY_NONE, _combat_board())
	assert_false(bool(neutral.get("has_affinity")), "A neutral `none` level reads has_affinity == false (the HUD renders `no affinity`).")
	assert_true(bool(neutral.get("is_neutral")), "A neutral `none` level reads is_neutral == true.")
	assert_false(bool((neutral.get("preview", {}) as Dictionary).get("has_effects")), "A neutral level has an empty-effect preview (no affected cells).")
	assert_false(bool((neutral.get("darkness", {}) as Dictionary).get("has_darkness")), "A neutral level has no Darkness read.")
	assert_equal((neutral.get("cue_ids", []) as Array).size(), 0, "A neutral level surfaces no cue ids.")

	# An UNRESOLVED id (never in the repo) is also fail-closed (has_affinity false), not a crash / half-badge.
	var unknown: Dictionary = model.project(&"not_a_real_affinity", _combat_board())
	assert_false(bool(unknown.get("has_affinity")), "An unresolved affinity id is fail-closed (has_affinity == false).")
	_assert_exact_keys(unknown, "an unresolved-id read")


# ---- Scorched read -------------------------------------------------------------------------------

func _scorched_read_surfaces_the_affinity_rule_and_affected_cells() -> void:
	var model: LiveAffinityReadModel = LiveAffinityReadModel.new(AffinityRepository.create_baseline_repository())
	var scorched: Dictionary = model.project(&"scorched", _combat_board())
	assert_true(bool(scorched.get("has_affinity")), "A Scorched level reads has_affinity == true.")
	assert_false(bool(scorched.get("is_neutral")), "A Scorched level is NOT neutral.")
	assert_equal(String(scorched.get("affinity_id")), "scorched", "The read surfaces the affinity id.")
	assert_false(String(scorched.get("display_name")).is_empty(), "The read surfaces the affinity display-name (the badge label).")
	assert_true((scorched.get("tactical_rules", []) as Array).size() >= 1, "The read surfaces the RECORD-ONLY tactical rule(s).")
	assert_true((scorched.get("visual_tags", []) as Array).size() >= 1, "The read surfaces the visual_tags (the treatment art/cue hooks).")
	# The affected cells + cues (the board/inspect "which cells" read).
	var preview: Dictionary = scorched.get("preview", {})
	assert_true(bool(preview.get("has_effects")), "A Scorched preview has effects (affected cells).")
	assert_true((preview.get("hazard_cells", []) as Array).size() >= 1, "The Scorched preview surfaces the affected hazard cells.")
	assert_true((scorched.get("cue_ids", []) as Array).has(DarknessVisibilityLayer.STATE_HIDDEN) == false, "Sanity: the Scorched cue set is the affinity cues, not a visibility state.")
	assert_true((scorched.get("cue_ids", []) as Array).has("affinity_scorched_hazard"), "The read surfaces the Scorched hazard non-color cue id (color-independent danger).")


# ---- Darkness read -------------------------------------------------------------------------------

func _darkness_read_surfaces_the_reduced_radius_and_memory_uncertainty() -> void:
	var model: LiveAffinityReadModel = LiveAffinityReadModel.new(AffinityRepository.create_baseline_repository())
	var darkness: Dictionary = model.project(&"darkness", _combat_board())
	# Darkness has NO hazard cells (its effect is visibility/memory) but IS a non-neutral affinity with a rule + read.
	assert_true(bool(darkness.get("has_affinity")), "A Darkness level reads has_affinity == true.")
	var read: Dictionary = darkness.get("darkness", {})
	assert_true(bool(read.get("has_darkness")), "The Darkness read surfaces has_darkness == true.")
	assert_equal(int(read.get("reduced_radius")), DarknessVisibilityLayer.DARKNESS_REDUCED_LINE_OF_SIGHT_RADIUS, "The read surfaces the reduced LoS radius (2).")
	assert_true(int(read.get("baseline_radius")) > int(read.get("reduced_radius")), "The read surfaces the reduced radius as a delta from the baseline.")
	assert_true(bool(read.get("memory_uncertain")), "The read surfaces the memory-uncertainty state.")
	# The 2 FINAL Darkness cue ids surface in the aggregated cue set (non-color channels).
	var cue_ids: Array = darkness.get("cue_ids", [])
	assert_true(cue_ids.has(DarknessVisibilityLayer.CUE_DARKNESS_REDUCED_VISIBILITY), "The read surfaces the Darkness reduced-visibility cue id.")
	assert_true(cue_ids.has(DarknessVisibilityLayer.CUE_DARKNESS_MEMORY_UNCERTAIN), "The read surfaces the Darkness memory-uncertain cue id.")


# ---- AC3: the fairness verdict is reflected -------------------------------------------------------

func _fairness_verdict_is_reflected_verbatim() -> void:
	var model: LiveAffinityReadModel = LiveAffinityReadModel.new(AffinityRepository.create_baseline_repository())
	# The model REFLECTS the DarknessFairnessQuery verdict passed to it (it runs no fairness of its own — AC3 single
	# authority). Pass a representative pass report + assert it surfaces verbatim under `fairness`.
	var verdict: Dictionary = {
		"darkness_fairness_applicable": true,
		"reduced_radius": 2,
		"hazard_count": 0,
		"reachable_seen_hazard_count": 0
	}
	var projected: Dictionary = model.project(&"darkness", _combat_board(), verdict)
	assert_equal(projected.get("fairness"), verdict, "The DarknessFairnessQuery verdict is REFLECTED verbatim under `fairness` (never re-derived).")
	# No verdict passed -> an empty fairness read (the fail-closed default).
	var no_verdict: Dictionary = model.project(&"darkness", _combat_board())
	assert_true((no_verdict.get("fairness", {}) as Dictionary).is_empty(), "With no verdict passed, `fairness` is the empty read (fail-closed).")


# ---- purity --------------------------------------------------------------------------------------

func _read_is_pure_and_returns_a_fresh_copy() -> void:
	var model: LiveAffinityReadModel = LiveAffinityReadModel.new(AffinityRepository.create_baseline_repository())
	var board: BoardState = _combat_board()
	var first: Dictionary = model.project(&"scorched", board)
	var second: Dictionary = model.project(&"scorched", board)
	assert_equal(first, second, "Repeated reads of the same inputs are byte-identical (PURE).")
	# Mutating the returned dict does not perturb a fresh read (a fresh copy each call — no live handle leak).
	(first.get("tactical_rules", []) as Array).clear()
	(first.get("cue_ids", []) as Array).clear()
	var third: Dictionary = model.project(&"scorched", board)
	assert_true((third.get("tactical_rules", []) as Array).size() >= 1, "A mutation of a returned field does not perturb a fresh read (fresh copy each call).")
	assert_true((third.get("cue_ids", []) as Array).size() >= 1, "The cue_ids are a fresh copy each call.")


# ---- helpers -------------------------------------------------------------------------------------

# A small all-FLOOR board (through CreateBoardCommand so the shape is the real BoardState) for the preview reads.
func _combat_board() -> BoardState:
	var board: BoardState = BoardState.new()
	var create: Variant = CreateBoardCommand.new(6, 6).execute(board)
	assert_true(create.succeeded, "Setup: the preview board should build.")
	return board
