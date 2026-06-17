extends "res://tests/unit/test_case.gd"

# Story 3.7 — Manual-seed loader (AC1 + AC2).
#
# ManualSeedLoader is a THIN pure-domain orchestration + seed-parse layer over the complete
# LevelGenerator.generate(...) pipeline (Stories 3.1-3.6). It draws NO RNG of its own and re-authors
# no generation/validation/retry. This test covers:
#
#   AC1 — "the same seed and recipe produce the same generated level, and the generated level reports
#          that the run is manual-seed ineligible for meta progression."
#     * load_level(seed, recipe) twice -> byte-identical GenerationResult (terrain fingerprint derived
#       from the payload board + diagnostics.attempts + diagnostics.validated), proving the loader adds
#       no randomness (just the 3.6 pipeline determinism surfaced through the loader).
#     * the load result EXPLICITLY carries is_manual_seed == true + meta_progression_eligible == false
#       (the EXISTING RunSnapshot split vocabulary; NEVER the dropped manual_seed_eligible_for_progression
#       key).
#
#   AC2 — "Given a seed is invalid or malformed, when the loader parses it, then it returns a clear
#          validation error, and no generation starts from ambiguous seed input."
#     * parse_seed rejects empty/blank, non-integer text ("abc", "12x", "1.5", embedded whitespace), and
#       unsupported types with a STABLE lower-snake code; mirrors RngStreamSet._int64_from_value's
#       String/int discipline (is_valid_int + to_int).
#     * load_level SHORT-CIRCUITS on a parse error: it returns the parse error verbatim and NEVER calls
#       generate (no GenerationResult, no payload).
#     * SEED-SIGN PROVENANCE (carried from the 3.1 review Decision): a legitimate full-64-bit shared seed
#       can decode NEGATIVE as a signed int64; GenerationRequest.validate() rejects root_seed < 0. The
#       loader NORMALIZES a parsed seed to the non-negative range (& 0x7fffffffffffffff) BEFORE building
#       the request, so a negative-decoding seed NORMALIZES-AND-LOADS instead of being silently rejected.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")
const SmallLevelLayoutGenerator = preload("res://scripts/generation/level/small_level_layout_generator.gd")
const ManualSeedLoader = preload("res://scripts/generation/level/manual_seed_loader.gd")

# Non-negative mask the loader applies for seed-sign-provenance normalization (mirrored here so the
# test pins the EXACT documented normalization, not just "some non-negative result").
const NON_NEGATIVE_MASK: int = 0x7fffffffffffffff

func run() -> Dictionary:
	_parse_accepts_decimal_string_and_int()
	_parse_rejects_malformed_and_ambiguous_input()
	_parse_normalizes_negative_decoding_seed_to_non_negative()
	_load_short_circuits_on_parse_error_without_generating()
	_load_reports_manual_seed_meta_ineligibility()
	_load_is_deterministic_for_same_seed_and_recipe()
	_load_negative_decoding_seed_normalizes_and_loads()
	_load_surfaces_generation_error_for_unknown_recipe()
	return result()


func _loader() -> ManualSeedLoader:
	return ManualSeedLoader.new()


func _recipes() -> LevelRecipeRepository:
	return LevelRecipeRepository.create_baseline_repository()


func _enemies() -> EnemyRepository:
	return EnemyRepository.create_baseline_repository()


# AC2: a String decimal seed (the share/replay format) and a plain int both parse to a non-negative
# root_seed. The String must round-trip losslessly per the int64-string rule.
func _parse_accepts_decimal_string_and_int() -> void:
	var loader: ManualSeedLoader = _loader()

	var from_int: ActionResult = loader.parse_seed(1001)
	assert_true(from_int.succeeded, "parse_seed(1001) should succeed.")
	assert_equal(int(from_int.metadata.get("root_seed")), 1001, "parse_seed(1001) should yield root_seed 1001.")

	var from_string: ActionResult = loader.parse_seed("2002")
	assert_true(from_string.succeeded, "parse_seed(\"2002\") should succeed.")
	assert_equal(int(from_string.metadata.get("root_seed")), 2002, "parse_seed(\"2002\") should yield root_seed 2002.")

	# Full-64-bit positive decimal string must round-trip losslessly (int64-string rule).
	var big_text: String = "9223372036854775807" # max int64
	var from_big: ActionResult = loader.parse_seed(big_text)
	assert_true(from_big.succeeded, "parse_seed(max-int64 string) should succeed.")
	assert_equal(int(from_big.metadata.get("root_seed")), 9223372036854775807, "parse_seed(max-int64 string) should round-trip losslessly.")


