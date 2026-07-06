extends "res://tests/unit/test_case.gd"

# Story 11.3 Task 3 — RouteMapViewModel (AC1/AC2, Contract gap G2): the route/run-map view model.
#
# RouteMapViewModel is the thin fail-closed RefCounted route PROJECTION the route-map scene reads (today the map
# would read RouteState / RouteNode DIRECTLY — there is NO dedicated route VIEW model). It projects, from the
# pinned route reads: current_node_id, cleared_node_ids, the SELECTION-legal eligible_choice_ids() (known +
# REVEAL_REVEALED + not cleared — NOT the looser available_choice_ids()), and per-node type (RouteNode.TYPE_*),
# reveal_state (REVEAL_*), depth, outgoing_link_ids, and clues (CLUE_*). It owns NO route truth (the commit of a
# chosen node is the EXISTING route-advance command the flow submits — the map presents choices + reports the
# pick). This test pins the eligible-vs-available discipline, the per-node fields, the reveal vocabulary, the
# exact key set, the fail-closed empty/terminal route, and the no-live-handle projection.

const RouteMapViewModel = preload("res://scripts/ui/view_models/route_map_view_model.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")

# The pinned top-level key set (sorted).
const EXPECTED_KEYS: Array[String] = [
	"cleared_node_ids",
	"current_node_id",
	"eligible_choice_ids",
	"has_route",
	"nodes"
]

# The pinned per-node key set (sorted).
const EXPECTED_NODE_KEYS: Array[String] = [
	"clues",
	"depth",
	"id",
	"is_cleared",
	"is_current",
	"is_eligible",
	"outgoing_link_ids",
	"reveal_state",
	"type"
]

func run() -> Dictionary:
	_null_route_projects_fail_closed_empty()
	_projects_current_cleared_and_eligible()
	_eligible_uses_eligible_not_available()
	_per_node_fields_projected()
	_exact_key_sets_pinned()
	_terminal_route_projects_no_eligible_choices()
	_projection_is_a_pure_copy_no_live_handle_leak()
	return result()


# G2 fail-closed: a null route projects the empty fact (has_route == false) — never a crash.
func _null_route_projects_fail_closed_empty() -> void:
	var data: Dictionary = RouteMapViewModel.from_route(null).to_dictionary()
	assert_equal(data.get("has_route"), false, "A null route must project has_route == false (fail-closed).")
	assert_equal(data.get("current_node_id"), "", "A null route must project an empty current node id.")
	assert_equal((data.get("nodes", []) as Array).size(), 0, "A null route must project no nodes.")
	assert_equal((data.get("eligible_choice_ids", []) as Array).size(), 0, "A null route must project no eligible choices.")


# G2: current_node_id + cleared_node_ids + eligible_choice_ids are projected from the route.
func _projects_current_cleared_and_eligible() -> void:
	var route: RouteState = _diamond_route()
	route.current_node_id = "start"
	var data: Dictionary = RouteMapViewModel.from_route(route).to_dictionary()
	assert_equal(data.get("has_route"), true, "A real route must project has_route == true.")
	assert_equal(data.get("current_node_id"), "start", "current_node_id must be projected.")
	# start links to left + right, both REVEAL_REVEALED and not cleared -> both eligible.
	assert_equal(data.get("eligible_choice_ids"), ["left", "right"], "Both revealed uncleared links must be eligible choices.")


# G2 (the load-bearing discipline): eligible_choice_ids uses eligible_choice_ids() (reveal-gated), NOT
# available_choice_ids() (which surfaces a HIDDEN linked node). A hidden link must NOT appear in the projection.
func _eligible_uses_eligible_not_available() -> void:
	var nodes: Array[RouteNode] = [
		RouteNode.new("start", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_REVEALED, ["revealed_next", "hidden_next"], []),
		RouteNode.new("revealed_next", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_REVEALED, [], []),
		RouteNode.new("hidden_next", RouteNode.TYPE_EVENT, 1, RouteNode.REVEAL_HIDDEN, [], [])
	]
	var route: RouteState = RouteState.new(nodes, "start", [])
	# available_choice_ids() would return BOTH (it does not reveal-gate); the projection must return only the revealed one.
	assert_equal(route.available_choice_ids(), ["revealed_next", "hidden_next"], "Sanity: available_choice_ids surfaces the hidden link.")
	var data: Dictionary = RouteMapViewModel.from_route(route).to_dictionary()
	assert_equal(data.get("eligible_choice_ids"), ["revealed_next"], "The projection must use eligible_choice_ids() (reveal-gated), NOT available_choice_ids().")


