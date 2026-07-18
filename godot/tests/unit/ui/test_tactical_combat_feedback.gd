extends "res://tests/unit/test_case.gd"

# Story 14.3 (Task 3 — the F8 move/hit/death/telegraph animation plan) — TacticalCombatFeedback coverage. Proves the
# scene-free seam reads ONLY the pinned VM `event_log_summary` + `occupants` slots and decides WHAT to animate for the
# events NEWER than since_sequence_id:
#   - the EXACT PLAN_KEYS set for BOTH a populated and an empty plan (a key never silently appears/vanishes);
#   - a batch (a move from->to, a non-lethal hit, a LETHAL hit hp_after == 0, a telegraph) surfaces the move (from/to),
#     the hits (cell resolved from occupants + amount), the DEATH only for the hp_after == 0 hit (cell resolved), the
#     telegraph (marked cell), and last_sequence_id == the batch max;
#   - the REAL sprite-slide inputs (Round-1 review decision): each move carries the actor_id (the join key to the VM
#     occupant whose own sprite the presenter interpolates) + from/to endpoints, and several SIMULTANEOUS moves each
#     surface independently (the presenter slides every moving unit's own sprite, not one shared marker);
#   - a since_sequence_id at/above the batch max re-animates NOTHING (empty plan — each event animates once);
#   - a damage entry whose target is ABSENT from occupants yields no hit/death (a safe no-op, never a fabricated cell);
#   - a damage entry with NO hp_after is a hit but NOT a death (no fabricated death);
#   - has_feedback reflects whether any entry is present;
#   - zero mutation of the input; reads only the two pinned slots (passed directly, no other VM read).
# str() (never eager String(nullable)) is used in assert messages (the 14.1 retro test-honesty note).

const TacticalCombatFeedback = preload("res://scripts/ui/view_models/tactical_combat_feedback.gd")

func run() -> Dictionary:
	_plan_keys_are_exact_for_populated_and_empty()
	_batch_surfaces_moves_hits_deaths_and_telegraphs()
	_moves_carry_the_sprite_slide_inputs()
	_since_at_or_above_batch_max_re_animates_nothing()
	_damage_on_an_absent_occupant_is_a_safe_no_op()
	_damage_without_hp_after_is_a_hit_but_not_a_death()
	_has_feedback_reflects_plan_contents()
	_plan_does_not_mutate_the_input()
	return result()


# ---- exact-key discipline ------------------------------------------------------------------------

func _plan_keys_are_exact_for_populated_and_empty() -> void:
	var empty: Dictionary = TacticalCombatFeedback.plan([], 0, [])
	_assert_exact_keys(empty, TacticalCombatFeedback.PLAN_KEYS, "An empty plan must carry EXACTLY the PLAN_KEYS set.")
	var populated: Dictionary = TacticalCombatFeedback.plan(_batch(), 0, _occupants())
	_assert_exact_keys(populated, TacticalCombatFeedback.PLAN_KEYS, "A populated plan must carry the SAME PLAN_KEYS set.")


# ---- the main batch ------------------------------------------------------------------------------

func _batch_surfaces_moves_hits_deaths_and_telegraphs() -> void:
	var plan: Dictionary = TacticalCombatFeedback.plan(_batch(), 0, _occupants())

	var moves: Array = plan.get("moves", [])
	assert_equal(moves.size(), 1, "The batch surfaces one move. Got %s." % str(moves.size()))
	var move: Dictionary = moves[0] if moves.size() > 0 else {}
	assert_equal(move.get("actor_id"), "hero", "The move carries the actor. Got %s." % str(move.get("actor_id")))
	assert_equal(move.get("from"), {"x": 0, "y": 2}, "The move slides from the origin cell. Got %s." % str(move.get("from")))
	assert_equal(move.get("to"), {"x": 1, "y": 2}, "The move slides to the destination cell. Got %s." % str(move.get("to")))

	var hits: Array = plan.get("hits", [])
	assert_equal(hits.size(), 2, "Both damage entries surface as hits. Got %s." % str(hits.size()))
	var first_hit: Dictionary = hits[0] if hits.size() > 0 else {}
	assert_equal(first_hit.get("cell"), {"x": 2, "y": 2}, "The hit cell is resolved from occupants (id -> position). Got %s." % str(first_hit.get("cell")))
	assert_equal(first_hit.get("target_id"), "enemy_iron", "The hit names the victim. Got %s." % str(first_hit.get("target_id")))
	assert_equal(first_hit.get("amount"), 3, "The hit reads the final damage. Got %s." % str(first_hit.get("amount")))

	var deaths: Array = plan.get("deaths", [])
	assert_equal(deaths.size(), 1, "ONLY the hp_after == 0 hit is a death. Got %s." % str(deaths.size()))
	var death: Dictionary = deaths[0] if deaths.size() > 0 else {}
	assert_equal(death.get("entity_id"), "enemy_iron", "The death names the fallen entity. Got %s." % str(death.get("entity_id")))
	assert_equal(death.get("cell"), {"x": 2, "y": 2}, "The death cell resolves (a dead victim is still an occupant). Got %s." % str(death.get("cell")))

	var telegraphs: Array = plan.get("telegraphs", [])
	assert_equal(telegraphs.size(), 1, "The batch surfaces one telegraph. Got %s." % str(telegraphs.size()))
	assert_equal((telegraphs[0] as Dictionary).get("cell"), {"x": 3, "y": 3}, "The telegraph reads the marked cell. Got %s." % str((telegraphs[0] as Dictionary).get("cell")))

	assert_equal(plan.get("last_sequence_id"), 4, "last_sequence_id is the batch max. Got %s." % str(plan.get("last_sequence_id")))


