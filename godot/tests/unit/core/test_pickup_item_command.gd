extends "res://tests/unit/test_case.gd"

# Story 6.2 Task 6.2 — PickupItemCommand (the backpack pickup command). Covers AC2 (a pickup with capacity
# records ONE slot + emits ONE item_gained event + returns ok) and AC3 (the fail-closed / no-mutation /
# no-silent-delete rejections): sequence_id <= 0 rejects FIRST; a non-RunState/invalid run rejects
# invalid_context; a bad item id / off-allowlist category rejects; a FULL backpack rejects inventory_full with
# ZERO mutation + NO event + NO silent delete; and the command draws ZERO RNG on both success and reject.
#
# Mirrors test_route_advance_command.gd (the run-command valid/invalid/no-mutation/no-RNG shape).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const PickupItemCommand = preload("res://scripts/core/commands/pickup_item_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_successful_pickup_records_a_slot_and_emits_one_item_gained_event()
	_two_pickups_of_the_same_id_are_two_slots_no_stacking()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_invalid_context()
	_rejects_a_bad_item_id_with_no_mutation()
	_rejects_an_off_allowlist_category_with_no_mutation()
	_full_backpack_rejects_inventory_full_with_no_mutation_and_no_silent_delete()
	_pickup_draws_no_rng_on_success_and_reject()
	_pickup_is_deterministic()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# A minimal valid run parked at a route choice (PHASE_NEW_RUN validates with a structurally-sound route).
func _valid_run() -> RunState:
	var start: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["node-1-0"])
	var boss: RouteNode = RouteNode.new("node-1-0", RouteNode.TYPE_BOSS, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([start, boss], "", [])
	var run: RunState = RunState.new_run(7, false, route)
	assert_true(run.validate().succeeded, "Setup: the valid run should validate.")
	assert_true(run.inventory != null, "Setup: a fresh run has a non-null (empty) inventory.")
	assert_equal(run.inventory.size(), 0, "Setup: a fresh run's backpack is empty.")
	return run


# ---- AC2: successful pickup ----------------------------------------------------------------------

func _successful_pickup_records_a_slot_and_emits_one_item_gained_event() -> void:
	var run: RunState = _valid_run()
	var command: PickupItemCommand = PickupItemCommand.new(&"minor_healing_draught", &"consumable")
	var picked: ActionResult = command.execute(run)
	assert_true(picked.succeeded, "A pickup with capacity should succeed: %s" % picked.metadata)

	# The backpack recorded exactly one slot.
	assert_equal(run.inventory.size(), 1, "A successful pickup increases the slot count by exactly one.")
	var slot: Dictionary = run.inventory.backpack[0]
	assert_equal(slot.get("item_id"), "minor_healing_draught", "The recorded slot carries the item id.")
	assert_equal(slot.get("category"), "consumable", "The recorded slot carries the category.")
	assert_equal(slot.get("quantity"), 1, "The recorded slot defaults quantity to 1.")

	# Exactly one item_gained event with the right payload.
	assert_equal(picked.events.size(), 1, "A successful pickup should emit exactly one event.")
	var event: DomainEvent = picked.events[0]
	assert_equal(event.event_type, DomainEvent.Type.ITEM_GAINED, "The emitted event should be item_gained.")
	assert_equal(String(event.actor_id), "", "item_gained is a system event with no actor.")
	assert_equal(event.payload.get("item_id"), "minor_healing_draught", "Event should carry the item id.")
	assert_equal(event.payload.get("category"), "consumable", "Event should carry the category.")
	assert_equal(event.payload.get("backpack_size_after"), 1, "Event should carry the post-pickup backpack size.")
	assert_equal(event.payload.get("slot_index"), 0, "Event should carry the appended slot index.")
	# The emitted event is a valid DomainEvent (full payload-validation round-trip through real JSON).
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "The emitted item_gained event should pass payload validation: %s" % parsed.metadata)

	# Metadata advertises the record.
	assert_true(bool(picked.metadata.get("records_item")), "Metadata should flag records_item.")
	assert_equal(picked.metadata.get("slot_index"), 0, "Metadata should carry the slot index.")
	assert_equal(picked.metadata.get("backpack_size_after"), 1, "Metadata should carry the post-pickup backpack size.")

	# The run stays structurally valid after the pickup.
	assert_true(run.validate().succeeded, "A committed pickup should leave the run structurally valid.")


