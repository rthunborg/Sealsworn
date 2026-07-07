extends "res://tests/unit/test_case.gd"

# Story 5.2 Task 5.1 — HeroSelectViewModel (AC1/AC2): the scene-free roster projection.
#
# HeroSelectViewModel projects ClassRepository into serializable view data for the (future) hero-select
# screen: per class in class_ids() order a dict {class_id, display_name, selectable, unlock_hint}, plus the
# AC2 confirm gate is_class_selectable(id) (fail-closed: unknown -> false, locked -> false, selectable ->
# true). It owns NO domain truth and submits NO commands — it PROJECTS the repository (mirrors the
# TacticalBoardViewModel exact-key discipline: a key never silently appears/vanishes).
#
# This test pins: the baseline roster projects all 5 classes in class_ids() order; Warrior/Pyromancer/Ranger
# selectable; Necromancer/Shadeblade locked with a NON-EMPTY unlock_hint and an EMPTY hint for selectable
# classes; is_class_selectable true/false/unknown-false; the exact per-entry key contract; the convenience
# selectable_class_ids()/locked_class_ids() reads; and that an empty repository projects an empty roster
# (fail-closed, no crash).

const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const HeroSelectViewModel = preload("res://scripts/ui/view_models/hero_select_view_model.gd")
const ProfileSnapshot = preload("res://scripts/save/snapshots/profile_snapshot.gd")

# The pinned per-entry key contract (sorted). A key never silently appears/vanishes (the
# TacticalBoardViewModel discipline).
const EXPECTED_ENTRY_KEYS: Array[String] = [
	"class_id",
	"display_name",
	"selectable",
	"unlock_hint"
]

const SELECTABLE_IDS: Array[String] = ["warrior", "pyromancer", "ranger"]
const LOCKED_IDS: Array[String] = ["necromancer", "shadeblade"]

func run() -> Dictionary:
	_baseline_roster_projects_five_classes_in_order()
	_selectable_classes_are_selectable_with_empty_hint()
	_locked_classes_are_not_selectable_with_non_empty_hint()
	_each_entry_exposes_the_exact_pinned_key_set()
	_is_class_selectable_is_fail_closed()
	_convenience_id_reads_partition_the_roster()
	_view_model_projection_is_a_pure_copy_not_a_live_handle()
	_empty_repository_projects_an_empty_roster()
	# Story 11.6 — the profile-aware selectability overlay (AC2/FR43).
	_null_profile_is_byte_identical_to_static_behavior()
	_profile_with_unlock_makes_the_locked_class_selectable()
	_profile_without_unlock_keeps_the_class_locked()
	_profile_unlock_partitions_move_the_class_to_selectable()
	return result()


func _view_model() -> HeroSelectViewModel:
	return HeroSelectViewModel.new(ClassRepository.create_baseline_repository())


func _baseline_roster_projects_five_classes_in_order() -> void:
	var view_model: HeroSelectViewModel = _view_model()
	var classes: Array = view_model.classes()
	assert_equal(classes.size(), 5, "The baseline roster should project exactly the 5 MVP classes.")
	# class_ids() order is stable: warrior, pyromancer, ranger, necromancer, shadeblade.
	var ordered_ids: Array[String] = []
	for entry: Variant in classes:
		ordered_ids.append(String((entry as Dictionary).get("class_id", "")))
	assert_equal(ordered_ids, [
		"warrior",
		"pyromancer",
		"ranger",
		"necromancer",
		"shadeblade"
	], "The roster must project classes in ClassRepository.class_ids() order.")
	# Display names are projected from the definitions (not invented in the view model).
	assert_equal(String((classes[0] as Dictionary).get("display_name")), "Warrior", "Warrior display name should be projected.")
	assert_equal(String((classes[3] as Dictionary).get("display_name")), "Necromancer", "Necromancer display name should be projected.")


