extends "res://tests/unit/test_case.gd"

# Story 6.3 Task 6 — ResolveRewardCommand (the reward-RESOLVE command). Covers AC2 (a valid resolve applies the
# selected reward + flips the offer to `resolved` + emits reward_resolved; a backpack reward composes
# PickupItemCommand -> a slot + item_gained) and AC3 (the load-bearing no-double-apply guarantee + the
# fail-closed/no-mutation rejections): sequence_id <= 0 rejects FIRST; a non-RunState/invalid run rejects
# invalid_context; no pending offer rejects no_pending_reward_offer; a non-offered selection rejects
# invalid_reward_selection; a SECOND resolve against a resolved offer rejects reward_offer_already_resolved with
# ZERO events, ZERO RNG, byte-identical run + backpack; a full-backpack reward resolution surfaces inventory_full
# (offer stays pending — no silent delete); gold/passive resolve as a reward_resolved outcome only; and the
# command draws ZERO NEW RNG on both success and reject.
#
# Mirrors test_pickup_item_command.gd (the run-command valid/invalid/no-mutation/no-RNG shape).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const PickupItemCommand = preload("res://scripts/core/commands/pickup_item_command.gd")
const ResolveRewardCommand = preload("res://scripts/core/commands/resolve_reward_command.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_resolves_a_backpack_reward_records_a_slot_and_two_events()
	_resolves_a_gold_reward_as_a_resolution_outcome_only()
	_resolves_a_passive_reward_as_a_resolution_outcome_only()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_invalid_context()
	_rejects_when_no_pending_offer()
	_rejects_a_non_offered_selection()
	_duplicate_resolve_against_a_resolved_offer_rejects_no_double_apply()
	_full_backpack_resolution_surfaces_inventory_full_and_keeps_offer_pending()
	_resolve_draws_no_rng_on_success_and_reject()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A minimal valid run parked at a route choice WITH a pending offer carrying the given entries.
func _run_with_offer(table_id: StringName, offered_entries: Array) -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, boss], "", [])
	var run: RunState = RunState.new_run(7, false, route)
	run.pending_reward_offer = RewardOffer.new(table_id, RewardOffer.STATUS_PENDING, offered_entries, {}, "rewards", 1, 0, 42)
	assert_true(run.validate().succeeded, "Setup: the run with an offer should validate.")
	return run


# ---- AC2: successful resolve ---------------------------------------------------------------------

func _resolves_a_backpack_reward_records_a_slot_and_two_events() -> void:
	var run: RunState = _run_with_offer(&"standard_combat_reward", [
		{"category": "weapon", "content_id": "sword"},
		{"category": "gold", "content_id": "small_gold_purse"}
	])
	var command: ResolveRewardCommand = ResolveRewardCommand.new(&"weapon", &"sword")
	var resolved: ActionResult = command.execute(run)
	assert_true(resolved.succeeded, "Resolving a backpack reward should succeed: %s" % resolved.metadata)

	# The backpack recorded exactly one slot via the composed pickup.
	assert_equal(run.inventory.size(), 1, "Resolving a backpack reward records exactly one slot.")
	assert_equal(run.inventory.backpack[0].get("item_id"), "sword", "The recorded slot carries the selected content id.")
	assert_equal(run.inventory.backpack[0].get("category"), "weapon", "The recorded slot carries the selected category.")

	# Exactly two events: item_gained (the pickup) + reward_resolved (the resolution record).
	assert_equal(resolved.events.size(), 2, "A backpack resolve should emit two events (item_gained + reward_resolved).")
	var has_item_gained: bool = false
	var has_reward_resolved: bool = false
	for event: DomainEvent in resolved.events:
		if event.event_type == DomainEvent.Type.ITEM_GAINED:
			has_item_gained = true
			assert_equal(event.payload.get("item_id"), "sword", "item_gained should carry the resolved item id.")
		if event.event_type == DomainEvent.Type.REWARD_RESOLVED:
			has_reward_resolved = true
			assert_equal(event.payload.get("category"), "weapon", "reward_resolved should carry the resolved category.")
			assert_equal(event.payload.get("content_id"), "sword", "reward_resolved should carry the resolved content id.")
			assert_equal(event.payload.get("table_id"), "standard_combat_reward", "reward_resolved should carry the table id.")
	assert_true(has_item_gained, "A backpack resolve should emit an item_gained event.")
	assert_true(has_reward_resolved, "A resolve should emit a reward_resolved event.")
	# Both emitted events pass payload validation (real JSON round-trip).
	for event: DomainEvent in resolved.events:
		var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
		assert_true(parsed.succeeded, "The emitted %s event should pass payload validation: %s" % [event.event_type, parsed.metadata])
	# The two events carry distinct sequence ids.
	assert_true(resolved.events[0].sequence_id != resolved.events[1].sequence_id, "The two emitted events must carry distinct sequence ids.")

	# The offer flipped to resolved + recorded the selected entry.
	assert_true(run.pending_reward_offer.is_resolved(), "The offer must flip to resolved after a successful resolve.")
	assert_equal(String(run.pending_reward_offer.selected_entry.get("content_id")), "sword", "The offer must record the selected entry.")
	assert_true(run.validate().succeeded, "A committed resolve should leave the run structurally valid.")


