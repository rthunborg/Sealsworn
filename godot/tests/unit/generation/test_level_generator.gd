extends "res://tests/unit/test_case.gd"

const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const BoardState = preload("res://scripts/tactical/board/board_state.gd")

func run() -> Dictionary:
	_known_small_recipe_returns_real_layout_payload()
	_small_payload_carries_validated_board_not_placeholder()
	_medium_recipe_returns_real_validated_layout_payload()
	_unknown_recipe_returns_structured_recipe_phase_error()
	_invalid_request_returns_structured_recipe_phase_error()
	_null_repository_returns_structured_error_without_crash()
	_recipe_is_resolved_through_repository_boundary()
	_missing_enemy_repository_returns_structured_enemies_phase_error()
	_placement_diagnostics_record_enemy_and_reward_counts()
	return result()


func _repository() -> LevelRecipeRepository:
	return LevelRecipeRepository.create_baseline_repository()


func _enemy_repository() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


func _valid_request(recipe_id: StringName = &"small_combat_basic", size_class: StringName = GenerationRequest.SIZE_SMALL) -> GenerationRequest:
	return GenerationRequest.new(
		1234,
		&"node_1",
		&"combat",
		recipe_id,
		size_class,
		GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE,
		{}
	)


func _known_small_recipe_returns_real_layout_payload() -> void:
	# Story 3.2 fills the GenerationResult.payload slot that 3.1 left empty: a Small recipe now
	# returns a REAL generated layout payload (board snapshot + entrance/exit/size_class/recipe_id),
	# fired against the layout phase — not the obsolete 3.1 {placeholder: true} payload.
	var result_value: GenerationResult = LevelGenerator.generate(_valid_request(), _repository(), _enemy_repository())

	assert_true(result_value.succeeded, "A known Small recipe should resolve to a successful generation result. Error: %s" % result_value.diagnostics)
	assert_true(result_value.has_payload(), "A successful Small generation should return a real layout payload.")
	assert_false(result_value.payload.get("placeholder", false), "The 3.2 Small payload must NOT be a placeholder.")
	assert_equal(result_value.payload.get("recipe_id"), "small_combat_basic", "Layout payload should echo the resolved recipe id.")
	assert_equal(result_value.payload.get("size_class"), "small", "Layout payload should echo the resolved size class.")
	assert_equal(result_value.payload.get("level_seed"), "1234", "Layout payload should carry the level seed string for traceability.")
	assert_equal(result_value.diagnostics.get("phase"), String(GenerationResult.PHASE_LAYOUT), "A Small generation should report the layout phase.")
	# Story 3.4: the success diagnostics now record the placed tactical-wrinkle kinds + count (AC1).
	assert_true(result_value.diagnostics.has("wrinkles"), "Story 3.4: Small success diagnostics must record the placed wrinkle kinds.")
	assert_true(result_value.diagnostics.has("wrinkle_count"), "Story 3.4: Small success diagnostics must record the wrinkle count.")
	assert_true(int(result_value.diagnostics.get("wrinkle_count")) >= 1, "Story 3.4: a Small combat recipe must place at least one wrinkle (min_tactical_wrinkles = 1).")
	assert_equal(int(result_value.diagnostics.get("wrinkle_count")), (result_value.diagnostics.get("wrinkles") as Array).size(), "Story 3.4: wrinkle_count must match the recorded kinds length.")


func _small_payload_carries_validated_board_not_placeholder() -> void:
	var result_value: GenerationResult = LevelGenerator.generate(_valid_request(), _repository(), _enemy_repository())
	# The payload board converts through the STRICT BoardState.try_from_snapshot path.
	assert_true(result_value.payload.has("board"), "The Small layout payload must contain a generated board snapshot.")
	var board_snapshot: Dictionary = result_value.payload.get("board")
	var restore_result = BoardState.try_from_snapshot(board_snapshot)
	assert_true(restore_result.succeeded, "The payload board must restore through the strict BoardState validator. Error: %s" % restore_result.metadata)
	var board = restore_result.metadata.get("board")
	assert_equal(board.width, 8, "Small layout board should be 8 wide (Small v0).")
	assert_equal(board.height, 8, "Small layout board should be 8 tall (Small v0).")
	# Story 3.5: the Small generated board now carries placed enemies (small_combat_basic budget 2..4).
	var small_recipe: LevelRecipeDefinition = _repository().get_recipe(&"small_combat_basic")
	assert_true(
		board.entity_count() >= small_recipe.enemy_budget_min and board.entity_count() <= small_recipe.enemy_budget_max,
		"Story 3.5: the Small generated board must carry enemies within the recipe budget [%d..%d] (got %d)." % [small_recipe.enemy_budget_min, small_recipe.enemy_budget_max, board.entity_count()]
	)
	# Payload must survive the REAL JSON transport, not just native dicts (Epic 3 retro / 1.x lesson).
	var json_payload = JSON.parse_string(JSON.stringify(result_value.payload))
	assert_true(json_payload is Dictionary, "The layout payload must survive a JSON stringify/parse round-trip.")
	var json_restore = BoardState.try_from_snapshot(json_payload.get("board"))
	assert_true(json_restore.succeeded, "The JSON-round-tripped payload board must still restore through the strict validator.")