func _selectable_classes_are_selectable_with_empty_hint() -> void:
	var entries: Dictionary = _entries_by_id(_view_model())
	for class_id: String in SELECTABLE_IDS:
		var entry: Dictionary = entries.get(class_id, {})
		assert_equal(entry.get("selectable"), true, "%s should be selectable." % class_id)
		# unlock_hint is only meaningful for locked classes; a selectable class has an empty hint.
		assert_equal(String(entry.get("unlock_hint", "x")), "", "%s (selectable) should project an empty unlock hint." % class_id)


func _locked_classes_are_not_selectable_with_non_empty_hint() -> void:
	var entries: Dictionary = _entries_by_id(_view_model())
	for class_id: String in LOCKED_IDS:
		var entry: Dictionary = entries.get(class_id, {})
		assert_equal(entry.get("selectable"), false, "%s should be locked (not selectable)." % class_id)
		assert_false(String(entry.get("unlock_hint", "")).strip_edges().is_empty(), "%s (locked) should project a NON-EMPTY unlock hint." % class_id)


func _each_entry_exposes_the_exact_pinned_key_set() -> void:
	var view_model: HeroSelectViewModel = _view_model()
	for entry: Variant in view_model.classes():
		var keys: Array = (entry as Dictionary).keys()
		keys.sort()
		assert_equal(keys, EXPECTED_ENTRY_KEYS, "Each roster entry must expose EXACTLY the pinned key set (no extra/missing key).")


func _is_class_selectable_is_fail_closed() -> void:
	var view_model: HeroSelectViewModel = _view_model()
	assert_equal(view_model.is_class_selectable(&"warrior"), true, "AC2: a playable class is selectable.")
	assert_equal(view_model.is_class_selectable(&"pyromancer"), true, "AC2: pyromancer is selectable.")
	assert_equal(view_model.is_class_selectable(&"ranger"), true, "AC2: ranger is selectable.")
	assert_equal(view_model.is_class_selectable(&"necromancer"), false, "AC2: a locked class is NOT selectable.")
	assert_equal(view_model.is_class_selectable(&"shadeblade"), false, "AC2: shadeblade is NOT selectable.")
	# Fail-closed on an unknown id (mirrors the repository's null-on-miss lookup).
	assert_equal(view_model.is_class_selectable(&"does_not_exist"), false, "AC2: an unknown class id is fail-closed (not selectable).")
	assert_equal(view_model.is_class_selectable(&""), false, "AC2: an empty class id is fail-closed (not selectable).")


func _convenience_id_reads_partition_the_roster() -> void:
	var view_model: HeroSelectViewModel = _view_model()
	assert_equal(view_model.selectable_class_ids(), [&"warrior", &"pyromancer", &"ranger"], "selectable_class_ids() should list the playable classes in order.")
	assert_equal(view_model.locked_class_ids(), [&"necromancer", &"shadeblade"], "locked_class_ids() should list the locked classes in order.")


func _view_model_projection_is_a_pure_copy_not_a_live_handle() -> void:
	# The projection is pure serializable data: mutating a returned entry must not affect a fresh projection
	# (no shared live handle leaks out of the view model).
	var view_model: HeroSelectViewModel = _view_model()
	var first: Array = view_model.classes()
	(first[0] as Dictionary)["display_name"] = "MUTATED"
	var second: Array = view_model.classes()
	assert_equal(String((second[0] as Dictionary).get("display_name")), "Warrior", "Mutating a returned roster entry must not perturb a fresh projection.")


func _empty_repository_projects_an_empty_roster() -> void:
	# A repository with no registered classes projects an empty roster and a fail-closed gate — never a crash.
	var empty_view_model: HeroSelectViewModel = HeroSelectViewModel.new(ClassRepository.new())
	assert_equal(empty_view_model.classes().size(), 0, "An empty repository should project an empty roster.")
	assert_equal(empty_view_model.is_class_selectable(&"warrior"), false, "An empty repository's gate is fail-closed for every id.")
	assert_equal(empty_view_model.selectable_class_ids().size(), 0, "An empty repository has no selectable classes.")
	assert_equal(empty_view_model.locked_class_ids().size(), 0, "An empty repository has no locked classes.")


