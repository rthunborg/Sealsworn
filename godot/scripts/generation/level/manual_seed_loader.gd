class_name ManualSeedLoader
extends RefCounted

# Manual-seed level loader (Epic 3, Story 3.7) — the manual-seed reproduction capstone.
#
# A THIN, PURE-DOMAIN orchestration + seed-parse service over the COMPLETE generation pipeline
# (Stories 3.1-3.6). It has exactly two responsibilities:
#   (a) parse_seed(raw)  — PARSE + VALIDATE a raw seed input (a decimal String — the share/replay
#                          format — or a plain int) into a NORMALIZED non-negative root_seed, with a
#                          clear, stable lower-snake error on malformed/ambiguous input (AC2).
#   (b) load_level(...)  — BUILD a manual-seed-flagged GenerationRequest, run it through the existing
#                          LevelGenerator.generate(...), and report manual-seed META-INELIGIBILITY on
#                          the result (AC1).
#
# DATA-LAYER ONLY (NFR14): a RefCounted service, NOT a Node. NO scene/UI/audio/`user://`/autoload
# dependency. It draws NO RNG of its own and re-authors NO generation/validation/retry — LevelGenerator
# does all of that. It PERSISTS NOTHING; it returns a result. The optional player-facing seed-entry UI,
# the manual-seed RUN save, and the Epic 8 meta-progression gate are OUT OF SCOPE (this is the domain
# loader + the batch harness's dependency).
#
# AC1 DETERMINISM: the SAME (raw_seed, recipe) produces the SAME GenerationResult — the loader adds no
# randomness, so this is just the 3.6 pipeline determinism (RngStreamSet.new(request.level_seed()) per
# attempt; attempt 0 unperturbed) surfaced through the loader.
#
# AC1 MANUAL-SEED META-INELIGIBILITY: the load result EXPLICITLY carries is_manual_seed == true +
# meta_progression_eligible == false — the EXISTING RunSnapshot split vocabulary. It NEVER re-introduces
# the ambiguous manual_seed_eligible_for_progression key (deliberately dropped in the 2.7/2.8 save layer
# and test-pinned absent). The actual meta gate (refusing to award progression) is Epic 8; this story
# only REPORTS the status on the generated-level result.
#
# AC2 SEED-SIGN PROVENANCE (carried verbatim from the 3.1 code-review Decision): a legitimate full-64-bit
# shared/replay seed can decode NEGATIVE as a signed int64, and GenerationRequest.validate() REJECTS
# root_seed < 0. So parse_seed NORMALIZES a parsed seed to the non-negative range with NON_NEGATIVE_MASK
# (& 0x7fffffffffffffff — clears the sign bit, mapping any signed int64 into [0, 2^63-1]) BEFORE the
# request is built, so a negative-decoding seed LOADS instead of being silently rejected by the request
# validator. The mask is IDEMPOTENT for an already-non-negative seed. We normalize at the loader boundary
# and DO NOT relax GenerationRequest.validate()'s non-negative rule.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const GenerationRequest = preload("res://scripts/generation/level/generation_request.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const LevelGenerator = preload("res://scripts/generation/level/level_generator.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")
const LevelRecipeRepository = preload("res://scripts/content/repositories/level_recipe_repository.gd")
const EnemyRepository = preload("res://scripts/content/repositories/enemy_repository.gd")

# Manual-seed normalization mask (seed-sign provenance). Clears the int64 sign bit so any parsed seed
# normalizes into the non-negative range GenerationRequest.validate() accepts. Idempotent for a
# non-negative seed. Pinned by test_manual_seed_loader.gd so the exact normalization is a regression.
const NON_NEGATIVE_MASK: int = 0x7fffffffffffffff

# Manual-seed request defaults. The loader builds a VALID GenerationRequest: a normalized non-negative
# seed, lower-snake ids (the same node id the seed-regression tests use), the recipe's own size_class,
# the single standard difficulty band (NOT a difficulty knob — hard non-goal), and the none-affinity
# placeholder. The node id/type are documented manual-seed defaults; a future run-start flow may pass a
# real route node id when it wires the loader into a run.
const MANUAL_SEED_NODE_ID: StringName = &"node_1"
const MANUAL_SEED_NODE_TYPE: StringName = &"combat"


