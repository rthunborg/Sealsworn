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

# Phased generation entry point for Epic 3. Stories 3.2-3.6 extend it into the full pipeline
# (route -> recipe -> layout -> pathing -> blockers -> hazards -> enemies -> rewards -> affinity ->
# validation -> final snapshot). It currently fires:
#   - recipe (Story 3.1): validate the request, resolve the recipe THROUGH the repository boundary
#     (AC3 — no raw file read, no hardcoded source), structured error on failure.
#   - layout (Stories 3.2 + 3.3): for a Small recipe, run the deterministic Small layout phase; for a
#     Medium recipe, run the deterministic Medium layout phase PLUS the AC2 readability validation.
#     Both return a REAL board payload (board snapshot validated through the strict
#     BoardState.try_from_snapshot path). Layout-construction failures report against PHASE_LAYOUT;
#     AC2 readability rejections report against PHASE_VALIDATION.
#   - enemies + rewards (Story 3.5): both phases place deterministic enemies (board entities, resolved
#     through the threaded EnemyRepository) + intended reward markers (payload), then re-verify reward
#     reachability. An enemy-repository / placement failure reports against PHASE_ENEMIES; a reward-
#     reachability rejection reports against PHASE_VALIDATION. The success diagnostics gain
#     enemy_count / reward_count / optional_reward_count.
#
# The enemy_repository is REQUIRED (mirroring recipe_repository): the baseline combat recipes all carry
# an enemy budget > 0, and resolving enemies through the repository boundary is the AC3 contract carried
# from 3.1. A null/empty repository surfaces a structured PHASE_ENEMIES error rather than placing
# nothing silently.
static func generate(request: GenerationRequest, recipe_repository: LevelRecipeRepository, enemy_repository: EnemyRepository) -> GenerationResult:
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

	# Layout phase (Stories 3.2 + 3.3) + enemy/reward placement (Story 3.5): dispatch on the resolved
	# recipe size class. Small runs the Small layout phase (Story 3.2); Medium runs the Medium layout
	# phase + AC2 readability validation (Story 3.3). Both then place enemies + rewards (Story 3.5). A
	# size class that is neither (NOT reachable for valid requests today — validate() only allows
	# small/medium) returns a clearly-marked structured note rather than crashing.
	if recipe.size_class == LevelRecipeDefinition.SIZE_SMALL:
		return _run_small_layout_phase(request, recipe, enemy_repository, seed_text)
	if recipe.size_class == LevelRecipeDefinition.SIZE_MEDIUM:
		return _run_medium_layout_phase(request, recipe, enemy_repository, seed_text)

	return GenerationResult.error(
		GenerationResult.PHASE_LAYOUT,
		&"unsupported_size_class_for_layout",
		&"size_class_has_no_layout_phase",
		seed_text,
		{"recipe_id": String(recipe.recipe_id), "size_class": String(recipe.size_class)}
	)


# Run the deterministic Small layout phase + enemy/reward placement and assemble the real
# GenerationResult payload. The layout RNG is derived from request.level_seed() via a fresh
# RngStreamSet — every layout/placement-affecting draw routes through the named `level` stream
# (GenerationRequest.draw_layout_int/float). Layout/board-conversion failures report against
# PHASE_LAYOUT; an enemy-repository/placement failure reports against PHASE_ENEMIES; a reward-
# reachability rejection reports against PHASE_VALIDATION (AC4 discipline carried from Story 3.1).
static func _run_small_layout_phase(request: GenerationRequest, recipe: LevelRecipeDefinition, enemy_repository: EnemyRepository, seed_text: String) -> GenerationResult:
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: SmallLevelLayoutGenerator = SmallLevelLayoutGenerator.new()

	var layout_result: ActionResult = generator.generate_layout(request, recipe, streams, enemy_repository)
	if layout_result.is_error():
		return _map_layout_error(layout_result, seed_text)
	var layout: Dictionary = layout_result.metadata.get("layout")

	var board_result: ActionResult = generator.build_board_snapshot(layout)
	if board_result.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_LAYOUT,
			board_result.error_code,
			&"board_conversion_failed",
			seed_text,
			board_result.metadata.duplicate(true)
		)
	var board_snapshot: Dictionary = board_result.metadata.get("board_snapshot")

	return _ok_with_payload(GenerationResult.PHASE_LAYOUT, recipe, layout, board_snapshot, seed_text)


