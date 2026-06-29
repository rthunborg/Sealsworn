extends "res://tests/unit/test_case.gd"

# Story 6.7 Task 5.4 — UseConsumableCommand (use a backpack consumable -> record effect + remove slot). Covers AC3
# (a valid use removes the consumable slot + emits ONE item_consumed event recording the effect) and AC5 (the
# fail-closed / no-mutation rejections): sequence_id <= 0 rejects FIRST; a non-RunState/invalid run rejects
# invalid_context; a bad item id rejects invalid_item_id; an item not in the backpack rejects item_not_in_inventory;
# a non-consumable backpack slot rejects not_a_consumable; an unresolvable consumable rejects unknown_consumable; and
# the command draws ZERO RNG on both success and reject. Mirrors test_pickup_item_command.gd /
# test_consume_passive_command.gd (the run-command valid/invalid/no-mutation/no-RNG shape).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ConsumableDefinition = preload("res://scripts/content/definitions/consumable_definition.gd")
const ConsumableRepository = preload("res://scripts/content/repositories/consumable_repository.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const PickupItemCommand = preload("res://scripts/core/commands/pickup_item_command.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const UseConsumableCommand = preload("res://scripts/core/commands/use_consumable_command.gd")

func run() -> Dictionary:
	_successful_use_removes_the_slot_and_emits_one_item_consumed_event()
	_use_removes_only_the_used_slot_other_slots_untouched()
	_rejects_non_positive_sequence_id_first_with_no_mutation()
	_rejects_invalid_context()
	_rejects_a_bad_item_id_with_no_mutation()
	_rejects_item_not_in_inventory_with_no_mutation()
	_rejects_not_a_consumable_with_no_mutation()
	_rejects_unknown_consumable_with_no_mutation()
	_use_draws_no_rng_on_success_and_reject()
	_use_is_deterministic()
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


# A valid run with `item_id` (a baseline consumable) already picked up into the backpack.
func _run_with_consumable(item_id: StringName) -> RunState:
	var run: RunState = _valid_run()
	var picked: ActionResult = PickupItemCommand.new(item_id, &"consumable").execute(run)
	assert_true(picked.succeeded, "Setup: picking up %s should succeed." % String(item_id))
	return run


# ---- AC3: successful use -------------------------------------------------------------------------

func _successful_use_removes_the_slot_and_emits_one_item_consumed_event() -> void:
	var run: RunState = _run_with_consumable(&"minor_healing_draught")
	assert_equal(run.inventory.size(), 1, "Setup: the backpack holds the one consumable.")
	var command: UseConsumableCommand = UseConsumableCommand.new(&"minor_healing_draught")
	var used: ActionResult = command.execute(run)
	assert_true(used.succeeded, "A use of a backpack consumable should succeed: %s" % used.metadata)

	# The consumable's slot was REMOVED (the inverse of pickup).
	assert_equal(run.inventory.size(), 0, "A successful use removes the consumable's backpack slot.")

	# Exactly one item_consumed event recording the effect.
	assert_equal(used.events.size(), 1, "A successful use should emit exactly one event.")
	var event: DomainEvent = used.events[0]
	assert_equal(event.event_type, DomainEvent.Type.ITEM_CONSUMED, "The emitted event should be item_consumed.")
	assert_equal(String(event.actor_id), "", "item_consumed is a system event with no actor.")
	assert_equal(event.payload.get("item_id"), "minor_healing_draught", "Event should carry the item id.")
	# The effect + explanation are read from the resolved ConsumableDefinition (OUTCOME-RECORD-ONLY).
	var resolved: ConsumableDefinition = ConsumableRepository.create_baseline_repository().get_consumable(&"minor_healing_draught")
	assert_equal(event.payload.get("outcome_effect"), resolved.outcome_effect, "Event records the resolved consumable's outcome_effect.")
	assert_equal(event.payload.get("explanation"), resolved.explanation, "Event records the resolved consumable's explanation.")
	assert_equal(event.payload.get("backpack_size_after"), 0, "Event should carry the post-use backpack size.")
	assert_equal(event.payload.get("slot_index"), 0, "Event should carry the removed slot index.")
	# The emitted event passes payload validation (a full round-trip through real JSON).
	var parsed: ActionResult = DomainEvent.try_from_dictionary(JSON.parse_string(JSON.stringify(event.to_dictionary())))
	assert_true(parsed.succeeded, "The emitted item_consumed event should pass payload validation: %s" % parsed.metadata)

	# Metadata advertises the record.
	assert_true(bool(used.metadata.get("records_consumption")), "Metadata should flag records_consumption.")
	assert_equal(used.metadata.get("slot_index"), 0, "Metadata should carry the removed slot index.")
	assert_equal(used.metadata.get("backpack_size_after"), 0, "Metadata should carry the post-use backpack size.")

	# The run stays structurally valid after the use.
	assert_true(run.validate().succeeded, "A committed use should leave the run structurally valid.")


func _use_removes_only_the_used_slot_other_slots_untouched() -> void:
	# AC3 "removed according to inventory rules" + the no-collateral-damage guarantee: using one consumable removes
	# its slot ONLY; the surrounding slots are byte-identical.
	var run: RunState = _valid_run()
	PickupItemCommand.new(&"padded_vest", &"armor").execute(run)               # index 0
	PickupItemCommand.new(&"warding_salve", &"consumable").execute(run)        # index 1 (to be used)
	PickupItemCommand.new(&"health_morsel", &"pickup").execute(run)            # index 2
	assert_equal(run.inventory.size(), 3, "Setup: three slots before the use.")

	var used: ActionResult = UseConsumableCommand.new(&"warding_salve").execute(run)
	assert_true(used.succeeded, "Using the consumable in the middle slot should succeed.")
	assert_equal(run.inventory.size(), 2, "The use removed exactly one slot.")
	assert_equal(used.events[0].payload.get("slot_index"), 1, "The event records the removed slot's index (1).")
	# The other two slots are intact + in order (the used middle slot is gone).
	assert_equal(run.inventory.backpack[0].get("item_id"), "padded_vest", "The armor slot is untouched.")
	assert_equal(run.inventory.backpack[1].get("item_id"), "health_morsel", "The pickup slot shifts down, order preserved.")


# ---- AC5: no-mutation rejections -----------------------------------------------------------------

func _rejects_non_positive_sequence_id_first_with_no_mutation() -> void:
	# The sequence-id gate fires FIRST (before context/item/inventory). A non-positive id rejects even with a
	# perfectly legal item + run, leaving the run byte-identical with zero events.
	for bad_sequence_id: int in [0, -1]:
		var run: RunState = _run_with_consumable(&"minor_healing_draught")
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = UseConsumableCommand.new(&"minor_healing_draught", bad_sequence_id).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "A non-positive sequence id (%d) must be rejected." % bad_sequence_id)
		assert_equal(rejected.error_code, &"invalid_event_sequence_id", "A non-positive sequence id should use the stable code (%d)." % bad_sequence_id)
		assert_equal(rejected.metadata.get("sequence_id"), bad_sequence_id, "The rejection should echo the offending sequence id.")
		assert_false(rejected.has_events(), "A sequence-id rejection should emit zero events (%d)." % bad_sequence_id)
		assert_equal(after, before, "A sequence-id rejection must leave the run byte-identical (%d)." % bad_sequence_id)

	# validate() alone (pure read) also rejects a non-positive id, FIRST (before the item-id check).
	var validate_only: ActionResult = UseConsumableCommand.new(&"", 0).validate(_valid_run())
	assert_true(validate_only.is_error(), "validate() should reject a non-positive sequence id directly.")
	assert_equal(validate_only.error_code, &"invalid_event_sequence_id", "validate() should surface the sequence-id code FIRST.")