# ---- the sprite-slide plan output (Round-1 review decision — the REAL sprite slide) --------------

# The move plan carries EXACTLY the inputs the presenter needs to slide each unit's OWN sprite: the actor_id (the join
# key to the VM occupant whose sprite/marker/HP bar is interpolated) + the from/to endpoints (sourced from the event
# payload, NOT from occupants — so a move surfaces even with an empty occupants array). A batch with several
# SIMULTANEOUS moves (a hero move + an enemy-phase move) surfaces each as an INDEPENDENT move entry, so the presenter
# slides every moving unit's own sprite rather than one shared marker.
func _moves_carry_the_sprite_slide_inputs() -> void:
	var summary: Array = [
		{
			"sequence_id": 1,
			"event_id": "entity_moved",
			"actor_id": "hero",
			"details": {"from": {"x": 0, "y": 2}, "to": {"x": 1, "y": 2}}
		},
		{
			"sequence_id": 2,
			"event_id": "entity_moved",
			"actor_id": "enemy_iron",
			"details": {"from": {"x": 4, "y": 2}, "to": {"x": 3, "y": 2}}
		}
	]
	# Empty occupants on purpose: the move endpoints come from the event payload, so both slides still surface.
	var plan: Dictionary = TacticalCombatFeedback.plan(summary, 0, [])
	var moves: Array = plan.get("moves", [])
	assert_equal(moves.size(), 2, "Each simultaneous move surfaces independently (the presenter slides each unit's own sprite). Got %s." % str(moves.size()))
	var by_actor: Dictionary = {}
	for move_value: Variant in moves:
		var move: Dictionary = move_value
		by_actor[String(move.get("actor_id", ""))] = move
	assert_true(by_actor.has("hero"), "The hero move surfaces with its actor_id (the sprite-slide join key). Got %s." % str(by_actor.keys()))
	assert_true(by_actor.has("enemy_iron"), "The enemy move surfaces with its own actor_id. Got %s." % str(by_actor.keys()))
	var hero_move: Dictionary = by_actor.get("hero", {})
	assert_equal(hero_move.get("from"), {"x": 0, "y": 2}, "The hero slide reads its origin cell (the sprite's start). Got %s." % str(hero_move.get("from")))
	assert_equal(hero_move.get("to"), {"x": 1, "y": 2}, "The hero slide reads its destination cell (the sprite's end). Got %s." % str(hero_move.get("to")))
	var enemy_move: Dictionary = by_actor.get("enemy_iron", {})
	assert_equal(enemy_move.get("from"), {"x": 4, "y": 2}, "The enemy slide reads its own origin cell. Got %s." % str(enemy_move.get("from")))
	assert_equal(enemy_move.get("to"), {"x": 3, "y": 2}, "The enemy slide reads its own destination cell. Got %s." % str(enemy_move.get("to")))


# ---- animate-once discipline ---------------------------------------------------------------------

func _since_at_or_above_batch_max_re_animates_nothing() -> void:
	var plan: Dictionary = TacticalCombatFeedback.plan(_batch(), 4, _occupants())
	assert_false(TacticalCombatFeedback.has_feedback(plan), "A since at the batch max re-animates nothing (each event animates once).")
	assert_equal((plan.get("moves", []) as Array).size(), 0, "No moves re-animate.")
	assert_equal((plan.get("hits", []) as Array).size(), 0, "No hits re-animate.")
	assert_equal((plan.get("deaths", []) as Array).size(), 0, "No deaths re-animate.")
	assert_equal((plan.get("telegraphs", []) as Array).size(), 0, "No telegraphs re-animate.")
	assert_equal(plan.get("last_sequence_id"), 4, "last_sequence_id holds at the batch max. Got %s." % str(plan.get("last_sequence_id")))
	# A since ABOVE the max is also inert (the presenter never regresses the high-water mark).
	assert_false(TacticalCombatFeedback.has_feedback(TacticalCombatFeedback.plan(_batch(), 9, _occupants())), "A since above the batch max is inert.")


