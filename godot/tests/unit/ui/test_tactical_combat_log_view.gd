extends "res://tests/unit/test_case.gd"

# Story 14.3 (Task 2 — the F6/F7 in-combat event log) — TacticalCombatLogView coverage. Proves the scene-free seam
# reads ONLY the pinned VM `event_log_summary` slot and projects the log-region content:
#   - the EXACT VIEW_KEYS set for BOTH a populated and an empty projection (a key never silently appears/vanishes);
#   - a VM with several entries (a move, a hit, a death, a telegraph, a victory) projects has_entries: true and the
#     expected per-action lines (order preserved) — the damage amounts read inline off each line;
#   - an empty VM projects has_entries: false / entry_count: 0 / no lines (the honest empty state, not "0 events");
#   - the lines are TAIL-limited to the last MAX_LINES (newest last) so the small region never overflows;
#   - the LIVE data flow (Task 1): real DomainEvents -> CombatExplanationLog.build_entries -> the VM
#     event_log_summary slot (carrying the pinned CombatExplanationLog entry shape) -> a non-empty log view;
#   - zero mutation of the input VM dict; reads only the pinned slot.
# The seam exposes NO structured `damage_numbers` slot (Round-1 review decision — the presenter never consumed it;
# damage reaches the screen via the inline line text + the feedback plan's floating numbers), so this suite pins only
# the lines/count/has_entries output the presenter actually renders.
# str() (never eager String(nullable)) is used in assert messages (the 14.1 retro test-honesty note).

const BoardFixtureFactory = preload("res://tests/fixtures/tactical/board_fixture_factory.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")
const CombatExplanationLog = preload("res://scripts/tactical/outcomes/combat_explanation_log.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")
const TacticalBoardViewModel = preload("res://scripts/ui/view_models/tactical_board_view_model.gd")
const TacticalCombatLogView = preload("res://scripts/ui/view_models/tactical_combat_log_view.gd")
const TacticalTurnState = preload("res://scripts/tactical/turns/tactical_turn_state.gd")

func run() -> Dictionary:
	_view_keys_are_exact_for_populated_and_empty()
	_populated_vm_projects_lines()
	_empty_vm_projects_no_entries()
	_lines_are_tail_limited_to_the_last_max_lines()
	_live_events_flow_through_the_vm_into_the_log_view()
	_projection_does_not_mutate_the_input()
	return result()


# ---- exact-key discipline ------------------------------------------------------------------------

func _view_keys_are_exact_for_populated_and_empty() -> void:
	var empty: Dictionary = TacticalCombatLogView.from_board_vm({})
	_assert_exact_keys(empty, TacticalCombatLogView.VIEW_KEYS, "An empty log view must carry EXACTLY the VIEW_KEYS set.")
	var populated: Dictionary = TacticalCombatLogView.from_board_vm({"event_log_summary": [_hit_entry(2, "enemy_1", 3, 10, 7, 10)]})
	_assert_exact_keys(populated, TacticalCombatLogView.VIEW_KEYS, "A populated log view must carry the SAME VIEW_KEYS set.")


# ---- populated projection ------------------------------------------------------------------------

func _populated_vm_projects_lines() -> void:
	var vm: Dictionary = {
		"event_log_summary": [
			_entry(1, "entity_moved", "hero", "hero moved from (0,2) to (1,2).", {"from": {"x": 0, "y": 2}, "to": {"x": 1, "y": 2}}),
			_hit_entry(2, "enemy_1", 3, 10, 7, 10),
			_death_entry(3, "enemy_1", 7, 7, 10),
			_entry(4, "tile_marked", "ash_seer", "ash_seer marked hero at (3,3).", {"marked_cell": {"x": 3, "y": 3}}),
			_entry(5, "level_victory_reached", "", "Victory reached.", {"outcome": "victory"})
		]
	}
	var view: Dictionary = TacticalCombatLogView.from_board_vm(vm)
	assert_equal(view.get("has_entries"), true, "A populated VM projects has_entries: true.")
	assert_equal(view.get("entry_count"), 5, "entry_count reflects every summary entry. Got %s." % str(view.get("entry_count")))
	assert_equal(view.get("lines"), [
		"hero moved from (0,2) to (1,2).",
		"enemy_1 took 3 physical damage from hero.",
		"enemy_1 took 7 physical damage from hero.",
		"ash_seer marked hero at (3,3).",
		"Victory reached."
	], "The log lines are the per-action summaries in order. Got %s." % str(view.get("lines")))
	# The damage amount reads INLINE off the hit/death lines (the presenter renders these lines verbatim) — the seam
	# exposes no separate structured damage-number slot (the Round-1 review pruned that unconsumed output).
	assert_true(String((view.get("lines", []) as Array)[1]).contains("3 physical damage"), "The hit line carries the inline damage amount. Got %s." % str(view.get("lines")))


# ---- empty projection ----------------------------------------------------------------------------

