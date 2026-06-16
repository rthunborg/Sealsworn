extends "res://tests/unit/test_case.gd"

# Story 3.6 — Bounded Deterministic Retry (AC2).
#
# Covers the bounded deterministic retry loop wired into LevelGenerator.generate:
#   AC2 — deterministic retry: the SAME root_seed + recipe reproduces the SAME final result (same attempt
#         count, same final candidate OR same final error); an injected ALWAYS-FAIL validator exhausts the
#         attempt cap and returns a structured GenerationResult.error carrying seed + phase + reason + an
#         `attempts` diagnostic == MAX_GENERATION_ATTEMPTS; an injected FAIL-THEN-PASS validator succeeds
#         on a later attempt and reports the attempt index (`attempts` == k+1); attempt i>0's candidate
#         differs DETERMINISTICALLY from attempt 0's (the seed-mix perturbs the layout while attempt 0
#         stays unperturbed).
#
# The retry is exercised WITHOUT a genuinely-bad baseline seed (baseline candidates pass on attempt 0) by
# INJECTING a validator outcome via the optional 4th `validator` param of LevelGenerator.generate. The
# injected stand-ins below expose `validate(candidate: Dictionary) -> ActionResult`, the same seam the
# real LevelValidator implements.
#
# Headless / scene-free. No user:// writes.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelValidator = preload("res://scripts/generation/level/level_validator.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")


# Stand-in validator that ALWAYS fails with a chosen check code (default unreachable_reward -> maps to
# PHASE_VALIDATION). Counts how many times it was invoked so a test can assert the attempt cap.
class AlwaysFailValidator:
	extends RefCounted
	const _ActionResult = preload("res://scripts/core/results/action_result.gd")
	var calls: int = 0
	var fail_code: StringName = &"unreachable_reward"
	func validate(_candidate: Dictionary) -> _ActionResult:
		calls += 1
		return _ActionResult.error(fail_code, {"reason": "injected_always_fail", "probe": calls})


# Stand-in validator that fails for the first `fail_count` attempts, then PASSES. Counts invocations so a
# test can assert the success attempt index.
class FailThenPassValidator:
	extends RefCounted
	const _ActionResult = preload("res://scripts/core/results/action_result.gd")
	var calls: int = 0
	var fail_count: int = 1
	var fail_code: StringName = &"unreachable_reward"
	func validate(_candidate: Dictionary) -> _ActionResult:
		calls += 1
		if calls <= fail_count:
			return _ActionResult.error(fail_code, {"reason": "injected_fail_then_pass", "probe": calls})
		return _ActionResult.ok([], {"reason": "injected_pass", "probe": calls})


func run() -> Dictionary:
	_same_seed_recipe_reproduces_same_final_result()
	_same_seed_reproduces_same_final_error_when_always_failing()
	_always_fail_validator_exhausts_attempt_cap_with_structured_error()
	_final_error_carries_seed_phase_reason_and_attempts()
	_pathing_failure_maps_to_pathing_phase()
	_fail_then_pass_succeeds_on_later_attempt_and_reports_index()
	_fail_for_several_then_pass_reports_correct_attempt_count()
	_attempt_zero_is_unperturbed()
	_perturbed_attempt_differs_deterministically_from_attempt_zero()
	_attempt_seed_is_deterministic_and_distinct_per_attempt()
	_success_path_tags_validated_and_attempts()
	return result()


func _repository() -> LevelRecipeRepository:
	return LevelRecipeRepository.create_baseline_repository()


func _enemy_repository() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


func _small_request(root_seed: int = 1234) -> GenerationRequest:
	return GenerationRequest.new(
		root_seed, &"node_1", &"combat", &"small_combat_basic",
		GenerationRequest.SIZE_SMALL, GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE, {}
	)


func _medium_request(root_seed: int = 1234) -> GenerationRequest:
	return GenerationRequest.new(
		root_seed, &"node_1", &"combat", &"medium_combat_basic",
		GenerationRequest.SIZE_MEDIUM, GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE, {}
	)


