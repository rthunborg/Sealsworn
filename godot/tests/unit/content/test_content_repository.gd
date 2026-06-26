extends "res://tests/unit/test_case.gd"

# Story 6.1 AC6 — the central duplicate-id fail-loud guard on the generic ContentRepository boundary (the
# single mechanism every domain *Repository registers through). register_definition now returns a structured
# ActionResult and REJECTS a second registration under an already-present (type, id) with a stable
# duplicate_definition error, instead of silently last-write-winning. This is the load-bearing cross-cutting
# hardening that retrofits all six existing repos + every new Epic-6 loot/reward repo in one place.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")

func run() -> Dictionary:
	_first_registration_succeeds_and_reports_type_and_id()
	_second_registration_under_same_type_and_id_fails_loud()
	_rejected_duplicate_does_not_overwrite_the_first_definition()
	_same_id_under_a_different_type_is_not_a_duplicate()
	return result()


func _first_registration_succeeds_and_reports_type_and_id() -> void:
	var repository: ContentRepository = ContentRepository.new()
	var definition: WeaponDefinition = WeaponDefinition.new(
		&"sword", 1, 4, WeaponDefinition.TARGETING_ADJACENT_CARDINAL, "Reliable melee."
	)
	var result_value: ActionResult = repository.register_definition(WeaponDefinition.DEFINITION_TYPE, &"sword", definition)
	assert_true(result_value.succeeded, "A first registration under a fresh (type, id) should succeed.")
	assert_equal(String(result_value.metadata.get("type")), "weapon", "The registration result should report the type.")
	assert_equal(String(result_value.metadata.get("id")), "sword", "The registration result should report the id.")
	assert_true(repository.has_definition(WeaponDefinition.DEFINITION_TYPE, &"sword"), "The definition should be registered.")


func _second_registration_under_same_type_and_id_fails_loud() -> void:
	var repository: ContentRepository = ContentRepository.new()
	var first: WeaponDefinition = WeaponDefinition.new(
		&"sword", 1, 4, WeaponDefinition.TARGETING_ADJACENT_CARDINAL, "First."
	)
	var duplicate: WeaponDefinition = WeaponDefinition.new(
		&"sword", 2, 9, WeaponDefinition.TARGETING_STRAIGHT_LINE, "Distinct duplicate."
	)
	assert_true(repository.register_definition(WeaponDefinition.DEFINITION_TYPE, &"sword", first).succeeded, "The first registration should succeed.")
	var duplicate_result: ActionResult = repository.register_definition(WeaponDefinition.DEFINITION_TYPE, &"sword", duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same (type, id) must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_definition", "A duplicate should use the stable duplicate_definition code.")
	assert_equal(String(duplicate_result.metadata.get("type")), "weapon", "The duplicate error should carry the type.")
	assert_equal(String(duplicate_result.metadata.get("id")), "sword", "The duplicate error should carry the offending id.")


func _rejected_duplicate_does_not_overwrite_the_first_definition() -> void:
	var repository: ContentRepository = ContentRepository.new()
	var first: WeaponDefinition = WeaponDefinition.new(
		&"sword", 1, 4, WeaponDefinition.TARGETING_ADJACENT_CARDINAL, "First."
	)
	var duplicate: WeaponDefinition = WeaponDefinition.new(
		&"sword", 2, 9, WeaponDefinition.TARGETING_STRAIGHT_LINE, "Distinct duplicate."
	)
	repository.register_definition(WeaponDefinition.DEFINITION_TYPE, &"sword", first)
	repository.register_definition(WeaponDefinition.DEFINITION_TYPE, &"sword", duplicate)
	var resolved: WeaponDefinition = repository.get_definition(WeaponDefinition.DEFINITION_TYPE, &"sword") as WeaponDefinition
	assert_equal(resolved.base_damage, 4, "get_definition must still resolve the FIRST definition (no silent last-write-win shadow).")


func _same_id_under_a_different_type_is_not_a_duplicate() -> void:
	var repository: ContentRepository = ContentRepository.new()
	var weapon: WeaponDefinition = WeaponDefinition.new(
		&"shared_id", 1, 4, WeaponDefinition.TARGETING_ADJACENT_CARDINAL, "A weapon."
	)
	# A different type bucket under the same id is independent — not a duplicate.
	assert_true(repository.register_definition(&"weapon", &"shared_id", weapon).succeeded, "A weapon under shared_id should register.")
	assert_true(repository.register_definition(&"armor", &"shared_id", weapon).succeeded, "The SAME id under a DIFFERENT type is not a duplicate and should register.")
