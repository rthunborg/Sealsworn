class_name ChooseEventOptionCommand
extends "res://scripts/core/commands/game_command.gd"

# The CHOOSE-EVENT-OPTION command (Story 7.3, AC2/AC3) — a RUN-domain command that, when the player picks a choice on
# the run's PENDING risk/reward EVENT offer, applies BOTH the REWARD and the RISK to the run's RiskEconomyState, RAISES
# the choice's declared risk flag(s) (the `risk_flags` PRODUCER this story owns — AC2 "future systems can query the
# resulting risk flags"), emits domain events recording BOTH sides, and flips the offer to `resolved`. It is fail-closed
# no-double-apply (AC3): a second choose against a `resolved` offer, or an off-offer/invalid choice id, fails with a
# stable error and applies ZERO extra reward/penalty. It follows the 4.3-ratified run-command idiom VERBATIM (the
# AcceptCursedRewardCommand + ResolveRewardCommand template): extends game_command.gd, takes the live RunState DIRECTLY,
# the CALLER supplies the run-level sequence_id via the constructor (default 1), validate() rejects sequence_id <= 0
# FIRST, validate-then-mutate (ZERO events + byte-identical no-mutation RunState on ANY reject), builds the events ONLY
# AFTER the mutation.
#
# IT DRAWS ZERO RNG. Choosing an event option is a RECORDED tradeoff, not a roll — the choice amounts are AUTHORED on the
# EventChoiceDefinition (NOT rolled at choose). The OFFER was rolled at GENERATE (RunOrchestrator.generate_event_offer,
# the ONE `events` draw). Deterministic, like AcceptCursedRewardCommand / ResolveRewardCommand. There is no
# RandomNumberGenerator here, no randi/randf, no stream draw.
#
# ALL-OR-NOTHING (AC2 "both the reward and the risk are recorded ... applied"): validate() checks BOTH the net gold
# change AND the net healing change against their floors BEFORE any mutation, so a choice whose resource COST would
# overdraw is rejected with ZERO mutation; on success, every mutation is infallible (the floors were proven). The events
# are built AFTER the mutation.
#
# [Decision] The event split (the 7.2 AcceptCursedRewardCommand precedent, extended to three): emit a NEW event_resolved
# (the choice-resolution + risk-flag record — the RISK record + the resolution record) AND reuse the 7.1 economy_changed
# (the gold/healing reward/cost side) AND — IF the chosen choice has a curse/corruption increment — reuse the 7.2
# curse_applied (the curse/corruption risk side), each at a DISTINCT sequence_id. A single mega-event was rejected
# because economy_changed/curse_applied are already wired end-to-end and reusing them keeps the AC2 log consistent with
# 7.1/7.2; event_resolved adds only the event/choice/risk-flag record. The economy_changed half is ALWAYS emitted (the
# honest-record posture, even for a zero-net safe choice); the curse_applied half is emitted ONLY when the choice
# applies a curse/corruption increment (a safe/no-curse choice emits no curse_applied). sequence_id is the event_resolved
# id; economy_changed is sequence_id + 1; curse_applied (when present) is sequence_id + 2 — all > 0 (sequence_id >= 1
# validated), so the round-trip never collides.
#
# WHAT THIS IS NOT (scope boundaries, Story 7.3):
#   - NOT a live combat-number mutation (the per-effect operation engine is the later operations story —
#     scripts/rules/{conditions,operations} stay empty). A risk effect RECORDS an economy-side penalty + raises a flag +
#     EXPLAINS — it does not mutate a combat HP/damage number.
#   - NOT a passive grant / a literal "lose max HP" mutation (modeled as the economy side + a flag — the 7.2 boundary).
#   - It does NOT seat a resolver curse (a curse/corruption COUNT increment via the 7.1 setter + a raised flag is enough;
#     the cursed-REWARD resolver-seating flow is 7.2's — recorded in the story Dev Notes). A v0 event choice raises flags
#     + increments counts; it seats no rule source.

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EventChoiceDefinition = preload("res://scripts/content/definitions/event_choice_definition.gd")
const EventDefinition = preload("res://scripts/content/definitions/event_definition.gd")
const EventOffer = preload("res://scripts/run/event_offer.gd")
const EventRepository = preload("res://scripts/content/repositories/event_repository.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The AC2 explanation-log reason recorded on the event_resolved / economy_changed / curse_applied events when an event
# choice is resolved. A lower_snake marker id.
const RESOLVED_REASON := &"event_choice_resolved"

var choice_id: StringName = &""
var sequence_id: int = 1

# The validated-only event content gate. Defaults to the baseline repository; injectable as the LAST constructor param
# for tests (mirroring AcceptCursedRewardCommand's _cursed_reward_repository injection). The command resolves the pending
# offer's event id to a typed EventDefinition through this gate (the offer references the event by id), then resolves the
# chosen choice_id on it — fail-closed on a miss. The repo MUST match the one the offer was generated from (the offer's
# event_id resolves through it).
var _event_repository: EventRepository = null

func _init(
	new_choice_id: StringName = &"",
	new_sequence_id: int = 1,
	new_event_repository: EventRepository = null
) -> void:
	command_id = &"choose_event_option"
	choice_id = new_choice_id
	sequence_id = new_sequence_id
	_event_repository = new_event_repository if new_event_repository != null else EventRepository.create_baseline_repository()


# Pure read: validate the sequence id, context, a pending unresolved offer, that the chosen choice is one of the offered
# choices AND resolves on the offer's event through the validated repository, and that neither the net gold change nor
# the net healing change would drive its resource below 0. No mutation, no event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the AcceptCursedRewardCommand precedent): execute() builds events with this sequence id
	# (and sequence_id + 1 / + 2), and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id
	# would make the success path emit a non-round-trippable event. Reject it BEFORE any state is read or mutated.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	# The run must be structurally sound before we change its economy.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# AC3: there must be a PENDING, UNRESOLVED event offer to choose from.
	var offer: EventOffer = run.pending_event_offer
	if offer == null:
		return ActionResult.error(&"no_pending_event_offer", {
			"command": String(command_id)
		})
	if offer.is_resolved():
		# The load-bearing AC3 no-double-apply reject: a second choose against a `resolved` offer fails closed (the
		# offer's event/choice ids ride metadata; the code carries no arbitrary id).
		return ActionResult.error(&"event_offer_already_resolved", {
			"command": String(command_id),
			"event_id": String(offer.event_id),
			"selected_choice_id": String(offer.selected_choice_id)
		})

	# AC2/AC3: the chosen choice must be one of the OFFERED choices (an off-offer pick is rejected, never fabricated).
	if not offer.has_offered_choice(choice_id):
		return ActionResult.error(&"invalid_event_choice", {
			"command": String(command_id),
			"event_id": String(offer.event_id),
			"choice_id": String(choice_id)
		})

	# The offer's event MUST resolve through the validated-only repository (fail closed — never apply against a
	# null/invalid event; the validate-before-use posture). The offending id rides metadata (NOT the code).
	var definition: EventDefinition = _event_repository.get_event(offer.event_id)
	if definition == null:
		return ActionResult.error(&"unknown_event", {
			"command": String(command_id),
			"event_id": String(offer.event_id)
		})
	# The chosen choice must resolve on that event (defensive — a desynced offer/repo would otherwise crash; the offered
	# set comes from this same definition at GENERATE, so this is non-null for a matching repo).
	var choice: EventChoiceDefinition = definition.get_choice(choice_id)
	if choice == null:
		return ActionResult.error(&"invalid_event_choice", {
			"command": String(command_id),
			"event_id": String(offer.event_id),
			"choice_id": String(choice_id)
		})

	var economy: RiskEconomyState = run.risk_economy
	if economy == null:
		# Defensive: RunState defaults a non-null economy, but a directly-nulled field would otherwise crash.
		return _invalid_context()

	# AC2 all-or-nothing: a choice's resource COST is paid alongside its benefit. Check the NET change of each resource
	# against its floor BEFORE any mutation (a choice whose gold_cost exceeds gold-held-plus-benefit, or whose
	# healing_cost exceeds healing-held-plus-benefit, is rejected fail-closed — ZERO mutation). The net is applied as
	# benefit-then-cost in execute(); checking the net here matches that.
	var net_gold: int = choice.gold_benefit - choice.gold_cost
	var net_healing: int = choice.healing_benefit - choice.healing_cost
	if not economy.can_apply_gold_delta(net_gold):
		return ActionResult.error(&"insufficient_gold", {
			"command": String(command_id),
			"event_id": String(offer.event_id),
			"choice_id": String(choice_id),
			"gold": economy.gold,
			"gold_benefit": choice.gold_benefit,
			"gold_cost": choice.gold_cost
		})
	if not economy.can_apply_healing_delta(net_healing):
		return ActionResult.error(&"insufficient_healing", {
			"command": String(command_id),
			"event_id": String(offer.event_id),
			"choice_id": String(choice_id),
			"healing_charges": economy.healing_charges,
			"healing_benefit": choice.healing_benefit,
			"healing_cost": choice.healing_cost
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: apply BOTH sides (the benefit credit + any resource cost via apply_*_delta; the
# curse/corruption risk via the 7.1 set_curse_count/set_corruption setters), RAISE each declared risk flag via the 7.1
# add_risk_flag setter (the `risk_flags` PRODUCER), flip the offer to `resolved` + record the selected choice id, and emit
# event_resolved (+ economy_changed, + curse_applied when the choice applies a curse). On any reject: structured error,
# ZERO events, byte-identical RunState. Draws ZERO RNG.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var economy: RiskEconomyState = run.risk_economy
	var offer: EventOffer = run.pending_event_offer
	var definition: EventDefinition = _event_repository.get_event(offer.event_id)
	var choice: EventChoiceDefinition = definition.get_choice(choice_id)

	# (1) Capture the before amounts (the honest-record before/after).
	var gold_before: int = economy.gold
	var healing_before: int = economy.healing_charges
	var curse_before: int = economy.curse_count
	var corruption_before: int = economy.corruption

	# (2) Apply BOTH sides via the 7.1 RiskEconomyState API (infallible once validated — both floors were checked).
	#     Benefit first, then any resource cost (the net was floor-checked in validate()).
	if choice.gold_benefit > 0:
		economy.apply_gold_delta(choice.gold_benefit)
	if choice.healing_benefit > 0:
		economy.apply_healing_delta(choice.healing_benefit)
	if choice.gold_cost > 0:
		economy.apply_gold_delta(-choice.gold_cost)
	if choice.healing_cost > 0:
		economy.apply_healing_delta(-choice.healing_cost)
	# The curse/corruption risk via the 7.1 STRUCTURAL setters (do NOT mutate the fields directly).
	if choice.curse_increment > 0:
		economy.set_curse_count(economy.curse_count + choice.curse_increment)
	if choice.corruption_increment > 0:
		economy.set_corruption(economy.corruption + choice.corruption_increment)
	# (3) RAISE each declared risk flag (the AC2 `risk_flags` PRODUCER — add_risk_flag is idempotent + drops a
	#     non-lower_snake id, but the definition validated each flag is lower_snake). Capture the raised set for the
	#     event_resolved record (the flags actually present afterward, in declared order).
	var raised_flags: Array = []
	for flag_value: Variant in choice.risk_flags:
		var flag_id: StringName = StringName(String(flag_value))
		economy.add_risk_flag(flag_id)
		if economy.has_risk_flag(flag_id):
			raised_flags.append(String(flag_id))

	var gold_after: int = economy.gold
	var healing_after: int = economy.healing_charges
	var curse_after: int = economy.curse_count
	var corruption_after: int = economy.corruption

	# (4) Flip the offer to resolved + record the selected choice id (AFTER the application succeeds — the
	#     ResolveRewardCommand offer-flip; AC3 no-double-apply, a second choose now rejects at validate()).
	offer.status = EventOffer.STATUS_RESOLVED
	offer.selected_choice_id = choice_id

	# (5) Build the events AFTER the mutation. event_resolved (the choice-resolution + risk-flag record) at sequence_id.
	var events: Array[DomainEvent] = []
	var resolved_event: DomainEvent = DomainEvent.event_resolved(sequence_id, {
		"event_id": String(definition.event_id),
		"choice_id": String(choice_id),
		"risk_flags": raised_flags,
		"reason": String(RESOLVED_REASON)
	})
	events.append(resolved_event)

	# (6) economy_changed (the gold/healing reward/cost side; AC2) at a DISTINCT sequence_id (sequence_id + 1). The
	#     honest-record posture (the 7.1 all-zero economy_changed [Decision]): record the real before/after even if the
	#     net is 0 (a safe choice records a no-op economy change).
	var economy_event: DomainEvent = DomainEvent.economy_changed(sequence_id + 1, {
		"reason": String(RESOLVED_REASON),
		"gold_before": gold_before,
		"gold_after": gold_after,
		"gold_delta": gold_after - gold_before,
		"healing_before": healing_before,
		"healing_after": healing_after,
		"healing_delta": healing_after - healing_before
	})
	events.append(economy_event)

	# (7) curse_applied (the curse/corruption risk side; AC2) at a DISTINCT sequence_id (sequence_id + 2) — ONLY when the
	#     choice applies a curse/corruption increment (a safe/no-curse choice emits no curse_applied). The curse_source is
	#     the event_id (the source marker). SIGNED deltas (positive on a risk increment).
	if choice.applies_curse():
		var curse_event: DomainEvent = DomainEvent.curse_applied(sequence_id + 2, {
			"curse_source": String(definition.event_id),
			"reason": String(RESOLVED_REASON),
			"curse_before": curse_before,
			"curse_after": curse_after,
			"curse_delta": curse_after - curse_before,
			"corruption_before": corruption_before,
			"corruption_after": corruption_after,
			"corruption_delta": corruption_after - corruption_before
		})
		events.append(curse_event)

	# (8) Return ok with the events + diagnostics metadata.
	return ActionResult.ok(events, {
		"resolves_event_choice": true,
		"event_id": String(definition.event_id),
		"choice_id": String(choice_id),
		"risk_flags": raised_flags,
		"gold_before": gold_before,
		"gold_after": gold_after,
		"healing_before": healing_before,
		"healing_after": healing_after,
		"curse_before": curse_before,
		"curse_after": curse_after,
		"corruption_before": corruption_before,
		"corruption_after": corruption_after,
		"applies_curse": choice.applies_curse()
	})


# A single stable top-level code (invalid_context) holds the "give me a valid run" contract for the not-a-RunState /
# structurally-invalid-run / null-economy cases (mirroring AcceptCursedRewardCommand._invalid_context). When the
# rejection is a structurally-invalid run, attach the inner RunState.validate() error_code (and its metadata) for
# diagnosis. The not-a-RunState case has no inner result.
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
