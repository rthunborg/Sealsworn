extends "res://tests/unit/test_case.gd"

# Story 9.2 Task 1 — BossDefinition + BossPhaseDefinition + BossActionDefinition (the typed, validated Larval Avatar
# BOSS content definition, AC1). Covers the AC1 content contract: a valid boss validates; each top-level per-field
# reject (bad boss_id, max_hp <= 0, < 2 phases, blank explanation); the STRUCTURAL threshold cross-rules (phase 0 must
# be 100, thresholds must strictly decrease); each per-PHASE reject surfaced with the phase index (bad phase_id,
# out-of-band threshold, empty actions, duplicate action id, blank phase explanation); each per-ACTION reject surfaced
# with the phase + action index (bad action_id, blank telegraph, negative damage, bad damage_type, blank action
# explanation); the accessors (phase_count/get_phase/phase_ids/legal_action_ids/phase_threshold_percent). Mirrors
# test_event_definition.gd (the typed-Resource validate() per-field shape).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BossActionDefinition = preload("res://scripts/content/definitions/boss_action_definition.gd")
const BossPhaseDefinition = preload("res://scripts/content/definitions/boss_phase_definition.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossRepository = preload("res://scripts/content/repositories/boss_repository.gd")

func run() -> Dictionary:
	_a_valid_boss_validates()
	_rejects_a_non_lower_snake_boss_id()
	_rejects_non_positive_max_hp()
	_rejects_fewer_than_two_phases()
	_rejects_a_blank_boss_explanation()
	_rejects_phase_zero_threshold_not_100()
	_rejects_non_strictly_decreasing_thresholds()
	_rejects_duplicate_thresholds()
	_rejects_a_duplicate_phase_id()
	_rejects_per_phase_bad_phase_id()
	_rejects_per_phase_out_of_band_threshold()
	_rejects_per_phase_empty_actions()
	_rejects_per_phase_null_phase()
	_rejects_per_action_bad_action_id()
	_rejects_per_action_blank_telegraph()
	_rejects_per_action_negative_damage()
	_rejects_per_action_blank_explanation()
	_rejects_per_phase_duplicate_action_id()
	_action_validates_and_rejects_per_field()
	_accessors_resolve()
	_legal_action_sets_are_phase_dependent()
	_baseline_boss_phase_action_sets_are_queryable_and_differ()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _action(action_id: StringName, damage: int = 6) -> BossActionDefinition:
	return BossActionDefinition.new(action_id, "It rears back to strike.", damage, &"physical", "Deals %d damage to the adjacent hero." % damage)


func _phase(phase_id: StringName, threshold: int, actions: Array = []) -> BossPhaseDefinition:
	var phase_actions: Array = actions
	if phase_actions.is_empty():
		phase_actions = [_action(StringName("%s_strike" % String(phase_id)))]
	return BossPhaseDefinition.new(phase_id, threshold, phase_actions, "The boss behaves in a readable way this phase.")


# A fully valid two-phase Larval Avatar. Mutate one field per reject test.
func _valid_definition() -> BossDefinition:
	return BossDefinition.new(
		BossDefinition.BOSS_ID,
		30,
		[
			_phase(&"emergence", 100, [_action(&"lash", 6), _action(&"skitter", 0)]),
			_phase(&"frenzy", 50, [_action(&"lash", 8), _action(&"corrupt", 10)])
		],
		"The Larval Avatar tests everything the run taught the hero."
	)


# ---- valid + top-level rejects -------------------------------------------------------------------

func _a_valid_boss_validates() -> void:
	var boss: BossDefinition = _valid_definition()
	var validation: ActionResult = boss.validate()
	assert_true(validation.succeeded, "A well-formed Larval Avatar should validate.")
	assert_equal(boss.phase_count(), 2, "The valid boss should report 2 phases.")


func _rejects_a_non_lower_snake_boss_id() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.boss_id = &"Larval Avatar"
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A non-lower_snake boss_id should be rejected.")
	assert_equal(validation.error_code, &"invalid_boss_definition", "A bad boss uses the stable code.")
	assert_equal(validation.metadata.get("field"), "boss_id", "The rejection should name the boss_id field.")


func _rejects_non_positive_max_hp() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.max_hp = 0
	assert_true(boss.validate().is_error(), "max_hp <= 0 should be rejected.")
	assert_equal(boss.validate().metadata.get("field"), "max_hp", "The rejection should name the max_hp field.")


func _rejects_fewer_than_two_phases() -> void:
	var boss: BossDefinition = BossDefinition.new(
		BossDefinition.BOSS_ID, 30, [_phase(&"only", 100)], "Boss explanation."
	)
	assert_true(boss.validate().is_error(), "A boss with < 2 phases should be rejected.")
	assert_equal(boss.validate().metadata.get("field"), "phases", "The rejection should name the phases field.")


func _rejects_a_blank_boss_explanation() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.explanation = "   "
	assert_true(boss.validate().is_error(), "A blank boss explanation should be rejected.")
	assert_equal(boss.validate().metadata.get("field"), "explanation", "The rejection should name the explanation field.")


# ---- structural threshold cross-rules ------------------------------------------------------------

func _rejects_phase_zero_threshold_not_100() -> void:
	var boss: BossDefinition = BossDefinition.new(
		BossDefinition.BOSS_ID, 30,
		[_phase(&"emergence", 90), _phase(&"frenzy", 50)],
		"Boss explanation."
	)
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A phase-0 threshold != 100 should be rejected.")
	assert_equal(validation.metadata.get("reason"), "invalid_phase", "It should be a per-phase rejection.")
	assert_equal(validation.metadata.get("phase_index"), 0, "It should name phase index 0.")
	assert_equal(validation.metadata.get("field"), "hp_threshold_percent", "It should name the threshold field.")


func _rejects_non_strictly_decreasing_thresholds() -> void:
	# Phase 2 threshold (60) is HIGHER than phase 1 (50) — non-monotonic (out of order).
	var boss: BossDefinition = BossDefinition.new(
		BossDefinition.BOSS_ID, 30,
		[_phase(&"emergence", 100), _phase(&"frenzy", 50), _phase(&"collapse", 60)],
		"Boss explanation."
	)
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A non-strictly-decreasing threshold should be rejected.")
	assert_equal(validation.metadata.get("phase_index"), 2, "It should name the out-of-order phase index.")
	assert_equal(validation.metadata.get("field"), "hp_threshold_percent", "It should name the threshold field.")


func _rejects_duplicate_thresholds() -> void:
	# Phase 2 threshold (50) EQUALS phase 1 (50) — equal is not strictly-decreasing.
	var boss: BossDefinition = BossDefinition.new(
		BossDefinition.BOSS_ID, 30,
		[_phase(&"emergence", 100), _phase(&"frenzy", 50), _phase(&"collapse", 50)],
		"Boss explanation."
	)
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "An equal (duplicate) threshold should be rejected as non-monotonic.")
	assert_equal(validation.metadata.get("phase_index"), 2, "It should name the duplicate-threshold phase index.")


