class_name UseConsumableCommand
extends "res://scripts/core/commands/game_command.gd"

# The USE-a-backpack-consumable command (Story 6.7) — a RUN-domain command that USES a consumable already sitting
# in the run's InventoryState backpack: it resolves the consumable id through a validated ConsumableRepository,
# RECORDS the consumable's OUTCOME-RECORD effect via ONE NEW item_consumed SYSTEM event, and REMOVES the used
# consumable's backpack slot (the inverse of PickupItemCommand's append_slot), or fails closed on an absent /
# wrong-category / unresolvable selection. It is the AC3/AC4 "the player uses a consumable; the command executes
# -> the item effect resolves through domain events -> the consumable is removed" surface.
#
# It follows the 4.3-ratified run-command idiom VERBATIM (the PickupItemCommand / ConsumePassiveCommand template):
# it extends game_command.gd, takes the live RunState DIRECTLY as its validate(state)/execute(state) arg (NO
# wrapper), the CALLER supplies the run-level sequence_id via the constructor (default 1), validate() rejects
# sequence_id <= 0 FIRST so a success path can never emit an event its own validator rejects, and it is
# validate-then-mutate: on ANY rejection it returns a structured ActionResult.error with ZERO events and a
# byte-identical no-mutation RunState; it removes the slot + builds the item_consumed event ONLY AFTER validation.
#
# IT DRAWS ZERO RNG. Use is DETERMINISTIC — a content lookup (ConsumableRepository.get_consumable) + a slot removal
# + a record; there is NO roll here (unlike DestroyPassiveCommand's 70/20/10 roll, which routes through the
# run-level `rewards` stream). The load-bearing guarantee: a rejected use draws NO RNG, removes NOTHING, leaves the
# whole RunState byte-identical with ZERO events.
#
# [Decision] The command takes the `item_id` DIRECTLY (decoupled from any view-model / external id list): the
# run.inventory backpack is the AUTHORITATIVE source of what can be used — the command reads the matching slot, not
# an external offer/id list. (The HUD wiring of an in-flight "use this item" intent -> this command call site is a
# later HUD story; the smoke harness + tests construct UseConsumableCommand.new(item_id, sequence_id) DIRECTLY.)
#
# [Decision] v0 consumable-use is OUTCOME-RECORD-ONLY (the EXACT parallel of 6.3's gold-reward + 6.6's Destroy
# outcome-only decisions). There is NO live HP / wallet / curse domain field in v0 (the run carries
# starting_kit.baseline_hp, a FIXED kit value — NOT a mutable current-HP — and no gold/wallet field). So a "heal" /
# "ward" / "ember" consumable RECORDS its authored outcome_effect + explanation deterministically via the
# item_consumed event — it does NOT mutate an HP bar / wallet / curse because none exists. The live heal/cure/buff
# MUTATION is Epic 7's risk-economy state, wired off the recorded item_consumed effect when that domain field lands.
#
# [Decision] v0 has NO stacking, so using a consumable REMOVES THE WHOLE backpack slot (the inverse of
# PickupItemCommand's append_slot — each occupied slot is exactly one item; there is no quantity-- path since no
# item ships with quantity > 1). The removal is a real InventoryState mutation, asserted byte-identical-except-the-
# removed-slot; a reject removes NOTHING.

