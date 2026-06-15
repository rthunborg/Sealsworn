class_name GenerationRequest
extends RefCounted

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const LevelRecipeDefinition = preload("res://scripts/content/definitions/level_recipe_definition.gd")

# Size classes mirror LevelRecipeDefinition (v0: Small + Medium only).
const SIZE_SMALL := LevelRecipeDefinition.SIZE_SMALL
const SIZE_MEDIUM := LevelRecipeDefinition.SIZE_MEDIUM

# Internal difficulty band. NOT a player-selectable difficulty tier (hard non-goal).
# v0 carries a single "standard" band describing intended pressure for a node/depth.
const DIFFICULTY_STANDARD := &"standard"

# Affinity placeholder slot. Real affinities (Scorched/Flooded/Cursed/Darkness) are Epic 7.
const AFFINITY_NONE := &"none"

var root_seed: int = 0
var node_id: StringName = &""
var node_type: StringName = &""
var recipe_id: StringName = &""
var size_class: StringName = &""
var difficulty_band: StringName = DIFFICULTY_STANDARD
var affinity_placeholder: StringName = AFFINITY_NONE
var _constraints: Dictionary = {}

func _init(
	new_root_seed: int = 0,
	new_node_id: StringName = &"",
	new_node_type: StringName = &"",
	new_recipe_id: StringName = &"",
	new_size_class: StringName = SIZE_SMALL,
	new_difficulty_band: StringName = DIFFICULTY_STANDARD,
	new_affinity_placeholder: StringName = AFFINITY_NONE,
	new_constraints: Dictionary = {}
) -> void:
	root_seed = new_root_seed
	node_id = new_node_id
	node_type = new_node_type
	recipe_id = new_recipe_id
	size_class = new_size_class
	difficulty_band = new_difficulty_band
	affinity_placeholder = new_affinity_placeholder
	_constraints = new_constraints.duplicate(true)


# Layout RNG is derived from the root seed. The full 64-bit seed is preserved; v0 uses the root
# seed directly as the level seed. If this is ever persisted, string-encode it per the int64/JSON
# rule (see RngStreamSet.to_snapshot) — small bounded ints (budgets, draw indexes) stay numeric.
func level_seed() -> int:
	return root_seed


func constraints() -> Dictionary:
	return _constraints.duplicate(true)


func validate() -> ActionResult:
	if root_seed < 0:
		return _invalid(&"root_seed")
	if not _is_lower_snake_id(node_id):
		return _invalid(&"node_id")
	if not _is_lower_snake_id(node_type):
		return _invalid(&"node_type")
	if not _is_lower_snake_id(recipe_id):
		return _invalid(&"recipe_id")
	if not _is_valid_size_class(size_class):
		return _invalid(&"size_class")
	if not _is_valid_difficulty_band(difficulty_band):
		return _invalid(&"difficulty_band")
	if not _is_lower_snake_id(affinity_placeholder):
		return _invalid(&"affinity_placeholder")
	return ActionResult.ok()


# CRITICAL (AC1): layout-affecting randomness is drawn from the named `level` stream ONLY,
# never global randi()/randf() and never another stream. The generator must route every
# layout-affecting draw through these helpers so the contract is enforced in one place.
func draw_layout_int(streams: RngStreamSet, minimum: int, maximum: int, consumer_context: Dictionary = {}) -> ActionResult:
	return streams.rand_int(RngStreamSet.STREAM_LEVEL, minimum, maximum, _layout_context(consumer_context))


func draw_layout_float(streams: RngStreamSet, consumer_context: Dictionary = {}) -> ActionResult:
	return streams.rand_float(RngStreamSet.STREAM_LEVEL, _layout_context(consumer_context))


func _layout_context(consumer_context: Dictionary) -> Dictionary:
	var context: Dictionary = consumer_context.duplicate(true)
	context["system"] = "generation"
	context["node_id"] = String(node_id)
	context["recipe_id"] = String(recipe_id)
	return context


static func _is_valid_size_class(value: StringName) -> bool:
	return value == SIZE_SMALL or value == SIZE_MEDIUM


static func _is_valid_difficulty_band(value: StringName) -> bool:
	return value == DIFFICULTY_STANDARD


static func _is_lower_snake_id(value: StringName) -> bool:
	var text: String = String(value)
	if text.is_empty():
		return false
	if text != text.to_lower():
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore: bool = code == 95
		if not is_lower and not is_digit and not is_underscore:
			return false
	return true


static func _invalid(field_name: StringName) -> ActionResult:
	return ActionResult.error(&"invalid_generation_request", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