# ---- fog / edge safety ---------------------------------------------------------------------------

func _damage_on_an_absent_occupant_is_a_safe_no_op() -> void:
	# A damage entry whose victim is not in occupants (fog / edge) surfaces NO hit and NO death (never a fabricated
	# cell) — even the lethal one.
	var summary: Array = [
		_damage_entry(5, "ghost_9", 3, 4),
		_damage_entry(6, "ghost_9", 9, 0)
	]
	var plan: Dictionary = TacticalCombatFeedback.plan(summary, 0, _occupants())
	assert_equal((plan.get("hits", []) as Array).size(), 0, "An absent-occupant damage yields no hit. Got %s." % str(plan.get("hits")))
	assert_equal((plan.get("deaths", []) as Array).size(), 0, "An absent-occupant lethal damage yields no death. Got %s." % str(plan.get("deaths")))
	assert_equal(plan.get("last_sequence_id"), 6, "The high-water mark still advances past the skipped events. Got %s." % str(plan.get("last_sequence_id")))


func _damage_without_hp_after_is_a_hit_but_not_a_death() -> void:
	# A damage entry that omits hp_after must NOT be mistaken for a death (the hp_after == 0 death signal is explicit).
	var entry: Dictionary = {
		"sequence_id": 7,
		"event_id": "damage_applied",
		"actor_id": "hero",
		"details": {"target_entity_id": "enemy_iron", "final_damage": 2, "amount": 2}
	}
	var plan: Dictionary = TacticalCombatFeedback.plan([entry], 0, _occupants())
	assert_equal((plan.get("hits", []) as Array).size(), 1, "A damage with no hp_after is still a hit. Got %s." % str(plan.get("hits")))
	assert_equal((plan.get("deaths", []) as Array).size(), 0, "A damage with no hp_after is NOT a death. Got %s." % str(plan.get("deaths")))


# ---- has_feedback --------------------------------------------------------------------------------

func _has_feedback_reflects_plan_contents() -> void:
	assert_true(TacticalCombatFeedback.has_feedback(TacticalCombatFeedback.plan(_batch(), 0, _occupants())), "A batch with new events has feedback.")
	assert_false(TacticalCombatFeedback.has_feedback(TacticalCombatFeedback.plan([], 0, [])), "An empty log has no feedback.")


# ---- purity --------------------------------------------------------------------------------------

func _plan_does_not_mutate_the_input() -> void:
	var summary: Array = _batch()
	var summary_before: Array = summary.duplicate(true)
	var occupants: Array = _occupants()
	var occupants_before: Array = occupants.duplicate(true)
	TacticalCombatFeedback.plan(summary, 0, occupants)
	assert_equal(summary, summary_before, "plan must not mutate the event_log_summary input.")
	assert_equal(occupants, occupants_before, "plan must not mutate the occupants input.")


# ---- fixtures / helpers --------------------------------------------------------------------------

# A committed-action batch: hero moves (seq 1), a non-lethal hit (seq 2), a LETHAL hit hp_after == 0 (seq 3), an Ash
# Seer telegraph (seq 4). The CombatExplanationLog entry shape (sequence_id / event_id / actor_id / details).
func _batch() -> Array:
	return [
		{
			"sequence_id": 1,
			"event_id": "entity_moved",
			"actor_id": "hero",
			"details": {"from": {"x": 0, "y": 2}, "to": {"x": 1, "y": 2}}
		},
		_damage_entry(2, "enemy_iron", 3, 7),
		_damage_entry(3, "enemy_iron", 7, 0),
		{
			"sequence_id": 4,
			"event_id": "tile_marked",
			"actor_id": "ash_seer",
			"details": {"marked_cell": {"x": 3, "y": 3}}
		}
	]


func _damage_entry(sequence_id: int, target_id: String, amount: int, hp_after: int) -> Dictionary:
	return {
		"sequence_id": sequence_id,
		"event_id": "damage_applied",
		"actor_id": "hero",
		"details": {
			"target_entity_id": target_id,
			"final_damage": amount,
			"amount": amount,
			"hp_after": hp_after,
			"max_hp": 10
		}
	}


# The VM occupants (id -> current cell) the damage cell resolution reads. enemy_iron sits at (2,2) — a dead victim is
# still an occupant at its death cell (Story 14.1), so the death cell resolves too.
func _occupants() -> Array:
	return [
		{"entity_id": "hero", "position": {"x": 1, "y": 2}},
		{"entity_id": "enemy_iron", "position": {"x": 2, "y": 2}}
	]


func _assert_exact_keys(actual: Dictionary, expected: Array, message: String) -> void:
	var keys: Array = actual.keys()
	keys.sort()
	var want: Array = expected.duplicate()
	want.sort()
	assert_equal(keys, want, message)
