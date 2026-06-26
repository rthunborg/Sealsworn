extends "res://tests/unit/test_case.gd"

# Story 5.5 Task 5.3 — the CONSOLIDATED 5.4 RE-DERIVE-BOTH obligation, CLOSED in-story. A run resumed from a
# route-position save persists the CLASS ID ONLY: restored_run.starting_kit AND restored_run.rules_resolver are
# BOTH null by design (live RefCounted services re-derived on restore, the 4.6 inert-RngStreamSet precedent).
# This test proves the ONE canonical re-derive helper (ClassStartSummaryViewModel.re_derive_kit /
# re_derive_resolver) re-derives BOTH deterministically from the restored selected_class_id so the re-derived
# kit/resolver/explanations EQUAL a fresh RunOrchestrator.start(same_seed, false, same_class_id)'s.
#
# It EXTENDS the 5.3 kit re-derive precedent (test_run_route_position_save.gd::_kit_re_derives_from_restored_
# class_id) to the RESOLVER, and is the in-story closure of the deferred-work "owner Story 5.5" obligation.
#
# Pins:
#   - a class run's route-position save restores with starting_kit == null AND rules_resolver == null (null by
#     design — the save persists class-id only);
#   - the Task-3 helper re-derives the kit to byte-equal the kit RunStartCommand recorded on a fresh start;
#   - the Task-3 helper re-derives the resolver to byte-equal a fresh start's registered_passive_ids + the
#     per-window explanations (run_started + before_attack), in the SAME stable registration order;
#   - an empty/unknown class id re-derives null/empty (fail-closed, back-compat — a pre-5.x payload carries no
#     class).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ClassStartSummaryViewModel = preload("res://scripts/ui/view_models/class_start_summary_view_model.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunResumeService = preload("res://scripts/save/run_resume_service.gd")
const RunSnapshot = preload("res://scripts/save/snapshots/run_snapshot.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const SaveRepository = preload("res://scripts/save/save_repository.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")

const SAVE_PATH := "user://test_class_start_re_derive.json"
const SELECTABLE_CLASS_IDS: Array[StringName] = [&"warrior", &"pyromancer", &"ranger"]

func run() -> Dictionary:
	_route_position_restore_yields_null_kit_and_resolver_then_re_derives_both()
	_re_derived_resolver_explanations_match_a_fresh_start()
	_empty_and_unknown_class_re_derive_nothing()
	_cleanup()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _orchestrator_parked_with_class(seed_value: int, advances: int, class_id: StringName) -> RunOrchestrator:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(seed_value, false, class_id).succeeded, "Seed %d (%s): class start should succeed." % [seed_value, class_id])
	var steps: int = 0
	while steps < advances and not orchestrator.run.is_terminal():
		var current: RouteNode = orchestrator.run.route.node_by_id(orchestrator.run.route.current_node_id)
		if current.type == RouteNode.TYPE_BOSS:
			break
		assert_true(orchestrator.resolve_current_node().succeeded, "Seed %d (%s): resolve should succeed at step %d." % [seed_value, class_id, steps])
		assert_true(orchestrator.advance_to_first_eligible().succeeded, "Seed %d (%s): advance should succeed at step %d." % [seed_value, class_id, steps])
		steps += 1
	assert_false(orchestrator.run.is_terminal(), "Seed %d (%s): the parked class run must NOT be terminal." % [seed_value, class_id])
	return orchestrator


func _write_through_repository(snapshot: RunSnapshot) -> void:
	var write_result: ActionResult = SaveRepository.new().write_run_snapshot(snapshot, SAVE_PATH)
	assert_true(write_result.succeeded, "Writing the route-position snapshot should succeed: %s" % write_result.metadata)


# ---- the re-derive-both proof --------------------------------------------------------------------

