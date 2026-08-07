class_name TacticalTelegraphOverlay
extends RefCounted

# Story 15.3 (AC1/AC2 — the F5 fix) — the PURE, SCENE-FREE PERSISTENT-TELEGRAPH projection seam. Given the pinned VM
# `event_log_summary` slot (the CombatExplanationLog entries the presenter sourced from the bound session — the FULL
# accumulated fight log), it returns the SET of currently-ACTIVE marked cells: a `tile_marked` whose `telegraph_id` has
# NO matching `marked_tile_detonated`. The presenter draws a persistent, non-color SHAPE/glyph telegraph on each active
# cell every render (mark -> resolution), so a marked detonation is a danger the player can SEE and dodge rather than
# one that happens to them.
#
# It reads ONLY the pinned VM `event_log_summary` slot — NO new board-VM key, NO new domain query (the mark/detonation
# events were already emitted + summarized; the domain `pending_telegraphs` state is deliberately NOT surfaced). It
# mutates NOTHING (the input is never written) and draws ZERO RNG.
#
# Kind-agnostic ON PURPOSE: it keys on the `tile_marked` / `marked_tile_detonated` event ids + the `telegraph_id`
# pairing, so it covers the ash-seer mark (KIND_ASH_SEER_MARK) AND the boss telegraph (KIND_LARVAL_AVATAR_TELEGRAPH)
# for free — never special-case a kind.
#
# Pairing: a mark is ACTIVE from its `tile_marked` until it is CLEARED — either the matching `marked_tile_detonated`
# with the SAME `telegraph_id` (hit OR avoided — the mark resolved), OR the death of its SOURCE entity (a
# `damage_applied` with `hp_after == 0` for the marking enemy). Both event payloads carry `telegraph_id`, so the
# detonation pairing needs no turn/window assumption (a seer mark is due created_turn + 1, but the projection never
# assumes it). The source-death clear is the AC1 "or is cancelled" case: a dead enemy never detonates (the enemy AI
# returns early on `is_dead()`, so no marked_tile_detonated is ever emitted), so killing the seer BEFORE its due turn
# removes the danger — the telegraph must clear rather than lie about a blast that can no longer happen.

# The EXACT key set of each active-mark entry (the exact-key discipline — a key never silently appears/vanishes; a
# test pins it).
const MARK_KEYS: Array[String] = [
	"cell",
	"telegraph_id"
]

# The CombatExplanationLog event ids the projection pairs (plain strings — the seam reads the sanitized VM, no
# cross-script const dependency, matching TacticalCombatFeedback).
const EVENT_ID_TILE_MARKED := "tile_marked"
const EVENT_ID_MARKED_TILE_DETONATED := "marked_tile_detonated"
const EVENT_ID_DAMAGE_APPLIED := "damage_applied"


# Project the SET of currently-active marked cells from the full VM `event_log_summary`. Order is first-appearance
# (the tile_marked iteration order); each telegraph_id surfaces at most once (a telegraph_id marks exactly once). An
# empty / all-cleared log yields an empty array. A malformed entry (missing telegraph_id or unresolvable cell) is
# skipped — a safe no-op, never a fabricated cell.
static func active_marks(event_log_summary: Array) -> Array[Dictionary]:
	# First pass: the telegraph_ids RESOLVED by a marked_tile_detonated (hit or avoided), and the entity_ids that DIED
	# (a damage_applied with hp_after == 0). A mark clears when its telegraph resolves OR its SOURCE dies.
	var resolved_ids: Dictionary = {}
	var dead_entity_ids: Dictionary = {}
	for entry_value: Variant in event_log_summary:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var event_id: String = String(entry.get("event_id", ""))
		var details: Dictionary = _dict(entry.get("details", {}))
		if event_id == EVENT_ID_MARKED_TILE_DETONATED:
			var resolved_telegraph_id: String = String(details.get("telegraph_id", ""))
			if not resolved_telegraph_id.is_empty():
				resolved_ids[resolved_telegraph_id] = true
		elif event_id == EVENT_ID_DAMAGE_APPLIED:
			# hp_after == 0 is the death signal (Story 14.1 — no separate death event). Default to a non-zero sentinel
			# so a payload that omits hp_after is NOT read as a death.
			if int(details.get("hp_after", -1)) == 0:
				var victim_id: String = String(details.get("target_entity_id", ""))
				if not victim_id.is_empty():
					dead_entity_ids[victim_id] = true

	# Second pass: a tile_marked whose telegraph_id has NO matching detonation, whose SOURCE is not dead, and which
	# carries a resolvable cell, is ACTIVE.
	var active: Array[Dictionary] = []
	var seen_ids: Dictionary = {}
	for entry_value: Variant in event_log_summary:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if String(entry.get("event_id", "")) != EVENT_ID_TILE_MARKED:
			continue
		var details: Dictionary = _dict(entry.get("details", {}))
		var telegraph_id: String = String(details.get("telegraph_id", ""))
		if telegraph_id.is_empty() or resolved_ids.has(telegraph_id) or seen_ids.has(telegraph_id):
			continue
		# The marking enemy: the explicit `source_entity_id`, falling back to the entry actor_id. A dead source cancels
		# the mark (the danger can no longer detonate).
		var source_id: String = String(details.get("source_entity_id", entry.get("actor_id", "")))
		if not source_id.is_empty() and dead_entity_ids.has(source_id):
			continue
		var cell: Variant = _cell_or_null(details.get("marked_cell"))
		if cell == null:
			continue
		seen_ids[telegraph_id] = true
		active.append({
			"cell": cell,
			"telegraph_id": telegraph_id
		})
	return active


static func _cell_or_null(value: Variant) -> Variant:
	if value is Vector2i:
		var vector: Vector2i = value
		return {"x": vector.x, "y": vector.y}
	if value is Dictionary:
		var data: Dictionary = value
		if (data.has("x") or data.has(&"x")) and (data.has("y") or data.has(&"y")):
			return {"x": _num(data, "x"), "y": _num(data, "y")}
	return null


static func _num(data: Dictionary, key: String) -> int:
	if data.has(key):
		return int(data[key])
	if data.has(StringName(key)):
		return int(data[StringName(key)])
	return 0


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
