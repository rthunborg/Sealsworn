class_name ConsumePassiveCommand
extends "res://scripts/core/commands/game_command.gd"

# The CONSUME-passive command (Story 6.5) — the REAL passive resolution that Story 6.3's ResolveRewardCommand
# deferred (6.3 resolved a passive offer as an OUTCOME-ONLY reward_resolved record and STOPPED; this command takes
# it the rest of the way). It is the FIRST half of the FR82 Consume/Destroy split (the Destroy half +
# the 70/20/10 outcome distribution is Story 6.6). A RUN-domain command that VALIDATES the run's PENDING `passive`
# offer, ADOPTS the chosen passive into the run (registers the resolved PassiveDefinition into the run's
# RulesResolver — the real "add the passive to active run state"), flips the offer to `resolved`, and emits ONE
# deterministic passive_consumed SYSTEM event, or fails closed (AC4 no-double-consume) on an
# absent/already-resolved/off-offer/unresolvable selection.
#
# It follows the 4.3-ratified run-command idiom VERBATIM (the ResolveRewardCommand / PickupItemCommand template):
# it extends game_command.gd, takes the live RunState DIRECTLY as its validate(state)/execute(state) arg (NO
# wrapper), the CALLER supplies the run-level sequence_id via the constructor (default 1), validate() rejects
# sequence_id <= 0 FIRST so a success path can never emit an event its own validator rejects, and it is
# validate-then-mutate: on ANY rejection it returns a structured ActionResult.error with ZERO events and a
# byte-identical no-mutation RunState; it registers the passive + flips the offer + builds the passive_consumed
# event ONLY AFTER validation.
#
# IT DRAWS ZERO RNG. Consume is DETERMINISTIC — a content lookup (PassiveRepository.get_passive) + a register +
# a field set; there is no roll here (the Destroy-outcome RNG is Story 6.6, and would route through the run-level
# `rewards` stream — NOT this story). The AC4 load-bearing guarantee: a re-submitted consume against a `resolved`
# offer draws NO RNG, advances NO stream, registers NO second passive, and leaves the whole RunState
# byte-identical.
#
# [Decision] ConsumePassiveCommand OWNS the passive offer's resolution end-to-end — it validates the pending
# passive offer, registers the passive, AND flips the offer to `resolved` itself (mirroring ResolveRewardCommand's
# offer-flip + selected-entry record), so a passive offer is resolved by EXACTLY ONE of {ResolveRewardCommand (the
# 6.3 generic outcome-only resolve, untouched) | ConsumePassiveCommand (Consume) | DestroyPassiveCommand (Destroy,
# 6.6)}. It does NOT compose ResolveRewardCommand (that would double-record the resolution with a reward_resolved
# AND a passive_consumed event); it flips the offer directly and emits ONLY passive_consumed. A HUD wiring story
# decides which command a passive offer routes to (out of scope here).
#
# [Decision] "adds the passive to active run state" = REGISTER it into the run's EXISTING RulesResolver (the
# Story-5.4 seam — the LIVE rules-kernel service that already holds the starting passives, registered by
# RunStartCommand). There is NO parallel "consumed passives" list and NO new RunState field. A legacy / seed-only
# / empty-class run has run.rules_resolver == null (the starting resolver is only seated for a selectable-class
# start), so this command CREATES + seats a fresh RulesResolver when the run has none — exactly the
# RunStartCommand.execute seating shape — before registering. v0 passives are EXPLANATION-ONLY: the consumed
# passive becomes resolvable + explainable through its trigger windows alongside the starting passives; it does
# NOT mutate a combat number (the per-effect operation engine is a later Epic-6 story). The resolver is a LIVE
# re-derivable service (NOT serialized), so the consumed passive is not in to_dictionary()/the route-position save
# — the consumed-passive re-derive across a route-position resume is a tracked forward residual (the later
# in-node-save / live-resume story).

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The category for a Consume is ALWAYS `passive` — this command is passive-specific (it does not consume a
# weapon/gold reward). The offered-entry gate checks this category against the pending offer.
const PASSIVE_CATEGORY := &"passive"

var passive_content_id: StringName = &""
var table_id: StringName = &""
var sequence_id: int = 1

# The validated-only passive content gate. Defaults to the baseline repository; injectable as the LAST constructor
# param for tests (mirroring RunStartCommand's _passive_repository injection). The command resolves the offered
# passive id to a typed PassiveDefinition through this gate and fails closed `unknown_passive` on a miss — a
# passive that fails validate() is never in the repository, so it can never be consumed.
var _passive_repository: PassiveRepository = null

func _init(
	new_passive_content_id: StringName = &"",
	new_table_id: StringName = &"",
	new_sequence_id: int = 1,
	new_passive_repository: PassiveRepository = null
) -> void:
	command_id = &"consume_passive"
	passive_content_id = new_passive_content_id
	table_id = new_table_id
	sequence_id = new_sequence_id
	_passive_repository = new_passive_repository if new_passive_repository != null else PassiveRepository.create_baseline_repository()


# Pure read: validate the sequence id, context, a pending unresolved offer, that the selected passive is an offered
# `passive` entry, and that it resolves through the validated PassiveRepository. No mutation, no event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the ResolveRewardCommand precedent): execute() builds a passive_consumed event with
	# this sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id would
	# make the success path emit a non-round-trippable event. Reject it BEFORE any state is read or mutated.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	# The run must be structurally sound before we adopt a passive into it.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# There must be a PENDING, UNRESOLVED offer to consume.
	var offer: RewardOffer = run.pending_reward_offer
	if offer == null:
		return ActionResult.error(&"no_pending_reward_offer", {
			"command": String(command_id)
		})
	if offer.is_resolved():
		# The load-bearing AC4 no-double-consume reject: a second consume against a `resolved` offer (the offer was
		# already consumed/destroyed/resolved) fails closed (the offer/table id rides metadata).
		return ActionResult.error(&"reward_offer_already_resolved", {
			"command": String(command_id),
			"table_id": String(offer.table_id)
		})

	# The selected passive must be one of the offer's `passive`-category offered entries (an off-offer selection is
	# rejected, never fabricated). Catches a wrong passive id or a passive id from a DIFFERENT offer.
	if not offer.has_offered_entry(PASSIVE_CATEGORY, passive_content_id):
		return ActionResult.error(&"invalid_reward_selection", {
			"command": String(command_id),
			"table_id": String(offer.table_id),
			"category": String(PASSIVE_CATEGORY),
			"content_id": String(passive_content_id)
		})

	# Defense-in-depth fail-closed gate: the offered passive id MUST resolve through the validated-only repository.
	# The validated-only repository should always resolve an offered passive id, but a generate path could in
	# principle offer an id that was later removed — fail closed, never register a null.
	if _passive_repository.get_passive(passive_content_id) == null:
		return ActionResult.error(&"unknown_passive", {
			"command": String(command_id),
			"passive_id": String(passive_content_id),
			"table_id": String(offer.table_id)
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: REGISTER the resolved passive into the run's RulesResolver (creating + seating
# a fresh resolver when the run has none), flip the offer to `resolved` + record the selected entry, and emit the
# passive_consumed event (built AFTER the mutation). On any reject: structured error, ZERO events, byte-identical
# RunState. Draws ZERO RNG; runs no sub-command (does NOT compose ResolveRewardCommand).
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var offer: RewardOffer = run.pending_reward_offer

	# (1) Resolve the passive (validate proved it resolves non-null).
	var passive_def: PassiveDefinition = _passive_repository.get_passive(passive_content_id)

	# (2) ADOPT into the run: create + seat a fresh RulesResolver when the run has none (the legacy/empty-class-run
	# case — mirror RunStartCommand.execute), then register the consumed passive in stable registration order
	# (appended AFTER any starting passives the resolver already holds).
	if run.rules_resolver == null:
		run.rules_resolver = RulesResolver.new()
	run.rules_resolver.register_passive(passive_def)

	# (3) Flip the offer to resolved + record the selected entry (AFTER the adoption succeeds — the
	# ResolveRewardCommand offer-flip posture).
	offer.status = RewardOffer.STATUS_RESOLVED
	offer.selected_entry = {
		"category": String(PASSIVE_CATEGORY),
		"content_id": String(passive_content_id)
	}

	# (4) Build the passive_consumed system event AFTER the mutation. The offer's table id is the authoritative
	# source (the constructor's table_id is carried for the caller's convenience but the offer is the truth).
	var consumed_event: DomainEvent = DomainEvent.passive_consumed(sequence_id, {
		"passive_id": String(passive_content_id),
		"table_id": String(offer.table_id)
	})

	# (5) Return ok with the single passive_consumed event + diagnostics.
	return ActionResult.ok([consumed_event], {
		"consumes_passive": true,
		"passive_id": String(passive_content_id),
		"table_id": String(offer.table_id),
		"registered_passive_count": run.rules_resolver.registered_passive_count()
	})


# A single stable top-level code (invalid_context) holds the "give me a valid run" contract for the
# not-a-RunState / structurally-invalid-run cases (copied VERBATIM from ResolveRewardCommand._invalid_context).
# When the rejection is a structurally-invalid run, attach the inner RunState.validate() error_code (and its
# metadata) for diagnosis. The not-a-RunState case has no inner result.
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
