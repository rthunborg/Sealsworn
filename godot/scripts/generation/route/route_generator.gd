class_name RouteGenerator
extends RefCounted

# Seeded, deterministic, scene-free route GENERATOR (Story 4.2). From a non-negative root seed it
# draws the `map` RNG stream EXCLUSIVELY to build an 8-12-non-boss-node forward-only DAG of RouteNodes
# (Story 4.1 type) plus exactly one terminal boss placeholder, assembled into a RouteState (4.1 type)
# with deterministic node ids, types, forward edges, reveal-state, and tradeoff clues. It is a plain
# typed RefCounted service (like LevelGenerator / ManualSeedLoader) — NOT a Node, NOT an autoload. It
# draws the seed and builds an in-memory RouteState; it persists nothing, composes no RunSnapshot,
# emits no DomainEvent, and mutates no external state.
#
# WHAT THIS IS NOT (boundaries — the single biggest risk for this story):
#   - NOT the run-progression model (RunState/RouteState/RouteNode already exist, Story 4.1).
#   - NOT route CHOICE / forward commitment (RouteAdvanceCommand is Story 4.3). It builds the graph
#     and proves the forward-only EDGE shape; it does NOT build the commit command or the choice filter.
#   - NOT node entry / level-request creation / GenerationResult(level) consumption (Story 4.4). It does
#     NOT call LevelGenerator / ManualSeedLoader, does NOT create a level GenerationRequest.
#   - NOT per-node-type RESOLUTION behavior (Story 4.5). It ASSIGNS node types only.
#   - NOT the run-start command / `run_started` emission. It is a generator, not a command.
#
# ============================================================================================
# FIXED DRAW ORDER (the canonical contract — pinned by the route seed-regression fingerprints).
# Reordering or INSERTING a `map` draw silently drifts EVERY approved-seed route fingerprint, exactly
# like the Epic-3 layout draw order. Every count draw FIRES UNCONDITIONALLY even when its band
# collapses to a single value, so the `map` stream advances identically across seeds. The draws are,
# in order, for a route of `column_count` interior+start columns (depth 0..boss_depth):
#   (1) non-boss node count in [MIN_NON_BOSS_NODES, MAX_NON_BOSS_NODES]  -- FIRST, unconditional.
#   (2) per interior column c in 1..(boss_depth-1), in ascending depth order:
#         (2a) the column width in [1, 2] (clamped so the remaining columns can still reach the exact
#              non-boss target; the draw STILL FIRES even when the clamp forces a single legal value).
#   (3) per non-boss node, in ascending (depth, index) order:
#         (3a) a node-type selector draw (depth-banded weighting; see _draw_node_type) -- fires for
#              EVERY non-boss node EXCEPT the depth-0 start, which is always `combat` and draws NO type
#              selector (so the start node consumes only the (3b) clue draw, a single `map` draw).
#         (3b) a clue selector draw (deterministic clue tags; see _assign_clues).
#   (4) per node in column c (c in 0..boss_depth-1), in ascending (depth, index) order:
#         (4a) a forward fan-out selector draw choosing which next-column node(s) it links to.
# Node ids are NOT drawn from `map` (they are derived from (depth, index) so they are reproducible and
# human-debuggable). Reveal-state is NOT drawn (depth-0 + depth-1 are REVEALED, deeper is HIDDEN).
# ============================================================================================
#
# DETERMINISM: route = pure function of (root_seed). Same seed -> byte-identical RouteState AND
# identical GenerationResult. This is the foundation of replay + the route fingerprints. v0 generation
# is valid BY CONSTRUCTION (a forward-only DAG with a bounded node count is always buildable), so there
# is NO bounded-retry loop — there is no fail-prone placement step to re-roll. Both the structural
# RouteState.validate() (4.1) AND the NEW forward-only edge pass (RouteValidator) run on every built
# route before success; a generated route that fails EITHER is a generator bug surfaced as a structured
# error, never a shipped route.

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RngStreamSet = preload("res://scripts/core/state/rng_stream_set.gd")
const GenerationResult = preload("res://scripts/generation/level/generation_result.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")
const RouteState = preload("res://scripts/run/route_state.gd")
const RouteValidator = preload("res://scripts/generation/route/route_validator.gd")

# 8-12 NON-BOSS nodes (boss excluded), per FR30 / GDD line 203 ("8-12 nodes before the boss" + 1 boss).
const MIN_NON_BOSS_NODES: int = 8
const MAX_NON_BOSS_NODES: int = 12

