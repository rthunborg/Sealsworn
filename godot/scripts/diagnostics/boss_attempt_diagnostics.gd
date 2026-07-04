class_name BossAttemptDiagnostics
extends RefCounted

# Story 9.5 (AC3) — the LOCAL/OFFLINE boss-attempt tuning DIAGNOSTICS recorder. A build-profile-gated, in-memory
# recorder that captures a Larval Avatar boss ATTEMPT's tuning facts — turn count + damage taken + major telegraphs +
# outcome — so a human can READ them to tune the finale's run arc (the FR31 "fair culmination" pass). It is the boss
# analogue of LocalTimingRecorder (scripts/diagnostics/local_timing_recorder.gd): its `enabled` is
# `new_enabled and OS.is_debug_build()` (INERT in a release build — the debug/cheat-tools-inert-in-production rule),
# it accumulates records in-memory, and it exposes records() (a defensive deep copy).
#
# ⭐ IT IS A PURE OBSERVER — LOCAL/OFFLINE, ZERO SIDE EFFECTS. It introduces ZERO telemetry / network / cloud / account /
# file-persist dependency (the NFR11 no-live-service rule + the TelemetrySink-stays-local platform rule). It draws ZERO
# RNG (no randi/randf/RandomNumberGenerator), MUTATES NOTHING (not the run, not the board, not a save), emits NO
# DomainEvent (the finale attempt is a LOCAL dev record, NOT an append-only event — the DomainEvent.Type enum tail is
# unchanged), and adds NO save key (the diagnostics are ephemeral in-memory records, never serialized). It is NOT a
# difficulty knob: it OBSERVES a run's turn count / damage / telegraphs / outcome; it does not TUNE the game (difficulty
# is a HARD non-goal).
#
# WHAT IT CAPTURES (AC3, per attempt) — all DERIVED from data that already exists (the boss fight's turn state + its
# emitted DomainEvent stream); the recorder computes nothing gameplay-affecting:
#   - turn_count       : the tactical turn number at the attempt's end (the TacticalTurnState.turn_number at
#                        defeat/death — how long the fight lasted).
#   - damage_taken     : the total damage the HERO absorbed during the attempt (the sum of damage_applied events whose
#                        target is the hero entity — the hero's HP attrition).
#   - major_telegraphs : the count of the boss's major telegraph events (the tile_marked telegraphs the boss emitted —
#                        the dangerous-ability windows the player had to react to).
#   - outcome          : victory (the boss reached 0 HP) or defeat (the hero died) — the OUTCOME_VICTORY / OUTCOME_DEFEAT
#                        markers.
#
# HOW A CALLER RECORDS AN ATTEMPT: build the recorder (enabled only in a dev build), then either call the granular
# record_attempt(turn_count, damage_taken, major_telegraphs, outcome) with pre-computed facts, OR call
# record_attempt_from_events(turn_count, hero_entity_id, events, outcome) to DERIVE damage_taken + major_telegraphs from
# the attempt's ordered DomainEvent stream (the derive-from-events posture RunSummary uses — the events ARE the source
# truth). Both are inert when disabled/release.
#
# HOME ([Decision]): scripts/diagnostics/ — alongside local_timing_recorder.gd, the sibling build-profile-gated local
# recorder. A DEDICATED RefCounted (RECOMMENDED over reusing the Diagnostics autoload) so the boss-attempt record shape
# is self-documenting and the dev-build gate is explicit; it is a pure RefCounted (NOT a Node/scene/autoload — 9.5 adds
# NO new autoload).

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

# The two stable attempt-outcome markers (lower_snake, self-documenting). A victory (the boss reached 0 HP) or a defeat
# (the hero died) — the ONLY two terminal boss-attempt outcomes AC3 records.
const OUTCOME_VICTORY := &"victory"
const OUTCOME_DEFEAT := &"defeat"

# The exact key set of each recorded attempt (the LocalTimingRecorder record-shape discipline — a key never silently
# appears/vanishes). Kept as a const so a consumer + a test can pin the shape.
const RECORD_KEYS: Array[String] = [
	"turn_count",
	"damage_taken",
	"major_telegraphs",
	"outcome"
]

# Whether the recorder actually records (dev build only — the LocalTimingRecorder gate VERBATIM). In a release build
# `enabled` is forced false regardless of the constructor argument, so the recorder is INERT (records() stays empty).
var enabled: bool = false
var _records: Array[Dictionary] = []

func _init(new_enabled: bool = false) -> void:
	enabled = new_enabled and OS.is_debug_build()


