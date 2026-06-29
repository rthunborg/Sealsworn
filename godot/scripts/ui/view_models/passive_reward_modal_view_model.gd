class_name PassiveRewardModalViewModel
extends RefCounted

# Story 6.4 — the scene-free PASSIVE-REWARD MODAL projection (FR47, AC1/AC5). It is the thin presentation
# contract the (future) passive-reward modal SCENE reads: it PROJECTS an OFFERED passive (resolved through
# PassiveRepository) into serializable modal data with an EXACT pinned key contract — a key never silently
# appears/vanishes (the ClassStartSummaryViewModel / HeroSelectViewModel exact-key discipline; a test pins
# MODAL_KEYS).
#
# WHAT IT IS:
#   - project_passive(content_id) -> a flat Dictionary keyed by MODAL_KEYS surfacing the FR47 fields (icon,
#     display_name = the evocative name, flavor = one short line, exact_mechanical_effects = the EXPLICIT
#     mechanics, consume_text, destroy_text) + the honest-unknown downside surface (has_unknown_consequences +
#     consequences_text). It reads the passive through PassiveRepository.get_passive(id) — never FileAccess /
#     load() / JSON.parse in a hot path.
#   - project_offer_entry(entry) -> projects a single OFFERED {category, content_id} entry (the Story-6.3
#     offered-entry shape); a non-"passive" category, a malformed/empty entry, or an unresolved content_id all
#     project identity-absent.
#   - project_offer(offer, index) -> projects the offered passive at `index` of a RewardOffer's offered_entries
#     (the AC4 passive 3-choice — three entries); a null offer or an out-of-range index projects identity-absent.
#
# WHAT IT IS NOT:
#   - It owns NO domain truth, submits NO command, draws NO RNG, and mutates nothing — it is a PURE read of
#     approved static content + the run's pending offer. It NEVER mutates RunState.pending_reward_offer.
#   - It is a RefCounted DTO — NOT a Control, NOT a Node, NOT a .tscn / scene / presenter / icon ART (the
#     UI-scene-last rule; the real modal scene + the icon assets are a later HUD/asset story). This is the data
#     contract — the `icon` field is an id/placeholder STRING, not art.
#   - It produces NO Consume/Destroy command (those are Stories 6.5/6.6). The Consume/Destroy CONFIRM /
#     two-step-commit data contract is PassiveRewardCommitFlow (a sibling RefCounted); the executed commands are
#     6.5/6.6.
#
# FAIL-CLOSED (the ClassStartSummaryViewModel._identity_absent_summary / HeroSelectViewModel fail-closed-skip
# discipline): an unresolved passive id (null get_passive), a non-passive entry, a malformed/empty entry, a
# null/absent offer, or an out-of-range index ALL project an identity-ABSENT modal — the SAME MODAL_KEYS set,
# empty/default values, has_passive == false — never a crash, never a half-entry. A consumer branches on
# has_passive without inspecting the empty fields.

const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")

# The EXACT key set of every projection (the SUMMARY_KEYS / ENTRY_KEYS exact-key discipline). A key never
# silently appears/vanishes — a test pins this. has_passive gates whether the other fields are meaningful.
const MODAL_KEYS: Array[String] = [
	"has_passive",
	"passive_id",
	"icon",
	"display_name",
	"flavor",
	"exact_mechanical_effects",
	"consume_text",
	"destroy_text",
	"has_unknown_consequences",
	"consequences_text"
]

var _passive_repository: PassiveRepository = null

func _init(new_passive_repository: PassiveRepository = null) -> void:
	# Default to the baseline passive repository (the HeroSelectViewModel / ClassStartSummaryViewModel injection
	# posture; tests inject a fixture repository). Resolves the passive's modal fields through get_passive(id).
	_passive_repository = new_passive_repository if new_passive_repository != null else PassiveRepository.create_baseline_repository()


# Project an offered passive by its content id into the EXACT-MODAL_KEYS modal dict. An unresolved id (null
# get_passive) projects the identity-absent modal (fail-closed). PURE read: no RNG, no mutation.
func project_passive(content_id: StringName) -> Dictionary:
	var definition: PassiveDefinition = _passive_repository.get_passive(content_id)
	if definition == null:
		return _identity_absent_modal()
	return _project(definition)


# Project a single OFFERED {category, content_id} entry (the Story-6.3 offered-entry shape). Only a
# "passive"-category entry with a resolvable content_id projects a present passive; anything else fail-closes.
func project_offer_entry(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return _identity_absent_modal()
	var entry_dict: Dictionary = entry
	# Only a passive-category entry is a passive — a weapon/armor/etc entry is NOT (fail-closed, never a mix).
	if StringName(String(entry_dict.get("category", ""))) != RewardTableDefinition.CATEGORY_PASSIVE:
		return _identity_absent_modal()
	if not entry_dict.has("content_id"):
		return _identity_absent_modal()
	return project_passive(StringName(String(entry_dict.get("content_id", ""))))


# Project the offered passive at `index` of a RewardOffer's offered_entries (the AC4 passive 3-choice). A null
# offer or an out-of-range index projects identity-absent. The offer is READ ONLY — never mutated.
func project_offer(offer: RewardOffer, index: int) -> Dictionary:
	if offer == null:
		return _identity_absent_modal()
	var entries: Array = offer.offered_entries
	if index < 0 or index >= entries.size():
		return _identity_absent_modal()
	return project_offer_entry(entries[index])


# The present-passive projection: plain String/bool data only (no live PassiveDefinition handle leaks out —
# the HeroSelectViewModel._project_entry discipline).
func _project(definition: PassiveDefinition) -> Dictionary:
	return {
		"has_passive": true,
		"passive_id": String(definition.passive_id),
		"icon": String(definition.icon),
		"display_name": definition.display_name,
		"flavor": definition.flavor,
		"exact_mechanical_effects": definition.exact_mechanical_effects,
		"consume_text": definition.consume_text,
		"destroy_text": definition.destroy_text,
		"has_unknown_consequences": definition.has_unknown_consequences,
		"consequences_text": definition.consequences_text
	}


# The identity-absent projection (an unresolved/non-passive/null input): the SAME MODAL_KEYS set, empty/default
# values, has_passive == false so a consumer can branch without inspecting the empty fields.
func _identity_absent_modal() -> Dictionary:
	return {
		"has_passive": false,
		"passive_id": "",
		"icon": "",
		"display_name": "",
		"flavor": "",
		"exact_mechanical_effects": "",
		"consume_text": "",
		"destroy_text": "",
		"has_unknown_consequences": false,
		"consequences_text": ""
	}
