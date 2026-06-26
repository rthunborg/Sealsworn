extends "res://tests/unit/test_case.gd"

# Story 6.4 — PassiveRewardCommitFlow (the scene-free Consume/Destroy CONFIRM / two-step-commit data
# contract, AC2/AC5). It mirrors TacticalAttackCommitFlow: a RefCounted with a to_dictionary() state, an
# arm_* that ARMS a pending confirmation (confirm_available/cancel_available cues), a confirm() that returns a
# COMMIT-INTENT (it does NOT execute a command — the Consume/Destroy commands are 6.5/6.6), a cancel() that
# clears the pending state with ZERO mutation + ZERO intent, and a dismiss() no-op.
#
# Pins: the empty/cleared initial state; arm_consume -> a pending consume confirmation; arm_destroy -> a
# pending destroy confirmation; confirm -> a {choice, passive_content_id, table_id} commit-intent + the
# pending state cleared; confirm with nothing armed -> a stable no-op reason + NO intent; cancel -> cleared,
# NO intent (AC2); dismiss -> cleared, NO intent (AC5); the flow holds NO RunState/RewardOffer (it cannot
# mutate one); AND the AC2/AC5 no-mutation + reopen-reproduces proof (a pending RewardOffer is byte-identical
# after arm+cancel / dismiss, and a freshly-built modal from the same offer reproduces byte-identically).

const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const PassiveRewardCommitFlow = preload("res://scripts/ui/view_models/passive_reward_commit_flow.gd")
const PassiveRewardModalViewModel = preload("res://scripts/ui/view_models/passive_reward_modal_view_model.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")

func run() -> Dictionary:
	_initial_state_is_empty()
	_arm_consume_arms_a_pending_consume_confirmation()
	_arm_destroy_arms_a_pending_destroy_confirmation()
	_confirm_consume_yields_a_consume_commit_intent()
	_confirm_destroy_yields_a_destroy_commit_intent()
	_confirm_with_nothing_armed_is_a_stable_no_op()
	_cancel_clears_the_pending_state_without_intent()
	_dismiss_is_a_no_op()
	_re_arming_replaces_the_pending_choice()
	_arm_cancel_leaves_the_offer_byte_identical_and_reopen_reproduces()
	_dismiss_leaves_the_offer_byte_identical()
	_flow_holds_no_run_or_offer_state()
	return result()


func _pending_offer() -> RewardOffer:
	return RewardOffer.new(
		&"passive_reward_choice",
		RewardOffer.STATUS_PENDING,
		[
			{"category": "passive", "content_id": "warrior_unbreakable_guard"},
			{"category": "passive", "content_id": "pyromancer_kindling_focus"},
			{"category": "passive", "content_id": "ranger_steady_aim"}
		]
	)


func _initial_state_is_empty() -> void:
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	var state: Dictionary = flow.to_dictionary()
	assert_equal(state.get("pending_choice"), "none", "A fresh flow should have no pending choice.")
	assert_equal(state.get("confirm_available"), false, "A fresh flow should not offer confirm.")
	assert_equal(state.get("cancel_available"), false, "A fresh flow should not offer cancel.")
	assert_equal(state.get("passive_content_id"), "", "A fresh flow should carry no passive content id.")
	assert_equal(state.get("table_id"), "", "A fresh flow should carry no table id.")


func _arm_consume_arms_a_pending_consume_confirmation() -> void:
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	flow.arm_consume(&"warrior_unbreakable_guard", &"passive_reward_choice")
	var state: Dictionary = flow.to_dictionary()
	assert_equal(state.get("pending_choice"), "consume", "arm_consume should arm a pending consume confirmation.")
	assert_equal(state.get("confirm_available"), true, "An armed confirmation should offer confirm.")
	assert_equal(state.get("cancel_available"), true, "An armed confirmation should offer cancel.")
	assert_equal(state.get("passive_content_id"), "warrior_unbreakable_guard", "The armed flow should carry the passive content id.")
	assert_equal(state.get("table_id"), "passive_reward_choice", "The armed flow should carry the table id.")


func _arm_destroy_arms_a_pending_destroy_confirmation() -> void:
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	flow.arm_destroy(&"ranger_steady_aim", &"passive_reward_choice")
	var state: Dictionary = flow.to_dictionary()
	assert_equal(state.get("pending_choice"), "destroy", "arm_destroy should arm a pending destroy confirmation.")
	assert_equal(state.get("confirm_available"), true, "An armed destroy confirmation should offer confirm.")
	assert_equal(state.get("cancel_available"), true, "An armed destroy confirmation should offer cancel.")
	assert_equal(state.get("passive_content_id"), "ranger_steady_aim", "The armed destroy flow should carry the passive content id.")


func _confirm_consume_yields_a_consume_commit_intent() -> void:
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	flow.arm_consume(&"warrior_unbreakable_guard", &"passive_reward_choice")
	var intent: Dictionary = flow.confirm()
	assert_equal(intent.get("committed"), true, "Confirming an armed consume should produce a committed intent.")
	assert_equal(intent.get("choice"), "consume", "The commit-intent should carry the consume choice.")
	assert_equal(intent.get("passive_content_id"), "warrior_unbreakable_guard", "The commit-intent should carry the passive content id.")
	assert_equal(intent.get("table_id"), "passive_reward_choice", "The commit-intent should carry the table id.")
	# After producing the intent, the pending state is cleared (a second confirm is a no-op).
	assert_equal(flow.to_dictionary().get("pending_choice"), "none", "Confirm should clear the pending state after producing the intent.")
	var second: Dictionary = flow.confirm()
	assert_equal(second.get("committed"), false, "A second confirm with nothing armed should be a no-op.")


