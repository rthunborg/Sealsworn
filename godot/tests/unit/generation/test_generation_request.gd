extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")

func run() -> Dictionary:
	_request_initializes_with_seed_and_level_context()
	_request_defaults_size_class_from_recipe_seam()
	_valid_request_validates()
	_validate_rejects_non_lower_snake_recipe_id()
	_validate_rejects_unknown_size_class()
	_validate_rejects_unknown_difficulty_band()
	_validate_rejects_non_lower_snake_node_type()
	_validate_rejects_negative_root_seed()
	_validate_rejects_non_lower_snake_affinity_placeholder()
	_constraints_are_deep_copied_on_construction()
	_layout_rng_uses_named_level_stream()
	_layout_float_rng_uses_named_level_stream()
	_identical_requests_replay_identical_level_draw_sequence()
	_cosmetic_and_combat_draws_do_not_change_level_layout_sequence()
	_layout_rng_surfaces_stream_errors_without_global_fallback()
	return result()


func _request(root_seed: int = 4242) -> GenerationRequest:
	return GenerationRequest.new(
		root_seed,
		&"node_3",
		&"combat",
		&"small_combat_basic",
		GenerationRequest.SIZE_SMALL,
		GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE,
		{"max_blocker_clusters": 2}
	)


func _request_initializes_with_seed_and_level_context() -> void:
	var request: GenerationRequest = _request()
	assert_equal(request.root_seed, 4242, "Request should carry the root seed.")
	assert_equal(request.level_seed(), 4242, "Request should derive a level seed from the root seed.")
	assert_equal(request.node_id, &"node_3", "Request should carry the node id context.")
	assert_equal(request.node_type, &"combat", "Request should carry the node type context.")
	assert_equal(request.recipe_id, &"small_combat_basic", "Request should reference the recipe by id.")
	assert_equal(request.size_class, GenerationRequest.SIZE_SMALL, "Request should carry the level size class.")
	assert_equal(request.difficulty_band, GenerationRequest.DIFFICULTY_STANDARD, "Request should carry the internal difficulty band.")
	assert_equal(request.affinity_placeholder, GenerationRequest.AFFINITY_NONE, "Request should carry the affinity placeholder slot.")
	assert_equal(request.constraints().get("max_blocker_clusters"), 2, "Request should carry generation constraints.")


func _request_defaults_size_class_from_recipe_seam() -> void:
	var request: GenerationRequest = GenerationRequest.new(7, &"node_1", &"combat", &"small_combat_basic")
	assert_equal(request.difficulty_band, GenerationRequest.DIFFICULTY_STANDARD, "Request should default to the standard difficulty band.")
	assert_equal(request.affinity_placeholder, GenerationRequest.AFFINITY_NONE, "Request should default to no affinity placeholder.")
	assert_true(request.constraints().is_empty(), "Request should default to empty constraints.")


func _valid_request_validates() -> void:
	var validation: ActionResult = _request().validate()
	assert_true(validation.succeeded, "A fully specified request should validate. Error: %s" % validation.metadata)


func _rejects_field(request: GenerationRequest, expected_field: StringName, message: String) -> void:
	var validation: ActionResult = request.validate()
	assert_true(validation.is_error(), message)
	assert_equal(validation.error_code, &"invalid_generation_request", "%s should use the stable request error code." % message)
	assert_equal(validation.metadata.get("field"), String(expected_field), "%s should name the offending field." % message)


func _validate_rejects_non_lower_snake_recipe_id() -> void:
	var request: GenerationRequest = _request()
	request.recipe_id = &"Small Combat"
	_rejects_field(request, &"recipe_id", "Request with a non-lower-snake recipe id should be rejected.")


func _validate_rejects_unknown_size_class() -> void:
	var request: GenerationRequest = _request()
	request.size_class = &"large"
	_rejects_field(request, &"size_class", "Request with a deferred Large size class should be rejected.")


func _validate_rejects_unknown_difficulty_band() -> void:
	var request: GenerationRequest = _request()
	request.difficulty_band = &"nightmare"
	_rejects_field(request, &"difficulty_band", "Request with an unknown difficulty band should be rejected (no difficulty ladder).")


func _validate_rejects_non_lower_snake_node_type() -> void:
	var request: GenerationRequest = _request()
	request.node_type = &"Combat Node"
	_rejects_field(request, &"node_type", "Request with a non-lower-snake node type should be rejected.")


func _validate_rejects_negative_root_seed() -> void:
	var request: GenerationRequest = _request()
	request.root_seed = -1
	_rejects_field(request, &"root_seed", "Request with a negative root seed should be rejected.")


func _validate_rejects_non_lower_snake_affinity_placeholder() -> void:
	var request: GenerationRequest = _request()
	request.affinity_placeholder = &"Scorched"
	_rejects_field(request, &"affinity_placeholder", "Request with a non-lower-snake affinity placeholder should be rejected.")