# Record a boss attempt from PRE-COMPUTED tuning facts (AC3). Inert when disabled/release (records nothing). Draws ZERO
# RNG, mutates nothing external. `outcome` is normalized to OUTCOME_VICTORY / OUTCOME_DEFEAT (anything else records the
# raw marker verbatim so a mis-supplied outcome is visible, not silently dropped — the honest-record posture). The
# counts are clamped to >= 0 (a negative count is a caller bug; clamp rather than record a nonsense negative).
func record_attempt(turn_count: int, damage_taken: int, major_telegraphs: int, outcome: StringName) -> void:
	if not enabled:
		return
	_records.append({
		"turn_count": maxi(0, turn_count),
		"damage_taken": maxi(0, damage_taken),
		"major_telegraphs": maxi(0, major_telegraphs),
		"outcome": String(outcome)
	})


# Record a boss attempt DERIVING damage_taken + major_telegraphs from the attempt's ordered DomainEvent stream (AC3) —
# the derive-from-events source truth (the RunSummary derive-from-events posture). `hero_entity_id` scopes the
# damage-taken sum to the hero (damage the boss took is NOT hero damage-taken). `events` is an untyped Array (tolerant
# of the element type — a non-DomainEvent entry is ignored, the RunSummary footgun-tolerant discipline). Inert when
# disabled/release. Draws ZERO RNG, mutates nothing.
func record_attempt_from_events(
	turn_count: int,
	hero_entity_id: StringName,
	events: Array,
	outcome: StringName
) -> void:
	if not enabled:
		return
	var damage_taken: int = damage_taken_from_events(hero_entity_id, events)
	var major_telegraphs: int = major_telegraph_count_from_events(events)
	record_attempt(turn_count, damage_taken, major_telegraphs, outcome)


# Derive the total damage the HERO absorbed from an ordered DomainEvent stream — the sum of every damage_applied event
# whose target is `hero_entity_id`. A PURE static read (no RNG, no mutation, no `enabled` gate — a caller may derive the
# fact independently of whether the recorder is enabled). A non-DomainEvent entry is ignored (the footgun-tolerant
# discipline). Reads the damage from the event payload's `final_damage` when present (the applied amount), else the
# hp_before - hp_after delta (both are the same for a damage_applied; final_damage is the canonical applied amount).
static func damage_taken_from_events(hero_entity_id: StringName, events: Array) -> int:
	var total: int = 0
	for event_value: Variant in events:
		if not (event_value is DomainEvent):
			continue
		var event: DomainEvent = event_value
		if event.event_type != DomainEvent.Type.DAMAGE_APPLIED:
			continue
		var payload: Dictionary = event.payload
		# The damage TARGET rides the payload as `target_entity_id` (DomainEvent has no top-level target field — only
		# actor_id + payload). Scope the sum to the hero: damage the boss took is NOT hero damage-taken.
		if String(payload.get("target_entity_id", "")) != String(hero_entity_id):
			continue
		# Prefer the canonical applied amount (final_damage / amount); fall back to the hp delta (hp_before - hp_after).
		# All three are equal for a damage_applied event — final_damage is the authoritative applied number.
		if payload.has("final_damage"):
			total += maxi(0, int(payload.get("final_damage", 0)))
		elif payload.has("amount"):
			total += maxi(0, int(payload.get("amount", 0)))
		else:
			total += maxi(0, int(payload.get("hp_before", 0)) - int(payload.get("hp_after", 0)))
	return total


# Derive the count of the boss's MAJOR telegraph events from an ordered DomainEvent stream — the number of tile_marked
# events (the boss's dangerous-ability telegraphs; the boss adapter emits a tile_marked per telegraph). A PURE static
# read (no RNG, no mutation, no `enabled` gate). A non-DomainEvent entry is ignored.
static func major_telegraph_count_from_events(events: Array) -> int:
	var count: int = 0
	for event_value: Variant in events:
		if not (event_value is DomainEvent):
			continue
		var event: DomainEvent = event_value
		if event.event_type == DomainEvent.Type.TILE_MARKED:
			count += 1
	return count


# The recorded attempts (a defensive deep copy — the LocalTimingRecorder.records() shape). Empty when the recorder is
# disabled/release (nothing was recorded) or when no attempt has been recorded yet.
func records() -> Array[Dictionary]:
	return _records.duplicate(true)


# The number of recorded attempts (a convenience read; equals records().size()).
func record_count() -> int:
	return _records.size()