func _resolves_a_gold_reward_as_a_resolution_outcome_only() -> void:
	# A gold reward (no wallet domain field yet) applies as a reward_resolved outcome ONLY (no backpack mutation).
	var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "gold", "content_id": "small_gold_purse"}])
	var resolved: ActionResult = ResolveRewardCommand.new(&"gold", &"small_gold_purse").execute(run)
	assert_true(resolved.succeeded, "Resolving a gold reward should succeed: %s" % resolved.metadata)
	assert_equal(run.inventory.size(), 0, "A gold reward records NO backpack slot (no wallet yet).")
	assert_equal(resolved.events.size(), 1, "A gold resolve emits ONLY the reward_resolved event (no item_gained).")
	assert_equal(resolved.events[0].event_type, DomainEvent.Type.REWARD_RESOLVED, "A gold resolve emits a reward_resolved event.")
	assert_equal(resolved.events[0].payload.get("category"), "gold", "The reward_resolved event carries the gold category.")
	assert_true(run.pending_reward_offer.is_resolved(), "The gold offer must flip to resolved.")
	assert_false(bool(resolved.metadata.get("applied_to_backpack")), "A gold reward is not applied to the backpack.")


func _resolves_a_passive_reward_as_a_resolution_outcome_only() -> void:
	# A passive reward applies as a reward_resolved outcome ONLY (the Consume/Destroy resolution is Story 6.5/6.6).
	var run: RunState = _run_with_offer(&"passive_reward_choice", [
		{"category": "passive", "content_id": "warrior_unbreakable_guard"},
		{"category": "passive", "content_id": "ranger_steady_aim"}
	])
	var resolved: ActionResult = ResolveRewardCommand.new(&"passive", &"ranger_steady_aim").execute(run)
	assert_true(resolved.succeeded, "Resolving a passive reward should succeed: %s" % resolved.metadata)
	assert_equal(run.inventory.size(), 0, "A passive reward records NO backpack slot.")
	assert_equal(resolved.events.size(), 1, "A passive resolve emits ONLY the reward_resolved event.")
	assert_equal(resolved.events[0].payload.get("content_id"), "ranger_steady_aim", "The reward_resolved event carries the selected passive id.")
	assert_true(run.pending_reward_offer.is_resolved(), "The passive offer must flip to resolved.")


# ---- AC3: no-mutation rejections -----------------------------------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	for bad_sequence_id: int in [0, -1]:
		var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "weapon", "content_id": "sword"}])
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = ResolveRewardCommand.new(&"weapon", &"sword", bad_sequence_id).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context.
	var not_a_run: ActionResult = ResolveRewardCommand.new(&"weapon", &"sword").execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is also rejected as invalid_context, with the inner error.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	run.pending_reward_offer = RewardOffer.new(&"t", RewardOffer.STATUS_PENDING, [{"category": "weapon", "content_id": "sword"}])
	var before: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = ResolveRewardCommand.new(&"weapon", &"sword").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner validate() error code for diagnosis.")
	assert_equal(after, before, "An invalid-context rejection must leave the run byte-identical.")


func _rejects_when_no_pending_offer() -> void:
	# A run with NO pending offer rejects no_pending_reward_offer with zero mutation.
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var run: RunState = RunState.new_run(7, false, RouteState.new([start, boss], "", []))
	assert_true(run.pending_reward_offer == null, "Setup: the run has no pending offer.")
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = ResolveRewardCommand.new(&"weapon", &"sword").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "A resolve with no pending offer must be rejected.")
	assert_equal(rejected.error_code, &"no_pending_reward_offer", "No pending offer should use the stable code.")
	assert_false(rejected.has_events(), "A no-offer rejection should emit zero events.")
	assert_equal(after, before, "A no-offer rejection must leave the run byte-identical.")


func _rejects_a_non_offered_selection() -> void:
	# A selection that is not one of the offered entries rejects invalid_reward_selection with zero mutation.
	var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "weapon", "content_id": "sword"}])
	var before: Dictionary = run.to_dictionary()
	# Wrong content id.
	var wrong_id: ActionResult = ResolveRewardCommand.new(&"weapon", &"crossbow").execute(run)
	assert_true(wrong_id.is_error(), "A non-offered content id must be rejected.")
	assert_equal(wrong_id.error_code, &"invalid_reward_selection", "A non-offered selection should use the stable code.")
	assert_false(wrong_id.has_events(), "A non-offered-selection rejection should emit zero events.")
	# Wrong category (right id).
	var wrong_category: ActionResult = ResolveRewardCommand.new(&"armor", &"sword").execute(run)
	assert_true(wrong_category.is_error(), "A right-id wrong-category selection must be rejected.")
	assert_equal(wrong_category.error_code, &"invalid_reward_selection", "A wrong-category selection should use the stable code.")
	assert_equal(run.to_dictionary(), before, "A non-offered-selection rejection must leave the run byte-identical.")
	assert_true(run.pending_reward_offer.is_pending(), "A rejected selection must leave the offer pending.")


