class_name TacticalCombatLogView
extends RefCounted

# Story 14.3 (AC1/AC3 — the F6/F7 fix) — the PURE, SCENE-FREE in-combat LOG-REGION projection seam. Given a board
# VM read (TacticalBoardViewModel.to_dictionary()), it projects the render-ready log content the presenter draws into
# the `log_or_outcome` region: the per-action display lines (tail-limited to the last MAX_LINES).
#
# It reads ONLY the pinned VM slot `event_log_summary` (the CombatExplanationLog entries the presenter sourced from
# the bound session's `event_log()` in render() — Task 1). The `event_log_summary` slot is an EXISTING pinned VM key;
# this seam adds NO new board-VM key and invents NO new domain query. It mutates NOTHING (the input dict is never
# written) and draws ZERO RNG. The presenter is a thin Control that renders this output; the WHICH-lines DECISION
# lives here and is unit-tested.
#
# The SOURCE of truth is the domain events the session accumulated (via `event_log()`); CombatExplanationLog is a
# stateless event->line transform, NOT a stored authority. This seam does NOT read a presentation/combat log as
# source truth and does NOT build the deferred run-level event store (it only formats the ephemeral session log the
# VM already carries).
#
# Damage numbers reach the screen through the two channels the presenter ACTUALLY consumes — the inline damage text
# baked into each log LINE ("enemy_1 took 3 physical damage from hero.") + the floating "-N" labels the FEEDBACK plan
# drives (TacticalCombatFeedback hits -> _animate_damage_number). This seam therefore projects ONLY the lines the
# presenter renders and exposes NO structured damage-number slot the presenter would not read (the fail-loud /
# no-dead-output posture — the Round-1 review decision pruned the previously-unconsumed `damage_numbers` output).
#
# NFR9 (accessibility): the log line is an inherently non-color text channel. A hit's legibility survives with color
# removed (the line names the victim + amount) and with audio off (no audio dependency).

# The EXACT key set of from_board_vm() (the exact-key discipline — a key never silently appears/vanishes; a test pins it).
const VIEW_KEYS: Array[String] = [
	"lines",
	"entry_count",
	"has_entries"
]

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
	for entry_value: Variant in tail_entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		lines.append(String(entry.get("summary", "")))

	return {
		"lines": lines,
		"entry_count": entry_count,
		"has_entries": entry_count > 0
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
