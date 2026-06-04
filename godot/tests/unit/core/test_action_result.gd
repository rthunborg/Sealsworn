extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	var event: DomainEvent = DomainEvent.board_created(1, 3, 2)
	var ok_result: ActionResult = ActionResult.ok([event], {"source": "test"})

	assert_true(ok_result.succeeded, "ActionResult.ok should succeed.")
	assert_true(ok_result.has_events(), "ActionResult.ok should retain typed events.")
	assert_equal(ok_result.events[0].event_type, DomainEvent.Type.BOARD_CREATED, "ActionResult.ok should preserve event type.")
	assert_equal(ok_result.metadata.get("source"), "test", "ActionResult.ok should preserve metadata.")

	var error_result: ActionResult = ActionResult.error(&"invalid_action")
	assert_false(error_result.succeeded, "ActionResult.error should not succeed.")
	assert_true(error_result.is_error(), "ActionResult.error should report an error.")
	assert_equal(error_result.error_code, &"invalid_action", "ActionResult.error should preserve the error code.")

	var invalid_event_result: ActionResult = ActionResult.ok(["not_an_event"])
	assert_true(invalid_event_result.is_error(), "ActionResult.ok should reject non-domain event values.")
	assert_equal(invalid_event_result.error_code, &"invalid_result_event", "ActionResult.ok should explain invalid event values.")

	return result()