# A compact terrain fingerprint of a generation payload's board snapshot (cell terrains in row-major
# order), used to compare candidates across attempts/runs WITHOUT depending on the generator's internal
# fingerprint helper.
func _payload_terrain_fingerprint(result_value: GenerationResult) -> String:
	var board_snapshot: Dictionary = result_value.payload.get("board")
	var parts: PackedStringArray = PackedStringArray()
	for cell_value: Variant in (board_snapshot.get("cells") as Array):
		parts.append(str(int((cell_value as Dictionary).get("terrain"))))
	return "".join(parts)


func _same_seed_recipe_reproduces_same_final_result() -> void:
	# AC2: same root_seed + recipe -> identical final result. With the REAL validator (baseline passes on
	# attempt 0), the two runs must produce the same success payload + attempts == 1.
	var first: GenerationResult = LevelGenerator.generate(_medium_request(4242), _repository(), _enemy_repository())
	var second: GenerationResult = LevelGenerator.generate(_medium_request(4242), _repository(), _enemy_repository())
	assert_true(first.succeeded and second.succeeded, "AC2: the same seed must succeed both times. Error: %s / %s" % [first.diagnostics, second.diagnostics])
	assert_equal(int(first.diagnostics.get("attempts")), int(second.diagnostics.get("attempts")), "AC2: the same seed must report the same attempt count.")
	assert_equal(_payload_terrain_fingerprint(first), _payload_terrain_fingerprint(second), "AC2: the same seed must reproduce a byte-identical final candidate.")
	assert_equal(first.payload.get("rewards"), second.payload.get("rewards"), "AC2: the same seed must reproduce identical reward markers.")


func _same_seed_reproduces_same_final_error_when_always_failing() -> void:
	# AC2: deterministic FINAL ERROR. Two always-fail runs with the same seed produce the same structured
	# error (same phase, code, reason, seed, attempts).
	var first: GenerationResult = LevelGenerator.generate(_medium_request(909), _repository(), _enemy_repository(), AlwaysFailValidator.new())
	var second: GenerationResult = LevelGenerator.generate(_medium_request(909), _repository(), _enemy_repository(), AlwaysFailValidator.new())
	assert_true(first.is_error() and second.is_error(), "AC2: an always-fail validator must error both times.")
	assert_equal(first.failed_phase, second.failed_phase, "AC2: the same-seed final error must report the same phase.")
	assert_equal(first.error_code, second.error_code, "AC2: the same-seed final error must report the same code.")
	assert_equal(first.reason, second.reason, "AC2: the same-seed final error must report the same reason.")
	assert_equal(first.seed, second.seed, "AC2: the same-seed final error must carry the same seed.")
	assert_equal(int(first.diagnostics.get("attempts")), int(second.diagnostics.get("attempts")), "AC2: the same-seed final error must report the same attempt count.")


func _always_fail_validator_exhausts_attempt_cap_with_structured_error() -> void:
	# AC2: an injected always-fail validator exhausts the attempt cap. The validator must be invoked
	# exactly MAX_GENERATION_ATTEMPTS times, and the final result is a structured error with
	# attempts == MAX_GENERATION_ATTEMPTS.
	var failing: AlwaysFailValidator = AlwaysFailValidator.new()
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(909), _repository(), _enemy_repository(), failing)
	assert_true(result_value.is_error(), "AC2: an always-fail validator must produce a structured error, not a payload.")
	assert_false(result_value.has_payload(), "AC2: an exhausted-retry failure must not return a payload.")
	assert_equal(failing.calls, LevelGenerator.MAX_GENERATION_ATTEMPTS, "AC2: the validator must be invoked exactly MAX_GENERATION_ATTEMPTS times (the attempt cap).")
	assert_equal(int(result_value.diagnostics.get("attempts")), LevelGenerator.MAX_GENERATION_ATTEMPTS, "AC2: the final error must report attempts == MAX_GENERATION_ATTEMPTS.")


