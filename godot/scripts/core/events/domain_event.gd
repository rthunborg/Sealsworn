class_name DomainEvent
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")

enum Type {
	UNKNOWN,
	RUN_STARTED,
	BOARD_CREATED,
	RNG_STREAM_ADVANCED,
	COMMAND_REJECTED,
	ENTITY_MOVED,
	VISIBILITY_UPDATED,
	ENTITY_ATTACKED,
	DAMAGE_APPLIED,
	STATUS_EFFECT_APPLIED,
	ENTITY_KNOCKED_BACK,
	TILE_MARKED,
	MARKED_TILE_DETONATED,
	ENEMY_WAITED,
	LEVEL_VICTORY_REACHED,
	LEVEL_DEFEAT_REACHED,
	ROUTE_ADVANCED,
	NODE_ENTERED,
	NODE_EXITED,
	ROUTE_SEALED,
	NODE_PLACEHOLDER_RESOLVED,
	RUN_COMPLETED,
	ITEM_GAINED,
	REWARD_OFFERED,
	REWARD_RESOLVED,
	PASSIVE_CONSUMED,
	PASSIVE_DESTROYED,
	ITEM_CONSUMED,
	ECONOMY_CHANGED
}

const EVENT_ID_UNKNOWN := &"unknown"
const EVENT_ID_RUN_STARTED := &"run_started"
const EVENT_ID_BOARD_CREATED := &"board_created"
const EVENT_ID_RNG_STREAM_ADVANCED := &"rng_stream_advanced"
const EVENT_ID_COMMAND_REJECTED := &"command_rejected"
const EVENT_ID_ENTITY_MOVED := &"entity_moved"
const EVENT_ID_VISIBILITY_UPDATED := &"visibility_updated"
const EVENT_ID_ENTITY_ATTACKED := &"entity_attacked"
const EVENT_ID_DAMAGE_APPLIED := &"damage_applied"
const EVENT_ID_STATUS_EFFECT_APPLIED := &"status_effect_applied"
const EVENT_ID_ENTITY_KNOCKED_BACK := &"entity_knocked_back"
const EVENT_ID_TILE_MARKED := &"tile_marked"
const EVENT_ID_MARKED_TILE_DETONATED := &"marked_tile_detonated"
const EVENT_ID_ENEMY_WAITED := &"enemy_waited"
const EVENT_ID_LEVEL_VICTORY_REACHED := &"level_victory_reached"
const EVENT_ID_LEVEL_DEFEAT_REACHED := &"level_defeat_reached"
const EVENT_ID_ROUTE_ADVANCED := &"route_advanced"
const EVENT_ID_NODE_ENTERED := &"node_entered"
const EVENT_ID_NODE_EXITED := &"node_exited"
const EVENT_ID_ROUTE_SEALED := &"route_sealed"
const EVENT_ID_NODE_PLACEHOLDER_RESOLVED := &"node_placeholder_resolved"
const EVENT_ID_RUN_COMPLETED := &"run_completed"
const EVENT_ID_ITEM_GAINED := &"item_gained"
const EVENT_ID_REWARD_OFFERED := &"reward_offered"
const EVENT_ID_REWARD_RESOLVED := &"reward_resolved"
const EVENT_ID_PASSIVE_CONSUMED := &"passive_consumed"
const EVENT_ID_PASSIVE_DESTROYED := &"passive_destroyed"
const EVENT_ID_ITEM_CONSUMED := &"item_consumed"
const EVENT_ID_ECONOMY_CHANGED := &"economy_changed"

# The allowlisted item categories the item_gained payload may carry (lower_snake). Mirrors
# InventoryState.BACKPACK_CATEGORIES (the Story-6.1 loot categories). Kept LOCAL to domain_event.gd (a static
# const) so the validator has no cross-script dependency on the run-domain model — the value sets are pinned to
# match by test. A category outside this set is rejected as a malformed payload.
const ITEM_GAINED_CATEGORIES: Array[StringName] = [
	&"weapon",
	&"armor",
	&"jewelry",
	&"support",
	&"consumable",
	&"pickup"
]

# The allowlisted reward categories the reward_offered / reward_resolved payloads may carry (lower_snake). It is
# the backpack categories PLUS `gold` and `passive` (the two reward-only categories that are NOT backpack items —
# gold has no wallet yet, a passive's Consume/Destroy resolution is Story 6.5/6.6). Mirrors
# RewardTableDefinition.REWARD_CATEGORIES. Kept LOCAL to domain_event.gd (a static const) so the validator has no
# cross-script dependency on the content model — the value sets are pinned to match by test. A category outside
# this set is rejected as a malformed payload.
const REWARD_CATEGORIES: Array[StringName] = [
	&"weapon",
	&"armor",
	&"jewelry",
	&"support",
	&"consumable",
	&"pickup",
	&"passive",
	&"gold"
]

# The allowlisted Destroy outcome categories the passive_destroyed payload may carry (lower_snake). The three
# FR50/GDD Destroy outcome categories. Mirrors DestroyOutcomeTableDefinition.DESTROY_OUTCOME_CATEGORIES. Kept LOCAL
# to domain_event.gd (a static const) so the validator has no cross-script dependency on the content model — the
# value sets are pinned to match by test. A category outside this set is rejected as a malformed payload.
const DESTROY_OUTCOME_CATEGORIES: Array[StringName] = [
	&"small_immediate_benefit",
	&"progress_unlock_hidden_flag",
	&"no_obvious_reward_avoids_danger"
]

# The stable placeholder markers carried by the two Story 4.5 events (lower_snake). RESOLUTION_PLACEHOLDER
# is the node_placeholder_resolved.resolution value for EVERY placeholder node (the five non-combat types
# AND the boss); RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER is the run_completed.outcome value for the boss
# placeholder run-end. The validators assert these EXACT values (mirroring level_victory_reached's
# outcome == "victory" value-equality). NodeResolvePlaceholderCommand references these so the command and
# the validator stay in lockstep on the marker vocabulary.
const RESOLUTION_PLACEHOLDER := &"placeholder_completed"
const RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER := &"boss_placeholder"

var event_type: int = Type.UNKNOWN
var sequence_id: int = 0
var actor_id: StringName = &""
var payload: Dictionary = {}

func _init(
	new_event_type: int = Type.UNKNOWN,
	new_sequence_id: int = 0,
	new_actor_id: StringName = &"",
	new_payload: Dictionary = {}
) -> void:
	event_type = new_event_type
	sequence_id = new_sequence_id
	actor_id = new_actor_id
	payload = new_payload.duplicate(true)


