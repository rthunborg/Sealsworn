class_name LevelGenerator
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")
const MediumLevelLayoutGenerator = preload("res://scripts/generation/level/medium_level_layout_generator.gd")
const LevelValidator = preload("res://scripts/generation/level/level_validator.gd")

# Phased generation entry point for Epic 3. Stories 3.2-3.6 extend it into the full pipeline
# (route -> recipe -> layout -> pathing -> blockers -> hazards -> enemies -> rewards -> affinity ->
# validation -> final snapshot). It currently fires:
#   - recipe (Story 3.1): validate the request, resolve the recipe THROUGH the repository boundary
#     (AC3 — no raw file read, no hardcoded source), structured error on failure.
#   - layout (Stories 3.2 + 3.3): for a Small recipe, run the deterministic Small layout phase; for a
#     Medium recipe, run the deterministic Medium layout phase PLUS the AC2 readability validation.
#     Both return a REAL board payload (board snapshot validated through the strict
#     BoardState.try_from_snapshot path).
#   - enemies + rewards (Story 3.5): both phases place deterministic enemies (board entities, resolved
#     through the threaded EnemyRepository) + intended reward markers (payload), then re-verify reward
#     reachability.
#   - validation + bounded retry (Story 3.6): after build_board_snapshot, the COMPREHENSIVE LevelValidator
#     checks the built candidate (entrance->exit reachability, no soft-lock, no required gate, legal enemy
#     placement, entity-aware reachable rewards, fog/readability, safe first reveal). On PASS the success
#     payload is returned (now tagged validated: true + attempts). On FAIL the candidate is rejected and a
#     BOUNDED DETERMINISTIC RETRY re-attempts up to MAX_GENERATION_ATTEMPTS deterministically-perturbed
#     candidates; final failure returns a structured GenerationResult.error against the failing check's
#     phase (via LevelValidator.phase_for_code) carrying seed + phase + reason + compact diagnostics +
#     attempts.
#
# BOUNDED-RETRY DETERMINISM CONTRACT (Story 3.6 — the central design decision):
#   A generated candidate is a PURE function of (root_seed, recipe): each attempt builds
#   RngStreamSet.new(attempt_seed) and runs the layout+placement+validation. Re-running the same seed
#   yields the SAME candidate, so a naive retry would loop forever on a genuinely-bad seed. To make
#   retries produce DIFFERENT-but-DETERMINISTIC candidates, attempt index `i` (0-based) derives its layout
#   seed by mixing `i` into request.level_seed() via _attempt_seed (a documented stable mix mirroring
#   RngStreamSet._derive_seed). ATTEMPT 0 USES THE UNPERTURBED request.level_seed() EXACTLY
#   (_attempt_seed(seed, 0) == seed), so the existing seed-regression terrain fingerprints + all 3.2-3.5
#   generated-layout/placement tests stay byte-identical (no re-pin) — this is the hard invariant. The
#   loop is BOUNDED at MAX_GENERATION_ATTEMPTS (small, so the worst-case retry path stays well inside the
#   NFR4 < 3s load budget). Same (root_seed, recipe) -> identical final result (same attempt count, same
#   final candidate or same final error).
#
# TEST SEAM (Story 3.6): baseline candidates pass on attempt 0, so the retry loop + cap are exercised by
# injecting a validator outcome via the optional 4th `validator` param (defaulting to the real
# LevelValidator). The injected object must expose `validate(candidate: Dictionary) -> ActionResult`. The
# public 3-arg generate(request, recipe_repository, enemy_repository) signature stays working for all
# existing callers (the validator is an OPTIONAL 4th param with a real default).
#
# The enemy_repository is REQUIRED (mirroring recipe_repository): the baseline combat recipes all carry
# an enemy budget > 0, and resolving enemies through the repository boundary is the AC3 contract carried
# from 3.1. A null/empty repository surfaces a structured PHASE_ENEMIES error rather than placing
# nothing silently.

