class_name AffinityViewModel
extends RefCounted

# Story 7.4 — the scene-free AFFINITY VIEW MODEL (FR56, AC1 readable surface). It is the thin presentation contract the
# (future) affinity badge / inspect-panel SCENE reads: it PROJECTS an affinity (resolved through AffinityRepository)
# into serializable display data with an EXACT pinned key contract — a key never silently appears/vanishes (the
# CursedRewardViewModel / EventViewModel exact-key discipline; a test pins MODAL_KEYS + RULE_KEYS). It surfaces the AC1
# fields: the display_name, the explanation, the recorded tactical_rules (as READ-ONLY descriptive data — NOT executed),
# and the visual_tags (the art/cue hooks).
#
# It is the direct sibling of CursedRewardViewModel (7.2) / EventViewModel (7.3): same posture, same fail-closed
# discipline, for AffinityDefinition.
#
# WHAT IT IS:
#   - project_affinity(affinity_id) -> a Dictionary keyed by MODAL_KEYS surfacing the affinity's display fields + a
#     `tactical_rules` Array of per-rule dicts (each keyed by RULE_KEYS) + the `visual_tags` String list. It reads the
#     affinity through AffinityRepository.get_affinity(id) — never FileAccess / load() / JSON.parse in a hot path.
#
# WHAT IT IS NOT:
#   - It owns NO domain truth, submits NO command, draws NO RNG, and mutates nothing — it is a PURE read of approved
#     static content. It does NOT APPLY any affinity effect (the Scorched DoT / Flooded pathing / Cursed hooks / Darkness
#     fairness are 7.5/7.6; this surface only DESCRIBES the recorded rule data). The recorded tactical_rules are surfaced
#     as descriptive data the player/debug can read, NOT executed.
#   - It is a RefCounted DTO — NOT a Control, NOT a Node, NOT a .tscn / scene / presenter / icon ART (the UI-scene-last
#     rule; the real affinity badge + inspect surface are a later HUD story). This is the data contract.
#
# FAIL-CLOSED (the CursedRewardViewModel._identity_absent_modal discipline): an unresolved affinity id (null
# get_affinity) projects an identity-ABSENT modal — the SAME MODAL_KEYS set, empty/default values, an EMPTY
# tactical_rules + visual_tags list, has_affinity == false — never a crash, never a half-entry. A consumer branches on
# has_affinity without inspecting the empty fields.

const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")

# The EXACT top-level key set of every projection (the MODAL_KEYS exact-key discipline). has_affinity gates whether the
# other fields are meaningful; is_neutral surfaces the AC3 neutral/no-affinity case.
const MODAL_KEYS: Array[String] = [
	"has_affinity",
	"affinity_id",
	"display_name",
	"explanation",
	"is_neutral",
	"tactical_rules",
	"visual_tags"
]

# The EXACT per-rule key set (each entry in the `tactical_rules` Array). Surfaces the RECORD-ONLY rule marker (a
# lower_snake rule id + a readable description) as descriptive data — NOT an executable operation.
const RULE_KEYS: Array[String] = [
	"rule_id",
	"description"
]

var _affinity_repository: AffinityRepository = null

func _init(new_affinity_repository: AffinityRepository = null) -> void:
	# Default to the baseline affinity repository (the CursedRewardViewModel injection posture; tests inject a fixture
	# repository). Resolves the affinity's display fields through get_affinity(id).
	_affinity_repository = new_affinity_repository if new_affinity_repository != null else AffinityRepository.create_baseline_repository()


# Project an affinity by its id into the EXACT-MODAL_KEYS modal dict. An unresolved id (null get_affinity) projects the
# identity-absent modal (fail-closed). PURE read: no RNG, no mutation.
func project_affinity(affinity_id: StringName) -> Dictionary:
	var definition: AffinityDefinition = _affinity_repository.get_affinity(affinity_id)
	if definition == null:
		return _identity_absent_modal()
	return _project(definition)


# The present-affinity projection: plain String/bool/Array data only (no live AffinityDefinition handle leaks out — the
# CursedRewardViewModel._project discipline).
func _project(definition: AffinityDefinition) -> Dictionary:
	var rules: Array = []
	for rule_value: Variant in definition.tactical_rules:
		if not rule_value is Dictionary:
			continue
		var rule: Dictionary = rule_value
		rules.append({
			"rule_id": String(rule.get(AffinityDefinition.RULE_ID_KEY, "")),
			"description": String(rule.get(AffinityDefinition.RULE_DESCRIPTION_KEY, ""))
		})
	var tags: Array = []
	for tag_value: Variant in definition.visual_tags:
		tags.append(String(tag_value))
	return {
		"has_affinity": true,
		"affinity_id": String(definition.affinity_id),
		"display_name": definition.display_name,
		"explanation": definition.explanation,
		"is_neutral": definition.is_neutral(),
		# The RECORD-ONLY tactical rule data (AC1), surfaced as descriptive data — NOT executed (7.5/7.6 own effects).
		"tactical_rules": rules,
		# The art/cue hooks (AC1) — plain Strings.
		"visual_tags": tags
	}


# The identity-absent projection (an unresolved/null input): the SAME MODAL_KEYS set, empty/default values, an EMPTY
# tactical_rules + visual_tags list, has_affinity == false so a consumer can branch without inspecting the empty fields.
func _identity_absent_modal() -> Dictionary:
	return {
		"has_affinity": false,
		"affinity_id": "",
		"display_name": "",
		"explanation": "",
		"is_neutral": false,
		"tactical_rules": [],
		"visual_tags": []
	}
