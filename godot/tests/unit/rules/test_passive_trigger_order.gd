extends "res://tests/unit/test_case.gd"

# Story 6.5 Task 5 — passive trigger-order fixtures (AC2/AC3). These prove the v0 EXPLANATION-ONLY rules-kernel
# resolution contract across STARTING + CONSUMED passives, end-to-end THROUGH ConsumePassiveCommand (the seam
# every consumed passive flows through, so "new passive content cannot bypass those fixtures"):
#   - TIMING:      a passive resolves ONLY in its declared trigger window(s), not others.
#   - ORDER:       a starting passive AND a consumed passive declaring the SAME window resolve in STABLE
#                  REGISTRATION order — starting first (registered at run-start), consumed second (appended by
#                  ConsumePassiveCommand).
#   - EXPLANATION: explain(window) surfaces BOTH explanation lines in the SAME stable order.
#   - STACKING:    two consumed passives declaring the same window both surface in consume order (no silent drop).
#   - DETERMINISM: byte-identical resolved id list + explanation list for the same registration sequence.
#   - CONTENT GATE: the validated-only PassiveRepository load is the content gate — a passive id that does NOT
#                  resolve fails unknown_passive and registers NOTHING (a passive that fails validate() is never
#                  in the repository, so it can never be consumed).
#
# SCOPE (v0): ONLY starting passives + consumed passives exist as rule sources. Item-effect rules (later
# Epic-6/7), affinity rules (Epic 7), and the per-effect conflict-RESOLUTION engine (priority/duration/operation
# — the later Epic-6 operations story) do NOT exist; the "conflict handling" v0 meaning is "stable deterministic
# order with no drop". v0 passives are EXPLANATION-ONLY — resolution SURFACES the passive + its explanation, it
# does NOT mutate an HP/damage/movement number. Those are tracked forward residuals; this story does NOT build
# them.
#
# Mirrors/extends test_rules_resolver.gd (the stable-order/explain/determinism shape) but drives the
# starting+consumed scenario through the real ConsumePassiveCommand.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ConsumePassiveCommand = preload("res://scripts/core/commands/consume_passive_command.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_starting_and_consumed_resolve_in_stable_registration_order()
	_explain_surfaces_both_lines_in_stable_order()
	_a_passive_resolves_only_in_its_declared_window()
	_two_consumed_passives_stack_in_consume_order()
	_resolution_is_deterministic_for_the_same_consume_sequence()
	_an_unresolved_passive_id_fails_unknown_passive_and_registers_nothing()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A minimal valid run parked at a route choice WITH a pending passive offer carrying the given entries.
func _run_with_passive_offer(offered_entries: Array) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, boss], "", [])
	var run: RunState = RunState.new_run(7, false, route)
	run.pending_reward_offer = RewardOffer.new(&"passive_reward_choice", RewardOffer.STATUS_PENDING, offered_entries, {}, "rewards", 1, 0, 42)
	assert_true(run.validate().succeeded, "Setup: the run with a passive offer should validate.")
	return run


# Seat a resolver on the run holding the given STARTING passive id (the run-start posture), resolved through the
# validated baseline repository so the registered passive is real content.
func _seat_starting_resolver(run: RunState, starting_passive_id: StringName) -> void:
	var resolver: RulesResolver = RulesResolver.new()
	var repo: PassiveRepository = PassiveRepository.create_baseline_repository()
	resolver.register_passive(repo.get_passive(starting_passive_id))
	run.rules_resolver = resolver
	assert_equal(run.rules_resolver.registered_passive_count(), 1, "Setup: the resolver should hold exactly the one starting passive.")


# An offered passive entry for the offer's offered_entries list.
func _passive_entry(passive_id: StringName) -> Dictionary:
	return {"category": "passive", "content_id": String(passive_id)}


