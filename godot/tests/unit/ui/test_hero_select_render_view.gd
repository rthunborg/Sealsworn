extends "res://tests/unit/test_case.gd"

# Story 14.8 (AC1/AC2/AC3, F13) — HeroSelectRenderView: the scene-free HERO-SELECT render-decision seam the rebuilt
# hero_select_presenter reads. Per the Epic-11/14 scene-free-harness constraint (the runner has NO SceneTree — DO NOT
# write SceneTree tests), the scene's assertable render decisions are covered by THIS RefCounted render-decision test +
# the scene-load compile guardrail (test_run_flow_scenes_load.gd already loads hero_select.tscn + compiles the
# presenter). The pinned roster + selectability contract is covered by test_hero_select_view_model.gd (5.2/11.6); this
# test pins the 14.8 rebuild's NEW decisions.
#
# It pins:
#   AC1 — the baseline roster projects all 5 rows in class_ids() order with the EXACT pinned row-key set; each row's
#     portrait_path maps correctly (char.<id>.png for warrior/pyromancer/ranger, char.<id>_locked.png for the two
#     locked classes — the _locked-suffix gotcha); a selectable row carries a non-empty kit summary (weapon/support/
#     passives via the STATIC re_derive_kit / re_derive_resolver, NOT summarize(run)); Ranger's kit carries the REAL
#     &"none" support (not dropped as missing).
#   AC2 — the visible selection state: is_selected is true for EXACTLY the selected class, false for the rest, and
#     false-for-all on the empty / unknown / locked selection (fail-closed); a locked row carries the locked label
#     (unlock hint + numeric cost 3 necromancer / 5 shadeblade) and NO kit; is_class_selectable passthrough is
#     fail-closed (warrior true; necromancer/shadeblade false with the profile-unaware VM; unknown false).
#   AC3 — the seam is a PURE read (a null VM is fail-closed; mutating a returned row never perturbs a fresh projection).

const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const HeroSelectViewModel = preload("res://scripts/ui/view_models/hero_select_view_model.gd")
const HeroSelectRenderView = preload("res://scripts/ui/view_models/hero_select_render_view.gd")
const MetaSpendRules = preload("res://scripts/save/meta_spend_rules.gd")

# The pinned per-row key contract (sorted). A key never silently appears/vanishes (the HeroSelectViewModel.ENTRY_KEYS
# discipline).
const EXPECTED_ROW_KEYS: Array[String] = [
	"class_id",
	"display_name",
	"is_selected",
	"kit",
	"locked_label",
	"portrait_path",
	"selectable"
]

func run() -> Dictionary:
	# AC1 — roster order + exact keys + portrait mapping + kit summary
	_baseline_projects_five_rows_in_order_with_exact_keys()
	_portrait_paths_map_with_the_locked_suffix()
	_selectable_rows_carry_a_non_empty_kit_summary()
	_ranger_kit_carries_the_real_none_support()
	# AC2 — visible selection state + locked affordance + passthrough gate
	_is_selected_is_true_for_exactly_the_selected_class()
	_no_selection_is_false_for_all()
	_unknown_selection_is_false_for_all()
	_locked_selection_is_false_for_all()
	_locked_rows_carry_the_locked_label_with_cost_and_no_kit()
	_selectable_rows_carry_an_empty_locked_label()
	_is_class_selectable_passthrough_is_fail_closed()
	# AC3 — pure read
	_null_view_model_is_fail_closed()
	_render_view_is_a_pure_read()
	return result()


# ---- helpers -------------------------------------------------------------------------------------

func _view_model() -> HeroSelectViewModel:
	return HeroSelectViewModel.new(ClassRepository.create_baseline_repository())


func _rows_by_id(view: HeroSelectRenderView) -> Dictionary:
	var by_id: Dictionary = {}
	for row_value: Variant in view.rows():
		by_id[String((row_value as Dictionary).get("class_id", ""))] = row_value
	return by_id


# ---- AC1: roster order, exact keys, portraits, kit -----------------------------------------------

func _baseline_projects_five_rows_in_order_with_exact_keys() -> void:
	var view: HeroSelectRenderView = HeroSelectRenderView.new(_view_model(), &"warrior")
	var rows: Array = view.rows()
	assert_equal(rows.size(), 5, "The render view projects exactly the 5 baseline classes.")
	var ordered_ids: Array[String] = []
	for row_value: Variant in rows:
		ordered_ids.append(String((row_value as Dictionary).get("class_id", "")))
	assert_equal(ordered_ids, [
		"warrior",
		"pyromancer",
		"ranger",
		"necromancer",
		"shadeblade"
	], "Rows are projected in ClassRepository.class_ids() order.")
	for row_value: Variant in rows:
		var keys: Array = (row_value as Dictionary).keys()
		keys.sort()
		assert_equal(keys, EXPECTED_ROW_KEYS, "Each row exposes EXACTLY the pinned key set (no extra/missing key).")


