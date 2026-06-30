extends "res://tests/unit/test_case.gd"

# Story 7.1 Task 3 — ApplyEconomyChangeCommand (apply a gold/healing change -> record + emit economy_changed). Covers
# AC2 (a valid change mutates the economy + emits ONE economy_changed event recording the reason + before/after) and
# AC3 (the fail-closed / no-mutation rejections): sequence_id <= 0 rejects FIRST; a non-RunState/invalid run rejects
# invalid_context; a bad reason rejects invalid_economy_reason; a no-op (both deltas 0) rejects invalid_economy_change;
# an over-spend of gold rejects insufficient_gold; an over-spend of healing rejects insufficient_healing; and the
# command draws ZERO RNG on success AND across EVERY reject branch (the 6.7 Round-1 Low — cover multiple reject
# branches, not just one). Mirrors test_pickup_item_command.gd / test_use_consumable_command.gd (the run-command
# valid/invalid/no-mutation/no-RNG shape).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ApplyEconomyChangeCommand = preload("res://scripts/core/commands/apply_economy_change_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_credits_gold_and_emits_economy_changed()
	_spends_gold_and_emits_economy_changed()
	_adds_healing_availability()
	_credits_gold_and_heals_in_one_change()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_invalid_context()
	_rejects_a_bad_reason_with_no_mutation()
	_rejects_a_no_op_change_with_no_mutation()
	_rejects_insufficient_gold_with_no_mutation()
	_rejects_insufficient_healing_with_no_mutation()
	_draws_no_rng_on_success_and_every_reject()
	_is_deterministic()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A minimal valid run parked at a route choice (PHASE_NEW_RUN validates with a structurally-sound route).
func _valid_run() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, boss], "", [])
	var run: RunState = RunState.new_run(7, false, route)
	assert_true(run.validate().succeeded, "Setup: the valid run should validate.")
	return run


# A valid run whose wallet has been pre-seeded with `gold` and whose healing has `healing` (via a prior change so the
# state is reached only through the public command path where possible; direct seeding is fine for a fixture).
func _run_with_economy(gold: int, healing: int) -> RunState:
	var run: RunState = _valid_run()
	if gold > 0:
		run.risk_economy.apply_gold_delta(gold)
	if healing > 0:
		run.risk_economy.apply_healing_delta(healing)
	return run


# ---- AC2: successful changes ---------------------------------------------------------------------

func _credits_gold_and_emits_economy_changed() -> void:
	var run: RunState = _valid_run()
	var command: ApplyEconomyChangeCommand = ApplyEconomyChangeCommand.new(12, 0, &"gold_reward_resolved")
	var applied: ActionResult = command.execute(run)
	assert_true(applied.succeeded, "Crediting gold should succeed: %s" % applied.metadata)
	assert_equal(run.risk_economy.gold, 12, "AC2: the credited gold is recorded on the wallet.")
	# Exactly one economy_changed event recording the reason + before/after.
	assert_equal(applied.events.size(), 1, "A gold credit emits exactly one economy_changed event.")
	var event: DomainEvent = applied.events[0]
	assert_equal(event.event_type, DomainEvent.Type.ECONOMY_CHANGED, "The emitted event is economy_changed.")
	assert_equal(event.payload.get("reason"), "gold_reward_resolved", "AC2: the event records the explanation-log reason.")
	assert_equal(event.payload.get("gold_before"), 0, "The event records gold_before.")
	assert_equal(event.payload.get("gold_after"), 12, "The event records gold_after.")
	assert_equal(event.payload.get("gold_delta"), 12, "The event records the gold_delta.")
	# The event passes payload validation (real JSON round-trip).
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "The emitted economy_changed event should pass payload validation: %s" % parsed.metadata)
	assert_true(run.validate().succeeded, "A committed change should leave the run structurally valid.")


