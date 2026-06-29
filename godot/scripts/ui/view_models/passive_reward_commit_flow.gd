class_name PassiveRewardCommitFlow
extends RefCounted

# Story 6.4 — the scene-free Consume/Destroy CONFIRM / TWO-STEP-COMMIT data contract (AC2/AC5). It mirrors
# TacticalAttackCommitFlow's mobile two-step-commit pattern (GDD lines 184-190 "deliberate two-step commit on
# mobile ... Mis-taps are especially punishing"): a RefCounted with a to_dictionary() state, an arm_* that
# ARMS a pending confirmation (surfacing confirm_available / cancel_available cues), a confirm() that COMMITS,
# and a cancel() that clears with ZERO mutation. The Consume/Destroy difference: confirm() produces a
# COMMIT-INTENT data structure (the {choice, passive_content_id, table_id} a LATER 6.5/6.6 caller hands to
# ConsumePassiveCommand / DestroyPassiveCommand) — it does NOT itself execute a command (those commands do not
# exist until 6.5/6.6), emits NO domain event, draws NO RNG, mutates NOTHING.
#
# THE TWO-STEP CONTRACT:
#   - arm_consume(content_id, table_id) / arm_destroy(content_id, table_id): a FIRST tap ARMS a pending
#     confirmation (pending_choice set to "consume"/"destroy", confirm_available = true, cancel_available =
#     true). Re-arming replaces the pending choice (a player switching Consume <-> Destroy before confirming).
#   - confirm(): a SECOND, confirming tap returns the COMMIT-INTENT ({committed: true, choice,
#     passive_content_id, table_id}) and CLEARS the pending state. Confirming with NOTHING armed returns a
#     stable no-op ({committed: false, reason: "no_pending_choice"}) and produces no intent (the
#     TacticalAttackCommitFlow.confirm_attack "no_pending_attack" precedent).
#   - cancel() (AC2): clears the pending confirmation, produces NO commit intent + ZERO mutation (the
#     TacticalAttackCommitFlow.cancel() no-mutation precedent — reward state byte-identical).
#   - dismiss() (AC5): the no-op dismiss (no armed choice required) — clears any transient state, produces no
#     intent, mutates nothing. AC5's "dismissed without choosing executes no command."
#
# WHAT IT IS NOT:
#   - It holds NO RunState / RewardOffer — it is a TRANSIENT view state over the immutable pending offer. It
#     exposes no run/offer/execute/resolve accessor; it CANNOT mutate domain state.
#   - It executes NO Consume/Destroy command, builds NO ConsumePassiveCommand / DestroyPassiveCommand, mutates
#     NO RunState.pending_reward_offer, emits NO event, draws NO RNG (Stories 6.5/6.6, FR82). It produces the
#     commit-INTENT a later command will consume — nothing more.
#   - It is a RefCounted DTO — NOT a Control / Node / scene (UI-scene-last; the real modal scene is a later HUD
#     story).

const CHOICE_NONE := "none"
const CHOICE_CONSUME := "consume"
const CHOICE_DESTROY := "destroy"

# The transient pending-confirmation state. pending_choice is "none" until an arm_* arms one.
var _pending_choice: String = CHOICE_NONE
var _passive_content_id: String = ""
var _table_id: String = ""

# The presenter-safe pending-confirmation state (the TacticalAttackCommitFlow.to_dictionary() precedent).
func to_dictionary() -> Dictionary:
	var armed: bool = _pending_choice != CHOICE_NONE
	return {
		"pending_choice": _pending_choice,
		"passive_content_id": _passive_content_id,
		"table_id": _table_id,
		"confirm_available": armed,
		"cancel_available": armed
	}


# ARM a pending Consume confirmation (the first tap). A second confirm() commits it.
func arm_consume(passive_content_id: StringName, table_id: StringName = &"") -> Dictionary:
	return _arm(CHOICE_CONSUME, passive_content_id, table_id)


# ARM a pending Destroy confirmation (the first tap). A second confirm() commits it.
func arm_destroy(passive_content_id: StringName, table_id: StringName = &"") -> Dictionary:
	return _arm(CHOICE_DESTROY, passive_content_id, table_id)


# COMMIT the armed choice (the second, confirming tap): return the COMMIT-INTENT a later 6.5/6.6 command
# consumes, then CLEAR the pending state. Confirming with nothing armed is a stable no-op (no intent). This
# does NOT execute a command, emit an event, or draw RNG.
func confirm() -> Dictionary:
	if _pending_choice == CHOICE_NONE:
		return {
			"committed": false,
			"choice": CHOICE_NONE,
			"passive_content_id": "",
			"table_id": "",
			"reason": "no_pending_choice"
		}
	var intent: Dictionary = {
		"committed": true,
		"choice": _pending_choice,
		"passive_content_id": _passive_content_id,
		"table_id": _table_id,
		"reason": "committed"
	}
	_clear()
	return intent


# CANCEL the pending confirmation (AC2): clear it, produce NO commit intent, mutate NOTHING.
func cancel() -> Dictionary:
	_clear()
	return {
		"committed": false,
		"choice": CHOICE_NONE,
		"passive_content_id": "",
		"table_id": "",
		"reason": "cancelled"
	}


# DISMISS the modal (AC5): the no-op dismiss path (no armed choice required). Clears any transient state,
# produces no intent, mutates nothing. AC5 "dismissed without choosing executes no command."
func dismiss() -> Dictionary:
	_clear()
	return {
		"committed": false,
		"choice": CHOICE_NONE,
		"passive_content_id": "",
		"table_id": "",
		"reason": "dismissed"
	}


func _arm(choice: String, passive_content_id: StringName, table_id: StringName) -> Dictionary:
	_pending_choice = choice
	_passive_content_id = String(passive_content_id)
	_table_id = String(table_id)
	return to_dictionary()


func _clear() -> void:
	_pending_choice = CHOICE_NONE
	_passive_content_id = ""
	_table_id = ""