# AC2: malformed/ambiguous input is rejected with a STABLE lower-snake code and NO generation can
# proceed (the caller must not reach generate on an error result).
func _parse_rejects_malformed_and_ambiguous_input() -> void:
	var loader: ManualSeedLoader = _loader()

	var empty: ActionResult = loader.parse_seed("")
	assert_true(empty.is_error(), "parse_seed(\"\") should be an error.")
	assert_equal(empty.error_code, &"empty_seed", "Empty seed should report empty_seed.")

	var blank: ActionResult = loader.parse_seed("   ")
	assert_true(blank.is_error(), "parse_seed(blank) should be an error.")
	assert_equal(blank.error_code, &"empty_seed", "Blank/whitespace-only seed should report empty_seed.")

	for bad_text: String in ["abc", "12x", "1.5", "12 34", " 12", "12 ", "0x1F", "1e3", "--5", "+"]:
		var bad: ActionResult = loader.parse_seed(bad_text)
		assert_true(bad.is_error(), "parse_seed(%s) should be an error (non-integer/ambiguous)." % bad_text)
		assert_equal(bad.error_code, &"non_integer_seed", "Non-integer seed %s should report non_integer_seed." % bad_text)

	# Unsupported types (float, bool, array, dictionary, null) are ambiguous and rejected.
	var as_float: ActionResult = loader.parse_seed(1.5)
	assert_true(as_float.is_error(), "parse_seed(1.5 float) should be an error.")
	assert_equal(as_float.error_code, &"non_integer_seed", "Non-integral float seed should report non_integer_seed.")

	var as_bool: ActionResult = loader.parse_seed(true)
	assert_true(as_bool.is_error(), "parse_seed(true) should be an error.")
	assert_equal(as_bool.error_code, &"unsupported_seed_type", "A bool seed should report unsupported_seed_type.")

	var as_array: ActionResult = loader.parse_seed([1, 2])
	assert_true(as_array.is_error(), "parse_seed(array) should be an error.")
	assert_equal(as_array.error_code, &"unsupported_seed_type", "An array seed should report unsupported_seed_type.")

	var as_dict: ActionResult = loader.parse_seed({"seed": 1})
	assert_true(as_dict.is_error(), "parse_seed(dict) should be an error.")
	assert_equal(as_dict.error_code, &"unsupported_seed_type", "A dictionary seed should report unsupported_seed_type.")

	var as_nil: ActionResult = loader.parse_seed(null)
	assert_true(as_nil.is_error(), "parse_seed(null) should be an error.")
	assert_equal(as_nil.error_code, &"unsupported_seed_type", "A null seed should report unsupported_seed_type.")


# AC2 seed-sign provenance: a negative-decoding seed (int or string) parses to a NON-NEGATIVE root_seed
# via the documented & 0x7fffffffffffffff mask. A non-negative seed is unchanged (idempotent mask).
func _parse_normalizes_negative_decoding_seed_to_non_negative() -> void:
	var loader: ManualSeedLoader = _loader()

	var negative_value: int = -4523566890123456789
	var expected_normalized: int = negative_value & NON_NEGATIVE_MASK

	var from_negative_int: ActionResult = loader.parse_seed(negative_value)
	assert_true(from_negative_int.succeeded, "parse_seed(negative int) should succeed after normalization.")
	var normalized_int: int = int(from_negative_int.metadata.get("root_seed"))
	assert_true(normalized_int >= 0, "Normalized seed must be non-negative.")
	assert_equal(normalized_int, expected_normalized, "Negative int seed should normalize via & 0x7fffffffffffffff.")

	var from_negative_string: ActionResult = loader.parse_seed(str(negative_value))
	assert_true(from_negative_string.succeeded, "parse_seed(negative string) should succeed after normalization.")
	assert_equal(int(from_negative_string.metadata.get("root_seed")), expected_normalized, "Negative string seed should normalize identically to the int form.")

	# Idempotence: a non-negative seed is unchanged by the mask.
	var already_non_negative: ActionResult = loader.parse_seed(1001)
	assert_equal(int(already_non_negative.metadata.get("root_seed")), 1001 & NON_NEGATIVE_MASK, "Non-negative seed must be unchanged by the normalization mask.")
	assert_equal(int(already_non_negative.metadata.get("root_seed")), 1001, "1001 must normalize to itself.")


