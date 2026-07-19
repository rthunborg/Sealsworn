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
	# Story 14.6 (AC1/AC3) — the render-fact accessors (current position / terminal boss / progress counts).
	_render_fact_accessors_project_current_boss_and_counts()
	_render_fact_accessors_fail_closed_on_null_route()
	_render_fact_accessors_on_terminal_boss_leaf()
	_render_fact_accessors_return_fresh_copies_no_live_handle_leak()
	_render_fact_accessors_add_no_projection_key()
	# Story 14.6 review (AC1) — the cleared-current-node render-fact the "✓ Cleared" marker on "You are here" reads.
	_current_node_carries_is_cleared_on_a_just_cleared_current_node()
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


# Story 14.6 (AC1): the render-fact accessors surface the current position, the terminal boss, and the
# cleared/total progress counts the presenter renders — pure computed reads over the already-projected nodes.
func _render_fact_accessors_project_current_boss_and_counts() -> void:
	var view_model: RouteMapViewModel = RouteMapViewModel.from_route(_mid_descent_route())

	var current: Dictionary = view_model.current_node()
	assert_equal(str(current.get("id", "")), "left", "current_node() must return the is_current node.")
	assert_equal(current.get("is_current"), true, "current_node() must carry is_current == true.")

	var boss: Dictionary = view_model.boss_node()
	assert_equal(str(boss.get("id", "")), "boss", "boss_node() must return the type == boss node.")
	assert_equal(str(boss.get("type", "")), "boss", "boss_node() must carry type == boss.")

	assert_equal(view_model.cleared_count(), 1, "cleared_count() must echo the route's cleared count.")
	assert_equal(view_model.node_count(), 4, "node_count() must echo the route's total node count.")


# Story 14.6 (AC1 fail-closed): a null route yields empty current/boss dicts and honest zero counts — no crash.
func _render_fact_accessors_fail_closed_on_null_route() -> void:
	var view_model: RouteMapViewModel = RouteMapViewModel.from_route(null)
	assert_true(view_model.current_node().is_empty(), "A null route must project an empty current_node().")
	assert_true(view_model.boss_node().is_empty(), "A null route must project an empty boss_node().")
	assert_equal(view_model.cleared_count(), 0, "A null route must project cleared_count() == 0.")
	assert_equal(view_model.node_count(), 0, "A null route must project node_count() == 0.")


# Story 14.6 (AC1): a run parked ON the terminal boss reads the boss as BOTH the current node and the boss goal
# (the accessors read the projection honestly at the descent's end — no crash).
func _render_fact_accessors_on_terminal_boss_leaf() -> void:
	var route: RouteState = _diamond_route()
	route.current_node_id = "boss"
	var view_model: RouteMapViewModel = RouteMapViewModel.from_route(route)
	assert_equal(str(view_model.current_node().get("id", "")), "boss", "current_node() must be the boss when parked on it.")
	assert_equal(str(view_model.boss_node().get("id", "")), "boss", "boss_node() must still resolve the boss node.")


# Story 14.6 (AC3): the render-fact accessors return FRESH copies — mutating a returned dict never perturbs a
# fresh read (the no-live-handle discipline extends to the new accessors).
func _render_fact_accessors_return_fresh_copies_no_live_handle_leak() -> void:
	var view_model: RouteMapViewModel = RouteMapViewModel.from_route(_mid_descent_route())
	var current: Dictionary = view_model.current_node()
	current["type"] = "MUTATED"
	var boss: Dictionary = view_model.boss_node()
	boss["type"] = "MUTATED"
	assert_false(str(view_model.current_node().get("type", "")) == "MUTATED", "Mutating a returned current_node() must not perturb a fresh read.")
	assert_false(str(view_model.boss_node().get("type", "")) == "MUTATED", "Mutating a returned boss_node() must not perturb a fresh read.")


# Story 14.6 (AC3): the render-fact accessors added NO projection key — the pinned key-set constants are
# byte-identical (the accessors are computed reads, not new keys). Belt-and-suspenders over _exact_key_sets_pinned.
func _render_fact_accessors_add_no_projection_key() -> void:
	var top_keys: Array = RouteMapViewModel.DICTIONARY_KEYS.duplicate()
	top_keys.sort()
	assert_equal(top_keys, EXPECTED_KEYS, "The render-fact accessors must not change DICTIONARY_KEYS.")
	var node_keys: Array = RouteMapViewModel.NODE_KEYS.duplicate()
	node_keys.sort()
	assert_equal(node_keys, EXPECTED_NODE_KEYS, "The render-fact accessors must not change NODE_KEYS.")


# ⭐ Story 14.6 review (AC1 — cleared-current-node marker): in the live combat flow current_node_id stays ON the
# node until the next advance_to, so a just-cleared combat node is STILL the current node when the map re-renders.
# current_node() must carry is_cleared == true in that state — the exact render-fact the presenter's "✓ Cleared"
# marker on the "You are here" line consumes (so it reads "you stand here, done" not "fight this again"). The
# complement (an uncleared current node) must project is_cleared == false so the marker is correctly withheld.
func _current_node_carries_is_cleared_on_a_just_cleared_current_node() -> void:
	# Park ON the just-cleared depth-0 opener (the live-flow state before the next advance_to): current AND cleared.
	var route: RouteState = RouteState.new([
		RouteNode.new("start", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["left", "right"], []),
		RouteNode.new("left", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["boss"], []),
		RouteNode.new("right", RouteNode.TYPE_ELITE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["boss"], []),
		RouteNode.new("boss", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [], [])
	], "start", ["start"])
	var current: Dictionary = RouteMapViewModel.from_route(route).current_node()
	assert_equal(str(current.get("id", "")), "start", "current_node() must be the parked node.")
	assert_equal(current.get("is_current"), true, "The parked node must project is_current == true.")
	assert_equal(current.get("is_cleared"), true, "A just-cleared current node must project is_cleared == true (the '✓ Cleared' marker render-fact).")
	# The complement: an UNCLEARED current node ('left') projects is_cleared == false, so the marker is withheld.
	var uncleared: Dictionary = RouteMapViewModel.from_route(_mid_descent_route()).current_node()
	assert_equal(uncleared.get("is_cleared"), false, "An uncleared current node ('left') must project is_cleared == false (no marker).")


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


# The diamond route parked mid-descent: the opener ("start") cleared, parked on "left" (the is_current node),
# with the terminal boss still ahead — the post-opener state the enriched map renders (Story 14.6).
func _mid_descent_route() -> RouteState:
	var nodes: Array[RouteNode] = [
		RouteNode.new("start", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_CLEARED, ["left", "right"], []),
		RouteNode.new("left", RouteNode.TYPE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["boss"], [RouteNode.CLUE_SAFER_COMBAT]),
		RouteNode.new("right", RouteNode.TYPE_ELITE_COMBAT, 1, RouteNode.REVEAL_REVEALED, ["boss"], [RouteNode.CLUE_ELITE_PRESSURE]),
		RouteNode.new("boss", RouteNode.TYPE_BOSS, 2, RouteNode.REVEAL_REVEALED, [], [])
	]
	return RouteState.new(nodes, "left", ["start"])


func _nodes_by_id(data: Dictionary) -> Dictionary:
	var by_id: Dictionary = {}
	for node: Variant in data.get("nodes", []):
		by_id[String((node as Dictionary).get("id", ""))] = node
	return by_id
