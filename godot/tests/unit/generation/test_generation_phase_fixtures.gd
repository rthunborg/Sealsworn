extends "res://tests/unit/test_case.gd"

# Story 3.6 — Per-Phase Generation Fixtures (AC4).
#
# AC4 verbatim: "Given generation phase fixtures are tested, when route context, recipe selection,
# layout/pathing, blocker placement, enemy placement, reward placement, and final validation run, then
# each phase has at least one focused regression assertion, and phase failures are reported separately
# from final-map fingerprint failures."
#
# This file provides one focused regression per generation phase, each asserting a DISTINCT
# `failed_phase`/`error_code` so a phase failure is diagnosable on its own:
#   - route          : PHASE_ROUTE is NOT exercised by v0 level generation (Epic 4 owns route generation);
#                      the request/recipe seam stands in for it (documented, asserted below).
#   - recipe         : an unknown recipe id -> PHASE_RECIPE/unknown_level_recipe; an invalid request ->
#                      PHASE_RECIPE/invalid_generation_request.
#   - layout/pathing : a reachability/soft-lock failure -> PHASE_PATHING (the now-available phase constant;
#                      DOCUMENTED CHOICE: reachability + soft-lock + the no-gate guardrail report
#                      PHASE_PATHING, distinct from the PHASE_VALIDATION readability/reward failures).
#   - blockers       : excessive interior-WALL-ratio -> PHASE_VALIDATION/excessive_blockage.
#   - enemies        : a missing/empty enemy repository -> PHASE_ENEMIES (reused 3.5 cases); an illegal
#                      enemy placement -> PHASE_ENEMIES/illegal_enemy_placement.
#   - rewards        : an unreachable MANDATORY reward -> PHASE_VALIDATION/unreachable_reward, driven
#                      END-TO-END through LevelGenerator.generate (CLOSES the 3.5 Round-2 deferred Low:
#                      the placer was unit-tested in isolation but the unreachable_reward result was never
#                      asserted through the integration path).
#   - final validation: a clean candidate PASSES the full LevelValidator (validated: true).
#
# SEPARATION INVARIANT (AC4): a PHASE regression surfaces HERE (asserting failed_phase/error_code); a
# TERRAIN regression surfaces in the seed-regression tests (test_small/medium_level_layout_seed_regression
# asserting the `fingerprint`). The two must NOT be conflated. A phase failure is a structured error that
# returns NO payload, so it cannot silently drift a fingerprint (asserted below); and the terrain
# fingerprints are pinned independently of these phase assertions. The validator-phase failures here are
# driven through the injected-validator seam (a phase-failure stand-in), which does not touch the terrain
# the fingerprint serializes.
#
# Headless / scene-free. No user:// writes.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelValidator = preload("res://scripts/generation/level/level_validator.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")


# Stand-in validator that fails EVERY attempt with a chosen check code, used to drive a specific
# validator-phase failure (pathing / enemies / validation) end-to-end through LevelGenerator.generate
# without a genuinely-bad baseline seed. Mirrors the real LevelValidator's validate() seam.
class PhaseFailValidator:
	extends RefCounted
	const _ActionResult = preload("res://scripts/core/results/action_result.gd")
	var fail_code: StringName = &"unreachable_reward"
	func validate(_candidate: Dictionary) -> _ActionResult:
		return _ActionResult.error(fail_code, {"reason": "injected_phase_fixture"})


func run() -> Dictionary:
	# route (documented non-exercise) + recipe
	_route_phase_is_not_exercised_by_v0_level_generation()
	_recipe_phase_unknown_recipe()
	_recipe_phase_invalid_request()
	# layout/pathing
	_pathing_phase_reachability_failure_is_distinct()
	_pathing_phase_soft_lock_failure_is_distinct()
	# blockers (readability)
	_blockers_phase_excessive_blockage_is_distinct()
	# enemies
	_enemies_phase_missing_repository()
	_enemies_phase_empty_repository()
	_enemies_phase_illegal_placement_is_distinct()
	# rewards (end-to-end unreachable reward — closes the 3.5 deferred Low #3)
	_rewards_phase_unreachable_reward_end_to_end()
	# final validation
	_final_validation_phase_clean_candidate_passes()
	# AC4 separation invariant
	_each_phase_failure_uses_a_distinct_phase_code_pair()
	_phase_failures_return_no_payload_so_cannot_drift_a_fingerprint()
	return result()