func _spends_gold_and_emits_economy_changed() -> void:
	var run: RunState = _run_with_economy(20, 0)
	var spent: ActionResult = ApplyEconomyChangeCommand.new(-8, 0, &"shop_purchase").execute(run)
	assert_true(spent.succeeded, "Spending gold should succeed: %s" % spent.metadata)
	assert_equal(run.risk_economy.gold, 12, "AC2: the spent gold is deducted from the wallet.")
	assert_equal(spent.events[0].payload.get("gold_delta"), -8, "The event records a negative gold_delta for a spend.")
	assert_equal(spent.events[0].payload.get("gold_after"), 12, "The event records the post-spend gold.")


func _adds_healing_availability() -> void:
	var run: RunState = _valid_run()
	var healed: ActionResult = ApplyEconomyChangeCommand.new(0, 2, &"rest_recovered").execute(run)
	assert_true(healed.succeeded, "Adding healing availability should succeed: %s" % healed.metadata)
	assert_equal(run.risk_economy.healing_charges, 2, "AC2: the added healing availability is recorded.")
	assert_equal(run.risk_economy.gold, 0, "A healing-only change leaves gold untouched.")
	assert_equal(healed.events[0].payload.get("healing_delta"), 2, "The event records the healing_delta.")
	assert_equal(healed.events[0].payload.get("gold_delta"), 0, "The event records a zero gold_delta for a healing-only change.")


func _credits_gold_and_heals_in_one_change() -> void:
	var run: RunState = _valid_run()
	var both: ActionResult = ApplyEconomyChangeCommand.new(5, 1, &"event_reward").execute(run)
	assert_true(both.succeeded, "A combined gold+healing change should succeed: %s" % both.metadata)
	assert_equal(run.risk_economy.gold, 5, "The combined change credits gold.")
	assert_equal(run.risk_economy.healing_charges, 1, "The combined change adds healing.")


# ---- AC3: no-mutation rejections -----------------------------------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	# The sequence-id gate fires FIRST (before context/reason/floor). A non-positive id rejects even with a perfectly
	# legal change + run, leaving the run byte-identical with zero events.
	for bad_sequence_id: int in [0, -1]:
		var run: RunState = _run_with_economy(10, 0)
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = ApplyEconomyChangeCommand.new(5, 0, &"gold_reward_resolved", bad_sequence_id).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context (no crash, no mutation possible).
	var not_a_run: ActionResult = ApplyEconomyChangeCommand.new(5, 0, &"gold_reward_resolved").execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is rejected as invalid_context, surfacing the inner error.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	var before: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = ApplyEconomyChangeCommand.new(5, 0, &"gold_reward_resolved").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner validate() error code.")
	assert_false(invalid_run.has_events(), "An invalid-context rejection should emit zero events.")
	assert_equal(after, before, "An invalid-context rejection must leave the run byte-identical.")


func _rejects_a_bad_reason_with_no_mutation() -> void:
	# An empty / hyphenated (non-lower_snake) reason is rejected (the reason is a lower_snake marker).
	for bad_reason: StringName in [&"", &"Not-Snake", &"gold reward"]:
		var run: RunState = _run_with_economy(10, 0)
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = ApplyEconomyChangeCommand.new(5, 0, bad_reason).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "A bad reason (%s) must be rejected." % String(bad_reason))
		assert_equal(rejected.error_code, &"invalid_economy_reason", "A bad reason should use the stable invalid_economy_reason code (%s)." % String(bad_reason))
		assert_false(rejected.has_events(), "A bad-reason rejection should emit zero events (%s)." % String(bad_reason))
		assert_equal(after, before, "A bad-reason rejection must leave the run byte-identical (%s)." % String(bad_reason))


func _rejects_a_no_op_change_with_no_mutation() -> void:
	# A change with BOTH deltas zero is a no-op record and is rejected.
	var run: RunState = _run_with_economy(10, 1)
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = ApplyEconomyChangeCommand.new(0, 0, &"gold_reward_resolved").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "A no-op change (both deltas 0) must be rejected.")
	assert_equal(rejected.error_code, &"invalid_economy_change", "A no-op change should use the stable invalid_economy_change code.")
	assert_false(rejected.has_events(), "A no-op rejection should emit zero events.")
	assert_equal(after, before, "A no-op rejection must leave the run byte-identical.")