func _two_pickups_of_the_same_id_are_two_slots_no_stacking() -> void:
	# AC1 through the command path: a second pickup of the SAME id is a SECOND slot, not a quantity++.
	var run: RunState = _valid_run()
	PickupItemCommand.new(&"health_morsel", &"pickup").execute(run)
	var second: ActionResult = PickupItemCommand.new(&"health_morsel", &"pickup").execute(run)
	assert_true(second.succeeded, "A second pickup of the same id should succeed.")
	assert_equal(run.inventory.size(), 2, "Two pickups of the same id are TWO slots (no stacking).")
	assert_equal(second.events[0].payload.get("slot_index"), 1, "The second pickup records slot index 1.")
	assert_equal(run.inventory.backpack[0].get("quantity"), 1, "The first same-id slot stays quantity 1.")
	assert_equal(run.inventory.backpack[1].get("quantity"), 1, "The second same-id slot stays quantity 1.")


# ---- AC3: no-mutation rejections -----------------------------------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	# The sequence-id gate fires FIRST (before context/item/capacity), so a non-positive id rejects even with a
	# perfectly legal item + run. The rejection leaves the run byte-identical with zero events.
	for bad_sequence_id: int in [0, -1]:
		var run: RunState = _valid_run()
		var before: Dictionary = run.to_dictionary()
		var command: PickupItemCommand = PickupItemCommand.new(&"minor_healing_draught", &"consumable", bad_sequence_id)
		var rejected: ActionResult = command.execute(run)
		var after: Dictionary = run.to_dictionary()

		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_equal(rejected.metadata.get("sequence_id"), bad_sequence_id, "The rejection should echo the offending sequence id.")
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)

	# validate() alone (pure read) also rejects a non-positive id, and it fires before the item-id check (a bad
	# item id with a bad sequence id still surfaces the sequence-id code).
	var validate_only: ActionResult = PickupItemCommand.new(&"", &"consumable", 0).validate(_valid_run())
	assert_true(validate_only.is_error(), "validate() should reject a non-positive sequence id directly.")
	assert_equal(validate_only.error_code, &"invalid_event_sequence_id", "validate() should surface the stable sequence-id code FIRST (before the item-id check).")


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context (no crash, no mutation possible).
	var not_a_run: ActionResult = PickupItemCommand.new(&"minor_healing_draught", &"consumable").execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is also rejected as invalid_context, AND the inner
	# RouteState/RunState validate() error is surfaced for diagnosis.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	var before: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = PickupItemCommand.new(&"minor_healing_draught", &"consumable").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner validate() error code for diagnosis.")
	assert_false(invalid_run.has_events(), "An invalid-context rejection should emit zero events.")
	assert_equal(after, before, "An invalid-context rejection must leave the run byte-identical.")


func _rejects_a_bad_item_id_with_no_mutation() -> void:
	# An empty / hyphenated (non-lower_snake) item id is rejected (Story-6.1 content ids are lower_snake).
	for bad_id: StringName in [&"", &"Not-Snake", &"node-1-0"]:
		var run: RunState = _valid_run()
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = PickupItemCommand.new(bad_id, &"consumable").execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "A bad item id (%s) must be rejected." % String(bad_id))
		assert_equal(rejected.error_code, &"invalid_item_id", "A bad item id should use the stable invalid_item_id code (%s)." % String(bad_id))
		assert_false(rejected.has_events(), "A bad-item-id rejection should emit zero events (%s)." % String(bad_id))
		assert_equal(after, before, "A bad-item-id rejection must leave the run byte-identical (%s)." % String(bad_id))


func _rejects_an_off_allowlist_category_with_no_mutation() -> void:
	# An off-allowlist or non-lower_snake category is rejected (reject, don't coerce).
	for bad_category: StringName in [&"", &"gold_reward", &"Weapon", &"reward_table"]:
		var run: RunState = _valid_run()
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = PickupItemCommand.new(&"minor_healing_draught", bad_category).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "An off-allowlist category (%s) must be rejected." % String(bad_category))
		assert_equal(rejected.error_code, &"invalid_item_category", "An off-allowlist category should use the stable invalid_item_category code (%s)." % String(bad_category))
		assert_false(rejected.has_events(), "A bad-category rejection should emit zero events (%s)." % String(bad_category))
		assert_equal(after, before, "A bad-category rejection must leave the run byte-identical (%s)." % String(bad_category))