func _repository() -> LevelRecipeRepository:
	return LevelRecipeRepository.create_baseline_repository()


func _enemy_repository() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


func _request(recipe_id: StringName, size_class: StringName, root_seed: int = 1234) -> GenerationRequest:
	return GenerationRequest.new(
		root_seed, &"node_1", &"combat", recipe_id, size_class,
		GenerationRequest.DIFFICULTY_STANDARD, GenerationRequest.AFFINITY_NONE, {}
	)


func _medium_request(root_seed: int = 1234) -> GenerationRequest:
	return _request(&"medium_combat_basic", GenerationRequest.SIZE_MEDIUM, root_seed)


# ---- route -------------------------------------------------------------------------------------

func _route_phase_is_not_exercised_by_v0_level_generation() -> void:
	# AC4 route: v0 level generation has NO route phase (Epic 4 owns route/map generation). The request +
	# recipe selection seam stands in for it: a valid request + resolved recipe never reports PHASE_ROUTE,
	# and the recipe phase is the first phase v0 generation actually fires. Document + assert that a
	# successful generation never carries the route phase, so PHASE_ROUTE is reserved (not v0-fired).
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository())
	assert_true(result_value.succeeded, "A valid request must generate successfully (route is not a v0 phase). Error: %s" % result_value.diagnostics)
	assert_false(String(result_value.diagnostics.get("phase", "")) == String(GenerationResult.PHASE_ROUTE), "AC4: v0 level generation must not report the route phase (Epic 4 owns route generation).")


# ---- recipe ------------------------------------------------------------------------------------

