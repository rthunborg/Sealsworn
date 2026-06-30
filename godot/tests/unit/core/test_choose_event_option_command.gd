extends "res://tests/unit/test_case.gd"

# Story 7.3 Task 4 — ChooseEventOptionCommand (choose a risk/reward event option -> apply BOTH sides + RAISE the risk
# flag(s) + emit events + flip the offer). Covers AC2 (a valid choose applies the reward AND the risk through domain
# events, updates economy, AND RAISES the choice's risk flag — the headline `risk_flags` PRODUCER test), AC3 (a second
# choose against a resolved offer / an off-offer choice fails closed with NO extra reward/penalty), and the
# fail-closed/no-mutation rejections: sequence_id <= 0 rejects FIRST; a non-RunState/invalid run/null-economy rejects
# invalid_context; no pending offer rejects no_pending_event_offer; an off-offer choice rejects invalid_event_choice; an
# over-cost rejects insufficient_gold / insufficient_healing; the command draws ZERO RNG on success AND across EVERY
# reject branch (byte-identical no-mutation run); and determinism (same run + same offer + same choice -> same result).
# Mirrors test_accept_cursed_reward_command.gd.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ChooseEventOptionCommand = preload("res://scripts/core/commands/choose_event_option_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const EventChoiceDefinition = preload("res://scripts/content/definitions/event_choice_definition.gd")
const EventDefinition = preload("res://scripts/content/definitions/event_definition.gd")
const EventOffer = preload("res://scripts/run/event_offer.gd")
const EventRepository = preload("res://scripts/content/repositories/event_repository.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_choose_applies_both_sides_and_raises_the_flag_and_emits_events()
	_choose_a_corruption_option_emits_curse_applied()
	_choose_pays_a_resource_cost_alongside_the_benefit()
	_choose_a_safe_decline_emits_no_curse_and_raises_no_flag()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_invalid_context()
	_rejects_a_nulled_economy()
	_rejects_no_pending_offer()
	_rejects_an_off_offer_choice()
	_rejects_insufficient_gold_for_the_cost()
	_no_double_apply_a_second_choose_against_a_resolved_offer()
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


# A fixture repository with shaped events: a flag-raising tradeoff event, a corruption event, a cost-bearing event.
func _fixture_repository() -> EventRepository:
	return EventRepository.create_repository_from_definitions([
		EventDefinition.new(
			&"gold_for_flag", "Gold for a Flag", "Take gold, raise a future-danger flag.",
			[
				EventChoiceDefinition.new(&"take_gold", "Take 25 gold and raise the elite flag.", 25, 0, 0, 0, 0, 0, ["elite_chance"]),
				EventChoiceDefinition.new(&"decline", "Leave it.", 0, 0, 0, 0, 0, 0, [])
			]
		),
		EventDefinition.new(
			&"reforge", "Reforge", "Reforge cheaply, add corruption.",
			[
				EventChoiceDefinition.new(&"reforge_cheap", "Recover 18 gold and add 1 corruption.", 18, 0, 0, 1, 0, 0, []),
				EventChoiceDefinition.new(&"walk", "Walk away.", 0, 0, 0, 0, 0, 0, [])
			]
		),
		EventDefinition.new(
			&"power_for_price", "Power for a Price", "Pay gold for power, take a curse + a flag.",
			[
				EventChoiceDefinition.new(&"claim", "Gain 10 gold, pay 4 gold, take 1 curse, raise max_hp_loss.", 10, 0, 1, 0, 4, 0, ["max_hp_loss"]),
				EventChoiceDefinition.new(&"refuse", "Refuse.", 0, 0, 0, 0, 0, 0, [])
			]
		)
	])


# Seat a pending event offer on the run (mirroring the GENERATE output) for the given event id. The repository must
# match the command's repository so the offer's event id resolves.
func _seat_offer(run: RunState, repository: EventRepository, event_id: StringName) -> void:
	var definition: EventDefinition = repository.get_event(event_id)
	assert_true(definition != null, "Setup: the fixture event %s must resolve." % String(event_id))
	var offered_choice_ids: Array = []
	for choice_id: StringName in definition.choice_ids():
		offered_choice_ids.append(String(choice_id))
	run.pending_event_offer = EventOffer.new(event_id, EventOffer.STATUS_PENDING, offered_choice_ids, &"", "events", 1, 1, 123)


func _command(choice_id: StringName, sequence_id: int, repository: EventRepository) -> ChooseEventOptionCommand:
	return ChooseEventOptionCommand.new(choice_id, sequence_id, repository)


# ---- AC2: a valid choose applies BOTH sides AND raises the flag -----------------------------------

func _choose_applies_both_sides_and_raises_the_flag_and_emits_events() -> void:
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()
	_seat_offer(run, repository, &"gold_for_flag")
	var chosen: ActionResult = _command(&"take_gold", 1, repository).execute(run)
	assert_true(chosen.succeeded, "Choosing an event option should succeed: %s" % chosen.metadata)

	# AC2: the REWARD (gold) is credited.
	assert_equal(run.risk_economy.gold, 25, "AC2: the gold benefit is credited.")
	# AC2 (the HEADLINE PRODUCER assertion): the choice's risk flag is RAISED — has_risk_flag(...) is true afterward.
	assert_true(run.risk_economy.has_risk_flag(&"elite_chance"), "AC2: the chosen risk option RAISES its risk flag (the risk_flags PRODUCER — has_risk_flag true).")

	# AC2: the offer is flipped to resolved + records the selected choice id.
	assert_true(run.pending_event_offer.is_resolved(), "The offer is flipped to resolved after a choose.")
	assert_equal(run.pending_event_offer.selected_choice_id, &"take_gold", "The offer records the selected choice id.")

	# AC2: BOTH sides are recorded through domain events — event_resolved (the resolution + risk-flag record) + an
	# economy_changed (the reward side). This choice applies NO curse, so there is NO curse_applied (2 events).
	assert_equal(chosen.events.size(), 2, "A no-curse choose emits TWO events (event_resolved + economy_changed).")
	var resolved_event: DomainEvent = chosen.events[0]
	var economy_event: DomainEvent = chosen.events[1]
	assert_equal(resolved_event.event_type, DomainEvent.Type.EVENT_RESOLVED, "The first event is event_resolved.")
	assert_equal(economy_event.event_type, DomainEvent.Type.ECONOMY_CHANGED, "The second event is economy_changed (the reward side).")
	# The event_resolved payload records the chosen event + choice + the RAISED risk flag (the AC2 record).
	assert_equal(String(resolved_event.payload.get("event_id")), "gold_for_flag", "event_resolved records the chosen event id.")
	assert_equal(String(resolved_event.payload.get("choice_id")), "take_gold", "event_resolved records the chosen choice id.")
	assert_equal((resolved_event.payload.get("risk_flags") as Array), ["elite_chance"], "AC2: event_resolved records the raised risk flag.")
	# The economy_changed payload records the gold reward.
	assert_equal(int(economy_event.payload.get("gold_delta")), 25, "economy_changed records the gold reward delta.")
	# Each event has a UNIQUE sequence_id (event_resolved at 1, economy_changed at 2) and round-trips through real JSON.
	assert_equal(resolved_event.sequence_id, 1, "event_resolved uses the supplied sequence_id.")
	assert_equal(economy_event.sequence_id, 2, "economy_changed uses sequence_id + 1 (unique).")
	_assert_event_round_trips(resolved_event)
	_assert_event_round_trips(economy_event)


func _choose_a_corruption_option_emits_curse_applied() -> void:
	# A corruption choice (reforge_cheap: +18 gold, +1 corruption, no flag) applies a curse/corruption increment, so it
	# emits THREE events: event_resolved + economy_changed + curse_applied.
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()
	_seat_offer(run, repository, &"reforge")
	var chosen: ActionResult = _command(&"reforge_cheap", 1, repository).execute(run)
	assert_true(chosen.succeeded, "Choosing the corruption option should succeed: %s" % chosen.metadata)
	assert_equal(run.risk_economy.gold, 18, "The gold benefit is credited.")
	assert_equal(run.risk_economy.corruption, 1, "AC2: the corruption risk is applied.")
	assert_equal(chosen.events.size(), 3, "A curse/corruption choose emits THREE events (event_resolved + economy_changed + curse_applied).")
	var curse_event: DomainEvent = chosen.events[2]
	assert_equal(curse_event.event_type, DomainEvent.Type.CURSE_APPLIED, "The third event is curse_applied (the risk side).")
	assert_equal(String(curse_event.payload.get("curse_source")), "reforge", "curse_applied identifies the event as the source.")
	assert_equal(int(curse_event.payload.get("corruption_delta")), 1, "curse_applied records the corruption increment.")
	assert_equal(curse_event.sequence_id, 3, "curse_applied uses sequence_id + 2 (unique).")
	_assert_event_round_trips(curse_event)
	# A choice with no raised flag records an EMPTY risk_flags list on event_resolved.
	assert_equal((chosen.events[0].payload.get("risk_flags") as Array).size(), 0, "A no-flag choice records an empty risk_flags list.")


func _choose_pays_a_resource_cost_alongside_the_benefit() -> void:
	# power_for_price/claim: +10 gold benefit, -4 gold cost, +1 curse, raises max_hp_loss. Net gold +6.
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()
	run.risk_economy.apply_gold_delta(20)  # seed 20 gold
	_seat_offer(run, repository, &"power_for_price")
	var chosen: ActionResult = _command(&"claim", 1, repository).execute(run)
	assert_true(chosen.succeeded, "Choosing the cost-bearing option should succeed: %s" % chosen.metadata)
	assert_equal(run.risk_economy.gold, 26, "The net gold change (benefit minus cost) is applied: 20 + 10 - 4 = 26.")
	assert_equal(run.risk_economy.curse_count, 1, "The curse risk is applied.")
	assert_true(run.risk_economy.has_risk_flag(&"max_hp_loss"), "AC2: the max_hp_loss flag is raised.")
	# The economy_changed event records the NET gold change (before 20, after 26, delta +6).
	var economy_event: DomainEvent = chosen.events[1]
	assert_equal(int(economy_event.payload.get("gold_delta")), 6, "economy_changed records the NET gold delta (benefit minus cost).")


func _choose_a_safe_decline_emits_no_curse_and_raises_no_flag() -> void:
	# A safe decline (decline: no reward, no risk, no flag) still succeeds + flips the offer + emits event_resolved +
	# economy_changed (a no-op economy record), but NO curse_applied and raises NO flag.
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()
	_seat_offer(run, repository, &"gold_for_flag")
	var chosen: ActionResult = _command(&"decline", 1, repository).execute(run)
	assert_true(chosen.succeeded, "Choosing a safe decline should succeed: %s" % chosen.metadata)
	assert_equal(run.risk_economy.gold, 0, "A safe decline credits no gold.")
	assert_equal(run.risk_economy.risk_flags, [], "A safe decline raises NO risk flag.")
	assert_true(run.pending_event_offer.is_resolved(), "A safe decline still resolves the offer.")
	assert_equal(chosen.events.size(), 2, "A safe decline emits TWO events (event_resolved + economy_changed), NO curse_applied.")
	assert_equal(int(chosen.events[1].payload.get("gold_delta")), 0, "A safe decline records a zero gold delta (honest no-op record).")


# ---- AC3 rejects (fail-closed, byte-identical no-mutation, NO extra reward/penalty) --------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()
	_seat_offer(run, repository, &"gold_for_flag")
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = _command(&"take_gold", 0, repository).execute(run)
	assert_true(rejected.is_error(), "A non-positive sequence_id must reject.")
	assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence_id uses the stable code FIRST.")
	assert_true(rejected.events.is_empty(), "A reject emits ZERO events.")
	assert_equal(run.to_dictionary(), before, "A reject leaves the run byte-identical (no mutation, no extra reward/penalty).")


func _rejects_invalid_context() -> void:
	var repository: EventRepository = _fixture_repository()
	var not_a_run: ActionResult = _command(&"take_gold", 1, repository).execute("not a run")
	assert_true(not_a_run.is_error(), "A non-RunState context must reject.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A non-RunState context uses invalid_context.")


func _rejects_a_nulled_economy() -> void:
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()
	_seat_offer(run, repository, &"gold_for_flag")
	run.risk_economy = null  # a directly-nulled economy
	var rejected: ActionResult = _command(&"take_gold", 1, repository).execute(run)
	assert_true(rejected.is_error(), "A nulled economy must reject.")
	assert_equal(rejected.error_code, &"invalid_context", "A nulled economy uses invalid_context (defensive guard).")
	assert_true(rejected.events.is_empty(), "A reject emits ZERO events.")


func _rejects_no_pending_offer() -> void:
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()  # NO pending event offer
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = _command(&"take_gold", 1, repository).execute(run)
	assert_true(rejected.is_error(), "Choosing with no pending offer must reject.")
	assert_equal(rejected.error_code, &"no_pending_event_offer", "No pending offer uses the stable no_pending_event_offer code.")
	assert_true(rejected.events.is_empty(), "A reject emits ZERO events.")
	assert_equal(run.to_dictionary(), before, "A reject leaves the run byte-identical (no mutation).")


func _rejects_an_off_offer_choice() -> void:
	# A choice id that is NOT one of the offered choices rejects invalid_event_choice (the off-offer reject) with NO
	# reward/penalty applied (AC3).
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()
	_seat_offer(run, repository, &"gold_for_flag")
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = _command(&"not_an_offered_choice", 1, repository).execute(run)
	assert_true(rejected.is_error(), "An off-offer choice must reject.")
	assert_equal(rejected.error_code, &"invalid_event_choice", "An off-offer choice uses the stable invalid_event_choice code.")
	assert_equal(String(rejected.metadata.get("choice_id")), "not_an_offered_choice", "The reject carries the offending choice id in metadata.")
	assert_true(rejected.events.is_empty(), "A reject emits ZERO events.")
	assert_equal(run.to_dictionary(), before, "A reject leaves the run byte-identical (no extra reward/penalty — AC3).")
	assert_false(run.pending_event_offer.is_resolved(), "An off-offer reject leaves the offer PENDING (not resolved).")


func _rejects_insufficient_gold_for_the_cost() -> void:
	# A choice whose gold_cost exceeds gold_benefit + held gold rejects insufficient_gold, all-or-nothing (NO part of
	# the reward/risk is applied — AC3).
	var repository: EventRepository = EventRepository.create_repository_from_definitions([
		EventDefinition.new(
			&"heavy_cost", "Heavy Cost", "A choice you cannot afford.",
			[
				EventChoiceDefinition.new(&"overpay", "Gain 5 healing but pay 99 gold and take 1 curse.", 0, 5, 1, 0, 99, 0, ["a_flag"]),
				EventChoiceDefinition.new(&"skip", "Skip.", 0, 0, 0, 0, 0, 0, [])
			]
		)
	])
	var run: RunState = _valid_run()
	_seat_offer(run, repository, &"heavy_cost")
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = _command(&"overpay", 1, repository).execute(run)
	assert_true(rejected.is_error(), "An over-cost choice must reject.")
	assert_equal(rejected.error_code, &"insufficient_gold", "An over-cost choice uses insufficient_gold.")
	assert_true(rejected.events.is_empty(), "A reject emits ZERO events.")
	assert_equal(run.to_dictionary(), before, "A reject leaves the run byte-identical (no mutation).")
	assert_equal(run.risk_economy.curse_count, 0, "AC2/AC3 all-or-nothing: the curse risk is NOT applied when the cost is unaffordable.")
	assert_false(run.risk_economy.has_risk_flag(&"a_flag"), "AC3 all-or-nothing: the flag is NOT raised when the cost is unaffordable.")


# ---- AC3 no-double-apply -------------------------------------------------------------------------

func _no_double_apply_a_second_choose_against_a_resolved_offer() -> void:
	# The load-bearing AC3 no-double-apply: after a successful choose flips the offer to resolved, a SECOND choose
	# rejects at validate() BEFORE any credit -> ZERO second reward, the flag is not re-raised, byte-identical run.
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()
	_seat_offer(run, repository, &"gold_for_flag")
	var first: ActionResult = _command(&"take_gold", 1, repository).execute(run)
	assert_true(first.succeeded, "The first choose should succeed.")
	assert_equal(run.risk_economy.gold, 25, "The first choose credits the gold.")
	var after_first: Dictionary = run.to_dictionary()

	# A SECOND choose (any choice) against the now-resolved offer rejects fail-closed.
	var second: ActionResult = _command(&"take_gold", 2, repository).execute(run)
	assert_true(second.is_error(), "A second choose against a resolved offer must reject (AC3 no-double-apply).")
	assert_equal(second.error_code, &"event_offer_already_resolved", "A second choose uses the stable event_offer_already_resolved code.")
	assert_true(second.events.is_empty(), "A second choose emits ZERO events.")
	assert_equal(run.risk_economy.gold, 25, "A second choose applies NO second reward (gold unchanged).")
	assert_equal(run.to_dictionary(), after_first, "A second choose leaves the run byte-identical to after the first (no extra reward/penalty — AC3).")


# ---- ZERO RNG across success + every reject ------------------------------------------------------

func _no_mutation_and_no_rng_across_every_reject() -> void:
	# The 6.7 Round-1 Low convention: re-assert the held state byte-identical across EVERY reject branch (the command
	# draws ZERO RNG and mutates nothing on any reject). The run carries some pre-seeded economy so a silent mutation
	# would be visible.
	var repository: EventRepository = _fixture_repository()
	var run: RunState = _valid_run()
	run.risk_economy.apply_gold_delta(3)
	_seat_offer(run, repository, &"gold_for_flag")
	var before: Dictionary = run.to_dictionary()

	for command: ChooseEventOptionCommand in [
		_command(&"take_gold", -1, repository),          # bad sequence id
		_command(&"not_an_offered_choice", 1, repository) # off-offer choice
	]:
		var rejected: ActionResult = command.execute(run)
		assert_true(rejected.is_error(), "Every reject branch must error.")
		assert_true(rejected.events.is_empty(), "Every reject branch must emit ZERO events.")
		assert_equal(run.to_dictionary(), before, "Every reject branch must leave the run byte-identical (no mutation, no RNG).")

	# The non-RunState reject (cannot mutate the run dict, but must not crash / must error).
	assert_true(_command(&"take_gold", 1, repository).execute(42).is_error(), "A non-RunState reject must error without mutation.")
	assert_equal(run.to_dictionary(), before, "The run stays byte-identical after the non-RunState reject too.")

	# A successful choose draws ZERO RNG too (the OFFER was rolled at GENERATE; the choose applies authored amounts).
	# Hold a stream set, snapshot it, run a successful choose, assert the streams are byte-identical (no draw). The
	# command takes no streams — this proves it constructs no RandomNumberGenerator / draws nothing.
	var streams: RngStreamSet = RngStreamSet.new(99)
	var streams_before: Dictionary = streams.to_snapshot()
	var success_run: RunState = _valid_run()
	_seat_offer(success_run, repository, &"gold_for_flag")
	assert_true(_command(&"take_gold", 1, repository).execute(success_run).succeeded, "The success choose should succeed.")
	assert_equal(streams.to_snapshot(), streams_before, "A successful choose draws ZERO RNG (a held stream set is byte-identical).")


# ---- determinism ---------------------------------------------------------------------------------

func _is_deterministic() -> void:
	var repository: EventRepository = _fixture_repository()
	var first: RunState = _valid_run()
	var second: RunState = _valid_run()
	_seat_offer(first, repository, &"reforge")
	_seat_offer(second, repository, &"reforge")
	var first_result: ActionResult = _command(&"reforge_cheap", 1, repository).execute(first)
	var second_result: ActionResult = _command(&"reforge_cheap", 1, repository).execute(second)
	assert_true(first_result.succeeded and second_result.succeeded, "Both chooses should succeed.")
	assert_equal(first.risk_economy.to_dictionary(), second.risk_economy.to_dictionary(), "Same run + same offer + same choice -> byte-identical economy.")
	assert_equal(first_result.events[0].payload, second_result.events[0].payload, "Same choose -> byte-identical event_resolved payload.")
	assert_equal(first_result.events[2].payload, second_result.events[2].payload, "Same choose -> byte-identical curse_applied payload.")


# ---- shared assertion ----------------------------------------------------------------------------

func _assert_event_round_trips(event: DomainEvent) -> void:
	var as_dict: Dictionary = event.to_dictionary()
	var json_text: String = JSON.stringify(as_dict)
	var parsed: Variant = JSON.parse_string(json_text)
	assert_true(parsed is Dictionary, "The event must survive a JSON round-trip.")
	var restored: DomainEvent = DomainEvent.from_dictionary(parsed)
	assert_true(restored != null, "The round-tripped event must reconstruct.")
	assert_equal(restored.event_type, event.event_type, "The round-tripped event type must match.")
