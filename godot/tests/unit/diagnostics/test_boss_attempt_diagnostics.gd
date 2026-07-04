extends "res://tests/unit/test_case.gd"

# Story 9.5 Task 3 (AC3) — the LOCAL/OFFLINE boss-attempt tuning DIAGNOSTICS recorder (BossAttemptDiagnostics, the
# LocalTimingRecorder-modeled build-profile-gated recorder). Covers: an ENABLED (dev-build) recorder captures a boss
# attempt's turn count / damage taken / major telegraphs / outcome (both the granular record_attempt AND the
# derive-from-events record_attempt_from_events); a DISABLED recorder is INERT (records() empty, no capture); the
# derive-from-events helpers scope damage-taken to the hero and count only tile_marked telegraphs (a mixed event stream
# does not pollute the record); the recorder is a PURE in-memory observer (no telemetry/network/file dependency — it
# holds only plain-data records + adds no save key); the record shape is the pinned RECORD_KEYS set.
#
# OS.is_debug_build() is TRUE under the headless test runner (a debug build), so the enabled path is directly
# exercisable. The `enabled = new_enabled and OS.is_debug_build()` gate is asserted by constructing with new_enabled
# false (INERT regardless of the build) AND by the note that a release build forces enabled false (the conjunction).

const BossAttemptDiagnostics = preload("res://scripts/diagnostics/boss_attempt_diagnostics.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

const HERO_ID := &"hero"
const BOSS_ID := &"larval_avatar"

func run() -> Dictionary:
	_enabled_recorder_captures_the_four_attempt_facts()
	_disabled_recorder_is_inert()
	_derive_from_events_scopes_damage_to_the_hero_and_counts_telegraphs()
	_record_from_events_captures_derived_facts_when_enabled()
	_record_shape_is_the_pinned_key_set()
	_recorder_is_a_pure_in_memory_observer()
	_outcome_markers_are_stable()
	_negative_counts_are_clamped_and_a_release_gate_is_documented()
	return result()


# ---- AC3: an enabled (dev-build) recorder captures the four tuning facts ---------------------------

func _enabled_recorder_captures_the_four_attempt_facts() -> void:
	var recorder: BossAttemptDiagnostics = BossAttemptDiagnostics.new(true)
	assert_true(recorder.enabled, "In the headless (debug) build, a recorder constructed enabled must BE enabled.")
	assert_equal(recorder.record_count(), 0, "A fresh recorder has recorded no attempts yet.")

	recorder.record_attempt(7, 12, 3, BossAttemptDiagnostics.OUTCOME_VICTORY)

	assert_equal(recorder.record_count(), 1, "record_attempt appends one attempt record when enabled.")
	var records: Array[Dictionary] = recorder.records()
	assert_equal(records.size(), 1, "records() returns the one recorded attempt.")
	var record: Dictionary = records[0]
	assert_equal(int(record.get("turn_count")), 7, "The record captures the turn count (AC3).")
	assert_equal(int(record.get("damage_taken")), 12, "The record captures the damage taken (AC3).")
	assert_equal(int(record.get("major_telegraphs")), 3, "The record captures the major telegraph count (AC3).")
	assert_equal(String(record.get("outcome")), "victory", "The record captures the outcome (AC3).")

	# A second attempt (a defeat) accumulates.
	recorder.record_attempt(4, 18, 1, BossAttemptDiagnostics.OUTCOME_DEFEAT)
	assert_equal(recorder.record_count(), 2, "A second attempt accumulates in-memory.")
	assert_equal(String(recorder.records()[1].get("outcome")), "defeat", "The second attempt records the defeat outcome.")


# ---- AC3: a disabled recorder is INERT (no capture, records() empty) ------------------------------

func _disabled_recorder_is_inert() -> void:
	# Constructed disabled -> INERT regardless of the build (the LocalTimingRecorder gate). This is the direct proof of
	# the enabled gate: a disabled recorder records NOTHING even in a debug build.
	var recorder: BossAttemptDiagnostics = BossAttemptDiagnostics.new(false)
	assert_false(recorder.enabled, "A recorder constructed disabled must NOT be enabled.")

	recorder.record_attempt(9, 30, 5, BossAttemptDiagnostics.OUTCOME_VICTORY)
	recorder.record_attempt_from_events(9, HERO_ID, _attempt_events(), BossAttemptDiagnostics.OUTCOME_DEFEAT)

	assert_equal(recorder.record_count(), 0, "A disabled recorder captures NOTHING (INERT).")
	assert_true(recorder.records().is_empty(), "A disabled recorder's records() stays empty.")

	# The default constructor is disabled (a caller must opt in — the safe default).
	var default_recorder: BossAttemptDiagnostics = BossAttemptDiagnostics.new()
	assert_false(default_recorder.enabled, "The default constructor is disabled (opt-in required).")


# ---- AC3: derive-from-events helpers scope damage to the hero + count telegraphs ------------------

func _derive_from_events_scopes_damage_to_the_hero_and_counts_telegraphs() -> void:
	var events: Array = _attempt_events()

	# The hero absorbed 6 + 4 = 10 damage; the boss's 16 damage is NOT hero damage-taken.
	var damage: int = BossAttemptDiagnostics.damage_taken_from_events(HERO_ID, events)
	assert_equal(damage, 10, "damage_taken sums only damage_applied events targeting the HERO (6 + 4), not the boss's HP loss.")

	# There are two tile_marked telegraphs in the stream.
	var telegraphs: int = BossAttemptDiagnostics.major_telegraph_count_from_events(events)
	assert_equal(telegraphs, 2, "major_telegraph_count counts only tile_marked events (2).")

	# A non-DomainEvent entry in the stream is ignored (the footgun-tolerant discipline).
	var mixed: Array = events.duplicate()
	mixed.append({"not": "an event"})
	mixed.append("garbage")
	assert_equal(BossAttemptDiagnostics.damage_taken_from_events(HERO_ID, mixed), 10, "A non-DomainEvent entry does not pollute the damage sum.")
	assert_equal(BossAttemptDiagnostics.major_telegraph_count_from_events(mixed), 2, "A non-DomainEvent entry does not pollute the telegraph count.")

	# An empty stream derives 0 (no crash, honest zero).
	assert_equal(BossAttemptDiagnostics.damage_taken_from_events(HERO_ID, []), 0, "An empty stream derives 0 damage taken.")
	assert_equal(BossAttemptDiagnostics.major_telegraph_count_from_events([]), 0, "An empty stream derives 0 telegraphs.")


func _record_from_events_captures_derived_facts_when_enabled() -> void:
	var recorder: BossAttemptDiagnostics = BossAttemptDiagnostics.new(true)
	recorder.record_attempt_from_events(11, HERO_ID, _attempt_events(), BossAttemptDiagnostics.OUTCOME_VICTORY)

	assert_equal(recorder.record_count(), 1, "record_attempt_from_events records one attempt when enabled.")
	var record: Dictionary = recorder.records()[0]
	assert_equal(int(record.get("turn_count")), 11, "The derived record carries the supplied turn count.")
	assert_equal(int(record.get("damage_taken")), 10, "The derived record computes hero damage taken from the events (10).")
	assert_equal(int(record.get("major_telegraphs")), 2, "The derived record computes the telegraph count from the events (2).")
	assert_equal(String(record.get("outcome")), "victory", "The derived record carries the supplied outcome.")


# ---- AC3: the record shape is the pinned RECORD_KEYS set ------------------------------------------

func _record_shape_is_the_pinned_key_set() -> void:
	var recorder: BossAttemptDiagnostics = BossAttemptDiagnostics.new(true)
	recorder.record_attempt(3, 5, 1, BossAttemptDiagnostics.OUTCOME_VICTORY)
	var record: Dictionary = recorder.records()[0]

	var keys: Array = record.keys()
	keys.sort()
	var expected: Array = BossAttemptDiagnostics.RECORD_KEYS.duplicate()
	expected.sort()
	assert_equal(keys, expected, "A recorded attempt carries EXACTLY the pinned RECORD_KEYS set (no key silently appears/vanishes).")


# ---- AC3: the recorder is a PURE in-memory observer (no telemetry/network/file dependency) --------

func _recorder_is_a_pure_in_memory_observer() -> void:
	# The recorder holds ONLY plain-data records (int/String) — no live handle, no file path, no network client. records()
	# returns a defensive deep copy, so a caller mutating the returned list never perturbs the recorder (proving the
	# records are owned in-memory, not backed by an external sink).
	var recorder: BossAttemptDiagnostics = BossAttemptDiagnostics.new(true)
	recorder.record_attempt(2, 4, 1, BossAttemptDiagnostics.OUTCOME_DEFEAT)

	var snapshot_a: Array[Dictionary] = recorder.records()
	snapshot_a.clear()
	snapshot_a.append({"turn_count": 999, "damage_taken": 999, "major_telegraphs": 999, "outcome": "tampered"})
	# The recorder's own records are untouched by mutating the returned copy.
	assert_equal(recorder.record_count(), 1, "Mutating the returned records() copy must not perturb the recorder (in-memory ownership).")
	assert_equal(int(recorder.records()[0].get("turn_count")), 2, "The recorder's record is unchanged after external mutation.")

	# Mutating a nested record dict from records() must not perturb the recorder either (deep copy).
	var snapshot_b: Array[Dictionary] = recorder.records()
	(snapshot_b[0] as Dictionary)["turn_count"] = 12345
	assert_equal(int(recorder.records()[0].get("turn_count")), 2, "records() deep-copies each record dict (no shared mutable handle leaks out).")


# ---- outcome markers ------------------------------------------------------------------------------

func _outcome_markers_are_stable() -> void:
	assert_equal(String(BossAttemptDiagnostics.OUTCOME_VICTORY), "victory", "The victory marker is the stable lower_snake `victory`.")
	assert_equal(String(BossAttemptDiagnostics.OUTCOME_DEFEAT), "defeat", "The defeat marker is the stable lower_snake `defeat`.")


func _negative_counts_are_clamped_and_a_release_gate_is_documented() -> void:
	# A negative count (a caller bug) is clamped to 0 rather than recorded as a nonsense negative.
	var recorder: BossAttemptDiagnostics = BossAttemptDiagnostics.new(true)
	recorder.record_attempt(-3, -5, -1, BossAttemptDiagnostics.OUTCOME_VICTORY)
	var record: Dictionary = recorder.records()[0]
	assert_equal(int(record.get("turn_count")), 0, "A negative turn count is clamped to 0.")
	assert_equal(int(record.get("damage_taken")), 0, "A negative damage taken is clamped to 0.")
	assert_equal(int(record.get("major_telegraphs")), 0, "A negative telegraph count is clamped to 0.")

	# The `enabled = new_enabled and OS.is_debug_build()` conjunction means a RELEASE build forces enabled false (the
	# recorder is INERT in production — asserted by inspection here; OS.is_debug_build() cannot be toggled in the headless
	# suite, so the disabled-constructor test above is the runnable proof of the gate).
	assert_true(OS.is_debug_build(), "The headless test runner is a debug build (so the enabled path is exercisable here).")


# ---- helpers -------------------------------------------------------------------------------------

# A representative attempt event stream: a boss telegraph (tile_marked), the boss detonating it and hitting the hero for
# 6 (marked_tile_detonated + damage_applied to the hero), a second telegraph, a second hit for 4, and a player hit that
# damages the BOSS for 16 (which must NOT count as hero damage-taken). Sequence ids are unique + monotonic.
func _attempt_events() -> Array:
	var events: Array = []
	events.append(_tile_marked(1, BOSS_ID, HERO_ID, Vector2i(6, 4), "tel-1"))
	events.append(_damage_applied(2, BOSS_ID, HERO_ID, 6, 18, 12, 18))
	events.append(_tile_marked(3, BOSS_ID, HERO_ID, Vector2i(6, 4), "tel-2"))
	events.append(_damage_applied(4, BOSS_ID, HERO_ID, 4, 12, 8, 18))
	# A player hit to the boss (damage_applied targeting the BOSS — NOT hero damage-taken).
	events.append(_damage_applied(5, HERO_ID, BOSS_ID, 16, 36, 20, 36))
	return events


func _tile_marked(sequence_id: int, actor: StringName, target: StringName, cell: Vector2i, telegraph_id: String) -> DomainEvent:
	return DomainEvent.tile_marked(
		sequence_id,
		actor,
		target,
		cell,
		telegraph_id,
		{
			"kind": "larval_avatar_telegraph",
			"source_entity_id": String(actor),
			"boss_definition_id": String(actor),
			"boss_action_id": "phase_lash",
			"created_turn_number": 1,
			"due_turn_number": 2,
			"damage": 6,
			"damage_type": "physical",
			"status": "pending",
			"explanation": "The Larval Avatar telegraphs."
		}
	)


func _damage_applied(sequence_id: int, actor: StringName, target: StringName, amount: int, hp_before: int, hp_after: int, max_hp: int) -> DomainEvent:
	return DomainEvent.damage_applied(
		sequence_id,
		actor,
		target,
		amount,
		hp_before,
		hp_after,
		max_hp,
		{
			"weapon_id": "test_strike",
			"base_damage": amount,
			"final_damage": amount,
			"damage_type": "physical",
			"explanation": "Test damage."
		}
	)
