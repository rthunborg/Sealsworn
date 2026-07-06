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
# ⭐ STORY 11.6 EXTENSION — PROFILE-AWARE SELECTABILITY (AC2, FR43 — the crux): the constructor gained an OPTIONAL
# trailing ProfileSnapshot (default null = the byte-identical Story-5.2 STATIC behavior). When a profile is supplied,
# a locked class becomes selectable IFF (static LOCK_STATE_SELECTABLE) OR (its unlock requirement is met on the profile
# — its `<class>_unlocked` applied-unlock flag is set, derived via the SINGLE source MetaSpendRules.unlocked_class_ids_for,
# the SAME source the authoritative RunStartCommand class gate reads so the VM affordance + the gate AGREE). The applied-
# unlock is a profile-aware OVERLAY at the view-model layer — it does NOT mutate the static ClassDefinition.lock_state
# (approved static content is selected-from, not rewritten) and owns NO scene state. The pinned ENTRY_KEYS is UNCHANGED:
# the `selectable` field's VALUE becomes profile-aware (no new key). A null profile => every existing caller (the 5.2
# hero-select path, the 8.6/11.5 OutpostViewModel) stays byte-identical (the fail-closed static default). Meta power is
# capped/sparse: the unlock flips a VARIETY gate (a class becomes selectable), NEVER a raw combat stat (FR95).
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
const MetaSpendRules = preload("res://scripts/save/meta_spend_rules.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")

# The EXACT per-entry key set (the TacticalBoardViewModel exact-key discipline). A key never silently
# appears/vanishes — a test pins this.
const ENTRY_KEYS: Array[String] = [
	"class_id",
	"display_name",
	"selectable",
	"unlock_hint"
]

var _class_repository: ClassRepository = null
# Story 11.6: the set of class ids the supplied profile has UNLOCKED via an applied-unlock flag (the profile-aware
# OVERLAY, derived ONCE via MetaSpendRules.unlocked_class_ids_for — the SAME source the authoritative RunStartCommand
# class gate reads). EMPTY when no profile is supplied (the byte-identical static default). A lower_snake String set.
var _unlocked_class_ids: Array[String] = []

func _init(new_class_repository: ClassRepository = null, new_profile: ProfileSnapshot = null) -> void:
	# Default to the baseline repository (mirroring RunStartCommand's repository injection). Tests inject a
	# fixture repository.
	_class_repository = new_class_repository if new_class_repository != null else ClassRepository.create_baseline_repository()
	# Story 11.6: derive the profile-aware applied-unlock overlay ONCE. A null profile => an EMPTY set (byte-identical
	# static behavior — every existing caller stays correct). The overlay is a pure read of the profile's unlock flags; it
	# does NOT mutate the static ClassDefinition.
	if new_profile != null:
		_unlocked_class_ids = MetaSpendRules.unlocked_class_ids_for(new_profile.unlock_progress)


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
# returns false; a class is selectable iff it is STATICALLY selectable OR the supplied profile has unlocked it
# (Story 11.6 — the profile-aware overlay). Mirrors the repository's null-on-miss lookup so the UI gate and the
# authoritative run-start command gate agree (both read the SAME applied-unlock source).
func is_class_selectable(query_class_id: StringName) -> bool:
	var def: ClassDefinition = _class_repository.get_class_definition(query_class_id)
	if def == null:
		return false
	return _class_is_selectable(def)


# Convenience: the selectable class ids in class_ids() order (the playable roster). Profile-aware (Story 11.6): a
# formerly-locked class the profile has unlocked joins the playable roster.
func selectable_class_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for current_class_id: StringName in _class_repository.class_ids():
		var def: ClassDefinition = _class_repository.get_class_definition(current_class_id)
		if def != null and _class_is_selectable(def):
			ids.append(current_class_id)
	return ids


# Convenience: the locked class ids in class_ids() order (shown grayed-out with an unlock hint at scene time).
# Profile-aware (Story 11.6): a class the profile has unlocked is NO LONGER in the locked partition.
func locked_class_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for current_class_id: StringName in _class_repository.class_ids():
		var def: ClassDefinition = _class_repository.get_class_definition(current_class_id)
		if def != null and not _class_is_selectable(def):
			ids.append(current_class_id)
	return ids


# Story 11.6 (AC2, the crux): the profile-aware selectability decision — the SINGLE place the VM decides "is this class
# selectable", so the projection + the pre-gate + the partitions all agree. A class is selectable iff it is STATICALLY
# LOCK_STATE_SELECTABLE OR the supplied profile has unlocked it (its class id is in the applied-unlock overlay derived
# from MetaSpendRules — the SAME source the authoritative RunStartCommand class gate reads). With no profile the overlay
# is empty, so this is byte-identical to def.is_selectable() (the static Story-5.2 behavior). It does NOT mutate the
# static ClassDefinition (approved static content is selected-from, not rewritten).
func _class_is_selectable(def: ClassDefinition) -> bool:
	if def.is_selectable():
		return true
	return _unlocked_class_ids.has(String(def.class_id))


func _project_entry(def: ClassDefinition) -> Dictionary:
	# unlock_hint is only meaningful for locked classes; project it verbatim (empty for selectable classes by
	# ClassDefinition's 5.1 validate()). Story 11.6: `selectable` is PROFILE-AWARE (a profile-unlocked class projects
	# selectable: true). The unlock_hint stays the definition's hint (a later polish MAY clear it once unlocked; v0 keeps
	# the static hint — the `selectable` flag is the authoritative affordance the presenter reads).
	return {
		"class_id": String(def.class_id),
		"display_name": def.display_name,
		"selectable": _class_is_selectable(def),
		"unlock_hint": def.unlock_hint
	}
