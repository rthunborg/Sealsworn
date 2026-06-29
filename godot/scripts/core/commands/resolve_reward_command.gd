class_name ResolveRewardCommand
extends "res://scripts/core/commands/game_command.gd"

# The reward-RESOLVE command (Story 6.3) — a RUN-domain command that APPLIES the player's SELECTED entry from the
# run's PENDING reward offer and flips the offer to `resolved`, or fails closed (AC3 no-double-apply) on a
# duplicate/absent/invalid selection. It follows the 4.3-ratified run-command idiom VERBATIM (the
# PickupItemCommand / RouteAdvanceCommand template): it extends game_command.gd, takes the live RunState DIRECTLY
# as its validate(state)/execute(state) arg (NO wrapper), the CALLER supplies the run-level sequence_id via the
# constructor (default 1), validate() rejects sequence_id <= 0 FIRST so a success path can never emit an event its
# own validator rejects, and it is validate-then-mutate: on ANY rejection it returns a structured
# ActionResult.error with ZERO events and a byte-identical no-mutation RunState; it applies the reward + builds the
# reward_resolved event ONLY AFTER validation.
#
# IT DRAWS ZERO NEW RNG. The reward was ALREADY rolled at GENERATE time (RunOrchestrator.generate_reward_offer is
# the ONE draw, through the run-level RngStreamSet via RewardOfferBuilder). RESOLVING a stored offer is purely
# deterministic — the player picks an already-offered entry, so no stream advances here (the AC3 load-bearing
# guarantee: a re-submitted selection draws NO RNG, advances NO stream, applies NO second reward, leaves the run
# byte-identical).
#
# APPLY BY CATEGORY (compose, do NOT fork):
#   - A BACKPACK-category reward (InventoryState.is_backpack_category — weapon/armor/jewelry/support/consumable/
#     pickup) is applied by COMPOSING the EXISTING Story-6.2 PickupItemCommand (-> ONE backpack slot + ONE
#     item_gained event, fail-closed inventory_full). A FULL backpack surfaces the pickup's inventory_full error
#     HONESTLY and does NOT flip the offer to `resolved` (the offer stays `pending` — no silent delete, no
#     unclaimed-resolution; a later replacement-choice UX owns the full-backpack disposition). [Decision]
#   - A GOLD reward CREDITS the wallet (Story 7.1 — the T1 wire-off; the run now HAS a RiskEconomyState wallet). The
#     concrete gold amount was already rolled within the GoldRewardDefinition's gold_min..gold_max band at GENERATE
#     time (RunOrchestrator.generate_reward_offer, stored on the offer's gold_amount), so RESOLVE credits exactly
#     that amount DETERMINISTICALLY (drawing ZERO new RNG — the Epic-6 zero-new-RNG-on-resolve invariant holds). It
#     emits a SECOND event (economy_changed, sequence_id + 1) alongside reward_resolved. A re-resolve of a `resolved`
#     offer is rejected at validate() BEFORE any credit, so no second gold is ever credited. [Decision]
#   - A PASSIVE reward is recorded as a reward_resolved OUTCOME only: 6.3 GENERATES + STORES + flips the passive
#     offer to `resolved`; the passive's CONSUME/DESTROY resolution (the real passive outcome) is Stories
#     6.5/6.6. 6.3 takes passive resolution exactly this far (offer flip + reward_resolved record). [Decision]
#
# The item_gained event is the inventory record; the reward_resolved event is the offer-resolution record (always
# emitted on success).

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const PickupItemCommand = preload("res://scripts/core/commands/pickup_item_command.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# Story 7.1: the explanation-log reason recorded on the economy_changed event when a gold reward credits the wallet
# (the T1 wire-off). A lower_snake marker id (the AC2 reason).
const GOLD_REWARD_REASON := &"gold_reward_resolved"
# Story 7.1: the `gold` reward category (kept LOCAL — the command already takes the category by-id; this avoids a
# cross-dependency on RewardTableDefinition. Matches RewardTableDefinition.CATEGORY_GOLD / the REWARD_CATEGORIES set).
const GOLD_CATEGORY := &"gold"

var category: StringName = &""
var content_id: StringName = &""
var sequence_id: int = 1

func _init(new_category: StringName = &"", new_content_id: StringName = &"", new_sequence_id: int = 1) -> void:
	command_id = &"resolve_reward"
	category = new_category
	content_id = new_content_id
	sequence_id = new_sequence_id


# Pure read: validate the sequence id, context, a pending unresolved offer, and that the selected entry is one of
# the offered entries. No mutation, no event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the PickupItemCommand precedent): execute() builds a reward_resolved event with this
	# sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id would make
	# the success path emit a non-round-trippable event. Reject it BEFORE any state is read or mutated.
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

	# AC3: there must be a PENDING, UNRESOLVED offer to resolve.
	var offer: RewardOffer = run.pending_reward_offer
	if offer == null:
		return ActionResult.error(&"no_pending_reward_offer", {
			"command": String(command_id)
		})
	if offer.is_resolved():
		# The load-bearing AC3 no-double-apply reject: a second resolve against a `resolved` offer fails closed
		# (the offer/table id rides metadata; the code carries no arbitrary id).
		return ActionResult.error(&"reward_offer_already_resolved", {
			"command": String(command_id),
			"table_id": String(offer.table_id)
		})

	# AC2/AC3: the selected entry must be one of the offered entries (an off-offer selection is rejected, never
	# fabricated). Catches a wrong content_id, a wrong category, or a selection from a DIFFERENT offer.
	if not offer.has_offered_entry(category, content_id):
		return ActionResult.error(&"invalid_reward_selection", {
			"command": String(command_id),
			"table_id": String(offer.table_id),
			"category": String(category),
			"content_id": String(content_id)
		})

	# Story 7.1: a GOLD reward credits the wallet, so the run must have a non-null economy. RunState defaults a
	# non-null economy, but guard defensively against a directly-nulled field so the gold-credit path never crashes
	# (mirroring PickupItemCommand's null-inventory guard). A non-gold reward needs no economy.
	if category == GOLD_CATEGORY and run.risk_economy == null:
		return _invalid_context()

	return ActionResult.ok()


# Validate-then-mutate. On success: apply the selected reward by category (a backpack reward composes
# PickupItemCommand; gold/passive are recorded as a resolution outcome), flip the offer to `resolved`, and emit
# the reward_resolved event (built AFTER the mutation). On any reject: structured error, ZERO events,
# byte-identical RunState. Draws ZERO NEW RNG (the offer was rolled at GENERATE).
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var offer: RewardOffer = run.pending_reward_offer
	var events: Array[DomainEvent] = []
	var item_gained_event: DomainEvent = null

	# (1) Apply the selected reward by category.
	if InventoryState.is_backpack_category(category):
		# Compose the EXISTING Story-6.2 pickup (one slot + one item_gained, fail-closed inventory_full). It runs
		# BEFORE the offer flip so a full-backpack reject leaves the offer `pending` (no silent delete). The pickup
		# uses a DISTINCT sequence id (sequence_id + 1) from the reward_resolved event (sequence_id), so both
		# emitted events have unique ids; sequence_id >= 1 (validated), so sequence_id + 1 >= 2 > 0.
		var pickup: ActionResult = PickupItemCommand.new(content_id, category, sequence_id + 1).execute(run)
		if pickup.is_error():
			# Surface the pickup's error (e.g. inventory_full) VERBATIM and DO NOT flip the offer — the offer
			# stays pending/unresolved (a documented full-backpack edge; no second reward, no silent delete).
			return pickup
		for pickup_event: DomainEvent in pickup.events:
			if pickup_event.event_type == DomainEvent.Type.ITEM_GAINED:
				item_gained_event = pickup_event
		if item_gained_event != null:
			events.append(item_gained_event)
	elif category == GOLD_CATEGORY:
		# Story 7.1 (the T1 wire-off): a GOLD reward CREDITS the wallet by the amount ALREADY rolled at GENERATE
		# (offer.gold_amount, within the GoldRewardDefinition band). This draws ZERO new RNG — the credit is a recorded
		# amount, not a roll (the Epic-6 zero-new-RNG-on-resolve invariant). The credit is infallible (a credit only
		# adds, never spends — it can never drive gold below 0), so it runs unconditionally here after validation. It
		# emits a SECOND event (economy_changed) with a DISTINCT sequence id (sequence_id + 1, the item_gained
		# precedent), so both emitted events have unique ids; sequence_id >= 1 (validated), so sequence_id + 1 >= 2 > 0.
		var economy: RiskEconomyState = run.risk_economy
		var gold_before: int = economy.gold
		economy.apply_gold_delta(offer.gold_amount)
		var economy_event: DomainEvent = DomainEvent.economy_changed(sequence_id + 1, {
			"reason": String(GOLD_REWARD_REASON),
			"gold_before": gold_before,
			"gold_after": economy.gold,
			"gold_delta": offer.gold_amount,
			"healing_before": economy.healing_charges,
			"healing_after": economy.healing_charges,
			"healing_delta": 0
		})
		events.append(economy_event)
	# passive: no domain mutation beyond the offer flip + the reward_resolved record (the passive Consume/Destroy is
	# 6.5/6.6; curse is 7.2). No-op here on purpose.

	# (2) Flip the offer to resolved + record the selected entry (AFTER the application succeeds).
	offer.status = RewardOffer.STATUS_RESOLVED
	offer.selected_entry = {
		"category": String(category),
		"content_id": String(content_id)
	}

	# (3) Build the reward_resolved system event AFTER the mutation.
	var resolved_event: DomainEvent = DomainEvent.reward_resolved(sequence_id, {
		"table_id": String(offer.table_id),
		"category": String(category),
		"content_id": String(content_id)
	})
	events.append(resolved_event)

	# (4) Return ok with the events (item_gained for a backpack reward, then reward_resolved) + diagnostics.
	return ActionResult.ok(events, {
		"resolves_reward": true,
		"table_id": String(offer.table_id),
		"category": String(category),
		"content_id": String(content_id),
		"applied_to_backpack": item_gained_event != null
	})


# A single stable top-level code (invalid_context) holds the "give me a valid run" contract for the
# not-a-RunState / structurally-invalid-run cases (mirroring PickupItemCommand._invalid_context). When the
# rejection is a structurally-invalid run, attach the inner RunState.validate() error_code (and its metadata) for
# diagnosis. The not-a-RunState case has no inner result.
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
