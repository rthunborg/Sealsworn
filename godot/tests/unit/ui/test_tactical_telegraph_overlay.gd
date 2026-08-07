extends "res://tests/unit/test_case.gd"

# Story 15.3 (AC1/AC2/AC3 — the F5 fix) — TacticalTelegraphOverlay coverage. Proves the scene-free projection reads ONLY
# the pinned VM `event_log_summary` slot and returns the SET of currently-ACTIVE marked cells (a tile_marked whose
# telegraph_id has NO matching marked_tile_detonated):
#   - the EXACT MARK_KEYS set on each active entry (a key never silently appears/vanishes);
#   - a lone tile_marked -> its cell is active (cell + telegraph_id surfaced);
#   - a tile_marked paired with its marked_tile_detonated (same telegraph_id) -> cleared (hit OR avoided both clear);
#   - a mark whose SOURCE enemy dies (a damage_applied hp_after == 0) -> cleared (AC1 "or is cancelled" — a dead enemy
#     never detonates); a NON-lethal hit on the source leaves it active; killing one seer clears only its own mark;
#   - two simultaneous marks -> both active, and detonating ONE clears only that one (independent);
#   - kind-agnostic -> a boss-telegraph mark (a different telegraph_id namespace + kind) surfaces too;
#   - a malformed / absent entry is a safe no-op (never a fabricated cell);
#   - has_active_marks mirrors whether any mark is active;
#   - zero mutation of the input.
# str() (never eager String(nullable)) is used in assert messages (the 14.1 retro test-honesty note).

const TacticalTelegraphOverlay = preload("res://scripts/ui/view_models/tactical_telegraph_overlay.gd")

func run() -> Dictionary:
	_mark_keys_are_exact()
	_a_lone_mark_is_active()
	_a_detonated_mark_is_cleared()
	_an_avoided_detonation_also_clears_the_mark()
	_a_mark_clears_when_its_source_enemy_dies()
	_a_mark_survives_a_non_lethal_hit_on_its_source()
	_killing_one_seer_clears_only_its_own_mark()
	_two_simultaneous_marks_are_independent()
	_a_boss_telegraph_mark_surfaces_kind_agnostically()
	_malformed_or_absent_entries_are_a_safe_no_op()
	_has_active_marks_reflects_state()
	_active_marks_does_not_mutate_the_input()
	return result()


# ---- exact-key discipline ------------------------------------------------------------------------

func _mark_keys_are_exact() -> void:
	var active: Array = TacticalTelegraphOverlay.active_marks([_mark(1, "t1", 3, 3)])
	assert_equal(active.size(), 1, "One active mark surfaces. Got %s." % str(active.size()))
	_assert_exact_keys(active[0] if active.size() > 0 else {}, TacticalTelegraphOverlay.MARK_KEYS, "An active mark carries EXACTLY the MARK_KEYS set.")


# ---- the projection ------------------------------------------------------------------------------

func _a_lone_mark_is_active() -> void:
	var active: Array = TacticalTelegraphOverlay.active_marks([_mark(1, "t1", 3, 3)])
	assert_equal(active.size(), 1, "A tile_marked with no matching detonation is active. Got %s." % str(active.size()))
	var mark: Dictionary = active[0] if active.size() > 0 else {}
	assert_equal(mark.get("cell"), {"x": 3, "y": 3}, "The active mark carries the marked cell. Got %s." % str(mark.get("cell")))
	assert_equal(mark.get("telegraph_id"), "t1", "The active mark carries its telegraph_id. Got %s." % str(mark.get("telegraph_id")))


func _a_detonated_mark_is_cleared() -> void:
	var summary: Array = [_mark(1, "t1", 3, 3), _detonation(2, "t1", 3, 3, "hit")]
	var active: Array = TacticalTelegraphOverlay.active_marks(summary)
	assert_equal(active.size(), 0, "A mark whose telegraph_id has a matching marked_tile_detonated is cleared. Got %s." % str(active.size()))


func _an_avoided_detonation_also_clears_the_mark() -> void:
	# The mark resolves whether the detonation HIT or was AVOIDED — either marked_tile_detonated clears the telegraph.
	var summary: Array = [_mark(1, "t1", 3, 3), _detonation(2, "t1", 3, 3, "avoided")]
	var active: Array = TacticalTelegraphOverlay.active_marks(summary)
	assert_equal(active.size(), 0, "An AVOIDED detonation also clears the mark (the danger window is over). Got %s." % str(active.size()))