# ActionResult is already declared on the GameCommand parent (inherited here); do not redeclare it.
const ConsumableDefinition = preload("res://scripts/content/definitions/consumable_definition.gd")
const ConsumableRepository = preload("res://scripts/content/repositories/consumable_repository.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const InventoryState = preload("res://scripts/run/inventory_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

# The category a usable slot MUST carry — a Use is consumable-specific (it does not "use" a weapon/armor slot). The
# in-inventory gate checks this category against the matching backpack slot.
const CONSUMABLE_CATEGORY := &"consumable"

var item_id: StringName = &""
var sequence_id: int = 1

# The validated-only consumable content gate. Defaults to the baseline repository; injectable as the LAST
# constructor param for tests (mirroring ConsumePassiveCommand's _passive_repository injection). The command
# resolves the offered consumable id to a typed ConsumableDefinition through this gate and fails closed
# `unknown_consumable` on a miss — a consumable that fails validate() is never in the repository, so it can never
# be used.
var _consumable_repository: ConsumableRepository = null

func _init(
	new_item_id: StringName = &"",
	new_sequence_id: int = 1,
	new_consumable_repository: ConsumableRepository = null
) -> void:
	command_id = &"use_consumable"
	item_id = new_item_id
	sequence_id = new_sequence_id
	_consumable_repository = new_consumable_repository if new_consumable_repository != null else ConsumableRepository.create_baseline_repository()


# Pure read: validate the sequence id, context, item-id shape, that a matching consumable slot is in the backpack,
# that the matching slot is a `consumable`, and that the id resolves through the validated ConsumableRepository. No
# mutation, no event, no RNG. The gates fire cheapest/most-specific first (sequence -> context -> id shape ->
# in-inventory -> is-consumable -> resolves).
func validate(state: Variant) -> ActionResult:
	# Self-consistency gate (the PickupItemCommand precedent): execute() builds an item_consumed event with this
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
	# The run must be structurally sound before we use a consumable from it.
	var run_validation: ActionResult = run.validate()
	if run_validation.is_error():
		return _invalid_context(run_validation)

	# Defensive: RunState defaults a non-null inventory, but a directly-nulled field would otherwise crash the slot
	# lookup. Treat a null inventory as an invalid context.
	var inventory: InventoryState = run.inventory
	if inventory == null:
		return _invalid_context()

	# The item id must be a lower_snake content id (Story-6.1 ids are lower_snake). A bad/empty id is rejected with
	# a stable code; the offending id rides metadata (not the code — codes carry no arbitrary ids).
	if not _is_lower_snake_id(String(item_id)):
		return ActionResult.error(&"invalid_item_id", {
			"command": String(command_id),
			"item_id": String(item_id)
		})

	# There must be a matching backpack slot to use. The backpack is the authoritative source of what can be used —
	# an item id not present in the backpack is rejected (the offending id rides metadata).
	var slot_index: int = _first_slot_index_with_id(inventory, item_id)
	if slot_index < 0:
		return ActionResult.error(&"item_not_in_inventory", {
			"command": String(command_id),
			"item_id": String(item_id)
		})

	# The matching slot MUST be a `consumable` (reject, don't coerce — a weapon/armor/pickup slot is not usable via
	# this command). Catches a non-consumable item id that happens to be in the backpack.
	var slot_category: String = String(inventory.backpack[slot_index].get("category", ""))
	if slot_category != String(CONSUMABLE_CATEGORY):
		return ActionResult.error(&"not_a_consumable", {
			"command": String(command_id),
			"item_id": String(item_id),
			"category": slot_category
		})

	# Defense-in-depth fail-closed gate: the consumable id MUST resolve through the validated-only repository. A
	# backpack slot could in principle carry an id that is not a real validated consumable (a hand-built run / a
	# later-removed content id) — fail closed, never record a null effect.
	if _consumable_repository.get_consumable(item_id) == null:
		return ActionResult.error(&"unknown_consumable", {
			"command": String(command_id),
			"item_id": String(item_id)
		})

	return ActionResult.ok()


# Validate-then-mutate. On success: REMOVE the consumable's backpack slot (the inverse of PickupItemCommand's
# append_slot), read the resolved ConsumableDefinition's outcome_effect/explanation, and emit ONE item_consumed
# event (built AFTER the infallible-once-validated removal) recording the effect + the post-removal provenance. On
# any reject: structured error, ZERO events, byte-identical RunState (nothing removed). Draws ZERO RNG; runs no
# sub-command.
func execute(state: Variant) -> ActionResult:
	var validation: ActionResult = validate(state)
	if validation.is_error():
		return validation

	var run: RunState = state as RunState
	var inventory: InventoryState = run.inventory

	# (1) Resolve the consumable (validate proved it resolves non-null + the slot exists + is a consumable).
	var consumable_def: ConsumableDefinition = _consumable_repository.get_consumable(item_id)

	# (2) REMOVE the used consumable's backpack slot (the inverse of append_slot). validate() proved a matching
	# consumable slot exists, so the removal returns a valid slot index (never -1). v0 has no stacking, so this drops
	# the whole slot.
	var slot_index: int = inventory.remove_first_slot_with_id(item_id)
	var backpack_size_after: int = inventory.size()

	# (3) Build the single item_consumed system event AFTER the mutation, recording the resolved effect + the
	# post-removal provenance. The effect is OUTCOME-RECORD-ONLY (no live HP/wallet mutation — none exists in v0).
	var event: DomainEvent = DomainEvent.item_consumed(sequence_id, {
		"item_id": String(item_id),
		"outcome_effect": consumable_def.outcome_effect,
		"explanation": consumable_def.explanation,
		"backpack_size_after": backpack_size_after,
		"slot_index": slot_index
	})

	# (4) Return ok with the single item_consumed event + diagnostics metadata.
	return ActionResult.ok([event], {
		"records_consumption": true,
		"item_id": String(item_id),
		"outcome_effect": consumable_def.outcome_effect,
		"slot_index": slot_index,
		"backpack_size_after": backpack_size_after
	})


# The 0-based index of the FIRST backpack slot whose item_id matches, or -1 if none. Kept LOCAL (a pure read of the
# backpack) so validate() can both prove the slot exists AND surface its index/category without mutating anything.
func _first_slot_index_with_id(inventory: InventoryState, target_item_id: StringName) -> int:
	var target_id: String = String(target_item_id)
	for index: int in range(inventory.backpack.size()):
		if String(inventory.backpack[index].get("item_id", "")) == target_id:
			return index
	return -1


# A single stable top-level code (invalid_context) holds the "give me a valid run" contract for the
# not-a-RunState / structurally-invalid-run cases (copied VERBATIM from PickupItemCommand._invalid_context). When
# the rejection is a structurally-invalid run, attach the inner RunState.validate() error_code (and its metadata)
# for diagnosis. The not-a-RunState case has no inner result.
func _invalid_context(inner: ActionResult = null) -> ActionResult:
	var metadata: Dictionary = {"command": String(command_id)}
	if inner != null and inner.is_error():
		metadata["inner_error_code"] = String(inner.error_code)
		if not inner.metadata.is_empty():
			metadata["inner_metadata"] = inner.metadata.duplicate(true)
	return ActionResult.error(&"invalid_context", metadata)


# Local lower_snake id check (kept LOCAL to the command — mirrors PickupItemCommand._is_lower_snake_id: non-empty,
# all [a-z0-9_], no hyphens; Story-6.1 content ids are lower_snake).
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