# Column-width band for interior depths (start column is always width 1; boss column is always width 1).
const MIN_COLUMN_WIDTH: int = 1
const MAX_COLUMN_WIDTH: int = 2

# v0 deterministic interior-column count. With start (1) + boss (1) + INTERIOR_COLUMN_COUNT interior
# columns each 1..2 wide, the interior columns supply (non_boss_target - 1) nodes, i.e. [7, 11]. With
# INTERIOR_COLUMN_COUNT = 6 the interior range is [6, 12] which fully spans [7, 11], AND because the
# MINIMUM interior demand (7) exceeds the column count (6), AT LEAST ONE interior column is ALWAYS width
# 2 for every target in [8, 12]. That guaranteed width-2 column guarantees AT LEAST ONE branch point
# (AC4): either a source draws the "link both" selector, or the deterministic reachability repair
# attaches the un-linked second node to a source that already has a link — either way a node ends up with
# >= 2 outgoing links. (Verified exhaustively over every target and every draw outcome that all four
# invariants — forward-only, full reachability, a branch point, a single terminal boss — hold for 6 but
# NOT for 7, where target=8 collapses to an all-linear route with no branch point.)
const INTERIOR_COLUMN_COUNT: int = 6

# The payload key carrying the serializable RouteState dict (survives a JSON round-trip; the live
# RefCounted RouteState is rehydrated by route_from_result). Mirrors how the level GenerationResult
# payload carries the board SNAPSHOT dict, not the live BoardState.
const PAYLOAD_ROUTE_KEY := "route_state"
const PAYLOAD_NODE_COUNT_KEY := "node_count"


# Public entry. Returns a GenerationResult: on success, payload[PAYLOAD_ROUTE_KEY] is the serializable
# RouteState dict and payload[PAYLOAD_NODE_COUNT_KEY] is the non-boss node count ([8, 12]); diagnostics
# carry compact phase/seed/counts. On failure, a structured PHASE_ROUTE error with seed + reason +
# compact diagnostics (NEVER a full graph dump). Use route_from_result() to rehydrate the RouteState.
static func generate(root_seed: int) -> GenerationResult:
	var seed_text: String = str(root_seed)

	if root_seed < 0:
		return GenerationResult.error(
			GenerationResult.PHASE_ROUTE,
			&"invalid_route_seed",
			&"root_seed_must_be_non_negative",
			seed_text,
			{"phase": String(GenerationResult.PHASE_ROUTE)}
		)

	var streams: RngStreamSet = RngStreamSet.new(root_seed)
	var build_result: ActionResult = _build_route(streams)
	if build_result.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_ROUTE,
			build_result.error_code,
			&"route_build_failed",
			seed_text,
			_diagnostics_with_phase(build_result.metadata)
		)

	var route: RouteState = build_result.metadata.get("route") as RouteState
	var non_boss_count: int = int(build_result.metadata.get("non_boss_count"))

	# Validate-then-reject: BOTH the 4.1 structural pass AND the new forward-only edge pass. A generated
	# route that fails either is a generator bug, surfaced as a structured error (not a shipped route).
	var structural: ActionResult = route.validate()
	if structural.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_ROUTE,
			structural.error_code,
			&"route_structural_validation_failed",
			seed_text,
			_diagnostics_with_phase(structural.metadata)
		)

	var forward: ActionResult = RouteValidator.validate_forward_only(route)
	if forward.is_error():
		return GenerationResult.error(
			GenerationResult.PHASE_ROUTE,
			forward.error_code,
			&"route_forward_only_validation_failed",
			seed_text,
			_diagnostics_with_phase(forward.metadata)
		)

	var payload: Dictionary = {
		PAYLOAD_ROUTE_KEY: route.to_dictionary(),
		PAYLOAD_NODE_COUNT_KEY: non_boss_count
	}
	return GenerationResult.ok(payload, {
		"phase": String(GenerationResult.PHASE_ROUTE),
		"seed": seed_text,
		"node_count": non_boss_count,
		"boss_depth": _boss_depth(route),
		"total_node_count": route.node_count()
	})


# Rehydrate the live RouteState from a successful route GenerationResult (mirrors how a level consumer
# rebuilds a BoardState from the serializable board snapshot). Returns null on an error/empty result.
static func route_from_result(generation_result: GenerationResult) -> RouteState:
	if generation_result == null or generation_result.is_error():
		return null
	var route_dict: Variant = generation_result.payload.get(PAYLOAD_ROUTE_KEY)
	if not route_dict is Dictionary:
		return null
	var parse_result: ActionResult = RouteState.try_from_dictionary(route_dict)
	if parse_result.is_error():
		return null
	return parse_result.metadata.get("route") as RouteState