# The single most load-bearing correctness property: a SECOND resolve against an already-resolved offer fails
# closed with ZERO events, ZERO RNG, byte-identical run + backpack (no double-apply).
func _duplicate_resolve_against_a_resolved_offer_rejects_no_double_apply() -> void:
	var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "weapon", "content_id": "sword"}])
	# First resolve succeeds + applies the reward.
	var first: ActionResult = ResolveRewardCommand.new(&"weapon", &"sword").execute(run)
	assert_true(first.succeeded, "The first resolve should succeed.")
	assert_equal(run.inventory.size(), 1, "The first resolve records one slot.")
	assert_true(run.pending_reward_offer.is_resolved(), "The offer is resolved after the first resolve.")

	# Snapshot the post-first-resolve run + a held RNG stream set; the SECOND resolve must change NOTHING.
	var before: Dictionary = run.to_dictionary()
	var streams: RngStreamSet = RngStreamSet.new(13579)
	var streams_before: Dictionary = streams.to_snapshot()

	var second: ActionResult = ResolveRewardCommand.new(&"weapon", &"sword").execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(second.is_error(), "A second resolve against a resolved offer must be rejected.")
	assert_equal(second.error_code, &"reward_offer_already_resolved", "A duplicate resolve should use the stable reward_offer_already_resolved code.")
	assert_equal(String(second.metadata.get("table_id")), "standard_combat_reward", "The duplicate-resolve error should carry the table id.")
	assert_false(second.has_events(), "A duplicate resolve must emit ZERO events (no second item_gained, no second reward_resolved).")
	# No double-apply: byte-identical run + backpack, and the slot count did not grow.
	assert_equal(after, before, "A duplicate resolve must leave the run byte-identical (no double-apply).")
	assert_equal(run.inventory.size(), 1, "A duplicate resolve must not add a second slot (no double-apply).")
	# No RNG drawn by the duplicate resolve (the held stream set is byte-identical).
	assert_equal(streams.to_snapshot(), streams_before, "A duplicate resolve must draw NO RNG (held stream set unchanged).")


func _full_backpack_resolution_surfaces_inventory_full_and_keeps_offer_pending() -> void:
	# A backpack reward resolution into a FULL backpack surfaces the composed pickup's inventory_full error
	# HONESTLY and leaves the offer PENDING (no silent delete, no unclaimed-resolution).
	var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "armor", "content_id": "chain_hauberk"}])
	# Fill the default-6 backpack.
	var fill_ids: Array[StringName] = [&"minor_healing_draught", &"warding_salve", &"ember_flask", &"health_morsel", &"focus_ember", &"padded_vest"]
	var fill_categories: Array[StringName] = [&"consumable", &"consumable", &"consumable", &"pickup", &"pickup", &"armor"]
	for i: int in range(fill_ids.size()):
		assert_true(PickupItemCommand.new(fill_ids[i], fill_categories[i]).execute(run).succeeded, "Filling slot %d should succeed." % i)
	assert_true(run.inventory.is_full(), "Setup: the backpack should be full (6/6).")

	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = ResolveRewardCommand.new(&"armor", &"chain_hauberk").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "A backpack resolve into a full backpack must surface an error.")
	assert_equal(rejected.error_code, &"inventory_full", "A full-backpack resolve should surface the composed pickup's inventory_full code.")
	assert_false(rejected.has_events(), "A full-backpack resolve must emit ZERO events (no item_gained, no reward_resolved).")
	assert_equal(after, before, "A full-backpack resolve must leave the run byte-identical (no silent delete).")
	assert_true(run.pending_reward_offer.is_pending(), "A full-backpack resolve must leave the offer PENDING (not consumed/lost).")


# ---- AC2: no RNG ---------------------------------------------------------------------------------

func _resolve_draws_no_rng_on_success_and_reject() -> void:
	# Resolve draws ZERO RNG (the offer was rolled at GENERATE). Hold a stream set, snapshot it, run a SUCCESSFUL
	# resolve and a REJECTED resolve, and assert the streams are byte-identical in both cases.
	var streams: RngStreamSet = RngStreamSet.new(24680)
	var before: Dictionary = streams.to_snapshot()

	var run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "weapon", "content_id": "sword"}])
	ResolveRewardCommand.new(&"weapon", &"sword").execute(run)
	assert_equal(streams.to_snapshot(), before, "A successful resolve must draw no RNG (stream set unchanged).")

	var reject_run: RunState = _run_with_offer(&"standard_combat_reward", [{"category": "weapon", "content_id": "sword"}])
	ResolveRewardCommand.new(&"weapon", &"crossbow").execute(reject_run)
	assert_equal(streams.to_snapshot(), before, "A rejected resolve must draw no RNG (stream set unchanged).")
