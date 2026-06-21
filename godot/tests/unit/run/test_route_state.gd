extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")

func run() -> Dictionary:
	_valid_route_round_trips_with_stable_node_order()
	_dangling_link_is_rejected()
	_unknown_current_node_is_rejected()
	_duplicate_node_id_is_rejected()
	_unknown_cleared_node_is_rejected()
	_duplicate_cleared_node_is_rejected()
	_available_choices_exclude_cleared_nodes()
	_available_choices_empty_when_not_on_a_node()
	_eligible_choices_are_reveal_gated_and_cleared_excluded()
	_eligible_choices_empty_when_not_on_a_node()
	_is_eligible_choice_membership_matches_the_set()
	_node_lookup_helpers_work()
	return result()


func _build_linear_route() -> RouteState:
	# start -> choice-a / choice-b ; choice-a -> boss
	var start: RouteNode = RouteNode.new("start", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["choice-a", "choice-b"])
	var choice_a: RouteNode = RouteNode.new("choice-a", RouteNode.TYPE_ELITE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["boss"])
	var choice_b: RouteNode = RouteNode.new("choice-b", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_REVEALED, ["boss"])
	var boss: RouteNode = RouteNode.new("boss", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_HIDDEN, [])
	return RouteState.new([start, choice_a, choice_b, boss], "start", ["start"])


func _valid_route_round_trips_with_stable_node_order() -> void:
	var route: RouteState = _build_linear_route()
	assert_true(route.validate().succeeded, "A structurally sound route should validate.")

	# Real JSON round-trip (mandatory). Node order must be preserved.
	var json_data: Variant = JSON.parse_string(JSON.stringify(route.to_dictionary()))
	assert_true(json_data is Dictionary, "Route state should survive JSON stringify/parse.")
	var parse_result: ActionResult = RouteState.try_from_dictionary(json_data)
	assert_true(parse_result.succeeded, "Route state should parse after a real JSON round-trip: %s" % parse_result.metadata)
	var parsed: RouteState = parse_result.metadata.get("route") as RouteState

	var parsed_ids: Array[String] = []
	for node: RouteNode in parsed.nodes():
		parsed_ids.append(node.id)
	assert_equal(parsed_ids, ["start", "choice-a", "choice-b", "boss"], "Node order must be stable through the JSON round-trip.")
	assert_equal(parsed.current_node_id, "start", "Current node id must round-trip.")
	assert_equal(parsed.cleared_node_ids, ["start"], "Cleared node ids must round-trip.")


func _dangling_link_is_rejected() -> void:
	var a: RouteNode = RouteNode.new("a", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN, ["missing"])
	var route: RouteState = RouteState.new([a], "", [])
	var validation: ActionResult = route.validate()
	assert_true(validation.is_error(), "A link to an unknown node should be rejected.")
	assert_equal(validation.error_code, &"dangling_route_link", "Dangling link should use a stable code.")
	assert_equal(validation.metadata.get("link"), "missing", "Dangling link should name the offending link.")