func _empty_vm_projects_no_entries() -> void:
	var view: Dictionary = TacticalCombatLogView.from_board_vm({})
	assert_equal(view.get("has_entries"), false, "An empty VM projects has_entries: false (not the F6 '0 events').")
	assert_equal(view.get("entry_count"), 0, "An empty VM projects entry_count: 0. Got %s." % str(view.get("entry_count")))
	assert_equal((view.get("lines", []) as Array).size(), 0, "An empty VM projects no lines. Got %s." % str(view.get("lines")))
	# A VM whose slot is present-but-empty is also empty (no fabricated entries).
	assert_equal(TacticalCombatLogView.from_board_vm({"event_log_summary": []}).get("has_entries"), false, "A present-but-empty slot is still empty.")


# ---- tail-limiting -------------------------------------------------------------------------------

func _lines_are_tail_limited_to_the_last_max_lines() -> void:
	var entries: Array = []
	var total: int = TacticalCombatLogView.MAX_LINES + 3
	for index: int in range(total):
		entries.append(_entry(index + 1, "entity_moved", "hero", "line %d" % index, {}))
	var view: Dictionary = TacticalCombatLogView.from_board_vm({"event_log_summary": entries})
	var lines: Array = view.get("lines", [])
	assert_equal(lines.size(), TacticalCombatLogView.MAX_LINES, "The lines tail-limit to MAX_LINES. Got %s." % str(lines.size()))
	assert_equal(view.get("entry_count"), total, "entry_count still reflects the FULL log, not the tail. Got %s." % str(view.get("entry_count")))
	assert_equal(lines[0], "line 3", "The tail keeps the LAST MAX_LINES (newest last), dropping the oldest. Got %s." % str(lines[0]))
	assert_equal(lines[lines.size() - 1], "line %d" % (total - 1), "The newest line is last. Got %s." % str(lines[lines.size() - 1]))


# ---- the LIVE data flow (Task 1: session events -> CombatExplanationLog -> the VM slot) ----------

func _live_events_flow_through_the_vm_into_the_log_view() -> void:
	var board: BoardState = BoardFixtureFactory.micro_combat_board()
	var turn_state: TacticalTurnState = TacticalTurnState.new(1, TacticalTurnState.Phase.PLAYER_PLANNING, &"hero")
	var events: Array[DomainEvent] = []
	events.append(DomainEvent.entity_moved(1, &"hero", Vector2i(0, 2), Vector2i(1, 2), 1, 3))
	events.append(DomainEvent.damage_applied(2, &"hero", &"enemy_iron", 3, 10, 7, 10))
	events.append(DomainEvent.level_victory_reached(3, 1, 0, ["enemy_iron"], 2, "Victory reached."))
	var entries: Array[Dictionary] = CombatExplanationLog.new().build_entries(events)
	# render() sources these through from_domain's EXISTING event_log_summary option (a real board so from_domain does
	# not short-circuit on null). This proves the Task 1 flow: the emitted domain events reach the VM slot.
	var vm: Dictionary = TacticalBoardViewModel.from_domain(board, turn_state, {"event_log_summary": entries}).to_dictionary()
	var summary: Array = vm.get("event_log_summary", [])
	assert_equal(summary.size(), 3, "The VM event_log_summary carries the sourced entries. Got %s." % str(summary.size()))
	var first: Dictionary = summary[0] if summary.size() > 0 else {}
	for key: String in ["entry_id", "sequence_id", "event_id", "actor_id", "summary", "details"]:
		assert_true(first.has(key), "The sourced entry carries the CombatExplanationLog key '%s'. Got keys %s." % [key, str(first.keys())])

	var view: Dictionary = TacticalCombatLogView.from_board_vm(vm)
	assert_equal(view.get("has_entries"), true, "Sourced live events make the log non-empty (the F6/F7 fix).")
	assert_equal((view.get("lines", []) as Array).size(), 3, "The log renders one line per sourced entry. Got %s." % str(view.get("lines")))


# ---- purity --------------------------------------------------------------------------------------

func _projection_does_not_mutate_the_input() -> void:
	var vm: Dictionary = {"event_log_summary": [_hit_entry(2, "enemy_1", 3, 10, 7, 10)]}
	var before: Dictionary = vm.duplicate(true)
	TacticalCombatLogView.from_board_vm(vm)
	assert_equal(vm, before, "from_board_vm must not mutate the input VM dict.")


# ---- fixtures / helpers --------------------------------------------------------------------------

func _entry(sequence_id: int, event_id: String, actor_id: String, summary: String, details: Dictionary) -> Dictionary:
	return {
		"entry_id": "%s:%d" % [event_id, sequence_id],
		"sequence_id": sequence_id,
		"event_id": event_id,
		"actor_id": actor_id,
		"summary": summary,
		"details": details
	}


func _hit_entry(sequence_id: int, target_id: String, amount: int, hp_before: int, hp_after: int, max_hp: int) -> Dictionary:
	return _entry(sequence_id, "damage_applied", "hero", "%s took %d physical damage from hero." % [target_id, amount], {
		"target_entity_id": target_id,
		"amount": amount,
		"final_damage": amount,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"damage_type": "physical"
	})


func _death_entry(sequence_id: int, target_id: String, amount: int, hp_before: int, max_hp: int) -> Dictionary:
	return _hit_entry(sequence_id, target_id, amount, hp_before, 0, max_hp)


func _assert_exact_keys(actual: Dictionary, expected: Array, message: String) -> void:
	var keys: Array = actual.keys()
	keys.sort()
	var want: Array = expected.duplicate()
	want.sort()
	assert_equal(keys, want, message)