func _rejects_insufficient_gold_with_no_mutation() -> void:
	# Spending more gold than held is rejected fail-closed (AC3 — currency stays unchanged).
	var run: RunState = _run_with_economy(3, 0)
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = ApplyEconomyChangeCommand.new(-4, 0, &"shop_purchase").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "An over-spend of gold must be rejected.")
	assert_equal(rejected.error_code, &"insufficient_gold", "An over-spend should use the stable insufficient_gold code.")
	assert_equal(rejected.metadata.get("gold"), 3, "The rejection should echo the held gold.")
	assert_false(rejected.has_events(), "An insufficient-gold rejection should emit zero events.")
	assert_equal(after, before, "An insufficient-gold rejection must leave the run byte-identical (no spend).")


func _rejects_insufficient_healing_with_no_mutation() -> void:
	# Spending more healing than available is rejected fail-closed.
	var run: RunState = _run_with_economy(0, 1)
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = ApplyEconomyChangeCommand.new(0, -2, &"heal_spent").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "An over-spend of healing must be rejected.")
	assert_equal(rejected.error_code, &"insufficient_healing", "An over-spend of healing should use the stable insufficient_healing code.")
	assert_equal(rejected.metadata.get("healing_charges"), 1, "The rejection should echo the held healing availability.")
	assert_false(rejected.has_events(), "An insufficient-healing rejection should emit zero events.")
	assert_equal(after, before, "An insufficient-healing rejection must leave the run byte-identical.")


# ---- AC3: determinism / no RNG -------------------------------------------------------------------

func _draws_no_rng_on_success_and_every_reject() -> void:
	# A change draws ZERO RNG. Hold a stream set, snapshot it, run a SUCCESSFUL change and EACH reject branch, and
	# assert the streams are byte-identical in every case (the command holds no RngStreamSet at all — this guards that
	# no hidden global RNG is touched; the false-PASS grep also confirms no randi/randf in the source). Per the 6.7
	# Round-1 Low, cover MULTIPLE reject branches, not just one.
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var before: Dictionary = streams.to_snapshot()

	# Success.
	ApplyEconomyChangeCommand.new(7, 0, &"gold_reward_resolved").execute(_valid_run())
	assert_equal(streams.to_snapshot(), before, "A successful change must draw no RNG (stream set unchanged).")

	# Each reject branch.
	ApplyEconomyChangeCommand.new(5, 0, &"gold_reward_resolved", 0).execute(_valid_run())  # invalid_event_sequence_id
	assert_equal(streams.to_snapshot(), before, "A sequence-id reject must draw no RNG.")
	ApplyEconomyChangeCommand.new(5, 0, &"gold_reward_resolved").execute("nope")  # invalid_context
	assert_equal(streams.to_snapshot(), before, "An invalid-context reject must draw no RNG.")
	ApplyEconomyChangeCommand.new(5, 0, &"Bad-Reason").execute(_valid_run())  # invalid_economy_reason
	assert_equal(streams.to_snapshot(), before, "A bad-reason reject must draw no RNG.")
	ApplyEconomyChangeCommand.new(0, 0, &"gold_reward_resolved").execute(_valid_run())  # invalid_economy_change
	assert_equal(streams.to_snapshot(), before, "A no-op reject must draw no RNG.")
	ApplyEconomyChangeCommand.new(-99, 0, &"shop_purchase").execute(_valid_run())  # insufficient_gold
	assert_equal(streams.to_snapshot(), before, "An insufficient-gold reject must draw no RNG.")
	ApplyEconomyChangeCommand.new(0, -99, &"heal_spent").execute(_valid_run())  # insufficient_healing
	assert_equal(streams.to_snapshot(), before, "An insufficient-healing reject must draw no RNG.")


func _is_deterministic() -> void:
	# Same starting run + same change -> byte-identical resulting run.to_dictionary().
	var run_a: RunState = _run_with_economy(10, 1)
	var run_b: RunState = _run_with_economy(10, 1)
	ApplyEconomyChangeCommand.new(5, -1, &"event_reward").execute(run_a)
	ApplyEconomyChangeCommand.new(5, -1, &"event_reward").execute(run_b)
	assert_equal(run_a.to_dictionary(), run_b.to_dictionary(), "The change must be a deterministic state transition.")