# Compact deterministic fingerprint of a built RouteState: a PURE function of the RouteState (no RNG,
# no mutation). Format: `count|<id:type@depth ...>|<src>->><dst,...> ...|boss<depth>` over the ORDERED
# node list. Stable across regenerations of the same seed (node order is deterministic by construction).
static func fingerprint(route: RouteState) -> String:
	var nodes: Array[RouteNode] = route.nodes()
	var non_boss: int = 0
	var node_parts: Array[String] = []
	var edge_parts: Array[String] = []
	var boss_depth: int = -1
	for node: RouteNode in nodes:
		if node.type != RouteNode.TYPE_BOSS:
			non_boss += 1
		else:
			boss_depth = node.depth
		node_parts.append("%s:%s@%d" % [node.id, String(node.type), node.depth])
		var links: Array[String] = node.outgoing_link_ids.duplicate()
		edge_parts.append("%s>%s" % [node.id, ",".join(links)])
	return "%d|%s|%s|boss%d" % [
		non_boss,
		" ".join(node_parts),
		" ".join(edge_parts),
		boss_depth
	]


# ---- internal build ------------------------------------------------------------------------------

# Build the forward-only DAG. Returns an ActionResult carrying {route, non_boss_count} on success, or a
# structured error on an internal draw failure (e.g. an unexpected RNG range error — should not happen
# for a non-negative seed, but surfaced rather than swallowed).
static func _build_route(streams: RngStreamSet) -> ActionResult:
	# (1) non-boss node count -- FIRST, unconditional.
	var count_draw: ActionResult = _draw_map_int(streams, MIN_NON_BOSS_NODES, MAX_NON_BOSS_NODES, {"step": "non_boss_count"})
	if count_draw.is_error():
		return count_draw
	var non_boss_target: int = int(count_draw.metadata.get("value"))

	# (2) interior column widths. Columns: depth 0 = start (width 1), depths 1..INTERIOR_COLUMN_COUNT =
	# interior, depth boss_depth = boss (width 1). The start node counts toward the non-boss target, so
	# the interior columns must supply (non_boss_target - 1) nodes. Each interior column draws a width in
	# [1, 2], clamped so the REMAINING interior columns can still reach EXACTLY the residual target. The
	# draw fires every column even when the clamp forces one legal value (collapse discipline).
	var interior_target: int = non_boss_target - 1
	var column_widths: Array[int] = [1]  # depth 0 (start) is always a single node.
	var remaining: int = interior_target
	for column_index: int in range(INTERIOR_COLUMN_COUNT):
		var columns_left_after_this: int = INTERIOR_COLUMN_COUNT - column_index - 1
		# Lower bound: leave at most MAX_COLUMN_WIDTH per remaining column for the rest.
		var min_width: int = maxi(MIN_COLUMN_WIDTH, remaining - columns_left_after_this * MAX_COLUMN_WIDTH)
		# Upper bound: take at most MAX_COLUMN_WIDTH, and leave at least MIN_COLUMN_WIDTH per remaining column.
		var max_width: int = mini(MAX_COLUMN_WIDTH, remaining - columns_left_after_this * MIN_COLUMN_WIDTH)
		if min_width > max_width:
			# Defensive: the band/column-count math guarantees min_width <= max_width for any target in
			# [MIN_NON_BOSS_NODES, MAX_NON_BOSS_NODES]. Surface a structured error rather than draw badly.
			return ActionResult.error(&"route_column_width_unsatisfiable", {
				"step": "column_width",
				"column": column_index + 1,
				"remaining": remaining
			})
		var width_draw: ActionResult = _draw_map_int(streams, min_width, max_width, {"step": "column_width", "column": column_index + 1})
		if width_draw.is_error():
			return width_draw
		var width: int = int(width_draw.metadata.get("value"))
		column_widths.append(width)
		remaining -= width
	# The boss column (always 1 node) is appended after the interior columns.
	var boss_depth: int = column_widths.size()  # depths 0..(size-1) are non-boss; boss sits at `size`.

	# (2->topology) Build the node grid: column_nodes[depth] = Array[RouteNode] in stable index order.
	var column_nodes: Array = []  # Array[Array[RouteNode]]
	var ordered_nodes: Array[RouteNode] = []
	for depth: int in range(column_widths.size()):
		var width: int = column_widths[depth]
		var this_column: Array[RouteNode] = []
		for index: int in range(width):
			var node: RouteNode = RouteNode.new(
				_mint_node_id(depth, index),
				RouteNode.TYPE_COMBAT,  # placeholder; (3a) assigns the real type below.
				depth,
				_reveal_for_depth(depth),
				[],
				[]
			)
			this_column.append(node)
			ordered_nodes.append(node)
		column_nodes.append(this_column)
	# Append the single boss node at boss_depth.
	var boss_node: RouteNode = RouteNode.new(
		_mint_node_id(boss_depth, 0),
		RouteNode.TYPE_BOSS,
		boss_depth,
		_reveal_for_depth(boss_depth),
		[],
		[]
	)
	column_nodes.append([boss_node] as Array[RouteNode])
	ordered_nodes.append(boss_node)

	# (3) per NON-BOSS node, in ascending (depth, index) order: (3a) type draw, then (3b) clue draw.
	# The boss node keeps TYPE_BOSS and draws no type/clue selector (its clues stay empty).
	for node: RouteNode in ordered_nodes:
		if node.type == RouteNode.TYPE_BOSS:
			continue
		var type_draw: ActionResult = _draw_node_type(streams, node.depth, boss_depth)
		if type_draw.is_error():
			return type_draw
		node.type = StringName(String(type_draw.metadata.get("value")))
		var clue_result: ActionResult = _assign_clues(streams, node)
		if clue_result.is_error():
			return clue_result
		node.clues = clue_result.metadata.get("clues")

	# (4) forward edges: each node in column c links forward to one or two nodes in column c+1. The fan-out
	# selector draw chooses the target subset deterministically. The LAST non-boss column links every node
	# to the boss. This guarantees: forward-only edges, full reachability (every node has >= 1 incoming
	# from c-1 because each next-column node is covered, and >= 1 outgoing to c+1), and >= 1 branch point.
	var edge_result: ActionResult = _wire_forward_edges(streams, column_nodes)
	if edge_result.is_error():
		return edge_result

	var route: RouteState = RouteState.new(ordered_nodes, ordered_nodes[0].id, [])
	return ActionResult.ok([], {"route": route, "non_boss_count": non_boss_target})