# Bounded-retry attempt cap (Story 3.6). A small bound: the validator + generation are cheap per-cell
# passes and NFR4 caps generated-level load at < 3s, so a small cap keeps the worst-case retry path well
# inside budget while still giving a genuinely-marginal seed several deterministic re-rolls. Attempt 0 is
# the unperturbed seed; attempts 1..MAX-1 are deterministically perturbed.
const MAX_GENERATION_ATTEMPTS: int = 8

static func generate(request: GenerationRequest, recipe_repository: LevelRecipeRepository, enemy_repository: EnemyRepository, validator: Object = null) -> GenerationResult:
	var seed_text: String = _seed_text(request)

	if request == null:
		return GenerationResult.error(
			GenerationResult.PHASE_RECIPE,
			&"invalid_generation_request",
			&"missing_request",
			seed_text,
			{}
		)

	# Request validation is part of the recipe-selection seam this story.
	var validation: ActionResult = request.validate()
	if validation.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_RECIPE,
			validation.error_code,
			&"request_validation_failed",
			seed_text,
			validation.metadata.duplicate(true)
		)

	# AC3: resolve the recipe through the repository boundary, never a raw file read.
	var recipe: LevelRecipeDefinition = null
	if recipe_repository != null:
		recipe = recipe_repository.get_recipe(request.recipe_id)
	if recipe == null:
		return GenerationResult.error(
			GenerationResult.PHASE_RECIPE,
			&"unknown_level_recipe",
			&"recipe_not_registered",
			seed_text,
			{"recipe_id": String(request.recipe_id)}
		)

	# The comprehensive validator runs on every attempt's built candidate. Default to the real
	# LevelValidator; a test may inject a stand-in (always-fail / fail-then-pass) to exercise the bounded
	# retry loop + cap without a genuinely-bad baseline seed.
	var active_validator: Object = validator
	if active_validator == null:
		active_validator = LevelValidator.new()

	# Layout phase (Stories 3.2 + 3.3) + enemy/reward placement (Story 3.5) + validation + bounded retry
	# (Story 3.6): dispatch on the resolved recipe size class. A size class that is neither small nor
	# medium (NOT reachable for valid requests today — validate() only allows small/medium) returns a
	# clearly-marked structured note rather than crashing.
	if recipe.size_class == LevelRecipeDefinition.SIZE_SMALL:
		return _run_layout_phase_with_retry(request, recipe, enemy_repository, active_validator, seed_text, SmallLevelLayoutGenerator.new(), false)
	if recipe.size_class == LevelRecipeDefinition.SIZE_MEDIUM:
		return _run_layout_phase_with_retry(request, recipe, enemy_repository, active_validator, seed_text, MediumLevelLayoutGenerator.new(), true)

	return GenerationResult.error(
		GenerationResult.PHASE_LAYOUT,
		&"unsupported_size_class_for_layout",
		&"size_class_has_no_layout_phase",
		seed_text,
		{"recipe_id": String(recipe.recipe_id), "size_class": String(recipe.size_class)}
	)