# AC2: parse + validate a raw seed into a normalized non-negative root_seed.
# Returns ActionResult.ok([], {"root_seed": <int>, "raw_type": <type-name>}) on success, or
# ActionResult.error(<lower-snake code>, {...compact reason...}) on failure. The caller (load_level) MUST
# NOT proceed to generate on an error result — that is AC2's "no generation starts from ambiguous input".
#
# Accepted: a plain int (any sign — normalized) and a decimal String/StringName (the share/replay format,
# honoring the int64-string lossless rule via is_valid_int + to_int). Rejected with a stable code:
#   empty_seed          - an empty or whitespace-only String.
#   non_integer_seed    - a String that is not a valid decimal integer (e.g. "abc", "12x", "1.5",
#                         embedded/leading/trailing whitespace, hex, scientific notation), a decimal
#                         string OUTSIDE the signed-int64 range (e.g. "99999999999999999999" or
#                         "9223372036854775808" — String.to_int() saturates/wraps these rather than
#                         round-tripping, so we reject them loudly instead of silently mapping to
#                         max int64), OR a float (ambiguous numeric form — a seed is an int or a
#                         decimal string, never a float).
#   unsupported_seed_type - any other type (bool, Array, Dictionary, null, object).
func parse_seed(raw: Variant) -> ActionResult:
	match typeof(raw):
		TYPE_INT:
			return _ok_seed(_normalize(int(raw)), "int")
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(raw)
			if text.strip_edges().is_empty():
				return ActionResult.error(&"empty_seed", {"reason": "blank_seed_input"})
			# Mirror RngStreamSet._int64_from_value's String discipline (is_valid_int + to_int). is_valid_int
			# is strict: it rejects embedded/leading/trailing whitespace, hex, decimals, and scientific
			# notation, so an ambiguous string never starts a generation.
			if not text.is_valid_int():
				return ActionResult.error(&"non_integer_seed", {"reason": "seed_not_a_decimal_integer", "raw_text": text})
			# is_valid_int() also returns true for a magnitude BEYOND the signed-int64 range (the digits are
			# all valid), where String.to_int() saturates to max int64 or wraps — so the parsed value does
			# NOT round-trip the input. Enforce the int64-string lossless rule: re-stringify to_int() and
			# compare to the (canonicalized) input; on mismatch the seed is out of range -> reject as
			# non_integer_seed rather than silently saturating to max int64.
			var parsed_value: int = text.to_int()
			if not _decimal_string_round_trips_losslessly(text, parsed_value):
				return ActionResult.error(&"non_integer_seed", {"reason": "seed_out_of_int64_range", "raw_text": text})
			return _ok_seed(_normalize(parsed_value), "string")
		TYPE_FLOAT:
			# A float seed is ambiguous (precision / non-integer form). The share format is a decimal
			# String or a plain int — never a float. Reject loudly rather than silently truncating.
			return ActionResult.error(&"non_integer_seed", {"reason": "seed_must_not_be_a_float"})
		_:
			return ActionResult.error(&"unsupported_seed_type", {"reason": "unsupported_seed_type", "type_id": typeof(raw)})


