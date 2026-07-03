class_name BossPhaseDefinition
extends Resource

# A single ordered PHASE of the Larval Avatar boss (Story 9.2, FR63, AC1/AC2/AC3) — the typed, validated sub-resource
# carrying ONE readable boss phase: its HP-THRESHOLD trigger (the % at/below which the boss ENTERS this phase), its
# per-phase LEGAL-ACTION set (the AC1 "legal actions" + "telegraph definitions" + "damage rules", each a
# BossActionDefinition), and a readable phase EXPLANATION. It is the boss-content analogue of EventChoiceDefinition
# (a typed sub-resource with a per-field validate() surface) — each phase re-validates exactly like a top-level
# definition, and the parent BossDefinition surfaces per-phase errors with the phase INDEX (the _invalid_choice
# precedent).
#
# PHASES ARE ORDERED + FORWARD-ONLY (AC3): a BossDefinition holds an ORDERED Array[BossPhaseDefinition] whose
# DECLARATION ORDER == the stable transition order. Phase 0 is the ENTRY phase (threshold 100 — always active on the
# fresh boss); each later phase carries a STRICTLY-LOWER hp_threshold_percent (enforced by the parent), so the boss
# transitions phase 0 -> 1 -> 2 ... monotonically as HP falls, NEVER reverting (the RouteState reveal-monotonicity
# precedent). This phase carries only its OWN threshold + content; the strictly-decreasing / phase-0==100 CROSS-rule
# is enforced by BossDefinition.validate() (the structural cross-rule, like EventDefinition's at-least-one-tradeoff).
#
# THE PER-PHASE CONTRACT:
#   - phase_id:              lower_snake stable id (validated), UNIQUE within the boss (the parent enforces uniqueness).
#   - hp_threshold_percent:  the HP % (1..100 inclusive) at or below which the boss ENTERS this phase (an int, not a
#                            float — a readable authored threshold, e.g. 100 / 60 / 30). REJECT <= 0 or > 100. The
#                            phase-resolver compares current_hp * 100 vs threshold * max_hp (integer math, no float
#                            rounding — the deterministic-read discipline).
#   - actions:               a NON-EMPTY Array[BossActionDefinition] (>= 1 — a phase with no legal action is not a
#                            playable phase). Each action is a typed sub-resource carrying a UNIQUE lower_snake
#                            action_id + its telegraph + damage + explanation (see BossActionDefinition). This IS the
#                            AC2-half-2 "future AI choices are constrained by the active phase" surface: legal_action_ids()
#                            exposes exactly this phase's action id set, and 9.3's boss AI scores ONLY these.
#   - explanation:           a readable player/debug explanation of the phase (non-empty — the Readability Rule).
#
# validate() rejects fail-loud (never coerce): a non-lower_snake phase_id; an out-of-(0,100] threshold; an empty
# actions list; a DUPLICATE action_id within the phase; any per-action validation error (delegated to
# BossActionDefinition.validate(), surfaced with the action index); a blank explanation.
#
# DIFFICULTY IS A HARD NON-GOAL (project-context): a phase is AUTHORED escalation content, NOT a difficulty tier —
# nothing here scales by a selectable difficulty knob.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const BossActionDefinition = preload("res://scripts/content/definitions/boss_action_definition.gd")

@export var phase_id: StringName = &""
# The HP % (1..100 inclusive) at/below which the boss ENTERS this phase. Phase 0 is 100 (always active); later phases
# strictly lower (the parent enforces the strictly-decreasing cross-rule). REJECT <= 0 or > 100.
@export var hp_threshold_percent: int = 0
# The legal actions the boss may take in this phase (>= 1; a typed sub-resource list). REJECT empty. This is the
# per-phase legal-action set 9.3's AI is constrained to (AC2 half 2).
@export var actions: Array[BossActionDefinition] = []
@export var explanation: String = ""

func _init(
	new_phase_id: StringName = &"",
	new_hp_threshold_percent: int = 0,
	new_actions: Array = [],
	new_explanation: String = ""
) -> void:
	phase_id = new_phase_id
	hp_threshold_percent = new_hp_threshold_percent
	explanation = new_explanation
	# Copy the input into a typed Array[BossActionDefinition] (a typed @export array assigned an untyped literal at a
	# call site would otherwise mis-type). A non-BossActionDefinition entry is kept as null so validate() REJECTS it
	# (do NOT silently drop a malformed entry — the author must fix it; the EventDefinition.choices precedent).
	var copied_actions: Array[BossActionDefinition] = []
	for action_value: Variant in new_actions:
		copied_actions.append(action_value as BossActionDefinition)
	actions = copied_actions


# Pure read: validate the phase id, the threshold band, the action list (non-empty, unique ids, each action valid),
# and the explanation. Returns ok or a per-field invalid_boss_definition error. The parent BossDefinition.validate()
# calls this for each phase and prefixes the phase index. Draws NO RNG, mutates nothing.
func validate() -> ActionResult:
	if not _is_lower_snake_id(phase_id):
		return _invalid(&"phase_id")
	# The threshold is a readable authored HP % in (0, 100] — 100 for the entry phase, strictly lower for later
	# phases (the strictly-decreasing cross-rule is the parent's job). REJECT <= 0 or > 100.
	if hp_threshold_percent <= 0 or hp_threshold_percent > 100:
		return _invalid(&"hp_threshold_percent")
	# A phase MUST offer at least one legal action (a phase with no action is not a playable phase — REJECT empty).
	if actions.is_empty():
		return _invalid(&"actions")
	var seen_action_ids: Dictionary = {}
	for index: int in range(actions.size()):
		var action: BossActionDefinition = actions[index]
		if action == null:
			return _invalid_action(index, &"action")
		var action_validation: ActionResult = action.validate()
		if action_validation.is_error():
			# Surface the offending field with the action INDEX (a fabricated/typo'd action is rejected per-field).
			return _invalid_action(index, StringName(String(action_validation.metadata.get("field"))))
		# A duplicate action_id within the phase is rejected (each action must be uniquely addressable for 9.3's AI
		# to score — a duplicate id would make the selection ambiguous; the EventDefinition duplicate-choice precedent).
		var action_id_text: String = String(action.action_id)
		if seen_action_ids.has(action_id_text):
			return _invalid_action(index, &"action_id")
		seen_action_ids[action_id_text] = true
	if explanation.strip_edges().is_empty():
		return _invalid(&"explanation")
	return ActionResult.ok()


# The ordered list of this phase's legal action ids (lower_snake StringNames) — the AC2-half-2 constraint surface
# 9.3's boss AI scores against (it scores ONLY these ids). A pure read; deterministic (declaration order).
func legal_action_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for action: BossActionDefinition in actions:
		if action != null:
			ids.append(action.action_id)
	return ids


# Resolve one legal action by its id (null on a miss — a fail-closed lookup, the get_choice precedent). 9.3 reads the
# selected action's telegraph/damage through this.
func get_action(action_id_value: StringName) -> BossActionDefinition:
	for action: BossActionDefinition in actions:
		if action != null and action.action_id == action_id_value:
			return action
	return null


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


static func _invalid_action(index: int, field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_boss_definition", {
		"reason": "invalid_action",
		"action_index": index,
		"field": String(field_name)
	})