# Wire forward edges between consecutive columns. For each node in column c, draw a fan-out selector that
# picks 1 or 2 targets in column c+1. To GUARANTEE every node in column c+1 has at least one incoming edge
# (reachability — no dangling/orphan node), after the per-source draws we deterministically attach any
# next-column node that received no incoming edge to the FIRST node of column c. This is a deterministic
# repair (NOT an RNG draw), so it does not perturb the fixed draw order.
static func _wire_forward_edges(streams: RngStreamSet, column_nodes: Array) -> ActionResult:
	for column_index: int in range(column_nodes.size() - 1):
		var current_column: Array = column_nodes[column_index]
		var next_column: Array = column_nodes[column_index + 1]
		var next_width: int = next_column.size()
		var incoming_count: Array[int] = []
		for _i: int in range(next_width):
			incoming_count.append(0)

		for source_node: RouteNode in current_column:
			var links: Array[String] = []
			if next_width == 1:
				# Only one legal target; the selector draw STILL FIRES (collapse discipline) for stream
				# stability, but the result is always the single next node.
				var single_draw: ActionResult = _draw_map_int(streams, 0, 0, {"step": "fan_out", "depth": source_node.depth})
				if single_draw.is_error():
					return single_draw
				links.append((next_column[0] as RouteNode).id)
				incoming_count[0] += 1
			else:
				# next_width == 2. Selector in [0, 2]: 0 -> link only target 0; 1 -> link only target 1;
				# 2 -> link BOTH (a branch point). Deterministic from the `map` draw.
				var sel_draw: ActionResult = _draw_map_int(streams, 0, 2, {"step": "fan_out", "depth": source_node.depth})
				if sel_draw.is_error():
					return sel_draw
				var selector: int = int(sel_draw.metadata.get("value"))
				if selector == 0:
					links.append((next_column[0] as RouteNode).id)
					incoming_count[0] += 1
				elif selector == 1:
					links.append((next_column[1] as RouteNode).id)
					incoming_count[1] += 1
				else:
					links.append((next_column[0] as RouteNode).id)
					links.append((next_column[1] as RouteNode).id)
					incoming_count[0] += 1
					incoming_count[1] += 1
			source_node.outgoing_link_ids = links

		# Deterministic reachability repair: any next-column node with zero incoming edges is attached to
		# the first node of the current column (forward edge, lower->higher depth). No RNG draw here.
		for target_index: int in range(next_width):
			if incoming_count[target_index] == 0:
				var first_source: RouteNode = current_column[0]
				var orphan_id: String = (next_column[target_index] as RouteNode).id
				if not first_source.outgoing_link_ids.has(orphan_id):
					var repaired: Array[String] = first_source.outgoing_link_ids.duplicate()
					repaired.append(orphan_id)
					first_source.outgoing_link_ids = repaired
	return ActionResult.ok()


