class_name AffinityDefinition
extends Resource

# A typed, validated AFFINITY definition (Story 7.4, FR56) — the content-layer truth for a level's readable affinity
# IDENTITY (Scorched / Flooded-Conductive / Cursed / Darkness, plus the neutral `none`). It mirrors
# CursedRewardDefinition / GoldRewardDefinition / DestroyOutcomeTableDefinition VERBATIM in shape: a DEFINITION_TYPE
# const, @export fields, an _init copying inputs, validate() -> ActionResult returning invalid_affinity_definition +
# {reason:"invalid_field", field:...} per field, and the shared _is_lower_snake_id helper. It is mirrored from an
# APPROVED code-constant baseline through the AffinityRepository boundary (NO JSON pipeline — data/source and
# data/resources stay empty; the Epic-6/7 content-as-code-constant posture).
#
# THE AC1 SURFACE (the definition EXPOSES "id, display name, tactical rules, visual tags, and explanation text"):
#   - affinity_id:    lower_snake stable id (validated). The neutral affinity reuses GenerationRequest.AFFINITY_NONE
#                     (&"none") as its id so the deterministic assignment can pick it like any other.
#   - display_name:   the evocative human-facing name (non-empty) — feeds the (later) HUD/view-model surface.
#   - tactical_rules: the RECORD-ONLY rule data (see the CRITICAL note below). A plain Array of plain Dictionary rule
#                     markers, each {rule_id: lower_snake String, description: non-empty String}. This is DATA that
#                     DESCRIBES the affinity's intended tactical pressure — the 7.5/7.6 effects layer will READ it to
#                     wire real effects; 7.4 only AUTHORS + VALIDATES it. The neutral affinity has an EMPTY set (AC3).
#   - visual_tags:    an Array[StringName] of lower_snake visual/cue tag ids — the art/cue hooks. The existing
#                     affinity.<kind>.png board art maps here (e.g. `scorched` -> a `scorched` tag). Default empty for
#                     the neutral affinity.
#   - explanation:    a non-empty player/debug-readable line — the AC1 "explanation text" (the honest description of the
#                     tactical pressure the affinity represents; the GDD "affinities alter tactical choices, not just
#                     visuals" intent communicated honestly).
#
# CRITICAL — tactical_rules is DATA, NOT an operation engine (the v0 RECORD/EXPLANATION-ONLY posture, the exact
# parallel of the 7.2 "v0 curse resolution is EXPLANATION-ONLY" + 7.3 "a risk effect RECORDS + raises a flag +
# EXPLAINS; it mutates NO combat number" boundaries): tactical_rules is a strictly-VALIDATED plain dict-list (rule
# marker ids + descriptions). It is NOT executable, fires no hooks, and mutates no tactical number. validate()
# SHAPE-CHECKS each rule (lower_snake rule_id, non-empty description) — it does NOT resolve a rule against an operation
# engine (there is none in v0; scripts/rules/{conditions,operations} stay EMPTY). [Decision] A plain Array of plain
# Dictionary was chosen over a typed sub-resource because (a) it matches the ratified "metadata-carried dictionary
# lists" rule (the RewardOffer.offered_entries / EventChoiceDefinition.risk_flags precedent — `Array[Dictionary]` does
# NOT survive an ActionResult metadata deep-copy, so these lists are received as a plain untyped `Array`), and (b) it
# is the simplest RECORD-ONLY shape the 7.5 layer can read without a new resource type. The 7.5 effects layer will
# READ these rule markers to wire the real Scorched/Flooded/Cursed/Darkness effects.
#
# DIFFICULTY IS A HARD NON-GOAL (project-context): an affinity is a readable tactical IDENTITY + RECORDED rule data,
# NOT a difficulty knob. No affinity field (and no tactical_rules value) may be a hidden multiplier that scales enemy
# stats/HP/damage/rewards/RNG/run length. Affinity pressure is authored tactical CONTENT, surfaced honestly. The
# tactical_rules markers are descriptive ids + prose, never a raw difficulty scalar.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"affinity"

# The canonical neutral / no-affinity id (AC3). Reuses the established GenerationRequest.AFFINITY_NONE sentinel value
# (&"none") so a level with no affinity and a registered neutral affinity share one id — the assignment can pick it
# like any other affinity, and the neutral query surface keys off it.
const AFFINITY_NONE := &"none"

# The EXACT key set of a single tactical_rules entry. A rule marker is a plain Dictionary with a lower_snake rule id +
# a non-empty human/debug-readable description (RECORD-ONLY — it is read by the 7.5 effects layer, never executed in
# v0). Kept as a constant so the validate() shape-check and any reader agree on the keys.
const RULE_ID_KEY := "rule_id"
const RULE_DESCRIPTION_KEY := "description"

