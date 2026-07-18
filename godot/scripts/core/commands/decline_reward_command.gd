class_name DeclineRewardCommand
extends "res://scripts/core/commands/game_command.gd"

# The reward-DECLINE command (Story 14.7) — a RUN-domain command that CLEARS the run's PENDING reward offer WITHOUT
# applying it and flips the offer to `resolved`, breaking the full-backpack soft-lock (a backpack-category reward
# resolved against a FULL backpack returns inventory_full and — correctly, fail-closed — leaves the offer `pending`,
# which the generic overlay could otherwise only re-trigger, with no player escape). The decline is the minimal escape
# hatch: it NEVER touches the backpack/inventory/economy, so it can NEVER hit inventory_full and it does NOT weaken the
# fail-closed guard (ResolveRewardCommand / PickupItemCommand are untouched) — declining simply forfeits the reward.
#
# It follows the 4.3-ratified run-command idiom VERBATIM (the ResolveRewardCommand / AcceptCursedRewardCommand
# template): it extends game_command.gd, takes the live RunState DIRECTLY as its validate(state)/execute(state) arg (NO
# wrapper), the CALLER supplies the run-level sequence_id via the constructor (default 1), validate() rejects
# sequence_id <= 0 FIRST so a success path can never emit an event its own validator rejects, and it is
# validate-then-mutate: on ANY rejection it returns a structured ActionResult.error with ZERO events and a
# byte-identical no-mutation RunState; it flips the offer + builds the reward_declined event ONLY AFTER validation.
#
# IT DRAWS ZERO RNG. A decline is a deterministic disposition — the player dismisses an already-generated offer, so no
# RandomNumberGenerator, no randi/randf, no stream draw. It is the SIMPLEST member of the reward-command family: it
# applies NOTHING (no PickupItemCommand, no gold credit, no curse) — it just flips the offer status + records the
# decline event.
#
# DECLINE SELECTS NO ENTRY. Unlike ResolveRewardCommand, the command takes NO category/content_id — a decline picks no
# offered entry (it clears the whole pending offer), so selected_entry stays {} (declined = no selection recorded) and
# NO item_gained / economy_changed event is emitted. A declined reward therefore correctly contributes NO notable_loot
# to RunSummary (which single-sources notable loot from item_gained). It is offer-type-agnostic (it clears whatever
# pending offer exists), but only the GENERIC overlay routes to it — a passive offer never can (it always resolves via
# Consume/Destroy), so each offer still resolves via EXACTLY ONE command (a second decline hits
# reward_offer_already_resolved; no double-record). [Decision]
#
# NO SAVE-SCHEMA CHANGE. The offer rides RunState.to_dictionary()'s existing `pending_reward_offer` key; the decline
# flips only the existing RewardOffer.status (pending -> resolved, an already-valid value) and selected_entry (-> {},
# an already-valid value). It adds NO RewardOffer.DICTIONARY_KEYS entry, NO RunState field, NO RunSnapshot key: the
# 23-key RunSnapshot gate stays 23, SCHEMA_VERSION == 1.

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# Story 14.7: the lower_snake `reason` marker recorded on the reward_declined event payload (the AC2 reason). Kept
# DISTINCT from the event id (`reward_declined`) so the reason names the disposition, not the record type — the
# player actively declined the offer.
const DECLINE_REASON := &"player_declined"

var sequence_id: int = 1

func _init(new_sequence_id: int = 1) -> void:
	command_id = &"decline_reward"
	sequence_id = new_sequence_id


# Pure read: validate the sequence id, context, and a pending unresolved offer. No mutation, no event, no RNG. Shares
# the SAME reject codes as ResolveRewardCommand for the absent/resolved-offer cases (the no-double-resolve guard).
# There is NO entry-selection check (a decline selects nothing) and NO economy check (a decline credits no gold).
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the ResolveRewardCommand precedent): execute() builds a reward_declined event with this
	# sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id would make the
	# success path emit a non-round-trippable event. Reject it BEFORE any state is read or mutated.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	# The run must be structurally sound before we resolve into it.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# There must be a PENDING, UNRESOLVED offer to decline.
	var offer: RewardOffer = run.pending_reward_offer
	if offer == null:
		return ActionResult.error(&"no_pending_reward_offer", {
			"command": String(command_id)
		})
	if offer.is_resolved():
		# The no-double-resolve reject: a decline against a `resolved` offer fails closed (the offer/table id rides
		# metadata; the code carries no arbitrary id). Shares the resolve command's stable code.
		return ActionResult.error(&"reward_offer_already_resolved", {
			"command": String(command_id),
			"table_id": String(offer.table_id)
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: flip the offer to `resolved` with NO recorded selection (selected_entry = {}) and
# emit the reward_declined event (built AFTER the mutation). On any reject: structured error, ZERO events,
# byte-identical RunState. Draws ZERO RNG. Composes NO PickupItemCommand, credits NO gold, touches the
# backpack/inventory/economy NOT AT ALL — this is exactly what makes the decline immune to inventory_full and what
# keeps the fail-closed guard untouched.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var offer: RewardOffer = run.pending_reward_offer

	# (1) Flip the offer to resolved WITHOUT recording a selection (declined = nothing applied, nothing selected).
	offer.status = RewardOffer.STATUS_RESOLVED
	offer.selected_entry = {}

	# (2) Build the reward_declined system event AFTER the mutation. The payload carries the offer's table id (the
	# resolution record) + the lower_snake decline reason (distinct from the event id).
	var declined_event: DomainEvent = DomainEvent.reward_declined(sequence_id, {
		"table_id": String(offer.table_id),
		"reason": String(DECLINE_REASON)
	})

	# (3) Return ok with the single reward_declined event + diagnostics.
	return ActionResult.ok([declined_event], {
		"declines_reward": true,
		"table_id": String(offer.table_id),
		"reason": String(DECLINE_REASON)
	})


# A single stable top-level code (invalid_context) holds the "give me a valid run" contract for the not-a-RunState /
# structurally-invalid-run cases (mirroring ResolveRewardCommand._invalid_context). When the rejection is a
# structurally-invalid run, attach the inner RunState.validate() error_code (and its metadata) for diagnosis. The
# not-a-RunState case has no inner result.
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