# AC2: load_level must short-circuit on a parse error and NOT call generate.
func _load_short_circuits_on_parse_error_without_generating() -> void:
	var loader: ManualSeedLoader = _loader()
	var loaded: Dictionary = loader.load_level("abc", &"small_combat_basic", _recipes(), _enemies())

	assert_false(bool(loaded.get("ok", true)), "load_level on a malformed seed must not be ok.")
	assert_true(loaded.get("result") == null, "load_level on a parse error must NOT produce a GenerationResult (no generation started).")
	var parse_error: ActionResult = loaded.get("parse_error") as ActionResult
	assert_true(parse_error != null, "load_level must surface the parse_error verbatim.")
	assert_true(parse_error.is_error(), "The surfaced parse_error must be an error.")
	assert_equal(parse_error.error_code, &"non_integer_seed", "The parse error code must be carried through load_level.")
	# Manual-seed status is still reported even when parse fails (the run, had it loaded, would be manual-seed).
	assert_true(bool(loaded.get("is_manual_seed", false)), "A manual-seed load is always flagged is_manual_seed.")
	assert_false(bool(loaded.get("meta_progression_eligible", true)), "A manual-seed load is never meta-progression eligible.")


# AC1: the load result reports manual-seed meta-ineligibility with the EXISTING split vocabulary, and
# the underlying generation succeeds for an approved seed.
func _load_reports_manual_seed_meta_ineligibility() -> void:
	var loader: ManualSeedLoader = _loader()
	var loaded: Dictionary = loader.load_level(1001, &"small_combat_basic", _recipes(), _enemies())

	assert_true(bool(loaded.get("ok", false)), "load_level(1001, small) should be ok.")
	assert_true(bool(loaded.get("is_manual_seed", false)), "AC1: a loaded manual-seed level reports is_manual_seed == true.")
	assert_false(bool(loaded.get("meta_progression_eligible", true)), "AC1: a loaded manual-seed level reports meta_progression_eligible == false.")
	# The deliberately-dropped ambiguous key must NOT be re-introduced.
	assert_false(loaded.has("manual_seed_eligible_for_progression"), "The dropped ambiguous manual_seed_eligible_for_progression key must NOT reappear.")

	var generation: GenerationResult = loaded.get("result") as GenerationResult
	assert_true(generation != null, "A successful load must carry a GenerationResult.")
	assert_true(generation.succeeded, "The underlying generation for approved seed 1001 should succeed.")
	assert_true(generation.has_payload(), "A successful generation must carry a payload.")
	assert_true(bool(generation.diagnostics.get("validated", false)), "The generated level should be validated.")
	assert_equal(int(generation.diagnostics.get("attempts", -1)), 1, "Approved seed 1001 should pass on attempt 0 (attempts == 1).")


# AC1 determinism: the SAME (seed, recipe) -> byte-identical GenerationResult. Asserted via the terrain
# fingerprint derived from the payload board PLUS attempts/validated (not raw object identity).
func _load_is_deterministic_for_same_seed_and_recipe() -> void:
	var loader: ManualSeedLoader = _loader()
	var first: Dictionary = loader.load_level(2002, &"medium_combat_basic", _recipes(), _enemies())
	var second: Dictionary = loader.load_level(2002, &"medium_combat_basic", _recipes(), _enemies())

	var first_result: GenerationResult = first.get("result") as GenerationResult
	var second_result: GenerationResult = second.get("result") as GenerationResult
	assert_true(first_result != null and second_result != null, "Both loads of seed 2002 should produce a result.")
	assert_true(first_result.succeeded and second_result.succeeded, "Both loads of seed 2002 should succeed.")

	var first_fp: String = _terrain_fingerprint_from_payload(first_result.payload)
	var second_fp: String = _terrain_fingerprint_from_payload(second_result.payload)
	assert_equal(first_fp, second_fp, "Same (seed, recipe) must produce a byte-identical terrain fingerprint.")
	assert_equal(int(first_result.diagnostics.get("attempts", -1)), int(second_result.diagnostics.get("attempts", -2)), "Same seed must produce the same attempt count.")
	assert_equal(bool(first_result.diagnostics.get("validated", false)), bool(second_result.diagnostics.get("validated", true)), "Same seed must produce the same validated flag.")
	# The success-path seed transport is payload.level_seed (GenerationResult.seed is populated only on
	# the ERROR path — the existing contract). Assert it is the stable, normalized seed string.
	assert_equal(String(first_result.payload.get("level_seed", "")), "2002", "The payload.level_seed string should equal the normalized seed.")
	assert_equal(String(first_result.payload.get("level_seed", "")), String(second_result.payload.get("level_seed", "")), "The payload seed string must be stable across loads.")