# G2: each node projects id/type/reveal_state/depth/outgoing_link_ids/clues + the derived is_current/is_cleared/is_eligible.
func _per_node_fields_projected() -> void:
	var route: RouteState = _diamond_route()
	route.current_node_id = "start"
	var data: Dictionary = RouteMapViewModel.from_route(route).to_dictionary()
	var by_id: Dictionary = _nodes_by_id(data)
	var left: Dictionary = by_id.get("left", {})
	assert_equal(left.get("type"), "combat", "Node type must be projected as a lower_snake string.")
	assert_equal(left.get("reveal_state"), "revealed", "Node reveal_state must be projected.")
	assert_equal(left.get("depth"), 1, "Node depth must be projected.")
	assert_equal(left.get("outgoing_link_ids"), ["boss"], "Node outgoing links must be projected.")
	assert_equal(left.get("clues"), ["safer_combat"], "Node clues must be projected verbatim.")
	assert_equal(left.get("is_eligible"), true, "A revealed uncleared current-node link must project is_eligible == true.")
	assert_equal(left.get("is_current"), false, "A non-current node must project is_current == false.")
	assert_equal(left.get("is_cleared"), false, "An uncleared node must project is_cleared == false.")
	var start_node: Dictionary = by_id.get("start", {})
	assert_equal(start_node.get("is_current"), true, "The current node must project is_current == true.")
	assert_equal(start_node.get("is_eligible"), false, "The current node itself is not an eligible CHOICE.")


func _exact_key_sets_pinned() -> void:
	var route: RouteState = _diamond_route()
	route.current_node_id = "start"
	var data: Dictionary = RouteMapViewModel.from_route(route).to_dictionary()
	var keys: Array = data.keys()
	keys.sort()
	assert_equal(keys, EXPECTED_KEYS, "The route-map projection must expose EXACTLY the pinned top-level key set.")
	for node: Variant in data.get("nodes", []):
		var node_keys: Array = (node as Dictionary).keys()
		node_keys.sort()
		assert_equal(node_keys, EXPECTED_NODE_KEYS, "Each node must expose EXACTLY the pinned per-node key set.")
	# The empty projection carries the SAME top-level key set (fail-closed).
	var empty_keys: Array = RouteMapViewModel.from_route(null).to_dictionary().keys()
	empty_keys.sort()
	assert_equal(empty_keys, EXPECTED_KEYS, "The empty projection must expose the SAME pinned key set.")


# G2 fail-closed: a route parked at a terminal boss (no revealed uncleared outgoing links) projects no eligible choices.
func _terminal_route_projects_no_eligible_choices() -> void:
	var route: RouteState = _diamond_route()
	# Park on the boss (a leaf: no outgoing links) — no eligible choices, no crash.
	route.current_node_id = "boss"
	var data: Dictionary = RouteMapViewModel.from_route(route).to_dictionary()
	assert_equal((data.get("eligible_choice_ids", []) as Array).size(), 0, "A terminal-node route must project no eligible choices (no crash).")


# G2 no-live-handle: mutating a returned node/list never perturbs the source route or a fresh projection.
func _projection_is_a_pure_copy_no_live_handle_leak() -> void:
	var route: RouteState = _diamond_route()
	route.current_node_id = "start"
	var view_model: RouteMapViewModel = RouteMapViewModel.from_route(route)
	var first: Dictionary = view_model.to_dictionary()
	(first.get("eligible_choice_ids", []) as Array).append("MUTATED")
	(first.get("nodes", [])[0] as Dictionary)["type"] = "MUTATED"
	var second: Dictionary = view_model.to_dictionary()
	assert_false((second.get("eligible_choice_ids", []) as Array).has("MUTATED"), "Mutating a returned choice list must not perturb a fresh projection.")
	assert_false(String((second.get("nodes", [])[0] as Dictionary).get("type", "")) == "MUTATED", "Mutating a returned node must not perturb a fresh projection.")
	# The source route node is untouched.
	assert_false(String(route.nodes()[0].type) == "MUTATED", "The projection must not mutate the source route.")


# --- helpers ---------------------------------------------------------------

# start -> {left, right}; left -> boss; right -> boss; boss is the terminal leaf.
func _diamond_route() -> RouteState:
	var nodes: Array[RouteNode] = [
		RouteNode.new("start", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["left", "right"], []),
		RouteNode.new("left", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["boss"], [RouteNode.CLUE_SAFER_COMBAT]),
		RouteNode.new("right", RouteNode.TYPE_ELITE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["boss"], [RouteNode.CLUE_ELITE_PRESSURE]),
		RouteNode.new("boss", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [], [])
	]
	return RouteState.new(nodes, "start", [])


func _nodes_by_id(data: Dictionary) -> Dictionary:
	var by_id: Dictionary = {}
	for node: Variant in data.get("nodes", []):
		by_id[String((node as Dictionary).get("id", ""))] = node
	return by_id
