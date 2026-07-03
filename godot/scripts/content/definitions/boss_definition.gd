class_name BossDefinition
extends Resource

# The Larval Avatar BOSS definition (Story 9.2, FR63, AC1/AC2/AC3) — the validated content-layer truth for the ONLY
# required MVP boss (FR63 "The Larval Avatar must be implemented as the only required MVP boss"). It is a NEW
# *Definition in the content family (NOT an EnemyDefinition — that flat two-behavior shape has no phases/telegraphs/
# multi-action set; the 9.1 Dev Notes: "the Larval Avatar (phases, telegraphs, boss actions) is a NEW definition
# shape in Story 9.2/9.3, NOT this one"). It mirrors EventDefinition + EventChoiceDefinition VERBATIM in shape (a
# DEFINITION_TYPE const, @export fields, an _init copying inputs into a typed Array[BossPhaseDefinition], a
# validate() -> ActionResult returning invalid_boss_definition + {reason, field} / {reason, phase_index, field},
# the shared _is_lower_snake_id helper, and get_<x>/<x>_ids accessors) — the boss is an EventDefinition whose
# "choices" are ordered PHASES.
#
# THIS FILLS THE SLOT STORY 9.1 RESERVED (the load-bearing fact): BossArenaBuilder emits a boss-entity SLOT MARKER
# (boss_slot.entity_id == "larval_avatar", is_placeholder: true) with an EMPTY board entities array — 9.1 authored NO
# boss HP/stats. THIS definition is that fill: BOSS_ID == BossEncounterRequest.BOSS_ENTITY_ID ("larval_avatar"), a
# test cross-checks it. It is authored as a CODE-CONSTANT baseline through the BossRepository -> ContentRepository
# boundary (the fail-loud duplicate-id guard); there is STILL NO .tres/JSON content pipeline (data/source + data/
# resources stay empty scaffolding — the Epic-6/7 content-as-code-constant posture). The boss is a content DEFINITION
# here, NOT (yet) a live TacticalEntityState on a board (that needs max_hp > 0 on a board entity — the later live-loop
# story 9.3/9.4; 9.2 stays headless/content-and-state-machine-only).
#
# THE AC1 CONTENT CONTRACT (the definition carries "HP, phase thresholds or triggers, legal actions, telegraph
# definitions, damage rules, and explanation text"):
#   - boss_id:      lower_snake stable id (validated), == BOSS_ID ("larval_avatar", the 9.1 slot id).
#   - max_hp:       the boss's HP (> 0 — the AC1 "HP"; the EnemyDefinition/TacticalEntityState max_hp > 0 rule).
#   - phases:       an ORDERED Array[BossPhaseDefinition] (>= 2 — a boss with one phase has no phase model; the finale
#                   needs a readable escalation). Declaration order == stable transition order (AC3). Each phase carries
#                   its HP-THRESHOLD trigger + its legal-action set (each action = a legal action + telegraph + damage
#                   rule, see BossActionDefinition) + a phase explanation. The STRUCTURAL cross-rule: phase 0 threshold
#                   == 100 (the entry phase, always active on the fresh boss), and thresholds STRICTLY DECREASE
#                   thereafter (forward-only monotonic escalation — the RouteState reveal-monotonicity precedent).
#   - explanation:  the boss-level readable explanation (non-empty — the Readability Rule).
#
# validate() rejects fail-loud (never coerce): a non-lower_snake boss_id; max_hp <= 0; a < 2 phase list; a phase 0
# threshold != 100; a non-strictly-decreasing threshold (a later phase threshold >= the prior — non-monotonic or
# duplicate); a DUPLICATE phase_id; any per-phase validation error (delegated to BossPhaseDefinition.validate(),
# surfaced with the phase INDEX — the _invalid_choice precedent); a blank explanation.
#
# DETERMINISM: validate() draws ZERO RNG and mutates nothing (the EnemyDefinition/RulesResolver PURE-READ posture).
# DIFFICULTY IS A HARD NON-GOAL: the boss + its phases are AUTHORED escalation content, NOT a difficulty tier.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BossPhaseDefinition = preload("res://scripts/content/definitions/boss_phase_definition.gd")

const DEFINITION_TYPE := &"boss"

# The stable Larval Avatar boss id — MUST equal BossEncounterRequest.BOSS_ENTITY_ID (the 9.1 slot id "larval_avatar").
# Duplicated here as a plain literal (NOT preloading the generation-layer request into the content layer) so the
# content definition has no cross-layer dependency; a test cross-checks the two are equal so they can never drift.
const BOSS_ID := &"larval_avatar"

# The entry-phase threshold: phase 0 is always active on the fresh boss (100% HP). A structural anchor for the
# strictly-decreasing threshold cross-rule.
const ENTRY_PHASE_THRESHOLD_PERCENT := 100

@export var boss_id: StringName = &""
@export var max_hp: int = 0
# The ordered phases (>= 2; a typed sub-resource list). Declaration order == stable transition order. REJECT < 2.
@export var phases: Array[BossPhaseDefinition] = []
@export var explanation: String = ""

func _init(
	new_boss_id: StringName = &"",
	new_max_hp: int = 0,
	new_phases: Array = [],
	new_explanation: String = ""
) -> void:
	boss_id = new_boss_id
	max_hp = new_max_hp
	explanation = new_explanation
	# Copy the input into a typed Array[BossPhaseDefinition] (a typed @export array assigned an untyped literal at a
	# call site would otherwise mis-type). A non-BossPhaseDefinition entry is kept as null so validate() REJECTS it
	# (do NOT silently drop a malformed entry — the author must fix it; the EventDefinition.choices precedent).
	var copied_phases: Array[BossPhaseDefinition] = []
	for phase_value: Variant in new_phases:
		copied_phases.append(phase_value as BossPhaseDefinition)
	phases = copied_phases