# Deterministic depth-banded node-type weighting (v0). The pacing bias from the GDD (early = combat-heavy;
# mid = shops/reforge/gambling/first elites; late = elite/boss prep) informs a SIMPLE depth-banded weight
# table — exact node frequency is explicitly deferred (GDD line 708, Epic 10 tuning). Boss is NEVER drawn
# here (only the terminal node is boss). The draw fires once per non-boss node EXCEPT the depth-0 start
# (always `combat`, short-circuited below with NO draw), so step 3a is skipped for depth 0.
static func _draw_node_type(streams: RngStreamSet, depth: int, boss_depth: int) -> ActionResult:
	# The start node (depth 0) is always a plain combat node (a fair, legible run opener).
	if depth == 0:
		return ActionResult.ok([], {"value": String(RouteNode.TYPE_COMBAT)})

	var weights: Array = _type_weights_for_band(depth, boss_depth)
	var total: int = 0
	for entry: Array in weights:
		total += int(entry[1])
	var pick_draw: ActionResult = _draw_map_int(streams, 0, total - 1, {"step": "node_type", "depth": depth})
	if pick_draw.is_error():
		return pick_draw
	var roll: int = int(pick_draw.metadata.get("value"))
	var cursor: int = 0
	for entry: Array in weights:
		cursor += int(entry[1])
		if roll < cursor:
			return ActionResult.ok([], {"value": String(entry[0] as StringName)})
	# Unreachable (roll < total always lands inside a band); fall back to combat defensively.
	return ActionResult.ok([], {"value": String(RouteNode.TYPE_COMBAT)})


# Depth-banded weighted type table (weights are small ints; order is FIXED so the cumulative selection is
# deterministic). Three bands: early (first third), mid (middle), late (final third before the boss).
static func _type_weights_for_band(depth: int, boss_depth: int) -> Array:
	# boss_depth is the number of non-boss columns (depths 0..boss_depth-1). Use the LAST non-boss depth
	# (boss_depth - 1) as the band denominator.
	var last_non_boss_depth: int = maxi(1, boss_depth - 1)
	var ratio: float = float(depth) / float(last_non_boss_depth)
	if ratio <= 0.34:
		# Early: combat-heavy, the first elite is rare, light support.
		return [
			[RouteNode.TYPE_COMBAT, 6],
			[RouteNode.TYPE_EVENT, 2],
			[RouteNode.TYPE_SHOP, 1],
			[RouteNode.TYPE_ELITE_COMBAT, 1]
		]
	if ratio <= 0.67:
		# Mid: shops/reforge/gambling + first real elite pressure, combat still common.
		return [
			[RouteNode.TYPE_COMBAT, 4],
			[RouteNode.TYPE_SHOP, 3],
			[RouteNode.TYPE_REFORGE, 2],
			[RouteNode.TYPE_GAMBLING, 2],
			[RouteNode.TYPE_ELITE_COMBAT, 2],
			[RouteNode.TYPE_EVENT, 1],
			[RouteNode.TYPE_SECRET, 1]
		]
	# Late: elite/boss prep — elites dominate, a recovery shop/reforge for the boss run-up.
	return [
		[RouteNode.TYPE_ELITE_COMBAT, 5],
		[RouteNode.TYPE_COMBAT, 3],
		[RouteNode.TYPE_REFORGE, 2],
		[RouteNode.TYPE_SHOP, 2],
		[RouteNode.TYPE_SECRET, 1]
	]


