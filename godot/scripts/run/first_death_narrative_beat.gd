class_name FirstDeathNarrativeBeat
extends RefCounted

# Story 8.5 (AC1/AC2/AC3) — the scene-free, SKIPPABLE first-death NARRATIVE-BEAT read DTO. It is the "narrative flavor
# without blocking play" DATA surface: a single, PURE-READ, serializable DOMAIN projection that surfaces the first-death
# LINE ("Good. You remembered how to die." — FR61) + a skippability marker, so a later outpost UI (Story 8.6) can PRESENT
# and DISMISS the beat, and so a skip is STRUCTURALLY a pure no-op (the DTO owns no truth to change).
#
# ⭐ THE SINGLE MOST IMPORTANT ARCHITECTURAL FACT — it is a PURE READ (mirroring RunSummary VERBATIM). Building it, reading
# it, and "dismissing" it draw ZERO RNG, run NO command, emit NO event, and mutate NOTHING. It owns NO domain truth — the
# first-death FLAG is set by RecordFirstDeathCommand (the run-end mutation), SEPARATELY from this DTO (the line delivery),
# so a skip/dismiss CANNOT mutate the flag. A skip/dismiss is simply the presentation layer NOT rendering the beat further;
# there is NO "skip command" that could mutate rewards/unlocks/tactical state (AC2 satisfied STRUCTURALLY, not behaviorally).
#
# ⭐ LINE-AS-ID (the by-id posture): the beat is keyed by a stable lower_snake line_id (== DomainEvent.FIRST_DEATH_LINE_ID
# in v0); the raw display prose lives as a const on THIS DTO (FIRST_DEATH_LINE), resolved from the line_id via a tiny const
# lookup. This mirrors the epic-wide by-id posture (content referenced BY ID; the display string is a presentation/
# localization concern) and centralizes the prose for a future localization pass (deferred). v0 has EXACTLY ONE narrative
# line — a single const + this DTO is the whole surface; 8.5 authors NO narrative CONTENT roster / repository / codex /
# JSON-or-.tres pipeline (the epic-wide by-id + no-content-pipeline defer). The GDD's first-VICTORY reveal ("It did not die.
# It learned the way back." — FR62) is Epic 9 (Story 9.4) — NOT authored here.
#
# ⭐ OFF THE CRITICAL PATH (AC3 — the load-bearing non-dependency): the beat is a SEPARATE, OPTIONAL surface (its own DTO).
# The RunSummary (Story 8.2/8.4) is COMPLETE without it — 8.5 adds NO narrative field to RunSummary and does NOT make the
# summary or the start-another-descent path depend on the beat. A later outpost UI (8.6) MAY render the beat ALONGSIDE the
# summary, but is NEVER blocked by its absence. Ignoring lore never blocks understanding the run summary / outpost options /
# starting another descent.
#
# WHAT IT IS:
#   - FirstDeathNarrativeBeat.for_first_death(...): a PURE read that projects a POPULATED beat (has_beat == true) from the
#     first-death FACT (a FAILED run + the profile's freshly-set first-death state, OR the first_death_recorded event). It
#     is DELIBERATELY built from the RECORD, not re-derived: a caller that just ran RecordFirstDeathCommand passes the fact
#     through. to_dictionary() projects the EXACT pinned DICTIONARY_KEYS set (a key never silently appears/vanishes; pinned
#     by test_first_death_narrative_beat.gd), mirroring the RunSummary exact-key discipline VERBATIM. Repeated builds/reads
#     are byte-identical (pure).
#   - A null / non-first-death / non-failed input projects the FAIL-CLOSED empty beat (has_beat == false + empty fields) so
#     a consumer branches on has_beat WITHOUT inspecting the empty fields (the RunSummary._empty() discipline) — NEVER a
#     crash, NEVER a half-fact.
#
# WHAT IT IS NOT: it owns NO domain truth, submits NO command, draws NO RNG (ZERO randi/randf/RandomNumberGenerator), emits
# NO event, and mutates nothing. It is NOT a scene/Control/.tscn (the outpost/narrative screen is Story 8.6; UI-scene-last).
# It is NOT a save snapshot (DERIVED on demand, NOT persisted). It does NOT set the first-death FLAG (RecordFirstDeath
# Command owns that) and does NOT author narrative CONTENT beyond the single first-death line const.

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