# AC1: parse the seed (returning the parse error verbatim if invalid — NO generation), build a
# manual-seed-flagged GenerationRequest for recipe_id with the normalized seed, run it through
# LevelGenerator.generate(...), and return a typed Dictionary result that ALWAYS reports manual-seed
# meta-ineligibility (is_manual_seed: true / meta_progression_eligible: false) alongside the outcome.
#
# Return shape (stable, machine-readable):
#   ok: bool                          - true only when the seed parsed AND generation succeeded.
#   is_manual_seed: bool              - ALWAYS true (this is the manual-seed loader).
#   meta_progression_eligible: bool   - ALWAYS false (AC1: manual-seed runs grant no meta progression).
#   parse_error: ActionResult | null  - the verbatim parse error when the seed was malformed; else null.
#   result: GenerationResult | null   - the generation result (success OR structured generation error)
#                                       when the seed parsed; null when generation was NOT attempted
#                                       (i.e. a parse error short-circuited it — AC2).
#   root_seed: int                    - the normalized non-negative seed (present when parsed).
#   recipe_id: String                 - the requested recipe id (for reporting).
func load_level(raw_seed: Variant, recipe_id: StringName, recipe_repository: LevelRecipeRepository, enemy_repository: EnemyRepository) -> Dictionary:
	# The manual-seed eligibility signal is reported on EVERY return (even a parse error / generation
	# failure) — a manual-seed load is never eligible for meta progression regardless of outcome.
	var base_result: Dictionary = {
		"is_manual_seed": true,
		"meta_progression_eligible": false,
		"recipe_id": String(recipe_id)
	}

	var parsed: ActionResult = parse_seed(raw_seed)
	if parsed.is_error():
		# AC2: short-circuit — NO generation starts from ambiguous seed input.
		var error_dict: Dictionary = base_result.duplicate(true)
		error_dict["ok"] = false
		error_dict["parse_error"] = parsed
		error_dict["result"] = null
		return error_dict

	var root_seed: int = int(parsed.metadata.get("root_seed"))

	# Resolve the recipe to read its size_class for the request. A missing recipe is NOT a parse error —
	# we still build the request (with the recipe's size class when resolvable) and let
	# LevelGenerator.generate surface the structured unknown_level_recipe error, so the failure shape is
	# the pipeline's, not a second ad-hoc one.
	var size_class: StringName = _size_class_for_recipe(recipe_repository, recipe_id)

	var request: GenerationRequest = GenerationRequest.new(
		root_seed,
		MANUAL_SEED_NODE_ID,
		MANUAL_SEED_NODE_TYPE,
		recipe_id,
		size_class,
		GenerationRequest.DIFFICULTY_STANDARD,
		GenerationRequest.AFFINITY_NONE,
		{}
	)

	var generation: GenerationResult = LevelGenerator.generate(request, recipe_repository, enemy_repository)

	var loaded: Dictionary = base_result.duplicate(true)
	loaded["ok"] = generation.succeeded
	loaded["parse_error"] = null
	loaded["result"] = generation
	loaded["root_seed"] = root_seed
	return loaded


# Resolve the recipe's declared size class for the request. Falls back to SIZE_SMALL when the recipe is
# unknown/unresolvable — the request is still well-formed (a valid size class) so generate's recipe-phase
# resolution produces the structured unknown_level_recipe error rather than a size-class validation error.
func _size_class_for_recipe(recipe_repository: LevelRecipeRepository, recipe_id: StringName) -> StringName:
	if recipe_repository == null:
		return GenerationRequest.SIZE_SMALL
	var recipe: LevelRecipeDefinition = recipe_repository.get_recipe(recipe_id)
	if recipe == null:
		return GenerationRequest.SIZE_SMALL
	return recipe.size_class


func _normalize(seed_value: int) -> int:
	# Seed-sign provenance: map any signed int64 into the non-negative range GenerationRequest.validate()
	# accepts. Idempotent for an already-non-negative seed.
	return seed_value & NON_NEGATIVE_MASK


# Int64-string lossless check: did String.to_int() (-> parsed_value) preserve the full magnitude of the
# is_valid_int-accepted decimal string `text`? to_int() saturates an over-max-int64 string to max int64
# and WRAPS a max-int64+1 string into the negative range, so an out-of-range seed would otherwise silently
# map to a wrong value. We compare a canonicalized form of the input to str(parsed_value): a mismatch means
# the value did not round-trip (out of int64 range) and must be rejected. The canonicalization tolerates
# the BENIGN representational differences is_valid_int() accepts (a leading "+", surplus leading zeros, and
# a signed zero like "-0"/"+0") so those still parse — only a genuine magnitude/sign loss fails.
func _decimal_string_round_trips_losslessly(text: String, parsed_value: int) -> bool:
	return _canonical_decimal_string(text) == str(parsed_value)


# Canonicalize an is_valid_int-accepted decimal string to the same form str(int) produces: drop a single
# leading "+"/"-" sign, strip surplus leading zeros (keep one digit), and treat "-0"/"+0"/"0" as "0".
func _canonical_decimal_string(text: String) -> String:
	var sign_prefix: String = ""
	var body: String = text
	if body.begins_with("+"):
		body = body.substr(1)
	elif body.begins_with("-"):
		sign_prefix = "-"
		body = body.substr(1)
	while body.length() > 1 and body.begins_with("0"):
		body = body.substr(1)
	if body == "0":
		# A signed zero ("-0"/"+0") and "0" all canonicalize to the unsigned "0" str(0) produces.
		sign_prefix = ""
	return sign_prefix + body


func _ok_seed(root_seed: int, raw_type: String) -> ActionResult:
	return ActionResult.ok([], {"root_seed": root_seed, "raw_type": raw_type})
