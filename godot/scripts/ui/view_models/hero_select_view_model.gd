class_name HeroSelectViewModel
extends RefCounted

# Story 5.2 — the scene-free hero-select roster PROJECTION (AC1/AC2). HeroSelectViewModel is the presentation
# contract the (future) hero-select scene reads: it PROJECTS ClassRepository into serializable view data so
# the screen reads DOMAIN TRUTH (selectable/locked, the unlock hint), never a UI literal. It is a RefCounted
# DTO — NOT a Control, NOT a Node, NOT a scene — mirroring the TacticalBoardViewModel pattern (a pure
# projection with an EXACT per-entry key contract; a key never silently appears/vanishes).
#
# WHAT IT IS:
#   - classes() -> Array of per-class dicts {class_id, display_name, selectable, unlock_hint} for each class
#     in ClassRepository.class_ids() order (warrior, pyromancer, ranger, necromancer, shadeblade for the
#     baseline). `selectable` is ClassDefinition.is_selectable(); `unlock_hint` is the definition's hint
#     (non-empty for locked classes, empty for selectable ones). "Grayed-out locked" is the UI's job at scene
#     time — the view model only reports selectable: false + the hint.
#   - is_class_selectable(id) -> bool: the AC2 confirm pre-gate, FAIL-CLOSED (unknown id -> false, locked ->
#     false, selectable -> true). The (future) confirm path uses this to gray out + block a locked/unknown
#     class; the AUTHORITATIVE fail-closed gate is RunStartCommand's class validation (so even a mis-enabled
#     confirm button cannot start a locked run).
#   - selectable_class_ids() / locked_class_ids(): convenience partition reads in class_ids() order.
#
# WHAT IT IS NOT:
#   - It owns NO domain truth and submits NO commands — it PROJECTS the repository (the confirm intent reaches
#     a VALIDATED RunStartCommand via RunOrchestrator.start, not through this view model).
#   - It draws NO RNG, never generates a class, never mutates the repository (a pure read of approved static
#     content).
#   - It does NOT read starting_*/baseline_hp/passive ids (those are Story 5.3 / 5.4); it only needs
#     class_id/display_name/is_selectable/unlock_hint.

const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")

# The EXACT per-entry key set (the TacticalBoardViewModel exact-key discipline). A key never silently
# appears/vanishes — a test pins this.
const ENTRY_KEYS: Array[String] = [
	"class_id",
	"display_name",
	"selectable",
	"unlock_hint"
]

var _class_repository: ClassRepository = null

func _init(new_class_repository: ClassRepository = null) -> void:
	# Default to the baseline repository (mirroring RunStartCommand's repository injection). Tests inject a
	# fixture repository.
	_class_repository = new_class_repository if new_class_repository != null else ClassRepository.create_baseline_repository()


# Project the full roster: one serializable entry per class in class_ids() order. PURE String/bool data (no
# live ClassDefinition handle leaks out). A class id that somehow has no resolvable definition is skipped
# (fail-closed — the projection never carries a half-entry), though the baseline repository never triggers it.
func classes() -> Array:
	var roster: Array = []
	for current_class_id: StringName in _class_repository.class_ids():
		var def: ClassDefinition = _class_repository.get_class_definition(current_class_id)
		if def == null:
			continue
		roster.append(_project_entry(def))
	return roster


# The AC2 confirm pre-gate: is this class id selectable RIGHT NOW? Fail-closed — an unknown id (null lookup)
# or a locked class returns false; only a resolved selectable class returns true. Mirrors the repository's
# null-on-miss lookup so the UI gate and the run-start command gate agree.
func is_class_selectable(query_class_id: StringName) -> bool:
	var def: ClassDefinition = _class_repository.get_class_definition(query_class_id)
	if def == null:
		return false
	return def.is_selectable()


# Convenience: the selectable class ids in class_ids() order (the playable roster).
func selectable_class_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for current_class_id: StringName in _class_repository.class_ids():
		var def: ClassDefinition = _class_repository.get_class_definition(current_class_id)
		if def != null and def.is_selectable():
			ids.append(current_class_id)
	return ids


# Convenience: the locked class ids in class_ids() order (shown grayed-out with an unlock hint at scene time).
func locked_class_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for current_class_id: StringName in _class_repository.class_ids():
		var def: ClassDefinition = _class_repository.get_class_definition(current_class_id)
		if def != null and not def.is_selectable():
			ids.append(current_class_id)
	return ids


func _project_entry(def: ClassDefinition) -> Dictionary:
	# unlock_hint is only meaningful for locked classes; project it verbatim (empty for selectable classes by
	# ClassDefinition's 5.1 validate()).
	return {
		"class_id": String(def.class_id),
		"display_name": def.display_name,
		"selectable": def.is_selectable(),
		"unlock_hint": def.unlock_hint
	}
