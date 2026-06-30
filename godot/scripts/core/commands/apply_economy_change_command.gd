class_name ApplyEconomyChangeCommand
extends "res://scripts/core/commands/game_command.gd"

# The ECONOMY-CHANGE command (Story 7.1, AC2/AC3) — a RUN-domain command that applies a gold and/or healing change to
# the run's RiskEconomyState and emits ONE deterministic economy_changed SYSTEM event recording the reason + the
# before/after amounts (AC2's "deterministic currency or healing events" + "the explanation log records the reason"),
# or fails closed with a stable error when the change is invalid (AC3 — currency/health remain unchanged). It follows
# the 4.3-ratified run-command idiom VERBATIM (the PickupItemCommand / ResolveRewardCommand template): it extends
# game_command.gd, takes the live RunState DIRECTLY as its validate(state)/execute(state) arg (NO wrapper), the CALLER
# supplies the run-level sequence_id via the constructor (default 1), validate() rejects sequence_id <= 0 FIRST so a
# success path can never emit an event its own validator rejects, and it is validate-then-mutate: on ANY rejection it
# returns a structured ActionResult.error with ZERO events and a byte-identical no-mutation RunState; it applies the
# change + builds the economy_changed event ONLY AFTER validation.
#
# IT DRAWS ZERO RNG. A credit / spend / heal is a RECORDED amount, not a roll (deterministic, like item_consumed —
# NOT passive_destroyed). The named-RNG rule is satisfied trivially: there is no RandomNumberGenerator here, no
# randi/randf, no stream draw. (If a future GAMBLING-style random economy outcome is ever added, that draw MUST go
# through the run-level RngStreamSet on the rewards/events stream — but no AC here requires it.)
#
# WHAT THIS IS (a single parameterized economy command):
#   - new_gold_delta:    a SIGNED gold change (positive credits, negative spends). 0 means "no gold change".
#   - new_healing_delta: a SIGNED healing-availability change (positive adds, negative spends). 0 means "no change".
#   - new_reason:        the AC2 explanation-log reason, a lower_snake marker id (e.g. gold_reward_resolved /
#                        heal_spent / curse_gold_penalty). REQUIRED + validated.
# At least one of the two deltas must be non-zero (a no-op change is rejected — invalid_economy_change).
#
# WHAT THIS IS NOT (scope boundaries, Story 7.1):
#   - NOT a curse/corruption RULE or the cursed-reward tradeoff (Story 7.2). It does NOT change curse/corruption (the
#     structural setters on RiskEconomyState are 7.2's to drive).
#   - NOT the risk/reward event roll (Story 7.3). It does NOT add risk flags.
#   - NOT the gold-reward wire-off itself (that lives in ResolveRewardCommand — this command is the DIRECT
#     caller-driven economy mutation; the reward path credits the wallet via the same RiskEconomyState API).

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RiskEconomyState = preload("res://scripts/run/risk_economy_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var gold_delta: int = 0
var healing_delta: int = 0
var reason: StringName = &""
var sequence_id: int = 1

func _init(new_gold_delta: int = 0, new_healing_delta: int = 0, new_reason: StringName = &"", new_sequence_id: int = 1) -> void:
	command_id = &"apply_economy_change"
	gold_delta = new_gold_delta
	healing_delta = new_healing_delta
	reason = new_reason
	sequence_id = new_sequence_id


# Pure read: validate the sequence id, context, reason, that the change is non-empty, and that neither field would go
# below its floor. No mutation, no event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the PickupItemCommand precedent): execute() builds an economy_changed event with this
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
	# The run must be structurally sound before we change its economy.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# The reason must be a lower_snake marker id (the AC2 explanation-log record). A bad/empty reason is rejected with
	# a stable code; the offending reason rides metadata (NOT the code — codes carry no arbitrary ids).
	if not _is_lower_snake_id(String(reason)):
		return ActionResult.error(&"invalid_economy_reason", {
			"command": String(command_id),
			"reason": String(reason)
		})

	# A no-op change (both deltas zero) is rejected — a change must change something (no empty record).
	if gold_delta == 0 and healing_delta == 0:
		return ActionResult.error(&"invalid_economy_change", {
			"command": String(command_id),
			"gold_delta": gold_delta,
			"healing_delta": healing_delta
		})

	var economy: RiskEconomyState = run.risk_economy
	if economy == null:
		# Defensive: RunState defaults a non-null economy, but a directly-nulled field would otherwise crash.
		return _invalid_context()

	# AC3: a change that would drive gold below 0 (spending more than held) is rejected fail-closed — ZERO mutation.
	if not economy.can_apply_gold_delta(gold_delta):
		return ActionResult.error(&"insufficient_gold", {
			"command": String(command_id),
			"gold": economy.gold,
			"gold_delta": gold_delta
		})
	# AC3: a change that would drive healing availability below 0 is rejected fail-closed — ZERO mutation.
	if not economy.can_apply_healing_delta(healing_delta):
		return ActionResult.error(&"insufficient_healing", {
			"command": String(command_id),
			"healing_charges": economy.healing_charges,
			"healing_delta": healing_delta
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: apply the gold/healing change to the run's economy + emit ONE economy_changed
# event (built AFTER the infallible-once-validated mutation, carrying the reason + before/after amounts). On any
# reject: structured error, ZERO events, byte-identical RunState. Draws ZERO RNG.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var economy: RiskEconomyState = run.risk_economy

	# (1) Capture the before amounts, then apply each delta (infallible once validated — both floors were checked).
	var gold_before: int = economy.gold
	var healing_before: int = economy.healing_charges
	economy.apply_gold_delta(gold_delta)
	economy.apply_healing_delta(healing_delta)
	var gold_after: int = economy.gold
	var healing_after: int = economy.healing_charges

	# (2) Build the single economy_changed system event AFTER the mutation (the AC2 explanation-log record).
	var event: DomainEvent = DomainEvent.economy_changed(sequence_id, {
		"reason": String(reason),
		"gold_before": gold_before,
		"gold_after": gold_after,
		"gold_delta": gold_delta,
		"healing_before": healing_before,
		"healing_after": healing_after,
		"healing_delta": healing_delta
	})

	# (3) Return ok with the event + diagnostics metadata.
	return ActionResult.ok([event], {
		"applies_economy_change": true,
		"reason": String(reason),
		"gold_before": gold_before,
		"gold_after": gold_after,
		"gold_delta": gold_delta,
		"healing_before": healing_before,
		"healing_after": healing_after,
		"healing_delta": healing_delta
	})


# A single stable top-level code (invalid_context) holds the "give me a valid run" contract for the not-a-RunState /
# structurally-invalid-run cases (mirroring PickupItemCommand._invalid_context). When the rejection is a
# structurally-invalid run, attach the inner RunState.validate() error_code (and its metadata) for diagnosis. The
# not-a-RunState case has no inner result.
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)


# Local lower_snake id check (kept LOCAL to the command — matches PickupItemCommand._is_lower_snake_id /
# DomainEvent._is_lower_snake_id): non-empty, all [a-z0-9_], no hyphens.
static func _is_lower_snake_id(value: String) -> bool:
	if value.is_empty():
		return false
	if value != value.to_lower():
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false
	return true
