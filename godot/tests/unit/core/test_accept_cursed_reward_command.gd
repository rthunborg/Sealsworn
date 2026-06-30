extends "res://tests/unit/test_case.gd"

# Story 7.2 Task 3 — AcceptCursedRewardCommand (accept a cursed reward -> apply BOTH sides + emit events + seat the
# curse rule source). Covers AC2 (a valid accept applies the benefit AND the penalty through domain events + updates
# curse/corruption state), AC3 (the curse effect is seated on the run's RulesResolver), and the fail-closed/no-mutation
# rejections: sequence_id <= 0 rejects FIRST; a non-RunState/invalid run/null-economy rejects invalid_context; an
# unknown id rejects unknown_cursed_reward; an over-cost rejects insufficient_gold / insufficient_healing; the command
# draws ZERO RNG on success AND across EVERY reject branch (byte-identical no-mutation run); and determinism (same run +
# same id -> same result). Mirrors test_apply_economy_change_command.gd (the run-command valid/invalid/no-mutation
# shape).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const AcceptCursedRewardCommand = preload("res://scripts/core/commands/accept_cursed_reward_command.gd")
const CursedRewardDefinition = preload("res://scripts/content/definitions/cursed_reward_definition.gd")
const CursedRewardRepository = preload("res://scripts/content/repositories/cursed_reward_repository.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_accept_applies_both_sides_and_emits_both_events()
	_accept_pays_a_resource_cost_alongside_the_benefit()
	_accept_seats_the_curse_rule_source_on_the_resolver()
	_accept_without_a_curse_effect_seats_no_curse()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_invalid_context()
	_rejects_a_nulled_economy()
	_rejects_an_unknown_cursed_reward()
	_rejects_insufficient_gold_for_the_cost()
	_rejects_insufficient_healing_for_the_cost()
	_no_mutation_and_no_rng_across_every_reject()
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


# A fixture repository with three shaped cursed rewards: a curse-only (gold benefit + curse), a corruption variant, a
# cost-bearing (benefit + a gold cost + a curse), and a cost-only (benefit + gold cost, no curse).
func _fixture_repository() -> CursedRewardRepository:
	return CursedRewardRepository.create_repository_from_definitions([
		CursedRewardDefinition.new(
			&"gold_for_curse", "Gold for a Curse",
			"Gain 25 gold.", "Take on 1 curse.",
			25, 0, 1, 0, 0, 0, false, "The curse is the cost."
		),
		CursedRewardDefinition.new(
			&"heal_for_corruption", "Heal for Corruption",
			"Restore 3 healing.", "Take on 2 corruption.",
			0, 3, 0, 2, 0, 0, true, "Honestly unknown future penalty."
		),
		CursedRewardDefinition.new(
			&"power_for_a_price", "Power for a Price",
			"Gain 10 gold of power.", "Pay 4 gold and take 1 curse.",
			10, 0, 1, 0, 4, 0, false, "A gold price plus the curse."
		),
		CursedRewardDefinition.new(
			&"costly_no_curse", "Costly, No Curse",
			"Gain 8 healing.", "Pay 5 gold.",
			0, 8, 0, 0, 5, 0, false, "Only a gold price, no curse."
		)
	])


func _command(cursed_reward_id: StringName, sequence_id: int = 1) -> AcceptCursedRewardCommand:
	return AcceptCursedRewardCommand.new(cursed_reward_id, sequence_id, _fixture_repository())


# ---- AC2: a valid accept applies BOTH sides ------------------------------------------------------

func _accept_applies_both_sides_and_emits_both_events() -> void:
	var run: RunState = _valid_run()
	var accepted: ActionResult = _command(&"gold_for_curse").execute(run)
	assert_true(accepted.succeeded, "Accepting a cursed reward should succeed: %s" % accepted.metadata)

	# AC2: the BENEFIT (gold) AND the PENALTY (curse) are both applied to the economy.
	assert_equal(run.risk_economy.gold, 25, "AC2: the gold benefit is credited.")
	assert_equal(run.risk_economy.curse_count, 1, "AC2: the curse penalty is applied (curse_count updated).")

	# AC2: BOTH sides are recorded through domain events — a curse_applied (penalty) + an economy_changed (economic).
	assert_equal(accepted.events.size(), 2, "An accept emits TWO events (curse_applied + economy_changed).")
	var curse_event: DomainEvent = accepted.events[0]
	var economy_event: DomainEvent = accepted.events[1]
	assert_equal(curse_event.event_type, DomainEvent.Type.CURSE_APPLIED, "The first event is curse_applied (the penalty).")
	assert_equal(economy_event.event_type, DomainEvent.Type.ECONOMY_CHANGED, "The second event is economy_changed (the economic side).")

	# The curse_applied payload records the source + the SIGNED positive delta.
	assert_equal(String(curse_event.payload.get("curse_source")), "gold_for_curse", "AC3: the curse_applied event identifies the source.")
	assert_equal(int(curse_event.payload.get("curse_before")), 0, "The curse_applied event records curse_before.")
	assert_equal(int(curse_event.payload.get("curse_after")), 1, "The curse_applied event records curse_after.")
	assert_equal(int(curse_event.payload.get("curse_delta")), 1, "The curse_applied event records a positive curse_delta on accept.")

	# The economy_changed payload records the gold benefit.
	assert_equal(int(economy_event.payload.get("gold_before")), 0, "The economy_changed event records gold_before.")
	assert_equal(int(economy_event.payload.get("gold_after")), 25, "The economy_changed event records gold_after.")
	assert_equal(int(economy_event.payload.get("gold_delta")), 25, "The economy_changed event records the gold_delta.")

	# Each event has a UNIQUE sequence_id (curse_applied at 1, economy_changed at 2) and round-trips through real JSON.
	assert_equal(curse_event.sequence_id, 1, "The curse_applied event uses the supplied sequence_id.")
	assert_equal(economy_event.sequence_id, 2, "The economy_changed event uses sequence_id + 1 (unique).")
	_assert_event_round_trips(curse_event)
	_assert_event_round_trips(economy_event)


func _accept_pays_a_resource_cost_alongside_the_benefit() -> void:
	# A run pre-seeded with gold so the gold_cost can be paid. power_for_a_price: +10 gold benefit, -4 gold cost, +1
	# curse. Net gold +6.
	var run: RunState = _valid_run()
	run.risk_economy.apply_gold_delta(20)  # seed 20 gold
	var accepted: ActionResult = _command(&"power_for_a_price").execute(run)
	assert_true(accepted.succeeded, "Accepting a cost-bearing cursed reward should succeed: %s" % accepted.metadata)
	assert_equal(run.risk_economy.gold, 26, "The net gold change (benefit minus cost) is applied: 20 + 10 - 4 = 26.")
	assert_equal(run.risk_economy.curse_count, 1, "The curse penalty is applied.")
	# The economy_changed event records the NET gold change (before 20, after 26, delta +6).
	var economy_event: DomainEvent = accepted.events[1]
	assert_equal(int(economy_event.payload.get("gold_before")), 20, "The economy event records the pre-accept gold.")
	assert_equal(int(economy_event.payload.get("gold_after")), 26, "The economy event records the post-accept gold.")
	assert_equal(int(economy_event.payload.get("gold_delta")), 6, "The economy event records the NET gold delta (benefit minus cost).")


# ---- AC3: the curse is seated on the resolver ----------------------------------------------------

func _accept_seats_the_curse_rule_source_on_the_resolver() -> void:
	var run: RunState = _valid_run()
	assert_true(run.rules_resolver == null, "Setup: a fresh run has no resolver.")
	assert_true(_command(&"gold_for_curse").execute(run).succeeded, "The accept should succeed.")
	# AC3: a resolver is created + seated, holding the curse, and the curse resolves + EXPLAINS in its trigger window
	# with a source-identifying explanation.
	assert_true(run.rules_resolver != null, "AC3: a resolver is created + seated when the run had none.")
	assert_equal(run.rules_resolver.registered_curse_count(), 1, "AC3: the curse is registered as a rule source.")
	var explanations: Array[String] = run.rules_resolver.explain(RuleTrigger.LEVEL_ENTERED)
	assert_equal(explanations.size(), 1, "The seated curse resolves in its declared trigger window.")
	assert_true(explanations[0].contains("gold_for_curse"), "AC3: the curse's explanation identifies its source (the cursed_reward_id).")
	# The curse does NOT resolve in an unrelated window (trigger timing).
	assert_true(run.rules_resolver.explain(RuleTrigger.BEFORE_ATTACK).is_empty(), "A level_entered curse must NOT resolve in before_attack.")


func _accept_without_a_curse_effect_seats_no_curse() -> void:
	# A cost-only cursed reward (benefit + gold cost, NO curse/corruption increment) seats NO curse (applies_curse is
	# false). It still succeeds + applies the economy side.
	var run: RunState = _valid_run()
	run.risk_economy.apply_gold_delta(10)  # seed gold so the 5-gold cost can be paid
	var accepted: ActionResult = _command(&"costly_no_curse").execute(run)
	assert_true(accepted.succeeded, "A cost-only cursed reward should accept: %s" % accepted.metadata)
	assert_equal(run.risk_economy.healing_charges, 8, "The healing benefit is credited.")
	assert_equal(run.risk_economy.gold, 5, "The gold cost is paid: 10 - 5 = 5.")
	assert_true(run.rules_resolver == null or run.rules_resolver.registered_curse_count() == 0, "A no-curse cursed reward seats NO curse rule source.")
	# The curse_applied event records a ZERO curse/corruption delta (an honest record — nothing changed there).
	var curse_event: DomainEvent = accepted.events[0]
	assert_equal(int(curse_event.payload.get("curse_delta")), 0, "A no-curse reward records a zero curse_delta.")
	assert_equal(int(curse_event.payload.get("corruption_delta")), 0, "A no-curse reward records a zero corruption_delta.")


# ---- AC2 rejects (fail-closed, byte-identical no-mutation) ---------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	var run: RunState = _valid_run()
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = _command(&"gold_for_curse", 0).execute(run)
	assert_true(rejected.is_error(), "A non-positive sequence_id must reject.")
	assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence_id uses the stable code FIRST.")
	assert_true(rejected.events.is_empty(), "A reject emits ZERO events.")
	assert_equal(run.to_dictionary(), before, "A reject leaves the run byte-identical (no mutation).")


func _rejects_invalid_context() -> void:
	# A non-RunState context rejects invalid_context.
	var not_a_run: ActionResult = _command(&"gold_for_curse").execute("not a run")
	assert_true(not_a_run.is_error(), "A non-RunState context must reject.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A non-RunState context uses invalid_context.")


func _rejects_a_nulled_economy() -> void:
	var run: RunState = _valid_run()
	run.risk_economy = null  # a directly-nulled economy
	var rejected: ActionResult = _command(&"gold_for_curse").execute(run)
	assert_true(rejected.is_error(), "A nulled economy must reject.")
	assert_equal(rejected.error_code, &"invalid_context", "A nulled economy uses invalid_context (defensive guard).")
	assert_true(rejected.events.is_empty(), "A reject emits ZERO events.")


func _rejects_an_unknown_cursed_reward() -> void:
	var run: RunState = _valid_run()
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = _command(&"does_not_exist").execute(run)
	assert_true(rejected.is_error(), "An unknown cursed reward must reject.")
	assert_equal(rejected.error_code, &"unknown_cursed_reward", "An unknown id uses the stable unknown_cursed_reward code.")
	assert_equal(String(rejected.metadata.get("cursed_reward_id")), "does_not_exist", "The reject carries the offending id in metadata.")
	assert_true(rejected.events.is_empty(), "A reject emits ZERO events.")
	assert_equal(run.to_dictionary(), before, "A reject leaves the run byte-identical (no mutation).")
	assert_true(run.rules_resolver == null, "A reject seats NO curse.")


func _rejects_insufficient_gold_for_the_cost() -> void:
	# power_for_a_price costs 4 gold but gives 10 — net +6, so it would NOT overdraw from 0. To force insufficient_gold
	# we need a reward whose gold_cost exceeds gold_benefit + held gold. Use a fixture with a heavy cost and no gold
	# benefit (a healing-benefit reward with a gold cost) against an empty wallet.
	var run: RunState = _valid_run()
	var repository: CursedRewardRepository = CursedRewardRepository.create_repository_from_definitions([
		CursedRewardDefinition.new(
			&"heavy_gold_cost", "Heavy Gold Cost",
			"Restore 5 healing.", "Pay 99 gold and take 1 curse.",
			0, 5, 1, 0, 99, 0, false, "A gold price you may not be able to pay."
		)
	])
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = AcceptCursedRewardCommand.new(&"heavy_gold_cost", 1, repository).execute(run)
	assert_true(rejected.is_error(), "An over-cost gold reward must reject.")
	assert_equal(rejected.error_code, &"insufficient_gold", "An over-cost gold reward uses insufficient_gold.")
	assert_true(rejected.events.is_empty(), "A reject emits ZERO events.")
	assert_equal(run.to_dictionary(), before, "A reject leaves the run byte-identical (no mutation).")
	assert_equal(run.risk_economy.curse_count, 0, "AC2 all-or-nothing: the curse penalty is NOT applied when the cost is unaffordable.")


func _rejects_insufficient_healing_for_the_cost() -> void:
	var run: RunState = _valid_run()
	var repository: CursedRewardRepository = CursedRewardRepository.create_repository_from_definitions([
		CursedRewardDefinition.new(
			&"heavy_healing_cost", "Heavy Healing Cost",
			"Gain 5 gold.", "Pay 99 healing and take 1 curse.",
			5, 0, 1, 0, 0, 99, false, "A healing price you may not be able to pay."
		)
	])
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = AcceptCursedRewardCommand.new(&"heavy_healing_cost", 1, repository).execute(run)
	assert_true(rejected.is_error(), "An over-cost healing reward must reject.")
	assert_equal(rejected.error_code, &"insufficient_healing", "An over-cost healing reward uses insufficient_healing.")
	assert_equal(run.to_dictionary(), before, "A reject leaves the run byte-identical (no mutation).")


func _no_mutation_and_no_rng_across_every_reject() -> void:
	# The 6.7 Round-1 Low convention: re-assert the held state byte-identical across EVERY reject branch (the command
	# draws ZERO RNG and mutates nothing on any reject). The run carries some pre-seeded economy so a silent mutation
	# would be visible.
	var run: RunState = _valid_run()
	run.risk_economy.apply_gold_delta(3)
	var before: Dictionary = run.to_dictionary()

	for command: AcceptCursedRewardCommand in [
		_command(&"gold_for_curse", -1),  # bad sequence id
		_command(&"does_not_exist", 1)    # unknown id
	]:
		var rejected: ActionResult = command.execute(run)
		assert_true(rejected.is_error(), "Every reject branch must error.")
		assert_true(rejected.events.is_empty(), "Every reject branch must emit ZERO events.")
		assert_equal(run.to_dictionary(), before, "Every reject branch must leave the run byte-identical (no mutation, no RNG).")

	# The non-RunState reject (cannot mutate the run dict, but must not crash / must error).
	assert_true(_command(&"gold_for_curse").execute(42).is_error(), "A non-RunState reject must error without mutation.")
	assert_equal(run.to_dictionary(), before, "The run stays byte-identical after the non-RunState reject too.")


# ---- AC2/AC3: determinism ------------------------------------------------------------------------

func _is_deterministic() -> void:
	# Two runs accepting the same cursed reward end in the same economy + emit the same event payloads.
	var first: RunState = _valid_run()
	var second: RunState = _valid_run()
	var first_result: ActionResult = _command(&"heal_for_corruption").execute(first)
	var second_result: ActionResult = _command(&"heal_for_corruption").execute(second)
	assert_true(first_result.succeeded and second_result.succeeded, "Both accepts should succeed.")
	assert_equal(first.risk_economy.to_dictionary(), second.risk_economy.to_dictionary(), "Same run + same id -> byte-identical economy.")
	assert_equal(first_result.events[0].payload, second_result.events[0].payload, "Same accept -> byte-identical curse_applied payload.")
	assert_equal(first_result.events[1].payload, second_result.events[1].payload, "Same accept -> byte-identical economy_changed payload.")
	# corruption was applied (heal_for_corruption: +3 healing, +2 corruption).
	assert_equal(first.risk_economy.corruption, 2, "The corruption penalty is applied.")
	assert_equal(first.risk_economy.healing_charges, 3, "The healing benefit is credited.")


# ---- shared assertion ----------------------------------------------------------------------------

func _assert_event_round_trips(event: DomainEvent) -> void:
	# Real JSON round-trip (the project save discipline): the event's payload survives JSON.stringify -> parse_string
	# and re-validates.
	var as_dict: Dictionary = event.to_dictionary()
	var json_text: String = JSON.stringify(as_dict)
	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary, "The event must survive a JSON round-trip.")
	var restored: DomainEvent = DomainEvent.from_dictionary(parsed)
	assert_true(restored != null, "The round-tripped event must reconstruct.")
	assert_equal(restored.event_type, event.event_type, "The round-tripped event type must match.")
