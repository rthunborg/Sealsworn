class_name TacticalCombatFeedback
extends RefCounted

# Story 14.3 (AC2/AC3 — the F8 fix) — the PURE, SCENE-FREE combat-ANIMATION PLAN seam. Given the pinned VM
# `event_log_summary` slot (the CombatExplanationLog entries the presenter sourced from the bound session), the id of
# the last-animated sequence, and the VM `occupants` array (for entity_id -> current cell), it decides WHAT to animate
# for the events NEWER than `since_sequence_id` and returns a render-ready plan: the moves to slide, the hits to
# flash, the deaths to fade into the corpse decal, and the telegraphs to pulse.
#
# It reads ONLY the pinned VM slots `event_log_summary` + `occupants` (no new board-VM key, no new domain query — the
# events were already emitted + summarized). It mutates NOTHING (the input is never written) and draws ZERO RNG. The
# presenter is a thin Control that plays a bounded, self-terminating tween for each plan entry; the WHAT-animates and
# WHICH-events-are-NEW DECISION lives here and is unit-tested (the scene tweens are verified by construction).
#
# LOAD-BEARING — death detection: there is NO separate death event. A death is a `damage_applied` entry whose
# `details.hp_after == 0` (Story 14.1 folds the corpse-clear into the 0-HP damage apply). So a damage entry is
# classified as BOTH a hit AND (when hp_after == 0) a death.
#
# LOAD-BEARING — cell resolution: the `damage_applied` payload carries the victim id + HP but NO cell. The victim
# cell is resolved from the VM `occupants` (entity_id -> position). A dead victim is STILL an occupant at its death
# cell (Story 14.1: is_dead == true), so the death cell resolves too. If the id is absent from occupants (fog / edge
# case) NO hit/death is emitted for it — a safe no-op, never a fabricated cell.
#
# `since_sequence_id` (presenter state, reset on bind) is what makes each event animate EXACTLY once: a batch at/above
# `since_sequence_id` re-animates nothing; `last_sequence_id` is the high-water mark the presenter advances to.

# The EXACT key set of plan() (the exact-key discipline — a key never silently appears/vanishes; a test pins it).
const PLAN_KEYS: Array[String] = [
	"moves",
	"hits",
	"deaths",
	"telegraphs",
	"last_sequence_id"
]

# The CombatExplanationLog event ids the plan reacts to (plain strings — the seam reads the sanitized VM, no
# cross-script const dependency). A `damage_applied` is a hit (and a death when hp_after == 0); a move is a slide; a
# tile_marked / marked_tile_detonated is a telegraph pulse.
const EVENT_ID_ENTITY_MOVED := "entity_moved"
const EVENT_ID_DAMAGE_APPLIED := "damage_applied"
const EVENT_ID_TILE_MARKED := "tile_marked"
const EVENT_ID_MARKED_TILE_DETONATED := "marked_tile_detonated"


# Project the animation plan for the events NEWER than `since_sequence_id`. An empty log, or a `since_sequence_id`
# at/above the batch max, yields the empty plan (no moves/hits/deaths/telegraphs) so the presenter animates nothing.
static func plan(event_log_summary: Array, since_sequence_id: int, occupants: Array) -> Dictionary:
	var moves: Array[Dictionary] = []
	var hits: Array[Dictionary] = []
	var deaths: Array[Dictionary] = []
	var telegraphs: Array[Dictionary] = []
	var last_sequence_id: int = since_sequence_id
	var cell_by_id: Dictionary = _occupant_cells(occupants)

	for entry_value: Variant in event_log_summary:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		var sequence_id: int = int(entry.get("sequence_id", 0))
		# Track the high-water mark over ALL entries so the presenter advances past benign (non-animated) events too.
		last_sequence_id = maxi(last_sequence_id, sequence_id)
		if sequence_id <= since_sequence_id:
			continue
		var event_id: String = String(entry.get("event_id", ""))
		var details: Dictionary = _dict(entry.get("details", {}))
		match event_id:
			EVENT_ID_ENTITY_MOVED:
				var from_cell: Variant = _cell_or_null(details.get("from"))
				var to_cell: Variant = _cell_or_null(details.get("to"))
				if from_cell != null and to_cell != null:
					moves.append({
						"actor_id": String(entry.get("actor_id", "")),
						"from": from_cell,
						"to": to_cell
					})
			EVENT_ID_DAMAGE_APPLIED:
				var target_id: String = String(details.get("target_entity_id", ""))
				# Resolve the victim cell from occupants. Absent id -> no hit/death (safe no-op, never fabricated).
				if not cell_by_id.has(target_id):
					continue
				var cell: Dictionary = cell_by_id[target_id]
				var amount: int = int(details.get("final_damage", details.get("amount", 0)))
				hits.append({
					"cell": cell.duplicate(),
					"target_id": target_id,
					"amount": amount
				})
				# A death is a damage entry whose hp_after == 0 (no separate death event). Default hp_after to a
				# non-zero sentinel so a payload that omits it is NOT mistaken for a death.
				if int(details.get("hp_after", -1)) == 0:
					deaths.append({
						"cell": cell.duplicate(),
						"entity_id": target_id
					})
			EVENT_ID_TILE_MARKED:
				var marked: Variant = _cell_or_null(details.get("marked_cell"))
				if marked != null:
					telegraphs.append({"cell": marked})
			EVENT_ID_MARKED_TILE_DETONATED:
				var detonated: Variant = _cell_or_null(details.get("marked_cell"))
				if detonated != null:
					telegraphs.append({"cell": detonated})

	return {
		"moves": moves,
		"hits": hits,
		"deaths": deaths,
		"telegraphs": telegraphs,
		"last_sequence_id": last_sequence_id
	}


# Whether a plan carries any animation entry (the presenter gates the tweens + the last-sequence advance on this).
static func has_feedback(plan_dict: Dictionary) -> bool:
	return (
		not (_array(plan_dict.get("moves", [])).is_empty())
		or not (_array(plan_dict.get("hits", [])).is_empty())
		or not (_array(plan_dict.get("deaths", [])).is_empty())
		or not (_array(plan_dict.get("telegraphs", [])).is_empty())
	)


# Build an entity_id -> {x,y} cell map from the VM occupants (each occupant carries `entity_id` + `position`). A dead
# occupant is included (Story 14.1 keeps a corpse readable at its death cell), so a death cell resolves.
static func _occupant_cells(occupants: Array) -> Dictionary:
	var result: Dictionary = {}
	for occupant_value: Variant in occupants:
		if not occupant_value is Dictionary:
			continue
		var occupant: Dictionary = occupant_value
		var entity_id: String = String(occupant.get("entity_id", ""))
		if entity_id.is_empty():
			continue
		var cell: Variant = _cell_or_null(occupant.get("position"))
		if cell != null:
			result[entity_id] = cell
	return result


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


static func _array(value: Variant) -> Array:
	return value if value is Array else []


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