func _resolved_ids(resolver: RulesResolver, window_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition: PassiveDefinition in resolver.resolve(window_id):
		ids.append(definition.passive_id)
	return ids


# ---- AC2/AC3: stable registration order across starting + consumed --------------------------------

func _starting_and_consumed_resolve_in_stable_registration_order() -> void:
	# A STARTING class passive (warrior_unbreakable_guard, before_attack) is seated at run-start; a CONSUMED class
	# passive that ALSO declares before_attack (pyromancer_kindling_focus) is consumed. Both resolve in
	# before_attack in REGISTRATION order — starting first, consumed second.
	var run: RunState = _run_with_passive_offer([_passive_entry(&"pyromancer_kindling_focus")])
	_seat_starting_resolver(run, &"warrior_unbreakable_guard")

	var consumed: ActionResult = ConsumePassiveCommand.new(&"pyromancer_kindling_focus", &"passive_reward_choice").execute(run)
	assert_true(consumed.succeeded, "Consuming a before_attack passive should succeed: %s" % consumed.metadata)

	var resolved: Array[StringName] = _resolved_ids(run.rules_resolver, RuleTrigger.BEFORE_ATTACK)
	assert_equal(resolved.size(), 2, "Both the starting and consumed before_attack passives should resolve.")
	assert_equal(resolved[0], &"warrior_unbreakable_guard", "The STARTING passive resolves first (registered at run-start).")
	assert_equal(resolved[1], &"pyromancer_kindling_focus", "The CONSUMED passive resolves second (appended by ConsumePassiveCommand).")


func _explain_surfaces_both_lines_in_stable_order() -> void:
	# explain(before_attack) surfaces BOTH explanation lines in the same stable order (starting then consumed).
	var run: RunState = _run_with_passive_offer([_passive_entry(&"pyromancer_kindling_focus")])
	_seat_starting_resolver(run, &"warrior_unbreakable_guard")
	assert_true(ConsumePassiveCommand.new(&"pyromancer_kindling_focus", &"passive_reward_choice").execute(run).succeeded, "Setup: the consume should succeed.")

	var repo: PassiveRepository = PassiveRepository.create_baseline_repository()
	var starting_explanation: String = repo.get_passive(&"warrior_unbreakable_guard").explanation
	var consumed_explanation: String = repo.get_passive(&"pyromancer_kindling_focus").explanation

	var explanations: Array[String] = run.rules_resolver.explain(RuleTrigger.BEFORE_ATTACK)
	assert_equal(explanations.size(), 2, "explain(before_attack) should surface BOTH explanation lines.")
	assert_equal(explanations[0], starting_explanation, "The STARTING passive's explanation surfaces first.")
	assert_equal(explanations[1], consumed_explanation, "The CONSUMED passive's explanation surfaces second (same stable order).")


# ---- AC3: trigger timing -------------------------------------------------------------------------

func _a_passive_resolves_only_in_its_declared_window() -> void:
	# A consumed before_attack-only passive resolves in before_attack but NOT in an unrelated window.
	var run: RunState = _run_with_passive_offer([_passive_entry(&"warrior_unbreakable_guard")])
	assert_true(ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute(run).succeeded, "Setup: the consume should succeed.")

	assert_true(run.rules_resolver.resolve(RuleTrigger.BEFORE_ATTACK).size() == 1, "The consumed passive resolves in its declared before_attack window.")
	assert_true(run.rules_resolver.resolve(RuleTrigger.LEVEL_COMPLETED).is_empty(), "A before_attack-only passive must NOT resolve in level_completed (trigger timing).")
	assert_true(run.rules_resolver.resolve(RuleTrigger.RUN_STARTED).is_empty(), "A before_attack-only passive must NOT resolve in run_started (trigger timing).")


# ---- AC3: stacking -------------------------------------------------------------------------------

func _two_consumed_passives_stack_in_consume_order() -> void:
	# Two passives declaring the SAME window (before_attack) consumed in sequence (two pending offers) both appear
	# in resolve(before_attack) in CONSUME order — the v0 "stacking" meaning: all present, no silent drop.
	var run: RunState = _run_with_passive_offer([_passive_entry(&"warrior_unbreakable_guard")])
	assert_true(ConsumePassiveCommand.new(&"warrior_unbreakable_guard", &"passive_reward_choice").execute(run).succeeded, "Setup: the first consume should succeed.")

	# A SECOND pending passive offer, consumed next.
	run.pending_reward_offer = RewardOffer.new(&"passive_reward_choice", RewardOffer.STATUS_PENDING, [_passive_entry(&"pyromancer_kindling_focus")], {}, "rewards", 1, 0, 42)
	assert_true(ConsumePassiveCommand.new(&"pyromancer_kindling_focus", &"passive_reward_choice").execute(run).succeeded, "Setup: the second consume should succeed.")

	var resolved: Array[StringName] = _resolved_ids(run.rules_resolver, RuleTrigger.BEFORE_ATTACK)
	assert_equal(resolved.size(), 2, "Both consumed before_attack passives should stack (both present).")
	assert_equal(resolved[0], &"warrior_unbreakable_guard", "The first-consumed passive resolves first (consume order).")
	assert_equal(resolved[1], &"pyromancer_kindling_focus", "The second-consumed passive resolves second (consume order).")


# ---- AC3: determinism ----------------------------------------------------------------------------

func _resolution_is_deterministic_for_the_same_consume_sequence() -> void:
	# Two runs that seat the same starting passive then consume the same passive resolve byte-identically.
	var first_run: RunState = _run_with_passive_offer([_passive_entry(&"pyromancer_kindling_focus")])
	_seat_starting_resolver(first_run, &"warrior_unbreakable_guard")
	assert_true(ConsumePassiveCommand.new(&"pyromancer_kindling_focus", &"passive_reward_choice").execute(first_run).succeeded, "Setup: the first run consume should succeed.")

	var second_run: RunState = _run_with_passive_offer([_passive_entry(&"pyromancer_kindling_focus")])
	_seat_starting_resolver(second_run, &"warrior_unbreakable_guard")
	assert_true(ConsumePassiveCommand.new(&"pyromancer_kindling_focus", &"passive_reward_choice").execute(second_run).succeeded, "Setup: the second run consume should succeed.")

	for window_id: StringName in [RuleTrigger.BEFORE_ATTACK, RuleTrigger.RUN_STARTED, RuleTrigger.LEVEL_COMPLETED]:
		assert_equal(
			_resolved_ids(first_run.rules_resolver, window_id),
			_resolved_ids(second_run.rules_resolver, window_id),
			"Resolved ids for %s must be byte-identical across identical consume sequences." % String(window_id)
		)
		assert_equal(
			first_run.rules_resolver.explain(window_id),
			second_run.rules_resolver.explain(window_id),
			"Explanations for %s must be byte-identical across identical consume sequences." % String(window_id)
		)


# ---- AC3: the content gate -----------------------------------------------------------------------

func _an_unresolved_passive_id_fails_unknown_passive_and_registers_nothing() -> void:
	# AC3 "new passive content cannot bypass those fixtures": the consume path is the seam, and the validated-only
	# PassiveRepository load is the content gate. An offered passive id that does NOT resolve through the injected
	# repository fails unknown_passive and registers NOTHING — so an invalid/absent passive can never be consumed.
	var run: RunState = _run_with_passive_offer([_passive_entry(&"ghost_passive")])
	# The baseline repository does not hold `ghost_passive`.
	var repo: PassiveRepository = PassiveRepository.create_baseline_repository()
	var rejected: ActionResult = ConsumePassiveCommand.new(&"ghost_passive", &"passive_reward_choice", 1, repo).execute(run)
	assert_true(rejected.is_error(), "An unresolved passive id must be rejected.")
	assert_equal(rejected.error_code, &"unknown_passive", "An unresolved passive must use the stable unknown_passive code.")
	assert_true(run.rules_resolver == null, "An unresolved passive must register NOTHING (resolver stays null).")
	assert_true(run.pending_reward_offer.is_pending(), "An unresolved passive must leave the offer pending.")