func _final_error_carries_seed_phase_reason_and_attempts() -> void:
	# AC2: the final-failure GenerationResult.error carries seed + failed_phase + error_code + reason +
	# attempts in diagnostics (compact, never a grid dump).
	var failing: AlwaysFailValidator = AlwaysFailValidator.new()
	failing.fail_code = &"unreachable_reward"
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(515), _repository(), _enemy_repository(), failing)
	assert_equal(result_value.seed, "515", "AC2: the final error must carry the request seed string.")
	# unreachable_reward maps to PHASE_VALIDATION (LevelValidator.phase_for_code).
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_VALIDATION, "AC2: an unreachable_reward failure must report PHASE_VALIDATION.")
	assert_equal(result_value.error_code, &"unreachable_reward", "AC2: the final error must carry the failing check code.")
	assert_true(result_value.reason != &"", "AC2: the final error must carry a machine-stable reason.")
	assert_true(result_value.diagnostics.has("attempts"), "AC2: the final error diagnostics must carry the attempt count.")
	assert_true(result_value.diagnostics.has("recipe_id"), "AC2: the final error diagnostics must carry the recipe id.")
	assert_false(result_value.diagnostics.has("terrain"), "AC2: the final error diagnostics must stay compact (no grid dump).")


func _pathing_failure_maps_to_pathing_phase() -> void:
	# AC2/AC4: a validator failure whose code maps to PHASE_PATHING (soft_lock_detected) reports
	# PHASE_PATHING (distinct from the PHASE_VALIDATION reward/readability failures).
	var failing: AlwaysFailValidator = AlwaysFailValidator.new()
	failing.fail_code = &"soft_lock_detected"
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(616), _repository(), _enemy_repository(), failing)
	assert_true(result_value.is_error(), "A soft-lock failure must error.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_PATHING, "AC4: a soft_lock_detected failure must report PHASE_PATHING.")


func _fail_then_pass_succeeds_on_later_attempt_and_reports_index() -> void:
	# AC2: an injected fail-then-pass validator (fail attempt 0, pass attempt 1) succeeds and reports
	# attempts == 2 (the success attempt index + 1).
	var validator: FailThenPassValidator = FailThenPassValidator.new()
	validator.fail_count = 1
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(1234), _repository(), _enemy_repository(), validator)
	assert_true(result_value.succeeded, "AC2: a fail-then-pass validator must eventually succeed. Error: %s" % result_value.diagnostics)
	assert_equal(int(result_value.diagnostics.get("attempts")), 2, "AC2: a fail-on-attempt-0-pass-on-attempt-1 run must report attempts == 2.")
	assert_equal(validator.calls, 2, "AC2: the validator must have been invoked exactly twice (attempt 0 fail + attempt 1 pass).")


func _fail_for_several_then_pass_reports_correct_attempt_count() -> void:
	# AC2: fail the first 3 attempts, pass the 4th -> attempts == 4 (still under the cap of 8).
	var validator: FailThenPassValidator = FailThenPassValidator.new()
	validator.fail_count = 3
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(1234), _repository(), _enemy_repository(), validator)
	assert_true(result_value.succeeded, "AC2: a fail-3-then-pass validator must succeed (4 <= MAX). Error: %s" % result_value.diagnostics)
	assert_equal(int(result_value.diagnostics.get("attempts")), 4, "AC2: a fail-first-3-then-pass run must report attempts == 4.")


func _attempt_zero_is_unperturbed() -> void:
	# AC2 hard invariant: attempt 0 uses the UNPERTURBED level seed. _attempt_seed(seed, 0) must equal the
	# base seed exactly (so the pinned terrain fingerprints stay byte-identical).
	for seed_value: int in [0, 1, 1234, 8675309, 2147483646]:
		assert_equal(LevelGenerator._attempt_seed(seed_value, 0), seed_value, "AC2: _attempt_seed(seed, 0) must return the base seed unchanged (attempt-0 invariant) for seed %d." % seed_value)