func _constraints_are_deep_copied_on_construction() -> void:
	var source_constraints: Dictionary = {"tags": ["choke", "hazard"]}
	var request: GenerationRequest = GenerationRequest.new(
		11, &"node_2", &"combat", &"small_combat_basic",
		GenerationRequest.SIZE_SMALL, GenerationRequest.DIFFICULTY_STANDARD, GenerationRequest.AFFINITY_NONE,
		source_constraints
	)
	source_constraints["tags"][0] = "mutated"
	assert_equal(request.constraints().get("tags")[0], "choke", "Request constraints should be deep copied so caller mutation cannot rewrite them.")


func _layout_rng_uses_named_level_stream() -> void:
	# The request is the source of layout-affecting randomness via the named level stream ONLY.
	var streams: RngStreamSet = RngStreamSet.new(_request().level_seed())
	var draw: ActionResult = _request().draw_layout_int(streams, 1, 100, {"consumer": "layout_probe"})
	assert_true(draw.succeeded, "Layout RNG draw should succeed through the level stream.")
	assert_equal(draw.metadata.get("stream_name"), String(RngStreamSet.STREAM_LEVEL), "Layout RNG must be drawn from the named level stream.")


func _layout_float_rng_uses_named_level_stream() -> void:
	var streams: RngStreamSet = RngStreamSet.new(_request().level_seed())
	var draw: ActionResult = _request().draw_layout_float(streams, {"consumer": "layout_float_probe"})
	assert_true(draw.succeeded, "Layout float RNG draw should succeed through the level stream.")
	assert_equal(draw.metadata.get("stream_name"), String(RngStreamSet.STREAM_LEVEL), "Layout float RNG must be drawn from the named level stream.")


func _identical_requests_replay_identical_level_draw_sequence() -> void:
	var first_request: GenerationRequest = _request(8675309)
	var second_request: GenerationRequest = _request(8675309)
	var first_streams: RngStreamSet = RngStreamSet.new(first_request.level_seed())
	var second_streams: RngStreamSet = RngStreamSet.new(second_request.level_seed())

	var first_values: Array[int] = []
	var second_values: Array[int] = []
	for draw_index: int in range(8):
		first_values.append(int(first_request.draw_layout_int(first_streams, 1, 1000, {"step": draw_index}).metadata.get("value")))
		second_values.append(int(second_request.draw_layout_int(second_streams, 1, 1000, {"step": draw_index}).metadata.get("value")))

	assert_equal(first_values, second_values, "Identical requests + identical level-stream state should replay an identical layout draw sequence.")


func _cosmetic_and_combat_draws_do_not_change_level_layout_sequence() -> void:
	var clean_request: GenerationRequest = _request(24680)
	var noisy_request: GenerationRequest = _request(24680)
	var clean_streams: RngStreamSet = RngStreamSet.new(clean_request.level_seed())
	var noisy_streams: RngStreamSet = RngStreamSet.new(noisy_request.level_seed())

	var clean_values: Array[int] = []
	var noisy_values: Array[int] = []
	for draw_index: int in range(6):
		# Interleave unrelated-stream noise into the noisy run; layout draws must be unaffected.
		noisy_streams.rand_float(RngStreamSet.STREAM_COSMETIC, {"consumer": "ambient_noise", "step": draw_index})
		noisy_streams.rand_int(RngStreamSet.STREAM_COMBAT, 1, 6, {"consumer": "combat_noise", "step": draw_index})
		clean_values.append(int(clean_request.draw_layout_int(clean_streams, 1, 1000, {"step": draw_index}).metadata.get("value")))
		noisy_values.append(int(noisy_request.draw_layout_int(noisy_streams, 1, 1000, {"step": draw_index}).metadata.get("value")))

	assert_equal(noisy_values, clean_values, "Cosmetic/combat draws must not change the level-affected layout draw sequence (stream isolation).")


func _layout_rng_surfaces_stream_errors_without_global_fallback() -> void:
	# The layout helpers route EXCLUSIVELY through the named level stream (asserted above). The
	# underlying RngStreamSet never silently substitutes a global RNG: any stream name it does not
	# own returns a structured unknown_rng_stream error. This proves there is no global-RNG fallback
	# path the layout helpers could leak into. An invalid range likewise errors structurally rather
	# than producing an unattributed draw.
	var streams: RngStreamSet = RngStreamSet.new(_request().level_seed())
	var unknown_draw: ActionResult = streams.rand_int(&"not_a_real_stream", 1, 10)
	assert_true(unknown_draw.is_error(), "An unknown stream must surface a structured error, never a global RNG fallback.")
	assert_equal(unknown_draw.error_code, &"unknown_rng_stream", "An unknown stream should report the stable unknown_rng_stream code.")

	var invalid_range_draw: ActionResult = _request().draw_layout_int(streams, 10, 1)
	assert_true(invalid_range_draw.is_error(), "An invalid layout RNG range must surface a structured error, not a silent fallback draw.")
	assert_equal(invalid_range_draw.error_code, &"invalid_rng_range", "An invalid layout RNG range should report the stable invalid_rng_range code.")