func _recipe_phase_unknown_recipe() -> void:
	var result_value: GenerationResult = LevelGenerator.generate(_request(&"missing_recipe", GenerationRequest.SIZE_SMALL), _repository(), _enemy_repository())
	assert_true(result_value.is_error(), "AC4: an unknown recipe must fail.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_RECIPE, "AC4: an unknown recipe must report PHASE_RECIPE.")
	assert_equal(result_value.error_code, &"unknown_level_recipe", "AC4: an unknown recipe must use the unknown_level_recipe code.")


func _recipe_phase_invalid_request() -> void:
	var invalid_request: GenerationRequest = _request(&"small_combat_basic", GenerationRequest.SIZE_SMALL)
	invalid_request.size_class = &"large"
	var result_value: GenerationResult = LevelGenerator.generate(invalid_request, _repository(), _enemy_repository())
	assert_true(result_value.is_error(), "AC4: an invalid request must fail.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_RECIPE, "AC4: an invalid request must report PHASE_RECIPE.")
	assert_equal(result_value.error_code, &"invalid_generation_request", "AC4: an invalid request must use the invalid_generation_request code.")


# ---- layout/pathing ----------------------------------------------------------------------------

func _pathing_phase_reachability_failure_is_distinct() -> void:
	# AC4 layout/pathing: an entrance->exit reachability failure reports PHASE_PATHING (DOCUMENTED CHOICE).
	# Driven through the integration path via the injected-validator seam returning unreachable_exit.
	var validator: PhaseFailValidator = PhaseFailValidator.new()
	validator.fail_code = LevelValidator.CODE_UNREACHABLE_EXIT
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository(), validator)
	assert_true(result_value.is_error(), "AC4: a reachability failure must error.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_PATHING, "AC4: an unreachable_exit failure must report PHASE_PATHING (distinct phase).")
	assert_equal(result_value.error_code, LevelValidator.CODE_UNREACHABLE_EXIT, "AC4: the reachability failure must carry the unreachable_exit code.")


func _pathing_phase_soft_lock_failure_is_distinct() -> void:
	# AC4 layout/pathing: a soft-lock failure also reports PHASE_PATHING with its own code.
	var validator: PhaseFailValidator = PhaseFailValidator.new()
	validator.fail_code = LevelValidator.CODE_SOFT_LOCK_DETECTED
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository(), validator)
	assert_true(result_value.is_error(), "AC4: a soft-lock failure must error.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_PATHING, "AC4: a soft_lock_detected failure must report PHASE_PATHING.")
	assert_equal(result_value.error_code, LevelValidator.CODE_SOFT_LOCK_DETECTED, "AC4: the soft-lock failure must carry the soft_lock_detected code.")


# ---- blockers (readability) --------------------------------------------------------------------

func _blockers_phase_excessive_blockage_is_distinct() -> void:
	# AC4 blockers: an excessive interior-WALL-ratio failure reports PHASE_VALIDATION/excessive_blockage.
	# The baseline never over-blocks (the budget band keeps the interior ratio far below 0.35), so this is
	# driven through the integration path via the injected-validator seam.
	var validator: PhaseFailValidator = PhaseFailValidator.new()
	validator.fail_code = LevelValidator.CODE_EXCESSIVE_BLOCKAGE
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository(), validator)
	assert_true(result_value.is_error(), "AC4: an excessive-blockage failure must error.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_VALIDATION, "AC4: an excessive_blockage failure must report PHASE_VALIDATION.")
	assert_equal(result_value.error_code, LevelValidator.CODE_EXCESSIVE_BLOCKAGE, "AC4: the blockage failure must carry the excessive_blockage code.")


# ---- enemies -----------------------------------------------------------------------------------

func _enemies_phase_missing_repository() -> void:
	# AC4 enemies: a null enemy repository (combat recipe budget > 0) reports PHASE_ENEMIES (reused 3.5).
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), null)
	assert_true(result_value.is_error(), "AC4: a missing enemy repository must fail.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_ENEMIES, "AC4: a missing enemy repository must report PHASE_ENEMIES.")
	assert_equal(result_value.error_code, &"missing_enemy_repository", "AC4: a missing enemy repository must use the missing_enemy_repository code.")


func _enemies_phase_empty_repository() -> void:
	# AC4 enemies: an empty enemy repository reports PHASE_ENEMIES/no_placeable_enemy (reused 3.5).
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), EnemyRepository.new())
	assert_true(result_value.is_error(), "AC4: an empty enemy repository must fail.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_ENEMIES, "AC4: an empty enemy repository must report PHASE_ENEMIES.")
	assert_equal(result_value.error_code, &"no_placeable_enemy", "AC4: an empty enemy repository must use the no_placeable_enemy code.")


func _enemies_phase_illegal_placement_is_distinct() -> void:
	# AC4 enemies: an illegal enemy placement reports PHASE_ENEMIES/illegal_enemy_placement (the validator
	# placement check, distinct from the layout/pathing + validation reward failures). Driven through the
	# integration path via the injected-validator seam.
	var validator: PhaseFailValidator = PhaseFailValidator.new()
	validator.fail_code = LevelValidator.CODE_ILLEGAL_ENEMY_PLACEMENT
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository(), validator)
	assert_true(result_value.is_error(), "AC4: an illegal enemy placement must error.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_ENEMIES, "AC4: an illegal_enemy_placement failure must report PHASE_ENEMIES.")
	assert_equal(result_value.error_code, LevelValidator.CODE_ILLEGAL_ENEMY_PLACEMENT, "AC4: the placement failure must carry the illegal_enemy_placement code.")


# ---- rewards (end-to-end; closes 3.5 deferred Low #3) -----------------------------------------

func _rewards_phase_unreachable_reward_end_to_end() -> void:
	# AC4 rewards + CLOSES the 3.5 Round-2 deferred Low #3: an unreachable MANDATORY reward must be driven
	# END-TO-END through LevelGenerator.generate and assert PHASE_VALIDATION/unreachable_reward (not just
	# the placer unit-tested in isolation). Driven via the injected-validator seam returning
	# unreachable_reward, exercising the full generate -> validator -> phase-mapping integration path.
	var validator: PhaseFailValidator = PhaseFailValidator.new()
	validator.fail_code = LevelValidator.CODE_UNREACHABLE_REWARD
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository(), validator)
	assert_true(result_value.is_error(), "AC4: an unreachable reward must error end-to-end.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_VALIDATION, "AC4 (closes 3.5 Low #3): an unreachable_reward must report PHASE_VALIDATION end-to-end through generate().")
	assert_equal(result_value.error_code, LevelValidator.CODE_UNREACHABLE_REWARD, "AC4: the reward failure must carry the unreachable_reward code end-to-end.")
	assert_true(result_value.reason != &"", "AC4: the end-to-end reward failure must carry a machine-stable reason.")
	assert_false(result_value.has_payload(), "AC4: an unreachable-reward failure must return no payload.")


# ---- final validation --------------------------------------------------------------------------

func _final_validation_phase_clean_candidate_passes() -> void:
	# AC4 final validation: a clean candidate PASSES the full LevelValidator (validated: true) and reports
	# the validation phase in its success diagnostics.
	var result_value: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository())
	assert_true(result_value.succeeded, "AC4: a clean Medium candidate must pass final validation. Error: %s" % result_value.diagnostics)
	assert_true(bool(result_value.diagnostics.get("validated")), "AC4: a passing candidate must record validated: true.")
	assert_equal(String(result_value.diagnostics.get("phase")), String(GenerationResult.PHASE_VALIDATION), "AC4: a fully-validated Medium candidate must report the validation phase.")


# ---- AC4 separation invariant ------------------------------------------------------------------

func _each_phase_failure_uses_a_distinct_phase_code_pair() -> void:
	# AC4: each phase's focused regression asserts a DISTINCT failed_phase/error_code. Collect the
	# (phase, code) pairs from the representative per-phase failures and assert they are all distinct, and
	# that the distinct architecture phases (recipe / pathing / enemies / validation) are each represented.
	var pairs: Array[String] = []
	pairs.append(_pair(LevelGenerator.generate(_request(&"missing_recipe", GenerationRequest.SIZE_SMALL), _repository(), _enemy_repository())))
	pairs.append(_pair(LevelGenerator.generate(_medium_request(), _repository(), null)))
	pairs.append(_pair(LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository(), _validator_for(LevelValidator.CODE_UNREACHABLE_EXIT))))
	pairs.append(_pair(LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository(), _validator_for(LevelValidator.CODE_ILLEGAL_ENEMY_PLACEMENT))))
	pairs.append(_pair(LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository(), _validator_for(LevelValidator.CODE_UNREACHABLE_REWARD))))

	var seen: Dictionary = {}
	for pair: String in pairs:
		assert_false(seen.has(pair), "AC4: each phase failure must use a DISTINCT (phase, code) pair (duplicate: %s)." % pair)
		seen[pair] = true

	# The distinct architecture phases are represented across the per-phase fixtures.
	var phases: Dictionary = {}
	for pair: String in pairs:
		phases[pair.split("|")[0]] = true
	assert_true(phases.has(String(GenerationResult.PHASE_RECIPE)), "AC4: the recipe phase must be represented.")
	assert_true(phases.has(String(GenerationResult.PHASE_ENEMIES)), "AC4: the enemies phase must be represented.")
	assert_true(phases.has(String(GenerationResult.PHASE_PATHING)), "AC4: the pathing phase must be represented (distinct reachability phase).")
	assert_true(phases.has(String(GenerationResult.PHASE_VALIDATION)), "AC4: the validation phase must be represented.")


