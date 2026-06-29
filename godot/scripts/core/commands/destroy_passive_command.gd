class_name DestroyPassiveCommand
extends "res://scripts/core/commands/game_command.gd"

# The DESTROY-passive command (Story 6.6) — the SECOND half of the FR82 Consume/Destroy split (the Consume half,
# ConsumePassiveCommand, shipped in Story 6.5). A RUN-domain command that VALIDATES the run's PENDING `passive`
# offer, ROLLS a deterministic 70/20/10 Destroy outcome from a validated DestroyOutcomeTableDefinition through the
# run-level RngStreamSet `rewards` stream, flips the offer to `resolved`, and emits ONE NEW passive_destroyed SYSTEM
# event recording the passive id + the rolled outcome category/id + the effect marker + the draw provenance, or
# fails closed (AC4 no-double-destroy) on an absent/already-resolved/off-offer/unresolvable selection.
#
# It follows the 4.3-ratified run-command idiom VERBATIM (the ConsumePassiveCommand / ResolveRewardCommand
# template): it extends game_command.gd, takes the live RunState DIRECTLY as its validate(state)/execute(state) arg
# (NO wrapper), the CALLER supplies the run-level sequence_id + the run-level RngStreamSet via the constructor,
# validate() rejects sequence_id <= 0 FIRST so a success path can never emit an event its own validator rejects, and
# it is validate-then-mutate: on ANY rejection it returns a structured ActionResult.error with ZERO events, ZERO
# RNG, and a byte-identical no-mutation RunState; it rolls the outcome + flips the offer + builds the
# passive_destroyed event ONLY AFTER validation.
#
# IT DRAWS EXACTLY ONE RNG DRAW. Unlike Consume (which is deterministic — a content lookup + a register + a field
# set, ZERO RNG), DESTROY rolls ONE weighted-pick to select the 70/20/10 outcome. The roll MUST go through the
# INJECTED run-level RngStreamSet `rand_int(STREAM_REWARDS, ...)` — NEVER randi()/randf()/RandomNumberGenerator.new()
# (the architecture's named-RNG-streams-only rule, the single most load-bearing constraint for this story). The
# `rewards` stream is the SAME stream the reward GENERATE path draws on (Story 6.3), so a run that generated a reward
# offer then destroys a passive advances the `rewards` stream coherently. The roll ADVANCES only the `rewards` stream
# (stream isolation). DETERMINISM: the SAME run-level stream-set seed + the SAME outcome table -> the SAME rolled
# outcome. The AC4 load-bearing guarantee: a re-submitted destroy against a `resolved` offer draws NO RNG, advances
# NO stream, leaves the whole RunState byte-identical.
#
# [Decision] DestroyPassiveCommand OWNS the passive offer's resolution end-to-end (mirroring the Story-6.5 Consume
# decision) — it validates the pending passive offer, rolls the outcome, AND flips the offer to `resolved` itself,
# so a passive offer is resolved by EXACTLY ONE of {ResolveRewardCommand (the 6.3 generic outcome-only resolve,
# untouched fallback) | ConsumePassiveCommand (Consume, 6.5) | DestroyPassiveCommand (Destroy, this story)}. It does
# NOT compose ResolveRewardCommand or ConsumePassiveCommand (that would double-record the resolution with a
# reward_resolved / passive_consumed AND a passive_destroyed event); it flips the offer directly and emits ONLY
# passive_destroyed. A HUD wiring story decides which command a passive offer routes to (out of scope here).
#
# [Decision] DESTROY does NOT register the destroyed passive into the run's RulesResolver — that is the CONSUME
# behavior (adoption). Destroy is the OPPOSITE of adopting the passive: the passive is destroyed, not adopted, so
# run.rules_resolver is UNTOUCHED by Destroy (no create/seat/register).
#
# [Decision] v0 Destroy outcomes are OUTCOME-RECORD-ONLY (the EXACT parallel of 6.3's gold-reward-as-outcome-only
# decision, resolve_reward_command.gd:26-31). The live currency/WALLET (gold), the heal/cleanse state, the
# curse/corruption-removal, the Oath-Shards/mastery/unlock/Echoes meta progression, and the future-reward reroll
# state do NOT exist as domain fields in v0 (the gold wallet + heal/cleanse/curse is Epic 7's risk-economy state;
# Oath Shards/mastery/unlock/Echoes is Epic 8; the reroll is a later reward-flow story). So a Destroy outcome
# RECORDS its rolled outcome_category + outcome_id + outcome_effect deterministically via the passive_destroyed event
# — it does NOT credit a wallet, heal, cleanse, advance meta, or reroll. When the economy/meta stories land, they
# wire the actual mutation off the recorded outcome (the passive_destroyed event's outcome_category/outcome_id is the
# single hook).

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DestroyOutcomeTableDefinition = preload("res://scripts/content/definitions/destroy_outcome_table_definition.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The category for a Destroy is ALWAYS `passive` — this command is passive-specific (it does not destroy a
# weapon/gold reward). The offered-entry gate checks this category against the pending offer.
const PASSIVE_CATEGORY := &"passive"

var passive_content_id: StringName = &""
var table_id: StringName = &""
var sequence_id: int = 1

# The run-level RngStreamSet the outcome roll draws through (the SAME set the reward GENERATE path draws on —
# RunOrchestrator.streams). INJECTED, NOT defaulted: a Destroy with no stream set cannot roll (fail closed
# `missing_rng_streams`). The roll routes through this set's rand_int(STREAM_REWARDS, ...) ONLY.
var _streams: RngStreamSet = null

# The validated 70/20/10 Destroy outcome pool. Defaults to the baseline table; injectable for tests (mirroring the
# _passive_repository injection). validate() re-validates this table before drawing (the 6.1
# reward-table-validate-before-draw posture — never draw against a malformed table).
var _outcome_table: DestroyOutcomeTableDefinition = null

# The validated-only passive content gate. Defaults to the baseline repository; injectable for tests (mirroring
# ConsumePassiveCommand). The command resolves the offered passive id to a typed PassiveDefinition through this gate
# and fails closed `unknown_passive` on a miss — a passive that fails validate() is never in the repository.
var _passive_repository: PassiveRepository = null

func _init(
	new_passive_content_id: StringName = &"",
	new_table_id: StringName = &"",
	new_sequence_id: int = 1,
	new_streams: RngStreamSet = null,
	new_outcome_table: DestroyOutcomeTableDefinition = null,
	new_passive_repository: PassiveRepository = null
) -> void:
	command_id = &"destroy_passive"
	passive_content_id = new_passive_content_id
	table_id = new_table_id
	sequence_id = new_sequence_id
	_streams = new_streams
	_outcome_table = new_outcome_table if new_outcome_table != null else DestroyOutcomeTableDefinition.create_baseline_table()
	_passive_repository = new_passive_repository if new_passive_repository != null else PassiveRepository.create_baseline_repository()


# Pure read: validate the sequence id, the run-level rewards stream, context, a pending unresolved offer, that the
# selected passive is an offered `passive` entry, that it resolves through the validated PassiveRepository, and that
# the outcome table is valid. No mutation, no event, NO RNG (validate must NOT roll).
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the ConsumePassiveCommand precedent): execute() builds a passive_destroyed event with
	# this sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id would
	# make the success path emit a non-round-trippable event. Reject it BEFORE any state is read or mutated.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	# The outcome roll is gameplay-affecting randomness and MUST use the assigned run-level `rewards` stream. A
	# Destroy with no stream set (or a stream set missing the `rewards` stream) cannot roll — fail closed.
	if _streams == null or not _streams.has_stream(RngStreamSet.STREAM_REWARDS):
		return ActionResult.error(&"missing_rng_streams", {
			"command": String(command_id),
			"stream": String(RngStreamSet.STREAM_REWARDS)
		})
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	# The run must be structurally sound before we resolve into it.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# There must be a PENDING, UNRESOLVED offer to destroy.
	var offer: RewardOffer = run.pending_reward_offer
	if offer == null:
		return ActionResult.error(&"no_pending_reward_offer", {
			"command": String(command_id)
		})
	if offer.is_resolved():
		# The load-bearing AC4 no-double-destroy reject: a second destroy against a `resolved` offer (the offer was
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
	# A generate path could in principle offer an id that was later removed — fail closed, never destroy a null.
	if _passive_repository.get_passive(passive_content_id) == null:
		return ActionResult.error(&"unknown_passive", {
			"command": String(command_id),
			"passive_id": String(passive_content_id),
			"table_id": String(offer.table_id)
		})

	# The outcome table MUST be present + valid before we draw (the 6.1 validate-before-draw posture — never roll
	# against a malformed/off-distribution table).
	if _outcome_table == null:
		return ActionResult.error(&"invalid_destroy_outcome_table", {
			"command": String(command_id),
			"reason": "missing_outcome_table"
		})
	var table_validation: ActionResult = _outcome_table.validate()
	if table_validation.is_error():
		return ActionResult.error(&"invalid_destroy_outcome_table", {
			"command": String(command_id),
			"inner_error_code": String(table_validation.error_code),
			"inner_metadata": table_validation.metadata.duplicate(true)
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: ROLL the 70/20/10 outcome through the run-level `rewards` stream (the ONE RNG
# draw), flip the offer to `resolved` + record the selected entry, and emit the passive_destroyed event (built AFTER
# the mutation). On any reject: structured error, ZERO events, ZERO RNG, byte-identical RunState. Draws EXACTLY ONE
# RNG draw through the `rewards` stream only; runs no sub-command (does NOT compose ResolveRewardCommand /
# ConsumePassiveCommand); does NOT register into run.rules_resolver (Destroy is the opposite of adoption).
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var offer: RewardOffer = run.pending_reward_offer

	# (1) Resolve the passive (validate proved it resolves non-null). It is recorded but NOT registered — Destroy
	# does not adopt the passive (run.rules_resolver is UNTOUCHED). The lookup is the fail-closed proof the offered id
	# is a real validated passive; the def itself is not otherwise used (v0 Destroy is outcome-record-only).
	var passive_def: PassiveDefinition = _passive_repository.get_passive(passive_content_id)
	assert(passive_def != null, "validate() must prove the offered passive resolves before execute() rolls.")

	# (2) ROLL the 70/20/10 outcome through the run-level `rewards` stream (the ONE RNG draw — the named-stream rule).
	# rand_int returns an ActionResult carrying the draw's value/draw_index/state_after metadata; total_weight() >= 1
	# (validate proved the table is non-empty + every weight positive), so the [0, total_weight() - 1] range is valid.
	var total_weight: int = _outcome_table.total_weight()
	var draw: ActionResult = _streams.rand_int(RngStreamSet.STREAM_REWARDS, 0, total_weight - 1, {
		"command": String(command_id),
		"table_id": String(offer.table_id),
		"passive_id": String(passive_content_id)
	})
	if draw.is_error():
		# Defense-in-depth: a valid stream + valid range should never error here, but never roll-and-mutate past a
		# failed draw. Surface the draw error and leave the offer pending (no flip, no event). The held stream state
		# is unchanged on an error path (rand_int advances the draw index only on success).
		return draw
	var rolled_value: int = int(draw.metadata.get("value"))
	var rolled_draw_index: int = int(draw.metadata.get("draw_index"))
	var outcome: Dictionary = _pick_outcome(rolled_value)

	# (3) Flip the offer to resolved + record the selected entry (AFTER the roll succeeds — the
	# ConsumePassiveCommand / ResolveRewardCommand offer-flip posture).
	offer.status = RewardOffer.STATUS_RESOLVED
	offer.selected_entry = {
		"category": String(PASSIVE_CATEGORY),
		"content_id": String(passive_content_id)
	}

	# (4) Build the passive_destroyed system event AFTER the mutation. The offer's table id is the authoritative
	# source (the constructor's table_id is carried for the caller's convenience but the offer is the truth). The
	# payload carries the draw provenance (roll/draw_index) because Destroy DRAWS RNG (mirroring reward_offered).
	var destroyed_event: DomainEvent = DomainEvent.passive_destroyed(sequence_id, {
		"passive_id": String(passive_content_id),
		"table_id": String(offer.table_id),
		"outcome_category": String(outcome.get("outcome_category")),
		"outcome_id": String(outcome.get("outcome_id")),
		"outcome_effect": String(outcome.get("effect")),
		"explanation": String(outcome.get("explanation")),
		"roll": rolled_value,
		"draw_index": rolled_draw_index
	})

	# (5) Return ok with the single passive_destroyed event + diagnostics.
	return ActionResult.ok([destroyed_event], {
		"destroys_passive": true,
		"passive_id": String(passive_content_id),
		"table_id": String(offer.table_id),
		"outcome_category": String(outcome.get("outcome_category")),
		"outcome_id": String(outcome.get("outcome_id"))
	})


# Weighted-pick the outcome entry the rolled value [0, total_weight - 1] lands on by walking the cumulative weights
# in the table's stable entry order. validate() proves the table is non-empty with every weight a positive int, and
# the caller draws in [0, total_weight - 1], so the rolled value ALWAYS lands on an entry — the trailing return is a
# defensive last-entry fallback that is unreachable for a validated table + an in-range roll.
func _pick_outcome(rolled_value: int) -> Dictionary:
	var cumulative: int = 0
	var entries: Array = _outcome_table.outcome_entries()
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var weight: int = int(entry.get("weight", 0))
		if weight <= 0:
			continue
		cumulative += weight
		if rolled_value < cumulative:
			return entry
	# Unreachable for a validated table + an in-range roll; return the last shape-valid entry as a fail-safe so a
	# self-consistency violation never returns an empty dict.
	for index: int in range(entries.size() - 1, -1, -1):
		if entries[index] is Dictionary:
			return entries[index]
	return {}


# A single stable top-level code (invalid_context) holds the "give me a valid run" contract for the
# not-a-RunState / structurally-invalid-run cases (copied VERBATIM from ConsumePassiveCommand._invalid_context).
# When the rejection is a structurally-invalid run, attach the inner RunState.validate() error_code (and its
# metadata) for diagnosis. The not-a-RunState case has no inner result.
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