func _full_backpack_rejects_inventory_full_with_no_mutation_and_no_silent_delete() -> void:
	# AC3 (the load-bearing correctness property): a FULL backpack rejects with inventory_full, emits NO event,
	# mutates the backpack NOT AT ALL (byte-identical), and overwrites/drops NO existing slot.
	var run: RunState = _valid_run()
	# Fill the default-6 backpack with six distinct items.
	var fill_ids: Array[StringName] = [
		&"minor_healing_draught", &"warding_salve", &"ember_flask",
		&"health_morsel", &"focus_ember", &"padded_vest"
	]
	var fill_categories: Array[StringName] = [
		&"consumable", &"consumable", &"consumable", &"pickup", &"pickup", &"armor"
	]
	for i: int in range(fill_ids.size()):
		var ok: ActionResult = PickupItemCommand.new(fill_ids[i], fill_categories[i]).execute(run)
		assert_true(ok.succeeded, "Filling slot %d should succeed." % i)
	assert_equal(run.inventory.size(), 6, "The backpack should be full (6/6).")
	assert_true(run.inventory.is_full(), "The backpack should report full.")

	# Snapshot the FULL run and attempt a 7th pickup of a DIFFERENT item.
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = PickupItemCommand.new(&"chain_hauberk", &"armor").execute(run)
	var after: Dictionary = run.to_dictionary()

	assert_true(rejected.is_error(), "A pickup into a full backpack must be rejected.")
	assert_equal(rejected.error_code, &"inventory_full", "A full backpack should use the stable inventory_full code.")
	assert_equal(rejected.metadata.get("capacity"), 6, "The inventory_full rejection should carry the capacity.")
	assert_equal(rejected.metadata.get("item_id"), "chain_hauberk", "The inventory_full rejection should echo the rejected item id.")
	assert_false(rejected.has_events(), "A full-backpack rejection must emit ZERO events (no item_gained).")
	# No silent delete: the backpack is byte-identical and every original slot is intact.
	assert_equal(after, before, "A full-backpack rejection must leave the run byte-identical (no silent delete).")
	assert_equal(run.inventory.size(), 6, "A full-backpack rejection must not change the slot count.")
	for i: int in range(fill_ids.size()):
		assert_equal(run.inventory.backpack[i].get("item_id"), String(fill_ids[i]), "Original slot %d must be intact (no overwrite)." % i)


# ---- AC2: determinism / no RNG -------------------------------------------------------------------

func _pickup_draws_no_rng_on_success_and_reject() -> void:
	# A pickup draws ZERO RNG. Hold a stream set, snapshot it, run a SUCCESSFUL pickup and a REJECTED pickup,
	# and assert the streams are byte-identical in both cases. (The command holds no RngStreamSet at all — this
	# guards that no hidden global RNG is touched.)
	var streams: RngStreamSet = RngStreamSet.new(24680)
	var before: Dictionary = streams.to_snapshot()

	var run: RunState = _valid_run()
	PickupItemCommand.new(&"minor_healing_draught", &"consumable").execute(run)
	assert_equal(streams.to_snapshot(), before, "A successful pickup must draw no RNG (stream set unchanged).")

	var reject_run: RunState = _valid_run()
	PickupItemCommand.new(&"", &"consumable").execute(reject_run)
	assert_equal(streams.to_snapshot(), before, "A rejected pickup must draw no RNG (stream set unchanged).")


func _pickup_is_deterministic() -> void:
	# Same starting run + same item -> byte-identical resulting run.to_dictionary().
	var run_a: RunState = _valid_run()
	var run_b: RunState = _valid_run()
	PickupItemCommand.new(&"ember_flask", &"consumable").execute(run_a)
	PickupItemCommand.new(&"ember_flask", &"consumable").execute(run_b)
	assert_equal(run_a.to_dictionary(), run_b.to_dictionary(), "The pickup must be a deterministic state transition.")
