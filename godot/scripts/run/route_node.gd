class_name RouteNode
extends RefCounted

# Scene-independent route node model (Story 4.1). A RouteNode is a plain typed RefCounted DTO:
# it carries a STABLE caller/fixture-supplied id (NOT minted here — id minting during route
# generation is Story 4.2 and requires the `map` stream this story must not touch), a node type
# drawn from the MVP node-type vocabulary, a non-negative depth, an orthogonal reveal state, its
# outgoing link ids, and optional tradeoff-clue tags. It validates structurally (validate-then-
# reject, no mutation) and round-trips through serialization unchanged.
#
# Mirrors the serialization+parse contract style of CombatOutcomeState (string-like field guards,
# `_field`/`_has_field` helpers, `try_*` returns ActionResult, `from_*` is the lenient wrapper).

const ActionResult = preload("res://scripts/core/results/action_result.gd")

# Reveal state (orthogonal to RunState phase). lower_snake wire ids held in UPPER_SNAKE constants.
const REVEAL_HIDDEN := &"hidden"
const REVEAL_REVEALED := &"revealed"
const REVEAL_CLEARED := &"cleared"

# MVP node-type vocabulary (epics Story 4.5 set). 4.1 owns the vocabulary + validation only;
# per-type resolution behavior is Story 4.5.
const TYPE_COMBAT := &"combat"
const TYPE_ELITE_COMBAT := &"elite_combat"
const TYPE_SHOP := &"shop"
const TYPE_REFORGE := &"reforge"
const TYPE_GAMBLING := &"gambling"
const TYPE_EVENT := &"event"
const TYPE_SECRET := &"secret"
const TYPE_BOSS := &"boss"

# Canonical tradeoff-clue tags (epics Story 4.2 AC4 vocabulary). In 4.1 these are OPTIONAL,
# free-form data fields (default empty); Story 4.2 populates them during generation. We define the
# field + the canonical tags but build no clue-generation logic here.
const CLUE_SAFER_COMBAT := &"safer_combat"
const CLUE_STRONGER_REWARD := &"stronger_reward"
const CLUE_UNKNOWN_RISK := &"unknown_risk"
const CLUE_RECOVERY := &"recovery"
const CLUE_ELITE_PRESSURE := &"elite_pressure"
const CLUE_MYSTERY := &"mystery"

var id: String = ""
var type: StringName = TYPE_COMBAT
var depth: int = 0
var reveal_state: StringName = REVEAL_HIDDEN
var outgoing_link_ids: Array[String] = []
var clues: Array[String] = []

func _init(
	new_id: String = "",
	new_type: StringName = TYPE_COMBAT,
	new_depth: int = 0,
	new_reveal_state: StringName = REVEAL_HIDDEN,
	new_outgoing_link_ids: Array = [],
	new_clues: Array = []
) -> void:
	id = new_id
	type = new_type
	depth = new_depth
	reveal_state = new_reveal_state
	outgoing_link_ids = _copy_string_array(new_outgoing_link_ids)
	clues = _copy_string_array(new_clues)


func validate() -> ActionResult:
	if not _is_valid_node_id(id):
		return _invalid(&"invalid_node_id", {"field": "id"})
	if not _is_supported_type(type):
		return _invalid(&"invalid_node_type", {"field": "type", "type": String(type)})
	if depth < 0:
		return _invalid(&"invalid_node_depth", {"field": "depth", "depth": depth})
	if not _is_supported_reveal_state(reveal_state):
		return _invalid(&"invalid_node_reveal_state", {
			"field": "reveal_state",
			"reveal_state": String(reveal_state)
		})

	var seen_links: Dictionary = {}
	for link_id: String in outgoing_link_ids:
		if not _is_valid_node_id(link_id):
			return _invalid(&"invalid_node_link", {"field": "outgoing_link_ids", "link": link_id})
		if link_id == id:
			return _invalid(&"self_referential_node_link", {
				"field": "outgoing_link_ids",
				"link": link_id
			})
		if seen_links.has(link_id):
			return _invalid(&"duplicate_node_link", {"field": "outgoing_link_ids", "link": link_id})
		seen_links[link_id] = true

	# Clue tags are optional and free-form; reject only non-string-like junk so the payload stays
	# serializable. Story 4.2 owns the clue VALUES; 4.1 keeps the field tolerant.
	for clue: String in clues:
		if clue.strip_edges().is_empty():
			return _invalid(&"invalid_node_clue", {"field": "clues", "clue": clue})

	return ActionResult.ok()


