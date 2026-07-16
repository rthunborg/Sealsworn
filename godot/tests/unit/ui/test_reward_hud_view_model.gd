extends "res://tests/unit/test_case.gd"

# Story 13.2 — RewardHudViewModel (the scene-free, exact-key reward-HUD render projection + the v0 node -> table
# policy, AC1/AC2). Pins:
#   - the EXACT REWARD_KEYS / CHOICE_KEYS sets (a key never silently appears/vanishes);
#   - a null / already-resolved offer projects the empty state (has_offer == false, no choices — no crash);
#   - a GENERIC single-pick offer projects has_offer/one choice/is_passive == false + a "category: content_id"
#     label + an identity-absent modal (reusing the pinned MODAL_KEYS, adding no key);
#   - a PASSIVE 3-choice offer projects is_passive == true / three choices, each carrying the full MODAL_KEYS
#     modal (has_passive == true) + the passive display name as the label;
#   - is_passive_offer detection (generic false, passive true, empty false);
#   - the v0 node -> table policy (combat -> standard single-pick; elite -> passive 3-choice; other -> no reward).

const PassiveRewardModalViewModel = preload("res://scripts/ui/view_models/passive_reward_modal_view_model.gd")
const RewardHudViewModel = preload("res://scripts/ui/view_models/reward_hud_view_model.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")

func run() -> Dictionary:
	_reward_keys_are_exact_for_a_generic_offer()
	_reward_keys_are_exact_for_the_empty_state()
	_choice_keys_are_exact()
	_null_offer_projects_the_empty_state()
	_resolved_offer_projects_the_empty_state()
	_generic_offer_projects_one_non_passive_choice()
	_passive_offer_projects_three_passive_choices_with_modals()
	_is_passive_offer_detection()
	_node_table_policy_maps_combat_elite_and_defaults()
	return result()


# ---- fixtures ------------------------------------------------------------------------------------

func _generic_offer() -> RewardOffer:
	return RewardOffer.new(&"standard_combat_reward", RewardOffer.STATUS_PENDING, [
		{"category": "weapon", "content_id": "sword"}
	])


func _passive_offer() -> RewardOffer:
	return RewardOffer.new(&"passive_reward_choice", RewardOffer.STATUS_PENDING, [
		{"category": "passive", "content_id": "warrior_unbreakable_guard"},
		{"category": "passive", "content_id": "pyromancer_kindling_focus"},
		{"category": "passive", "content_id": "ranger_hunters_quiver"}
	])


func _assert_exact_keys(actual: Dictionary, expected: Array, message: String) -> void:
	var keys: Array = actual.keys()
	keys.sort()
	var want: Array = expected.duplicate()
	want.sort()
	assert_equal(keys, want, message)


# ---- exact-key discipline ------------------------------------------------------------------------

func _reward_keys_are_exact_for_a_generic_offer() -> void:
	var projection: Dictionary = RewardHudViewModel.new().project(_generic_offer())
	_assert_exact_keys(projection, RewardHudViewModel.REWARD_KEYS, "A generic-offer projection must carry EXACTLY the REWARD_KEYS set.")


func _reward_keys_are_exact_for_the_empty_state() -> void:
	var projection: Dictionary = RewardHudViewModel.new().project(null)
	_assert_exact_keys(projection, RewardHudViewModel.REWARD_KEYS, "The empty-state projection must carry the SAME REWARD_KEYS set.")


func _choice_keys_are_exact() -> void:
	var projection: Dictionary = RewardHudViewModel.new().project(_passive_offer())
	var choices: Array = projection.get("choices", [])
	assert_false(choices.is_empty(), "A passive offer must project choices.")
	for choice_value: Variant in choices:
		_assert_exact_keys(choice_value as Dictionary, RewardHudViewModel.CHOICE_KEYS, "Every projected choice must carry EXACTLY the CHOICE_KEYS set.")


# ---- empty state ---------------------------------------------------------------------------------

func _null_offer_projects_the_empty_state() -> void:
	var projection: Dictionary = RewardHudViewModel.new().project(null)
	assert_equal(projection.get("has_offer"), false, "A null offer projects has_offer == false.")
	assert_equal((projection.get("choices") as Array).size(), 0, "A null offer projects no choices.")


func _resolved_offer_projects_the_empty_state() -> void:
	# A RESOLVED offer is no longer pending -> the empty state (the HUD renders nothing; the flow advanced).
	var resolved: RewardOffer = RewardOffer.new(&"standard_combat_reward", RewardOffer.STATUS_RESOLVED, [
		{"category": "weapon", "content_id": "sword"}
	])
	var projection: Dictionary = RewardHudViewModel.new().project(resolved)
	assert_equal(projection.get("has_offer"), false, "A resolved (non-pending) offer projects the empty state.")


