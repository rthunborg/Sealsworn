class_name AcceptCursedRewardCommand
extends "res://scripts/core/commands/game_command.gd"

# The ACCEPT-CURSED-REWARD command (Story 7.2, AC2/AC3) — a RUN-domain command that, when the player ACCEPTS a cursed
# reward, applies BOTH the BENEFIT and the PENALTY to the run's RiskEconomyState and emits domain events recording BOTH
# sides (AC2 "the benefit AND the penalty are both applied through domain events"), AND seats the curse/corruption
# EFFECT as a rule source on the run's RulesResolver so it resolves through the rules kernel (AC3). It follows the
# 4.3-ratified run-command idiom VERBATIM (the ApplyEconomyChangeCommand / DestroyPassiveCommand template): it extends
# game_command.gd, takes the live RunState DIRECTLY as its validate(state)/execute(state) arg (NO wrapper), the CALLER
# supplies the run-level sequence_id via the constructor (default 1), validate() rejects sequence_id <= 0 FIRST so a
# success path can never emit an event its own validator rejects, and it is validate-then-mutate: on ANY rejection it
# returns a structured ActionResult.error with ZERO events and a byte-identical no-mutation RunState; it applies both
# sides + seats the curse + builds the events ONLY AFTER validation.
#
# IT DRAWS ZERO RNG. Accepting a cursed reward is a RECORDED tradeoff, not a roll — the benefit/penalty amounts are
# AUTHORED on the CursedRewardDefinition (NOT rolled at accept). Deterministic, like ApplyEconomyChangeCommand /
# item_consumed. There is no RandomNumberGenerator here, no randi/randf, no stream draw. (If a future cursed reward
# needs a RANDOM penalty magnitude, that draw MUST route through the run-level RngStreamSet on the rewards/events
# stream via the orchestrator — but no AC here requires it; v0 amounts are fixed on the definition.)
#
# ALL-OR-NOTHING (AC2 "the benefit AND the penalty are both applied"): validate() checks BOTH the net gold change AND
# the net healing change against their floors BEFORE any mutation, so a reward whose resource COST would overdraw is
# rejected with ZERO mutation; on success, every mutation is infallible (the floors were proven). The events are built
# AFTER the mutation.
#
# [Decision] The two-event split: emit the curse_applied event (Task 4) recording the PENALTY (the curse/corruption
# increment, source-identifying) AND the 7.1 economy_changed event recording the ECONOMIC side (the gold/healing
# benefit minus any resource cost) — each with a DISTINCT sequence_id (curse_applied at sequence_id, economy_changed at
# sequence_id + 1, the item_gained sequence_id + 1 precedent). A combined single event was rejected because the
# curse_applied / economy_changed shapes are already wired end-to-end (factory + validator + id maps + round-trip) and
# reusing them keeps the AC2 explanation log consistent with the 7.1 economy posture. Both sequence_ids are > 0 (since
# sequence_id >= 1 validated) so the round-trip never collides.
#
# [Decision] AC3 seating: if the cursed reward carries a curse EFFECT (curse_increment/corruption_increment > 0), a
# CurseDefinition is built (CurseDefinition.for_cursed_reward) and REGISTERED into the run's RulesResolver (creating +
# seating a fresh resolver when the run has none — the ConsumePassiveCommand "create + seat when null" shape), so the
# curse resolves + EXPLAINS through its trigger window alongside passives. The resolver is a LIVE re-derivable service
# (NOT serialized), so the seated curse — like the 6.5 consumed passive — is NOT in the route-position save; the
# curse_count/corruption COUNT survives the save via 7.1's nested economy, and the registered curse RULE is a live
# re-derivable (recorded in Completion Notes as a tracked forward residual, consistent with consumed passives).
#
# WHAT THIS IS NOT (scope boundaries, Story 7.2):
#   - NOT a live combat-number mutation (the per-effect operation engine is the later operations story —
#     scripts/rules/{conditions,operations} stay empty). v0 curse resolution is EXPLANATION-ONLY; the economy-side
#     penalty applies through the RiskEconomyState API, NOT a combat HP/damage number.
#   - NOT a passive grant (a "strong passive" benefit is out of scope as a literal passive — the benefit is modeled as
#     the economy side in v0).
#   - NOT the risk/reward event roll (Story 7.3 — this command sets NO risk flag via a roll; the v0 baseline rewards
#     carry no honest-delayed-consequence that demands a queryable flag, so this command sets none — recorded in
#     Completion Notes).

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const CurseDefinition = preload("res://scripts/content/definitions/curse_definition.gd")
const CursedRewardDefinition = preload("res://scripts/content/definitions/cursed_reward_definition.gd")
const CursedRewardRepository = preload("res://scripts/content/repositories/cursed_reward_repository.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var cursed_reward_id: StringName = &""
var sequence_id: int = 1

# The validated-only cursed-reward content gate. Defaults to the baseline repository; injectable as the LAST
# constructor param for tests (mirroring DestroyPassiveCommand's _passive_repository injection). The command resolves
# the cursed-reward id to a typed CursedRewardDefinition through this gate and fails closed `unknown_cursed_reward` on a
# miss — a cursed reward that fails validate() is never in the repository, so it can never be accepted.
var _cursed_reward_repository: CursedRewardRepository = null

func _init(
	new_cursed_reward_id: StringName = &"",
	new_sequence_id: int = 1,
	new_cursed_reward_repository: CursedRewardRepository = null
) -> void:
	command_id = &"accept_cursed_reward"
	cursed_reward_id = new_cursed_reward_id
	sequence_id = new_sequence_id
	_cursed_reward_repository = new_cursed_reward_repository if new_cursed_reward_repository != null else CursedRewardRepository.create_baseline_repository()


# Pure read: validate the sequence id, context, that the cursed reward resolves through the validated repository, and
# that neither the net gold change nor the net healing change would drive its resource below 0. No mutation, no event,
# no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the ApplyEconomyChangeCommand precedent): execute() builds events with this sequence id
	# (and sequence_id + 1), and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id would
	# make the success path emit a non-round-trippable event. Reject it BEFORE any state is read or mutated.
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

	# The cursed reward MUST resolve through the validated-only repository (fail closed — never accept a null/invalid
	# cursed reward; the validate-before-use posture). The offending id rides metadata (NOT the code).
	var definition: CursedRewardDefinition = _cursed_reward_repository.get_cursed_reward(cursed_reward_id)
	if definition == null:
		return ActionResult.error(&"unknown_cursed_reward", {
			"command": String(command_id),
			"cursed_reward_id": String(cursed_reward_id)
		})

	var economy: RiskEconomyState = run.risk_economy
	if economy == null:
		# Defensive: RunState defaults a non-null economy, but a directly-nulled field would otherwise crash.
		return _invalid_context()

	# AC2 all-or-nothing: a cursed reward's resource COST is paid alongside its benefit. Check the NET change of each
	# resource against its floor BEFORE any mutation (a reward whose gold_cost exceeds gold-held-plus-benefit, or whose
	# healing_cost exceeds healing-held-plus-benefit, is rejected fail-closed — ZERO mutation). The net is applied as
	# benefit-then-cost in execute(); checking the net here matches that.
	var net_gold: int = definition.gold_benefit - definition.gold_cost
	var net_healing: int = definition.healing_benefit - definition.healing_cost
	if not economy.can_apply_gold_delta(net_gold):
		return ActionResult.error(&"insufficient_gold", {
			"command": String(command_id),
			"cursed_reward_id": String(cursed_reward_id),
			"gold": economy.gold,
			"gold_benefit": definition.gold_benefit,
			"gold_cost": definition.gold_cost
		})
	if not economy.can_apply_healing_delta(net_healing):
		return ActionResult.error(&"insufficient_healing", {
			"command": String(command_id),
			"cursed_reward_id": String(cursed_reward_id),
			"healing_charges": economy.healing_charges,
			"healing_benefit": definition.healing_benefit,
			"healing_cost": definition.healing_cost
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: apply BOTH sides (the benefit credit + any resource cost via apply_*_delta; the
# curse/corruption penalty via the 7.1 set_curse_count/set_corruption setters), seat the curse rule source on the
# resolver (if the reward carries a curse effect), and emit the curse_applied event (the penalty, source-identifying) +
# the economy_changed event (the economic side). On any reject: structured error, ZERO events, byte-identical RunState.
# Draws ZERO RNG.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var economy: RiskEconomyState = run.risk_economy
	var definition: CursedRewardDefinition = _cursed_reward_repository.get_cursed_reward(cursed_reward_id)

	# (1) Capture the before amounts (the honest-record before/after).
	var gold_before: int = economy.gold
	var healing_before: int = economy.healing_charges
	var curse_before: int = economy.curse_count
	var corruption_before: int = economy.corruption

	# (2) Apply BOTH sides via the 7.1 RiskEconomyState API (infallible once validated — both floors were checked).
	#     Benefit first, then any resource cost (the net was floor-checked in validate()).
	if definition.gold_benefit > 0:
		economy.apply_gold_delta(definition.gold_benefit)
	if definition.healing_benefit > 0:
		economy.apply_healing_delta(definition.healing_benefit)
	if definition.gold_cost > 0:
		economy.apply_gold_delta(-definition.gold_cost)
	if definition.healing_cost > 0:
		economy.apply_healing_delta(-definition.healing_cost)
	# The curse/corruption penalty via the 7.1 STRUCTURAL setters (do NOT mutate the fields directly).
	if definition.curse_increment > 0:
		economy.set_curse_count(economy.curse_count + definition.curse_increment)
	if definition.corruption_increment > 0:
		economy.set_corruption(economy.corruption + definition.corruption_increment)

	var gold_after: int = economy.gold
	var healing_after: int = economy.healing_charges
	var curse_after: int = economy.curse_count
	var corruption_after: int = economy.corruption

	# (3) AC3: seat the curse/corruption EFFECT as a rule source on the run's RulesResolver when the reward carries a
	#     curse effect (curse_increment/corruption_increment > 0). Create + seat a fresh resolver when the run has none
	#     (the legacy/empty-class-run case — mirror ConsumePassiveCommand.execute). The resolver is a PURE READ; the
	#     economy-side penalty above is the mutation, NOT the resolver.
	if definition.applies_curse():
		if run.rules_resolver == null:
			run.rules_resolver = RulesResolver.new()
		run.rules_resolver.register_curse(CurseDefinition.for_cursed_reward(definition.cursed_reward_id, definition.display_name))

	# (4) Build the curse_applied event (the PENALTY — source-identifying; AC3 "its explanation identifies the curse or
	#     corruption source"). The curse_source is the cursed_reward_id (the source marker). SIGNED deltas (positive on
	#     accept). Built AFTER the mutation.
	var curse_event: DomainEvent = DomainEvent.curse_applied(sequence_id, {
		"curse_source": String(definition.cursed_reward_id),
		"reason": "cursed_reward_accepted",
		"curse_before": curse_before,
		"curse_after": curse_after,
		"curse_delta": curse_after - curse_before,
		"corruption_before": corruption_before,
		"corruption_after": corruption_after,
		"corruption_delta": corruption_after - corruption_before
	})

	# (5) Build the economy_changed event (the ECONOMIC side — the benefit minus any cost; AC2 "the benefit ... applied
	#     through domain events"). A DISTINCT sequence_id (sequence_id + 1) so the round-trip never collides. The
	#     honest-record posture (the 7.1 all-zero economy_changed [Decision]): record the real before/after even if the
	#     net is 0.
	var economy_event: DomainEvent = DomainEvent.economy_changed(sequence_id + 1, {
		"reason": "cursed_reward_accepted",
		"gold_before": gold_before,
		"gold_after": gold_after,
		"gold_delta": gold_after - gold_before,
		"healing_before": healing_before,
		"healing_after": healing_after,
		"healing_delta": healing_after - healing_before
	})

	# (6) Return ok with BOTH events (the penalty event first, then the economic event) + diagnostics metadata.
	return ActionResult.ok([curse_event, economy_event], {
		"accepts_cursed_reward": true,
		"cursed_reward_id": String(definition.cursed_reward_id),
		"curse_before": curse_before,
		"curse_after": curse_after,
		"corruption_before": corruption_before,
		"corruption_after": corruption_after,
		"gold_before": gold_before,
		"gold_after": gold_after,
		"healing_before": healing_before,
		"healing_after": healing_after,
		"seats_curse": definition.applies_curse()
	})


# A single stable top-level code (invalid_context) holds the "give me a valid run" contract for the not-a-RunState /
# structurally-invalid-run cases (mirroring ApplyEconomyChangeCommand._invalid_context). When the rejection is a
# structurally-invalid run, attach the inner RunState.validate() error_code (and its metadata) for diagnosis. The
# not-a-RunState case has no inner result.
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)
