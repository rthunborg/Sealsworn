extends "res://tests/unit/test_case.gd"

# Story 9.2 Task 3 — BossPhaseResolver (the deterministic, pure, forward-only, stable-ordered, idempotent phase state
# machine, AC2/AC3). Covers: reaching a threshold fires EXACTLY one change; re-reaching / staying below fires NONE; a
# threshold already behind the current phase fires NONE (idempotency — AC3); transitions fire in DECLARATION order
# (AC3); the multi-threshold-in-one-hit case emits ONE change per phase entered, in order (the recorded decision);
# determinism (same inputs -> same transitions + explanations); the resolve is a PURE READ (mutates nothing on the
# definition/phases, and drawing it repeatedly yields identical output — no hidden RNG/state). Boundary HP-% math (a
# boss AT exactly the threshold enters the phase). Fail-closed on a null definition / out-of-range phase index.

const BossActionDefinition = preload("res://scripts/content/definitions/boss_action_definition.gd")
const BossPhaseDefinition = preload("res://scripts/content/definitions/boss_phase_definition.gd")
const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossPhaseResolver = preload("res://scripts/content/boss/boss_phase_resolver.gd")
const BossPhaseTransition = preload("res://scripts/content/boss/boss_phase_transition.gd")

func run() -> Dictionary:
	_reaching_a_threshold_fires_exactly_one_change()
	_staying_above_a_threshold_fires_none()
	_re_reaching_the_same_threshold_fires_none()
	_a_threshold_behind_the_current_phase_fires_none()
	_already_in_last_phase_fires_none()
	_transitions_fire_in_declaration_order()
	_multi_threshold_in_one_hit_emits_a_chain()
	_boundary_at_exact_threshold_enters_the_phase()
	_just_above_threshold_does_not_enter()
	_is_deterministic()
	_is_a_pure_read_no_mutation()
	_fails_closed_on_null_or_out_of_range()
	_transition_payload_is_forward_only()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _action(action_id: StringName) -> BossActionDefinition:
	return BossActionDefinition.new(action_id, "Telegraph.", 5, &"physical", "Explanation.")


func _phase(phase_id: StringName, threshold: int) -> BossPhaseDefinition:
	return BossPhaseDefinition.new(phase_id, threshold, [_action(StringName("%s_act" % String(phase_id)))], "Phase explanation.")


# A 3-phase boss with max_hp 100 and clean thresholds 100 / 60 / 30 (so 60% == 60 HP, 30% == 30 HP).
func _boss() -> BossDefinition:
	var boss: BossDefinition = BossDefinition.new(
		&"larval_avatar",
		100,
		[_phase(&"emergence", 100), _phase(&"adaptation", 60), _phase(&"desperation", 30)],
		"Boss explanation."
	)
	# Sanity: the fixture itself must be valid so the resolver reads a well-formed boss.
	assert_true(boss.validate().succeeded, "The resolver fixture boss must validate.")
	return boss


# ---- single-transition + idempotency (AC3) -------------------------------------------------------

func _reaching_a_threshold_fires_exactly_one_change() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	# Boss in phase 0, HP drops to 55 (below the 60% threshold, above the 30%). Exactly one change: 0 -> 1.
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 0, 55)
	assert_equal(transitions.size(), 1, "Crossing exactly one threshold fires exactly one change.")
	assert_equal(transitions[0].from_phase, 0, "The change is from phase 0.")
	assert_equal(transitions[0].to_phase, 1, "The change is to phase 1.")
	assert_equal(transitions[0].phase_id, &"adaptation", "The entered phase id is carried.")
	assert_equal(transitions[0].trigger, BossPhaseTransition.TRIGGER_HP_THRESHOLD, "The trigger is the HP threshold marker.")
	assert_false(transitions[0].explanation.strip_edges().is_empty(), "The transition carries a readable explanation.")


func _staying_above_a_threshold_fires_none() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	# Boss in phase 0, HP 80 (still above the 60% threshold). No change.
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 0, 80)
	assert_equal(transitions.size(), 0, "Staying above the next threshold fires no change.")


func _re_reaching_the_same_threshold_fires_none() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	# Boss ALREADY in phase 1 (adaptation), HP 55 (still below 60%, the threshold that put it there). Re-evaluating at
	# the same phase/HP is idempotent — no duplicate change.
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 1, 55)
	assert_equal(transitions.size(), 0, "Re-reaching the threshold already crossed (same phase) fires no change (idempotent).")


func _a_threshold_behind_the_current_phase_fires_none() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	# Boss in phase 2 (desperation) but HEALED back to 70 HP (above BOTH the 60% and 30% thresholds). Forward-only:
	# it never reverts to phase 1/0 — a threshold behind the current phase fires nothing.
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 2, 70)
	assert_equal(transitions.size(), 0, "A threshold behind the current phase (healed above it) fires no change (forward-only).")


func _already_in_last_phase_fires_none() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	# Boss in the last phase (2), HP 10 (deep below all thresholds). Nothing deeper to enter.
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 2, 10)
	assert_equal(transitions.size(), 0, "Already in the last phase fires no change.")


# ---- stable order + multi-threshold (AC3) --------------------------------------------------------

func _transitions_fire_in_declaration_order() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	# Boss in phase 0, HP drops to 25 (below BOTH 60% and 30%). Two changes, in declaration order 0->1 then 1->2.
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 0, 25)
	assert_equal(transitions.size(), 2, "Crossing two thresholds at once fires two changes.")
	assert_equal(transitions[0].to_phase, 1, "The FIRST change enters phase 1 (declaration order).")
	assert_equal(transitions[1].to_phase, 2, "The SECOND change enters phase 2 (declaration order).")


