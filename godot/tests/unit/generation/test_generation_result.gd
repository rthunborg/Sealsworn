extends "res://tests/unit/test_case.gd"

const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")

func run() -> Dictionary:
	_success_result_exposes_payload_slot()
	_success_result_deep_copies_diagnostics()
	_error_result_carries_phase_seed_reason_diagnostics()
	_error_result_deep_copies_diagnostics()
	_error_result_normalizes_invalid_codes()
	_error_result_rejects_unknown_phase()
	_phase_constants_are_stable_lower_snake()
	return result()


func _success_result_exposes_payload_slot() -> void:
	var payload: Dictionary = {"recipe_id": "small_combat_basic", "size_class": "small"}
	var result_value: GenerationResult = GenerationResult.ok(payload, {"phase": "recipe"})

	assert_true(result_value.succeeded, "A successful generation result should report success.")
	assert_false(result_value.is_error(), "A successful generation result should not be an error.")
	assert_equal(result_value.error_code, &"", "A successful generation result should carry no error code.")
	assert_equal(result_value.failed_phase, &"", "A successful generation result should carry no failed phase.")
	assert_true(result_value.has_payload(), "A successful generation result should expose its payload slot.")
	assert_equal(result_value.payload.get("recipe_id"), "small_combat_basic", "Success payload should carry the placeholder recipe id.")


func _success_result_deep_copies_diagnostics() -> void:
	var diagnostics: Dictionary = {"tags": ["recipe_resolved"]}
	var result_value: GenerationResult = GenerationResult.ok({"recipe_id": "x"}, diagnostics)
	diagnostics["tags"][0] = "mutated"
	assert_equal(result_value.diagnostics.get("tags")[0], "recipe_resolved", "Success diagnostics should be deep copied.")


func _error_result_carries_phase_seed_reason_diagnostics() -> void:
	var result_value: GenerationResult = GenerationResult.error(
		GenerationResult.PHASE_RECIPE,
		&"unknown_level_recipe",
		&"recipe_not_registered",
		"4242",
		{"recipe_id": "missing_recipe"}
	)

	assert_true(result_value.is_error(), "A failure generation result should report an error.")
	assert_false(result_value.succeeded, "A failure generation result should not report success.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_RECIPE, "Failure result should carry the failed phase (AC4).")
	assert_equal(result_value.error_code, &"unknown_level_recipe", "Failure result should carry the stable error code (AC4).")
	assert_equal(result_value.reason, &"recipe_not_registered", "Failure result should carry the machine-stable reason (AC4).")
	assert_equal(result_value.seed, "4242", "Failure result should carry the seed (AC4).")
	assert_equal(result_value.diagnostics.get("recipe_id"), "missing_recipe", "Failure result should carry compact diagnostics (AC4).")
	assert_false(result_value.has_payload(), "A failure generation result should not expose a generated payload.")

	# The architecture's Diagnostics.error("generation", error_code, {seed, phase, reason}) flow
	# must be expressible directly from the result fields.
	var diagnostics_payload: Dictionary = {
		"seed": result_value.seed,
		"phase": String(result_value.failed_phase),
		"reason": String(result_value.reason)
	}
	assert_equal(diagnostics_payload.get("phase"), "recipe", "Failure result should feed the Diagnostics.error phase field.")
	assert_equal(diagnostics_payload.get("reason"), "recipe_not_registered", "Failure result should feed the Diagnostics.error reason field.")


func _error_result_deep_copies_diagnostics() -> void:
	var diagnostics: Dictionary = {"candidates": ["a", "b"]}
	var result_value: GenerationResult = GenerationResult.error(
		GenerationResult.PHASE_RECIPE, &"unknown_level_recipe", &"recipe_not_registered", "7", diagnostics
	)
	diagnostics["candidates"][0] = "mutated"
	assert_equal(result_value.diagnostics.get("candidates")[0], "a", "Failure diagnostics should be deep copied.")


func _error_result_normalizes_invalid_codes() -> void:
	var result_value: GenerationResult = GenerationResult.error(
		GenerationResult.PHASE_RECIPE, &"Unknown Recipe!", &"Bad Reason", "7", {}
	)
	assert_equal(result_value.error_code, &"invalid_error_code", "Failure result should normalize a non-lower-snake error code.")
	assert_equal(result_value.reason, &"invalid_reason", "Failure result should normalize a non-lower-snake reason.")


func _error_result_rejects_unknown_phase() -> void:
	var result_value: GenerationResult = GenerationResult.error(
		&"teleport_phase", &"unknown_level_recipe", &"recipe_not_registered", "7", {}
	)
	assert_equal(result_value.failed_phase, &"invalid_phase", "Failure result should reject an unknown generation phase id.")


func _phase_constants_are_stable_lower_snake() -> void:
	var phases: Array[StringName] = GenerationResult.generation_phases()
	var expected_phases: Array[StringName] = [
		GenerationResult.PHASE_ROUTE,
		GenerationResult.PHASE_RECIPE,
		GenerationResult.PHASE_LAYOUT,
		GenerationResult.PHASE_PATHING,
		GenerationResult.PHASE_BLOCKERS,
		GenerationResult.PHASE_HAZARDS,
		GenerationResult.PHASE_ENEMIES,
		GenerationResult.PHASE_REWARDS,
		GenerationResult.PHASE_AFFINITY,
		GenerationResult.PHASE_VALIDATION,
		GenerationResult.PHASE_FINALIZE
	]
	assert_equal(phases, expected_phases, "Generation phases should match the architecture phase order.")
	for phase: StringName in phases:
		assert_true(GenerationResult.is_known_phase(phase), "Phase %s should be recognized as a known generation phase." % String(phase))
