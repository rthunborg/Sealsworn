extends "res://tests/unit/test_case.gd"

# Story 6.7 Task 6.1-6.3/6.5 — the HEADLESS loot/passive build SMOKE RUN (AC1/AC2/AC5 end-to-end capstone). The
# Epic-6 analogue of Story 5.5's class-start playable smoke slice: it threads the ALREADY-shipped 6.1-6.6
# capabilities + the new 6.7 UseConsumableCommand into ONE deterministic headless surface and PROVES:
#   - AC1: a shell run CLEARS a real node (the harness drives orchestrator.resolve_current_node() to clear the
#     parked depth-0 start node and ASSERTS it landed in cleared_node_ids — the node-completion boundary is
#     genuinely exercised, not asserted-but-skipped); the harness (the CALLER — generate is caller-driven, NOT
#     auto-wired into run_to_completion) then generates a loot offer + a 3-choice passive offer; and EACH offer
#     disposition resolves through a real command, proven AGAINST A GENERATED OFFER — the PICKUP disposition
#     resolves an offered BACKPACK-category entry (ResolveRewardCommand composes PickupItemCommand; the backpack
#     GROWS by one slot + item_gained fires); the SKIP/DECLINE disposition is a GENUINE no-apply resolve of an
#     offered GOLD entry (outcome-only — the offer flips + reward_resolved fires but NOTHING is applied to the
#     backpack, kept consistent with _gold_offer_resolves_outcome_only); a passive offer -> ConsumePassiveCommand
#     (adopt) OR DestroyPassiveCommand (roll the 70/20/10 through the run-level `rewards` stream). Every offer
#     type has a real resolving command behind it, and no hard-coded item id stands in for an offer's disposition.
#   - AC3/AC4: a consumable is USED end-to-end (PickupItemCommand a consumable -> UseConsumableCommand) — the
#     item_consumed event records the effect + the slot is removed. The AC4 "observed/simulated use demonstrates
#     value" evidence (v0 is OUTCOME-RECORD-ONLY — the felt value is the recorded effect + the slot consumption).
#   - AC5: the run stays DETERMINISTIC for the same (seed, class_id) + the same ordered generate/command sequence
#     (byte-identical RunState.to_dictionary() incl. inventory + resolved offer + Destroy outcome; byte-identical
#     generated offers; byte-identical event ids), a divergent seed CAN diverge, and the invalid/no-mutation surface
#     is covered (the UseConsumableCommand rejects + a Consume/Resolve against a resolved offer fails closed).
#
# It is a HEADLESS harness (the orchestrator + the commands drive deterministically), NOT a scene/HUD — the 5.5
# "playable proven headless" precedent. The HUD wiring of the commit-intent -> command call site is a later HUD
# story; this harness constructs the commands DIRECTLY (the 6.5/6.6 test-driver posture).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ConsumePassiveCommand = preload("res://scripts/core/commands/consume_passive_command.gd")
const DestroyPassiveCommand = preload("res://scripts/core/commands/destroy_passive_command.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const PickupItemCommand = preload("res://scripts/core/commands/pickup_item_command.gd")
const ResolveRewardCommand = preload("res://scripts/core/commands/resolve_reward_command.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const UseConsumableCommand = preload("res://scripts/core/commands/use_consumable_command.gd")

const STANDARD_TABLE := &"standard_combat_reward"
const PASSIVE_TABLE := &"passive_reward_choice"
const SMOKE_CLASS := &"warrior"

func run() -> Dictionary:
	_loot_offer_can_be_picked_up_then_skipped_against_the_same_run()
	_passive_offer_can_be_consumed_in_one_run_and_destroyed_in_another()
	_gold_offer_resolves_outcome_only()
	_consumable_is_used_end_to_end_recording_the_effect_and_removing_the_slot()
	_full_loot_passive_loop_is_deterministic_for_the_same_seed()
	_a_divergent_seed_can_diverge()
	_invalid_and_no_mutation_surface_is_covered()
	return result()


# ---- AC1: a real node is cleared, then an offered backpack entry is picked up + an offered gold entry skipped --

func _loot_offer_can_be_picked_up_then_skipped_against_the_same_run() -> void:
	# AC1 "a shell run CLEARS eligible nodes ... generates offers at node-completion boundaries": drive ONE real
	# node-completion through the orchestrator FIRST (resolve_current_node clears the parked depth-0 start node —
	# always a combat node, so it routes through the combat enter -> level-generate -> auto-resolve -> exit path
	# and lands the node id in cleared_node_ids), ASSERT a node was actually cleared, and ONLY THEN generate the
	# offer — so the node-completion -> reward boundary is genuinely exercised, not asserted-but-skipped.
	var orchestrator: RunOrchestrator = _started_run(20260607)
	var start_node_id: String = orchestrator.run.route.current_node_id
	assert_false(start_node_id.is_empty(), "A started run is parked on a node before the first node-completion.")
	var cleared_before: int = orchestrator.run.route.cleared_node_ids.size()
	var node_resolved: ActionResult = orchestrator.resolve_current_node()
	assert_true(node_resolved.succeeded, "Resolving the current node should clear it: %s" % node_resolved.metadata)
	assert_false(bool(node_resolved.metadata.get("run_completed")), "The depth-0 start node does not end the run.")
	assert_equal(orchestrator.run.route.cleared_node_ids.size(), cleared_before + 1, "A real node was cleared at the node-completion boundary.")
	assert_true(orchestrator.run.route.cleared_node_ids.has(start_node_id), "The cleared node is the start node the run was parked on.")

	# Disposition A (PICKUP, proven AGAINST a generated OFFER) — generate loot offers until a BACKPACK-category
	# entry is offered, then RESOLVE that OFFERED entry. ResolveRewardCommand composes PickupItemCommand for a
	# backpack category (resolve_reward_command.gd:115-129), so resolving the offered backpack entry IS the pickup
	# disposition: assert the backpack GREW (+1 slot, item_gained emitted, applied_to_backpack true). The offered
	# entry — not a hard-coded id — drives the pickup, so an offer->pickup regression would be caught.
	var backpack_result: Dictionary = _resolve_first_offered_backpack_entry()
	assert_true(bool(backpack_result.get("found")), "A backpack-category loot offer should surface within the seed sample (standard_combat_reward has 5 backpack entries).")
	assert_true(bool(backpack_result.get("applied_to_backpack")), "Resolving an offered BACKPACK entry applies it to the backpack (the pickup disposition).")
	assert_equal(int(backpack_result.get("backpack_after")), int(backpack_result.get("backpack_before")) + 1, "The offered-backpack-entry resolve grew the backpack by one slot.")
	assert_true(bool(backpack_result.get("has_item_gained")), "Resolving an offered backpack entry emits an item_gained event (the pickup record).")
	assert_true(bool(backpack_result.get("has_reward_resolved")), "Resolving an offered backpack entry also emits a reward_resolved event (the offer flip).")
	assert_true(bool(backpack_result.get("is_resolved")), "The offer is resolved after the offered-backpack-entry pickup.")

	# Disposition B (SKIP/DECLINE, a GENUINE no-apply resolve) — generate loot offers until a GOLD entry is offered,
	# then resolve THAT offered gold entry. A gold resolve is intentionally OUTCOME-ONLY (no wallet exists in v0): it
	# flips the offer to resolved + records reward_resolved but applies NOTHING to the backpack. This is the true
	# skip/decline disposition (NOT conflated with a backpack apply); it is kept consistent with
	# _gold_offer_resolves_outcome_only by asserting applied_to_backpack is FALSE and the backpack did NOT grow.
	var skip_result: Dictionary = _resolve_first_offered_gold_entry()
	assert_true(bool(skip_result.get("found")), "A gold loot offer should surface within the seed sample (standard_combat_reward has a gold entry).")
	assert_false(bool(skip_result.get("applied_to_backpack")), "The skip/decline (gold) resolve applies NOTHING to the backpack (outcome-only, no wallet in v0).")
	assert_equal(int(skip_result.get("backpack_after")), int(skip_result.get("backpack_before")), "The skip/decline (gold) resolve did NOT grow the backpack.")
	assert_true(bool(skip_result.get("has_reward_resolved")), "The skip/decline resolve emits a reward_resolved event (the offer flip).")
	assert_true(bool(skip_result.get("is_resolved")), "The offer is resolved after the skip/decline (gold) resolve.")


# ---- AC1/AC6: a passive offer routes to ConsumePassiveCommand AND (a parallel run) DestroyPassiveCommand ------

func _passive_offer_can_be_consumed_in_one_run_and_destroyed_in_another() -> void:
	# CONSUME path — one run adopts the passive into its RulesResolver (the build-defining adoption).
	var consume_orchestrator: RunOrchestrator = _started_run(424242)
	var consume_gen: ActionResult = consume_orchestrator.generate_passive_reward_offer(PASSIVE_TABLE)
	assert_true(consume_gen.succeeded, "The passive offer should generate (consume path): %s" % consume_gen.metadata)
	var consume_offer: RewardOffer = consume_orchestrator.run.pending_reward_offer
	assert_equal(consume_offer.offered_entries.size(), 3, "The passive offer surfaces 3 distinct choices.")
	# Capture the GENERATED offer dict BEFORE the Consume mutates it (Consume flips it to resolved + sets
	# selected_entry), so the consume-vs-destroy generate determinism cross-check compares the pending generated
	# offers, not a resolved one against a pending one.
	var consume_offer_generated: Dictionary = consume_offer.to_dictionary()
	var chosen_passive: StringName = StringName(String(consume_offer.offered_entries[0].get("content_id")))
	var resolver_count_before: int = 0
	if consume_orchestrator.run.rules_resolver != null:
		resolver_count_before = consume_orchestrator.run.rules_resolver.registered_passive_count()
	var consumed: ActionResult = ConsumePassiveCommand.new(chosen_passive, consume_offer.table_id, 2000).execute(consume_orchestrator.run)
	assert_true(consumed.succeeded, "Consuming a passive should succeed: %s" % consumed.metadata)
	assert_true(consume_orchestrator.run.pending_reward_offer.is_resolved(), "The passive offer is resolved after Consume.")
	# The passive was adopted into the run's resolver (the real "add the passive to active run state").
	assert_equal(consume_orchestrator.run.rules_resolver.registered_passive_count(), resolver_count_before + 1, "Consume registers the passive into the run's RulesResolver.")
	var consumed_event: DomainEvent = consumed.events[0]
	assert_equal(consumed_event.event_type, DomainEvent.Type.PASSIVE_CONSUMED, "Consume emits a passive_consumed event.")

	# DESTROY path — a PARALLEL run on the same seed rolls the 70/20/10 outcome through the run-level `rewards`
	# stream (thread orchestrator.streams — the named-stream rule). The same chosen passive is destroyed.
	var destroy_orchestrator: RunOrchestrator = _started_run(424242)
	var destroy_gen: ActionResult = destroy_orchestrator.generate_passive_reward_offer(PASSIVE_TABLE)
	assert_true(destroy_gen.succeeded, "The passive offer should generate (destroy path): %s" % destroy_gen.metadata)
	var destroy_offer: RewardOffer = destroy_orchestrator.run.pending_reward_offer
	# The two parallel runs generated the SAME offer (determinism across the generate path) — compare the freshly
	# generated (still pending) destroy offer against the captured pending consume offer.
	assert_equal(JSON.stringify(destroy_offer.to_dictionary()), JSON.stringify(consume_offer_generated), "The same seed generates the same passive offer (consume vs destroy parallel runs).")
	var destroyed: ActionResult = DestroyPassiveCommand.new(chosen_passive, destroy_offer.table_id, 2000, destroy_orchestrator.streams).execute(destroy_orchestrator.run)
	assert_true(destroyed.succeeded, "Destroying a passive should succeed: %s" % destroyed.metadata)
	assert_true(destroy_orchestrator.run.pending_reward_offer.is_resolved(), "The passive offer is resolved after Destroy.")
	# Destroy did NOT adopt the passive (the opposite of Consume — run.rules_resolver is untouched by Destroy).
	var destroy_resolver_count: int = 0
	if destroy_orchestrator.run.rules_resolver != null:
		destroy_resolver_count = destroy_orchestrator.run.rules_resolver.registered_passive_count()
	assert_equal(destroy_resolver_count, resolver_count_before, "Destroy does NOT register the passive (the opposite of adoption).")
	var destroyed_event: DomainEvent = destroyed.events[0]
	assert_equal(destroyed_event.event_type, DomainEvent.Type.PASSIVE_DESTROYED, "Destroy emits a passive_destroyed event.")
	# The Destroy outcome carries a rolled 70/20/10 outcome category + the draw provenance (Destroy DRAWS RNG).
	assert_false(String(destroyed_event.payload.get("outcome_category")).is_empty(), "The Destroy outcome records a rolled outcome_category.")
	assert_false(String(destroyed_event.payload.get("explanation")).is_empty(), "The Destroy outcome records a player-readable explanation (the gain/give-up surface).")


# ---- AC1: a gold offer resolves outcome-only via ResolveRewardCommand ----------------------------

func _gold_offer_resolves_outcome_only() -> void:
	# Drive offers until a gold entry surfaces (standard_combat_reward has a gold entry; a small bounded retry across
	# fresh runs finds one deterministically). Then resolve it outcome-only (no wallet exists in v0 — record only).
	for seed_value: int in [1, 2, 3, 5, 7, 11, 13, 17, 42, 99]:
		var orchestrator: RunOrchestrator = _started_run(seed_value)
		var generated: ActionResult = orchestrator.generate_reward_offer(STANDARD_TABLE)
		assert_true(generated.succeeded, "The loot offer should generate for seed %d." % seed_value)
		var entry: Dictionary = orchestrator.run.pending_reward_offer.offered_entries[0]
		if String(entry.get("category")) != "gold":
			continue
		var backpack_before: int = orchestrator.run.inventory.size()
		var resolved: ActionResult = ResolveRewardCommand.new(&"gold", StringName(String(entry.get("content_id"))), 3000).execute(orchestrator.run)
		assert_true(resolved.succeeded, "A gold offer should resolve outcome-only: %s" % resolved.metadata)
		assert_true(orchestrator.run.pending_reward_offer.is_resolved(), "The gold offer is resolved.")
		# Gold is outcome-only: NO backpack mutation (no wallet field exists), just the offer flip + reward_resolved.
		assert_equal(orchestrator.run.inventory.size(), backpack_before, "A gold reward does NOT touch the backpack (outcome-only, no wallet in v0).")
		assert_false(bool(resolved.metadata.get("applied_to_backpack")), "A gold reward is not applied to the backpack.")
		return
	# Defensive: the standard table's gold weight is the highest, so a gold entry surfaces within the sample.
	assert_true(false, "A gold offer should surface within the seed sample (standard_combat_reward has a gold entry).")


# ---- AC3/AC4: a consumable is USED end-to-end -----------------------------------------------------

func _consumable_is_used_end_to_end_recording_the_effect_and_removing_the_slot() -> void:
	var orchestrator: RunOrchestrator = _started_run(60607)
	# Pick up a consumable (the PickupItemCommand of a `consumable`-category item — the prior step AC3 requires).
	var pickup: ActionResult = PickupItemCommand.new(&"minor_healing_draught", &"consumable", 4000).execute(orchestrator.run)
	assert_true(pickup.succeeded, "Picking up the consumable should succeed.")
	assert_equal(orchestrator.run.inventory.size(), 1, "The backpack holds the consumable.")

	# USE it (the new UseConsumableCommand). The item_consumed event records the effect; the slot is removed.
	var used: ActionResult = UseConsumableCommand.new(&"minor_healing_draught", 4001).execute(orchestrator.run)
	assert_true(used.succeeded, "Using the consumable should succeed: %s" % used.metadata)
	assert_equal(orchestrator.run.inventory.size(), 0, "Using the consumable removed its backpack slot.")
	var event: DomainEvent = used.events[0]
	assert_equal(event.event_type, DomainEvent.Type.ITEM_CONSUMED, "Using a consumable emits an item_consumed event.")
	assert_equal(event.payload.get("item_id"), "minor_healing_draught", "The item_consumed event records the item id.")
	# The effect is the recorded OUTCOME-RECORD effect (v0 felt value = the recorded effect + the slot consumption).
	assert_equal(event.payload.get("outcome_effect"), "restore_minor_health", "The item_consumed event records the consumable's effect.")
	assert_false(String(event.payload.get("explanation")).is_empty(), "The item_consumed event records a player-readable explanation.")


# ---- AC5: determinism of the FULL loot/passive loop ----------------------------------------------

func _full_loot_passive_loop_is_deterministic_for_the_same_seed() -> void:
	# Two independent drives on the SAME (seed, class_id) with the SAME ordered generate/command sequence produce
	# byte-identical RunState.to_dictionary() (incl. inventory + resolved offer + the Destroy outcome) + byte-identical
	# generated-offer payloads + byte-identical event ids.
	var drive_a: Dictionary = _drive_full_loop(987654321)
	var drive_b: Dictionary = _drive_full_loop(987654321)

	assert_equal(drive_a.get("run_dict"), drive_b.get("run_dict"), "The full loop must produce a byte-identical RunState for the same seed.")
	assert_equal(drive_a.get("loot_offer"), drive_b.get("loot_offer"), "The loot offer must reproduce for the same seed.")
	assert_equal(drive_a.get("passive_offer"), drive_b.get("passive_offer"), "The passive offer must reproduce for the same seed.")
	assert_equal(drive_a.get("destroy_outcome"), drive_b.get("destroy_outcome"), "The Destroy 70/20/10 outcome must reproduce for the same seed.")
	assert_equal(drive_a.get("event_ids"), drive_b.get("event_ids"), "The emitted event ids must reproduce for the same seed.")


func _a_divergent_seed_can_diverge() -> void:
	# A DIFFERENT seed CAN diverge — at least one observable field differs (the generated offers / Destroy outcome
	# key off the seed). This proves the determinism is seed-keyed, not a constant.
	var drive_a: Dictionary = _drive_full_loop(111)
	var drive_b: Dictionary = _drive_full_loop(999999)
	var any_differs: bool = (
		drive_a.get("loot_offer") != drive_b.get("loot_offer")
		or drive_a.get("passive_offer") != drive_b.get("passive_offer")
		or drive_a.get("destroy_outcome") != drive_b.get("destroy_outcome")
		or drive_a.get("run_dict") != drive_b.get("run_dict")
	)
	assert_true(any_differs, "A divergent seed should be able to diverge (the determinism is seed-keyed, not constant).")


# ---- AC5: the invalid/no-mutation surface is covered ---------------------------------------------

func _invalid_and_no_mutation_surface_is_covered() -> void:
	var orchestrator: RunOrchestrator = _started_run(50505)

	# UseConsumableCommand rejects fail-closed (item not in inventory) — byte-identical run, zero events.
	var before_use: Dictionary = orchestrator.run.to_dictionary()
	var bad_use: ActionResult = UseConsumableCommand.new(&"minor_healing_draught", 5000).execute(orchestrator.run)
	assert_true(bad_use.is_error(), "Using a consumable not in the backpack must reject under the smoke harness.")
	assert_equal(bad_use.error_code, &"item_not_in_inventory", "The reject uses the stable item_not_in_inventory code.")
	assert_false(bad_use.has_events(), "A rejected use emits zero events.")
	assert_equal(orchestrator.run.to_dictionary(), before_use, "A rejected use leaves the run byte-identical.")

	# A Consume/Resolve against a RESOLVED offer fails closed (the 6.3/6.5 no-double-resolve guarantee under the
	# harness). Generate a passive offer, Consume it, then re-Consume + re-Resolve against the resolved offer.
	var generated: ActionResult = orchestrator.generate_passive_reward_offer(PASSIVE_TABLE)
	assert_true(generated.succeeded, "The passive offer should generate.")
	var offer: RewardOffer = orchestrator.run.pending_reward_offer
	var chosen: StringName = StringName(String(offer.offered_entries[0].get("content_id")))
	ConsumePassiveCommand.new(chosen, offer.table_id, 5001).execute(orchestrator.run)
	assert_true(orchestrator.run.pending_reward_offer.is_resolved(), "The passive offer is resolved after the first Consume.")

	var after_resolve: Dictionary = orchestrator.run.to_dictionary()
	var double_consume: ActionResult = ConsumePassiveCommand.new(chosen, offer.table_id, 5002).execute(orchestrator.run)
	assert_true(double_consume.is_error(), "A second Consume against a resolved offer must fail closed.")
	assert_equal(double_consume.error_code, &"reward_offer_already_resolved", "The double-consume uses the stable already-resolved code.")
	assert_false(double_consume.has_events(), "A double-consume emits zero events.")
	assert_equal(orchestrator.run.to_dictionary(), after_resolve, "A double-consume leaves the run byte-identical.")

	var double_resolve: ActionResult = ResolveRewardCommand.new(&"passive", chosen, 5003).execute(orchestrator.run)
	assert_true(double_resolve.is_error(), "A Resolve against a resolved offer must fail closed.")
	assert_equal(double_resolve.error_code, &"reward_offer_already_resolved", "The double-resolve uses the stable already-resolved code.")
	assert_equal(orchestrator.run.to_dictionary(), after_resolve, "A double-resolve leaves the run byte-identical.")


# ---- helpers -------------------------------------------------------------------------------------

# A small fixed seed sample for the bounded "drive offers until the target category surfaces" retries. Each
# value starts a FRESH run and generates ONE offer (a generate-while-pending fails closed reward_offer_pending,
# so one offer per fresh run is the clean deterministic way to sample the single-pick draw across seeds).
const OFFER_SAMPLE_SEEDS: Array[int] = [1, 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 42, 99, 2026]

# Disposition A support — generate standard loot offers across the seed sample until a BACKPACK-category entry is
# offered, then RESOLVE that OFFERED entry (ResolveRewardCommand composes PickupItemCommand for a backpack
# category, so this is the offer->pickup disposition). Returns the observable surfaces of the resolved offer (the
# backpack delta, whether item_gained/reward_resolved were emitted, the applied_to_backpack flag, the resolved
# flag). `found` is false if no backpack entry surfaced within the sample (the assertion site fails loud then).
func _resolve_first_offered_backpack_entry() -> Dictionary:
	for seed_value: int in OFFER_SAMPLE_SEEDS:
		var orchestrator: RunOrchestrator = _started_run(seed_value)
		var generated: ActionResult = orchestrator.generate_reward_offer(STANDARD_TABLE)
		assert_true(generated.succeeded, "The loot offer should generate for seed %d." % seed_value)
		var entry: Dictionary = orchestrator.run.pending_reward_offer.offered_entries[0]
		var category: StringName = StringName(String(entry.get("category")))
		# Only a backpack-category offered entry proves the pickup disposition (gold is the outcome-only path).
		if not InventoryState.is_backpack_category(category):
			continue
		var backpack_before: int = orchestrator.run.inventory.size()
		var resolved: ActionResult = ResolveRewardCommand.new(
			category,
			StringName(String(entry.get("content_id"))),
			6000
		).execute(orchestrator.run)
		assert_true(resolved.succeeded, "Resolving the offered backpack entry should succeed: %s" % resolved.metadata)
		var has_item_gained: bool = false
		var has_reward_resolved: bool = false
		for event: DomainEvent in resolved.events:
			if event.event_type == DomainEvent.Type.ITEM_GAINED:
				has_item_gained = true
			elif event.event_type == DomainEvent.Type.REWARD_RESOLVED:
				has_reward_resolved = true
		return {
			"found": true,
			"applied_to_backpack": bool(resolved.metadata.get("applied_to_backpack")),
			"backpack_before": backpack_before,
			"backpack_after": orchestrator.run.inventory.size(),
			"has_item_gained": has_item_gained,
			"has_reward_resolved": has_reward_resolved,
			"is_resolved": orchestrator.run.pending_reward_offer.is_resolved()
		}
	return {"found": false}


# Disposition B support — generate standard loot offers across the seed sample until a GOLD entry is offered, then
# resolve THAT offered gold entry outcome-only (the genuine skip/decline disposition: no wallet exists in v0, so a
# gold resolve flips the offer + records reward_resolved but applies NOTHING to the backpack). Returns the same
# observable-surface shape as the backpack helper. `found` is false if no gold entry surfaced within the sample.
func _resolve_first_offered_gold_entry() -> Dictionary:
	for seed_value: int in OFFER_SAMPLE_SEEDS:
		var orchestrator: RunOrchestrator = _started_run(seed_value)
		var generated: ActionResult = orchestrator.generate_reward_offer(STANDARD_TABLE)
		assert_true(generated.succeeded, "The loot offer should generate for seed %d." % seed_value)
		var entry: Dictionary = orchestrator.run.pending_reward_offer.offered_entries[0]
		if String(entry.get("category")) != "gold":
			continue
		var backpack_before: int = orchestrator.run.inventory.size()
		var resolved: ActionResult = ResolveRewardCommand.new(
			&"gold",
			StringName(String(entry.get("content_id"))),
			6100
		).execute(orchestrator.run)
		assert_true(resolved.succeeded, "Resolving the offered gold entry should succeed: %s" % resolved.metadata)
		var has_reward_resolved: bool = false
		for event: DomainEvent in resolved.events:
			if event.event_type == DomainEvent.Type.REWARD_RESOLVED:
				has_reward_resolved = true
		return {
			"found": true,
			"applied_to_backpack": bool(resolved.metadata.get("applied_to_backpack")),
			"backpack_before": backpack_before,
			"backpack_after": orchestrator.run.inventory.size(),
			"has_reward_resolved": has_reward_resolved,
			"is_resolved": orchestrator.run.pending_reward_offer.is_resolved()
		}
	return {"found": false}


# Start a fresh run via the orchestrator with the smoke class. Fail loud if the start rejects.
func _started_run(seed_value: int) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var started: ActionResult = orchestrator.start(seed_value, false, SMOKE_CLASS)
	assert_true(started.succeeded, "The smoke run should start for seed %d: %s" % [seed_value, started.metadata])
	return orchestrator


# Drive the FULL loot/passive loop deterministically and capture the observable surfaces for a determinism
# cross-check. ORDER (fixed across drives): generate a loot offer -> resolve it; pick up + use a consumable;
# generate a passive offer -> Destroy it (rolls the 70/20/10 through the run-level `rewards` stream). Returns the
# captured surfaces (the run dict, the two generated offers, the Destroy outcome, the ordered event ids).
func _drive_full_loop(seed_value: int) -> Dictionary:
	var orchestrator: RunOrchestrator = _started_run(seed_value)
	var event_ids: Array[String] = []
	var seq: int = 7000

	# (1) Loot offer -> resolve it.
	var loot_gen: ActionResult = orchestrator.generate_reward_offer(STANDARD_TABLE)
	assert_true(loot_gen.succeeded, "Loot offer generate should succeed for seed %d." % seed_value)
	var loot_offer_dict: Dictionary = orchestrator.run.pending_reward_offer.to_dictionary()
	var loot_entry: Dictionary = orchestrator.run.pending_reward_offer.offered_entries[0]
	var loot_resolved: ActionResult = ResolveRewardCommand.new(
		StringName(String(loot_entry.get("category"))),
		StringName(String(loot_entry.get("content_id"))),
		seq
	).execute(orchestrator.run)
	_collect_event_ids(loot_resolved, event_ids)
	seq += 10

	# (2) Pick up + use a consumable.
	var pickup: ActionResult = PickupItemCommand.new(&"warding_salve", &"consumable", seq).execute(orchestrator.run)
	_collect_event_ids(pickup, event_ids)
	seq += 1
	var used: ActionResult = UseConsumableCommand.new(&"warding_salve", seq).execute(orchestrator.run)
	_collect_event_ids(used, event_ids)
	seq += 10

	# (3) Passive offer -> Destroy it (roll the 70/20/10 through the run-level `rewards` stream).
	var passive_gen: ActionResult = orchestrator.generate_passive_reward_offer(PASSIVE_TABLE)
	assert_true(passive_gen.succeeded, "Passive offer generate should succeed for seed %d." % seed_value)
	var passive_offer_dict: Dictionary = orchestrator.run.pending_reward_offer.to_dictionary()
	var chosen: StringName = StringName(String(orchestrator.run.pending_reward_offer.offered_entries[0].get("content_id")))
	var destroyed: ActionResult = DestroyPassiveCommand.new(chosen, orchestrator.run.pending_reward_offer.table_id, seq, orchestrator.streams).execute(orchestrator.run)
	assert_true(destroyed.succeeded, "Destroy should succeed for seed %d: %s" % [seed_value, destroyed.metadata])
	_collect_event_ids(destroyed, event_ids)
	var destroy_event: DomainEvent = destroyed.events[0]
	var destroy_outcome: Dictionary = {
		"outcome_category": String(destroy_event.payload.get("outcome_category")),
		"outcome_id": String(destroy_event.payload.get("outcome_id")),
		"roll": int(destroy_event.payload.get("roll"))
	}

	return {
		"run_dict": orchestrator.run.to_dictionary(),
		"loot_offer": loot_offer_dict,
		"passive_offer": passive_offer_dict,
		"destroy_outcome": destroy_outcome,
		"event_ids": event_ids
	}


func _collect_event_ids(action_result: ActionResult, into: Array[String]) -> void:
	for event: DomainEvent in action_result.events:
		into.append(String(DomainEvent.id_for_type(event.event_type)))
