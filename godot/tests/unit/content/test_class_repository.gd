extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")
const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")
const SupportRepository = preload("res://scripts/content/repositories/support_repository.gd")

const EXPECTED_CLASSES: Dictionary = {
	&"warrior": {
		"display_name": "Warrior",
		"lock_state": &"selectable"
	},
	&"pyromancer": {
		"display_name": "Pyromancer",
		"lock_state": &"selectable"
	},
	&"ranger": {
		"display_name": "Ranger",
		"lock_state": &"selectable"
	},
	&"necromancer": {
		"display_name": "Necromancer",
		"lock_state": &"locked"
	},
	&"shadeblade": {
		"display_name": "Shadeblade",
		"lock_state": &"locked"
	}
}

func run() -> Dictionary:
	_baseline_classes_are_registered_by_stable_id()
	_baseline_classes_expose_expected_fields()
	_baseline_includes_three_selectable_and_two_locked_classes()
	_class_repository_keeps_generic_content_registration_intact()
	_unknown_class_lookup_fails_closed()
	_register_class_rejects_null_definition()
	_class_repository_factory_fails_closed_on_invalid_definitions()
	_class_repository_rejects_duplicate_id_fail_loud()
	_selectable_baseline_kit_ids_are_real_content_ids()
	return result()


func _baseline_classes_are_registered_by_stable_id() -> void:
	var repository: ClassRepository = ClassRepository.create_baseline_repository()
	var actual_ids: Array[StringName] = repository.class_ids()

	assert_equal(actual_ids, EXPECTED_CLASSES.keys(), "Baseline class ids should be stable and ordered.")
	assert_equal(actual_ids, ClassRepository.BASELINE_CLASS_IDS, "Baseline class ids should match the named constant order.")
	for class_id: StringName in EXPECTED_CLASSES.keys():
		var definition: ClassDefinition = repository.get_class_definition(class_id)
		assert_true(definition != null, "Baseline class %s should be available through the repository." % String(class_id))
		assert_true(repository.has_class(class_id), "Repository should report having baseline class %s." % String(class_id))


func _baseline_classes_expose_expected_fields() -> void:
	var repository: ClassRepository = ClassRepository.create_baseline_repository()

	for class_id: StringName in EXPECTED_CLASSES.keys():
		var definition: ClassDefinition = repository.get_class_definition(class_id)
		var expected: Dictionary = EXPECTED_CLASSES[class_id]
		var validation: ActionResult = definition.validate()

		assert_true(validation.succeeded, "Baseline class %s should validate." % String(class_id))
		assert_equal(definition.class_id, class_id, "Class ids should use lower snake StringName values.")
		assert_equal(definition.display_name, expected.get("display_name"), "Class %s should expose its display name." % String(class_id))
		assert_equal(definition.lock_state, expected.get("lock_state"), "Class %s should expose its lock state." % String(class_id))


func _baseline_includes_three_selectable_and_two_locked_classes() -> void:
	var repository: ClassRepository = ClassRepository.create_baseline_repository()
	var selectable_count: int = 0
	var locked_count: int = 0
	for class_id: StringName in repository.class_ids():
		var definition: ClassDefinition = repository.get_class_definition(class_id)
		if definition.lock_state == ClassDefinition.LOCK_STATE_SELECTABLE:
			selectable_count += 1
		elif definition.lock_state == ClassDefinition.LOCK_STATE_LOCKED:
			locked_count += 1

	assert_equal(selectable_count, 3, "Baseline should expose exactly three selectable MVP classes (Warrior/Pyromancer/Ranger).")
	assert_equal(locked_count, 2, "Baseline should expose exactly two locked future classes (Necromancer/Shadeblade).")
	for locked_id: StringName in [&"necromancer", &"shadeblade"]:
		var definition: ClassDefinition = repository.get_class_definition(locked_id)
		assert_false(definition.unlock_hint.strip_edges().is_empty(), "Locked class %s should carry a clear unlock hint." % String(locked_id))


