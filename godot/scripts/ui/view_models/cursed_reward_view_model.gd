class_name CursedRewardViewModel
extends RefCounted

# Story 7.2 — the scene-free CURSED-REWARD VIEW MODEL (FR55, AC1). It is the thin presentation contract the (future)
# cursed-reward modal SCENE reads: it PROJECTS a cursed reward (resolved through CursedRewardRepository) into
# serializable modal data with an EXACT pinned key contract — a key never silently appears/vanishes (the
# PassiveRewardModalViewModel exact-key discipline; a test pins MODAL_KEYS). It surfaces the AC1 contract BEFORE
# acceptance: the CLEAR UPSIDE (upside_text + the concrete benefit amounts), the CLEAR DOWNSIDE (downside_text + the
# concrete penalty amounts — the curse/corruption increment + any resource cost), and the HONEST hidden/delayed-
# consequence label (has_delayed_consequences + consequences_text, surfaced honestly — NOT hidden, NOT blank).
#
# It is the direct sibling of PassiveRewardModalViewModel (the 6.4 passive-reward modal data contract): same posture,
# same fail-closed discipline, for CursedRewardDefinition instead of PassiveDefinition.
#
# WHAT IT IS:
#   - project_cursed_reward(cursed_reward_id) -> a flat Dictionary keyed by MODAL_KEYS surfacing the AC1 tradeoff
#     fields. It reads the cursed reward through CursedRewardRepository.get_cursed_reward(id) — never FileAccess /
#     load() / JSON.parse in a hot path.
#
# WHAT IT IS NOT:
#   - It owns NO domain truth, submits NO command, draws NO RNG, and mutates nothing — it is a PURE read of approved
#     static content. It does NOT submit the accept command itself (the command bridge / a later HUD story owns the
#     accept call site — the SAME residual the passive modal left).
#   - It is a RefCounted DTO — NOT a Control, NOT a Node, NOT a .tscn / scene / presenter / icon ART (the
#     UI-scene-last rule; the real modal scene is a later HUD story). This is the data contract.
#
# FAIL-CLOSED (the PassiveRewardModalViewModel._identity_absent_modal discipline): an unresolved cursed-reward id
# (null get_cursed_reward) projects an identity-ABSENT modal — the SAME MODAL_KEYS set, empty/default values,
# has_cursed_reward == false — never a crash, never a half-entry. A consumer branches on has_cursed_reward without
# inspecting the empty fields.

const CursedRewardDefinition = preload("res://scripts/content/definitions/cursed_reward_definition.gd")
const CursedRewardRepository = preload("res://scripts/content/repositories/cursed_reward_repository.gd")

# The EXACT key set of every projection (the MODAL_KEYS exact-key discipline). A key never silently
# appears/vanishes — a test pins this. has_cursed_reward gates whether the other fields are meaningful.
const MODAL_KEYS: Array[String] = [
	"has_cursed_reward",
	"cursed_reward_id",
	"display_name",
	"upside_text",
	"gold_benefit",
	"healing_benefit",
	"downside_text",
	"curse_increment",
	"corruption_increment",
	"gold_cost",
	"healing_cost",
	"has_delayed_consequences",
	"consequences_text"
]

var _cursed_reward_repository: CursedRewardRepository = null

func _init(new_cursed_reward_repository: CursedRewardRepository = null) -> void:
	# Default to the baseline cursed-reward repository (the PassiveRewardModalViewModel injection posture; tests
	# inject a fixture repository). Resolves the cursed reward's modal fields through get_cursed_reward(id).
	_cursed_reward_repository = new_cursed_reward_repository if new_cursed_reward_repository != null else CursedRewardRepository.create_baseline_repository()


# Project a cursed reward by its id into the EXACT-MODAL_KEYS modal dict. An unresolved id (null get_cursed_reward)
# projects the identity-absent modal (fail-closed). PURE read: no RNG, no mutation.
func project_cursed_reward(cursed_reward_id: StringName) -> Dictionary:
	var definition: CursedRewardDefinition = _cursed_reward_repository.get_cursed_reward(cursed_reward_id)
	if definition == null:
		return _identity_absent_modal()
	return _project(definition)


# The present-cursed-reward projection: plain String/int/bool data only (no live CursedRewardDefinition handle leaks
# out — the PassiveRewardModalViewModel._project discipline).
func _project(definition: CursedRewardDefinition) -> Dictionary:
	return {
		"has_cursed_reward": true,
		"cursed_reward_id": String(definition.cursed_reward_id),
		"display_name": definition.display_name,
		# The CLEAR UPSIDE (AC1): the upside line + the concrete benefit amounts.
		"upside_text": definition.upside_text,
		"gold_benefit": definition.gold_benefit,
		"healing_benefit": definition.healing_benefit,
		# The CLEAR DOWNSIDE (AC1): the downside line + the concrete penalty amounts (the curse/corruption increment +
		# any resource cost).
		"downside_text": definition.downside_text,
		"curse_increment": definition.curse_increment,
		"corruption_increment": definition.corruption_increment,
		"gold_cost": definition.gold_cost,
		"healing_cost": definition.healing_cost,
		# The HONEST hidden/delayed-consequence label (AC1): surfaced honestly, never hidden/blank.
		"has_delayed_consequences": definition.has_delayed_consequences,
		"consequences_text": definition.consequences_text
	}


# The identity-absent projection (an unresolved/null input): the SAME MODAL_KEYS set, empty/default values,
# has_cursed_reward == false so a consumer can branch without inspecting the empty fields.
func _identity_absent_modal() -> Dictionary:
	return {
		"has_cursed_reward": false,
		"cursed_reward_id": "",
		"display_name": "",
		"upside_text": "",
		"gold_benefit": 0,
		"healing_benefit": 0,
		"downside_text": "",
		"curse_increment": 0,
		"corruption_increment": 0,
		"gold_cost": 0,
		"healing_cost": 0,
		"has_delayed_consequences": false,
		"consequences_text": ""
	}
