class_name BossPhaseResolver
extends RefCounted

# The deterministic Larval Avatar PHASE RESOLVER (Story 9.2, FR63, AC2/AC3) — the boss analogue of RulesResolver. Given
# a BossDefinition + the boss's current phase index + current HP, it returns the ordered list of phase TRANSITIONS to
# apply as HP crosses the authored thresholds. It is the small, self-contained, deterministic, explanation-first state
# machine the story's phase MODEL calls for — NOT the generic rules engine (scripts/rules/conditions stays EMPTY,
# scripts/rules/operations stays single-file; no RuleCondition/RuleTarget/RuleOperation, no stacking/conflict/duration).
#
# IT IS A PURE READ (the snapshot / RulesResolver / LevelValidator purity contract): resolve() draws ZERO RNG (no
# randi/randf/RandomNumberGenerator), runs NO commands, and MUTATES NOTHING — not the definition, not its phases. It is
# a PURE FUNCTION of (definition, current_phase_index, current_hp): same inputs -> the same transition list + the same
# explanations + the same emitted boss_phase_changed payloads (the AC2/AC3 determinism guarantee).
#
# FORWARD-ONLY + STABLE DECLARATION ORDER + IDEMPOTENT (AC3):
#   - FORWARD-ONLY: the boss never returns to a phase < its current phase. Healing back ABOVE a crossed threshold does
#     NOT revert (the RouteState reveal-monotonicity precedent). resolve() only ever advances.
#   - STABLE ORDER: phases transition in DECLARATION order (phase 0 -> 1 -> 2 ...). The definition guarantees strictly-
#     decreasing thresholds, so "the deepest crossed phase" is unambiguous and the emitted chain is ordered.
#   - IDEMPOTENT: idempotency is STRUCTURAL, not a dedup cache. Because the current phase index is the state and the
#     resolve only advances, re-evaluating at the same or a higher phase (a re-crossed or already-behind threshold)
#     yields NO transition. Reaching a threshold fires exactly one change; re-reaching / staying below fires none.
#
# MULTI-THRESHOLD-IN-ONE-HIT ([Decision], RECOMMENDED): if a single large damage event drops HP past MULTIPLE
# thresholds at once, resolve() advances to the DEEPEST crossed phase and emits ONE BossPhaseTransition PER phase
# actually entered, in order (a chain of adjacent from/to steps) — so the record is honest and NO phase is skipped in
# the log. (The alternative — one jump straight to the deepest phase — would hide the intermediate phases from the
# event log; rejected.)
#
# HOME ([Decision]): scripts/content/boss/ — with the boss content/logic (the BossDefinition it reads + the
# BossPhaseTransition it returns), NOT the rules kernel. It is a scene-free RefCounted service (no Node/scene/autoload).

const BossDefinition = preload("res://scripts/content/definitions/boss_definition.gd")
const BossPhaseDefinition = preload("res://scripts/content/definitions/boss_phase_definition.gd")
const BossPhaseTransition = preload("res://scripts/content/boss/boss_phase_transition.gd")

# Resolve the phase transitions to apply for a boss at `current_phase_index` with `current_hp`. Returns the ordered
# (forward-only, declaration-order) list of transitions to enter — typically 0 (no threshold crossed past the current
# phase) or 1, and MORE than one only when a single crossing spans multiple thresholds (one per phase entered, in
# order). A null/invalid definition or an out-of-range phase index returns an EMPTY list (fail-closed — the resolver
# never fabricates a transition on bad input). PURE READ: draws no RNG, mutates nothing.
func resolve(definition: BossDefinition, current_phase_index: int, current_hp: int) -> Array[BossPhaseTransition]:
	var transitions: Array[BossPhaseTransition] = []
	if definition == null:
		return transitions
	var phase_count: int = definition.phase_count()
	# A valid boss always has >= 2 phases; guard defensively so a malformed/unvalidated definition can't index badly.
	if phase_count < 1:
		return transitions
	# Clamp the current phase index into range (a caller passing a stale/out-of-range index gets no transition rather
	# than a crash — the fail-closed posture). A negative index is treated as "before phase 0" so phase 0's entry can
	# still fire; but on a VALID boss the caller starts at phase 0 (always active), so this is defensive only.
	if current_phase_index >= phase_count - 1:
		# Already in (or past) the last phase — nothing deeper to enter. Also covers an out-of-range-high index.
		return transitions

	# The DEEPEST phase whose threshold is crossed by current_hp, scanning declaration order. Thresholds strictly
	# decrease, so once a threshold is NOT crossed no later (lower) one can be either — but we scan all to be explicit
	# and to keep the read robust to any (already-rejected) non-monotonic definition.
	var deepest_crossed: int = _deepest_crossed_phase(definition, current_hp)
	if deepest_crossed <= current_phase_index:
		# No phase deeper than the current one is crossed — idempotent NO-OP (a re-crossed / already-behind threshold).
		return transitions

	# Emit ONE transition per phase actually entered, in order (the multi-threshold-in-one-hit chain — no phase skipped
	# in the log). Each step is a forward adjacent transition (to_phase == from_phase + 1).
	for entered_phase: int in range(current_phase_index + 1, deepest_crossed + 1):
		var phase: BossPhaseDefinition = definition.get_phase(entered_phase)
		var phase_id_value: StringName = &""
		var explanation_value: String = ""
		if phase != null:
			phase_id_value = phase.phase_id
			explanation_value = _transition_explanation(definition, entered_phase, phase)
		transitions.append(BossPhaseTransition.new(
			definition.boss_id,
			entered_phase - 1,
			entered_phase,
			phase_id_value,
			BossPhaseTransition.TRIGGER_HP_THRESHOLD,
			explanation_value
		))
	return transitions


# The deepest phase index whose HP threshold is crossed by current_hp. Phase 0 (threshold 100) is crossed at any
# current_hp <= max_hp (always active). Integer comparison (current_hp * 100 <= threshold * max_hp) — no float rounding
# (the deterministic-read discipline; a boss at exactly the threshold % ENTERS the phase). Returns -1 if not even
# phase 0 is crossed (current_hp > max_hp, an out-of-band input) — fail-closed.
func _deepest_crossed_phase(definition: BossDefinition, current_hp: int) -> int:
	var deepest: int = -1
	var max_hp: int = definition.max_hp
	if max_hp <= 0:
		return deepest
	for phase_index: int in range(definition.phase_count()):
		var threshold: int = definition.phase_threshold_percent(phase_index)
		if threshold < 0:
			continue
		# Enter the phase when current HP is AT or BELOW the threshold %: current_hp / max_hp <= threshold / 100,
		# rearranged to integer math as current_hp * 100 <= threshold * max_hp.
		if current_hp * 100 <= threshold * max_hp:
			deepest = phase_index
	return deepest


# A readable explanation for entering `phase` (the Readability Rule — every phase change is explainable). Combines the
# threshold trigger with the phase's authored explanation. Pure; deterministic.
func _transition_explanation(definition: BossDefinition, phase_index: int, phase: BossPhaseDefinition) -> String:
	return "Entered phase %d (%s) at or below %d%% HP: %s" % [
		phase_index,
		String(phase.phase_id),
		definition.phase_threshold_percent(phase_index),
		phase.explanation
	]