func _confirm_destroy_yields_a_destroy_commit_intent() -> void:
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	flow.arm_destroy(&"pyromancer_kindling_focus", &"passive_reward_choice")
	var intent: Dictionary = flow.confirm()
	assert_equal(intent.get("committed"), true, "Confirming an armed destroy should produce a committed intent.")
	assert_equal(intent.get("choice"), "destroy", "The commit-intent should carry the destroy choice.")
	assert_equal(intent.get("passive_content_id"), "pyromancer_kindling_focus", "The destroy commit-intent should carry the passive content id.")


func _confirm_with_nothing_armed_is_a_stable_no_op() -> void:
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	var intent: Dictionary = flow.confirm()
	assert_equal(intent.get("committed"), false, "Confirming with nothing armed should not commit.")
	assert_equal(intent.get("choice"), "none", "A no-op confirm should carry no choice.")
	assert_equal(intent.get("reason"), "no_pending_choice", "A no-op confirm should expose a stable reason.")
	assert_equal(flow.to_dictionary().get("pending_choice"), "none", "A no-op confirm should leave the flow cleared.")


func _cancel_clears_the_pending_state_without_intent() -> void:
	# AC2: canceling a pending confirmation clears it and emits NO command intent.
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	flow.arm_consume(&"warrior_unbreakable_guard", &"passive_reward_choice")
	var cancel_result: Dictionary = flow.cancel()
	assert_equal(cancel_result.get("committed"), false, "Cancel should not produce a commit intent (AC2).")
	assert_equal(cancel_result.get("reason"), "cancelled", "Cancel should expose a stable reason.")
	var state: Dictionary = flow.to_dictionary()
	assert_equal(state.get("pending_choice"), "none", "Cancel should clear the pending choice.")
	assert_equal(state.get("confirm_available"), false, "Cancel should withdraw confirm.")
	assert_equal(state.get("cancel_available"), false, "Cancel should withdraw cancel.")


func _dismiss_is_a_no_op() -> void:
	# AC5: dismissing the modal (distinct from canceling a pending confirmation) produces NO intent + clears any
	# transient state. Dismiss is valid with NOTHING armed (the no-op dismiss path).
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	var dismiss_unarmed: Dictionary = flow.dismiss()
	assert_equal(dismiss_unarmed.get("committed"), false, "Dismiss with nothing armed should be a no-op.")
	assert_equal(dismiss_unarmed.get("reason"), "dismissed", "Dismiss should expose a stable reason.")
	# Dismiss also clears an armed pending confirmation (no intent).
	flow.arm_destroy(&"ranger_steady_aim", &"passive_reward_choice")
	var dismiss_armed: Dictionary = flow.dismiss()
	assert_equal(dismiss_armed.get("committed"), false, "Dismiss should not produce a commit intent even when armed (AC5).")
	assert_equal(flow.to_dictionary().get("pending_choice"), "none", "Dismiss should clear any armed pending state.")


func _re_arming_replaces_the_pending_choice() -> void:
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	flow.arm_consume(&"warrior_unbreakable_guard", &"passive_reward_choice")
	flow.arm_destroy(&"ranger_steady_aim", &"passive_reward_choice")
	var state: Dictionary = flow.to_dictionary()
	assert_equal(state.get("pending_choice"), "destroy", "Re-arming should replace the pending choice.")
	assert_equal(state.get("passive_content_id"), "ranger_steady_aim", "Re-arming should replace the pending passive content id.")


# AC2/AC5 no-mutation + reopen-reproduces: arming + canceling (or dismissing) leaves the pending RewardOffer
# BYTE-IDENTICAL, and a freshly-built modal from the SAME offer reproduces byte-identically (reopen).
func _arm_cancel_leaves_the_offer_byte_identical_and_reopen_reproduces() -> void:
	var offer: RewardOffer = _pending_offer()
	var before: Dictionary = offer.to_dictionary()
	var modal: PassiveRewardModalViewModel = PassiveRewardModalViewModel.new(PassiveRepository.create_baseline_repository())
	var first_projection: Dictionary = modal.project_offer(offer, 0)

	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	flow.arm_consume(&"warrior_unbreakable_guard", &"passive_reward_choice")
	flow.cancel()

	assert_equal(offer.to_dictionary(), before, "Arm + cancel must leave the pending offer byte-identical (AC2).")
	assert_true(offer.is_pending(), "The offer must stay pending after a cancelled confirmation.")
	# Reopen: a freshly-built modal from the SAME unchanged offer reproduces the first projection byte-identically.
	var reopen_modal: PassiveRewardModalViewModel = PassiveRewardModalViewModel.new(PassiveRepository.create_baseline_repository())
	var reopen_projection: Dictionary = reopen_modal.project_offer(offer, 0)
	assert_equal(reopen_projection, first_projection, "Reopening the modal from the unchanged offer must reproduce the projection byte-identically (AC5).")


func _dismiss_leaves_the_offer_byte_identical() -> void:
	var offer: RewardOffer = _pending_offer()
	var before: Dictionary = offer.to_dictionary()
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	flow.arm_destroy(&"ranger_steady_aim", &"passive_reward_choice")
	flow.dismiss()
	assert_equal(offer.to_dictionary(), before, "Arm + dismiss must leave the pending offer byte-identical (AC5).")
	assert_true(offer.is_pending(), "The offer must stay pending after a dismiss.")


func _flow_holds_no_run_or_offer_state() -> void:
	# The flow is a transient view state — it exposes NO RunState/RewardOffer accessor (it cannot mutate one).
	var flow: PassiveRewardCommitFlow = PassiveRewardCommitFlow.new()
	for forbidden: String in ["run", "run_state", "offer", "reward_offer", "execute", "resolve"]:
		assert_false(flow.has_method(forbidden), "The commit flow must not expose a '%s' method (it holds no domain state)." % forbidden)
