extends "res://tests/unit/test_case.gd"

const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_board_created_serializes_stable_event_id()
	_unknown_event_id_round_trips_to_unknown_type()
	return result()


func _board_created_serializes_stable_event_id() -> void:
	var event: DomainEvent = DomainEvent.board_created(4, 5, 6)
	var serialized: Dictionary = event.to_dictionary()
	var restored: DomainEvent = DomainEvent.from_dictionary(serialized)

	assert_equal(serialized.get("event_id"), "board_created", "DomainEvent should serialize stable string ids.")
	assert_false(serialized.has("event_type"), "DomainEvent should not serialize enum integers.")
	assert_equal(restored.event_type, DomainEvent.Type.BOARD_CREATED, "DomainEvent should restore event type from stable id.")
	assert_equal(restored.sequence_id, 4, "DomainEvent should preserve sequence id.")


func _unknown_event_id_round_trips_to_unknown_type() -> void:
	var restored: DomainEvent = DomainEvent.from_dictionary({
		"event_id": "future_event",
		"sequence_id": 1,
		"payload": {}
	})

	assert_equal(restored.event_type, DomainEvent.Type.UNKNOWN, "Unknown event ids should not map to valid event types.")