func _medium_recipe_returns_real_validated_layout_payload() -> void:
	# Story 3.3 REPLACES the 3.2 {layout_pending: true} Medium payload: a Medium recipe now returns a
	# REAL generated layout payload (validated board snapshot + entrance/exit/size_class/recipe_id),
	# having passed the layout phase AND the AC2 readability validation. The successful Medium result
	# reports the validation phase (it cleared both layout construction and the AC2 readability pass).
	var result_value: GenerationResult = LevelGenerator.generate(
		_valid_request(&"medium_combat_basic", GenerationRequest.SIZE_MEDIUM),
		_repository(),
		_enemy_repository()
	)
	assert_true(result_value.succeeded, "A Medium recipe should resolve to a successful generation result. Error: %s" % result_value.diagnostics)
	assert_true(result_value.has_payload(), "A successful Medium generation should return a real layout payload.")
	assert_false(result_value.payload.get("layout_pending", false), "The 3.3 Medium payload must NOT be marked layout_pending.")
	assert_false(result_value.payload.get("placeholder", false), "The 3.3 Medium payload must NOT be a placeholder.")
	assert_true(result_value.payload.has("board"), "A Medium recipe must now produce a generated board (Story 3.3).")
	assert_equal(result_value.payload.get("recipe_id"), "medium_combat_basic", "Medium layout payload should echo the resolved recipe id.")
	assert_equal(result_value.payload.get("size_class"), "medium", "A Medium recipe payload should echo the medium size class.")
	assert_equal(result_value.payload.get("level_seed"), "1234", "Medium layout payload should carry the level seed string for traceability.")
	assert_equal(result_value.diagnostics.get("phase"), String(GenerationResult.PHASE_VALIDATION), "A successful Medium generation should report the validation phase (layout + AC2 readability cleared).")
	# Story 3.4: the success diagnostics now record the placed tactical-wrinkle kinds + count (AC1).
	assert_true(result_value.diagnostics.has("wrinkles"), "Story 3.4: Medium success diagnostics must record the placed wrinkle kinds.")
	assert_true(result_value.diagnostics.has("wrinkle_count"), "Story 3.4: Medium success diagnostics must record the wrinkle count.")
	assert_true(int(result_value.diagnostics.get("wrinkle_count")) >= 2, "Story 3.4: a Medium combat recipe must place at least two wrinkles (min_tactical_wrinkles = 2).")
	assert_equal(int(result_value.diagnostics.get("wrinkle_count")), (result_value.diagnostics.get("wrinkles") as Array).size(), "Story 3.4: wrinkle_count must match the recorded kinds length.")

	# The payload board converts through the STRICT BoardState.try_from_snapshot path, at 14x12.
	var board_snapshot: Dictionary = result_value.payload.get("board")
	var restore_result = BoardState.try_from_snapshot(board_snapshot)
	assert_true(restore_result.succeeded, "The Medium payload board must restore through the strict BoardState validator. Error: %s" % restore_result.metadata)
	var board = restore_result.metadata.get("board")
	assert_equal(board.width, 14, "Medium layout board should be 14 wide (Medium v0).")
	assert_equal(board.height, 12, "Medium layout board should be 12 tall (Medium v0).")
	# Story 3.5: the Medium generated board now carries placed enemies (medium_combat_basic budget 3..6).
	var medium_recipe: LevelRecipeDefinition = _repository().get_recipe(&"medium_combat_basic")
	assert_true(
		board.entity_count() >= medium_recipe.enemy_budget_min and board.entity_count() <= medium_recipe.enemy_budget_max,
		"Story 3.5: the Medium generated board must carry enemies within the recipe budget [%d..%d] (got %d)." % [medium_recipe.enemy_budget_min, medium_recipe.enemy_budget_max, board.entity_count()]
	)

	# Payload must survive the REAL JSON transport, not just native dicts (Epic 3 retro / 1.x lesson).
	var json_payload = JSON.parse_string(JSON.stringify(result_value.payload))
	assert_true(json_payload is Dictionary, "The Medium layout payload must survive a JSON stringify/parse round-trip.")
	var json_restore = BoardState.try_from_snapshot(json_payload.get("board"))
	assert_true(json_restore.succeeded, "The JSON-round-tripped Medium payload board must still restore through the strict validator.")