func _rejects_a_duplicate_phase_id() -> void:
	# Two phases share the id "emergence" — thresholds are still strictly-decreasing so the id check is what fires.
	var boss: BossDefinition = BossDefinition.new(
		BossDefinition.BOSS_ID, 30,
		[_phase(&"emergence", 100), _phase(&"emergence", 50)],
		"Boss explanation."
	)
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A duplicate phase_id should be rejected.")
	assert_equal(validation.metadata.get("phase_index"), 1, "It should name the duplicate phase index.")
	assert_equal(validation.metadata.get("field"), "phase_id", "It should name the phase_id field.")


# ---- per-phase rejects (index-surfaced) ----------------------------------------------------------

func _rejects_per_phase_bad_phase_id() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.phases[1].phase_id = &"Frenzy"
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A per-phase bad phase_id should be rejected.")
	assert_equal(validation.metadata.get("reason"), "invalid_phase", "It should be a per-phase rejection.")
	assert_equal(validation.metadata.get("phase_index"), 1, "It should name the offending phase index.")
	assert_equal(validation.metadata.get("field"), "phase_id", "It should name the phase_id field.")


func _rejects_per_phase_out_of_band_threshold() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.phases[1].hp_threshold_percent = 0
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A per-phase out-of-band threshold should be rejected.")
	assert_equal(validation.metadata.get("phase_index"), 1, "It should name the offending phase index.")
	assert_equal(validation.metadata.get("field"), "hp_threshold_percent", "It should name the threshold field.")