# Run the deterministic layout phase + enemy/reward placement + comprehensive validation under the
# bounded deterministic retry loop (Story 3.6). Shared by BOTH size classes (the generator is passed in
# and quacks the same `generate_layout` / [validate_readability] / `build_board_snapshot` surface);
# `run_readability` toggles the Medium-only AC2 readability pass that the generator exposes (Small has no
# validate_readability — the comprehensive LevelValidator gives Small the full readability pass instead).
#
# Per attempt:
#   - attempt 0 builds RngStreamSet.new(request.level_seed()) UNPERTURBED (fingerprint invariant);
#   - attempt i>0 builds RngStreamSet.new(_attempt_seed(level_seed, i)) (deterministic perturbation);
#   - generate_layout -> [Medium: validate_readability] -> build_board_snapshot;
#   - run the comprehensive LevelValidator over the built candidate (layout + BoardState + rewards).
# On the FIRST passing attempt, return the success payload tagged validated: true + attempts = i+1. A
# layout-construction / readability failure on a GIVEN attempt is ALSO retried (a future jittered
# generator could produce a transiently-bad layout) — only a FINAL exhaustion (or an unrecoverable error
# like a missing enemy repository, which would fail identically every attempt) returns a structured error
# carrying attempts = the number tried.
static func _run_layout_phase_with_retry(request: GenerationRequest, recipe: LevelRecipeDefinition, enemy_repository: EnemyRepository, validator: Object, seed_text: String, generator: Object, run_readability: bool) -> GenerationResult:
	var base_seed: int = request.level_seed()
	var last_error: GenerationResult = null

	for attempt_index: int in range(MAX_GENERATION_ATTEMPTS):
		var attempt_seed: int = _attempt_seed(base_seed, attempt_index)
		var streams: RngStreamSet = RngStreamSet.new(attempt_seed)

		var attempt_outcome: Dictionary = _run_single_attempt(request, recipe, enemy_repository, validator, seed_text, generator, run_readability, streams, attempt_index)
		if bool(attempt_outcome.get("ok", false)):
			return attempt_outcome.get("result") as GenerationResult

		last_error = attempt_outcome.get("result") as GenerationResult
		# An unrecoverable failure (one that would fail identically on every attempt — e.g. a missing/empty
		# enemy repository, a non-medium recipe fed to the Medium generator, or a null input) is not worth
		# retrying: re-rolling the seed cannot fix it. Surface it immediately (attempts = 1).
		if bool(attempt_outcome.get("unrecoverable", false)):
			return last_error

	# All attempts exhausted: the candidate could not be made valid within the bound. Return the LAST
	# failing attempt's structured error, re-stamped with the final attempt count.
	return _with_attempts(last_error, MAX_GENERATION_ATTEMPTS)


# Run ONE generation attempt with the given (already attempt-seeded) stream set. Returns a small outcome
# dict: {"ok": true, "result": <success GenerationResult>} on a fully-valid candidate, or {"ok": false,
# "result": <error GenerationResult>, "unrecoverable": bool} on any failure. `unrecoverable` marks errors
# that would recur identically every attempt (missing enemy repo, structural input error) so the caller
# can short-circuit the retry loop.
static func _run_single_attempt(request: GenerationRequest, recipe: LevelRecipeDefinition, enemy_repository: EnemyRepository, validator: Object, seed_text: String, generator: Object, run_readability: bool, streams: RngStreamSet, attempt_index: int) -> Dictionary:
	var attempts_so_far: int = attempt_index + 1

	var layout_result: ActionResult = generator.generate_layout(request, recipe, streams, enemy_repository)
	if layout_result.is_error():
		var mapped: GenerationResult = _map_layout_error(layout_result, seed_text, attempts_so_far)
		return {"ok": false, "result": mapped, "unrecoverable": _is_unrecoverable_layout_error(layout_result.error_code)}
	var layout: Dictionary = layout_result.metadata.get("layout")

	# Medium exposes the focused AC2 readability pass (excessive blockage / unreachable exit / unreadable
	# first reveal). Run it before the board build so a readability rejection is reported against
	# PHASE_VALIDATION with the focused validator's compact diagnostics (carried from 3.3). The
	# comprehensive LevelValidator re-runs the same readability subset, but keeping this call preserves the
	# Medium success-path behaviour the 3.3-3.5 tests pin.
	if run_readability:
		var readability_result: ActionResult = generator.validate_readability(layout)
		if readability_result.is_error():
			var readability_error: GenerationResult = GenerationResult.error(
				GenerationResult.PHASE_VALIDATION,
				readability_result.error_code,
				&"readability_validation_failed",
				seed_text,
				_diagnostics_with_attempts(readability_result.metadata, attempts_so_far)
			)
			return {"ok": false, "result": readability_error, "unrecoverable": false}

	var board_result: ActionResult = generator.build_board_snapshot(layout)
	if board_result.is_error():
		var board_error: GenerationResult = GenerationResult.error(
			GenerationResult.PHASE_LAYOUT,
			board_result.error_code,
			&"board_conversion_failed",
			seed_text,
			_diagnostics_with_attempts(board_result.metadata, attempts_so_far)
		)
		return {"ok": false, "result": board_error, "unrecoverable": false}
	var board_snapshot: Dictionary = board_result.metadata.get("board_snapshot")
	var board: Object = board_result.metadata.get("board")

	# Story 3.6: run the comprehensive validator over the built candidate (layout + validated BoardState +
	# reward markers). It draws NO RNG (pure query), so it does not perturb the level stream / the
	# fingerprints. A failure rejects THIS candidate; the caller retries with a perturbed seed.
	var candidate: Dictionary = {
		"layout": layout,
		"board": board,
		"rewards": layout.get("rewards", [])
	}
	var validation: ActionResult = validator.validate(candidate)
	if validation.is_error():
		var failed_phase: StringName = LevelValidator.phase_for_code(validation.error_code)
		var validation_error: GenerationResult = GenerationResult.error(
			failed_phase,
			validation.error_code,
			&"level_validation_failed",
			seed_text,
			_validation_diagnostics(validation.metadata, recipe, attempts_so_far)
		)
		return {"ok": false, "result": validation_error, "unrecoverable": false}

	# PASS: assemble the shared success payload + diagnostics, tagged validated: true + attempts.
	var phase: StringName = GenerationResult.PHASE_VALIDATION if run_readability else GenerationResult.PHASE_LAYOUT
	var success: GenerationResult = _ok_with_payload(phase, recipe, layout, board_snapshot, seed_text, attempts_so_far, validation.metadata)
	return {"ok": true, "result": success}