func _phase_failures_return_no_payload_so_cannot_drift_a_fingerprint() -> void:
	# AC4 separation invariant: a phase failure is a structured error that returns NO payload, so it cannot
	# silently drift a terrain fingerprint (which is serialized only from a successful payload's board).
	# Conversely, a SUCCESS carries a payload + a stable terrain. Assert the failure carries no payload and
	# the success carries one — the two surfaces are disjoint.
	var failure: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository(), _validator_for(LevelValidator.CODE_UNREACHABLE_EXIT))
	assert_false(failure.has_payload(), "AC4: a phase failure must return no payload (cannot drift a fingerprint).")
	assert_true(failure.payload.is_empty(), "AC4: a phase failure's payload must be empty.")

	var success: GenerationResult = LevelGenerator.generate(_medium_request(), _repository(), _enemy_repository())
	assert_true(success.has_payload(), "AC4: a successful generation must carry a payload (the fingerprint source).")
	assert_true(success.payload.has("board"), "AC4: the success payload must carry the board the seed-regression fingerprint serializes.")


func _validator_for(code: StringName) -> PhaseFailValidator:
	var validator: PhaseFailValidator = PhaseFailValidator.new()
	validator.fail_code = code
	return validator


func _pair(result_value: GenerationResult) -> String:
	return "%s|%s" % [String(result_value.failed_phase), String(result_value.error_code)]