func has_clue(clue: StringName) -> bool:
	return clues.has(String(clue))


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"type": String(type),
		"depth": depth,
		"reveal_state": String(reveal_state),
		"outgoing_link_ids": outgoing_link_ids.duplicate(true),
		"clues": clues.duplicate(true)
	}


func copy() -> RouteNode:
	return load("res://scripts/run/route_node.gd").new(
		id,
		type,
		depth,
		reveal_state,
		outgoing_link_ids,
		clues
	)


static func try_from_dictionary(data: Dictionary) -> ActionResult:
	if not _has_string_like_field(data, &"id"):
		return _invalid(&"invalid_node_id", {"field": "id"})
	if not _has_string_like_field(data, &"type"):
		return _invalid(&"invalid_node_type", {"field": "type"})
	if not _has_field(data, &"depth") or not _is_integral_number(_field(data, &"depth")):
		return _invalid(&"invalid_node_depth", {"field": "depth"})
	if not _has_string_like_field(data, &"reveal_state"):
		return _invalid(&"invalid_node_reveal_state", {"field": "reveal_state"})

	var parsed_links: Array[String] = []
	if _has_field(data, &"outgoing_link_ids"):
		var links_value: Variant = _field(data, &"outgoing_link_ids")
		if not links_value is Array:
			return _invalid(&"invalid_node_link", {"field": "outgoing_link_ids"})
		for link_value: Variant in links_value:
			if not (link_value is String or link_value is StringName):
				return _invalid(&"invalid_node_link", {"field": "outgoing_link_ids"})
			parsed_links.append(String(link_value))

	var parsed_clues: Array[String] = []
	if _has_field(data, &"clues"):
		var clues_value: Variant = _field(data, &"clues")
		if not clues_value is Array:
			return _invalid(&"invalid_node_clue", {"field": "clues"})
		for clue_value: Variant in clues_value:
			if not (clue_value is String or clue_value is StringName):
				return _invalid(&"invalid_node_clue", {"field": "clues"})
			parsed_clues.append(String(clue_value))

	var node: RouteNode = load("res://scripts/run/route_node.gd").new(
		String(_field(data, &"id")),
		StringName(String(_field(data, &"type"))),
		int(_field(data, &"depth")),
		StringName(String(_field(data, &"reveal_state"))),
		parsed_links,
		parsed_clues
	)
	var validation: ActionResult = node.validate()
	if validation.is_error():
		return validation
	return ActionResult.ok([], {"node": node})


static func from_dictionary(data: Dictionary) -> RouteNode:
	var result: ActionResult = try_from_dictionary(data)
	if result.is_error():
		push_error("RouteNode parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("node") as RouteNode


static func supported_types() -> Array[StringName]:
	return [
		TYPE_COMBAT,
		TYPE_ELITE_COMBAT,
		TYPE_SHOP,
		TYPE_REFORGE,
		TYPE_GAMBLING,
		TYPE_EVENT,
		TYPE_SECRET,
		TYPE_BOSS
	]


static func _is_supported_type(value: StringName) -> bool:
	return supported_types().has(value)


static func _is_supported_reveal_state(value: StringName) -> bool:
	return value == REVEAL_HIDDEN or value == REVEAL_REVEALED or value == REVEAL_CLEARED


# A stable node id: non-empty and free of any whitespace (it round-trips through serialization and
# is used as a test/save reference verbatim). Ids are caller/fixture-supplied in 4.1, not minted.
static func _is_valid_node_id(value: String) -> bool:
	if value.is_empty():
		return false
	if value.strip_edges() != value:
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		# Reject ASCII whitespace anywhere inside the id (space/tab/newline/CR/FF/VT).
		if code == 32 or (code >= 9 and code <= 13):
			return false
	return true


static func _is_integral_number(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			var numeric_value: float = float(value)
			if is_nan(numeric_value) or is_inf(numeric_value):
				return false
			return is_equal_approx(numeric_value, round(numeric_value))
		_:
			return false


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


static func _has_string_like_field(data: Dictionary, field_name: StringName) -> bool:
	if not _has_field(data, field_name):
		return false
	var value: Variant = _field(data, field_name)
	return value is String or value is StringName


static func _copy_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result


static func _invalid(error_code: StringName, new_metadata: Dictionary = {}) -> ActionResult:
	return ActionResult.error(error_code, new_metadata)