func _unknown_current_node_is_rejected() -> void:
	var a: RouteNode = RouteNode.new("a", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([a], "ghost", [])
	var validation: ActionResult = route.validate()
	assert_true(validation.is_error(), "An unknown current node should be rejected.")
	assert_equal(validation.error_code, &"unknown_current_node", "Unknown current node should use a stable code.")


func _duplicate_node_id_is_rejected() -> void:
	var first: RouteNode = RouteNode.new("dup", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN, [])
	var second: RouteNode = RouteNode.new("dup", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([first, second], "", [])
	var validation: ActionResult = route.validate()
	assert_true(validation.is_error(), "Duplicate node ids should be rejected.")
	assert_equal(validation.error_code, &"duplicate_route_node", "Duplicate node id should use a stable code.")
	assert_equal(validation.metadata.get("node_id"), "dup", "Duplicate node id should be named.")


func _unknown_cleared_node_is_rejected() -> void:
	var a: RouteNode = RouteNode.new("a", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([a], "", ["a", "phantom"])
	var validation: ActionResult = route.validate()
	assert_true(validation.is_error(), "A cleared id with no matching node should be rejected.")
	assert_equal(validation.error_code, &"unknown_cleared_node", "Unknown cleared node should use a stable code.")
	assert_equal(validation.metadata.get("node_id"), "phantom", "Unknown cleared node should be named.")


func _duplicate_cleared_node_is_rejected() -> void:
	var a: RouteNode = RouteNode.new("a", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN, [])
	var route: RouteState = RouteState.new([a], "", ["a", "a"])
	var validation: ActionResult = route.validate()
	assert_true(validation.is_error(), "A duplicate cleared id should be rejected.")
	assert_equal(validation.error_code, &"duplicate_cleared_node", "Duplicate cleared node should use a stable code.")


func _available_choices_exclude_cleared_nodes() -> void:
	# hub -> a, b, c ; b already cleared -> only a and c are available choices.
	var hub: RouteNode = RouteNode.new("hub", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["a", "b", "c"])
	var a: RouteNode = RouteNode.new("a", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_REVEALED, [])
	var b: RouteNode = RouteNode.new("b", RouteNode.TYPE_REFORGE, 1, RouteNode.REVEAL_CLEARED, [])
	var c: RouteNode = RouteNode.new("c", RouteNode.TYPE_EVENT, 1, RouteNode.REVEAL_REVEALED, [])
	var route: RouteState = RouteState.new([hub, a, b, c], "hub", ["b"])
	assert_true(route.validate().succeeded, "Route with a cleared branch should validate.")
	assert_equal(route.available_choice_ids(), ["a", "c"], "available_choice_ids must exclude cleared nodes and preserve link order.")


func _available_choices_empty_when_not_on_a_node() -> void:
	var route: RouteState = _build_linear_route()
	route.current_node_id = ""
	assert_equal(route.available_choice_ids(), [], "With no current node, there are no derived choices.")


func _eligible_choices_are_reveal_gated_and_cleared_excluded() -> void:
	# Story 4.3 filter: hub links to a REVEALED node, a HIDDEN node, and a CLEARED node. Only the
	# revealed, non-cleared link is ELIGIBLE — proving eligible_choice_ids() applies the reveal gate
	# that available_choice_ids() (4.1) deliberately lacks (it still surfaces the hidden node).
	var hub: RouteNode = RouteNode.new("hub", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["revealed", "hidden", "gone"])
	var revealed: RouteNode = RouteNode.new("revealed", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_REVEALED, [])
	var hidden: RouteNode = RouteNode.new("hidden", RouteNode.TYPE_EVENT, 1, RouteNode.REVEAL_HIDDEN, [])
	var gone: RouteNode = RouteNode.new("gone", RouteNode.TYPE_REFORGE, 1, RouteNode.REVEAL_CLEARED, [])
	var route: RouteState = RouteState.new([hub, revealed, hidden, gone], "hub", ["gone"])
	assert_true(route.validate().succeeded, "Route with hidden/cleared branches should validate.")

	assert_equal(route.eligible_choice_ids(), ["revealed"], "eligible_choice_ids must keep only the revealed, non-cleared link.")
	# The 4.1 sibling is UNCHANGED: it excludes only the cleared id, so it still surfaces the hidden node.
	assert_equal(route.available_choice_ids(), ["revealed", "hidden"], "available_choice_ids must keep its 4.1 behavior (hidden node still surfaced).")


func _eligible_choices_empty_when_not_on_a_node() -> void:
	var route: RouteState = _build_linear_route()
	route.current_node_id = ""
	assert_equal(route.eligible_choice_ids(), [], "With no current node, there are no eligible choices.")


func _is_eligible_choice_membership_matches_the_set() -> void:
	# choice-a is REVEALED + linked + non-cleared (eligible); boss is HIDDEN and not a current link
	# (ineligible); start is the current node (ineligible).
	var route: RouteState = _build_linear_route()
	assert_true(route.is_eligible_choice("choice-a"), "A revealed, linked, non-cleared node is an eligible choice.")
	assert_false(route.is_eligible_choice("boss"), "A hidden, non-linked node is not an eligible choice.")
	assert_false(route.is_eligible_choice("start"), "The current node itself is not an eligible choice.")
	assert_false(route.is_eligible_choice("ghost"), "An unknown id is not an eligible choice.")


func _node_lookup_helpers_work() -> void:
	var route: RouteState = _build_linear_route()
	assert_true(route.has_node("boss"), "has_node should find a present node.")
	assert_false(route.has_node("nope"), "has_node should reject an absent node.")
	assert_equal(route.node_by_id("choice-a").type, RouteNode.TYPE_ELITE_COMBAT, "node_by_id should return the right node.")
	assert_true(route.node_by_id("nope") == null, "node_by_id should return null for an absent id.")
	assert_equal(route.node_count(), 4, "node_count should report the number of nodes.")