# Deterministically populate a node's clues from (type, depth, one `map` draw). Uses the canonical
# RouteNode.CLUE_* tags. AC4 requires only that SOME revealed choices carry clues and the set is seed-
# stable — this is a defensible v0, NOT a clue economy (exact weighting is later tuning, GDD line 708).
# Fires one `map` draw per non-boss node (fixed draw order step 3b) so the stream advances stably.
static func _assign_clues(streams: RngStreamSet, node: RouteNode) -> ActionResult:
	var clues: Array[String] = []
	# Type-driven base clue (deterministic, no draw).
	match node.type:
		RouteNode.TYPE_COMBAT:
			clues.append(String(RouteNode.CLUE_SAFER_COMBAT))
		RouteNode.TYPE_ELITE_COMBAT:
			clues.append(String(RouteNode.CLUE_ELITE_PRESSURE))
		RouteNode.TYPE_SHOP, RouteNode.TYPE_REFORGE:
			clues.append(String(RouteNode.CLUE_RECOVERY))
		RouteNode.TYPE_GAMBLING:
			clues.append(String(RouteNode.CLUE_UNKNOWN_RISK))
		RouteNode.TYPE_SECRET:
			clues.append(String(RouteNode.CLUE_MYSTERY))
		RouteNode.TYPE_EVENT:
			clues.append(String(RouteNode.CLUE_UNKNOWN_RISK))
		_:
			clues.append(String(RouteNode.CLUE_SAFER_COMBAT))

	# One `map` draw adds an optional secondary tradeoff clue, deterministically. Hidden (deeper) nodes
	# lean toward mystery/unknown-risk; combat/elite nodes may advertise a stronger reward.
	var extra_draw: ActionResult = _draw_map_int(streams, 0, 3, {"step": "clue", "depth": node.depth})
	if extra_draw.is_error():
		return extra_draw
	var roll: int = int(extra_draw.metadata.get("value"))
	var secondary: String = ""
	if node.reveal_state == RouteNode.REVEAL_HIDDEN:
		secondary = String(RouteNode.CLUE_MYSTERY) if roll < 2 else String(RouteNode.CLUE_UNKNOWN_RISK)
	elif node.type == RouteNode.TYPE_ELITE_COMBAT or node.type == RouteNode.TYPE_GAMBLING:
		secondary = String(RouteNode.CLUE_STRONGER_REWARD) if roll < 2 else ""
	elif node.type == RouteNode.TYPE_COMBAT and roll < 1:
		secondary = String(RouteNode.CLUE_STRONGER_REWARD)
	if not secondary.is_empty() and not clues.has(secondary):
		clues.append(secondary)

	return ActionResult.ok([], {"clues": clues})


# Mint a stable node id from (depth, index) — NOT from a `map` draw, so it is reproducible and human-
# debuggable. Satisfies RouteNode._is_valid_node_id (non-empty, NO whitespace; hyphens allowed).
static func _mint_node_id(depth: int, index: int) -> String:
	return "node-%d-%d" % [depth, index]


# Reveal-state by depth (orthogonal to type/depth per the 4.1 rule). Depth 0 (start) and depth 1 (the
# first visible choice tier) are REVEALED; deeper not-yet-reachable nodes default HIDDEN. Nothing is
# marked CLEARED at generation time (a fresh route has cleared nothing).
static func _reveal_for_depth(depth: int) -> StringName:
	if depth <= 1:
		return RouteNode.REVEAL_REVEALED
	return RouteNode.REVEAL_HIDDEN


# The single FUNNEL for every route-affecting draw: routes EXCLUSIVELY through STREAM_MAP. Mirrors
# GenerationRequest.draw_layout_int funneling every layout draw through STREAM_LEVEL. Never STREAM_LEVEL,
# never another stream, never global randi()/randf(), never a bare RandomNumberGenerator. The single-
# stream contract is enforced here in ONE place and is unit-testable.
static func _draw_map_int(streams: RngStreamSet, minimum: int, maximum: int, consumer_context: Dictionary = {}) -> ActionResult:
	var context: Dictionary = consumer_context.duplicate(true)
	context["system"] = "route_generation"
	return streams.rand_int(RngStreamSet.STREAM_MAP, minimum, maximum, context)


static func _boss_depth(route: RouteState) -> int:
	for node: RouteNode in route.nodes():
		if node.type == RouteNode.TYPE_BOSS:
			return node.depth
	return -1


static func _diagnostics_with_phase(metadata: Dictionary) -> Dictionary:
	var diagnostics: Dictionary = metadata.duplicate(true)
	diagnostics["phase"] = String(GenerationResult.PHASE_ROUTE)
	return diagnostics
