class_name LevelRecipeDefinition
extends Resource

const ActionResult = preload("res://scripts/core/results/action_result.gd")

const DEFINITION_TYPE := &"level_recipe"

# Size classes. v0 supports ONLY Small and Medium; Large/Huge are deferred per FR39.
const SIZE_SMALL := &"small"
const SIZE_MEDIUM := &"medium"

# Tactical wrinkle kinds (GDD allowlist). A combat recipe must permit/require at least one.
const WRINKLE_HAZARD := &"hazard"
const WRINKLE_DOOR := &"door"
const WRINKLE_CHOKE_POINT := &"choke_point"
const WRINKLE_FLANK_ROUTE := &"flank_route"
const WRINKLE_BLOCKER_CLUSTER := &"blocker_cluster"
const WRINKLE_AFFINITY_PLACEHOLDER := &"affinity_placeholder"
const WRINKLE_ENEMY_FORMATION := &"enemy_formation"
const WRINKLE_REWARD_BEHIND_DANGER := &"reward_behind_danger"
const WRINKLE_RISKY_SIDE_BRANCH := &"risky_side_branch"

@export var recipe_id: StringName = &""
@export var size_class: StringName = &""
# Terrain rules (data only): floor/wall composition + whether blockers may be placed.
@export var allow_blockers: bool = true
@export var wall_density: float = 0.0
# Blocker budget (inclusive integer band).
@export var blocker_budget_min: int = 0
@export var blocker_budget_max: int = 0
# Enemy budget (inclusive integer band).
@export var enemy_budget_min: int = 0
@export var enemy_budget_max: int = 0
# Reward placement rules (data only): intended reward-count band + behind-danger permission.
@export var reward_count_min: int = 0
@export var reward_count_max: int = 0
@export var allow_reward_behind_danger: bool = false
# Tactical wrinkle requirements: minimum count + permitted wrinkle-kind allowlist.
@export var is_combat_recipe: bool = true
@export var min_tactical_wrinkles: int = 0
@export var allowed_wrinkle_kinds: Array[StringName] = []
@export var tactical_identity: String = ""

func _init(
	new_recipe_id: StringName = &"",
	new_size_class: StringName = &"",
	new_allow_blockers: bool = true,
	new_wall_density: float = 0.0,
	new_blocker_budget_min: int = 0,
	new_blocker_budget_max: int = 0,
	new_enemy_budget_min: int = 0,
	new_enemy_budget_max: int = 0,
	new_reward_count_min: int = 0,
	new_reward_count_max: int = 0,
	new_allow_reward_behind_danger: bool = false,
	new_min_tactical_wrinkles: int = 0,
	new_allowed_wrinkle_kinds: Array = [],
	new_tactical_identity: String = "",
	new_is_combat_recipe: bool = true
) -> void:
	recipe_id = new_recipe_id
	size_class = new_size_class
	allow_blockers = new_allow_blockers
	wall_density = new_wall_density
	blocker_budget_min = new_blocker_budget_min
	blocker_budget_max = new_blocker_budget_max
	enemy_budget_min = new_enemy_budget_min
	enemy_budget_max = new_enemy_budget_max
	reward_count_min = new_reward_count_min
	reward_count_max = new_reward_count_max
	allow_reward_behind_danger = new_allow_reward_behind_danger
	min_tactical_wrinkles = new_min_tactical_wrinkles
	allowed_wrinkle_kinds = _copy_ids(new_allowed_wrinkle_kinds)
	tactical_identity = new_tactical_identity
	is_combat_recipe = new_is_combat_recipe


func validate() -> ActionResult:
	if not _is_lower_snake_id(recipe_id):
		return _invalid(&"recipe_id")
	if not _is_valid_size_class(size_class):
		return _invalid(&"size_class")
	if wall_density < 0.0 or wall_density > 1.0:
		return _invalid(&"wall_density")
	if blocker_budget_min < 0:
		return _invalid(&"blocker_budget_min")
	if blocker_budget_max < blocker_budget_min:
		return _invalid(&"blocker_budget_max")
	if not allow_blockers and blocker_budget_max > 0:
		return _invalid(&"blocker_budget_max")
	if enemy_budget_min < 0:
		return _invalid(&"enemy_budget_min")
	if enemy_budget_max < enemy_budget_min:
		return _invalid(&"enemy_budget_max")
	if reward_count_min < 0:
		return _invalid(&"reward_count_min")
	if reward_count_max < reward_count_min:
		return _invalid(&"reward_count_max")
	if tactical_identity.strip_edges().is_empty():
		return _invalid(&"tactical_identity")
	if min_tactical_wrinkles < 0:
		return _invalid(&"min_tactical_wrinkles")
	if is_combat_recipe and min_tactical_wrinkles < 1:
		return _invalid(&"min_tactical_wrinkles")
	for wrinkle_kind: StringName in allowed_wrinkle_kinds:
		if not _is_valid_wrinkle_kind(wrinkle_kind):
			return _invalid(&"allowed_wrinkle_kinds")
	if min_tactical_wrinkles > 0 and allowed_wrinkle_kinds.is_empty():
		return _invalid(&"allowed_wrinkle_kinds")
	return ActionResult.ok()


func terrain_rules() -> Dictionary:
	return {
		"wall_density": wall_density,
		"allow_blockers": allow_blockers
	}


func reward_placement_rules() -> Dictionary:
	return {
		"reward_count_min": reward_count_min,
		"reward_count_max": reward_count_max,
		"allow_reward_behind_danger": allow_reward_behind_danger
	}


func tactical_wrinkle_requirements() -> Dictionary:
	return {
		"min_tactical_wrinkles": min_tactical_wrinkles,
		"allowed_wrinkle_kinds": _copy_ids(allowed_wrinkle_kinds)
	}


static func valid_wrinkle_kinds() -> Array[StringName]:
	return [
		WRINKLE_HAZARD,
		WRINKLE_DOOR,
		WRINKLE_CHOKE_POINT,
		WRINKLE_FLANK_ROUTE,
		WRINKLE_BLOCKER_CLUSTER,
		WRINKLE_AFFINITY_PLACEHOLDER,
		WRINKLE_ENEMY_FORMATION,
		WRINKLE_REWARD_BEHIND_DANGER,
		WRINKLE_RISKY_SIDE_BRANCH
	]


static func _is_valid_size_class(value: StringName) -> bool:
	return value == SIZE_SMALL or value == SIZE_MEDIUM


static func _is_valid_wrinkle_kind(value: StringName) -> bool:
	return valid_wrinkle_kinds().has(value)


static func _copy_ids(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(str(value)))
	return result


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
	return ActionResult.error(&"invalid_level_recipe_definition", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