func _multi_threshold_in_one_hit_emits_a_chain() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	# The recorded decision: advance to the deepest crossed phase, emit ONE change per phase entered, in order (a chain
	# of adjacent from/to steps — no phase skipped in the log). HP 25 from phase 0 crosses phase 1 AND phase 2.
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 0, 25)
	assert_equal(transitions.size(), 2, "The chain has one transition per phase entered.")
	# Each step is a forward ADJACENT transition (to == from + 1), so no phase is skipped.
	assert_equal(transitions[0].from_phase, 0, "Chain step 0 is from phase 0.")
	assert_equal(transitions[0].to_phase, 1, "Chain step 0 is to phase 1.")
	assert_equal(transitions[1].from_phase, 1, "Chain step 1 is from phase 1 (adjacent — no skip).")
	assert_equal(transitions[1].to_phase, 2, "Chain step 1 is to phase 2.")
	assert_equal(transitions[1].phase_id, &"desperation", "The deepest entered phase id is carried on the last step.")


# ---- boundary HP-% math --------------------------------------------------------------------------

func _boundary_at_exact_threshold_enters_the_phase() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	# HP exactly 60 on a max_hp-100 boss == exactly the 60% threshold. A boss AT the threshold ENTERS the phase (<=).
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 0, 60)
	assert_equal(transitions.size(), 1, "HP at exactly the threshold % enters the phase (inclusive boundary).")
	assert_equal(transitions[0].to_phase, 1, "It enters phase 1 at exactly 60%.")


func _just_above_threshold_does_not_enter() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	# HP 61 on a max_hp-100 boss is just ABOVE the 60% threshold — does NOT enter phase 1 yet.
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 0, 61)
	assert_equal(transitions.size(), 0, "HP just above the threshold % does not enter the phase.")


# ---- determinism + purity (AC2/AC3) --------------------------------------------------------------

func _is_deterministic() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	var boss: BossDefinition = _boss()
	var first: Array[BossPhaseTransition] = resolver.resolve(boss, 0, 25)
	var second: Array[BossPhaseTransition] = resolver.resolve(boss, 0, 25)
	assert_equal(first.size(), second.size(), "Same inputs -> same transition count.")
	for index: int in range(first.size()):
		assert_equal(first[index].to_phase, second[index].to_phase, "Same inputs -> same to_phase per step.")
		assert_equal(first[index].explanation, second[index].explanation, "Same inputs -> same explanation per step (deterministic).")
	# A fresh resolver instance yields the same output (no per-instance hidden state).
	var fresh: Array[BossPhaseTransition] = BossPhaseResolver.new().resolve(boss, 0, 25)
	assert_equal(fresh.size(), first.size(), "A fresh resolver instance yields the same output (stateless pure read).")


func _is_a_pure_read_no_mutation() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	var boss: BossDefinition = _boss()
	# Snapshot the definition's observable state before resolving.
	var max_hp_before: int = boss.max_hp
	var phase_count_before: int = boss.phase_count()
	var thresholds_before: Array[int] = []
	for index: int in range(boss.phase_count()):
		thresholds_before.append(boss.phase_threshold_percent(index))
	var phase0_actions_before: Array[StringName] = boss.legal_action_ids(0)

	# Resolve several times across different inputs (a full crossing, a no-op, an idempotent re-read).
	resolver.resolve(boss, 0, 25)
	resolver.resolve(boss, 0, 90)
	resolver.resolve(boss, 2, 5)

	# The definition is UNCHANGED (the resolve mutated nothing on the source — the pure-read contract).
	assert_equal(boss.max_hp, max_hp_before, "resolve() must not mutate max_hp.")
	assert_equal(boss.phase_count(), phase_count_before, "resolve() must not mutate the phase count.")
	for index: int in range(boss.phase_count()):
		assert_equal(boss.phase_threshold_percent(index), thresholds_before[index], "resolve() must not mutate a phase threshold.")
	assert_equal(boss.legal_action_ids(0), phase0_actions_before, "resolve() must not mutate a phase's action set.")


# ---- fail-closed ---------------------------------------------------------------------------------

func _fails_closed_on_null_or_out_of_range() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	assert_equal(resolver.resolve(null, 0, 10).size(), 0, "A null definition yields no transitions (fail-closed).")
	var boss: BossDefinition = _boss()
	# An out-of-range-high current phase index yields no transition (already at/past the last phase).
	assert_equal(resolver.resolve(boss, 9, 5).size(), 0, "An out-of-range-high phase index yields no transitions (fail-closed).")


func _transition_payload_is_forward_only() -> void:
	var resolver: BossPhaseResolver = BossPhaseResolver.new()
	var transitions: Array[BossPhaseTransition] = resolver.resolve(_boss(), 0, 25)
	for transition: BossPhaseTransition in transitions:
		assert_true(transition.to_phase > transition.from_phase, "Every transition is forward-only (to_phase > from_phase).")
		var payload: Dictionary = transition.to_payload()
		assert_equal(String(payload.get("boss_entity_id")), "larval_avatar", "The payload carries the boss id.")
		assert_true(int(payload.get("to_phase")) > int(payload.get("from_phase")), "The payload is forward-only for the event.")
