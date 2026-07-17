class_name TacticalCombatLogView
extends RefCounted

# Story 14.3 (AC1/AC3 — the F6/F7 fix) — the PURE, SCENE-FREE in-combat LOG-REGION projection seam. Given a board
# VM read (TacticalBoardViewModel.to_dictionary()), it projects the render-ready log content the presenter draws into
# the `log_or_outcome` region: the per-action display lines (tail-limited to the last MAX_LINES) and the structured
# damage numbers extracted from the damage events.
#
# It reads ONLY the pinned VM slot `event_log_summary` (the CombatExplanationLog entries the presenter sourced from
# the bound session's `event_log()` in render() — Task 1). The `event_log_summary` slot is an EXISTING pinned VM key;
# this seam adds NO new board-VM key and invents NO new domain query. It mutates NOTHING (the input dict is never
# written) and draws ZERO RNG. The presenter is a thin Control that renders this output; the WHAT-lines / WHICH-damage
# DECISION lives here and is unit-tested.
#
# The SOURCE of truth is the domain events the session accumulated (via `event_log()`); CombatExplanationLog is a
# stateless event->line transform, NOT a stored authority. This seam does NOT read a presentation/combat log as
# source truth and does NOT build the deferred run-level event store (it only formats the ephemeral session log the
# VM already carries).
#
# NFR9 (accessibility): the log line is an inherently non-color text channel; the damage number is text. A hit's
# legibility survives with color removed (the line + the number) and with audio off (no audio dependency).

# The EXACT key set of from_board_vm() (the exact-key discipline — a key never silently appears/vanishes; a test pins it).
const VIEW_KEYS: Array[String] = [
	"lines",
	"damage_numbers",
	"entry_count",
	"has_entries"
]

# The EXACT key set of every damage-number entry (pinned by the seam test).
const DAMAGE_NUMBER_KEYS: Array[String] = [
	"target_entity_id",
	"amount",
	"hp_before",
	"hp_after",
	"max_hp",
	"text"
]

# The CombatExplanationLog event id for a damage event (a hit / DoT / lethal blow). The only entry kind that yields a
# damage number. Kept as a plain string to avoid a cross-script const dependency (the seam reads the sanitized VM).
const EVENT_ID_DAMAGE_APPLIED := "damage_applied"

# The tail-limit for the small `log_or_outcome` region — the newest MAX_LINES entries (newest last) so the region
# never overflows on a long fight. Overridable via options["max_lines"] for a caller with a taller region.
const MAX_LINES: int = 8


# Project the in-combat log region from the pinned VM `event_log_summary` slot. An empty / absent slot projects the
# empty view (has_entries == false, entry_count == 0, no lines) so the presenter renders the honest "no events yet"
# state, never a fabricated line.
static func from_board_vm(board_vm: Dictionary, options: Dictionary = {}) -> Dictionary:
	var summary: Array = _array(board_vm.get("event_log_summary", []))
	var entry_count: int = summary.size()
	var max_lines: int = maxi(1, int(options.get("max_lines", MAX_LINES)))
	# Tail-limit to the last max_lines entries (newest last), preserving order — the region shows the recent tail.
	var tail_entries: Array = _tail(summary, max_lines)

	var lines: Array[String] = []
	var damage_numbers: Array[Dictionary] = []
	for entry_value: Variant in tail_entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		lines.append(String(entry.get("summary", "")))
		if String(entry.get("event_id", "")) == EVENT_ID_DAMAGE_APPLIED:
			var number: Dictionary = _damage_number(entry)
			if not number.is_empty():
				damage_numbers.append(number)

	return {
		"lines": lines,
		"damage_numbers": damage_numbers,
		"entry_count": entry_count,
		"has_entries": entry_count > 0
	}


# Extract a legible "12 -> 6 HP" style damage number from a damage_applied entry's details payload. A payload with no
# target id yields the empty dict (skipped) — never a fabricated number.
static func _damage_number(entry: Dictionary) -> Dictionary:
	var details: Dictionary = _dict(entry.get("details", {}))
	var target_id: String = String(details.get("target_entity_id", ""))
	if target_id.is_empty():
		return {}
	var amount: int = int(details.get("final_damage", details.get("amount", 0)))
	var hp_after: int = int(details.get("hp_after", 0))
	var max_hp: int = int(details.get("max_hp", 0))
	# hp_before is on the damage payload; fall back to hp_after + amount if a future event omits it.
	var hp_before: int = int(details.get("hp_before", hp_after + amount))
	return {
		"target_entity_id": target_id,
		"amount": amount,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"text": "%s -%d (%d->%d HP)" % [target_id, amount, hp_before, hp_after]
	}


# The last `count` items of an array, order preserved (newest last for a chronological log). A count >= size returns a
# copy of the whole array; a non-positive count returns an empty array.
static func _tail(source: Array, count: int) -> Array:
	if count <= 0:
		return []
	if source.size() <= count:
		return source.duplicate()
	return source.slice(source.size() - count, source.size())


static func _array(value: Variant) -> Array:
	return value if value is Array else []


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
