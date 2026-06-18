extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const RouteNode = preload("res://scripts/run/route_node.gd")

func run() -> Dictionary:
	_valid_node_round_trips_through_real_json()
	_each_node_type_is_accepted()
	_unknown_node_type_is_rejected()
	_negative_depth_is_rejected()
	_unknown_reveal_state_is_rejected()
	_empty_and_whitespace_ids_are_rejected()
	_self_referential_link_is_rejected()
	_duplicate_links_are_rejected()
	_optional_clue_fields_default_empty_and_round_trip()
	_from_dictionary_returns_null_and_push_errors_on_failure()
	return result()


func _valid_node_round_trips_through_real_json() -> void:
	var node: RouteNode = RouteNode.new(
		"choice-a",
		RouteNode.TYPE_ELITE_COMBAT,
		3,
		RouteNode.REVEAL_REVEALED,
		["combat-1", "shop-1"],
		[String(RouteNode.CLUE_ELITE_PRESSURE), String(RouteNode.CLUE_STRONGER_REWARD)]
	)
	assert_true(node.validate().succeeded, "A well-formed route node should validate.")

	var json_data: Variant = JSON.parse_string(JSON.stringify(node.to_dictionary()))
	assert_true(json_data is Dictionary, "Route node should survive JSON stringify/parse.")
	var parse_result: ActionResult = RouteNode.try_from_dictionary(json_data)
	assert_true(parse_result.succeeded, "Route node should parse after a real JSON round-trip: %s" % parse_result.metadata)
	var parsed: RouteNode = parse_result.metadata.get("node") as RouteNode

	assert_equal(parsed.id, "choice-a", "Route node id must round-trip unchanged (stable id).")
	assert_equal(parsed.type, RouteNode.TYPE_ELITE_COMBAT, "Route node type must round-trip.")
	assert_equal(parsed.depth, 3, "Route node depth must round-trip.")
	assert_equal(parsed.reveal_state, RouteNode.REVEAL_REVEALED, "Route node reveal state must round-trip.")
	assert_equal(parsed.outgoing_link_ids, ["combat-1", "shop-1"], "Route node outgoing links must round-trip in order.")
	assert_equal(parsed.clues, ["elite_pressure", "stronger_reward"], "Route node clues must round-trip.")


func _each_node_type_is_accepted() -> void:
	for node_type: StringName in RouteNode.supported_types():
		var node: RouteNode = RouteNode.new("n", node_type, 0, RouteNode.REVEAL_HIDDEN)
		assert_true(node.validate().succeeded, "MVP node type %s should be accepted." % String(node_type))
	# Spot-check the exact MVP set is present.
	assert_true(RouteNode.supported_types().has(RouteNode.TYPE_BOSS), "Boss node type must be in the MVP vocabulary.")
	assert_true(RouteNode.supported_types().has(RouteNode.TYPE_GAMBLING), "Gambling node type must be in the MVP vocabulary.")
	assert_equal(RouteNode.supported_types().size(), 8, "The MVP node-type vocabulary should hold exactly 8 types.")


func _unknown_node_type_is_rejected() -> void:
	var node: RouteNode = RouteNode.new("n", &"treasure_vault", 0, RouteNode.REVEAL_HIDDEN)
	var validation: ActionResult = node.validate()
	assert_true(validation.is_error(), "An unknown node type should be rejected.")
	assert_equal(validation.error_code, &"invalid_node_type", "Unknown node type should use a stable code.")
	assert_equal(validation.metadata.get("field"), "type", "Unknown node type should name the field.")


func _negative_depth_is_rejected() -> void:
	var node: RouteNode = RouteNode.new("n", RouteNode.TYPE_COMBAT, -1, RouteNode.REVEAL_HIDDEN)
	var validation: ActionResult = node.validate()
	assert_true(validation.is_error(), "A negative depth should be rejected.")
	assert_equal(validation.error_code, &"invalid_node_depth", "Negative depth should use a stable code.")
	assert_equal(validation.metadata.get("field"), "depth", "Negative depth should name the field.")