func _perturbed_attempt_differs_deterministically_from_attempt_zero() -> void:
	# AC2: attempt i>0's candidate differs DETERMINISTICALLY from attempt 0's. With a fail-then-pass
	# validator that fails attempt 0 and passes attempt 1, the returned (attempt-1) candidate must differ
	# from the real-validator attempt-0 candidate for the same seed — proving the seed-mix perturbed the
	# layout. And re-running the fail-then-pass must reproduce the SAME perturbed candidate (deterministic).
	var seed_value: int = 24680
	var attempt0: GenerationResult = LevelGenerator.generate(_medium_request(seed_value), _repository(), _enemy_repository())
	assert_true(attempt0.succeeded, "Attempt-0 (real validator) must succeed for the perturbation probe.")
	assert_equal(int(attempt0.diagnostics.get("attempts")), 1, "Attempt-0 baseline must report attempts == 1.")

	var validator_a: FailThenPassValidator = FailThenPassValidator.new()
	var perturbed_a: GenerationResult = LevelGenerator.generate(_medium_request(seed_value), _repository(), _enemy_repository(), validator_a)
	assert_true(perturbed_a.succeeded, "The fail-then-pass run must succeed on attempt 1.")
	assert_equal(int(perturbed_a.diagnostics.get("attempts")), 2, "The fail-then-pass run must report attempts == 2.")

	assert_true(
		_payload_terrain_fingerprint(perturbed_a) != _payload_terrain_fingerprint(attempt0),
		"AC2: attempt 1's candidate must DIFFER from attempt 0's (the seed-mix perturbs the layout)."
	)

	# Determinism: a second fail-then-pass run with the same seed reproduces the SAME perturbed candidate.
	var validator_b: FailThenPassValidator = FailThenPassValidator.new()
	var perturbed_b: GenerationResult = LevelGenerator.generate(_medium_request(seed_value), _repository(), _enemy_repository(), validator_b)
	assert_equal(
		_payload_terrain_fingerprint(perturbed_a),
		_payload_terrain_fingerprint(perturbed_b),
		"AC2: the perturbed attempt-1 candidate must be DETERMINISTIC (same seed -> same perturbed candidate)."
	)


func _attempt_seed_is_deterministic_and_distinct_per_attempt() -> void:
	# AC2: the per-attempt seed mix is deterministic, distinct per attempt (for i>0), and never 0.
	var base_seed: int = 1234
	var seen: Dictionary = {}
	seen[LevelGenerator._attempt_seed(base_seed, 0)] = true
	for attempt: int in range(1, LevelGenerator.MAX_GENERATION_ATTEMPTS):
		var attempt_seed: int = LevelGenerator._attempt_seed(base_seed, attempt)
		assert_true(attempt_seed != 0, "AC2: a perturbed attempt seed must never be 0 (attempt %d)." % attempt)
		assert_equal(attempt_seed, LevelGenerator._attempt_seed(base_seed, attempt), "AC2: the attempt-seed mix must be deterministic (attempt %d)." % attempt)
		seen[attempt_seed] = true
	# All attempt seeds (incl. attempt 0) distinct: well-distributed mix avoids collisions for the cap.
	assert_equal(seen.size(), LevelGenerator.MAX_GENERATION_ATTEMPTS, "AC2: every attempt index must derive a distinct seed across the attempt cap.")


func _success_path_tags_validated_and_attempts() -> void:
	# AC2/3.6: the success diagnostics gain validated: true + attempts, for BOTH size classes, alongside
	# the existing 3.5 diagnostics.
	var small_result: GenerationResult = LevelGenerator.generate(_small_request(), _repository(), _enemy_repository())
	assert_true(small_result.succeeded, "Small generation should succeed. Error: %s" % small_result.diagnostics)
	assert_true(bool(small_result.diagnostics.get("validated")), "Story 3.6: Small success diagnostics must record validated: true.")
	assert_equal(int(small_result.diagnostics.get("attempts")), 1, "Story 3.6: a baseline Small candidate must pass on attempt 0 (attempts == 1).")

	var medium_result: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository())
	assert_true(medium_result.succeeded, "Medium generation should succeed. Error: %s" % medium_result.diagnostics)
	assert_true(bool(medium_result.diagnostics.get("validated")), "Story 3.6: Medium success diagnostics must record validated: true.")
	assert_equal(int(medium_result.diagnostics.get("attempts")), 1, "Story 3.6: a baseline Medium candidate must pass on attempt 0 (attempts == 1).")