func _rejects_invalid_context() -> void:
	# A non-RunState context is rejected with invalid_context (no crash, no mutation possible).
	var not_a_run: ActionResult = UseConsumableCommand.new(&"minor_healing_draught").execute("not a run state")
	assert_true(not_a_run.is_error(), "A non-RunState context should be rejected.")
	assert_equal(not_a_run.error_code, &"invalid_context", "A bad context should use the stable invalid_context code.")
	assert_false(not_a_run.has_events(), "An invalid-context rejection should emit zero events.")

	# A structurally INVALID run (unknown current node) is rejected as invalid_context, surfacing the inner error.
	var broken: RouteNode = RouteNode.new("node-0-0", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([broken], "ghost", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 1, false, true, route)
	var before: Dictionary = run.to_dictionary()
	var invalid_run: ActionResult = UseConsumableCommand.new(&"minor_healing_draught").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(invalid_run.is_error(), "A structurally invalid run should be rejected.")
	assert_equal(invalid_run.error_code, &"invalid_context", "An invalid run should use the stable invalid_context code.")
	assert_equal(invalid_run.metadata.get("inner_error_code"), "unknown_current_node", "invalid_context should surface the inner validate() error code.")
	assert_false(invalid_run.has_events(), "An invalid-context rejection should emit zero events.")
	assert_equal(after, before, "An invalid-context rejection must leave the run byte-identical.")


func _rejects_a_bad_item_id_with_no_mutation() -> void:
	# An empty / hyphenated (non-lower_snake) item id is rejected (Story-6.1 content ids are lower_snake).
	for bad_id: StringName in [&"", &"Not-Snake", &"node-1-0"]:
		var run: RunState = _run_with_consumable(&"minor_healing_draught")
		var before: Dictionary = run.to_dictionary()
		var rejected: ActionResult = UseConsumableCommand.new(bad_id).execute(run)
		var after: Dictionary = run.to_dictionary()
		assert_true(rejected.is_error(), "A bad item id (%s) must be rejected." % String(bad_id))
		assert_equal(rejected.error_code, &"invalid_item_id", "A bad item id should use the stable invalid_item_id code (%s)." % String(bad_id))
		assert_false(rejected.has_events(), "A bad-item-id rejection should emit zero events (%s)." % String(bad_id))
		assert_equal(after, before, "A bad-item-id rejection must leave the run byte-identical (%s)." % String(bad_id))


func _rejects_item_not_in_inventory_with_no_mutation() -> void:
	# A consumable id that resolves but is NOT in the backpack is rejected (the backpack is the authoritative source).
	var run: RunState = _run_with_consumable(&"minor_healing_draught")
	var before: Dictionary = run.to_dictionary()
	# ember_flask is a real validated consumable, but it is NOT in this backpack.
	var rejected: ActionResult = UseConsumableCommand.new(&"ember_flask").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "A consumable not in the backpack must be rejected.")
	assert_equal(rejected.error_code, &"item_not_in_inventory", "Use the stable item_not_in_inventory code.")
	assert_equal(rejected.metadata.get("item_id"), "ember_flask", "The rejection should echo the offending item id.")
	assert_false(rejected.has_events(), "An item-not-in-inventory rejection should emit zero events.")
	assert_equal(after, before, "An item-not-in-inventory rejection must leave the run byte-identical.")