# Derive attempt index `i`'s layout seed from the base level seed. ATTEMPT 0 RETURNS THE BASE SEED
# UNCHANGED (the fingerprint invariant — attempt 0 must reproduce the byte-identical 3.2-3.5 layout). For
# i > 0 the seed is mixed with `i` using a stable LCG-style mix mirroring RngStreamSet._derive_seed (xor a
# stable per-attempt hash, LCG multiply/add, mask to 31 bits, avoid 0) so attempt seeds are well-
# distributed, deterministic, and never 0. Pure: does NOT mutate the request.
static func _attempt_seed(base_seed: int, attempt_index: int) -> int:
	if attempt_index == 0:
		return base_seed
	# Mix the attempt index into the base seed. The +1 offset keeps the per-attempt salt non-zero even for
	# attempt_index patterns, and the mix mirrors the named-stream seed derivation discipline.
	var salt: int = (attempt_index * 2654435761 + 40503) & 0x7fffffff
	var mixed: int = (base_seed & 0x7fffffff) ^ salt
	mixed = (mixed * 1103515245 + 12345) & 0x7fffffff
	if mixed == 0:
		return 1
	return mixed


# Map a generate_layout failure onto the right GenerationResult phase. The layout step also performs
# enemy + reward placement (Story 3.5), so its error codes span layout construction, enemy-repository /
# placement, and reward reachability. Route each to its architecture phase so diagnostics are accurate.
# Carries the attempt count into diagnostics (Story 3.6).
static func _map_layout_error(layout_result: ActionResult, seed_text: String, attempts: int) -> GenerationResult:
	var code: StringName = layout_result.error_code
	if code == &"missing_enemy_repository" or code == &"no_placeable_enemy":
		return GenerationResult.error(
			GenerationResult.PHASE_ENEMIES,
			code,
			&"enemy_placement_failed",
			seed_text,
			_diagnostics_with_attempts(layout_result.metadata, attempts)
		)
	if code == &"unreachable_reward":
		return GenerationResult.error(
			GenerationResult.PHASE_VALIDATION,
			code,
			&"reward_reachability_failed",
			seed_text,
			_diagnostics_with_attempts(layout_result.metadata, attempts)
		)
	return GenerationResult.error(
		GenerationResult.PHASE_LAYOUT,
		code,
		&"layout_generation_failed",
		seed_text,
		_diagnostics_with_attempts(layout_result.metadata, attempts)
	)