func _unknown_recipe_returns_structured_recipe_phase_error() -> void:
	var result_value: GenerationResult = LevelGenerator.generate(_valid_request(&"missing_recipe"), _repository(), _enemy_repository())

	assert_true(result_value.is_error(), "An unknown recipe id should produce an error result.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_RECIPE, "An unknown recipe should fail in the recipe phase.")
	assert_equal(result_value.error_code, &"unknown_level_recipe", "An unknown recipe should use the stable error code.")
	assert_true(result_value.reason != &"", "An unknown recipe failure should carry a machine-stable reason.")
	assert_equal(result_value.seed, "1234", "An unknown recipe failure should carry the request seed.")
	assert_equal(result_value.diagnostics.get("recipe_id"), "missing_recipe", "An unknown recipe failure should report the requested recipe id in diagnostics.")
	assert_false(result_value.has_payload(), "An unknown recipe failure should not return a payload.")


func _invalid_request_returns_structured_recipe_phase_error() -> void:
	var invalid_request: GenerationRequest = _valid_request()
	invalid_request.size_class = &"large"
	var result_value: GenerationResult = LevelGenerator.generate(invalid_request, _repository(), _enemy_repository())

	assert_true(result_value.is_error(), "An invalid request should produce an error result.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_RECIPE, "An invalid request should fail in the recipe phase this story.")
	assert_equal(result_value.error_code, &"invalid_generation_request", "An invalid request should use the request error code.")
	assert_true(result_value.diagnostics.has("field"), "An invalid request failure should report the offending field in diagnostics.")


func _null_repository_returns_structured_error_without_crash() -> void:
	var result_value: GenerationResult = LevelGenerator.generate(_valid_request(), null, _enemy_repository())
	assert_true(result_value.is_error(), "A null repository should produce a structured error, not a crash.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_RECIPE, "A null repository should fail in the recipe phase.")
	assert_equal(result_value.error_code, &"unknown_level_recipe", "A null repository should report the recipe as unresolvable.")


func _recipe_is_resolved_through_repository_boundary() -> void:
	# AC3: the selection seam resolves the recipe through the repository, not a raw file read.
	# A repository whose only registered recipe is custom must resolve THAT recipe (proving lookup
	# goes through the repository boundary, not a hardcoded/baseline source).
	var custom_definition: LevelRecipeDefinition = LevelRecipeDefinition.new(
		&"custom_arena",
		LevelRecipeDefinition.SIZE_MEDIUM,
		true,
		0.2,
		1,
		3,
		2,
		4,
		0,
		1,
		false,
		1,
		[LevelRecipeDefinition.WRINKLE_CHOKE_POINT],
		"Custom registered arena used to prove repository-boundary resolution."
	)
	var repository: LevelRecipeRepository = LevelRecipeRepository.create_repository_from_definitions([custom_definition])
	assert_true(repository != null, "Custom recipe repository should build from a valid definition.")

	var resolved: GenerationResult = LevelGenerator.generate(
		_valid_request(&"custom_arena", GenerationRequest.SIZE_MEDIUM),
		repository,
		_enemy_repository()
	)
	assert_true(resolved.succeeded, "A recipe registered only in this repository should resolve through the repository boundary.")
	assert_equal(resolved.payload.get("recipe_id"), "custom_arena", "Resolution should return the repository-registered recipe.")

	var unresolved: GenerationResult = LevelGenerator.generate(_valid_request(), repository, _enemy_repository())
	assert_true(unresolved.is_error(), "A baseline recipe not registered in this custom repository must NOT resolve from a raw/hardcoded source.")


func _missing_enemy_repository_returns_structured_enemies_phase_error() -> void:
	# Story 3.5 (AC1 repository-boundary discipline): a combat recipe with an enemy budget > 0 needs the
	# enemy repository threaded. A null enemy repository must surface a structured PHASE_ENEMIES error
	# (resolved through the boundary, not a crash or a silent no-placement). Mirrors the null-recipe-repo
	# structured-error case.
	var result_value: GenerationResult = LevelGenerator.generate(_valid_request(), _repository(), null)
	assert_true(result_value.is_error(), "A null enemy repository should produce a structured error, not a crash.")
	assert_equal(result_value.failed_phase, GenerationResult.PHASE_ENEMIES, "A null enemy repository should fail in the enemies phase.")
	assert_equal(result_value.error_code, &"missing_enemy_repository", "A null enemy repository should report the stable structured code.")
	assert_false(result_value.has_payload(), "A missing-enemy-repository failure should not return a payload.")

	# An empty enemy repository (no canonical enemies registered) is also a structured PHASE_ENEMIES
	# error rather than silently placing nothing while the budget is > 0.
	var empty_enemy_repository: EnemyRepository = EnemyRepository.new()
	var empty_result: GenerationResult = LevelGenerator.generate(_valid_request(), _repository(), empty_enemy_repository)
	assert_true(empty_result.is_error(), "An empty enemy repository should produce a structured error.")
	assert_equal(empty_result.failed_phase, GenerationResult.PHASE_ENEMIES, "An empty enemy repository should fail in the enemies phase.")
	assert_equal(empty_result.error_code, &"no_placeable_enemy", "An empty enemy repository should report the no-placeable-enemy code.")


func _placement_diagnostics_record_enemy_and_reward_counts() -> void:
	# Story 3.5 (AC1/AC2): the success diagnostics gain compact enemy_count / reward_count /
	# optional_reward_count alongside the existing keys, and the payload gains a `rewards` marker list.
	var small_result: GenerationResult = LevelGenerator.generate(_valid_request(), _repository(), _enemy_repository())
	assert_true(small_result.succeeded, "Small generation should succeed for the placement-diagnostics probe. Error: %s" % small_result.diagnostics)
	assert_true(small_result.diagnostics.has("enemy_count"), "Story 3.5: Small success diagnostics must record enemy_count.")
	assert_true(small_result.diagnostics.has("reward_count"), "Story 3.5: Small success diagnostics must record reward_count.")
	assert_true(small_result.diagnostics.has("optional_reward_count"), "Story 3.5: Small success diagnostics must record optional_reward_count.")
	var small_recipe: LevelRecipeDefinition = _repository().get_recipe(&"small_combat_basic")
	assert_true(
		int(small_result.diagnostics.get("enemy_count")) >= small_recipe.enemy_budget_min and int(small_result.diagnostics.get("enemy_count")) <= small_recipe.enemy_budget_max,
		"Story 3.5: Small enemy_count must fall within the recipe budget band [%d..%d]." % [small_recipe.enemy_budget_min, small_recipe.enemy_budget_max]
	)
	assert_true(small_result.payload.has("rewards"), "Story 3.5: the Small payload must carry a `rewards` marker list.")
	# reward_count diagnostic must equal the payload rewards length (compact count mirrors the payload).
	assert_equal(int(small_result.diagnostics.get("reward_count")), (small_result.payload.get("rewards") as Array).size(), "Story 3.5: reward_count must match the payload rewards length.")
	# The existing diagnostics keys stay preserved.
	assert_true(small_result.diagnostics.has("blocker_count"), "Existing blocker_count diagnostic must be preserved.")
	assert_true(small_result.diagnostics.has("wrinkle_count"), "Existing wrinkle_count diagnostic must be preserved.")

	var medium_result: GenerationResult = LevelGenerator.generate(
		_valid_request(&"medium_combat_basic", GenerationRequest.SIZE_MEDIUM),
		_repository(),
		_enemy_repository()
	)
	assert_true(medium_result.succeeded, "Medium generation should succeed for the placement-diagnostics probe. Error: %s" % medium_result.diagnostics)
	var medium_recipe: LevelRecipeDefinition = _repository().get_recipe(&"medium_combat_basic")
	assert_true(
		int(medium_result.diagnostics.get("enemy_count")) >= medium_recipe.enemy_budget_min and int(medium_result.diagnostics.get("enemy_count")) <= medium_recipe.enemy_budget_max,
		"Story 3.5: Medium enemy_count must fall within the recipe budget band [%d..%d]." % [medium_recipe.enemy_budget_min, medium_recipe.enemy_budget_max]
	)
	assert_true(int(medium_result.diagnostics.get("reward_count")) >= medium_recipe.reward_count_min, "Story 3.5: Medium reward_count must meet the recipe minimum.")
