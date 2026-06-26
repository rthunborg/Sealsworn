extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const ContentRepository = preload("res://scripts/content/repositories/content_repository.gd")
const WeaponDefinition = preload("res://scripts/content/definitions/weapon_definition.gd")
const WeaponRepository = preload("res://scripts/content/repositories/weapon_repository.gd")

const EXPECTED_WEAPONS: Dictionary = {
	&"sword": {
		"range": 1,
		"base_damage": 4,
		"targeting_shape": &"adjacent_cardinal",
		"tactical_identity": "Reliable melee damage.",
		"visibility_requirement": &"visible_target",
		"blocker_behavior": &"standard",
		"adjacency_modifier": &"",
		"preview_effect_ids": []
	},
	&"dagger": {
		"range": 1,
		"base_damage": 2,
		"targeting_shape": &"adjacent_cardinal",
		"tactical_identity": "Low normal damage; future Unseen synergy.",
		"visibility_requirement": &"visible_target",
		"blocker_behavior": &"standard",
		"adjacency_modifier": &"",
		"preview_effect_ids": [&"future_unseen_synergy"]
	},
	&"spear": {
		"range": 2,
		"base_damage": 3,
		"targeting_shape": &"straight_line",
		"tactical_identity": "Reach weapon with safer spacing.",
		"visibility_requirement": &"visible_target",
		"blocker_behavior": &"standard",
		"adjacency_modifier": &"",
		"preview_effect_ids": []
	},
	&"axe": {
		"range": 1,
		"base_damage": 3,
		"targeting_shape": &"adjacent_cardinal",
		"tactical_identity": "Bleed pressure if the target survives.",
		"visibility_requirement": &"visible_target",
		"blocker_behavior": &"standard",
		"adjacency_modifier": &"",
		"preview_effect_ids": [&"bleed_if_survives_35"]
	},
	&"mace": {
		"range": 1,
		"base_damage": 3,
		"targeting_shape": &"adjacent_cardinal",
		"tactical_identity": "Disorient pressure if the target survives.",
		"visibility_requirement": &"visible_target",
		"blocker_behavior": &"standard",
		"adjacency_modifier": &"",
		"preview_effect_ids": [&"disorient_if_survives_35"]
	},
	&"bow": {
		"range": 4,
		"base_damage": 3,
		"targeting_shape": &"straight_line",
		"tactical_identity": "Ranged attack with adjacent penalty.",
		"visibility_requirement": &"visible_target",
		"blocker_behavior": &"standard",
		"adjacency_modifier": &"adjacent_ranged_70",
		"preview_effect_ids": []
	},
	&"crossbow": {
		"range": 3,
		"base_damage": 4,
		"targeting_shape": &"straight_line",
		"tactical_identity": "Shorter range, heavier hit, knockback preview.",
		"visibility_requirement": &"visible_target",
		"blocker_behavior": &"standard",
		"adjacency_modifier": &"",
		"preview_effect_ids": [&"knockback_1_if_space_allows"]
	},
	&"staff": {
		"range": 4,
		"base_damage": 4,
		"targeting_shape": &"straight_line",
		"tactical_identity": "Projectile attack with adjacent penalty.",
		"visibility_requirement": &"visible_target",
		"blocker_behavior": &"standard",
		"adjacency_modifier": &"adjacent_half",
		"preview_effect_ids": []
	},
	&"wand": {
		"range": 4,
		"base_damage": 2,
		"targeting_shape": &"straight_line",
		"tactical_identity": "Lower damage line that ignores blockers.",
		"visibility_requirement": &"visible_target",
		"blocker_behavior": &"ignore_terrain_and_entities",
		"adjacency_modifier": &"",
		"preview_effect_ids": [&"ignore_blockers"]
	}
}

func run() -> Dictionary:
	_baseline_weapon_definitions_are_registered_by_stable_id()
	_weapon_definitions_validate_required_preview_fields()
	_weapon_definition_validation_rejects_contradictory_adjacency_modifiers()
	_weapon_repository_keeps_generic_content_registration_intact()
	_weapon_repository_factory_fails_closed_on_invalid_definitions()
	_weapon_repository_rejects_duplicate_id_fail_loud()
	return result()


func _baseline_weapon_definitions_are_registered_by_stable_id() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()
	var actual_ids: Array[StringName] = repository.weapon_ids()

	assert_equal(actual_ids, EXPECTED_WEAPONS.keys(), "Baseline weapon ids should be stable and ordered.")
	for weapon_id: StringName in EXPECTED_WEAPONS.keys():
		var definition: WeaponDefinition = repository.get_weapon(weapon_id)
		assert_true(definition != null, "Baseline weapon %s should be available through the repository." % String(weapon_id))


