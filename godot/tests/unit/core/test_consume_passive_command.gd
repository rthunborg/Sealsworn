extends "res://tests/unit/test_case.gd"

# Story 6.5 Task 4 — ConsumePassiveCommand (the CONSUME-passive command, the first half of the FR82
# Consume/Destroy split). Covers AC1 (a valid Consume validates the pending passive offer, ADOPTS the passive
# into the run's RulesResolver via register_passive — creating + seating a fresh resolver when the run has none,
# flips the offer to `resolved` + records the selected entry, and emits EXACTLY ONE passive_consumed event) and
# AC4 (the load-bearing no-double-consume guarantee + the fail-closed/no-mutation rejections): sequence_id <= 0
# rejects FIRST; a non-RunState/invalid run rejects invalid_context; no pending offer rejects
# no_pending_reward_offer; a non-offered passive id rejects invalid_reward_selection; an offered id that does NOT
# resolve through an injected PassiveRepository rejects unknown_passive; a SECOND consume against a resolved offer
# rejects reward_offer_already_resolved with ZERO events, ZERO RNG, byte-identical run + resolver (no second
# registration); and the command draws ZERO RNG on both success and reject.
#
# Mirrors test_resolve_reward_command.gd (the run-command valid/invalid/no-mutation/no-RNG shape). ConsumePassive
# is a DISTINCT command from ResolveReward: it REGISTERS the passive (the real adoption) + emits passive_consumed
# (NOT reward_resolved) — it does NOT compose ResolveRewardCommand (no double-record).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ConsumePassiveCommand = preload("res://scripts/core/commands/consume_passive_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const RunStartCommand = preload("res://scripts/core/commands/run_start_command.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_consumes_a_passive_registers_it_flips_the_offer_and_emits_one_event()
	_consume_seats_a_fresh_resolver_when_the_run_has_none()
	_consume_appends_after_starting_passives_in_stable_order()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_invalid_context()
	_rejects_when_no_pending_offer()
	_rejects_a_non_offered_passive_selection()
	_rejects_an_offered_passive_that_does_not_resolve_unknown_passive()
	_duplicate_consume_against_a_resolved_offer_rejects_no_double_consume()
	_consume_draws_no_rng_on_success_and_reject()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A minimal valid run parked at a route choice WITH a pending passive offer carrying the given entries.
func _run_with_passive_offer(table_id: StringName, offered_entries: Array) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, boss], "", [])
	var run: RunState = RunState.new_run(7, false, route)
	run.pending_reward_offer = RewardOffer.new(table_id, RewardOffer.STATUS_PENDING, offered_entries, {}, "rewards", 1, 0, 42)
	assert_true(run.validate().succeeded, "Setup: the run with a passive offer should validate.")
	return run


# ---- AC1: successful consume ---------------------------------------------------------------------