func _rejects_per_phase_empty_actions() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.phases[1].actions = [] as Array[BossActionDefinition]
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A per-phase empty actions list should be rejected.")
	assert_equal(validation.metadata.get("phase_index"), 1, "It should name the offending phase index.")
	assert_equal(validation.metadata.get("field"), "actions", "It should name the actions field.")


func _rejects_per_phase_null_phase() -> void:
	var boss: BossDefinition = BossDefinition.new(BossDefinition.BOSS_ID, 30, [_phase(&"emergence", 100), null], "Boss explanation.")
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A null phase entry should be rejected, not dropped.")
	assert_equal(validation.metadata.get("phase_index"), 1, "It should name the null phase index.")


# ---- per-action rejects (phase + action index) ---------------------------------------------------

func _rejects_per_action_bad_action_id() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.phases[1].actions[1].action_id = &"Corrupt"
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A per-action bad action_id should be rejected.")
	assert_equal(validation.metadata.get("reason"), "invalid_phase", "It surfaces as a per-phase rejection.")
	assert_equal(validation.metadata.get("phase_index"), 1, "It should name the offending phase index.")
	assert_equal(validation.metadata.get("phase_reason"), "invalid_action", "It should preserve the sub-action reason.")
	assert_equal(validation.metadata.get("action_index"), 1, "It should name the offending action index.")
	assert_equal(validation.metadata.get("field"), "action_id", "It should name the action_id field.")


func _rejects_per_action_blank_telegraph() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.phases[0].actions[0].telegraph_text = "   "
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A blank telegraph should be rejected.")
	assert_equal(validation.metadata.get("phase_index"), 0, "It should name the offending phase index.")
	assert_equal(validation.metadata.get("field"), "telegraph_text", "It should name the telegraph_text field.")


func _rejects_per_action_negative_damage() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.phases[0].actions[0].damage = -1
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A negative damage should be rejected (never coerced).")
	assert_equal(validation.metadata.get("field"), "damage", "It should name the damage field.")


func _rejects_per_action_blank_explanation() -> void:
	var boss: BossDefinition = _valid_definition()
	boss.phases[1].actions[0].explanation = ""
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A blank action explanation should be rejected.")
	assert_equal(validation.metadata.get("field"), "explanation", "It should name the explanation field.")


func _rejects_per_phase_duplicate_action_id() -> void:
	var boss: BossDefinition = BossDefinition.new(
		BossDefinition.BOSS_ID, 30,
		[
			_phase(&"emergence", 100, [_action(&"lash", 6), _action(&"lash", 8)]),
			_phase(&"frenzy", 50)
		],
		"Boss explanation."
	)
	var validation: ActionResult = boss.validate()
	assert_true(validation.is_error(), "A duplicate action_id within a phase should be rejected.")
	assert_equal(validation.metadata.get("phase_index"), 0, "It should name the phase with the duplicate.")
	assert_equal(validation.metadata.get("action_index"), 1, "It should name the duplicate action index.")
	assert_equal(validation.metadata.get("field"), "action_id", "It should name the action_id field.")


# ---- BossActionDefinition standalone -------------------------------------------------------------

func _action_validates_and_rejects_per_field() -> void:
	var action: BossActionDefinition = _action(&"lash", 6)
	assert_true(action.validate().succeeded, "A well-formed action validates.")

	# A zero-damage pure-telegraph action is legal.
	var zero_damage: BossActionDefinition = _action(&"reposition", 0)
	assert_true(zero_damage.validate().succeeded, "A zero-damage (pure-telegraph) action is legal.")

	# A bad damage_type is rejected.
	var bad_type: BossActionDefinition = BossActionDefinition.new(&"lash", "Telegraph.", 5, &"Physical", "Explanation.")
	assert_true(bad_type.validate().is_error(), "A non-lower_snake damage_type should be rejected.")
	assert_equal(bad_type.validate().metadata.get("field"), "damage_type", "It should name the damage_type field.")


