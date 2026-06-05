extends "res://tests/unit/test_case.gd"

const ActionResult = preload("res://scripts/core/results/action_result.gd")
const DomainEvent = preload("res://scripts/core/events/domain_event.gd")

func run() -> Dictionary:
	_success_results_preserve_events_and_metadata_contract()
	_error_results_preserve_stable_machine_contract()
	_ok_rejects_invalid_event_values_without_partial_events()
	_reason_codes_remain_machine_testable()
	return result()


func _success_results_preserve_events_and_metadata_contract() -> void:
	var event: DomainEvent = DomainEvent.board_created(1, 3, 2)
	var second_event: DomainEvent = DomainEvent.board_created(2, 4, 2)
	var metadata: Dictionary = {
		"source": "test",
		"context": {
			"turn": 1
		}
	}
	var ok_result: ActionResult = ActionResult.ok([event, second_event], metadata)
	metadata["source"] = "mutated"
	metadata["context"]["turn"] = 99

	assert_true(ok_result.succeeded, "ActionResult.ok should succeed.")
	assert_true(ok_result.has_events(), "ActionResult.ok should retain typed events.")
	assert_equal(ok_result.events[0].event_type, DomainEvent.Type.BOARD_CREATED, "ActionResult.ok should preserve event type.")
	assert_equal(ok_result.events[0].sequence_id, 1, "ActionResult.ok should preserve first event order.")
	assert_equal(ok_result.events[1].sequence_id, 2, "ActionResult.ok should preserve second event order.")
	assert_equal(ok_result.error_code, &"", "Successful ActionResult should not expose an error code.")
	assert_equal(ok_result.metadata.get("source"), "test", "ActionResult.ok should preserve metadata.")
	assert_equal(ok_result.metadata.get("context", {}).get("turn"), 1, "ActionResult.ok should deep-copy metadata at creation.")


func _error_results_preserve_stable_machine_contract() -> void:
	var error_result: ActionResult = ActionResult.error(&"invalid_action")
	var metadata: Dictionary = {
		"debug_context": {
			"width": 0
		},
		"display_text_key": "errors.invalid_action"
	}
	var metadata_result: ActionResult = ActionResult.error(&"invalid_board_size", metadata)
	metadata["debug_context"]["width"] = 10
	var empty_code_result: ActionResult = ActionResult.error(&"")

	assert_false(error_result.succeeded, "ActionResult.error should not succeed.")
	assert_true(error_result.is_error(), "ActionResult.error should report an error.")
	assert_equal(error_result.error_code, &"invalid_action", "ActionResult.error should preserve the error code.")
	assert_false(error_result.has_events(), "ActionResult.error should not retain events.")
	assert_equal(metadata_result.error_code, &"invalid_board_size", "Diagnostic metadata must not replace the stable error code.")
	assert_equal(metadata_result.metadata.get("debug_context", {}).get("width"), 0, "ActionResult.error should deep-copy diagnostic metadata.")
	assert_equal(metadata_result.metadata.get("display_text_key"), "errors.invalid_action", "Player-facing text keys should stay separate from error codes.")
	assert_equal(empty_code_result.error_code, &"invalid_error_code", "ActionResult.error should reject empty error codes with a stable code.")


func _ok_rejects_invalid_event_values_without_partial_events() -> void:
	var event: DomainEvent = DomainEvent.board_created(1, 3, 2)
	var invalid_event_result: ActionResult = ActionResult.ok(["not_an_event"])
	var partial_invalid_result: ActionResult = ActionResult.ok([event, "not_an_event"])

	assert_true(invalid_event_result.is_error(), "ActionResult.ok should reject non-domain event values.")
	assert_equal(invalid_event_result.error_code, &"invalid_result_event", "ActionResult.ok should explain invalid event values.")
	assert_false(invalid_event_result.has_events(), "ActionResult.ok should not retain invalid event values.")
	assert_true(partial_invalid_result.is_error(), "ActionResult.ok should reject mixed valid and invalid event arrays.")
	assert_false(partial_invalid_result.has_events(), "ActionResult.ok should not retain partial event data after validation fails.")


func _reason_codes_remain_machine_testable() -> void:
	var stable_codes: Array[StringName] = [
		&"invalid_board_size",
		&"board_already_created",
		&"event_sequence_mismatch",
		&"unsupported_board_event"
	]
	for error_code: StringName in stable_codes:
		var result_value: ActionResult = ActionResult.error(error_code)
		assert_equal(result_value.error_code, error_code, "Stable lower-snake reason codes should be preserved.")

	var prose_result: ActionResult = ActionResult.error(&"Board already created")
	assert_equal(prose_result.error_code, &"invalid_error_code", "Player-facing prose should not be accepted as an ActionResult error code.")