@export var affinity_id: StringName = &""
@export var display_name: String = ""
# RECORD-ONLY rule data (a plain Array of plain Dictionary markers). Received/stored untyped (the Array[Dictionary]
# deep-copy rule). EMPTY for the neutral affinity (AC3).
@export var tactical_rules: Array = []
# lower_snake visual/cue tag ids (the art/cue hooks). Typed Array[StringName]; EMPTY for the neutral affinity.
@export var visual_tags: Array[StringName] = []
@export var explanation: String = ""

func _init(
	new_affinity_id: StringName = &"",
	new_display_name: String = "",
	new_tactical_rules: Array = [],
	new_visual_tags: Array[StringName] = [],
	new_explanation: String = ""
) -> void:
	affinity_id = new_affinity_id
	display_name = new_display_name
	tactical_rules = new_tactical_rules.duplicate(true)
	visual_tags = new_visual_tags.duplicate()
	explanation = new_explanation


# The canonical NEUTRAL / no-affinity definition (AC3): a real registered affinity with the AFFINITY_NONE id, an EMPTY
# tactical_rules set (no affinity side effects), EMPTY visual_tags, and a neutral explanation. [Decision] The neutral
# case is a REGISTERED definition (not a bare repository sentinel) so get_affinity(&"none") resolves + the assignment
# can SELECT it like any other affinity; is_neutral() + the repository's tactical_rules_for(&"none") give the empty
# rule set the AC3 contract demands.
static func neutral() -> AffinityDefinition:
	# load(...) the script (rather than the bare class_name self-reference) so the factory resolves correctly even
	# before the global class-name cache lists this new definition — the same load(...)-the-script discipline the
	# repository factories use.
	return load("res://scripts/content/definitions/affinity_definition.gd").new(
		AFFINITY_NONE,
		"Unaffiliated",
		[],
		[] as Array[StringName],
		"This level carries no affinity: no failed containment protocol shapes it, so no affinity tactical rules apply."
	)


func validate() -> ActionResult:
	if not _is_lower_snake_id(affinity_id):
		return _invalid(&"affinity_id")
	if display_name.strip_edges().is_empty():
		return _invalid(&"display_name")
	# AC1: explanation text is REQUIRED non-empty (a level's affinity must be readable — the honest description of the
	# pressure it represents; the neutral affinity carries a neutral explanation, never blank).
	if explanation.strip_edges().is_empty():
		return _invalid(&"explanation")
	# tactical_rules is a plain Array of plain Dictionary rule markers — SHAPE-checked, never coerced. Each entry must
	# be a Dictionary carrying a lower_snake rule_id + a non-empty description. A non-Dictionary entry, a non-lower_snake
	# rule_id, or a blank description is INVALID (the RECORD-ONLY data contract). The neutral affinity's EMPTY set
	# passes this loop trivially (AC3 — no rule markers, so no rule shape can fail).
	for rule_value: Variant in tactical_rules:
		if not rule_value is Dictionary:
			return _invalid(&"tactical_rules")
		var rule: Dictionary = rule_value
		if not _is_lower_snake_id(StringName(String(rule.get(RULE_ID_KEY, "")))):
			return _invalid(&"tactical_rules")
		if String(rule.get(RULE_DESCRIPTION_KEY, "")).strip_edges().is_empty():
			return _invalid(&"tactical_rules")
	# visual_tags entries are lower_snake tag ids — REJECT a non-lower_snake tag (never coerce). The neutral affinity's
	# EMPTY list passes trivially.
	for tag_value: Variant in visual_tags:
		if not _is_lower_snake_id(StringName(String(tag_value))):
			return _invalid(&"visual_tags")
	return ActionResult.ok()


# True for the canonical neutral / no-affinity definition: the AFFINITY_NONE id with an EMPTY tactical_rules set (AC3).
# A consumer (a tactical system querying affinity rules) uses this to branch the no-affinity case without inspecting
# the empty rule list. A real affinity is never neutral (its id is not `none` and it carries >= 1 rule marker).
func is_neutral() -> bool:
	return affinity_id == AFFINITY_NONE and tactical_rules.is_empty()


# A DEEP read-only copy of the recorded rule markers (the RECORD-ONLY tactical_rules data the 7.5 effects layer will
# read). Returns a fresh Array of fresh Dictionaries so a caller can never mutate the definition's stored rules. The
# neutral affinity returns an EMPTY array (AC3 — an empty/neutral rule set, no affinity side effects).
func tactical_rules_copy() -> Array:
	return tactical_rules.duplicate(true)


# A DEEP read-only copy of the visual/cue tag ids (the art/cue hooks). Returns a fresh Array[StringName].
func visual_tags_copy() -> Array[StringName]:
	return visual_tags.duplicate()


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
	return ActionResult.error(&"invalid_affinity_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