# The EXACT top-level key set of every projection (the RunSummary.DICTIONARY_KEYS exact-key discipline — a key never
# silently appears/vanishes; the set is pinned by test_first_death_narrative_beat.gd). has_beat gates whether the other
# fields are meaningful (fail-closed like RunSummary.has_summary). line_id is the by-id line reference; line is the resolved
# display prose; is_skippable marks the beat dismissable (FR65).
const DICTIONARY_KEYS: Array[String] = [
	"has_beat",
	"line_id",
	"line",
	"is_skippable"
]

# The first-death display prose (FR61). Kept HERE (not in the event payload) so the event stays a clean by-id record and
# the prose is centralized for a future localization pass (deferred). Resolved from line_id via LINE_BY_ID.
const FIRST_DEATH_LINE := "Good. You remembered how to die."

# The v0 narrative-line lookup (LINE-AS-ID -> display prose). v0 has EXACTLY ONE line (the first-death line). A tiny const
# map IS the whole surface — NOT a NarrativeRepository / codex / content pipeline (the epic-wide no-content-pipeline defer).
# A future localization pass replaces the resolved value here (or swaps this for a localized lookup) without touching the
# event payload / the flag / the command (all of which stay by-id).
const LINE_BY_ID := {
	"first_death": FIRST_DEATH_LINE
}

# Whether a meaningful first-death beat is present (a FAILED first death). A null / non-first-death / non-failed source
# projects has_beat == false + empty fields (fail-closed). A consumer branches on has_beat.
var has_beat: bool = false
# The stable lower_snake narrative-line id (LINE-AS-ID). "" for an empty beat.
var line_id: StringName = &""
# The resolved display prose ("Good. You remembered how to die." for the first-death line). "" for an empty beat.
var line: String = ""
# Whether the beat is skippable/dismissable (FR65 — always true for a present v0 beat). false for an empty beat.
var is_skippable: bool = false

func _init(
	new_has_beat: bool = false,
	new_line_id: StringName = &"",
	new_line: String = "",
	new_is_skippable: bool = false
) -> void:
	has_beat = new_has_beat
	line_id = new_line_id
	line = new_line
	is_skippable = new_is_skippable


# Build the POPULATED first-death beat (AC1/AC2) from the first-death FACT: the line_id (by-id) + the skippable marker. A
# PURE read — draws NO RNG, runs NO command, emits NO event, mutates NOTHING. Resolves the display prose from the line_id
# via LINE_BY_ID. An UNKNOWN / blank line_id (not in LINE_BY_ID) projects the fail-closed empty beat (has_beat == false) so
# a consumer never renders a beat with no resolvable line. Repeated builds are byte-identical.
static func for_first_death(new_line_id: StringName = DomainEvent.FIRST_DEATH_LINE_ID, new_is_skippable: bool = true) -> FirstDeathNarrativeBeat:
	var key: String = String(new_line_id)
	if key.is_empty() or not LINE_BY_ID.has(key):
		return _empty()
	return load("res://scripts/run/first_death_narrative_beat.gd").new(
		true,
		StringName(key),
		String(LINE_BY_ID[key]),
		new_is_skippable
	)


# Build the beat from a first_death_recorded EVENT (the convenience seam a caller that has the run-end event uses). A PURE
# read: reads the event's line_id + is_skippable and projects the populated beat (or the fail-closed empty beat for a null /
# wrong-type / unresolvable-line event). Draws NO RNG, mutates NOTHING.
static func from_event(event: DomainEvent) -> FirstDeathNarrativeBeat:
	if event == null or event.event_type != DomainEvent.Type.FIRST_DEATH_RECORDED:
		return _empty()
	var event_line_id: StringName = StringName(String(event.payload.get("line_id", "")))
	var event_is_skippable: bool = bool(event.payload.get("is_skippable", false))
	return for_first_death(event_line_id, event_is_skippable)


# Exact-key projection (the RunSummary exact-key discipline): plain String/bool data only (no live handle leaks out). A
# FRESH dictionary each call so a mutation of the returned dict never perturbs this DTO. PURE read.
func to_dictionary() -> Dictionary:
	return {
		"has_beat": has_beat,
		"line_id": String(line_id),
		"line": line,
		"is_skippable": is_skippable
	}


# The fail-closed empty beat (a null / non-first-death / non-failed source): has_beat == false + empty fields, so a consumer
# branches on has_beat without inspecting the empty fields (the RunSummary._empty() discipline). NEVER a crash, NEVER a
# half-fact.
static func _empty() -> FirstDeathNarrativeBeat:
	return load("res://scripts/run/first_death_narrative_beat.gd").new(false, &"", "", false)
