class_name ContentRepository
extends RefCounted

# The generic, type-keyed content registry every domain-specific *Repository registers through. It is the
# single boundary between gameplay and approved static content definitions (weapons, armor, jewelry,
# consumables, pickups, gold rewards, reward tables, enemies, level recipes, classes, passives, ...).
#
# DUPLICATE-ID FAIL-LOUD GUARD (Story 6.1, AC6 — closes the carried Epic-5 cross-cutting [Review][Defer]):
# register_definition now returns a structured ActionResult and REJECTS a second registration under an
# already-present (type, id) with a stable `duplicate_definition` error carrying the offending {type, id}.
# Previously this method returned void and OVERWROTE by (type, id) (last-write-wins), so a duplicate id made
# the per-repo id-list (which keeps the FIRST insertion) and the resolver get_definition (which returned the
# SECOND) disagree about the canonical definition — silently. The guard is applied ONCE here so ALL content
# repositories (the six existing + every new Epic-6 loot/reward repo) inherit fail-loud duplicate rejection
# uniformly (parity preserved — no single repo is forked). Each register_<x> surfaces this as a per-type
# `duplicate_<x>` error (so the offending id is reported in the caller's own error vocabulary). A rejected
# duplicate is NEITHER stored (get_definition still returns the FIRST) NOR appended to the per-repo id order
# (the id-list keeps it exactly once) — no partial registration survives a rejected definition.

const ActionResult = preload("res://scripts/core/results/action_result.gd")

var _definitions_by_type: Dictionary = {}

func register_definition(definition_type: StringName, definition_id: StringName, definition: Resource) -> ActionResult:
	if not _definitions_by_type.has(definition_type):
		_definitions_by_type[definition_type] = {}

	var typed_bucket: Dictionary = _definitions_by_type[definition_type]
	if typed_bucket.has(definition_id):
		return ActionResult.error(&"duplicate_definition", {
			"reason": "duplicate_id",
			"type": String(definition_type),
			"id": String(definition_id)
		})

	typed_bucket[definition_id] = definition
	return ActionResult.ok([], {
		"type": String(definition_type),
		"id": String(definition_id)
	})


func get_definition(definition_type: StringName, definition_id: StringName) -> Resource:
	if not _definitions_by_type.has(definition_type):
		return null

	var typed_bucket: Dictionary = _definitions_by_type[definition_type]
	return typed_bucket.get(definition_id) as Resource


func has_definition(definition_type: StringName, definition_id: StringName) -> bool:
	if not _definitions_by_type.has(definition_type):
		return false

	var typed_bucket: Dictionary = _definitions_by_type[definition_type]
	return typed_bucket.has(definition_id)