func _consumes_a_passive_registers_it_flips_the_offer_and_emits_one_event() -> void:
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [
		{"category": "passive", "content_id": "warrior_unbreakable_guard"},
		{"category": "passive", "content_id": "ranger_steady_aim"}
	])
	var command: ConsumePassiveCommand = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice")
	var consumed: ActionResult = command.execute(run)
	assert_true(consumed.succeeded, "Consuming a passive should succeed: %s" % consumed.metadata)

	# The passive was ADOPTED into the run's resolver (the real adoption, NOT a parallel list).
	assert_true(run.rules_resolver != null, "Consume must seat a resolver on the run.")
	assert_true(run.rules_resolver.registered_passive_ids().has(&"warrior_unbreakable_guard"), "The consumed passive must be registered into the resolver.")

	# The offer flipped to resolved + recorded the selected entry (the ResolveReward offer-flip posture).
	assert_true(run.pending_reward_offer.is_resolved(), "The offer must flip to resolved after a successful consume.")
	assert_equal(String(run.pending_reward_offer.selected_entry.get("content_id")), "warrior_unbreakable_guard", "The offer must record the selected passive entry.")
	assert_equal(String(run.pending_reward_offer.selected_entry.get("category")), "passive", "The selected entry must be the passive category.")

	# EXACTLY ONE passive_consumed event (no reward_resolved — do NOT double-record the resolution).
	assert_equal(consumed.events.size(), 1, "A consume should emit EXACTLY ONE event.")
	assert_equal(consumed.events[0].event_type, DomainEvent.Type.PASSIVE_CONSUMED, "A consume should emit a passive_consumed event.")
	for event: DomainEvent in consumed.events:
		assert_false(event.event_type == DomainEvent.Type.REWARD_RESOLVED, "A consume must NOT emit a reward_resolved event (no double-record).")
	var event: DomainEvent = consumed.events[0]
	assert_equal(event.payload.get("passive_id"), "warrior_unbreakable_guard", "passive_consumed should carry the consumed passive id.")
	assert_equal(event.payload.get("table_id"), "passive_reward_choice", "passive_consumed should carry the offer's table id.")
	# A real JSON round-trip (the emitted event must pass payload validation).
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "The emitted passive_consumed event should pass payload validation: %s" % parsed.metadata)

	# Result metadata surfaces the consume diagnostics.
	assert_true(bool(consumed.metadata.get("consumes_passive")), "The metadata should flag a consume.")
	assert_equal(String(consumed.metadata.get("passive_id")), "warrior_unbreakable_guard", "The metadata should carry the passive id.")
	assert_equal(int(consumed.metadata.get("registered_passive_count")), 1, "The metadata should report the registered-passive count.")
	assert_true(run.validate().succeeded, "A committed consume should leave the run structurally valid.")


# ---- AC1: the null-resolver case + stable ordering -----------------------------------------------

func _consume_seats_a_fresh_resolver_when_the_run_has_none() -> void:
	# A new_run / empty-class run has rules_resolver == null. Consume CREATES + seats a fresh resolver carrying
	# exactly the consumed passive (the RunStartCommand seating shape).
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [
		{"category": "passive", "content_id": "pyromancer_kindling_focus"}
	])
	assert_true(run.rules_resolver == null, "Setup: a new_run has no resolver.")
	var consumed: ActionResult = ConsumePassiveCommand.new(&"pyromancer_kindling_focus", &"passive_reward_choice").execute(run)
	assert_true(consumed.succeeded, "Consuming on a null-resolver run should succeed: %s" % consumed.metadata)
	assert_true(run.rules_resolver != null, "Consume must create + seat a resolver when the run has none.")
	assert_equal(run.rules_resolver.registered_passive_count(), 1, "The fresh resolver should carry exactly the one consumed passive.")
	assert_equal(run.rules_resolver.registered_passive_ids(), [&"pyromancer_kindling_focus"] as Array[StringName], "The fresh resolver should hold the consumed passive.")


func _consume_appends_after_starting_passives_in_stable_order() -> void:
	# A run that ALREADY has a resolver (seat one + register a starting passive) appends the consumed passive
	# AFTER the starting passives (the AC2/AC3 stable registration order: starting first, consumed second).
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [
		{"category": "passive", "content_id": "ranger_steady_aim"}
	])
	var resolver: RulesResolver = RulesResolver.new()
	var repo: PassiveRepository = PassiveRepository.create_baseline_repository()
	resolver.register_passive(repo.get_passive(&"warrior_unbreakable_guard"))
	run.rules_resolver = resolver
	assert_equal(run.rules_resolver.registered_passive_count(), 1, "Setup: the resolver holds one starting passive.")

	var consumed: ActionResult = ConsumePassiveCommand.new(&"ranger_steady_aim", &"passive_reward_choice").execute(run)
	assert_true(consumed.succeeded, "Consuming on a seeded resolver should succeed: %s" % consumed.metadata)
	assert_equal(
		run.rules_resolver.registered_passive_ids(),
		[&"warrior_unbreakable_guard", &"ranger_steady_aim"] as Array[StringName],
		"The consumed passive must be appended AFTER the starting passives (stable registration order)."
	)


