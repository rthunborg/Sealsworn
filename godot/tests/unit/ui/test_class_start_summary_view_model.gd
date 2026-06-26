extends "res://tests/unit/test_case.gd"

# Story 5.5 Task 5.1 — ClassStartSummaryViewModel: the scene-free class-start identity PROJECTION (AC1/AC2/AC4).
# This is the NEW thin smoke-slice SURFACE 5.5 delivers: a pure projection that reads a STARTED RunState (class
# id + starting_kit + rules_resolver, all seated by RunStartCommand) and projects the class-start identity into
# serializable view data with an EXACT key contract (a key never silently appears/vanishes — the
# HeroSelectViewModel / TacticalBoardViewModel exact-key discipline).
#
# Pins:
#   - the EXACT SUMMARY_KEYS set on every projection (selectable class + empty-class/legacy run);
#   - each selectable class projects the RIGHT identity (class_id / display_name / weapon_id / support_id /
#     baseline_hp / the two passive ids) resolved against the RESOLVED ClassRepository/PassiveRepository
#     baselines, NOT hardcoded literals;
#   - the per-window passive EXPLANATIONS (run_started -> the equipment-synergy passive; before_attack -> the
#     class passive) are surfaced from the run's resolver (AC2 "explanations appear when preview/combat events
#     occur"), each the right class's;
#   - an empty-class/legacy run projects the EMPTY/identity-absent surface (same key set, empty/default values,
#     NO passive explanations) — fail-closed, NOT a crash, NOT a half-entry;
#   - NO active-skill key anywhere on the projection (FR45 — the absence stays pinned);
#   - the projection is class-DIFFERENTIATED: each class's explanation set is disjoint from the others' (AC2/AC4
#     "unrelated classes do not receive those effects").

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")
const ClassStartSummaryViewModel = preload("res://scripts/ui/view_models/class_start_summary_view_model.gd")
const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RunOrchestrator = preload("res://scripts/run/run_orchestrator.gd")
const RunState = preload("res://scripts/run/run_state.gd")

const SELECTABLE_CLASS_IDS: Array[StringName] = [&"warrior", &"pyromancer", &"ranger"]

func run() -> Dictionary:
	_summary_key_set_is_exact_for_every_selectable_class()
	_summary_projects_resolved_identity_for_every_selectable_class()
	_summary_surfaces_per_window_passive_explanations_for_every_class()
	_empty_class_run_projects_the_identity_absent_surface()
	_summary_has_no_active_skill_key()
	_summary_explanations_are_class_differentiated()
	_summary_projects_from_a_re_derived_resolver_run()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

# Start a run with the given class through the orchestrator (the authoritative class->kit->passive gate path)
# and return the seated RunState (carries selected_class_id + starting_kit + rules_resolver).
func _started_run(class_id: StringName) -> RunState:
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	var start: ActionResult = orchestrator.start(42, false, class_id)
	assert_true(start.succeeded, "%s: starting a run should succeed for the summary projection: %s" % [class_id, start.metadata])
	return orchestrator.run


# ---- the projection proofs -----------------------------------------------------------------------

func _summary_key_set_is_exact_for_every_selectable_class() -> void:
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		var run: RunState = _started_run(class_id)
		var summary: Dictionary = ClassStartSummaryViewModel.new().summarize(run)
		# Exact key parity: every expected key present, no surprise key.
		assert_equal(summary.keys().size(), ClassStartSummaryViewModel.SUMMARY_KEYS.size(), "%s: the summary must carry EXACTLY the pinned key count." % class_id)
		for key: String in ClassStartSummaryViewModel.SUMMARY_KEYS:
			assert_true(summary.has(key), "%s: the summary must carry the pinned key '%s'." % [class_id, key])
		for key: Variant in summary.keys():
			assert_true(ClassStartSummaryViewModel.SUMMARY_KEYS.has(key), "%s: the summary must NOT introduce a surprise key (%s)." % [class_id, str(key)])