# AC2 seed-sign provenance, end-to-end: a negative-decoding seed normalizes AND loads (it must NOT be
# rejected by GenerationRequest.validate()'s non-negative rule).
func _load_negative_decoding_seed_normalizes_and_loads() -> void:
	var loader: ManualSeedLoader = _loader()
	var negative_value: int = -4523566890123456789
	var loaded: Dictionary = loader.load_level(negative_value, &"small_combat_basic", _recipes(), _enemies())

	assert_true(bool(loaded.get("ok", false)), "A negative-decoding seed must normalize-and-load (not be rejected).")
	var generation: GenerationResult = loaded.get("result") as GenerationResult
	assert_true(generation != null and generation.succeeded, "The normalized negative seed must generate a valid level.")
	# The success-path seed transport (payload.level_seed) is the NORMALIZED (non-negative) seed, never
	# the raw negative value, AND the loader reports the normalized root_seed.
	var expected_seed: int = negative_value & NON_NEGATIVE_MASK
	assert_equal(String(generation.payload.get("level_seed", "")), str(expected_seed), "The generated payload seed must be the normalized non-negative seed.")
	assert_equal(int(loaded.get("root_seed", -1)), expected_seed, "load_level must report the normalized non-negative root_seed.")

	# Determinism still holds for the normalized seed: loading the negative form and the equivalent
	# normalized form produce the SAME terrain.
	var loaded_normalized: Dictionary = loader.load_level(expected_seed, &"small_combat_basic", _recipes(), _enemies())
	var negative_result: GenerationResult = loaded.get("result") as GenerationResult
	var normalized_result: GenerationResult = loaded_normalized.get("result") as GenerationResult
	assert_equal(
		_terrain_fingerprint_from_payload(negative_result.payload),
		_terrain_fingerprint_from_payload(normalized_result.payload),
		"A negative seed and its normalized form must produce the identical terrain."
	)


# A parse-valid seed with an unknown recipe must surface the generation error (no crash, no manual-seed
# silent-success): the loader runs generate and the pipeline returns a structured recipe error.
func _load_surfaces_generation_error_for_unknown_recipe() -> void:
	var loader: ManualSeedLoader = _loader()
	var loaded: Dictionary = loader.load_level(1001, &"no_such_recipe", _recipes(), _enemies())

	assert_false(bool(loaded.get("ok", true)), "An unknown recipe must not produce an ok load.")
	assert_true(loaded.get("parse_error") == null, "An unknown recipe is NOT a parse error (the seed parsed fine).")
	var generation: GenerationResult = loaded.get("result") as GenerationResult
	assert_true(generation != null, "An unknown recipe must still surface a GenerationResult error (generation was attempted).")
	assert_true(generation.is_error(), "The generation result for an unknown recipe must be an error.")
	assert_equal(generation.error_code, &"unknown_level_recipe", "An unknown recipe should fail with unknown_level_recipe.")
	# Manual-seed status is still reported on a generation failure.
	assert_true(bool(loaded.get("is_manual_seed", false)), "A manual-seed load reports is_manual_seed even on a generation error.")
	assert_false(bool(loaded.get("meta_progression_eligible", true)), "A manual-seed load reports meta-ineligibility even on a generation error.")


# Rebuild the layout-shaped dict (width/height/terrain/entrance/exit) from a GenerationResult.payload's
# board snapshot + entrance/exit, and compute the TERRAIN fingerprint via the EXISTING static (no second
# format). The board snapshot cells carry per-cell terrain; enemies are board ENTITIES on FLOOR cells, so
# the terrain grid equals the layout terrain the seed-regression tests pin.
func _terrain_fingerprint_from_payload(payload: Dictionary) -> String:
	var layout: Dictionary = _layout_from_payload(payload)
	return SmallLevelLayoutGenerator.fingerprint(layout)


func _layout_from_payload(payload: Dictionary) -> Dictionary:
	var board: Dictionary = payload.get("board", {})
	var width: int = int(board.get("width", 0))
	var height: int = int(board.get("height", 0))
	var cells: Array = board.get("cells", [])

	var terrain_grid: Array = []
	for _y: int in range(height):
		var row: Array = []
		row.resize(width)
		terrain_grid.append(row)
	for cell_value: Variant in cells:
		var cell: Dictionary = cell_value
		var position: Dictionary = cell.get("position", {})
		var x: int = int(position.get("x", -1))
		var y: int = int(position.get("y", -1))
		(terrain_grid[y] as Array)[x] = int(cell.get("terrain", 0))

	return {
		"width": width,
		"height": height,
		"entrance": payload.get("entrance", {}),
		"exit": payload.get("exit", {}),
		"terrain": terrain_grid
	}