# A layout error is "unrecoverable" (would recur identically on every attempt, so retrying is pointless)
# when it is a missing/empty enemy repository or a structural input/recipe error. A reward-reachability
# failure from the placer COULD differ across seeds, so it is recoverable (retryable).
static func _is_unrecoverable_layout_error(code: StringName) -> bool:
	return (
		code == &"missing_enemy_repository"
		or code == &"no_placeable_enemy"
		or code == &"invalid_layout_request"
		or code == &"invalid_layout_recipe"
		or code == &"invalid_layout_streams"
		or code == &"unsupported_size_class_for_layout"
	)


# Assemble the shared success payload + diagnostics for both size classes. Pure serializable payload (no
# BoardState/RefCounted/scene refs): the converted board snapshot (with placed enemies in `entities`)
# plus entrance/exit/blockers + the `rewards` markers, size_class/recipe_id, and the `level`-seed string.
# Survives a JSON.stringify/parse_string round-trip and re-converts via BoardState.try_from_snapshot.
# The diagnostics carry the existing phase/recipe/size/blocker/wrinkle keys PLUS Story 3.5's compact
# enemy_count / reward_count / optional_reward_count, PLUS Story 3.6's validated: true + attempts +
# compact validator report counts.
static func _ok_with_payload(phase: StringName, recipe: LevelRecipeDefinition, layout: Dictionary, board_snapshot: Dictionary, seed_text: String, attempts: int, validation_report: Dictionary) -> GenerationResult:
	var enemies: Array = layout.get("enemies", [])
	var rewards: Array = layout.get("rewards", [])
	var payload: Dictionary = {
		"board": board_snapshot,
		"entrance": layout.get("entrance").duplicate(true),
		"exit": layout.get("exit").duplicate(true),
		"blockers": layout.get("blockers").duplicate(true),
		"rewards": rewards.duplicate(true),
		"size_class": String(recipe.size_class),
		"recipe_id": String(recipe.recipe_id),
		"level_seed": seed_text
	}
	return GenerationResult.ok(payload, {
		"phase": String(phase),
		"recipe_id": String(recipe.recipe_id),
		"size_class": String(recipe.size_class),
		"blocker_count": layout.get("blockers").size(),
		"wrinkles": (layout.get("wrinkle_kinds", []) as Array).duplicate(),
		"wrinkle_count": (layout.get("wrinkle_kinds", []) as Array).size(),
		"enemy_count": enemies.size(),
		"reward_count": rewards.size(),
		"optional_reward_count": int(layout.get("optional_reward_count", 0)),
		"validated": true,
		"attempts": attempts,
		"validation_report": validation_report.duplicate(true)
	})


# Compose the final-failure diagnostics for a comprehensive-validator rejection: the validator's compact
# diagnostics PLUS attempts + recipe_id/size_class (NEVER a full grid dump). [Story 3.6 AC2]
static func _validation_diagnostics(validator_metadata: Dictionary, recipe: LevelRecipeDefinition, attempts: int) -> Dictionary:
	var diagnostics: Dictionary = validator_metadata.duplicate(true)
	diagnostics["attempts"] = attempts
	diagnostics["recipe_id"] = String(recipe.recipe_id)
	diagnostics["size_class"] = String(recipe.size_class)
	return diagnostics


static func _diagnostics_with_attempts(metadata: Dictionary, attempts: int) -> Dictionary:
	var diagnostics: Dictionary = metadata.duplicate(true)
	diagnostics["attempts"] = attempts
	return diagnostics


# Re-stamp a structured error's diagnostics with the FINAL attempt count (used when the retry loop is
# exhausted). Rebuilds the GenerationResult.error so its normalization (phase/code/reason) is preserved.
static func _with_attempts(error_result: GenerationResult, attempts: int) -> GenerationResult:
	if error_result == null:
		return null
	var diagnostics: Dictionary = error_result.diagnostics.duplicate(true)
	diagnostics["attempts"] = attempts
	return GenerationResult.error(
		error_result.failed_phase,
		error_result.error_code,
		error_result.reason,
		error_result.seed,
		diagnostics
	)


static func _seed_text(request: GenerationRequest) -> String:
	if request == null:
		return ""
	return str(request.level_seed())