func _summary_projects_resolved_identity_for_every_selectable_class() -> void:
	var class_repo: ClassRepository = ClassRepository.create_baseline_repository()
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		var run: RunState = _started_run(class_id)
		var summary: Dictionary = ClassStartSummaryViewModel.new().summarize(run)
		# Assert the projected identity against the RESOLVED baseline definition, not hardcoded literals.
		var def: ClassDefinition = class_repo.get_class_definition(class_id)
		assert_equal(summary.get("class_id"), String(class_id), "%s: the summary class_id must match." % class_id)
		assert_equal(summary.get("display_name"), def.display_name, "%s: the summary display_name must match the resolved definition." % class_id)
		assert_equal(summary.get("weapon_id"), String(def.starting_weapon_id), "%s: the summary weapon_id must match the resolved kit." % class_id)
		assert_equal(summary.get("support_id"), String(def.starting_support_id), "%s: the summary support_id must match the resolved kit." % class_id)
		assert_equal(summary.get("baseline_hp"), def.baseline_hp, "%s: the summary baseline_hp must match the resolved kit." % class_id)
		assert_equal(summary.get("class_passive_id"), String(def.class_passive_id), "%s: the summary class_passive_id must match." % class_id)
		assert_equal(summary.get("equipment_synergy_passive_id"), String(def.equipment_synergy_passive_id), "%s: the summary equipment_synergy_passive_id must match." % class_id)
		assert_true(bool(summary.get("has_class_identity")), "%s: a started class run must report has_class_identity = true." % class_id)


func _summary_surfaces_per_window_passive_explanations_for_every_class() -> void:
	var passive_repo: PassiveRepository = PassiveRepository.create_baseline_repository()
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		var run: RunState = _started_run(class_id)
		var summary: Dictionary = ClassStartSummaryViewModel.new().summarize(run)
		var def: ClassDefinition = ClassRepository.create_baseline_repository().get_class_definition(class_id)
		var class_passive: PassiveDefinition = passive_repo.get_passive(def.class_passive_id)
		var equip_passive: PassiveDefinition = passive_repo.get_passive(def.equipment_synergy_passive_id)

		# The equipment-synergy passive fires run_started; the class passive fires before_attack.
		var run_started_explanations: Array = summary.get("run_started_explanations")
		var before_attack_explanations: Array = summary.get("before_attack_explanations")
		assert_true(run_started_explanations is Array, "%s: run_started_explanations must be an Array." % class_id)
		assert_true(before_attack_explanations is Array, "%s: before_attack_explanations must be an Array." % class_id)
		assert_true(run_started_explanations.has(equip_passive.explanation), "%s: run_started must surface the equipment-synergy explanation." % class_id)
		assert_true(before_attack_explanations.has(class_passive.explanation), "%s: before_attack must surface the class-passive explanation." % class_id)
		# The flat all-explanations field carries BOTH (stable order: class passive then equipment synergy).
		var all_explanations: Array = summary.get("passive_explanations")
		assert_true(all_explanations is Array, "%s: passive_explanations must be an Array." % class_id)
		assert_true(all_explanations.has(class_passive.explanation), "%s: passive_explanations must include the class passive." % class_id)
		assert_true(all_explanations.has(equip_passive.explanation), "%s: passive_explanations must include the equipment-synergy passive." % class_id)
		# The explanations are plain Strings (survive any later ActionResult metadata deep-copy).
		for entry: Variant in all_explanations:
			assert_true(entry is String, "%s: every explanation entry must be a plain String." % class_id)


