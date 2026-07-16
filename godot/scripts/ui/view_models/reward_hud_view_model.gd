class_name RewardHudViewModel
extends RefCounted

# Story 13.2 — the scene-free REWARD-HUD render projection (AC1/AC2). It PROJECTS the run's PENDING RewardOffer
# into serializable, render-ready data the reward overlay Control reads, and it owns the v0 node -> reward-table
# POLICY (the one genuine presentation-flow decision this story owns). It is a PURE read of the offer + the
# approved passive content — it draws NO RNG, submits NO command, mutates NOTHING, and adds NO key to the pinned
# RewardOffer.DICTIONARY_KEYS / PassiveRewardModalViewModel.MODAL_KEYS (a generic choice reads offered_entries
# directly; a passive choice reuses PassiveRewardModalViewModel.project_offer — the EXISTING Epic-6 contracts).
#
# WHAT IT IS:
#   - project(offer) -> a flat Dictionary keyed by the pinned REWARD_KEYS: has_offer (false for a null/resolved
#     offer -> the empty state, never a crash), is_passive (true when every offered entry is a `passive` entry
#     -> the 3-choice Consume/Destroy moment), table_id, a prompt line, and `choices` (one entry for a generic
#     single-pick; up to three for a passive 3-choice). Each choice carries the pinned CHOICE_KEYS: index,
#     category, content_id, a human label, is_passive, and `modal` (the PassiveRewardModalViewModel MODAL_KEYS
#     projection — identity-absent for a non-passive entry, the full modal for a passive entry).
#   - table_for_node_type(node_type) -> the v0 node -> table policy: a combat node earns a generic single-pick
#     reward (`standard_combat_reward`); an elite node earns the passive Consume/Destroy 3-choice moment
#     (`passive_reward_choice`); every other node type earns NO combat-node reward HUD (their own surfaces own
#     their offers). Deterministic (documented in the story's Completion Notes) so a normal desktop playtest that
#     clears one combat node AND one elite node exercises BOTH a generic reward AND a passive choice.
#
# WHAT IT IS NOT:
#   - It executes NO reward/passive command (that is RewardResolutionBridge — a run-command bridge), holds NO
#     RunState/RewardOffer, and is NOT a Control/Node/scene. It is the render-data contract; the overlay Control
#     wiring is verified by construction (the compile guardrail), and the routing/execution is the bridge.

const PassiveRewardModalViewModel = preload("res://scripts/ui/view_models/passive_reward_modal_view_model.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")

# The `passive` reward category (kept LOCAL — matches RewardTableDefinition.CATEGORY_PASSIVE without a
# cross-dependency; the offered-entry shape carries the category by-id).
const PASSIVE_CATEGORY := "passive"

# The v0 node -> table policy table ids (the three EXISTING baseline reward tables — no new content).
const TABLE_STANDARD_COMBAT := &"standard_combat_reward"
const TABLE_PASSIVE_CHOICE := &"passive_reward_choice"

# The EXACT key set of project() (the exact-key discipline — a key never silently appears/vanishes; a test pins it).
const REWARD_KEYS: Array[String] = [
	"has_offer",
	"is_passive",
	"table_id",
	"prompt",
	"choices"
]

# The EXACT key set of every projected choice (a test pins it).
const CHOICE_KEYS: Array[String] = [
	"index",
	"category",
	"content_id",
	"label",
	"is_passive",
	"modal"
]

const PROMPT_GENERIC := "Reward earned - accept it to continue."
const PROMPT_PASSIVE := "Choose a passive to Consume or Destroy."
const PROMPT_EMPTY := "No reward pending."

var _modal: PassiveRewardModalViewModel = null

func _init(passive_modal: PassiveRewardModalViewModel = null) -> void:
	# Default to the baseline passive modal projection (tests may inject a fixture); it resolves the passive
	# fields through the baseline PassiveRepository.
	_modal = passive_modal if passive_modal != null else PassiveRewardModalViewModel.new()


# Project the run's pending offer into the pinned-key render dict. A null / already-resolved offer projects the
# empty state (has_offer == false, no choices) so the overlay renders nothing without crashing.
func project(offer: RewardOffer) -> Dictionary:
	if offer == null or not offer.is_pending():
		return _empty()
	var passive: bool = is_passive_offer(offer)
	var choices: Array = []
	for index: int in range(offer.offered_entries.size()):
		choices.append(_project_choice(offer, index))
	return {
		"has_offer": true,
		"is_passive": passive,
		"table_id": String(offer.table_id),
		"prompt": PROMPT_PASSIVE if passive else PROMPT_GENERIC,
		"choices": choices
	}


# Whether an offer is the passive 3-choice Consume/Destroy moment: a non-empty offer whose EVERY offered entry is
# a `passive`-category entry (the `passive_reward_choice` table). A generic reward (weapon/armor/gold/etc.) is not.
static func is_passive_offer(offer: RewardOffer) -> bool:
	if offer == null:
		return false
	var entries: Array = offer.offered_entries
	if entries.is_empty():
		return false
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			return false
		if String((entry_value as Dictionary).get("category", "")) != PASSIVE_CATEGORY:
			return false
	return true


# The v0 node -> reward-table policy (the presentation-flow decision this story owns). Returns {has_reward,
# table_id, is_passive}. Deterministic; other node types (shop/event/secret/boss/...) earn NO combat-node reward
# HUD here (their own offer surfaces are out of scope).
static func table_for_node_type(node_type: StringName) -> Dictionary:
	match node_type:
		&"combat":
			return {"has_reward": true, "table_id": TABLE_STANDARD_COMBAT, "is_passive": false}
		&"elite_combat":
			return {"has_reward": true, "table_id": TABLE_PASSIVE_CHOICE, "is_passive": true}
		_:
			return {"has_reward": false, "table_id": &"", "is_passive": false}


# Project ONE offered entry into the pinned CHOICE_KEYS. A passive entry carries the full MODAL_KEYS modal + its
# display name as the label; a generic entry carries an identity-absent modal + a "category: content_id" label.
func _project_choice(offer: RewardOffer, index: int) -> Dictionary:
	var entry_value: Variant = offer.offered_entries[index]
	var entry: Dictionary = entry_value if entry_value is Dictionary else {}
	var category: String = String(entry.get("category", ""))
	var content_id: String = String(entry.get("content_id", ""))
	var is_passive: bool = category == PASSIVE_CATEGORY
	# Reuse the EXISTING Epic-6 passive modal projection (its pinned MODAL_KEYS). A non-passive entry projects
	# identity-absent (has_passive == false) — the same key set, so every choice carries a uniform `modal`.
	var modal: Dictionary = _modal.project_offer(offer, index)
	var label: String
	if is_passive and bool(modal.get("has_passive", false)):
		label = String(modal.get("display_name", content_id))
	else:
		label = "%s: %s" % [category, content_id]
	return {
		"index": index,
		"category": category,
		"content_id": content_id,
		"label": label,
		"is_passive": is_passive,
		"modal": modal
	}


func _empty() -> Dictionary:
	return {
		"has_offer": false,
		"is_passive": false,
		"table_id": "",
		"prompt": PROMPT_EMPTY,
		"choices": []
	}