# ---- generic offer -------------------------------------------------------------------------------

func _generic_offer_projects_one_non_passive_choice() -> void:
	var projection: Dictionary = RewardHudViewModel.new().project(_generic_offer())
	assert_equal(projection.get("has_offer"), true, "A pending offer projects has_offer == true.")
	assert_equal(projection.get("is_passive"), false, "A weapon offer is NOT a passive offer.")
	assert_equal(String(projection.get("table_id")), "standard_combat_reward", "The projection carries the table id.")
	var choices: Array = projection.get("choices", [])
	assert_equal(choices.size(), 1, "A single-pick offer projects exactly one choice.")
	var choice: Dictionary = choices[0]
	assert_equal(String(choice.get("category")), "weapon", "The choice carries the offered category.")
	assert_equal(String(choice.get("content_id")), "sword", "The choice carries the offered content id.")
	assert_equal(choice.get("is_passive"), false, "A weapon choice is not passive.")
	assert_equal(String(choice.get("label")), "weapon: sword", "The generic label is category: content_id.")
	# A non-passive choice carries an identity-absent modal (the SAME MODAL_KEYS set, has_passive == false).
	var modal: Dictionary = choice.get("modal", {})
	assert_equal(modal.get("has_passive"), false, "A non-passive choice modal is identity-absent.")
	var modal_keys: Array = modal.keys()
	modal_keys.sort()
	var expected_modal_keys: Array = PassiveRewardModalViewModel.MODAL_KEYS.duplicate()
	expected_modal_keys.sort()
	assert_equal(modal_keys, expected_modal_keys, "The choice modal reuses the pinned MODAL_KEYS set (adds no key).")


# ---- passive offer -------------------------------------------------------------------------------

func _passive_offer_projects_three_passive_choices_with_modals() -> void:
	var projection: Dictionary = RewardHudViewModel.new().project(_passive_offer())
	assert_equal(projection.get("is_passive"), true, "A 3-passive-entry offer is a passive offer.")
	var choices: Array = projection.get("choices", [])
	assert_equal(choices.size(), 3, "A passive 3-choice offer projects three choices.")
	for choice_value: Variant in choices:
		var choice: Dictionary = choice_value
		assert_equal(choice.get("is_passive"), true, "Every passive-offer choice is passive.")
		assert_equal(String(choice.get("category")), "passive", "Every passive-offer choice carries the passive category.")
		var modal: Dictionary = choice.get("modal", {})
		assert_equal(modal.get("has_passive"), true, "A passive choice carries a present modal.")
		# The label is the evocative display name (not the raw id) for a resolved passive.
		assert_equal(String(choice.get("label")), String(modal.get("display_name")), "A passive choice label is the display name.")
		assert_false(String(choice.get("label")).strip_edges().is_empty(), "A resolved passive label must be non-empty.")


# ---- detection + policy --------------------------------------------------------------------------

func _is_passive_offer_detection() -> void:
	assert_equal(RewardHudViewModel.is_passive_offer(_passive_offer()), true, "An all-passive offer is a passive offer.")
	assert_equal(RewardHudViewModel.is_passive_offer(_generic_offer()), false, "A weapon offer is not a passive offer.")
	assert_equal(RewardHudViewModel.is_passive_offer(null), false, "A null offer is not a passive offer.")
	var empty_offer: RewardOffer = RewardOffer.new(&"empty", RewardOffer.STATUS_PENDING, [])
	assert_equal(RewardHudViewModel.is_passive_offer(empty_offer), false, "An empty offer is not a passive offer.")


func _node_table_policy_maps_combat_elite_and_defaults() -> void:
	var combat: Dictionary = RewardHudViewModel.table_for_node_type(&"combat")
	assert_equal(combat.get("has_reward"), true, "A combat node earns a reward.")
	assert_equal(combat.get("table_id"), &"standard_combat_reward", "A combat node earns the standard single-pick reward.")
	assert_equal(combat.get("is_passive"), false, "A combat node earns a generic (non-passive) reward.")

	var elite: Dictionary = RewardHudViewModel.table_for_node_type(&"elite_combat")
	assert_equal(elite.get("has_reward"), true, "An elite node earns a reward.")
	assert_equal(elite.get("table_id"), &"passive_reward_choice", "An elite node earns the passive 3-choice moment.")
	assert_equal(elite.get("is_passive"), true, "An elite node earns the passive Consume/Destroy reward.")

	for other: StringName in [&"shop", &"event", &"secret", &"boss", &"reforge", &"gambling"]:
		var policy: Dictionary = RewardHudViewModel.table_for_node_type(other)
		assert_equal(policy.get("has_reward"), false, "Node type %s earns NO combat-node reward HUD." % String(other))