func _weapon_definitions_validate_required_preview_fields() -> void:
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository()

	for weapon_id: StringName in EXPECTED_WEAPONS.keys():
		var definition: WeaponDefinition = repository.get_weapon(weapon_id)
		var expected: Dictionary = EXPECTED_WEAPONS[weapon_id]
		var validation: ActionResult = definition.validate()

		assert_true(validation.succeeded, "Weapon %s should validate required fields." % String(weapon_id))
		assert_equal(definition.weapon_id, weapon_id, "Weapon ids should use lower snake StringName values.")
		assert_equal(definition.attack_range, expected.get("range"), "Weapon %s should expose range." % String(weapon_id))
		assert_equal(definition.base_damage, expected.get("base_damage"), "Weapon %s should expose base damage." % String(weapon_id))
		assert_equal(definition.targeting_shape, expected.get("targeting_shape"), "Weapon %s should expose targeting shape." % String(weapon_id))
		assert_equal(definition.tactical_identity, expected.get("tactical_identity"), "Weapon %s should expose tactical identity." % String(weapon_id))
		assert_equal(definition.visibility_requirement, expected.get("visibility_requirement"), "Weapon %s should expose visibility requirement." % String(weapon_id))
		assert_equal(definition.blocker_behavior, expected.get("blocker_behavior"), "Weapon %s should expose blocker behavior." % String(weapon_id))
		assert_equal(definition.adjacency_modifier_id, expected.get("adjacency_modifier"), "Weapon %s should expose adjacency modifier id." % String(weapon_id))
		assert_equal(definition.preview_effect_ids, expected.get("preview_effect_ids"), "Weapon %s should expose preview effect ids." % String(weapon_id))


func _weapon_definition_validation_rejects_contradictory_adjacency_modifiers() -> void:
	var bow_with_half_multiplier: WeaponDefinition = WeaponDefinition.new(
		&"bad_bow",
		4,
		3,
		WeaponDefinition.TARGETING_STRAIGHT_LINE,
		"Invalid bow.",
		WeaponDefinition.VISIBILITY_VISIBLE_TARGET,
		WeaponDefinition.BLOCKER_STANDARD,
		WeaponDefinition.ADJACENCY_RANGED_70,
		0.5,
		WeaponDefinition.WARNING_ADJACENT_RANGED_PENALTY
	)
	var staff_with_bow_multiplier: WeaponDefinition = WeaponDefinition.new(
		&"bad_staff",
		4,
		4,
		WeaponDefinition.TARGETING_STRAIGHT_LINE,
		"Invalid staff.",
		WeaponDefinition.VISIBILITY_VISIBLE_TARGET,
		WeaponDefinition.BLOCKER_STANDARD,
		WeaponDefinition.ADJACENCY_HALF,
		0.7,
		WeaponDefinition.WARNING_ADJACENT_RANGED_PENALTY
	)

	assert_true(bow_with_half_multiplier.validate().is_error(), "adjacent_ranged_70 should require multiplier 0.7.")
	assert_true(staff_with_bow_multiplier.validate().is_error(), "adjacent_half should require multiplier 0.5.")


func _weapon_repository_keeps_generic_content_registration_intact() -> void:
	var content_repository: ContentRepository = ContentRepository.new()
	var repository: WeaponRepository = WeaponRepository.create_baseline_repository(content_repository)

	for weapon_id: StringName in EXPECTED_WEAPONS.keys():
		assert_true(
			content_repository.has_definition(WeaponDefinition.DEFINITION_TYPE, weapon_id),
			"Weapon %s should be registered through the generic content repository boundary." % String(weapon_id)
		)
		assert_equal(
			content_repository.get_definition(WeaponDefinition.DEFINITION_TYPE, weapon_id),
			repository.get_weapon(weapon_id),
			"Weapon %s should not require direct gameplay file access." % String(weapon_id)
		)


func _weapon_repository_factory_fails_closed_on_invalid_definitions() -> void:
	var invalid_definition: WeaponDefinition = WeaponDefinition.new()
	var repository: WeaponRepository = WeaponRepository.create_repository_from_definitions([invalid_definition])

	assert_equal(repository, null, "Repository factory should fail closed instead of returning partially registered content.")


# Story 6.1 AC6 — a SECOND registration under an already-present weapon id fails loud with a structured
# duplicate_weapon error, leaving weapon_ids() + get_weapon consistent (the rejected def is neither listed nor
# resolvable — no silent last-write-win shadow). A definitions batch carrying a duplicate id fails closed.
func _weapon_repository_rejects_duplicate_id_fail_loud() -> void:
	var first: WeaponDefinition = WeaponDefinition.new(
		&"sword", 1, 4, WeaponDefinition.TARGETING_ADJACENT_CARDINAL, "First sword."
	)
	var duplicate: WeaponDefinition = WeaponDefinition.new(
		&"sword", 2, 9, WeaponDefinition.TARGETING_STRAIGHT_LINE, "Distinct second definition under the same id."
	)
	var repository: WeaponRepository = WeaponRepository.new()
	assert_true(repository.register_weapon(first).succeeded, "The first weapon registration should succeed.")
	var duplicate_result: ActionResult = repository.register_weapon(duplicate)
	assert_true(duplicate_result.is_error(), "A second registration under the same weapon id must fail loud.")
	assert_equal(duplicate_result.error_code, &"duplicate_weapon", "A duplicate id should use the stable duplicate_weapon code.")
	assert_equal(String(duplicate_result.metadata.get("id")), "sword", "The duplicate error should carry the offending id.")
	assert_equal(repository.weapon_ids(), [&"sword"] as Array[StringName], "weapon_ids() must keep the id exactly once after a rejected duplicate.")
	assert_equal(repository.get_weapon(&"sword").base_damage, 4, "get_weapon must still resolve the FIRST definition (no silent shadow).")

	var batch_repository: WeaponRepository = WeaponRepository.create_repository_from_definitions([first, duplicate])
	assert_equal(batch_repository, null, "A definitions batch carrying a duplicate id must fail closed (null).")