# AC1 "or is cancelled": a dead enemy never detonates (the enemy AI returns early on is_dead(), so no
# marked_tile_detonated is ever emitted). Killing the seer BEFORE its due turn must CLEAR the telegraph rather than
# strand a glyph on a tile that is now safe. The source-death signal is a damage_applied with hp_after == 0 for the
# marking enemy (matched by the mark's source_entity_id / actor_id).
func _a_mark_clears_when_its_source_enemy_dies() -> void:
	var mark: Dictionary = _mark(1, "t1", 3, 3)
	(mark["details"] as Dictionary)["source_entity_id"] = "seer_1"
	mark["actor_id"] = "seer_1"
	var summary: Array = [mark, _death(2, "seer_1")]
	var active: Array = TacticalTelegraphOverlay.active_marks(summary)
	assert_equal(active.size(), 0, "A mark clears when its SOURCE enemy dies (a dead enemy never detonates). Got %s." % str(active.size()))


func _a_mark_survives_a_non_lethal_hit_on_its_source() -> void:
	# A NON-lethal hit on the seer (hp_after > 0) does NOT clear the mark — the seer is still alive and will detonate.
	var mark: Dictionary = _mark(1, "t1", 3, 3)
	(mark["details"] as Dictionary)["source_entity_id"] = "seer_1"
	mark["actor_id"] = "seer_1"
	var summary: Array = [mark, _hit(2, "seer_1", 4)]
	var active: Array = TacticalTelegraphOverlay.active_marks(summary)
	assert_equal(active.size(), 1, "A non-lethal hit on the source leaves the mark active (the seer still detonates). Got %s." % str(active.size()))


func _killing_one_seer_clears_only_its_own_mark() -> void:
	var mark_a: Dictionary = _mark(1, "ta", 2, 2)
	(mark_a["details"] as Dictionary)["source_entity_id"] = "seer_a"
	mark_a["actor_id"] = "seer_a"
	var mark_b: Dictionary = _mark(2, "tb", 4, 4)
	(mark_b["details"] as Dictionary)["source_entity_id"] = "seer_b"
	mark_b["actor_id"] = "seer_b"
	var active: Array = TacticalTelegraphOverlay.active_marks([mark_a, mark_b, _death(3, "seer_a")])
	assert_equal(active.size(), 1, "Killing one of two seers clears ONLY its mark. Got %s." % str(active.size()))
	assert_equal((active[0] as Dictionary).get("telegraph_id"), "tb", "The surviving mark belongs to the living seer_b. Got %s." % str((active[0] as Dictionary).get("telegraph_id")))


func _two_simultaneous_marks_are_independent() -> void:
	var both: Array = TacticalTelegraphOverlay.active_marks([_mark(1, "t1", 2, 2), _mark(2, "t2", 4, 4)])
	assert_equal(both.size(), 2, "Two un-detonated marks are BOTH active. Got %s." % str(both.size()))
	var cells: Dictionary = {}
	for mark_value: Variant in both:
		var mark: Dictionary = mark_value
		cells[String(mark.get("telegraph_id", ""))] = mark.get("cell")
	assert_equal(cells.get("t1"), {"x": 2, "y": 2}, "The first mark keeps its own cell. Got %s." % str(cells.get("t1")))
	assert_equal(cells.get("t2"), {"x": 4, "y": 4}, "The second mark keeps its own cell. Got %s." % str(cells.get("t2")))
	# Detonate ONLY t1 -> t2 remains active (independent clearing).
	var after: Array = TacticalTelegraphOverlay.active_marks([
		_mark(1, "t1", 2, 2), _mark(2, "t2", 4, 4), _detonation(3, "t1", 2, 2, "hit")
	])
	assert_equal(after.size(), 1, "Detonating one of two marks leaves the OTHER active. Got %s." % str(after.size()))
	assert_equal((after[0] as Dictionary).get("telegraph_id"), "t2", "The surviving mark is the un-detonated t2. Got %s." % str((after[0] as Dictionary).get("telegraph_id")))


func _a_boss_telegraph_mark_surfaces_kind_agnostically() -> void:
	# The projection keys on the tile_marked / marked_tile_detonated event ids + telegraph_id — NOT the kind — so the
	# boss telegraph (KIND_LARVAL_AVATAR_TELEGRAPH, a different telegraph_id namespace) surfaces exactly like the ash
	# seer mark, for free.
	var boss_mark: Dictionary = _mark(7, "larval_avatar:boss:7", 6, 1)
	(boss_mark["details"] as Dictionary)["kind"] = "larval_avatar_telegraph"
	var active: Array = TacticalTelegraphOverlay.active_marks([boss_mark])
	assert_equal(active.size(), 1, "A boss-telegraph mark surfaces kind-agnostically. Got %s." % str(active.size()))
	assert_equal((active[0] as Dictionary).get("cell"), {"x": 6, "y": 1}, "The boss mark carries its cell. Got %s." % str((active[0] as Dictionary).get("cell")))
	# And its own detonation clears it.
	var cleared: Array = TacticalTelegraphOverlay.active_marks([boss_mark, _detonation(9, "larval_avatar:boss:7", 6, 1, "hit")])
	assert_equal(cleared.size(), 0, "The boss telegraph clears on its own detonation. Got %s." % str(cleared.size()))


