extends "res://tests/unit/test_case.gd"

# Story 6.1 AC1/AC2/AC6 — PickupRepository (the fail-closed pickup content repository). Same pin set as the
# other new repos: stable-id baseline, fail-closed lookup, generic boundary, null/invalid reject, fail-closed
# factory, BASELINE_*_IDS constant, duplicate-id fail-loud.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const PickupDefinition = preload("res://scripts/content/definitions/pickup_definition.gd")
const PickupRepository = preload("res://scripts/content/repositories/pickup_repository.gd")

const EXPECTED_PICKUP_IDS: Array[StringName] = [
	&"health_morsel",
	&"focus_ember"
]

func run() -> Dictionary:
	_baseline_pickups_registered_by_stable_id()
	_baseline_pickups_validate()
	_get_pickup_returns_null_on_a_miss()
	_repository_keeps_generic_content_registration_intact()
	_register_pickup_rejects_null_definition()
	_factory_fails_closed_on_invalid_definitions()
	_baseline_ids_constant_matches_registered_ids()
	_repository_rejects_duplicate_id_fail_loud()
	return result()


func _baseline_pickups_registered_by_stable_id() -> void:
	var repository: PickupRepository = PickupRepository.create_baseline_repository()
	assert_equal(repository.pickup_ids(), EXPECTED_PICKUP_IDS, "Baseline pickup ids should be stable and ordered.")
	for pickup_id: StringName in EXPECTED_PICKUP_IDS:
		assert_true(repository.get_pickup(pickup_id) != null, "Baseline pickup %s should be available through the repository." % String(pickup_id))
		assert_true(repository.has_pickup(pickup_id), "Repository should report having baseline pickup %s." % String(pickup_id))


func _baseline_pickups_validate() -> void:
	var repository: PickupRepository = PickupRepository.create_baseline_repository()
	for pickup_id: StringName in EXPECTED_PICKUP_IDS:
		var definition: PickupDefinition = repository.get_pickup(pickup_id)
		assert_true(definition.validate().succeeded, "Baseline pickup %s should validate." % String(pickup_id))
		assert_equal(definition.pickup_id, pickup_id, "Pickup ids should use lower snake StringName values.")


func _get_pickup_returns_null_on_a_miss() -> void:
	var repository: PickupRepository = PickupRepository.create_baseline_repository()
	assert_true(repository.get_pickup(&"does_not_exist") == null, "get_pickup must return null on an unregistered id (fail-closed).")
	assert_true(repository.get_pickup(&"") == null, "get_pickup must return null on an empty id (fail-closed).")
	assert_false(repository.has_pickup(&"does_not_exist"), "has_pickup should be false for an unregistered id.")


func _repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: PickupRepository = PickupRepository.create_baseline_repository(content_repository)
	for pickup_id: StringName in EXPECTED_PICKUP_IDS:
		assert_true(
			content_repository.has_definition(PickupDefinition.DEFINITION_TYPE, pickup_id),
			"Pickup %s should be registered through the generic content repository boundary." % String(pickup_id)
		)
		assert_equal(
			content_repository.get_definition(PickupDefinition.DEFINITION_TYPE, pickup_id),
			repository.get_pickup(pickup_id),
			"Pickup %s should not require direct gameplay file access." % String(pickup_id)
		)
	assert_equal(repository.content_repository(), content_repository, "Repository should expose the shared content repository boundary.")


func _register_pickup_rejects_null_definition() -> void:
	var repository: PickupRepository = PickupRepository.new()
	var result_value: ActionResult = repository.register_pickup(null)
	assert_true(result_value.is_error(), "Registering a null pickup should fail.")
	assert_equal(result_value.error_code, &"invalid_pickup_repository", "Null pickup registration should use the stable repository error code.")
	assert_true(repository.pickup_ids().is_empty(), "A failed registration should not add a pickup id.")


func _factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: PickupDefinition = PickupDefinition.new()
	var repository: PickupRepository = PickupRepository.create_repository_from_definitions([invalid_definition])
	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered pickup content.")

	var shared_content_repository: ContentRepository = ContentRepository.new()
	var valid_definition: PickupDefinition = PickupDefinition.new(&"health_morsel", &"restore_small_health", "A morsel.")
	var partial_repository: PickupRepository = PickupRepository.create_repository_from_definitions(
		[valid_definition, invalid_definition], shared_content_repository
	)
	assert_equal(partial_repository, null, "Repository factory should reject the full batch when any later definition is invalid.")
	assert_false(
		shared_content_repository.has_definition(PickupDefinition.DEFINITION_TYPE, &"health_morsel"),
		"A failed pickup repository creation must not mutate a provided content repository."
	)


func _baseline_ids_constant_matches_registered_ids() -> void:
	var repository: PickupRepository = PickupRepository.create_baseline_repository()
	assert_equal(PickupRepository.BASELINE_PICKUP_IDS, repository.pickup_ids(), "The BASELINE_PICKUP_IDS constant should match the actually-registered ids.")


func _repository_rejects_duplicate_id_fail_loud() -> void:
	var first: PickupDefinition = PickupDefinition.new(&"health_morsel", &"restore_small_health", "First.")
	var duplicate: PickupDefinition = PickupDefinition.new(&"health_morsel", &"restore_large_health", "Distinct duplicate.")
	var repository: PickupRepository = PickupRepository.new()
	assert_true(repository.register_pickup(first).succeeded, "The first pickup registration should succeed.")
	var duplicate_result: ActionResult = repository.register_pickup(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same pickup id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_pickup", "A duplicate id should use the stable duplicate_pickup code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "health_morsel", "The duplicate error should carry the offending id.")
	assert_equal(repository.pickup_ids(), [&"health_morsel"] as Array[StringName], "pickup_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_pickup(&"health_morsel").effect_id, &"restore_small_health", "get_pickup must still resolve the FIRST definition (no silent shadow).")
	assert_equal(PickupRepository.create_repository_from_definitions([first, duplicate]), null, "A definitions batch carrying a duplicate id must fail closed (null).")
