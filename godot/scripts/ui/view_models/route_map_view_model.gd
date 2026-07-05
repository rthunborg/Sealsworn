class_name RouteMapViewModel
extends RefCounted

# Story 11.3 (AC1/AC2, Contract gap G2 — the 11.1 appendix §5.2 / §16 G2, owned by 11.3) — the scene-free
# ROUTE / RUN-MAP view model. Today the run map would read RouteState / RouteNode DIRECTLY (there is NO dedicated
# route VIEW model). This is the thin fail-closed RefCounted route PROJECTION the route-map scene reads instead.
# It projects, from the pinned route reads:
#   - current_node_id, cleared_node_ids;
#   - the SELECTION-legal eligible_choice_ids() — the reveal-gated forward filter (known + REVEAL_REVEALED + NOT
#     cleared), NOT the looser available_choice_ids() (which surfaces HIDDEN linked nodes by design). The map
#     presents only SELECTABLE choices, so it MUST use eligible_choice_ids() (the RouteAdvanceCommand's own
#     selection gate) — mixing in available_choice_ids() would offer a hidden node the advance command rejects.
#   - per-node: type (RouteNode.TYPE_*), reveal_state (REVEAL_HIDDEN/REVEALED/CLEARED), depth,
#     outgoing_link_ids, clues (CLUE_*), plus the derived is_current / is_cleared / is_eligible flags the scene
#     renders (node TYPE via icon+label, reveal state via pattern+label — the appendix §5.4 non-color channels;
#     the scene MAPS these fields to visuals, it invents no vocabulary).
#
# ⭐ IT OWNS NO ROUTE TRUTH. The commit of a chosen node is the EXISTING route-advance command the flow submits
# (RouteAdvanceCommand via RunOrchestrator.advance_to) — the map PRESENTS choices + REPORTS the picked id; it
# does NOT mutate the route, does NOT advance, does NOT clear a node. It mints NO event, consumes NO RNG (ZERO
# randi/randf/RandomNumberGenerator), and leaks NO live handle into the domain (a FRESH plain-data dictionary
# each call — a mutation of a returned node/list never perturbs the source route). It is a RefCounted DTO — NOT a
# Control/Node/scene. It mirrors the RouteState reads through the RunEndOutcome / HeroSelectViewModel exact-key +
# fail-closed + no-live-handle discipline VERBATIM.
#
# ⭐ FAIL-CLOSED: a null route (or a route parked at a terminal leaf with no revealed uncleared links) projects a
# VALID surface (has_route == false / empty eligible list) — never a crash. The pinned key set is IDENTICAL for
# the present and absent projections.

const RouteState = preload("res://scripts/run/route_state.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")

# The EXACT top-level key set (pinned by test — the exact-key discipline). has_route gates whether the other
# fields are meaningful.
const DICTIONARY_KEYS: Array[String] = [
	"has_route",
	"current_node_id",
	"cleared_node_ids",
	"eligible_choice_ids",
	"nodes"
]

# The EXACT per-node key set (pinned by test).
const NODE_KEYS: Array[String] = [
	"id",
	"type",
	"depth",
	"reveal_state",
	"outgoing_link_ids",
	"clues",
	"is_current",
	"is_cleared",
	"is_eligible"
]

var has_route: bool = false
var current_node_id: String = ""
var cleared_node_ids: Array[String] = []
var eligible_choice_ids: Array[String] = []
var _nodes: Array[Dictionary] = []

# Build the route-map projection from the live route. A null route projects the fail-closed empty fact.
static func from_route(route: RouteState) -> RouteMapViewModel:
	var view_model: RouteMapViewModel = load("res://scripts/ui/view_models/route_map_view_model.gd").new()
	if route == null:
		return view_model

	view_model.has_route = true
	view_model.current_node_id = route.current_node_id
	view_model.cleared_node_ids = route.cleared_node_ids.duplicate()
	# THE load-bearing choice: the SELECTION-legal eligible set, NOT the looser available set.
	view_model.eligible_choice_ids = route.eligible_choice_ids()

	var cleared_lookup: Dictionary = {}
	for cleared_id: String in route.cleared_node_ids:
		cleared_lookup[cleared_id] = true
	var eligible_lookup: Dictionary = {}
	for eligible_id: String in view_model.eligible_choice_ids:
		eligible_lookup[eligible_id] = true

	view_model._nodes = []
	for node: RouteNode in route.nodes():
		view_model._nodes.append({
			"id": node.id,
			"type": String(node.type),
			"depth": node.depth,
			"reveal_state": String(node.reveal_state),
			"outgoing_link_ids": node.outgoing_link_ids.duplicate(),
			"clues": node.clues.duplicate(),
			"is_current": node.id == route.current_node_id,
			"is_cleared": cleared_lookup.has(node.id),
			"is_eligible": eligible_lookup.has(node.id)
		})
	return view_model


# Exact-key projection: plain String/int/bool/Array data only (no live RouteState / RouteNode handle leaks out).
# A FRESH dictionary each call (with deep-copied lists) so a mutation of the returned dict never perturbs this
# DTO or the route it read.
func to_dictionary() -> Dictionary:
	var node_copies: Array[Dictionary] = []
	for node: Dictionary in _nodes:
		node_copies.append(node.duplicate(true))
	return {
		"has_route": has_route,
		"current_node_id": current_node_id,
		"cleared_node_ids": cleared_node_ids.duplicate(),
		"eligible_choice_ids": eligible_choice_ids.duplicate(),
		"nodes": node_copies
	}