# ---- AC4: no-mutation rejections -----------------------------------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	for bad_sequence_id: int in [0, -1]:
		var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", bad_sequence_id).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)
		assert_true(run.rules_resolver == null, "A sequence-id rejection must register nothing (resolver stays null) (%d)." % bad_sequence_id)


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context.
	var not_a_run: ActionResult = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is also rejected as invalid_context, with the inner error.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	run.pending_reward_offer = RewardOffer.new(&"passive_reward_choice", RewardOffer.STATUS_PENDING, [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var before: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner validate() error code for diagnosis.")
	assert_equal(after, before, "An invalid-context rejection must leave the run byte-identical.")
	assert_true(run.rules_resolver == null, "An invalid-context rejection must register nothing.")


func _rejects_when_no_pending_offer() -> void:
	# A run with NO pending offer rejects no_pending_reward_offer with zero mutation.
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var run: RunState = RunState.new_run(7, false, RouteState.new([start, boss], "", []))
	assert_true(run.pending_reward_offer == null, "Setup: the run has no pending offer.")
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "A consume with no pending offer must be rejected.")
	assert_equal(rejected.error_code, &"no_pending_reward_offer", "No pending offer should use the stable code.")
	assert_false(rejected.has_events(), "A no-offer rejection should emit zero events.")
	assert_equal(after, before, "A no-offer rejection must leave the run byte-identical.")
	assert_true(run.rules_resolver == null, "A no-offer rejection must register nothing.")


func _rejects_a_non_offered_passive_selection() -> void:
	# A passive id that is NOT one of the offered entries rejects invalid_reward_selection with zero mutation.
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	var before: Dictionary = run.to_dictionary()
	# A passive id not on the offer.
	var wrong_id: ActionResult = ConsumePassiveCommand.new(&"ranger_steady_aim", &"passive_reward_choice").execute(run)
	assert_true(wrong_id.is_error(), "A non-offered passive id must be rejected.")
	assert_equal(wrong_id.error_code, &"invalid_reward_selection", "A non-offered passive should use the stable code.")
	assert_false(wrong_id.has_events(), "A non-offered-selection rejection should emit zero events.")
	assert_equal(String(wrong_id.metadata.get("category")), "passive", "The reject metadata should carry the passive category.")
	assert_equal(String(wrong_id.metadata.get("content_id")), "ranger_steady_aim", "The reject metadata should carry the rejected content id.")
	assert_equal(run.to_dictionary(), before, "A non-offered-selection rejection must leave the run byte-identical.")
	assert_true(run.pending_reward_offer.is_pending(), "A rejected selection must leave the offer pending.")
	assert_true(run.rules_resolver == null, "A rejected selection must register nothing.")


func _rejects_an_offered_passive_that_does_not_resolve_unknown_passive() -> void:
	# An offered passive id that does NOT resolve through the injected PassiveRepository rejects unknown_passive
	# (defense-in-depth fail-closed — never register a null). The repository is injected WITHOUT that id.
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	# A fixture repository holding ONLY a different baseline passive (so warrior_unbreakable_guard does not resolve).
	var partial_repo: PassiveRepository = PassiveRepository.create_repository_from_definitions([
		PassiveDefinition.new(
			&"ranger_steady_aim", "Steady Aim", PassiveDefinition.KIND_CLASS, [RuleTrigger.BEFORE_ATTACK],
			"Steady Aim settles the shot.", PassiveDefinition.ICON_PLACEHOLDER, "A held breath.",
			"Before an attack resolves, settles the aim.", "Consume to keep the aim.", "Destroy to loose it.",
			false, "No hidden cost.", [PassiveDefinition.PILLAR_TACTICAL_CLARITY]
		)
	])
	assert_true(partial_repo != null, "Setup: the partial repository should build.")
	assert_true(partial_repo.get_passive(&"warrior_unbreakable_guard") == null, "Setup: the partial repo must not resolve the offered id.")
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice", 1, partial_repo).execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "An offered passive that does not resolve must be rejected.")
	assert_equal(rejected.error_code, &"unknown_passive", "An unresolvable passive should use the stable unknown_passive code.")
	assert_false(rejected.has_events(), "An unknown-passive rejection should emit zero events.")
	assert_equal(String(rejected.metadata.get("passive_id")), "warrior_unbreakable_guard", "The unknown-passive error should carry the passive id.")
	assert_equal(after, before, "An unknown-passive rejection must leave the run byte-identical.")
	assert_true(run.rules_resolver == null, "An unknown-passive rejection must register nothing (resolver stays null).")
	assert_true(run.pending_reward_offer.is_pending(), "An unknown-passive rejection must leave the offer pending.")


# The single most load-bearing correctness property: a SECOND consume against an already-resolved offer fails
# closed with ZERO events, ZERO RNG, byte-identical run + resolver (no second registration).
func _duplicate_consume_against_a_resolved_offer_rejects_no_double_consume() -> void:
	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	# First consume succeeds + registers + flips.
	var first: ActionResult = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute(run)
	assert_true(first.succeeded, "The first consume should succeed.")
	assert_equal(run.rules_resolver.registered_passive_count(), 1, "The first consume registers one passive.")
	assert_true(run.pending_reward_offer.is_resolved(), "The offer is resolved after the first consume.")

	# Snapshot the post-first-consume run + the resolver ids + a held RNG stream set; the SECOND consume must
	# change NOTHING.
	var before: Dictionary = run.to_dictionary()
	var resolver_ids_before: Array[StringName] = run.rules_resolver.registered_passive_ids()
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var streams_before: Dictionary = streams.to_snapshot()

	var second: ActionResult = ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(second.is_error(), "A second consume against a resolved offer must be rejected.")
	assert_equal(second.error_code, &"reward_offer_already_resolved", "A duplicate consume should use the stable reward_offer_already_resolved code.")
	assert_equal(String(second.metadata.get("table_id")), "passive_reward_choice", "The duplicate-consume error should carry the table id.")
	assert_false(second.has_events(), "A duplicate consume must emit ZERO events (no second passive_consumed).")
	# No double-consume: byte-identical run, and the resolver did NOT grow (no second registration).
	assert_equal(after, before, "A duplicate consume must leave the run byte-identical (no double-consume).")
	assert_equal(run.rules_resolver.registered_passive_count(), 1, "A duplicate consume must NOT register a second passive.")
	assert_equal(run.rules_resolver.registered_passive_ids(), resolver_ids_before, "A duplicate consume must leave the resolver byte-identical.")
	# No RNG drawn by the duplicate consume (the held stream set is byte-identical).
	assert_equal(streams.to_snapshot(), streams_before, "A duplicate consume must draw NO RNG (held stream set unchanged).")


# ---- AC1: no RNG ---------------------------------------------------------------------------------

func _consume_draws_no_rng_on_success_and_reject() -> void:
	# Consume is deterministic (a content lookup + a register + a field set). Hold a stream set, snapshot it, run a
	# SUCCESSFUL consume and a REJECTED consume, and assert the streams are byte-identical in both cases.
	#
	# NOTE (Round-1 [Review][Patch] Med — defense-in-depth, NOT a behavioral check): this held RngStreamSet is
	# INDEPENDENT of the command — ConsumePassiveCommand takes no RngStreamSet and never constructs one (see the
	# command's public API + the Task 6.3 randi/randf/RandomNumberGenerator grep on consume_passive_command.gd),
	# so this snapshot is physically unreachable by the command and the assertion is structurally tautological for
	# any implementation of THIS command. It is kept deliberately as a regression sentinel: it documents the
	# zero-RNG contract at the test layer and would start to bite if a future change wired an RNG stream INTO the
	# command (at which point this test would need to hold the run's own stream set and assert it). It is the
	# standalone twin of the load-bearing no-double-consume RNG assertion below, which is co-located with the real
	# no-double-consume property.
	var streams: RngStreamSet = RngStreamSet.new(24680)
	var before: Dictionary = streams.to_snapshot()

	var run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute(run)
	assert_equal(streams.to_snapshot(), before, "A successful consume must draw no RNG (stream set unchanged).")

	var reject_run: RunState = _run_with_passive_offer(&"passive_reward_choice", [{"category": "passive", "content_id": "warrior_unbreakable_guard"}])
	ConsumePassiveCommand.new(&"ranger_steady_aim", &"passive_reward_choice").execute(reject_run)
	assert_equal(streams.to_snapshot(), before, "A rejected consume must draw no RNG (stream set unchanged).")