func _class_repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: ClassRepository = ClassRepository.create_baseline_repository(content_repository)

	for class_id: StringName in EXPECTED_CLASSES.keys():
		assert_true(
			content_repository.has_definition(ClassDefinition.DEFINITION_TYPE, class_id),
			"Class %s should be registered through the generic content repository boundary." % String(class_id)
		)
		assert_equal(
			content_repository.get_definition(ClassDefinition.DEFINITION_TYPE, class_id),
			repository.get_class_definition(class_id),
			"Class %s should not require direct gameplay file access." % String(class_id)
		)
	assert_equal(repository.content_repository(), content_repository, "Repository should expose the shared content repository boundary.")


func _unknown_class_lookup_fails_closed() -> void:
	var repository: ClassRepository = ClassRepository.create_baseline_repository()
	assert_equal(repository.get_class_definition(&"does_not_exist"), null, "An unknown class id should resolve to null (fail-closed lookup), never a fabricated default.")
	assert_false(repository.has_class(&"does_not_exist"), "An unknown class id should not be reported as present.")


func _register_class_rejects_null_definition() -> void:
	var repository: ClassRepository = ClassRepository.new()
	var result_value: ActionResult = repository.register_class(null)
	assert_true(result_value.is_error(), "Registering a null class should fail.")
	assert_equal(result_value.error_code, &"invalid_class_repository", "Null class registration should use the stable repository error code.")
	assert_true(repository.class_ids().is_empty(), "A failed registration should not add a class id.")


func _class_repository_factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: ClassDefinition = ClassDefinition.new()
	var repository: ClassRepository = ClassRepository.create_repository_from_definitions([invalid_definition])

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: ClassDefinition = ClassRepository._baseline_definitions()[0]
	var partial_repository: ClassRepository = ClassRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition],
		shared_content_repository
	)

	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered class content.")
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(ClassDefinition.DEFINITION_TYPE, valid_definition.class_id),
		"Failed class repository creation must not mutate a provided content repository."
	)


# Story 6.1 AC6 — a SECOND registration under an already-present class id fails loud with a structured
# duplicate_class error, leaving class_ids() + get_class_definition consistent. A duplicate in a batch fails
# closed.
func _class_repository_rejects_duplicate_id_fail_loud() -> void:
	var first: ClassDefinition = ClassDefinition.new(
		&"shadeblade", "Shadeblade", ClassDefinition.LOCK_STATE_LOCKED, "First locked hint."
	)
	var duplicate: ClassDefinition = ClassDefinition.new(
		&"shadeblade", "Shadeblade Reborn", ClassDefinition.LOCK_STATE_LOCKED, "Distinct duplicate hint."
	)
	var repository: ClassRepository = ClassRepository.new()
	assert_true(repository.register_class(first).succeeded, "The first class registration should succeed.")
	var duplicate_result: ActionResult = repository.register_class(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same class id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_class", "A duplicate id should use the stable duplicate_class code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "shadeblade", "The duplicate error should carry the offending id.")
	assert_equal(repository.class_ids(), [&"shadeblade"] as Array[StringName], "class_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_class_definition(&"shadeblade").display_name, "Shadeblade", "get_class_definition must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: ClassRepository = ClassRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")


func _selectable_baseline_kit_ids_are_real_content_ids() -> void:
	# Optional integration safety net (Option B kept OUT of validate()): every selectable baseline
	# class references a REAL weapon/support baseline id so the v0 kit is valid by construction.
	# Story 5.3 owns the run-time cross-repository resolution + fail-closed rejection of a missing item.
	for definition: ClassDefinition in ClassRepository._baseline_definitions():
		if definition.lock_state != ClassDefinition.LOCK_STATE_SELECTABLE:
			continue
		assert_true(
			WeaponRepository.BASELINE_WEAPON_IDS.has(definition.starting_weapon_id),
			"Selectable class %s should start with a real weapon baseline id." % String(definition.class_id)
		)
		assert_true(
			SupportRepository.BASELINE_SUPPORT_IDS.has(definition.starting_support_id),
			"Selectable class %s should start with a real support baseline id." % String(definition.class_id)
		)
