class_name BossEncounterRequest
extends RefCounted

# The boss ENCOUNTER REQUEST (Story 9.1) — the deterministic, validated request that reaching the terminal
# boss node produces, the direct sibling of the combat-node level GenerationRequest. It carries the
# (root_seed, boss node id, boss entity id) needed to set up a Larval Avatar boss ARENA deterministically.
#
# WHY A DEDICATED DTO (not a reused GenerationRequest — the load-bearing [Decision]): GenerationRequest
# validates size_class ∈ {SIZE_SMALL, SIZE_MEDIUM} and difficulty_band == standard ONLY, and its pipeline
# produces an all-FLOOR combat board from the residual enemy/reward pool. A boss ARENA with a designated
# boss-entity SLOT + finale constraints is NOT a generic combat level, so it gets its own request shape:
# the GenerationRequest CONTRACT (root_seed + a lower_snake node id + node_type == boss + validate() +
# level_seed()) WITHOUT the combat size/difficulty validation. BossArenaBuilder consumes it (NOT
# LevelGenerator.generate), so the Small/Medium/route seed-regression fingerprints stay byte-identical.
#
# THE BOSS ENTITY is Story 9.2 — this request reserves the boss-entity SLOT id (larval_avatar) only; it
# authors NO HP/phases/actions (9.2 attaches the real definition at the same id).
#
# It draws ZERO RNG (building a request is pure — the NodeEnterCommand posture); the ARENA setup
# (BossArenaBuilder) is a deterministic pure function of (root_seed, boss node id).

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")

# The stable Larval Avatar boss node TYPE this request targets (== RouteNode.TYPE_BOSS). A request whose
# node_type is not this value is rejected — this request is ONLY for the terminal boss node.
const BOSS_NODE_TYPE := RouteNode.TYPE_BOSS

# The stable lower_snake boss-entity id the arena reserves a SLOT for. Story 9.2 attaches the real Larval
# Avatar definition (HP/phases/actions) at this id; 9.1 authors NO stats. Kept here so the id is defined in
# ONE place (the request + the arena builder + the event share it).
const BOSS_ENTITY_ID := &"larval_avatar"

var root_seed: int = 0
var node_id: StringName = &""
var node_type: StringName = BOSS_NODE_TYPE
var boss_entity_id: StringName = BOSS_ENTITY_ID

func _init(
	new_root_seed: int = 0,
	new_node_id: StringName = &"",
	new_node_type: StringName = BOSS_NODE_TYPE,
	new_boss_entity_id: StringName = BOSS_ENTITY_ID
) -> void:
	root_seed = new_root_seed
	node_id = new_node_id
	node_type = new_node_type
	boss_entity_id = new_boss_entity_id


# The arena seed derived from the root seed (v0: identity, mirroring GenerationRequest.level_seed()). The
# full 64-bit seed is preserved; if ever persisted, string-encode it per the int64/JSON rule.
func arena_seed() -> int:
	return root_seed


func validate() -> ActionResult:
	if root_seed < 0:
		return _invalid(&"root_seed")
	# node_id is DERIVED lower_snake from the hyphenated route boss id (node-7-0 -> node_7_0), so it is
	# validated lower_snake exactly like GenerationRequest.node_id (which rejects hyphens).
	if not _is_lower_snake_id(node_id):
		return _invalid(&"node_id")
	# This request is ONLY for the terminal boss node — the node_type must be the boss type.
	if node_type != BOSS_NODE_TYPE:
		return _invalid(&"node_type")
	if not _is_lower_snake_id(boss_entity_id):
		return _invalid(&"boss_entity_id")
	return ActionResult.ok()


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
	return ActionResult.error(&"invalid_boss_encounter_request", {
		"reason": "invalid_field",
		"field": String(field_name)
	})
