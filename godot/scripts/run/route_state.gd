class_name RouteState
extends RefCounted

# Scene-independent route graph container (Story 4.1). Holds an ORDERED collection of RouteNodes
# keyed by stable id, plus the current node pointer and the set of cleared node ids. It derives the
# legal next choices from the graph (available_choice_ids) and validates STRUCTURAL integrity
# (validate-then-reject, no mutation). It does NOT generate routes (Story 4.2), does NOT enforce
# the forward-only/no-backtracking graph shape (Story 4.2 owns edge-shape validation), and does NOT
# commit a route choice (Story 4.3). Node order MUST stay stable so the round-trip and any future
# route fingerprint are deterministic — nodes serialize as an ordered Array[Dictionary].

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")

var current_node_id: String = ""
var cleared_node_ids: Array[String] = []

# Insertion-ordered node list (authoritative for serialization order) + an id index for O(1)
# lookup. The index is rebuilt from the ordered list whenever nodes are set.
var _nodes: Array[RouteNode] = []
var _node_index: Dictionary = {}

func _init(
	new_nodes: Array = [],
	new_current_node_id: String = "",
	new_cleared_node_ids: Array = []
) -> void:
	set_nodes(new_nodes)
	current_node_id = new_current_node_id
	cleared_node_ids = _copy_string_array(new_cleared_node_ids)


func set_nodes(new_nodes: Array) -> void:
	_nodes = []
	_node_index = {}
	for node_value: Variant in new_nodes:
		if node_value is RouteNode:
			var node: RouteNode = node_value
			_nodes.append(node)
			# Last-writer-wins in the index; a duplicate id is caught structurally by validate().
			_node_index[node.id] = node


func nodes() -> Array[RouteNode]:
	return _nodes.duplicate()


func node_count() -> int:
	return _nodes.size()


func has_node(node_id: String) -> bool:
	return _node_index.has(node_id)


func node_by_id(node_id: String) -> RouteNode:
	return _node_index.get(node_id) as RouteNode


# The outgoing links of the current node that are not already cleared. When the run is not parked
# on a node (current_node_id == "") or the current node is unknown, there are no derived choices.
# This story only DERIVES these; the choose-and-commit command is Story 4.3.
func available_choice_ids() -> Array[String]:
	var choices: Array[String] = []
	if current_node_id.is_empty():
		return choices
	var current: RouteNode = node_by_id(current_node_id)
	if current == null:
		return choices
	var cleared_lookup: Dictionary = {}
	for cleared_id: String in cleared_node_ids:
		cleared_lookup[cleared_id] = true
	for link_id: String in current.outgoing_link_ids:
		if not cleared_lookup.has(link_id):
			choices.append(link_id)
	return choices


# The choice-eligibility FILTER that Story 4.1's available_choice_ids() deliberately lacks (its
# reveal-gating + no-backtracking deferral, OWNER = Story 4.3). An ELIGIBLE choice is a current-node
# outgoing link that is (a) a KNOWN node, (b) REVEAL_REVEALED, and (c) NOT in cleared_node_ids. This
# is the SELECTION filter RouteAdvanceCommand validates a chosen id against; available_choice_ids()
# is left byte-identical (it is pinned by 4.1 tests and surfaces hidden linked nodes by design).
# Pure query: no mutation, no RNG. Preserves the current node's link order.
func eligible_choice_ids() -> Array[String]:
	var eligible: Array[String] = []
	if current_node_id.is_empty():
		return eligible
	var current: RouteNode = node_by_id(current_node_id)
	if current == null:
		return eligible
	var cleared_lookup: Dictionary = {}
	for cleared_id: String in cleared_node_ids:
		cleared_lookup[cleared_id] = true
	for link_id: String in current.outgoing_link_ids:
		if cleared_lookup.has(link_id):
			continue
		var linked: RouteNode = node_by_id(link_id)
		if linked == null:
			continue
		if linked.reveal_state != RouteNode.REVEAL_REVEALED:
			continue
		eligible.append(link_id)
	return eligible


# Convenience membership check for the eligible-choice set so the command can validate a chosen id
# with a single call. Pure query.
func is_eligible_choice(node_id: String) -> bool:
	return eligible_choice_ids().has(node_id)