func _entries_by_id(view_model: HeroSelectViewModel) -> Dictionary:
	var by_id: Dictionary = {}
	for entry: Variant in view_model.classes():
		by_id[String((entry as Dictionary).get("class_id", ""))] = entry
	return by_id


# ---- Story 11.6: profile-aware selectability overlay (AC2/FR43) --------------------------------------------------

func _null_profile_is_byte_identical_to_static_behavior() -> void:
	# A null profile => the STATIC Story-5.2 behavior (every existing caller stays correct). Necromancer stays locked.
	var view_model: HeroSelectViewModel = HeroSelectViewModel.new(ClassRepository.create_baseline_repository(), null)
	assert_equal(view_model.is_class_selectable(&"necromancer"), false, "With no profile, a locked class stays locked (static).")
	assert_equal(view_model.selectable_class_ids(), [&"warrior", &"pyromancer", &"ranger"], "With no profile, the selectable roster is the static three.")
	var entries: Dictionary = _entries_by_id(view_model)
	assert_equal((entries.get("necromancer", {}) as Dictionary).get("selectable"), false, "With no profile, necromancer projects selectable: false.")


func _profile_with_unlock_makes_the_locked_class_selectable() -> void:
	# AC2 (the crux): a profile whose necromancer_unlocked flag is set makes the formerly-locked class SELECTABLE — through
	# the view model, flowing profile -> selectability (never scene-owned state).
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.unlock_progress["necromancer_unlocked"] = true
	var view_model: HeroSelectViewModel = HeroSelectViewModel.new(ClassRepository.create_baseline_repository(), profile)

	assert_equal(view_model.is_class_selectable(&"necromancer"), true, "AC2: a profile-unlocked class is selectable.")
	var entries: Dictionary = _entries_by_id(view_model)
	assert_equal((entries.get("necromancer", {}) as Dictionary).get("selectable"), true, "AC2: the unlocked class projects selectable: true.")
	# Shadeblade (no unlock) stays locked — the overlay flips ONLY the unlocked class.
	assert_equal(view_model.is_class_selectable(&"shadeblade"), false, "AC2: a class the profile has NOT unlocked stays locked.")


func _profile_without_unlock_keeps_the_class_locked() -> void:
	# AC2 symmetry: a profile WITHOUT the unlock (empty unlock_progress) still reports the class locked.
	var profile: ProfileSnapshot = ProfileSnapshot.new()  # empty unlock_progress
	var view_model: HeroSelectViewModel = HeroSelectViewModel.new(ClassRepository.create_baseline_repository(), profile)
	assert_equal(view_model.is_class_selectable(&"necromancer"), false, "AC2: a profile without the unlock keeps the class locked.")
	assert_equal(view_model.is_class_selectable(&"shadeblade"), false, "AC2: a profile without the unlock keeps shadeblade locked.")


func _profile_unlock_partitions_move_the_class_to_selectable() -> void:
	# The convenience partitions are profile-aware: an unlocked class joins selectable_class_ids + leaves locked_class_ids.
	var profile: ProfileSnapshot = ProfileSnapshot.new()
	profile.unlock_progress["necromancer_unlocked"] = true
	var view_model: HeroSelectViewModel = HeroSelectViewModel.new(ClassRepository.create_baseline_repository(), profile)
	assert_equal(view_model.selectable_class_ids(), [&"warrior", &"pyromancer", &"ranger", &"necromancer"], "The unlocked class joins the selectable partition (in class_ids() order).")
	assert_equal(view_model.locked_class_ids(), [&"shadeblade"], "The unlocked class leaves the locked partition; shadeblade (still locked) remains.")