func _route_position_restore_yields_null_kit_and_resolver_then_re_derives_both() -> void:
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		# Fresh start -> the authoritative kit + resolver RunStartCommand seated.
		var fresh_orchestrator: RunOrchestrator = RunOrchestrator.new()
		assert_true(fresh_orchestrator.start(42, false, class_id).succeeded, "%s: fresh start should succeed for the re-derive reference." % class_id)
		var recorded_kit: StartingKit = fresh_orchestrator.run.starting_kit
		var recorded_resolver: RulesResolver = fresh_orchestrator.run.rules_resolver
		assert_true(recorded_kit != null, "%s: the fresh start should record a kit." % class_id)
		assert_true(recorded_resolver != null, "%s: the fresh start should seat a resolver." % class_id)

		# Park + save + restore through the REAL repository round-trip.
		var parked: RunOrchestrator = _orchestrator_parked_with_class(42, 2, class_id)
		var snapshot: RunSnapshot = parked.compose_route_position_snapshot()
		_write_through_repository(snapshot)
		var restore: ActionResult = RunResumeService.new().resume_route_position(SAVE_PATH)
		assert_true(restore.succeeded, "%s: route-position resume should succeed: %s" % [class_id, restore.metadata])
		var restored_run: RunState = restore.metadata.get("run_state") as RunState

		# The consolidated obligation's PRECONDITION: both live services are null by design after restore.
		assert_equal(restored_run.selected_class_id, class_id, "%s: the restored run must carry the class id." % class_id)
		assert_true(restored_run.starting_kit == null, "%s: restored_run.starting_kit must be NULL by design (re-derive obligation)." % class_id)
		assert_true(restored_run.rules_resolver == null, "%s: restored_run.rules_resolver must be NULL by design (re-derive obligation)." % class_id)

		# RE-DERIVE both from the restored class id via the ONE canonical helper.
		var re_derived_kit: StartingKit = ClassStartSummaryViewModel.re_derive_kit(restored_run.selected_class_id)
		var re_derived_resolver: RulesResolver = ClassStartSummaryViewModel.re_derive_resolver(restored_run.selected_class_id)
		assert_true(re_derived_kit != null, "%s: re_derive_kit must return a kit for the restored class." % class_id)
		assert_true(re_derived_resolver != null, "%s: re_derive_resolver must return a resolver for the restored class." % class_id)

		# The re-derived kit byte-equals the kit RunStartCommand recorded on a fresh start.
		assert_equal(JSON.stringify(re_derived_kit.to_dictionary()), JSON.stringify(recorded_kit.to_dictionary()), "%s: the re-derived kit must byte-match the fresh-start kit (deterministic pure function)." % class_id)
		# The re-derived resolver registers the SAME ids in the SAME order as a fresh start.
		assert_equal(str(re_derived_resolver.registered_passive_ids()), str(recorded_resolver.registered_passive_ids()), "%s: the re-derived resolver must register the same passive ids in the same order." % class_id)


func _re_derived_resolver_explanations_match_a_fresh_start() -> void:
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		var fresh_orchestrator: RunOrchestrator = RunOrchestrator.new()
		assert_true(fresh_orchestrator.start(42, false, class_id).succeeded, "%s: fresh start should succeed." % class_id)
		var fresh_resolver: RulesResolver = fresh_orchestrator.run.rules_resolver

		var re_derived_resolver: RulesResolver = ClassStartSummaryViewModel.re_derive_resolver(class_id)
		# The per-window explanations (the AC2 surface) match byte-for-byte across the two windows the baselines
		# declare (run_started for the equipment-synergy passive, before_attack for the class passive).
		assert_equal(str(re_derived_resolver.explain(RuleTrigger.RUN_STARTED)), str(fresh_resolver.explain(RuleTrigger.RUN_STARTED)), "%s: the re-derived run_started explanations must match the fresh start." % class_id)
		assert_equal(str(re_derived_resolver.explain(RuleTrigger.BEFORE_ATTACK)), str(fresh_resolver.explain(RuleTrigger.BEFORE_ATTACK)), "%s: the re-derived before_attack explanations must match the fresh start." % class_id)


func _empty_and_unknown_class_re_derive_nothing() -> void:
	# Back-compat: a pre-5.x payload carries no class id; an empty / unknown id re-derives null (fail-closed).
	assert_true(ClassStartSummaryViewModel.re_derive_kit(&"") == null, "An empty class id must re-derive a null kit.")
	assert_true(ClassStartSummaryViewModel.re_derive_resolver(&"") == null, "An empty class id must re-derive a null resolver.")
	assert_true(ClassStartSummaryViewModel.re_derive_kit(&"does_not_exist") == null, "An unknown class id must re-derive a null kit (fail-closed).")
	assert_true(ClassStartSummaryViewModel.re_derive_resolver(&"does_not_exist") == null, "An unknown class id must re-derive a null resolver (fail-closed).")
	# A LOCKED class is not a startable kit either — re-derive returns null (fail-closed, mirrors the gate).
	assert_true(ClassStartSummaryViewModel.re_derive_kit(&"necromancer") == null, "A locked class id must re-derive a null kit (fail-closed).")
	assert_true(ClassStartSummaryViewModel.re_derive_resolver(&"necromancer") == null, "A locked class id must re-derive a null resolver (fail-closed).")


func _cleanup() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