func _rejects_not_a_consumable_with_no_mutation() -> void:
	# A backpack slot whose category is NOT `consumable` is rejected — a weapon/armor/pickup slot is not usable here.
	var run: RunState = _valid_run()
	PickupItemCommand.new(&"padded_vest", &"armor").execute(run)
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = UseConsumableCommand.new(&"padded_vest").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "Using a non-consumable backpack slot must be rejected.")
	assert_equal(rejected.error_code, &"not_a_consumable", "Use the stable not_a_consumable code.")
	assert_equal(rejected.metadata.get("category"), "armor", "The rejection should echo the offending slot category.")
	assert_false(rejected.has_events(), "A not-a-consumable rejection should emit zero events.")
	assert_equal(after, before, "A not-a-consumable rejection must leave the run byte-identical.")


func _rejects_unknown_consumable_with_no_mutation() -> void:
	# A backpack `consumable` slot whose id does NOT resolve through the repository is rejected fail-closed. Build a
	# run whose backpack carries a consumable-category slot with an id absent from the baseline repo.
	var run: RunState = _valid_run()
	run.inventory.backpack.append(InventoryState.make_slot(&"phantom_elixir", &"consumable"))
	assert_true(run.validate().succeeded, "Setup: the run with a phantom consumable slot still validates.")
	var before: Dictionary = run.to_dictionary()
	var rejected: ActionResult = UseConsumableCommand.new(&"phantom_elixir").execute(run)
	var after: Dictionary = run.to_dictionary()
	assert_true(rejected.is_error(), "An unresolvable consumable id must be rejected fail-closed.")
	assert_equal(rejected.error_code, &"unknown_consumable", "Use the stable unknown_consumable code.")
	assert_equal(rejected.metadata.get("item_id"), "phantom_elixir", "The rejection should echo the offending item id.")
	assert_false(rejected.has_events(), "An unknown-consumable rejection should emit zero events.")
	assert_equal(after, before, "An unknown-consumable rejection must leave the run byte-identical (nothing removed).")


# ---- AC5: determinism / no RNG -------------------------------------------------------------------

func _use_draws_no_rng_on_success_and_reject() -> void:
	# A use draws ZERO RNG. Hold a stream set, snapshot it, run a SUCCESSFUL use and a REJECTED use, and assert the
	# streams are byte-identical in both cases (the command holds no RngStreamSet at all — this guards that no hidden
	# global RNG is touched, the false-PASS grep guard also confirms no randi/randf in the source).
	var streams: RngStreamSet = RngStreamSet.new(24680)
	var before: Dictionary = streams.to_snapshot()

	var run: RunState = _run_with_consumable(&"ember_flask")
	UseConsumableCommand.new(&"ember_flask").execute(run)
	assert_equal(streams.to_snapshot(), before, "A successful use must draw no RNG (stream set unchanged).")

	var reject_run: RunState = _run_with_consumable(&"ember_flask")
	UseConsumableCommand.new(&"not_in_backpack").execute(reject_run)
	assert_equal(streams.to_snapshot(), before, "A rejected use must draw no RNG (stream set unchanged).")


func _use_is_deterministic() -> void:
	# Same starting run + same consumable -> byte-identical resulting run.to_dictionary() (incl. the removed slot).
	var run_a: RunState = _run_with_consumable(&"minor_healing_draught")
	var run_b: RunState = _run_with_consumable(&"minor_healing_draught")
	UseConsumableCommand.new(&"minor_healing_draught").execute(run_a)
	UseConsumableCommand.new(&"minor_healing_draught").execute(run_b)
	assert_equal(run_a.to_dictionary(), run_b.to_dictionary(), "The use must be a deterministic state transition.")