func _empty_class_run_projects_the_identity_absent_surface() -> void:
	# A seed-only (empty-class / legacy) start records NO kit + NO resolver.
	var orchestrator: RunOrchestrator = RunOrchestrator.new()
	assert_true(orchestrator.start(42, false).succeeded, "An empty-class start should succeed.")
	var run: RunState = orchestrator.run
	assert_true(run.starting_kit == null, "An empty-class run must have a null starting_kit (precondition).")
	assert_true(run.rules_resolver == null, "An empty-class run must have a null rules_resolver (precondition).")

	var summary: Dictionary = ClassStartSummaryViewModel.new().summarize(run)
	# Same key set, identity-absent values.
	assert_equal(summary.keys().size(), ClassStartSummaryViewModel.SUMMARY_KEYS.size(), "The empty-class summary must carry the SAME pinned key set.")
	for key: String in ClassStartSummaryViewModel.SUMMARY_KEYS:
		assert_true(summary.has(key), "The empty-class summary must carry the pinned key '%s'." % key)
	assert_false(bool(summary.get("has_class_identity")), "An empty-class run must report has_class_identity = false.")
	assert_equal(summary.get("class_id"), "", "An empty-class run must project an empty class_id.")
	assert_equal(summary.get("display_name"), "", "An empty-class run must project an empty display_name.")
	assert_equal(summary.get("weapon_id"), "", "An empty-class run must project an empty weapon_id.")
	assert_equal(summary.get("support_id"), "", "An empty-class run must project an empty support_id.")
	assert_equal(summary.get("baseline_hp"), 0, "An empty-class run must project baseline_hp 0.")
	assert_equal(summary.get("class_passive_id"), "", "An empty-class run must project an empty class_passive_id.")
	assert_equal(summary.get("equipment_synergy_passive_id"), "", "An empty-class run must project an empty equipment_synergy_passive_id.")
	assert_equal((summary.get("passive_explanations") as Array).size(), 0, "An empty-class run must surface NO passive explanations.")
	assert_equal((summary.get("run_started_explanations") as Array).size(), 0, "An empty-class run must surface NO run_started explanations.")
	assert_equal((summary.get("before_attack_explanations") as Array).size(), 0, "An empty-class run must surface NO before_attack explanations.")


func _summary_has_no_active_skill_key() -> void:
	# FR45: the projection surfaces ONLY passive rule-benders — never an active-skill activation. Pin the absence.
	var run: RunState = _started_run(&"warrior")
	var summary: Dictionary = ClassStartSummaryViewModel.new().summarize(run)
	for key: Variant in summary.keys():
		var key_text: String = str(key)
		assert_false(key_text.contains("active_skill"), "The summary must not carry an active-skill key (%s)." % key_text)
		assert_false(key_text.contains("class_skill"), "The summary must not carry a class-skill key (%s)." % key_text)


func _summary_explanations_are_class_differentiated() -> void:
	# AC2/AC4: each class's surfaced explanation set is disjoint from the others' — no class ever surfaces
	# another class's passive explanation.
	var explanation_sets: Dictionary = {}
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		var run: RunState = _started_run(class_id)
		var summary: Dictionary = ClassStartSummaryViewModel.new().summarize(run)
		explanation_sets[class_id] = summary.get("passive_explanations")

	for class_id: StringName in SELECTABLE_CLASS_IDS:
		for other_id: StringName in SELECTABLE_CLASS_IDS:
			if class_id == other_id:
				continue
			for explanation: Variant in explanation_sets.get(class_id):
				assert_false((explanation_sets.get(other_id) as Array).has(explanation), "%s must NOT surface %s's explanation (%s)." % [other_id, class_id, str(explanation)])


# The projection works off a RE-DERIVED resolver (the Task-3 helper), proving a resumer that re-derives the
# resolver can project the SAME identity surface as a fresh start.
func _summary_projects_from_a_re_derived_resolver_run() -> void:
	for class_id: StringName in SELECTABLE_CLASS_IDS:
		var fresh: RunState = _started_run(class_id)
		var fresh_summary: Dictionary = ClassStartSummaryViewModel.new().summarize(fresh)

		# Build a run carrying ONLY the class id (the route-position-restore shape: kit + resolver null), then
		# re-derive both and project.
		var re_derived_kit: Variant = ClassStartSummaryViewModel.re_derive_kit(class_id)
		var re_derived_resolver: Variant = ClassStartSummaryViewModel.re_derive_resolver(class_id)
		assert_true(re_derived_kit != null, "%s: re_derive_kit must return a kit." % class_id)
		assert_true(re_derived_resolver != null, "%s: re_derive_resolver must return a resolver." % class_id)
		var restored: RunState = RunState.new_run(42, false, fresh.route.copy())
		restored.selected_class_id = class_id
		restored.starting_kit = re_derived_kit
		restored.rules_resolver = re_derived_resolver

		var re_derived_summary: Dictionary = ClassStartSummaryViewModel.new().summarize(restored)
		assert_equal(JSON.stringify(re_derived_summary), JSON.stringify(fresh_summary), "%s: a re-derived-resolver run must project the SAME summary as a fresh start." % class_id)