# ---- fog / edge safety ---------------------------------------------------------------------------

func _malformed_or_absent_entries_are_a_safe_no_op() -> void:
	var summary: Array = [
		"not a dictionary",
		{"sequence_id": 1, "event_id": "tile_marked", "details": {"telegraph_id": "no_cell"}},
		{"sequence_id": 2, "event_id": "tile_marked", "details": {"marked_cell": {"x": 1, "y": 1}}},
		{"sequence_id": 3, "event_id": "tile_marked", "details": {"telegraph_id": "bad_cell", "marked_cell": "nope"}},
		_mark(4, "t_ok", 5, 5)
	]
	var active: Array = TacticalTelegraphOverlay.active_marks(summary)
	assert_equal(active.size(), 1, "Only the well-formed mark surfaces; malformed / telegraph-less / cell-less entries are skipped. Got %s." % str(active.size()))
	assert_equal((active[0] as Dictionary).get("telegraph_id"), "t_ok", "The one surviving mark is the well-formed one. Got %s." % str((active[0] as Dictionary).get("telegraph_id")))
	# An empty log yields no active marks.
	assert_equal(TacticalTelegraphOverlay.active_marks([]).size(), 0, "An empty event_log_summary yields no active marks.")


# ---- has_active_marks ----------------------------------------------------------------------------

func _has_active_marks_reflects_state() -> void:
	assert_true(TacticalTelegraphOverlay.has_active_marks([_mark(1, "t1", 3, 3)]), "A pending mark reports active.")
	assert_false(TacticalTelegraphOverlay.has_active_marks([_mark(1, "t1", 3, 3), _detonation(2, "t1", 3, 3, "hit")]), "A resolved mark reports NOT active.")
	assert_false(TacticalTelegraphOverlay.has_active_marks([]), "An empty log reports NOT active.")


# ---- purity --------------------------------------------------------------------------------------

func _active_marks_does_not_mutate_the_input() -> void:
	var summary: Array = [_mark(1, "t1", 2, 2), _mark(2, "t2", 4, 4), _detonation(3, "t1", 2, 2, "hit")]
	var before: Array = summary.duplicate(true)
	TacticalTelegraphOverlay.active_marks(summary)
	assert_equal(summary, before, "active_marks must not mutate the event_log_summary input.")


# ---- fixtures / helpers --------------------------------------------------------------------------

# A tile_marked log entry (the CombatExplanationLog shape: sequence_id / event_id / actor_id / details), carrying the
# telegraph_id + the marked cell the projection reads.
func _mark(sequence_id: int, telegraph_id: String, x: int, y: int) -> Dictionary:
	return {
		"sequence_id": sequence_id,
		"event_id": "tile_marked",
		"actor_id": "ash_seer",
		"details": {"telegraph_id": telegraph_id, "marked_cell": {"x": x, "y": y}}
	}


# A marked_tile_detonated log entry that clears the mark with the SAME telegraph_id (hit or avoided).
func _detonation(sequence_id: int, telegraph_id: String, x: int, y: int, outcome: String) -> Dictionary:
	return {
		"sequence_id": sequence_id,
		"event_id": "marked_tile_detonated",
		"actor_id": "ash_seer",
		"details": {"telegraph_id": telegraph_id, "marked_cell": {"x": x, "y": y}, "outcome": outcome}
	}


# A LETHAL damage_applied (hp_after == 0) on the given victim — the death signal that cancels a mark whose source is
# this entity (Story 14.1: a death is a 0-HP damage apply, no separate death event).
func _death(sequence_id: int, victim_id: String) -> Dictionary:
	return {
		"sequence_id": sequence_id,
		"event_id": "damage_applied",
		"actor_id": "hero",
		"details": {"target_entity_id": victim_id, "final_damage": 9, "amount": 9, "hp_after": 0, "max_hp": 9}
	}


# A NON-lethal damage_applied (hp_after > 0) — does NOT cancel a mark (the source survives to detonate).
func _hit(sequence_id: int, victim_id: String, hp_after: int) -> Dictionary:
	return {
		"sequence_id": sequence_id,
		"event_id": "damage_applied",
		"actor_id": "hero",
		"details": {"target_entity_id": victim_id, "final_damage": 2, "amount": 2, "hp_after": hp_after, "max_hp": 9}
	}


func _assert_exact_keys(actual: Dictionary, expected: Array, message: String) -> void:
	var keys: Array = actual.keys()
	keys.sort()
	var want: Array = expected.duplicate()
	want.sort()
	assert_equal(keys, want, message)
