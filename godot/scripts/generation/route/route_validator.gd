class_name RouteValidator
extends RefCounted

# Forward-only route-edge validation (Story 4.2) — the EDGE-shape guarantee that Story 4.1 explicitly
# deferred to this story. RouteState.validate() (4.1) checks STRUCTURAL integrity (per-node validity,
# duplicate ids, dangling links, unknown current node, duplicate/unknown cleared ids) but NOT the
# forward-only/no-backtracking edge shape. This validator REJECTS any non-forward edge.
#
# FORWARD-ONLY INVARIANT (AC3): an edge is forward iff target.depth > source.depth (STRICTLY greater).
# The generator must emit only forward edges; this pass proves no equal-or-lower-depth edge exists. This
# is BOTH "every visible choice leads forward" AND "no route edge allows backtracking to a cleared node"
# (the same monotonic-depth invariant from two directions): because every edge strictly increases depth,
# a forward-only graph can never link back to a lower/equal depth — and cleared nodes are necessarily at
# lower depths than the current node once progress is made, so no edge can target a cleared node.
#
# It is a PURE READ (validate-then-reject, no coercion, no mutation, no RNG) — same purity contract as a
# snapshot or the LevelValidator. On violation it returns a structured ActionResult.error with a stable
# lower_snake code + COMPACT diagnostics ({node_id, link, source_depth, target_depth} — ids/counts only,
# NEVER a full graph dump). It is kept OUT of RouteState.validate() so 4.1's structural contract is
# unchanged (the 23-key / no-surprise discipline is untouched).
#
# NOTE on layering (deferred-work overlap): this proves the GRAPH cannot contain a backtracking edge.
# The run-time choice-eligibility filter (reveal gating + excluding already-cleared ids AT SELECTION
# time) is Story 4.3's choose-and-commit RouteAdvanceCommand — NOT built here, and this validator does
# NOT touch RouteState.available_choice_ids().

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")

const ERROR_NON_FORWARD_EDGE := &"non_forward_route_edge"
const ERROR_DANGLING_EDGE := &"dangling_route_link"


# Reject any non-forward edge. Returns ActionResult.ok() when every outgoing link of every node resolves
# to a STRICTLY-greater-depth node. A link to an unknown node is reported as a dangling link (the same
# stable code RouteState.validate uses) so the diagnostics stay consistent if this pass runs standalone.
static func validate_forward_only(route: RouteState) -> ActionResult:
	for node: RouteNode in route.nodes():
		for link_id: String in node.outgoing_link_ids:
			var target: RouteNode = route.node_by_id(link_id)
			if target == null:
				return ActionResult.error(ERROR_DANGLING_EDGE, {
					"field": "outgoing_link_ids",
					"node_id": node.id,
					"link": link_id
				})
			if target.depth <= node.depth:
				return ActionResult.error(ERROR_NON_FORWARD_EDGE, {
					"field": "outgoing_link_ids",
					"node_id": node.id,
					"link": link_id,
					"source_depth": node.depth,
					"target_depth": target.depth
				})
	return ActionResult.ok()