# Pure read: validate the boss id, HP, the ordered phase list (>= 2, phase-0 == 100, strictly decreasing thresholds,
# unique ids, each phase valid), and the boss-level explanation. Returns ok or a per-field/per-phase
# invalid_boss_definition error. Draws NO RNG, mutates nothing.
func validate() -> ActionResult:
	if not _is_lower_snake_id(boss_id):
		return _invalid(&"boss_id")
	if max_hp <= 0:
		return _invalid(&"max_hp")
	# The boss MUST have >= 2 phases (a boss with one phase has no phase model — the finale needs a readable
	# escalation; the FR63 "readable boss phases" contract). REJECT < 2.
	if phases.size() < 2:
		return _invalid(&"phases")
	var seen_phase_ids: Dictionary = {}
	var previous_threshold: int = ENTRY_PHASE_THRESHOLD_PERCENT
	for index: int in range(phases.size()):
		var phase: BossPhaseDefinition = phases[index]
		if phase == null:
			return _invalid_phase(index, &"phase")
		var phase_validation: ActionResult = phase.validate()
		if phase_validation.is_error():
			# Surface the offending field with the phase INDEX (a fabricated/typo'd phase is rejected per-field,
			# preserving the sub-entry reason so an action-level error stays distinguishable).
			return _invalid_phase_from(index, phase_validation)
		# Phase 0 is the ENTRY phase: its threshold MUST be 100 (always active on the fresh boss). A phase 0 that is
		# not 100 would mean the boss starts in NO phase (an unreachable entry) — REJECT.
		if index == 0:
			if phase.hp_threshold_percent != ENTRY_PHASE_THRESHOLD_PERCENT:
				return _invalid_phase(index, &"hp_threshold_percent")
		else:
			# Thresholds STRICTLY DECREASE (forward-only monotonic escalation — a later phase entered at a LOWER HP %).
			# A threshold >= the prior is non-monotonic (equal == duplicate, greater == out-of-order) — REJECT. This is
			# the AC3 "stable order" structural guarantee at the content layer (the resolver relies on it).
			if phase.hp_threshold_percent >= previous_threshold:
				return _invalid_phase(index, &"hp_threshold_percent")
		previous_threshold = phase.hp_threshold_percent
		# A duplicate phase_id within the boss is rejected (each phase must be uniquely addressable — a duplicate id
		# would make the boss_phase_changed.phase_id ambiguous; the EventDefinition duplicate-choice precedent).
		var phase_id_text: String = String(phase.phase_id)
		if seen_phase_ids.has(phase_id_text):
			return _invalid_phase(index, &"phase_id")
		seen_phase_ids[phase_id_text] = true
	if explanation.strip_edges().is_empty():
		return _invalid(&"explanation")
	return ActionResult.ok()


# The number of phases (>= 2 on a valid boss). The phase resolver clamps to phase_count() - 1.
func phase_count() -> int:
	return phases.size()


# Resolve a phase by its ordered index (null on an out-of-range index — a fail-closed lookup). The resolver +
# accessors read the active phase through this.
func get_phase(phase_index: int) -> BossPhaseDefinition:
	if phase_index < 0 or phase_index >= phases.size():
		return null
	return phases[phase_index]


# The ordered list of phase ids (lower_snake StringNames) — declaration/transition order.
func phase_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for phase: BossPhaseDefinition in phases:
		if phase != null:
			ids.append(phase.phase_id)
	return ids


# The active phase's legal-action id set (AC2 half 2 — the AI constraint surface 9.3 scores against). Returns an
# EMPTY array on an out-of-range index (fail-closed). A pure read; deterministic.
func legal_action_ids(phase_index: int) -> Array[StringName]:
	var phase: BossPhaseDefinition = get_phase(phase_index)
	if phase == null:
		return []
	return phase.legal_action_ids()


# The HP threshold % (1..100) at/below which the boss enters the phase at `phase_index`. Returns -1 on an out-of-range
# index (fail-closed sentinel — an unreachable threshold, so the resolver treats it as never crossed). Pure read.
func phase_threshold_percent(phase_index: int) -> int:
	var phase: BossPhaseDefinition = get_phase(phase_index)
	if phase == null:
		return -1
	return phase.hp_threshold_percent


static func _is_lower_snake_id(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty():
		return false
	if text != text.to_lower():
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false
	return true


static func _invalid(field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_boss_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})


static func _invalid_phase(index: int, field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_boss_definition", {
		"reason": "invalid_phase",
		"phase_index": index,
		"field": String(field_name)
	})


# Surface a per-phase sub-validation error with the phase index, preserving the phase's own reason/field (and an
# action_index if the error came from a per-action sub-entry) so an action-level rejection stays distinguishable from
# a phase-field rejection.
static func _invalid_phase_from(index: int, phase_validation: ActionResult) -> ActionResult:
	var metadata: Dictionary = {
		"reason": "invalid_phase",
		"phase_index": index,
		"field": String(phase_validation.metadata.get("field"))
	}
	if String(phase_validation.metadata.get("reason")) == "invalid_action":
		metadata["phase_reason"] = "invalid_action"
		metadata["action_index"] = phase_validation.metadata.get("action_index")
	return ActionResult.error(&"invalid_boss_definition", metadata)