func validate() -> ActionResult:
	# Reject duplicate node ids and validate each node individually.
	var seen_nodes: Dictionary = {}
	for node: RouteNode in _nodes:
		var node_validation: ActionResult = node.validate()
		if node_validation.is_error():
			return node_validation
		if seen_nodes.has(node.id):
			return ActionResult.error(&"duplicate_route_node", {
				"field": "nodes",
				"node_id": node.id
			})
		seen_nodes[node.id] = true

	# Every outgoing link must resolve to a known node.
	for node: RouteNode in _nodes:
		for link_id: String in node.outgoing_link_ids:
			if not _node_index.has(link_id):
				return ActionResult.error(&"dangling_route_link", {
					"field": "outgoing_link_ids",
					"node_id": node.id,
					"link": link_id
				})

	# The current node pointer, when non-empty, must be a known node.
	if not current_node_id.is_empty() and not _node_index.has(current_node_id):
		return ActionResult.error(&"unknown_current_node", {
			"field": "current_node_id",
			"node_id": current_node_id
		})

	# Cleared node ids must all be known and unique.
	var seen_cleared: Dictionary = {}
	for cleared_id: String in cleared_node_ids:
		if not _node_index.has(cleared_id):
			return ActionResult.error(&"unknown_cleared_node", {
				"field": "cleared_node_ids",
				"node_id": cleared_id
			})
		if seen_cleared.has(cleared_id):
			return ActionResult.error(&"duplicate_cleared_node", {
				"field": "cleared_node_ids",
				"node_id": cleared_id
			})
		seen_cleared[cleared_id] = true

	return ActionResult.ok()


func to_dictionary() -> Dictionary:
	# Nodes serialize as an ORDERED Array[Dictionary] (not an unordered Dictionary) so order is
	# deterministic through the round-trip and any future fingerprint.
	var node_dicts: Array[Dictionary] = []
	for node: RouteNode in _nodes:
		node_dicts.append(node.to_dictionary())
	return {
		"nodes": node_dicts,
		"current_node_id": current_node_id,
		"cleared_node_ids": cleared_node_ids.duplicate(true)
	}


func copy() -> RouteState:
	var copied_nodes: Array[RouteNode] = []
	for node: RouteNode in _nodes:
		copied_nodes.append(node.copy())
	return load("res://scripts/run/route_state.gd").new(
		copied_nodes,
		current_node_id,
		cleared_node_ids
	)


static func try_from_dictionary(data: Dictionary) -> ActionResult:
	if not _has_field(data, &"nodes"):
		return ActionResult.error(&"invalid_route_state", {"field": "nodes"})
	var nodes_value: Variant = _field(data, &"nodes")
	if not nodes_value is Array:
		return ActionResult.error(&"invalid_route_state", {"field": "nodes"})

	var parsed_nodes: Array[RouteNode] = []
	for node_value: Variant in nodes_value:
		if not node_value is Dictionary:
			return ActionResult.error(&"invalid_route_state", {"field": "nodes"})
		var node_result: ActionResult = RouteNode.try_from_dictionary(node_value)
		if node_result.is_error():
			return node_result
		parsed_nodes.append(node_result.metadata.get("node") as RouteNode)

	var parsed_current_node_id: String = ""
	if _has_field(data, &"current_node_id"):
		var current_value: Variant = _field(data, &"current_node_id")
		if not (current_value is String or current_value is StringName):
			return ActionResult.error(&"invalid_route_state", {"field": "current_node_id"})
		parsed_current_node_id = String(current_value)

	var parsed_cleared: Array[String] = []
	if _has_field(data, &"cleared_node_ids"):
		var cleared_value: Variant = _field(data, &"cleared_node_ids")
		if not cleared_value is Array:
			return ActionResult.error(&"invalid_route_state", {"field": "cleared_node_ids"})
		for cleared_id_value: Variant in cleared_value:
			if not (cleared_id_value is String or cleared_id_value is StringName):
				return ActionResult.error(&"invalid_route_state", {"field": "cleared_node_ids"})
			parsed_cleared.append(String(cleared_id_value))

	var route: RouteState = load("res://scripts/run/route_state.gd").new(
		parsed_nodes,
		parsed_current_node_id,
		parsed_cleared
	)
	var validation: ActionResult = route.validate()
	if validation.is_error():
		return validation
	return ActionResult.ok([], {"route": route})


static func from_dictionary(data: Dictionary) -> RouteState:
	var result: ActionResult = try_from_dictionary(data)
	if result.is_error():
		push_error("RouteState parse failed: %s" % String(result.error_code))
		return null
	return result.metadata.get("route") as RouteState


static func _has_field(data: Dictionary, field_name: StringName) -> bool:
	return data.has(String(field_name)) or data.has(field_name)


static func _field(data: Dictionary, field_name: StringName) -> Variant:
	if data.has(String(field_name)):
		return data[String(field_name)]
	return data.get(field_name)


static func _copy_string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result