# ---- accessors -----------------------------------------------------------------------------------

func _accessors_resolve() -> void:
	var boss: BossDefinition = _valid_definition()
	assert_equal(boss.phase_ids(), [&"emergence", &"frenzy"] as Array[StringName], "phase_ids should return declaration order.")
	assert_equal(boss.get_phase(0).phase_id, &"emergence", "get_phase(0) resolves the entry phase.")
	assert_true(boss.get_phase(9) == null, "get_phase on an out-of-range index returns null (fail-closed).")
	assert_equal(boss.legal_action_ids(0), [&"lash", &"skitter"] as Array[StringName], "legal_action_ids(0) exposes phase 0's action set.")
	assert_equal(boss.legal_action_ids(1), [&"lash", &"corrupt"] as Array[StringName], "legal_action_ids(1) exposes phase 1's action set.")
	assert_equal(boss.legal_action_ids(9), [] as Array[StringName], "legal_action_ids on an out-of-range index is empty (fail-closed).")
	assert_equal(boss.phase_threshold_percent(1), 50, "phase_threshold_percent(1) returns the phase-1 threshold.")
	assert_equal(boss.phase_threshold_percent(9), -1, "phase_threshold_percent on an out-of-range index returns -1 (fail-closed).")


# ---- AC2 half 2: the per-phase legal-action set is the 9.3 AI constraint surface ----------------

func _legal_action_sets_are_phase_dependent() -> void:
	# AC2 "future AI choices are constrained by the active phase": 9.2 EXPOSES the per-phase legal-action set (9.3 scores
	# ONLY these). The fixture's phase 0 and phase 1 sets are QUERYABLE and DIFFER (phase 1 adds "corrupt", drops
	# "skitter"). The BossPhaseDefinition accessor agrees with the BossDefinition-by-index accessor.
	var boss: BossDefinition = _valid_definition()
	var phase0: Array[StringName] = boss.legal_action_ids(0)
	var phase1: Array[StringName] = boss.legal_action_ids(1)
	assert_false(phase0.is_empty(), "The active phase's legal-action set is queryable (non-empty).")
	assert_true(phase0 != phase1, "Phase 0 and phase 1 legal-action sets differ (the phase constrains the AI).")
	assert_true(phase1.has(&"corrupt"), "Phase 1 permits an action phase 0 does not.")
	assert_false(phase1.has(&"skitter"), "Phase 1 no longer permits a phase-0-only action.")
	# The phase sub-resource accessor agrees with the definition-by-index accessor.
	assert_equal(boss.get_phase(1).legal_action_ids(), phase1, "BossPhaseDefinition.legal_action_ids() agrees with the by-index accessor.")


func _baseline_boss_phase_action_sets_are_queryable_and_differ() -> void:
	# The REAL content 9.3 consumes: the baseline Larval Avatar's phase sets are queryable and escalate across phases.
	var repository: BossRepository = BossRepository.create_baseline_repository()
	var boss: BossDefinition = repository.get_boss(BossDefinition.BOSS_ID)
	assert_true(boss != null, "The baseline Larval Avatar resolves.")
	assert_true(boss.phase_count() >= 2, "The baseline boss has >= 2 phases.")
	var phase0: Array[StringName] = boss.legal_action_ids(0)
	var phase_last: Array[StringName] = boss.legal_action_ids(boss.phase_count() - 1)
	assert_false(phase0.is_empty(), "The baseline phase-0 legal-action set is queryable.")
	assert_false(phase_last.is_empty(), "The baseline last-phase legal-action set is queryable.")
	assert_true(phase0 != phase_last, "The baseline boss's first and last phase legal-action sets differ (readable escalation).")