func _portrait_paths_map_with_the_locked_suffix() -> void:
	# The _locked-suffix gotcha (Dev Notes): the two locked classes carry a `_locked` filename suffix the class id does
	# NOT — a naive char.%s.png format breaks for the pair.
	var by_id: Dictionary = _rows_by_id(HeroSelectRenderView.new(_view_model(), &""))
	assert_equal(String((by_id["warrior"] as Dictionary).get("portrait_path")), "res://assets/characters/char.warrior.png", "Warrior portrait maps to char.warrior.png.")
	assert_equal(String((by_id["pyromancer"] as Dictionary).get("portrait_path")), "res://assets/characters/char.pyromancer.png", "Pyromancer portrait maps to char.pyromancer.png.")
	assert_equal(String((by_id["ranger"] as Dictionary).get("portrait_path")), "res://assets/characters/char.ranger.png", "Ranger portrait maps to char.ranger.png.")
	assert_equal(String((by_id["necromancer"] as Dictionary).get("portrait_path")), "res://assets/characters/char.necromancer_locked.png", "Necromancer portrait carries the _locked suffix.")
	assert_equal(String((by_id["shadeblade"] as Dictionary).get("portrait_path")), "res://assets/characters/char.shadeblade_locked.png", "Shadeblade portrait carries the _locked suffix.")


func _selectable_rows_carry_a_non_empty_kit_summary() -> void:
	# A selectable class carries a non-empty kit summary (weapon/support/HP/passives) sourced from the STATIC
	# re_derive_kit / re_derive_resolver (the pre-start source — NOT summarize(run)).
	var by_id: Dictionary = _rows_by_id(HeroSelectRenderView.new(_view_model(), &""))
	var warrior_kit: Dictionary = (by_id["warrior"] as Dictionary).get("kit", {})
	assert_false(warrior_kit.is_empty(), "A selectable class carries a non-empty kit summary.")
	assert_equal(String(warrior_kit.get("weapon_id", "")), "sword", "Warrior kit weapon is sword (byte-equal to re_derive_kit).")
	assert_equal(String(warrior_kit.get("support_id", "")), "shield", "Warrior kit support is shield.")
	assert_equal(int(warrior_kit.get("baseline_hp", 0)), 18, "Warrior baseline HP is 18.")
	var passives: Array = warrior_kit.get("passives", [])
	assert_equal(passives.size(), 2, "Warrior kit surfaces two passive explanations (class + equipment-synergy).")
	for passive_value: Variant in passives:
		assert_false(str(passive_value).strip_edges().is_empty(), "Each passive explanation is a non-empty human-readable string.")


func _ranger_kit_carries_the_real_none_support() -> void:
	# support_id == "none" is the REAL Ranger baseline SUPPORT_NONE (a valid no-support kit), projected verbatim — the
	# presenter renders it honestly as "No support", NEVER as a missing/error item.
	var by_id: Dictionary = _rows_by_id(HeroSelectRenderView.new(_view_model(), &""))
	var ranger_kit: Dictionary = (by_id["ranger"] as Dictionary).get("kit", {})
	assert_false(ranger_kit.is_empty(), "Ranger carries a non-empty kit.")
	assert_equal(String(ranger_kit.get("support_id", "")), "none", "Ranger's support_id is the REAL baseline 'none' (not dropped as missing).")
	assert_equal(String(ranger_kit.get("weapon_id", "")), "bow", "Ranger kit weapon is bow.")


# ---- AC2: visible selection state, locked affordance, passthrough gate ---------------------------

func _is_selected_is_true_for_exactly_the_selected_class() -> void:
	var by_id: Dictionary = _rows_by_id(HeroSelectRenderView.new(_view_model(), &"pyromancer"))
	assert_true(bool((by_id["pyromancer"] as Dictionary).get("is_selected")), "The selected class is is_selected.")
	assert_false(bool((by_id["warrior"] as Dictionary).get("is_selected")), "A non-selected selectable class is not is_selected.")
	assert_false(bool((by_id["ranger"] as Dictionary).get("is_selected")), "A non-selected selectable class is not is_selected.")
	assert_false(bool((by_id["necromancer"] as Dictionary).get("is_selected")), "A locked class is never is_selected.")
	assert_false(bool((by_id["shadeblade"] as Dictionary).get("is_selected")), "A locked class is never is_selected.")


