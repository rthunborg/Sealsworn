extends "res://tests/unit/test_case.gd"

# Story 15.5 (AC3) — the EVENT-OUTCOME VIEW MODEL: the scene-free RefCounted projection the event-node outcome SURFACE
# reads AFTER the player picks a choice, so the node is "shown what happened and what changed before returning to the
# route" (FR54, NFR9) and NEVER resolves invisibly into a route-screen counter increment. This pins the testable
# decisions on the scene-free seam (the overlay Control is verified by construction + the compile guardrail):
#   - the EXACT pinned key contract (OUTCOME_KEYS — a key never silently appears/vanishes);
#   - the signed gold/healing/curse/corruption DELTAS (after - before) + the raised risk-flag ids surfaced honestly;
#   - a SAFE / decline choice projects a zero-net honest outcome (has_outcome == true, is_safe_outcome == true) — the
#     AC4 honesty requirement applied to the event surface (never a bare empty result read as "you got nothing");
#   - FAIL-CLOSED on a null / errored / non-event result (the identity-absent projection — same keys, has_outcome false);
#   - it READS THE EVENT NODE'S EXISTING RESOLUTION DATA (AC3 "no new domain data invented"): a projection built from a
#     REAL ChooseEventOptionCommand result surfaces the deltas/flags that command applied.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ChooseEventOptionCommand = preload("res://scripts/core/commands/choose_event_option_command.gd")
const EventChoiceDefinition = preload("res://scripts/content/definitions/event_choice_definition.gd")
const EventDefinition = preload("res://scripts/content/definitions/event_definition.gd")
const EventOffer = preload("res://scripts/run/event_offer.gd")
const EventOutcomeViewModel = preload("res://scripts/ui/view_models/event_outcome_view_model.gd")
const EventRepository = preload("res://scripts/content/repositories/event_repository.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RunState = preload("res://scripts/run/run_state.gd")

func run() -> Dictionary:
	_projection_carries_exactly_the_pinned_key_set()
	_from_metadata_surfaces_the_signed_deltas_and_flags()
	_safe_choice_is_a_zero_net_honest_outcome()
	_fail_closed_on_null_error_and_non_event_result()
	_reads_a_real_choose_event_command_result()
	_decline_of_a_real_offer_reads_as_a_safe_outcome()
	return result()


# ---- the exact-key contract ----------------------------------------------------------------------

func _projection_carries_exactly_the_pinned_key_set() -> void:
	# The exact-key discipline: EVERY projection (present OR identity-absent) carries EXACTLY OUTCOME_KEYS — no key
	# silently appears or vanishes. Assert both directions (every declared key present; no undeclared key present) on a
	# populated projection AND on the fail-closed identity-absent projection.
	var populated: Dictionary = EventOutcomeViewModel.from_metadata({
		"event_id": "evt", "choice_id": "take", "gold_before": 0, "gold_after": 25,
		"curse_before": 0, "curse_after": 1, "risk_flags": ["elite_chance"], "applies_curse": true
	}).to_dictionary()
	var absent: Dictionary = EventOutcomeViewModel.from_result(null).to_dictionary()

	for projection: Dictionary in [populated, absent]:
		assert_equal(projection.size(), EventOutcomeViewModel.OUTCOME_KEYS.size(), "The projection carries exactly the pinned OUTCOME_KEYS count.")
		for key: String in EventOutcomeViewModel.OUTCOME_KEYS:
			assert_true(projection.has(key), "The projection must carry the pinned key '%s'." % key)
		for key: Variant in projection.keys():
			assert_true(EventOutcomeViewModel.OUTCOME_KEYS.has(String(key)), "The projection must carry NO undeclared key ('%s')." % str(key))


func _from_metadata_surfaces_the_signed_deltas_and_flags() -> void:
	# The AC3 "shown what changed": from the resolution metadata, the projection computes the SIGNED deltas (after -
	# before) for gold/healing/curse/corruption and surfaces the raised risk flags + the curse marker.
	var view: EventOutcomeViewModel = EventOutcomeViewModel.from_metadata({
		"event_id": "salt_bargain",
		"choice_id": "take_the_gold",
		"gold_before": 10, "gold_after": 35,
		"healing_before": 2, "healing_after": 1,
		"curse_before": 0, "curse_after": 1,
		"corruption_before": 3, "corruption_after": 5,
		"risk_flags": ["elite_chance", "salt_marked"],
		"applies_curse": true
	})
	assert_true(view.has_outcome, "A real resolution metadata projects has_outcome == true.")
	assert_equal(view.event_id, "salt_bargain", "The event id is surfaced.")
	assert_equal(view.choice_id, "take_the_gold", "The choice id is surfaced.")
	var data: Dictionary = view.to_dictionary()
	assert_equal(int(data.get("gold_delta")), 25, "The gold delta is after - before (35 - 10 == +25).")
	assert_equal(int(data.get("healing_delta")), -1, "The healing delta is signed (1 - 2 == -1).")
	assert_equal(int(data.get("curse_delta")), 1, "The curse delta is after - before (1 - 0 == +1).")
	assert_equal(int(data.get("corruption_delta")), 2, "The corruption delta is after - before (5 - 3 == +2).")
	assert_equal((data.get("risk_flags") as Array).size(), 2, "Both raised risk flags are surfaced.")
	assert_true((data.get("risk_flags") as Array).has("elite_chance"), "The elite_chance risk flag is surfaced.")
	assert_true(bool(data.get("applies_curse")), "The curse marker is surfaced (the surface highlights the curse side).")
	assert_false(view.is_safe_outcome(), "A resolution with real deltas + raised flags is NOT a safe outcome.")

	# The projection is a FRESH copy (the no-live-handle discipline): a caller's mutation of the returned flags list
	# never perturbs the seam's projection.
	(data.get("risk_flags") as Array).clear()
	assert_equal((view.to_dictionary().get("risk_flags") as Array).size(), 2, "to_dictionary() returns a fresh copy — a caller's mutation does not perturb the seam.")


func _safe_choice_is_a_zero_net_honest_outcome() -> void:
	# AC4 honesty applied to the event surface: a SAFE / decline choice (no gold/healing/curse/corruption change AND no
	# raised flags) still projects has_outcome == true with all-zero deltas + is_safe_outcome == true — the honest "you
	# chose safely — nothing changed", NEVER a bare empty result that reads as "you got nothing".
	var view: EventOutcomeViewModel = EventOutcomeViewModel.from_metadata({
		"event_id": "quiet_shrine",
		"choice_id": "walk_away",
		"gold_before": 12, "gold_after": 12,
		"healing_before": 1, "healing_after": 1,
		"curse_before": 0, "curse_after": 0,
		"corruption_before": 0, "corruption_after": 0,
		"risk_flags": [],
		"applies_curse": false
	})
	assert_true(view.has_outcome, "A safe choice still HAS an outcome (it resolved — not a bare empty result).")
	assert_true(view.is_safe_outcome(), "A zero-net safe choice with no raised flags reads as a safe outcome.")
	var data: Dictionary = view.to_dictionary()
	assert_equal(int(data.get("gold_delta")), 0, "A safe choice has a zero gold delta.")
	assert_equal(int(data.get("curse_delta")), 0, "A safe choice has a zero curse delta.")
	assert_true((data.get("risk_flags") as Array).is_empty(), "A safe choice raised no risk flags.")


func _fail_closed_on_null_error_and_non_event_result() -> void:
	# FAIL-CLOSED: a null / errored / non-event result projects the identity-absent outcome (has_outcome == false, zero
	# values) — never a crash, never a half-entry. A consumer branches on has_outcome without inspecting the empty fields.
	var from_null: EventOutcomeViewModel = EventOutcomeViewModel.from_result(null)
	assert_false(from_null.has_outcome, "A null result projects the identity-absent outcome (has_outcome == false).")
	assert_false(from_null.is_safe_outcome(), "An identity-absent outcome is NOT a safe outcome (it has no outcome at all).")

	var errored: ActionResult = ActionResult.error(&"invalid_event_choice", {"command": "choose_event_option"})
	var from_error: EventOutcomeViewModel = EventOutcomeViewModel.from_result(errored)
	assert_false(from_error.has_outcome, "An errored result projects the identity-absent outcome (fail-closed).")

	# A metadata dict WITHOUT an event_id (a non-event result — e.g. a placeholder resolve) is identity-absent.
	var non_event: EventOutcomeViewModel = EventOutcomeViewModel.from_metadata({"resolution": "already_cleared_noop"})
	assert_false(non_event.has_outcome, "A non-event metadata dict (no event_id) is identity-absent.")


# ---- reads the REAL ChooseEventOptionCommand resolution data (AC3 "no new domain data invented") ----

# Build a minimal run parked on an event node with a pending offer, and an EventRepository whose one event has a
# risk-taking choice (+25 gold, +1 curse, raises elite_chance) and a decline choice (nothing). Mirrors the
# test_run_route_position_save event-command setup.
func _run_with_pending_event_offer() -> RunState:
	var node: RouteNode = RouteNode.new("evt-0", RouteNode.TYPE_EVENT, 0, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([node], "evt-0", [])
	var run: RunState = RunState.new(RunState.PHASE_ACTIVE_ROUTE, 4242, false, true, route)
	run.pending_event_offer = EventOffer.new(&"salt_bargain", EventOffer.STATUS_PENDING, ["take_risk", "decline"], &"", "events", 1, 1, 123)
	return run


func _event_repository() -> EventRepository:
	return EventRepository.create_repository_from_definitions([
		EventDefinition.new(
			&"salt_bargain", "The Salt Bargain", "A risk/reward choice.",
			[
				EventChoiceDefinition.new(&"take_risk", "Take 25 gold, 1 curse, raise the elite flag.", 25, 0, 1, 0, 0, 0, ["elite_chance"]),
				EventChoiceDefinition.new(&"decline", "Walk away untouched.", 0, 0, 0, 0, 0, 0, [])
			]
		)
	])


func _reads_a_real_choose_event_command_result() -> void:
	# The AC3 seam end-to-end: project the REAL ChooseEventOptionCommand result (the command that applies both the reward
	# and the risk, raises the flags, and carries the before/after deltas in its metadata). The projection must surface
	# the SAME deltas/flags the command applied — proving it reads the event node's EXISTING resolution data, invents none.
	var run: RunState = _run_with_pending_event_offer()
	var choose: ActionResult = ChooseEventOptionCommand.new(&"take_risk", 1, _event_repository()).execute(run)
	assert_true(choose.succeeded, "Setup: the risk-taking choice should resolve: %s" % choose.metadata)

	var view: EventOutcomeViewModel = EventOutcomeViewModel.from_result(choose)
	assert_true(view.has_outcome, "The projection of a resolved event command HAS an outcome.")
	assert_equal(view.event_id, "salt_bargain", "The projection reads the command's event id.")
	assert_equal(view.choice_id, "take_risk", "The projection reads the command's choice id.")
	var data: Dictionary = view.to_dictionary()
	assert_equal(int(data.get("gold_delta")), 25, "The projection surfaces the command's applied +25 gold.")
	assert_equal(int(data.get("curse_delta")), 1, "The projection surfaces the command's applied +1 curse.")
	assert_true((data.get("risk_flags") as Array).has("elite_chance"), "The projection surfaces the command's raised risk flag.")
	assert_true(bool(data.get("applies_curse")), "The projection surfaces the command's curse marker.")
	assert_false(view.is_safe_outcome(), "A real risk-taking resolution is not a safe outcome.")


func _decline_of_a_real_offer_reads_as_a_safe_outcome() -> void:
	# A DECLINE of the SAME real offer resolves with a zero-net change + no raised flags -> the projection reads as a safe
	# outcome (the honest "nothing changed" — the no-soft-lock decline path is always a valid, honestly-surfaced resolution).
	var run: RunState = _run_with_pending_event_offer()
	var choose: ActionResult = ChooseEventOptionCommand.new(&"decline", 1, _event_repository()).execute(run)
	assert_true(choose.succeeded, "Setup: the decline choice should resolve: %s" % choose.metadata)

	var view: EventOutcomeViewModel = EventOutcomeViewModel.from_result(choose)
	assert_true(view.has_outcome, "A resolved decline HAS an outcome (it resolved — not a bare empty result).")
	assert_true(view.is_safe_outcome(), "A decline of the offer reads as a zero-net safe outcome (honest 'nothing changed').")
	var data: Dictionary = view.to_dictionary()
	assert_equal(int(data.get("gold_delta")), 0, "The declined choice applied no gold change.")
	assert_equal(int(data.get("curse_delta")), 0, "The declined choice applied no curse change.")
	assert_true((data.get("risk_flags") as Array).is_empty(), "The declined choice raised no risk flags.")