static func run_started(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor). root_seed is decimal-string encoded (full int64-safe, mirroring
	# RunSnapshot/RunState); is_manual_seed is a bool; node_count is a non-negative integer.
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["root_seed"] = str(payload.get("root_seed", "0"))
	payload_value["is_manual_seed"] = bool(payload.get("is_manual_seed", false))
	payload_value["node_count"] = int(payload.get("node_count", 0))
	return load("res://scripts/core/events/domain_event.gd").new(Type.RUN_STARTED, sequence_id, &"", payload_value)


static func route_advanced(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor): a run-level route POINTER advance (Story 4.3). It is NOT an entity
	# action, so it is NOT in _event_requires_actor (actor_id stays empty). Node ids carry hyphens
	# (e.g. "node-1-0" from RouteGenerator._mint_node_id) so they are plain non-empty strings, NOT
	# lower_snake ids. to_node_type is a lower_snake RouteNode.TYPE_* id. Normalize/duplicate the
	# payload defensively (mirroring run_started); revealed_node_ids defaults to an empty Array.
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["from_node_id"] = String(payload.get("from_node_id", ""))
	payload_value["to_node_id"] = String(payload.get("to_node_id", ""))
	payload_value["to_node_type"] = String(payload.get("to_node_type", ""))
	payload_value["to_node_depth"] = int(payload.get("to_node_depth", 0))
	payload_value["cleared_node_id"] = String(payload.get("cleared_node_id", ""))
	var revealed_value: Variant = payload.get("revealed_node_ids", [])
	var revealed_ids: Array[String] = []
	if revealed_value is Array:
		for revealed_id: Variant in revealed_value:
			if revealed_id is String or revealed_id is StringName:
				revealed_ids.append(String(revealed_id))
	payload_value["revealed_node_ids"] = revealed_ids
	return load("res://scripts/core/events/domain_event.gd").new(Type.ROUTE_ADVANCED, sequence_id, &"", payload_value)


static func node_entered(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 4.4): a run-level node ENTRY that transitions ACTIVE_ROUTE ->
	# NODE_RESOLUTION and produces a level GenerationRequest. NOT an entity action, so it is NOT in
	# _event_requires_actor (actor_id stays empty). node_id carries hyphens (RouteGenerator mints
	# "node-<depth>-<index>") so it is a PLAIN non-empty string, NOT lower_snake. node_type, recipe_id,
	# size_class, and the DERIVED lower_snake level_request_node_id ARE lower_snake. node_depth is a
	# non-negative integral. Normalize/duplicate defensively (mirroring route_advanced).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["node_id"] = String(payload.get("node_id", ""))
	payload_value["node_type"] = String(payload.get("node_type", ""))
	payload_value["node_depth"] = int(payload.get("node_depth", 0))
	payload_value["level_request_node_id"] = String(payload.get("level_request_node_id", ""))
	payload_value["recipe_id"] = String(payload.get("recipe_id", ""))
	payload_value["size_class"] = String(payload.get("size_class", ""))
	return load("res://scripts/core/events/domain_event.gd").new(Type.NODE_ENTERED, sequence_id, &"", payload_value)


static func node_exited(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 4.4): a run-level node EXIT that marks the resolved node cleared
	# and transitions NODE_RESOLUTION -> ACTIVE_ROUTE. node_id carries hyphens -> PLAIN non-empty
	# string; node_type is lower_snake; node_depth is a non-negative integral; rewards_placeholder is a
	# bool. Normalize/duplicate defensively (mirroring route_advanced).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["node_id"] = String(payload.get("node_id", ""))
	payload_value["node_type"] = String(payload.get("node_type", ""))
	payload_value["node_depth"] = int(payload.get("node_depth", 0))
	payload_value["rewards_placeholder"] = bool(payload.get("rewards_placeholder", false))
	return load("res://scripts/core/events/domain_event.gd").new(Type.NODE_EXITED, sequence_id, &"", payload_value)


static func route_sealed(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 4.4): the deterministic door-sealed CONTAINMENT cue emitted on node
	# exit (GDD line 210 "doors seal behind the hero as a containment law"). It is a pure presentation
	# record — presentation/audio MIRROR it; it never drives domain control flow. node_id (the sealed
	# node) carries hyphens -> PLAIN non-empty string; cue_id is lower_snake (and the command asserts the
	# exact value door_sealed_placeholder). Normalize/duplicate defensively.
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["node_id"] = String(payload.get("node_id", ""))
	payload_value["cue_id"] = String(payload.get("cue_id", ""))
	return load("res://scripts/core/events/domain_event.gd").new(Type.ROUTE_SEALED, sequence_id, &"", payload_value)


static func node_placeholder_resolved(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 4.5): a run-level NON-combat / boss placeholder node RESOLUTION that
	# transitions ACTIVE_ROUTE -> NODE_RESOLUTION with NO tactical level (no GenerationRequest). It is the
	# "placeholder completion in domain/debug terms" record for the five non-combat MVP node types
	# (shop/reforge/gambling/event/secret) AND the boss placeholder — a deterministic marker a later real
	# system (shop = Epic 6/7, event/risk = Epic 7, boss = Epic 9) hooks the SAME node boundary. NOT an
	# entity action, so it is NOT in _event_requires_actor (actor_id stays empty). node_id carries hyphens
	# (RouteGenerator mints "node-<depth>-<index>") -> PLAIN non-empty string, NOT lower_snake. node_type
	# (the actual placeholder node type) + resolution (the stable placeholder marker) are lower_snake;
	# node_depth is a non-negative integral. Normalize/duplicate defensively (mirroring node_entered).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["node_id"] = String(payload.get("node_id", ""))
	payload_value["node_type"] = String(payload.get("node_type", ""))
	payload_value["node_depth"] = int(payload.get("node_depth", 0))
	payload_value["resolution"] = String(payload.get("resolution", ""))
	return load("res://scripts/core/events/domain_event.gd").new(Type.NODE_PLACEHOLDER_RESOLVED, sequence_id, &"", payload_value)


static func run_completed(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 4.5): the run-END boundary emitted when the BOSS placeholder resolves
	# before Epic 9 content exists (transition NODE_RESOLUTION -> COMPLETED). This is the node-boundary
	# record AC3 demands; Epic 9 reuses THIS boundary, swapping only the boss's pre-completion behavior (a
	# real boss level + a real victory) — NOT the run_completed event itself. It is NOT a sealed mid-run
	# node (no node_exited / route_sealed return-to-route): the boss ENDS the run. NOT an entity action, so
	# it is NOT in _event_requires_actor (actor_id stays empty). outcome is a lower_snake placeholder
	# marker (the validator additionally asserts the exact value, mirroring level_victory_reached's
	# outcome == "victory"); boss_node_id carries hyphens -> PLAIN non-empty string; cleared_node_count is
	# a non-negative integral. Normalize/duplicate defensively.
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["outcome"] = String(payload.get("outcome", ""))
	payload_value["boss_node_id"] = String(payload.get("boss_node_id", ""))
	payload_value["cleared_node_count"] = int(payload.get("cleared_node_count", 0))
	return load("res://scripts/core/events/domain_event.gd").new(Type.RUN_COMPLETED, sequence_id, &"", payload_value)


static func item_gained(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 6.2): a backpack item PICKUP record emitted by PickupItemCommand AFTER the
	# (infallible) slot append. NOT an entity action, so it is NOT in _event_requires_actor (actor_id stays
	# empty). UNLIKE the route node ids of the run/route events, item ids are Story-6.1 CONTENT ids — they are
	# lower_snake (no hyphens), so item_id + category use the lower_snake helpers (NOT the plain hyphen-tolerant
	# string helpers). backpack_size_after is the backpack slot count AFTER the append (a small non-negative
	# bounded int <= the capacity, well under 2^53); slot_index is the 0-based index of the appended slot (==
	# the prior backpack size). Normalize/duplicate the payload defensively (mirroring run_completed).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["item_id"] = String(payload.get("item_id", ""))
	payload_value["category"] = String(payload.get("category", ""))
	payload_value["backpack_size_after"] = int(payload.get("backpack_size_after", 0))
	payload_value["slot_index"] = int(payload.get("slot_index", 0))
	return load("res://scripts/core/events/domain_event.gd").new(Type.ITEM_GAINED, sequence_id, &"", payload_value)


static func reward_offered(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 6.3): the deterministic reward-OFFER record emitted at GENERATE time when a
	# combat/reward node draws a reward offer through the run-level RngStreamSet (the FIRST live reward roll). NOT
	# an entity action, so it is NOT in _event_requires_actor (actor_id stays empty). table_id + each offered
	# entry's category/content_id are Story-6.1 CONTENT ids -> lower_snake (no hyphens), so they use the
	# lower_snake helpers (UNLIKE the hyphenated route node ids); the category allowlist adds gold/passive
	# (REWARD_CATEGORIES). roll + draw_index are non-negative integral (the draw's weighted-pick roll + the stream
	# draw index). offered_entries is normalized to a plain Array of plain {category, content_id} dicts.
	# Normalize/duplicate the payload defensively (mirroring item_gained).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["table_id"] = String(payload.get("table_id", ""))
	payload_value["offered_entries"] = _normalize_reward_entries(payload.get("offered_entries", []))
	payload_value["roll"] = int(payload.get("roll", 0))
	payload_value["draw_index"] = int(payload.get("draw_index", 0))
	return load("res://scripts/core/events/domain_event.gd").new(Type.REWARD_OFFERED, sequence_id, &"", payload_value)


static func reward_resolved(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 6.3): the reward-RESOLVED record emitted by ResolveRewardCommand AFTER the
	# offer is applied (the chosen entry's category/content_id) and the offer flips to `resolved`. NOT an entity
	# action, so it is NOT in _event_requires_actor (actor_id stays empty). table_id + category + content_id are
	# Story-6.1 CONTENT ids -> lower_snake (no hyphens); the category allowlist adds gold/passive
	# (REWARD_CATEGORIES). Normalize/duplicate the payload defensively (mirroring item_gained).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["table_id"] = String(payload.get("table_id", ""))
	payload_value["category"] = String(payload.get("category", ""))
	payload_value["content_id"] = String(payload.get("content_id", ""))
	return load("res://scripts/core/events/domain_event.gd").new(Type.REWARD_RESOLVED, sequence_id, &"", payload_value)


static func passive_consumed(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 6.5): the passive-CONSUMED record emitted by ConsumePassiveCommand AFTER the
	# offered passive is REGISTERED into the run's RulesResolver (the real adoption) and the offer flips to
	# `resolved`. NOT an entity action, so it is NOT in _event_requires_actor (actor_id stays empty). passive_id is
	# a Story-5.4 passive id and table_id is the offer's table id — both Story-5.4/6.1 CONTENT ids -> lower_snake
	# (no hyphens). Normalize/duplicate the payload defensively (mirroring reward_resolved). The command draws ZERO
	# RNG — Consume is deterministic, so there is NO roll/draw_index on this payload (unlike reward_offered).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["passive_id"] = String(payload.get("passive_id", ""))
	payload_value["table_id"] = String(payload.get("table_id", ""))
	return load("res://scripts/core/events/domain_event.gd").new(Type.PASSIVE_CONSUMED, sequence_id, &"", payload_value)


static func passive_destroyed(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 6.6): the passive-DESTROYED record emitted by DestroyPassiveCommand AFTER the
	# offered passive's 70/20/10 outcome is ROLLED through the run-level RngStreamSet `rewards` stream and the offer
	# flips to `resolved`. NOT an entity action, so it is NOT in _event_requires_actor (actor_id stays empty).
	# passive_id is a Story-5.4 passive id, table_id is the offer's table id, outcome_category/outcome_id are the
	# rolled Destroy outcome (DestroyOutcomeTableDefinition) — all lower_snake content ids. Unlike passive_consumed,
	# Destroy DRAWS RNG, so the payload carries the draw provenance roll/draw_index (mirroring reward_offered) plus an
	# outcome_effect marker + an explanation of the known result. Normalize/duplicate the payload defensively
	# (mirroring reward_resolved + reward_offered).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["passive_id"] = String(payload.get("passive_id", ""))
	payload_value["table_id"] = String(payload.get("table_id", ""))
	payload_value["outcome_category"] = String(payload.get("outcome_category", ""))
	payload_value["outcome_id"] = String(payload.get("outcome_id", ""))
	payload_value["outcome_effect"] = String(payload.get("outcome_effect", ""))
	payload_value["explanation"] = String(payload.get("explanation", ""))
	payload_value["roll"] = int(payload.get("roll", 0))
	payload_value["draw_index"] = int(payload.get("draw_index", 0))
	return load("res://scripts/core/events/domain_event.gd").new(Type.PASSIVE_DESTROYED, sequence_id, &"", payload_value)


static func item_consumed(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 6.7): a backpack consumable USE record emitted by UseConsumableCommand AFTER the
	# (infallible-once-validated) slot removal. NOT an entity action, so it is NOT in _event_requires_actor (actor_id
	# stays empty). item_id is a Story-6.1 CONTENT id -> lower_snake (no hyphens), so it is validated via the
	# lower_snake helper (UNLIKE the hyphenated route node ids). outcome_effect + explanation are the resolved
	# ConsumableDefinition's OUTCOME-RECORD effect marker + the player/debug-readable known result (non-empty
	# strings). backpack_size_after is the backpack slot count AFTER the removal; slot_index is the 0-based index the
	# removed slot occupied. UNLIKE passive_destroyed (which DRAWS the 70/20/10 roll), Use draws ZERO RNG, so there is
	# NO roll/draw_index on this payload — it is a deterministic content-lookup + slot-removal + record. Normalize/
	# duplicate the payload defensively (mirroring item_gained).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["item_id"] = String(payload.get("item_id", ""))
	payload_value["outcome_effect"] = String(payload.get("outcome_effect", ""))
	payload_value["explanation"] = String(payload.get("explanation", ""))
	payload_value["backpack_size_after"] = int(payload.get("backpack_size_after", 0))
	payload_value["slot_index"] = int(payload.get("slot_index", 0))
	return load("res://scripts/core/events/domain_event.gd").new(Type.ITEM_CONSUMED, sequence_id, &"", payload_value)


static func economy_changed(sequence_id: int, payload: Dictionary = {}) -> DomainEvent:
	# System event (no actor, Story 7.1): the deterministic CURRENCY/HEALING-change record emitted by
	# ApplyEconomyChangeCommand AFTER a gold/healing change is applied (AC2) AND by ResolveRewardCommand when a gold
	# reward credits the wallet (the T1 wire-off). NOT an entity action, so it is NOT in _event_requires_actor
	# (actor_id stays empty). `reason` is the AC2 explanation-log reason (a lower_snake marker id, e.g.
	# gold_reward_resolved / heal_spent). gold_before/gold_after + healing_before/healing_after are non-negative
	# integral (a wallet/charge count is never negative); gold_delta/healing_delta are SIGNED integral (a credit is
	# positive, a spend negative — UNLIKE the always-non-negative roll/draw_index of the roll events). UNLIKE
	# passive_destroyed there is NO roll/draw_index: an economy change is a RECORDED amount, not a roll (the command
	# draws ZERO RNG — deterministic, the item_consumed shell). Normalize/duplicate the payload defensively (mirroring
	# item_consumed).
	var payload_value: Dictionary = payload.duplicate(true)
	payload_value["reason"] = String(payload.get("reason", ""))
	payload_value["gold_before"] = int(payload.get("gold_before", 0))
	payload_value["gold_after"] = int(payload.get("gold_after", 0))
	payload_value["gold_delta"] = int(payload.get("gold_delta", 0))
	payload_value["healing_before"] = int(payload.get("healing_before", 0))
	payload_value["healing_after"] = int(payload.get("healing_after", 0))
	payload_value["healing_delta"] = int(payload.get("healing_delta", 0))
	return load("res://scripts/core/events/domain_event.gd").new(Type.ECONOMY_CHANGED, sequence_id, &"", payload_value)


# Normalize an arbitrary offered-entries input into a clean Array of plain {category, content_id} dicts (the
# reward_offered factory uses this so the payload entry shape stays pinned). Each Dictionary entry is reshaped to
# EXACTLY {category, content_id} (plain Strings); a non-dict entry is skipped. Deep-copies (no shared reference).
static func _normalize_reward_entries(raw: Variant) -> Array:
	var result: Array = []
	if not raw is Array:
		return result
	for entry_value: Variant in (raw as Array):
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		result.append({
			"category": String(entry.get("category", "")),
			"content_id": String(entry.get("content_id", ""))
		})
	return result


static func board_created(sequence_id: int, width: int, height: int) -> DomainEvent:
	return load("res://scripts/core/events/domain_event.gd").new(Type.BOARD_CREATED, sequence_id, &"", {
		"width": width,
		"height": height
	})


static func entity_moved(
	sequence_id: int,
	actor_id: StringName,
	from_cell: Vector2i,
	to_cell: Vector2i,
	movement_cost: int,
	movement_budget: int
) -> DomainEvent:
	return load("res://scripts/core/events/domain_event.gd").new(Type.ENTITY_MOVED, sequence_id, actor_id, {
		"from": _cell_payload(from_cell),
		"to": _cell_payload(to_cell),
		"movement_cost": movement_cost,
		"movement_budget": movement_budget
	})


static func visibility_updated(
	sequence_id: int,
	actor_id: StringName,
	origin: Vector2i,
	radius: int,
	visible_cells: Array,
	newly_explored_cells: Array
) -> DomainEvent:
	return load("res://scripts/core/events/domain_event.gd").new(Type.VISIBILITY_UPDATED, sequence_id, actor_id, {
		"origin": _cell_payload(origin),
		"radius": radius,
		"visible_cells": _cell_array_payload(visible_cells),
		"newly_explored_cells": _cell_array_payload(newly_explored_cells)
	})


static func entity_attacked(
	sequence_id: int,
	actor_id: StringName,
	target_entity_id: StringName,
	target_cell: Vector2i,
	weapon_id: StringName,
	preview_payload: Dictionary = {}
) -> DomainEvent:
	var payload_value: Dictionary = preview_payload.duplicate(true)
	payload_value["actor_id"] = String(actor_id)
	payload_value["target_entity_id"] = String(target_entity_id)
	payload_value["target_cell"] = _cell_payload(target_cell)
	payload_value["weapon_id"] = String(weapon_id)
	return load("res://scripts/core/events/domain_event.gd").new(
		Type.ENTITY_ATTACKED,
		sequence_id,
		actor_id,
		payload_value
	)


static func damage_applied(
	sequence_id: int,
	actor_id: StringName,
	target_entity_id: StringName,
	amount: int,
	hp_before: int,
	hp_after: int,
	max_hp: int,
	damage_payload: Dictionary = {}
) -> DomainEvent:
	var payload_value: Dictionary = damage_payload.duplicate(true)
	payload_value["target_entity_id"] = String(target_entity_id)
	payload_value["amount"] = amount
	payload_value["hp_before"] = hp_before
	payload_value["hp_after"] = hp_after
	payload_value["max_hp"] = max_hp
	payload_value["final_damage"] = amount
	return load("res://scripts/core/events/domain_event.gd").new(
		Type.DAMAGE_APPLIED,
		sequence_id,
		actor_id,
		payload_value
	)


static func status_effect_applied(
	sequence_id: int,
	actor_id: StringName,
	target_entity_id: StringName,
	effect_id: StringName,
	status_payload: Dictionary = {}
) -> DomainEvent:
	var payload_value: Dictionary = status_payload.duplicate(true)
	payload_value["target_entity_id"] = String(target_entity_id)
	payload_value["effect_id"] = String(effect_id)
	return load("res://scripts/core/events/domain_event.gd").new(
		Type.STATUS_EFFECT_APPLIED,
		sequence_id,
		actor_id,
		payload_value
	)


static func entity_knocked_back(
	sequence_id: int,
	actor_id: StringName,
	target_entity_id: StringName,
	from_cell: Vector2i,
	to_cell: Vector2i,
	weapon_id: StringName,
	knockback_payload: Dictionary = {}
) -> DomainEvent:
	var payload_value: Dictionary = knockback_payload.duplicate(true)
	payload_value["target_entity_id"] = String(target_entity_id)
	payload_value["from"] = _cell_payload(from_cell)
	payload_value["to"] = _cell_payload(to_cell)
	payload_value["weapon_id"] = String(weapon_id)
	return load("res://scripts/core/events/domain_event.gd").new(
		Type.ENTITY_KNOCKED_BACK,
		sequence_id,
		actor_id,
		payload_value
	)


static func tile_marked(
	sequence_id: int,
	actor_id: StringName,
	target_entity_id: StringName,
	marked_cell: Vector2i,
	telegraph_id: String,
	mark_payload: Dictionary = {}
) -> DomainEvent:
	var payload_value: Dictionary = mark_payload.duplicate(true)
	payload_value["target_entity_id"] = String(target_entity_id)
	payload_value["marked_cell"] = _cell_payload(marked_cell)
	payload_value["telegraph_id"] = telegraph_id
	return load("res://scripts/core/events/domain_event.gd").new(
		Type.TILE_MARKED,
		sequence_id,
		actor_id,
		payload_value
	)


static func marked_tile_detonated(
	sequence_id: int,
	actor_id: StringName,
	target_entity_id: StringName,
	marked_cell: Vector2i,
	telegraph_id: String,
	outcome: StringName,
	detonation_payload: Dictionary = {}
) -> DomainEvent:
	var payload_value: Dictionary = detonation_payload.duplicate(true)
	payload_value["target_entity_id"] = String(target_entity_id)
	payload_value["marked_cell"] = _cell_payload(marked_cell)
	payload_value["telegraph_id"] = telegraph_id
	payload_value["outcome"] = String(outcome)
	return load("res://scripts/core/events/domain_event.gd").new(
		Type.MARKED_TILE_DETONATED,
		sequence_id,
		actor_id,
		payload_value
	)


static func enemy_waited(
	sequence_id: int,
	actor_id: StringName,
	reason: StringName,
	wait_payload: Dictionary = {}
) -> DomainEvent:
	var payload_value: Dictionary = wait_payload.duplicate(true)
	payload_value["reason"] = String(reason)
	return load("res://scripts/core/events/domain_event.gd").new(
		Type.ENEMY_WAITED,
		sequence_id,
		actor_id,
		payload_value
	)


static func level_victory_reached(
	sequence_id: int,
	living_player_count: int,
	remaining_enemy_count: int,
	defeated_enemy_ids: Array,
	cause_event_sequence_id: int,
	explanation: String
) -> DomainEvent:
	return load("res://scripts/core/events/domain_event.gd").new(Type.LEVEL_VICTORY_REACHED, sequence_id, &"", {
		"outcome": "victory",
		"living_player_count": living_player_count,
		"remaining_enemy_count": remaining_enemy_count,
		"defeated_enemy_ids": _string_array_payload(defeated_enemy_ids),
		"cause_event_sequence_id": cause_event_sequence_id,
		"explanation": explanation
	})


static func level_defeat_reached(
	sequence_id: int,
	defeated_player_id: StringName,
	cause_event_sequence_id: int,
	cause_event_id: StringName,
	source_entity_id: StringName,
	damage_type: StringName,
	final_damage: int,
	explanation: String
) -> DomainEvent:
	return load("res://scripts/core/events/domain_event.gd").new(Type.LEVEL_DEFEAT_REACHED, sequence_id, &"", {
		"outcome": "defeat",
		"defeated_player_id": String(defeated_player_id),
		"cause_event_sequence_id": cause_event_sequence_id,
		"cause_event_id": String(cause_event_id),
		"source_entity_id": String(source_entity_id),
		"damage_type": String(damage_type),
		"final_damage": final_damage,
		"explanation": explanation
	})


func to_dictionary() -> Dictionary:
	return {
		"event_id": String(id_for_type(event_type)),
		"sequence_id": sequence_id,
		"actor_id": String(actor_id),
		"payload": payload.duplicate(true)
	}


static func from_dictionary(data: Dictionary) -> DomainEvent:
	var parse_result: Variant = try_from_dictionary(data)
	if parse_result.succeeded:
		return parse_result.metadata.get("event") as DomainEvent

	return load("res://scripts/core/events/domain_event.gd").new()


static func try_from_dictionary(data: Dictionary) -> ActionResult:
	if not data.has("event_id"):
		return _error_result(&"invalid_event_id", {"field": "event_id"})

	var event_id_value: Variant = data.get("event_id")
	if not (event_id_value is String or event_id_value is StringName):
		return _error_result(&"invalid_event_id", {"field": "event_id"})

	var event_id: StringName = StringName(String(event_id_value))
	var parsed_event_type: int = type_for_id(event_id)
	if parsed_event_type == Type.UNKNOWN:
		return _error_result(&"invalid_event_id", {
			"event_id": String(event_id)
		})

	if not data.has("sequence_id"):
		return _error_result(&"invalid_event_sequence_id", {"field": "sequence_id"})

	var sequence_id_value: Variant = data.get("sequence_id")
	if not _is_integral_number(sequence_id_value):
		return _error_result(&"invalid_event_sequence_id", {"field": "sequence_id"})

	var parsed_sequence_id: int = int(sequence_id_value)
	if parsed_sequence_id <= 0:
		return _error_result(&"invalid_event_sequence_id", {
			"sequence_id": parsed_sequence_id
		})

	if not data.has("actor_id"):
		return _error_result(&"invalid_event_actor_id", {"field": "actor_id"})

	var actor_id_value: Variant = data.get("actor_id")
	if not (actor_id_value is String or actor_id_value is StringName):
		return _error_result(&"invalid_event_actor_id", {"field": "actor_id"})
	if _event_requires_actor(parsed_event_type) and String(actor_id_value).is_empty():
		return _error_result(&"invalid_event_actor_id", {"field": "actor_id"})

	if not data.has("payload"):
		return _error_result(&"invalid_event_payload", {"field": "payload"})

	var payload_value: Variant = data.get("payload")
	if not payload_value is Dictionary:
		return _error_result(&"invalid_event_payload", {"field": "payload"})
	var payload_validation: ActionResult = _validate_payload_for_event(parsed_event_type, payload_value)
	if payload_validation.is_error():
		return payload_validation

	var event: DomainEvent = load("res://scripts/core/events/domain_event.gd").new(
		parsed_event_type,
		parsed_sequence_id,
		StringName(String(actor_id_value)),
		payload_value
	)
	return _ok_result({"event": event})


static func _ok_result(new_metadata: Dictionary = {}) -> ActionResult:
	var result: ActionResult = ActionResult.new()
	result.succeeded = true
	result.metadata = new_metadata.duplicate(true)
	return result


static func _error_result(new_error_code: StringName, new_metadata: Dictionary = {}) -> ActionResult:
	return ActionResult.error(new_error_code, new_metadata)


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false


static func _validate_payload_for_event(event_type_value: int, payload_value: Dictionary) -> ActionResult:
	match event_type_value:
		Type.RUN_STARTED:
			return _validate_run_started_payload(payload_value)
		Type.ROUTE_ADVANCED:
			return _validate_route_advanced_payload(payload_value)
		Type.NODE_ENTERED:
			return _validate_node_entered_payload(payload_value)
		Type.NODE_EXITED:
			return _validate_node_exited_payload(payload_value)
		Type.ROUTE_SEALED:
			return _validate_route_sealed_payload(payload_value)
		Type.NODE_PLACEHOLDER_RESOLVED:
			return _validate_node_placeholder_resolved_payload(payload_value)
		Type.RUN_COMPLETED:
			return _validate_run_completed_payload(payload_value)
		Type.ITEM_GAINED:
			return _validate_item_gained_payload(payload_value)
		Type.REWARD_OFFERED:
			return _validate_reward_offered_payload(payload_value)
		Type.REWARD_RESOLVED:
			return _validate_reward_resolved_payload(payload_value)
		Type.PASSIVE_CONSUMED:
			return _validate_passive_consumed_payload(payload_value)
		Type.PASSIVE_DESTROYED:
			return _validate_passive_destroyed_payload(payload_value)
		Type.ITEM_CONSUMED:
			return _validate_item_consumed_payload(payload_value)
		Type.ECONOMY_CHANGED:
			return _validate_economy_changed_payload(payload_value)
		Type.ENTITY_MOVED:
			return _validate_entity_moved_payload(payload_value)
		Type.VISIBILITY_UPDATED:
			return _validate_visibility_updated_payload(payload_value)
		Type.ENTITY_ATTACKED:
			return _validate_entity_attacked_payload(payload_value)
		Type.DAMAGE_APPLIED:
			return _validate_damage_applied_payload(payload_value)
		Type.STATUS_EFFECT_APPLIED:
			return _validate_status_effect_applied_payload(payload_value)
		Type.ENTITY_KNOCKED_BACK:
			return _validate_entity_knocked_back_payload(payload_value)
		Type.TILE_MARKED:
			return _validate_tile_marked_payload(payload_value)
		Type.MARKED_TILE_DETONATED:
			return _validate_marked_tile_detonated_payload(payload_value)
		Type.ENEMY_WAITED:
			return _validate_enemy_waited_payload(payload_value)
		Type.LEVEL_VICTORY_REACHED:
			return _validate_level_victory_reached_payload(payload_value)
		Type.LEVEL_DEFEAT_REACHED:
			return _validate_level_defeat_reached_payload(payload_value)
		_:
			return _ok_result()


static func _validate_run_started_payload(payload_value: Dictionary) -> ActionResult:
	# root_seed is a full int64 carried as a decimal string (JSON-double-safe, mirroring
	# RunSnapshot/RunState encoding) — not a bounded integral payload.
	if not _has_decimal_string_payload(payload_value, &"root_seed"):
		return _error_result(&"invalid_event_payload", {"field": "root_seed"})
	if not _has_bool_payload(payload_value, &"is_manual_seed"):
		return _error_result(&"invalid_event_payload", {"field": "is_manual_seed"})
	if not _has_nonnegative_integral_payload(payload_value, &"node_count"):
		return _error_result(&"invalid_event_payload", {"field": "node_count"})
	return _ok_result()


static func _validate_route_advanced_payload(payload_value: Dictionary) -> ActionResult:
	# Route advance is a run-level SYSTEM transition. Node ids carry hyphens (RouteGenerator mints
	# "node-<depth>-<index>"), so id fields are validated as PLAIN non-empty strings / a plain
	# non-empty-string Array — NEVER via _is_lower_snake_id / _has_string_array_payload (both reject
	# hyphens). Only to_node_type is a lower_snake RouteNode.TYPE_* id.
	if not _has_nonempty_string_payload(payload_value, &"from_node_id"):
		return _error_result(&"invalid_event_payload", {"field": "from_node_id"})
	if not _has_nonempty_string_payload(payload_value, &"to_node_id"):
		return _error_result(&"invalid_event_payload", {"field": "to_node_id"})
	if not _has_lower_snake_payload(payload_value, &"to_node_type"):
		return _error_result(&"invalid_event_payload", {"field": "to_node_type"})
	if not _has_nonnegative_integral_payload(payload_value, &"to_node_depth"):
		return _error_result(&"invalid_event_payload", {"field": "to_node_depth"})
	if not _has_nonempty_string_payload(payload_value, &"cleared_node_id"):
		return _error_result(&"invalid_event_payload", {"field": "cleared_node_id"})
	# revealed_node_ids: a (possibly empty) Array of plain non-empty hyphen-tolerant node-id strings.
	if not _has_plain_string_array_payload(payload_value, &"revealed_node_ids", true):
		return _error_result(&"invalid_event_payload", {"field": "revealed_node_ids"})
	if _string_array_has_duplicates(payload_value.get("revealed_node_ids", [])):
		return _error_result(&"invalid_event_payload", {"field": "revealed_node_ids"})
	return _ok_result()


static func _validate_node_entered_payload(payload_value: Dictionary) -> ActionResult:
	# Node entry is a run-level SYSTEM transition (Story 4.4). node_id is the ORIGINAL route node id,
	# which carries hyphens (RouteGenerator mints "node-<depth>-<index>") -> validated as a PLAIN
	# non-empty string, NEVER via _has_lower_snake_payload (it rejects hyphens). node_type / recipe_id /
	# size_class / the DERIVED level_request_node_id are lower_snake. node_depth is non-negative integral.
	if not _has_nonempty_string_payload(payload_value, &"node_id"):
		return _error_result(&"invalid_event_payload", {"field": "node_id"})
	if not _has_lower_snake_payload(payload_value, &"node_type"):
		return _error_result(&"invalid_event_payload", {"field": "node_type"})
	if not _has_nonnegative_integral_payload(payload_value, &"node_depth"):
		return _error_result(&"invalid_event_payload", {"field": "node_depth"})
	if not _has_lower_snake_payload(payload_value, &"level_request_node_id"):
		return _error_result(&"invalid_event_payload", {"field": "level_request_node_id"})
	if not _has_lower_snake_payload(payload_value, &"recipe_id"):
		return _error_result(&"invalid_event_payload", {"field": "recipe_id"})
	if not _has_lower_snake_payload(payload_value, &"size_class"):
		return _error_result(&"invalid_event_payload", {"field": "size_class"})
	return _ok_result()


static func _validate_node_exited_payload(payload_value: Dictionary) -> ActionResult:
	# Node exit is a run-level SYSTEM transition (Story 4.4). node_id carries hyphens -> PLAIN non-empty
	# string. node_type is lower_snake; node_depth is non-negative integral; rewards_placeholder is bool.
	if not _has_nonempty_string_payload(payload_value, &"node_id"):
		return _error_result(&"invalid_event_payload", {"field": "node_id"})
	if not _has_lower_snake_payload(payload_value, &"node_type"):
		return _error_result(&"invalid_event_payload", {"field": "node_type"})
	if not _has_nonnegative_integral_payload(payload_value, &"node_depth"):
		return _error_result(&"invalid_event_payload", {"field": "node_depth"})
	if not _has_bool_payload(payload_value, &"rewards_placeholder"):
		return _error_result(&"invalid_event_payload", {"field": "rewards_placeholder"})
	return _ok_result()


static func _validate_route_sealed_payload(payload_value: Dictionary) -> ActionResult:
	# The door-sealed containment cue (Story 4.4). node_id (the sealed node) carries hyphens -> PLAIN
	# non-empty string. cue_id is lower_snake non-empty (the validator enforces the SHAPE; the exact
	# value door_sealed_placeholder is asserted in the command + tests).
	if not _has_nonempty_string_payload(payload_value, &"node_id"):
		return _error_result(&"invalid_event_payload", {"field": "node_id"})
	if not _has_lower_snake_payload(payload_value, &"cue_id"):
		return _error_result(&"invalid_event_payload", {"field": "cue_id"})
	return _ok_result()


static func _validate_node_placeholder_resolved_payload(payload_value: Dictionary) -> ActionResult:
	# Placeholder resolution is a run-level SYSTEM transition (Story 4.5). node_id is the ORIGINAL route
	# node id, which carries hyphens (RouteGenerator mints "node-<depth>-<index>") -> validated as a PLAIN
	# non-empty string, NEVER via _has_lower_snake_payload (it rejects hyphens). node_type (the actual
	# placeholder node type) is lower_snake; node_depth is non-negative integral; resolution is lower_snake
	# AND value-equal to the stable placeholder marker (mirroring level_victory_reached's outcome equality).
	if not _has_nonempty_string_payload(payload_value, &"node_id"):
		return _error_result(&"invalid_event_payload", {"field": "node_id"})
	if not _has_lower_snake_payload(payload_value, &"node_type"):
		return _error_result(&"invalid_event_payload", {"field": "node_type"})
	if not _has_nonnegative_integral_payload(payload_value, &"node_depth"):
		return _error_result(&"invalid_event_payload", {"field": "node_depth"})
	if not _has_lower_snake_payload(payload_value, &"resolution") \
			or String(payload_value.get("resolution")) != String(RESOLUTION_PLACEHOLDER):
		return _error_result(&"invalid_event_payload", {"field": "resolution"})
	return _ok_result()


static func _validate_run_completed_payload(payload_value: Dictionary) -> ActionResult:
	# The boss-placeholder run-END boundary (Story 4.5). outcome is lower_snake AND value-equal to the
	# stable boss-placeholder marker (mirroring _validate_level_victory_reached_payload's outcome ==
	# "victory" assertion). boss_node_id (the boss node) carries hyphens -> PLAIN non-empty string.
	# cleared_node_count is a non-negative integral: route.cleared_node_ids.size() AFTER the boss is cleared
	# — the count of nodes the player cleared on the traversed path (one per tier on the fixed-depth MVP
	# route), well under 2^53.
	if not _has_lower_snake_payload(payload_value, &"outcome") \
			or String(payload_value.get("outcome")) != String(RUN_COMPLETED_OUTCOME_BOSS_PLACEHOLDER):
		return _error_result(&"invalid_event_payload", {"field": "outcome"})
	if not _has_nonempty_string_payload(payload_value, &"boss_node_id"):
		return _error_result(&"invalid_event_payload", {"field": "boss_node_id"})
	if not _has_nonnegative_integral_payload(payload_value, &"cleared_node_count"):
		return _error_result(&"invalid_event_payload", {"field": "cleared_node_count"})
	return _ok_result()


static func _validate_item_gained_payload(payload_value: Dictionary) -> ActionResult:
	# A backpack item PICKUP record (Story 6.2). item_id is a Story-6.1 CONTENT id — lower_snake (no hyphens),
	# so it is validated via _has_lower_snake_payload (UNLIKE the hyphenated route node ids). category is
	# lower_snake AND in the allowlist (mirroring InventoryState.BACKPACK_CATEGORIES; the value sets are pinned
	# to match by test). backpack_size_after + slot_index are non-negative integral (small bounded counts).
	if not _has_lower_snake_payload(payload_value, &"item_id"):
		return _error_result(&"invalid_event_payload", {"field": "item_id"})
	if not _has_lower_snake_payload(payload_value, &"category") \
			or not ITEM_GAINED_CATEGORIES.has(StringName(String(payload_value.get("category")))):
		return _error_result(&"invalid_event_payload", {"field": "category"})
	if not _has_nonnegative_integral_payload(payload_value, &"backpack_size_after"):
		return _error_result(&"invalid_event_payload", {"field": "backpack_size_after"})
	if not _has_nonnegative_integral_payload(payload_value, &"slot_index"):
		return _error_result(&"invalid_event_payload", {"field": "slot_index"})
	return _ok_result()


static func _validate_reward_offered_payload(payload_value: Dictionary) -> ActionResult:
	# A deterministic reward-OFFER record (Story 6.3). table_id is a Story-6.1 content id -> lower_snake. roll +
	# draw_index are non-negative integral. offered_entries is a NON-EMPTY Array of {category, content_id} where
	# each category is lower_snake AND in the REWARD_CATEGORIES allowlist (the value sets are pinned to match
	# RewardTableDefinition.REWARD_CATEGORIES by test) and each content_id is lower_snake. A malformed entry, an
	# empty list, an off-allowlist category, or a non-lower_snake id is rejected per-field.
	if not _has_lower_snake_payload(payload_value, &"table_id"):
		return _error_result(&"invalid_event_payload", {"field": "table_id"})
	if not payload_value.has("offered_entries") or not payload_value.get("offered_entries") is Array:
		return _error_result(&"invalid_event_payload", {"field": "offered_entries"})
	var offered_entries: Array = payload_value.get("offered_entries")
	if offered_entries.is_empty():
		return _error_result(&"invalid_event_payload", {"field": "offered_entries"})
	for entry_value: Variant in offered_entries:
		if not entry_value is Dictionary:
			return _error_result(&"invalid_event_payload", {"field": "offered_entries"})
		var entry: Dictionary = entry_value
		if not _has_lower_snake_payload(entry, &"category") \
				or not REWARD_CATEGORIES.has(StringName(String(entry.get("category")))):
			return _error_result(&"invalid_event_payload", {"field": "offered_entries"})
		if not _has_lower_snake_payload(entry, &"content_id"):
			return _error_result(&"invalid_event_payload", {"field": "offered_entries"})
	if not _has_nonnegative_integral_payload(payload_value, &"roll"):
		return _error_result(&"invalid_event_payload", {"field": "roll"})
	if not _has_nonnegative_integral_payload(payload_value, &"draw_index"):
		return _error_result(&"invalid_event_payload", {"field": "draw_index"})
	return _ok_result()


static func _validate_reward_resolved_payload(payload_value: Dictionary) -> ActionResult:
	# A reward-RESOLVED record (Story 6.3). table_id + content_id are Story-6.1 content ids -> lower_snake. category
	# is lower_snake AND in the REWARD_CATEGORIES allowlist (adds gold/passive over the backpack set). A malformed
	# field is rejected per-field.
	if not _has_lower_snake_payload(payload_value, &"table_id"):
		return _error_result(&"invalid_event_payload", {"field": "table_id"})
	if not _has_lower_snake_payload(payload_value, &"category") \
			or not REWARD_CATEGORIES.has(StringName(String(payload_value.get("category")))):
		return _error_result(&"invalid_event_payload", {"field": "category"})
	if not _has_lower_snake_payload(payload_value, &"content_id"):
		return _error_result(&"invalid_event_payload", {"field": "content_id"})
	return _ok_result()


static func _validate_passive_consumed_payload(payload_value: Dictionary) -> ActionResult:
	# A passive-CONSUMED record (Story 6.5). passive_id is a Story-5.4 passive id and table_id is the offer's table
	# id — both Story-5.4/6.1 content ids -> lower_snake. A malformed/non-lower_snake/missing field is rejected
	# per-field (mirroring _validate_reward_resolved_payload).
	if not _has_lower_snake_payload(payload_value, &"passive_id"):
		return _error_result(&"invalid_event_payload", {"field": "passive_id"})
	if not _has_lower_snake_payload(payload_value, &"table_id"):
		return _error_result(&"invalid_event_payload", {"field": "table_id"})
	return _ok_result()


static func _validate_passive_destroyed_payload(payload_value: Dictionary) -> ActionResult:
	# A passive-DESTROYED record (Story 6.6). passive_id is a Story-5.4 passive id, table_id is the offer's table id,
	# outcome_id is the rolled Destroy outcome id — all lower_snake content ids. outcome_category is lower_snake AND
	# in the DESTROY_OUTCOME_CATEGORIES allowlist (the value set is pinned to match
	# DestroyOutcomeTableDefinition.DESTROY_OUTCOME_CATEGORIES by test — mirroring _validate_reward_offered_payload's
	# category-allowlist check). outcome_effect + explanation are non-empty strings (the Readability Rule). roll +
	# draw_index are non-negative integral (the draw provenance, mirroring reward_offered — Destroy DRAWS RNG). A
	# malformed/missing field is rejected per-field.
	if not _has_lower_snake_payload(payload_value, &"passive_id"):
		return _error_result(&"invalid_event_payload", {"field": "passive_id"})
	if not _has_lower_snake_payload(payload_value, &"table_id"):
		return _error_result(&"invalid_event_payload", {"field": "table_id"})
	if not _has_lower_snake_payload(payload_value, &"outcome_category") \
			or not DESTROY_OUTCOME_CATEGORIES.has(StringName(String(payload_value.get("outcome_category")))):
		return _error_result(&"invalid_event_payload", {"field": "outcome_category"})
	if not _has_lower_snake_payload(payload_value, &"outcome_id"):
		return _error_result(&"invalid_event_payload", {"field": "outcome_id"})
	if not _has_nonempty_string_payload(payload_value, &"outcome_effect"):
		return _error_result(&"invalid_event_payload", {"field": "outcome_effect"})
	if not _has_nonempty_string_payload(payload_value, &"explanation"):
		return _error_result(&"invalid_event_payload", {"field": "explanation"})
	if not _has_nonnegative_integral_payload(payload_value, &"roll"):
		return _error_result(&"invalid_event_payload", {"field": "roll"})
	if not _has_nonnegative_integral_payload(payload_value, &"draw_index"):
		return _error_result(&"invalid_event_payload", {"field": "draw_index"})
	return _ok_result()


static func _validate_item_consumed_payload(payload_value: Dictionary) -> ActionResult:
	# A backpack consumable USE record (Story 6.7). item_id is a Story-6.1 CONTENT id -> lower_snake (no hyphens),
	# validated via _has_lower_snake_payload (UNLIKE the hyphenated route node ids). outcome_effect + explanation are
	# the resolved ConsumableDefinition's effect marker + known result -> non-empty strings (the Readability Rule).
	# backpack_size_after + slot_index are non-negative integral (small bounded counts). UNLIKE passive_destroyed,
	# Use draws ZERO RNG, so there is NO roll/draw_index field (mirroring the deterministic item_gained shell). A
	# malformed/missing field is rejected per-field.
	if not _has_lower_snake_payload(payload_value, &"item_id"):
		return _error_result(&"invalid_event_payload", {"field": "item_id"})
	if not _has_nonempty_string_payload(payload_value, &"outcome_effect"):
		return _error_result(&"invalid_event_payload", {"field": "outcome_effect"})
	if not _has_nonempty_string_payload(payload_value, &"explanation"):
		return _error_result(&"invalid_event_payload", {"field": "explanation"})
	if not _has_nonnegative_integral_payload(payload_value, &"backpack_size_after"):
		return _error_result(&"invalid_event_payload", {"field": "backpack_size_after"})
	if not _has_nonnegative_integral_payload(payload_value, &"slot_index"):
		return _error_result(&"invalid_event_payload", {"field": "slot_index"})
	return _ok_result()


static func _validate_economy_changed_payload(payload_value: Dictionary) -> ActionResult:
	# A currency/healing-change record (Story 7.1). `reason` is the AC2 explanation-log reason -> a lower_snake marker
	# id (e.g. gold_reward_resolved). gold_before/gold_after + healing_before/healing_after are NON-NEGATIVE integral
	# (a wallet/charge count is never negative). gold_delta/healing_delta are SIGNED integral (a credit is positive, a
	# spend negative — so they are validated as integral, NOT non-negative). UNLIKE passive_destroyed there is NO
	# roll/draw_index (an economy change is a recorded amount, not a roll — the deterministic item_gained shell). A
	# malformed/missing field is rejected per-field. The before+delta==after arithmetic consistency is also enforced
	# (a fabricated/hand-edited payload whose after diverges from before+delta is rejected — the record must be honest).
	if not _has_lower_snake_payload(payload_value, &"reason"):
		return _error_result(&"invalid_event_payload", {"field": "reason"})
	if not _has_nonnegative_integral_payload(payload_value, &"gold_before"):
		return _error_result(&"invalid_event_payload", {"field": "gold_before"})
	if not _has_nonnegative_integral_payload(payload_value, &"gold_after"):
		return _error_result(&"invalid_event_payload", {"field": "gold_after"})
	if not _has_integral_payload(payload_value, &"gold_delta"):
		return _error_result(&"invalid_event_payload", {"field": "gold_delta"})
	if not _has_nonnegative_integral_payload(payload_value, &"healing_before"):
		return _error_result(&"invalid_event_payload", {"field": "healing_before"})
	if not _has_nonnegative_integral_payload(payload_value, &"healing_after"):
		return _error_result(&"invalid_event_payload", {"field": "healing_after"})
	if not _has_integral_payload(payload_value, &"healing_delta"):
		return _error_result(&"invalid_event_payload", {"field": "healing_delta"})
	# Arithmetic consistency (the record must be honest): before + delta == after for each of gold/healing.
	if int(payload_value.get("gold_before")) + int(payload_value.get("gold_delta")) != int(payload_value.get("gold_after")):
		return _error_result(&"invalid_event_payload", {"field": "gold_after"})
	if int(payload_value.get("healing_before")) + int(payload_value.get("healing_delta")) != int(payload_value.get("healing_after")):
		return _error_result(&"invalid_event_payload", {"field": "healing_after"})
	return _ok_result()


static func _validate_entity_moved_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_cell_payload(payload_value, &"from"):
		return _error_result(&"invalid_event_payload", {"field": "from"})
	if not _has_cell_payload(payload_value, &"to"):
		return _error_result(&"invalid_event_payload", {"field": "to"})
	if not payload_value.has("movement_cost") or not _is_integral_number(payload_value.get("movement_cost")):
		return _error_result(&"invalid_event_payload", {"field": "movement_cost"})
	if not payload_value.has("movement_budget") or not _is_integral_number(payload_value.get("movement_budget")):
		return _error_result(&"invalid_event_payload", {"field": "movement_budget"})

	var movement_cost: int = int(payload_value.get("movement_cost"))
	var movement_budget: int = int(payload_value.get("movement_budget"))
	if movement_cost <= 0:
		return _error_result(&"invalid_event_payload", {"field": "movement_cost"})
	if movement_budget <= 0:
		return _error_result(&"invalid_event_payload", {"field": "movement_budget"})
	if movement_cost > movement_budget:
		return _error_result(&"invalid_event_payload", {"field": "movement_cost"})

	return _ok_result()


static func _validate_visibility_updated_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_cell_payload(payload_value, &"origin"):
		return _error_result(&"invalid_event_payload", {"field": "origin"})
	if not payload_value.has("radius") or not _is_integral_number(payload_value.get("radius")):
		return _error_result(&"invalid_event_payload", {"field": "radius"})
	if int(payload_value.get("radius")) <= 0:
		return _error_result(&"invalid_event_payload", {"field": "radius"})
	if not _has_cell_array_payload(payload_value, &"visible_cells", false):
		return _error_result(&"invalid_event_payload", {"field": "visible_cells"})
	if not _has_cell_array_payload(payload_value, &"newly_explored_cells", true):
		return _error_result(&"invalid_event_payload", {"field": "newly_explored_cells"})
	if _cell_array_has_duplicates(payload_value.get("visible_cells", [])):
		return _error_result(&"invalid_event_payload", {"field": "visible_cells"})
	if _cell_array_has_duplicates(payload_value.get("newly_explored_cells", [])):
		return _error_result(&"invalid_event_payload", {"field": "newly_explored_cells"})

	return _ok_result()


static func _validate_entity_attacked_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_nonempty_string_payload(payload_value, &"actor_id"):
		return _error_result(&"invalid_event_payload", {"field": "actor_id"})
	if not _has_nonempty_string_payload(payload_value, &"target_entity_id"):
		return _error_result(&"invalid_event_payload", {"field": "target_entity_id"})
	if not _has_cell_payload(payload_value, &"target_cell"):
		return _error_result(&"invalid_event_payload", {"field": "target_cell"})
	if not _has_lower_snake_payload(payload_value, &"weapon_id"):
		return _error_result(&"invalid_event_payload", {"field": "weapon_id"})
	if not _has_positive_integral_payload(payload_value, &"expected_base_damage"):
		return _error_result(&"invalid_event_payload", {"field": "expected_base_damage"})
	if not _has_positive_integral_payload(payload_value, &"range"):
		return _error_result(&"invalid_event_payload", {"field": "range"})
	if not _has_positive_integral_payload(payload_value, &"distance"):
		return _error_result(&"invalid_event_payload", {"field": "distance"})
	if not _has_cell_array_payload(payload_value, &"line_cells", false):
		return _error_result(&"invalid_event_payload", {"field": "line_cells"})
	if not _has_cell_array_payload(payload_value, &"blocker_cells", true):
		return _error_result(&"invalid_event_payload", {"field": "blocker_cells"})
	if _cell_array_has_duplicates(payload_value.get("line_cells", [])):
		return _error_result(&"invalid_event_payload", {"field": "line_cells"})
	if _cell_array_has_duplicates(payload_value.get("blocker_cells", [])):
		return _error_result(&"invalid_event_payload", {"field": "blocker_cells"})
	if not _has_bool_payload(payload_value, &"blocker_ignored"):
		return _error_result(&"invalid_event_payload", {"field": "blocker_ignored"})
	if not payload_value.has("warnings") or not payload_value.get("warnings") is Array:
		return _error_result(&"invalid_event_payload", {"field": "warnings"})
	if not payload_value.has("effects") or not payload_value.get("effects") is Array:
		return _error_result(&"invalid_event_payload", {"field": "effects"})
	if not _has_nonempty_string_payload(payload_value, &"explanation"):
		return _error_result(&"invalid_event_payload", {"field": "explanation"})
	return _ok_result()


static func _validate_damage_applied_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_nonempty_string_payload(payload_value, &"target_entity_id"):
		return _error_result(&"invalid_event_payload", {"field": "target_entity_id"})
	if not _has_positive_integral_payload(payload_value, &"amount"):
		return _error_result(&"invalid_event_payload", {"field": "amount"})
	if not _has_positive_integral_payload(payload_value, &"final_damage"):
		return _error_result(&"invalid_event_payload", {"field": "final_damage"})
	if int(payload_value.get("final_damage")) != int(payload_value.get("amount")):
		return _error_result(&"invalid_event_payload", {"field": "final_damage"})
	if not _has_nonnegative_integral_payload(payload_value, &"hp_before"):
		return _error_result(&"invalid_event_payload", {"field": "hp_before"})
	if not _has_nonnegative_integral_payload(payload_value, &"hp_after"):
		return _error_result(&"invalid_event_payload", {"field": "hp_after"})
	if not _has_positive_integral_payload(payload_value, &"max_hp"):
		return _error_result(&"invalid_event_payload", {"field": "max_hp"})
	if int(payload_value.get("hp_before")) > int(payload_value.get("max_hp")):
		return _error_result(&"invalid_event_payload", {"field": "hp_before"})
	if int(payload_value.get("hp_after")) > int(payload_value.get("max_hp")):
		return _error_result(&"invalid_event_payload", {"field": "hp_after"})
	if not _has_lower_snake_payload(payload_value, &"weapon_id"):
		return _error_result(&"invalid_event_payload", {"field": "weapon_id"})
	if not _has_positive_integral_payload(payload_value, &"base_damage"):
		return _error_result(&"invalid_event_payload", {"field": "base_damage"})
	if not _has_nonnegative_integral_payload(payload_value, &"support_bonus_damage"):
		return _error_result(&"invalid_event_payload", {"field": "support_bonus_damage"})
	if not _has_nonnegative_integral_payload(payload_value, &"armor_reduction"):
		return _error_result(&"invalid_event_payload", {"field": "armor_reduction"})
	if not _has_bool_payload(payload_value, &"block_succeeded"):
		return _error_result(&"invalid_event_payload", {"field": "block_succeeded"})
	if not _has_lower_snake_payload(payload_value, &"damage_type"):
		return _error_result(&"invalid_event_payload", {"field": "damage_type"})
	if not payload_value.has("rng_draws") or not payload_value.get("rng_draws") is Array:
		return _error_result(&"invalid_event_payload", {"field": "rng_draws"})
	for draw_value: Variant in payload_value.get("rng_draws", []):
		if not draw_value is Dictionary or not _is_valid_rng_draw(draw_value):
			return _error_result(&"invalid_event_payload", {"field": "rng_draws"})
	return _ok_result()


static func _validate_status_effect_applied_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_nonempty_string_payload(payload_value, &"target_entity_id"):
		return _error_result(&"invalid_event_payload", {"field": "target_entity_id"})
	if not _has_lower_snake_payload(payload_value, &"effect_id"):
		return _error_result(&"invalid_event_payload", {"field": "effect_id"})
	if payload_value.has("weapon_id") and not _has_lower_snake_payload(payload_value, &"weapon_id"):
		return _error_result(&"invalid_event_payload", {"field": "weapon_id"})
	if payload_value.has("rng_draw"):
		var draw_value: Variant = payload_value.get("rng_draw")
		if not draw_value is Dictionary or not _is_valid_rng_draw(draw_value):
			return _error_result(&"invalid_event_payload", {"field": "rng_draw"})
	return _ok_result()


static func _validate_entity_knocked_back_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_nonempty_string_payload(payload_value, &"target_entity_id"):
		return _error_result(&"invalid_event_payload", {"field": "target_entity_id"})
	if not _has_cell_payload(payload_value, &"from"):
		return _error_result(&"invalid_event_payload", {"field": "from"})
	if not _has_cell_payload(payload_value, &"to"):
		return _error_result(&"invalid_event_payload", {"field": "to"})
	if not _has_lower_snake_payload(payload_value, &"weapon_id"):
		return _error_result(&"invalid_event_payload", {"field": "weapon_id"})
	if payload_value.has("source_cell") and not _has_cell_payload(payload_value, &"source_cell"):
		return _error_result(&"invalid_event_payload", {"field": "source_cell"})
	return _ok_result()


static func _validate_tile_marked_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_nonempty_string_payload(payload_value, &"target_entity_id"):
		return _error_result(&"invalid_event_payload", {"field": "target_entity_id"})
	if not _has_cell_payload(payload_value, &"marked_cell"):
		return _error_result(&"invalid_event_payload", {"field": "marked_cell"})
	if not _has_nonempty_string_payload(payload_value, &"telegraph_id"):
		return _error_result(&"invalid_event_payload", {"field": "telegraph_id"})
	if not _has_lower_snake_payload(payload_value, &"enemy_definition_id"):
		return _error_result(&"invalid_event_payload", {"field": "enemy_definition_id"})
	if not _has_positive_integral_payload(payload_value, &"created_turn_number"):
		return _error_result(&"invalid_event_payload", {"field": "created_turn_number"})
	if not _has_positive_integral_payload(payload_value, &"due_turn_number"):
		return _error_result(&"invalid_event_payload", {"field": "due_turn_number"})
	if int(payload_value.get("due_turn_number")) <= int(payload_value.get("created_turn_number")):
		return _error_result(&"invalid_event_payload", {"field": "due_turn_number"})
	if not _has_positive_integral_payload(payload_value, &"damage"):
		return _error_result(&"invalid_event_payload", {"field": "damage"})
	if not _has_lower_snake_payload(payload_value, &"damage_type"):
		return _error_result(&"invalid_event_payload", {"field": "damage_type"})
	if not _has_nonempty_string_payload(payload_value, &"explanation"):
		return _error_result(&"invalid_event_payload", {"field": "explanation"})
	return _ok_result()


static func _validate_marked_tile_detonated_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_nonempty_string_payload(payload_value, &"target_entity_id"):
		return _error_result(&"invalid_event_payload", {"field": "target_entity_id"})
	if not _has_cell_payload(payload_value, &"marked_cell"):
		return _error_result(&"invalid_event_payload", {"field": "marked_cell"})
	if not _has_nonempty_string_payload(payload_value, &"telegraph_id"):
		return _error_result(&"invalid_event_payload", {"field": "telegraph_id"})
	if not _has_lower_snake_payload(payload_value, &"outcome"):
		return _error_result(&"invalid_event_payload", {"field": "outcome"})
	var outcome: String = String(payload_value.get("outcome"))
	if outcome != "hit" and outcome != "avoided":
		return _error_result(&"invalid_event_payload", {"field": "outcome"})
	if not _has_positive_integral_payload(payload_value, &"damage"):
		return _error_result(&"invalid_event_payload", {"field": "damage"})
	if not _has_lower_snake_payload(payload_value, &"damage_type"):
		return _error_result(&"invalid_event_payload", {"field": "damage_type"})
	if not _has_nonempty_string_payload(payload_value, &"explanation"):
		return _error_result(&"invalid_event_payload", {"field": "explanation"})
	return _ok_result()


static func _validate_enemy_waited_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_lower_snake_payload(payload_value, &"reason"):
		return _error_result(&"invalid_event_payload", {"field": "reason"})
	if payload_value.has("enemy_definition_id") and not _has_lower_snake_payload(payload_value, &"enemy_definition_id"):
		return _error_result(&"invalid_event_payload", {"field": "enemy_definition_id"})
	if payload_value.has("action_id") and not _has_lower_snake_payload(payload_value, &"action_id"):
		return _error_result(&"invalid_event_payload", {"field": "action_id"})
	if payload_value.has("score") and not _is_integral_number(payload_value.get("score")):
		return _error_result(&"invalid_event_payload", {"field": "score"})
	if not payload_value.has("reasons") or not payload_value.get("reasons") is Array:
		return _error_result(&"invalid_event_payload", {"field": "reasons"})
	for reason_value: Variant in payload_value.get("reasons", []):
		if not (reason_value is String or reason_value is StringName):
			return _error_result(&"invalid_event_payload", {"field": "reasons"})
	if not _has_nonempty_string_payload(payload_value, &"explanation"):
		return _error_result(&"invalid_event_payload", {"field": "explanation"})
	return _ok_result()


static func _validate_level_victory_reached_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_lower_snake_payload(payload_value, &"outcome") or String(payload_value.get("outcome")) != "victory":
		return _error_result(&"invalid_event_payload", {"field": "outcome"})
	if not _has_positive_integral_payload(payload_value, &"living_player_count"):
		return _error_result(&"invalid_event_payload", {"field": "living_player_count"})
	if not _has_nonnegative_integral_payload(payload_value, &"remaining_enemy_count"):
		return _error_result(&"invalid_event_payload", {"field": "remaining_enemy_count"})
	if int(payload_value.get("remaining_enemy_count")) != 0:
		return _error_result(&"invalid_event_payload", {"field": "remaining_enemy_count"})
	if not _has_string_array_payload(payload_value, &"defeated_enemy_ids", true):
		return _error_result(&"invalid_event_payload", {"field": "defeated_enemy_ids"})
	if _string_array_has_duplicates(payload_value.get("defeated_enemy_ids", [])):
		return _error_result(&"invalid_event_payload", {"field": "defeated_enemy_ids"})
	if not _has_nonnegative_integral_payload(payload_value, &"cause_event_sequence_id"):
		return _error_result(&"invalid_event_payload", {"field": "cause_event_sequence_id"})
	if not _has_nonempty_string_payload(payload_value, &"explanation"):
		return _error_result(&"invalid_event_payload", {"field": "explanation"})
	return _ok_result()


static func _validate_level_defeat_reached_payload(payload_value: Dictionary) -> ActionResult:
	if not _has_lower_snake_payload(payload_value, &"outcome") or String(payload_value.get("outcome")) != "defeat":
		return _error_result(&"invalid_event_payload", {"field": "outcome"})
	if not _has_nonempty_string_payload(payload_value, &"defeated_player_id"):
		return _error_result(&"invalid_event_payload", {"field": "defeated_player_id"})
	if not _has_nonnegative_integral_payload(payload_value, &"cause_event_sequence_id"):
		return _error_result(&"invalid_event_payload", {"field": "cause_event_sequence_id"})
	if not _has_lower_snake_payload(payload_value, &"cause_event_id"):
		return _error_result(&"invalid_event_payload", {"field": "cause_event_id"})
	if not _has_string_payload(payload_value, &"source_entity_id"):
		return _error_result(&"invalid_event_payload", {"field": "source_entity_id"})
	var source_entity_id: String = String(payload_value.get("source_entity_id"))
	if not source_entity_id.is_empty() and not _is_lower_snake_id(source_entity_id):
		return _error_result(&"invalid_event_payload", {"field": "source_entity_id"})
	if not _has_lower_snake_payload(payload_value, &"damage_type"):
		return _error_result(&"invalid_event_payload", {"field": "damage_type"})
	if not _has_nonnegative_integral_payload(payload_value, &"final_damage"):
		return _error_result(&"invalid_event_payload", {"field": "final_damage"})
	if not _has_nonempty_string_payload(payload_value, &"explanation"):
		return _error_result(&"invalid_event_payload", {"field": "explanation"})
	return _ok_result()


static func _has_cell_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var cell_value: Variant = payload_value.get(String(field_name))
	if not cell_value is Dictionary:
		return false
	var cell_data: Dictionary = cell_value
	return (
		cell_data.has("x")
		and cell_data.has("y")
		and _is_integral_number(cell_data.get("x"))
		and _is_integral_number(cell_data.get("y"))
	)


static func _has_cell_array_payload(payload_value: Dictionary, field_name: StringName, allow_empty: bool) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var cells_value: Variant = payload_value.get(String(field_name))
	if not cells_value is Array:
		return false
	var cells: Array = cells_value
	if cells.is_empty() and not allow_empty:
		return false
	for cell_value: Variant in cells:
		if not cell_value is Dictionary:
			return false
		var cell_data: Dictionary = cell_value
		if not (
			cell_data.has("x")
			and cell_data.has("y")
			and _is_integral_number(cell_data.get("x"))
			and _is_integral_number(cell_data.get("y"))
		):
			return false
	return true


static func _cell_array_has_duplicates(cells_value: Variant) -> bool:
	if not cells_value is Array:
		return true
	var seen: Dictionary = {}
	for cell_value: Variant in cells_value:
		if not cell_value is Dictionary:
			return true
		var cell_data: Dictionary = cell_value
		var key: String = "%s,%s" % [int(cell_data.get("x", 0)), int(cell_data.get("y", 0))]
		if seen.has(key):
			return true
		seen[key] = true
	return false


static func _has_nonempty_string_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var value: Variant = payload_value.get(String(field_name))
	return (value is String or value is StringName) and not String(value).is_empty()


static func _has_string_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var value: Variant = payload_value.get(String(field_name))
	return value is String or value is StringName


static func _has_lower_snake_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	if not _has_nonempty_string_payload(payload_value, field_name):
		return false
	return _is_lower_snake_id(String(payload_value.get(String(field_name))))


static func _has_bool_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	return payload_value.has(String(field_name)) and typeof(payload_value.get(String(field_name))) == TYPE_BOOL


# A field carried as a decimal-string-encoded integer (the int64-safe wire form for seeds). Used ONLY by
# _validate_run_started_payload for run_started.root_seed (grep-confirmed single caller), so tightening it
# regresses no other event. Beyond accepting a String/StringName that is_valid_int(), it now ALSO enforces
# the int64 lossless round-trip (the Story 3.7 idiom ported from ManualSeedLoader): String.to_int() saturates
# an over-max-int64 string to max-int64 and WRAPS a max-int64+1 string into the negative range, so an
# out-of-int64-range decimal string would otherwise pass is_valid_int() yet silently map to a wrong value.
# Requiring _canonical_decimal_string(text) == str(text.to_int()) REJECTS such a hand-edited/foreign payload
# while still accepting the benign representational differences is_valid_int() tolerates (a leading "+",
# surplus leading zeros, a signed zero). The live emit path encodes root_seed via str(run.root_seed) (always
# in-range), so this hardens the VALIDATOR against malformed payloads without changing any emitted event.
static func _has_decimal_string_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var value: Variant = payload_value.get(String(field_name))
	if not (value is String or value is StringName):
		return false
	var text: String = String(value)
	if not text.is_valid_int():
		return false
	return _decimal_string_round_trips_losslessly(text, text.to_int())


# Int64-string lossless check (ported as a static helper from ManualSeedLoader._decimal_string_round_trips_
# losslessly, kept LOCAL to domain_event.gd to avoid a new cross-script dependency — _has_decimal_string_
# payload is static so the port must be static too). Did String.to_int() preserve the full magnitude of the
# is_valid_int-accepted decimal string `text`? Compare a canonicalized form of the input to str(parsed_value):
# a mismatch means the value did not round-trip (out of int64 range) and must be rejected.
static func _decimal_string_round_trips_losslessly(text: String, parsed_value: int) -> bool:
	return _canonical_decimal_string(text) == str(parsed_value)


# Canonicalize an is_valid_int-accepted decimal string to the same form str(int) produces: drop a single
# leading "+"/"-" sign, strip surplus leading zeros (keep one digit), and treat "-0"/"+0"/"0" as "0". Ported
# (static) from ManualSeedLoader._canonical_decimal_string.
static func _canonical_decimal_string(text: String) -> String:
	var sign_prefix: String = ""
	var body: String = text
	if body.begins_with("+"):
		body = body.substr(1)
	elif body.begins_with("-"):
		sign_prefix = "-"
		body = body.substr(1)
	while body.length() > 1 and body.begins_with("0"):
		body = body.substr(1)
	if body == "0":
		# A signed zero ("-0"/"+0") and "0" all canonicalize to the unsigned "0" str(0) produces.
		sign_prefix = ""
	return sign_prefix + body


static func _has_positive_integral_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var value: Variant = payload_value.get(String(field_name))
	return _is_integral_number(value) and int(value) > 0


static func _has_nonnegative_integral_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var value: Variant = payload_value.get(String(field_name))
	return _is_integral_number(value) and int(value) >= 0


# A SIGNED integral payload field (Story 7.1 — the economy_changed gold_delta/healing_delta, where a credit is
# positive and a spend negative). Unlike _has_nonnegative_integral_payload it imposes no sign constraint; it only
# requires the field to be present and integral (int or integral-float, the JSON-safe forms).
static func _has_integral_payload(payload_value: Dictionary, field_name: StringName) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	return _is_integral_number(payload_value.get(String(field_name)))


static func _has_string_array_payload(payload_value: Dictionary, field_name: StringName, allow_empty: bool) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var values: Variant = payload_value.get(String(field_name))
	if not values is Array:
		return false
	var string_values: Array = values
	if string_values.is_empty() and not allow_empty:
		return false
	for value: Variant in string_values:
		if not (value is String or value is StringName):
			return false
		var text: String = String(value)
		if text.is_empty() or not _is_lower_snake_id(text):
			return false
	return true


# A (possibly empty) Array of plain NON-EMPTY strings WITHOUT the lower_snake constraint — for
# node-id lists that carry hyphens (e.g. "node-1-0"). Sibling of _has_string_array_payload, which
# enforces lower_snake and therefore rejects hyphenated ids.
static func _has_plain_string_array_payload(payload_value: Dictionary, field_name: StringName, allow_empty: bool) -> bool:
	if not payload_value.has(String(field_name)):
		return false
	var values: Variant = payload_value.get(String(field_name))
	if not values is Array:
		return false
	var string_values: Array = values
	if string_values.is_empty() and not allow_empty:
		return false
	for value: Variant in string_values:
		if not (value is String or value is StringName):
			return false
		if String(value).is_empty():
			return false
	return true


static func _string_array_has_duplicates(values: Variant) -> bool:
	if not values is Array:
		return true
	var seen: Dictionary = {}
	for value: Variant in values:
		var text: String = String(value)
		if seen.has(text):
			return true
		seen[text] = true
	return false


static func _is_valid_rng_draw(draw_value: Dictionary) -> bool:
	if not _has_lower_snake_payload(draw_value, &"stream_name"):
		return false
	if String(draw_value.get("stream_name")) != "combat":
		return false
	if not _has_nonnegative_integral_payload(draw_value, &"draw_index"):
		return false
	if not draw_value.has("roll_value") or not _is_numeric(draw_value.get("roll_value")):
		return false
	if not draw_value.has("threshold") or not _is_numeric(draw_value.get("threshold")):
		return false
	if not _has_lower_snake_payload(draw_value, &"effect_id"):
		return false
	if not _has_bool_payload(draw_value, &"succeeded"):
		return false
	return true


static func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


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


static func _cell_payload(cell: Vector2i) -> Dictionary:
	return {
		"x": cell.x,
		"y": cell.y
	}


static func _cell_array_payload(cells: Array) -> Array[Dictionary]:
	var sorted_cells: Array[Vector2i] = []
	for cell_value: Variant in cells:
		if cell_value is Vector2i:
			sorted_cells.append(cell_value)
	sorted_cells.sort_custom(_sort_cells_by_position)
	var result: Array[Dictionary] = []
	for cell: Vector2i in sorted_cells:
		result.append(_cell_payload(cell))
	return result


static func _string_array_payload(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		if value is String or value is StringName:
			result.append(String(value))
	result.sort()
	return result


static func id_for_type(type_value: int) -> StringName:
	match type_value:
		Type.RUN_STARTED:
			return EVENT_ID_RUN_STARTED
		Type.BOARD_CREATED:
			return EVENT_ID_BOARD_CREATED
		Type.RNG_STREAM_ADVANCED:
			return EVENT_ID_RNG_STREAM_ADVANCED
		Type.COMMAND_REJECTED:
			return EVENT_ID_COMMAND_REJECTED
		Type.ENTITY_MOVED:
			return EVENT_ID_ENTITY_MOVED
		Type.VISIBILITY_UPDATED:
			return EVENT_ID_VISIBILITY_UPDATED
		Type.ENTITY_ATTACKED:
			return EVENT_ID_ENTITY_ATTACKED
		Type.DAMAGE_APPLIED:
			return EVENT_ID_DAMAGE_APPLIED
		Type.STATUS_EFFECT_APPLIED:
			return EVENT_ID_STATUS_EFFECT_APPLIED
		Type.ENTITY_KNOCKED_BACK:
			return EVENT_ID_ENTITY_KNOCKED_BACK
		Type.TILE_MARKED:
			return EVENT_ID_TILE_MARKED
		Type.MARKED_TILE_DETONATED:
			return EVENT_ID_MARKED_TILE_DETONATED
		Type.ENEMY_WAITED:
			return EVENT_ID_ENEMY_WAITED
		Type.LEVEL_VICTORY_REACHED:
			return EVENT_ID_LEVEL_VICTORY_REACHED
		Type.LEVEL_DEFEAT_REACHED:
			return EVENT_ID_LEVEL_DEFEAT_REACHED
		Type.ROUTE_ADVANCED:
			return EVENT_ID_ROUTE_ADVANCED
		Type.NODE_ENTERED:
			return EVENT_ID_NODE_ENTERED
		Type.NODE_EXITED:
			return EVENT_ID_NODE_EXITED
		Type.ROUTE_SEALED:
			return EVENT_ID_ROUTE_SEALED
		Type.NODE_PLACEHOLDER_RESOLVED:
			return EVENT_ID_NODE_PLACEHOLDER_RESOLVED
		Type.RUN_COMPLETED:
			return EVENT_ID_RUN_COMPLETED
		Type.ITEM_GAINED:
			return EVENT_ID_ITEM_GAINED
		Type.REWARD_OFFERED:
			return EVENT_ID_REWARD_OFFERED
		Type.REWARD_RESOLVED:
			return EVENT_ID_REWARD_RESOLVED
		Type.PASSIVE_CONSUMED:
			return EVENT_ID_PASSIVE_CONSUMED
		Type.PASSIVE_DESTROYED:
			return EVENT_ID_PASSIVE_DESTROYED
		Type.ITEM_CONSUMED:
			return EVENT_ID_ITEM_CONSUMED
		Type.ECONOMY_CHANGED:
			return EVENT_ID_ECONOMY_CHANGED
		_:
			return EVENT_ID_UNKNOWN


static func type_for_id(event_id: StringName) -> int:
	match event_id:
		EVENT_ID_RUN_STARTED:
			return Type.RUN_STARTED
		EVENT_ID_BOARD_CREATED:
			return Type.BOARD_CREATED
		EVENT_ID_RNG_STREAM_ADVANCED:
			return Type.RNG_STREAM_ADVANCED
		EVENT_ID_COMMAND_REJECTED:
			return Type.COMMAND_REJECTED
		EVENT_ID_ENTITY_MOVED:
			return Type.ENTITY_MOVED
		EVENT_ID_VISIBILITY_UPDATED:
			return Type.VISIBILITY_UPDATED
		EVENT_ID_ENTITY_ATTACKED:
			return Type.ENTITY_ATTACKED
		EVENT_ID_DAMAGE_APPLIED:
			return Type.DAMAGE_APPLIED
		EVENT_ID_STATUS_EFFECT_APPLIED:
			return Type.STATUS_EFFECT_APPLIED
		EVENT_ID_ENTITY_KNOCKED_BACK:
			return Type.ENTITY_KNOCKED_BACK
		EVENT_ID_TILE_MARKED:
			return Type.TILE_MARKED
		EVENT_ID_MARKED_TILE_DETONATED:
			return Type.MARKED_TILE_DETONATED
		EVENT_ID_ENEMY_WAITED:
			return Type.ENEMY_WAITED
		EVENT_ID_LEVEL_VICTORY_REACHED:
			return Type.LEVEL_VICTORY_REACHED
		EVENT_ID_LEVEL_DEFEAT_REACHED:
			return Type.LEVEL_DEFEAT_REACHED
		EVENT_ID_ROUTE_ADVANCED:
			return Type.ROUTE_ADVANCED
		EVENT_ID_NODE_ENTERED:
			return Type.NODE_ENTERED
		EVENT_ID_NODE_EXITED:
			return Type.NODE_EXITED
		EVENT_ID_ROUTE_SEALED:
			return Type.ROUTE_SEALED
		EVENT_ID_NODE_PLACEHOLDER_RESOLVED:
			return Type.NODE_PLACEHOLDER_RESOLVED
		EVENT_ID_RUN_COMPLETED:
			return Type.RUN_COMPLETED
		EVENT_ID_ITEM_GAINED:
			return Type.ITEM_GAINED
		EVENT_ID_REWARD_OFFERED:
			return Type.REWARD_OFFERED
		EVENT_ID_REWARD_RESOLVED:
			return Type.REWARD_RESOLVED
		EVENT_ID_PASSIVE_CONSUMED:
			return Type.PASSIVE_CONSUMED
		EVENT_ID_PASSIVE_DESTROYED:
			return Type.PASSIVE_DESTROYED
		EVENT_ID_ITEM_CONSUMED:
			return Type.ITEM_CONSUMED
		EVENT_ID_ECONOMY_CHANGED:
			return Type.ECONOMY_CHANGED
		_:
			return Type.UNKNOWN


static func _event_requires_actor(event_type_value: int) -> bool:
	return (
		event_type_value == Type.ENTITY_MOVED
		or event_type_value == Type.VISIBILITY_UPDATED
		or event_type_value == Type.ENTITY_ATTACKED
		or event_type_value == Type.DAMAGE_APPLIED
		or event_type_value == Type.STATUS_EFFECT_APPLIED
		or event_type_value == Type.ENTITY_KNOCKED_BACK
		or event_type_value == Type.TILE_MARKED
		or event_type_value == Type.MARKED_TILE_DETONATED
		or event_type_value == Type.ENEMY_WAITED
	)


static func _sort_cells_by_position(first: Vector2i, second: Vector2i) -> bool:
	if first.y == second.y:
		return first.x < second.x
	return first.y < second.y