func _no_selection_is_false_for_all() -> void:
	# The empty selection (no class chosen yet) marks no row — fail-closed.
	for row_value: Variant in HeroSelectRenderView.new(_view_model(), &"").rows():
		assert_false(bool((row_value as Dictionary).get("is_selected")), "With no selection, no row is is_selected (fail-closed).")


func _unknown_selection_is_false_for_all() -> void:
	# An unknown selected id matches no row — fail-closed.
	for row_value: Variant in HeroSelectRenderView.new(_view_model(), &"does_not_exist").rows():
		assert_false(bool((row_value as Dictionary).get("is_selected")), "An unknown selection marks no row (fail-closed).")


func _locked_selection_is_false_for_all() -> void:
	# Defensive: even if a LOCKED class id is somehow the selection (the presenter never selects one), the locked row is
	# NOT marked selected — agreeing with the authoritative RunStartCommand gate, which would reject it.
	var by_id: Dictionary = _rows_by_id(HeroSelectRenderView.new(_view_model(), &"necromancer"))
	assert_false(bool((by_id["necromancer"] as Dictionary).get("is_selected")), "A locked class id never marks the row selected (fail-closed).")


func _locked_rows_carry_the_locked_label_with_cost_and_no_kit() -> void:
	var by_id: Dictionary = _rows_by_id(HeroSelectRenderView.new(_view_model(), &""))
	var necromancer: Dictionary = by_id["necromancer"]
	assert_true((necromancer.get("kit", {}) as Dictionary).is_empty(), "A locked class carries NO kit (render only the locked affordance).")
	var necromancer_label: String = String(necromancer.get("locked_label", ""))
	assert_false(necromancer_label.strip_edges().is_empty(), "A locked class carries a non-empty locked label.")
	assert_true(necromancer_label.contains(str(MetaSpendRules.class_unlock_cost("necromancer"))), "The necromancer locked label carries its numeric unlock cost (3).")
	var shadeblade: Dictionary = by_id["shadeblade"]
	assert_true(String(shadeblade.get("locked_label", "")).contains(str(MetaSpendRules.class_unlock_cost("shadeblade"))), "The shadeblade locked label carries its numeric unlock cost (5).")


func _selectable_rows_carry_an_empty_locked_label() -> void:
	var by_id: Dictionary = _rows_by_id(HeroSelectRenderView.new(_view_model(), &""))
	assert_equal(String((by_id["warrior"] as Dictionary).get("locked_label", "x")), "", "A selectable class carries an EMPTY locked label (the key is always present).")


func _is_class_selectable_passthrough_is_fail_closed() -> void:
	var view: HeroSelectRenderView = HeroSelectRenderView.new(_view_model(), &"")
	assert_true(view.is_class_selectable(&"warrior"), "AC2: warrior passthrough is selectable.")
	assert_true(view.is_class_selectable(&"pyromancer"), "AC2: pyromancer passthrough is selectable.")
	assert_true(view.is_class_selectable(&"ranger"), "AC2: ranger passthrough is selectable.")
	# With the profile-unaware VM (Story 14.8 keeps HeroSelectViewModel.new() profile-unaware), the locked pair is not selectable.
	assert_false(view.is_class_selectable(&"necromancer"), "AC2: necromancer is NOT selectable (profile-unaware VM).")
	assert_false(view.is_class_selectable(&"shadeblade"), "AC2: shadeblade is NOT selectable (profile-unaware VM).")
	assert_false(view.is_class_selectable(&"does_not_exist"), "AC2: an unknown id is fail-closed.")
	assert_false(view.is_class_selectable(&""), "AC2: an empty id is fail-closed.")


# ---- AC3: pure read ------------------------------------------------------------------------------

func _null_view_model_is_fail_closed() -> void:
	var view: HeroSelectRenderView = HeroSelectRenderView.new(null, &"warrior")
	assert_equal(view.rows().size(), 0, "A null view model projects no rows (fail-closed).")
	assert_false(view.is_class_selectable(&"warrior"), "A null view model gate is fail-closed for every id.")


func _render_view_is_a_pure_read() -> void:
	# Building from the same VM twice yields identical decisions; mutating a returned row must not perturb a fresh
	# projection (no shared live handle leaks out).
	var view_model: HeroSelectViewModel = _view_model()
	var first: HeroSelectRenderView = HeroSelectRenderView.new(view_model, &"warrior")
	var second: HeroSelectRenderView = HeroSelectRenderView.new(view_model, &"warrior")
	assert_equal(first.rows().size(), second.rows().size(), "Two render views from the same VM agree (deterministic pure read).")
	var rows: Array = first.rows()
	(rows[0] as Dictionary)["display_name"] = "MUTATED"
	assert_equal(String((first.rows()[0] as Dictionary).get("display_name")), "Warrior", "Mutating a returned row must not perturb a fresh projection.")