func _unknown_reveal_state_is_rejected() -> void:
	var node: RouteNode = RouteNode.new("n", RouteNode.TYPE_COMBAT, 0, &"peeked")
	var validation: ActionResult = node.validate()
	assert_true(validation.is_error(), "An unknown reveal state should be rejected.")
	assert_equal(validation.error_code, &"invalid_node_reveal_state", "Unknown reveal state should use a stable code.")
	assert_equal(validation.metadata.get("field"), "reveal_state", "Unknown reveal state should name the field.")


func _empty_and_whitespace_ids_are_rejected() -> void:
	var empty_node: RouteNode = RouteNode.new("", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN)
	var empty_validation: ActionResult = empty_node.validate()
	assert_true(empty_validation.is_error(), "An empty node id should be rejected.")
	assert_equal(empty_validation.error_code, &"invalid_node_id", "Empty node id should use a stable code.")
	assert_equal(empty_validation.metadata.get("field"), "id", "Empty node id should name the field.")

	# Leading/trailing whitespace.
	var padded_node: RouteNode = RouteNode.new(" start ", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN)
	assert_true(padded_node.validate().is_error(), "A padded node id should be rejected.")

	# Internal whitespace.
	var spaced_node: RouteNode = RouteNode.new("choice a", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN)
	assert_true(spaced_node.validate().is_error(), "A node id containing whitespace should be rejected.")


func _self_referential_link_is_rejected() -> void:
	var node: RouteNode = RouteNode.new("loop", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN, ["loop"])
	var validation: ActionResult = node.validate()
	assert_true(validation.is_error(), "A self-referential link should be rejected.")
	assert_equal(validation.error_code, &"self_referential_node_link", "Self-link should use a stable code.")
	assert_equal(validation.metadata.get("field"), "outgoing_link_ids", "Self-link should name the field.")


func _duplicate_links_are_rejected() -> void:
	var node: RouteNode = RouteNode.new("a", RouteNode.TYPE_COMBAT, 0, RouteNode.REVEAL_HIDDEN, ["b", "b"])
	var validation: ActionResult = node.validate()
	assert_true(validation.is_error(), "Duplicate outgoing links should be rejected.")
	assert_equal(validation.error_code, &"duplicate_node_link", "Duplicate link should use a stable code.")
	assert_equal(validation.metadata.get("field"), "outgoing_link_ids", "Duplicate link should name the field.")


func _optional_clue_fields_default_empty_and_round_trip() -> void:
	var node: RouteNode = RouteNode.new("plain", RouteNode.TYPE_SHOP, 1, RouteNode.REVEAL_HIDDEN)
	assert_equal(node.clues, [], "Clues default to empty (optional field).")
	assert_equal(node.outgoing_link_ids, [], "Outgoing links default to empty.")
	assert_true(node.validate().succeeded, "A node with no clues/links should validate.")

	# Parse a dict that omits clues/links entirely (they are optional).
	var parse_result: ActionResult = RouteNode.try_from_dictionary({
		"id": "plain",
		"type": "shop",
		"depth": 1,
		"reveal_state": "hidden"
	})
	assert_true(parse_result.succeeded, "A node dict omitting optional fields should parse.")
	var parsed: RouteNode = parse_result.metadata.get("node") as RouteNode
	assert_equal(parsed.clues, [], "Omitted clues should default to empty on parse.")
	assert_equal(parsed.outgoing_link_ids, [], "Omitted links should default to empty on parse.")


func _from_dictionary_returns_null_and_push_errors_on_failure() -> void:
	var bad_dict: Dictionary = {
		"id": "x",
		"type": "not_a_real_type",
		"depth": 0,
		"reveal_state": "hidden"
	}
	# The strict path returns a structured error (no push_error noise)...
	var strict: ActionResult = RouteNode.try_from_dictionary(bad_dict)
	assert_true(strict.is_error(), "try_from_dictionary should return a structured error on a bad type.")
	assert_equal(strict.error_code, &"invalid_node_type", "Strict parse should surface the stable error code.")
	# ...and the lenient convenience wrapper returns null on failure (it push_errors, by design,
	# mirroring CombatOutcomeState.from_dictionary; the runner counts assertion failures, not stderr).
	var node: RouteNode = RouteNode.from_dictionary(bad_dict)
	assert_true(node == null, "from_dictionary should return null on a validation failure.")