# Run the deterministic Medium layout phase (Story 3.3) + enemy/reward placement (Story 3.5): generate
# the layout (which now also places enemies + rewards), run the AC2 readability validation, convert to a
# board snapshot, and assemble the real GenerationResult payload. The layout RNG is derived from
# request.level_seed() via a fresh RngStreamSet — every layout/placement-affecting draw routes through
# the named `level` stream (GenerationRequest.draw_layout_int/float). Layout/board-conversion failures
# report against PHASE_LAYOUT; an enemy-repository/placement failure reports against PHASE_ENEMIES; AC2
# readability + reward-reachability rejections report against PHASE_VALIDATION (carrying the validator's
# compact diagnostics).
static func _run_medium_layout_phase(request: GenerationRequest, recipe: LevelRecipeDefinition, enemy_repository: EnemyRepository, seed_text: String) -> GenerationResult:
	var streams: RngStreamSet = RngStreamSet.new(request.level_seed())
	var generator: MediumLevelLayoutGenerator = MediumLevelLayoutGenerator.new()

	var layout_result: ActionResult = generator.generate_layout(request, recipe, streams, enemy_repository)
	if layout_result.is_error():
		return _map_layout_error(layout_result, seed_text)
	var layout: Dictionary = layout_result.metadata.get("layout")

	# AC2 readability validation (excessive blockage / unreachable exit / unreadable first reveal).
	# A rejection is reported against PHASE_VALIDATION with the validator's compact diagnostics.
	var readability_result: ActionResult = generator.validate_readability(layout)
	if readability_result.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_VALIDATION,
			readability_result.error_code,
			&"readability_validation_failed",
			seed_text,
			readability_result.metadata.duplicate(true)
		)

	var board_result: ActionResult = generator.build_board_snapshot(layout)
	if board_result.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_LAYOUT,
			board_result.error_code,
			&"board_conversion_failed",
			seed_text,
			board_result.metadata.duplicate(true)
		)
	var board_snapshot: Dictionary = board_result.metadata.get("board_snapshot")

	# A successful Medium generation passed the layout phase, enemy/reward placement, and the AC2
	# readability + reward-reachability passes; report the validation phase as the best descriptor of a
	# fully-checked Medium level. Same payload shape as the Small payload.
	return _ok_with_payload(GenerationResult.PHASE_VALIDATION, recipe, layout, board_snapshot, seed_text)


# Map a generate_layout failure onto the right GenerationResult phase. The layout step now also performs
# enemy + reward placement (Story 3.5), so its error codes span layout construction, enemy-repository /
# placement, and reward reachability. Route each to its architecture phase so diagnostics are accurate.
static func _map_layout_error(layout_result: ActionResult, seed_text: String) -> GenerationResult:
	var code: StringName = layout_result.error_code
	if code == &"missing_enemy_repository" or code == &"no_placeable_enemy":
		return GenerationResult.error(
			GenerationResult.PHASE_ENEMIES,
			code,
			&"enemy_placement_failed",
			seed_text,
			layout_result.metadata.duplicate(true)
		)
	if code == &"unreachable_reward":
		return GenerationResult.error(
			GenerationResult.PHASE_VALIDATION,
			code,
			&"reward_reachability_failed",
			seed_text,
			layout_result.metadata.duplicate(true)
		)
	return GenerationResult.error(
		GenerationResult.PHASE_LAYOUT,
		code,
		&"layout_generation_failed",
		seed_text,
		layout_result.metadata.duplicate(true)
	)


# Assemble the shared success payload + diagnostics for both size classes. Pure serializable payload (no
# BoardState/RefCounted/scene refs): the converted board snapshot (with placed enemies in `entities`)
# plus entrance/exit/blockers + the `rewards` markers, size_class/recipe_id, and the `level`-seed string.
# Survives a JSON.stringify/parse_string round-trip and re-converts via BoardState.try_from_snapshot.
# The diagnostics carry the existing phase/recipe/size/blocker/wrinkle keys PLUS Story 3.5's compact
# enemy_count / reward_count / optional_reward_count (per-entity/per-reward detail lives in the payload).
static func _ok_with_payload(phase: StringName, recipe: LevelRecipeDefinition, layout: Dictionary, board_snapshot: Dictionary, seed_text: String) -> GenerationResult:
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
		"optional_reward_count": int(layout.get("optional_reward_count", 0))
	})


static func _seed_text(request: GenerationRequest) -> String:
	if request == null:
		return ""
	return str(request.level_seed())
