class_name PickupItemCommand
extends "res://scripts/core/commands/game_command.gd"

# The backpack PICKUP command (Story 6.2) — a RUN-domain command that records ONE gained item into the run's
# InventoryState backpack and emits ONE item_gained SYSTEM event, or fails closed with a stable inventory_full
# error when the backpack is full. It follows the 4.3-ratified run-command idiom VERBATIM (the RouteAdvanceCommand
# template): it extends game_command.gd, takes the live RunState DIRECTLY as its validate(state)/execute(state)
# arg (NO RunActionContext wrapper), the CALLER supplies the run-level sequence_id via the constructor (default
# 1), validate() rejects sequence_id <= 0 FIRST so a success path can never emit an event its own validator
# rejects, and it is validate-then-mutate: on ANY rejection it returns a structured ActionResult.error with ZERO
# events and a byte-identical no-mutation RunState; it builds the item_gained event ONLY AFTER the (infallible)
# slot append. It draws ZERO RNG (a pickup is deterministic — there is no roll here; the reward ROLL is Story
# 6.3, which owns the orchestrator RngStreamSet threading).
#
# WHAT THIS IS NOT (scope boundaries):
#   - NOT the live reward-offer FLOW / reward command / offer-in-domain-state / reward-applied events / the
#     marker->content resolution (Story 6.3). This command records an item that is HANDED to it (the offer flow
#     supplies a real rolled item id); it does NOT roll, draw, or generate a reward offer.
#   - NOT an EQUIP/UNEQUIP command and NOT the character-level equip-gate CHECK (deferred — no hero
#     character-level system exists yet; InventoryState builds the equipment STRUCTURE only).
#   - NOT Consume/Destroy (Stories 6.5/6.6), the passive-reward modal (6.4), or the build smoke run (6.7).
#
# AC3 DECISION (recorded): a full backpack returns the stable lower_snake inventory_full ActionResult.error
# (the recommended v0 — simplest; the replacement-choice UX defers to a later story). Either way the load-bearing
# guarantee holds: a rejected pickup mutates NOTHING (the backpack is byte-identical, the item_gained event is
# NOT emitted, and no existing slot is overwritten or dropped — "no item is silently deleted").
#
# CATEGORY VALIDATION DECISION (recorded): validate() checks the item id is lower_snake (the Story-6.1 content-id
# shape) AND the category is in InventoryState.BACKPACK_CATEGORIES (the allowlist). It does NOT resolve the id
# against a Story-6.1 repository — the offer flow (6.3) hands a REAL rolled id, and a repo lookup here would
# couple the pickup command to the content layer for no v0 benefit (recorded; a later story can tighten to a
# repo-existence check if a pickup ever accepts an unvalidated external id).

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

var item_id: StringName = &""
var category: StringName = &""
var sequence_id: int = 1

func _init(new_item_id: StringName = &"", new_category: StringName = &"", new_sequence_id: int = 1) -> void:
	command_id = &"pickup_item"
	item_id = new_item_id
	category = new_category
	sequence_id = new_sequence_id


# Pure read: validate the sequence id, context, item id/category shape, and backpack capacity. No mutation, no
# event, no RNG.
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the RouteAdvanceCommand precedent): execute() builds an item_gained event with this
	# sequence id, and DomainEvent.try_from_dictionary requires sequence_id > 0 — so a non-positive id would make
	# the success path emit a non-round-trippable event. Reject it BEFORE any state is read or mutated.
	if sequence_id <= 0:
		return ActionResult.error(&"invalid_event_sequence_id", {
			"command": String(command_id),
			"sequence_id": sequence_id
		})
	if not state is RunState:
		return _invalid_context()
	var run: RunState = state as RunState
	# The run must be structurally sound before we record into it.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# The item id must be a lower_snake content id (Story-6.1 ids are lower_snake). A bad/empty id is rejected
	# with a stable code; the offending id rides metadata (not the code — codes carry no arbitrary ids).
	if not _is_lower_snake_id(String(item_id)):
		return ActionResult.error(&"invalid_item_id", {
			"command": String(command_id),
			"item_id": String(item_id)
		})
	# The category must be lower_snake AND in the backpack allowlist (reject, don't coerce — the Story 1.3
	# precedent). An off-allowlist / wrong-shape category is rejected.
	if not _is_lower_snake_id(String(category)) or not InventoryState.is_backpack_category(category):
		return ActionResult.error(&"invalid_item_category", {
			"command": String(command_id),
			"category": String(category)
		})

	# AC3: a full backpack rejects with the stable inventory_full code + the capacity/rejected id in metadata.
	# ZERO mutation (validate is a pure read; execute re-runs validate before any append).
	var inventory: InventoryState = run.inventory
	if inventory == null:
		# Defensive: RunState defaults a non-null inventory, but a directly-nulled field would otherwise crash.
		return _invalid_context()
	if inventory.is_full():
		return ActionResult.error(&"inventory_full", {
			"command": String(command_id),
			"item_id": String(item_id),
			"capacity": inventory.capacity,
			"backpack_size": inventory.size()
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: append ONE single-item slot to the backpack + emit ONE item_gained event
# (built AFTER the infallible mutation). On any reject: structured error, ZERO events, byte-identical RunState
# (no slot overwritten/dropped — the AC3 "no silent delete" guarantee). Draws ZERO RNG; runs no sub-command.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var inventory: InventoryState = run.inventory

	# (1) Append one single-item slot (no stacking — always a fresh quantity-1 slot, never a merge). The append
	# is infallible once validated (capacity was checked above); it never overwrites/drops an existing slot.
	var slot_index: int = inventory.append_slot(item_id, category)
	var backpack_size_after: int = inventory.size()

	# (2) Build the single item_gained system event AFTER the mutation.
	var event: DomainEvent = DomainEvent.item_gained(sequence_id, {
		"item_id": String(item_id),
		"category": String(category),
		"backpack_size_after": backpack_size_after,
		"slot_index": slot_index
	})

	# (3) Return ok with the event + diagnostics metadata.
	return ActionResult.ok([event], {
		"records_item": true,
		"item_id": String(item_id),
		"category": String(category),
		"slot_index": slot_index,
		"backpack_size_after": backpack_size_after
	})


# A single stable top-level code (invalid_context) holds the "give me a valid run" contract for the
# not-a-RunState / structurally-invalid-run cases. When the rejection is caused by a structurally-invalid run,
# attach the inner RunState.validate() error_code (and its metadata) so a corrupt-run rejection is diagnosable
# (mirroring RouteAdvanceCommand._invalid_context). The not-a-RunState case has no inner result.
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)


# Local lower_snake id check (kept LOCAL to the command — the DomainEvent helper is private/static and the
# ActionResult code validator is a different shape). Matches DomainEvent._is_lower_snake_id: non-empty, all
# [a-z0-9_], no hyphens (Story-6.1 content ids are lower_snake).
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
