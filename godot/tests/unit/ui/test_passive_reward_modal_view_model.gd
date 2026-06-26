extends "res://tests/unit/test_case.gd"

# Story 6.4 — PassiveRewardModalViewModel (the scene-free, exact-key, fail-closed passive-reward MODAL
# projection, AC1/AC5).
#
# Pins: the EXACT MODAL_KEYS set (a key never silently appears/vanishes); projecting a baseline passive
# surfaces all FR47 fields (icon / display_name / flavor / exact_mechanical_effects / consume_text /
# destroy_text) + the honest-unknown surface (has_unknown_consequences + consequences_text); projecting an
# offered {category:"passive", content_id} entry resolves the same way; projecting via a RewardOffer + index
# works; the honest-unknown surface is SURFACED truthfully for a passive that declares unknown consequences;
# and FAIL-CLOSED identity-absent (the SAME key set, has_passive == false, no crash) for an unknown id, a
# non-passive entry, a malformed entry, and a null/absent input. No live PassiveDefinition handle leaks out.

const PassiveDefinition = preload("res://scripts/content/definitions/passive_definition.gd")
const PassiveRepository = preload("res://scripts/content/repositories/passive_repository.gd")
const PassiveRewardModalViewModel = preload("res://scripts/ui/view_models/passive_reward_modal_view_model.gd")
const RewardOffer = preload("res://scripts/run/reward_offer.gd")
const RewardTableDefinition = preload("res://scripts/content/definitions/reward_table_definition.gd")

func run() -> Dictionary:
	_modal_keys_are_exact_for_a_present_passive()
	_modal_keys_are_exact_for_an_absent_passive()
	_projects_a_baseline_passive_with_all_fr47_fields()
	_projects_an_offered_entry()
	_projects_via_a_reward_offer_and_index()
	_surfaces_an_honest_unknown_consequence_truthfully()
	_fails_closed_on_an_unknown_passive_id()
	_fails_closed_on_a_non_passive_entry()
	_fails_closed_on_a_malformed_entry()
	_fails_closed_on_a_null_or_absent_input()
	_uses_the_baseline_repository_by_default()
	_projection_leaks_no_live_handle()
	return result()


func _modal() -> PassiveRewardModalViewModel:
	return PassiveRewardModalViewModel.new(PassiveRepository.create_baseline_repository())


# An injectable repository carrying ONE passive with a declared HONEST-UNKNOWN downside (for the AC1 surface).
func _mystery_repository() -> PassiveRepository:
	var mystery: PassiveDefinition = PassiveDefinition.new(
		&"mystery_passive",
		"Whispered Memory",
		PassiveDefinition.KIND_CLASS,
		[&"before_attack"],
		"A registered passive surfaces with its explanation when its window resolves.",
		PassiveDefinition.ICON_PLACEHOLDER,
		"It hums with a language no living tongue still speaks.",
		"Adds a small bonus to the next attack roll.",
		"Consume to weave the whisper into your build.",
		"Destroy to silence the whisper.",
		true,
		"Consequences of destroying this memory are unknown.",
		[PassiveDefinition.PILLAR_MYSTERY]
	)
	return PassiveRepository.create_repository_from_definitions([mystery])


func _assert_exact_keys(projection: Dictionary, message: String) -> void:
	var keys: Array = projection.keys()
	keys.sort()
	var expected: Array = PassiveRewardModalViewModel.MODAL_KEYS.duplicate()
	expected.sort()
	assert_equal(keys, expected, message)


func _modal_keys_are_exact_for_a_present_passive() -> void:
	var projection: Dictionary = _modal().project_passive(&"warrior_unbreakable_guard")
	_assert_exact_keys(projection, "A present-passive projection must carry EXACTLY the MODAL_KEYS set.")


func _modal_keys_are_exact_for_an_absent_passive() -> void:
	var projection: Dictionary = _modal().project_passive(&"does_not_exist")
	_assert_exact_keys(projection, "An identity-absent projection must carry the SAME MODAL_KEYS set.")


func _projects_a_baseline_passive_with_all_fr47_fields() -> void:
	var modal: PassiveRewardModalViewModel = _modal()
	var repository: PassiveRepository = PassiveRepository.create_baseline_repository()
	var definition: PassiveDefinition = repository.get_passive(&"warrior_unbreakable_guard")
	var projection: Dictionary = modal.project_passive(&"warrior_unbreakable_guard")

	assert_equal(projection.get("has_passive"), true, "A resolvable passive should project has_passive true.")
	assert_equal(projection.get("passive_id"), "warrior_unbreakable_guard", "The projection should carry the passive id.")
	assert_equal(projection.get("icon"), String(definition.icon), "The projection should carry the icon id.")
	assert_equal(projection.get("display_name"), definition.display_name, "The projection should carry the evocative name.")
	assert_equal(projection.get("flavor"), definition.flavor, "The projection should carry the flavor line.")
	assert_equal(projection.get("exact_mechanical_effects"), definition.exact_mechanical_effects, "The projection should carry the exact mechanical effects.")
	assert_equal(projection.get("consume_text"), definition.consume_text, "The projection should carry the Consume text.")
	assert_equal(projection.get("destroy_text"), definition.destroy_text, "The projection should carry the Destroy text.")
	assert_equal(projection.get("has_unknown_consequences"), definition.has_unknown_consequences, "The projection should carry the honest-unknown flag.")
	assert_equal(projection.get("consequences_text"), definition.consequences_text, "The projection should carry the consequences line.")
	# Every FR47 field is non-empty for a baseline passive.
	assert_false(String(projection.get("display_name")).strip_edges().is_empty(), "The projected display_name should be non-empty.")
	assert_false(String(projection.get("flavor")).strip_edges().is_empty(), "The projected flavor should be non-empty.")
	assert_false(String(projection.get("exact_mechanical_effects")).strip_edges().is_empty(), "The projected mechanics should be non-empty.")
	assert_false(String(projection.get("consume_text")).strip_edges().is_empty(), "The projected Consume text should be non-empty.")
	assert_false(String(projection.get("destroy_text")).strip_edges().is_empty(), "The projected Destroy text should be non-empty.")


func _projects_an_offered_entry() -> void:
	var modal: PassiveRewardModalViewModel = _modal()
	var entry: Dictionary = {"category": "passive", "content_id": "ranger_steady_aim"}
	var projection: Dictionary = modal.project_offer_entry(entry)
	assert_equal(projection.get("has_passive"), true, "A passive-category offered entry should project a present passive.")
	assert_equal(projection.get("passive_id"), "ranger_steady_aim", "The offered-entry projection should resolve the entry's content_id.")
	_assert_exact_keys(projection, "An offered-entry projection must carry EXACTLY the MODAL_KEYS set.")


func _projects_via_a_reward_offer_and_index() -> void:
	var modal: PassiveRewardModalViewModel = _modal()
	var offer: RewardOffer = RewardOffer.new(
		&"passive_reward_choice",
		RewardOffer.STATUS_PENDING,
		[
			{"category": "passive", "content_id": "warrior_unbreakable_guard"},
			{"category": "passive", "content_id": "pyromancer_kindling_focus"},
			{"category": "passive", "content_id": "ranger_hunters_quiver"}
		]
	)
	var first: Dictionary = modal.project_offer(offer, 0)
	var third: Dictionary = modal.project_offer(offer, 2)
	assert_equal(first.get("passive_id"), "warrior_unbreakable_guard", "Index 0 should project the first offered passive.")
	assert_equal(third.get("passive_id"), "ranger_hunters_quiver", "Index 2 should project the third offered passive.")
	assert_equal(first.get("has_passive"), true, "A valid offered index should project a present passive.")
	# An out-of-range index fails closed (identity-absent, same key set).
	var out_of_range: Dictionary = modal.project_offer(offer, 9)
	assert_equal(out_of_range.get("has_passive"), false, "An out-of-range offer index should project identity-absent.")
	_assert_exact_keys(out_of_range, "An out-of-range offer-index projection must carry the SAME MODAL_KEYS set.")
	# A null offer fails closed.
	var null_offer: Dictionary = modal.project_offer(null, 0)
	assert_equal(null_offer.get("has_passive"), false, "A null offer should project identity-absent.")


func _surfaces_an_honest_unknown_consequence_truthfully() -> void:
	# AC1: a passive that HONESTLY labels its consequences unknown surfaces the flag + the honest line truthfully.
	var modal: PassiveRewardModalViewModel = PassiveRewardModalViewModel.new(_mystery_repository())
	var projection: Dictionary = modal.project_passive(&"mystery_passive")
	assert_equal(projection.get("has_passive"), true, "The mystery passive should resolve.")
	assert_equal(projection.get("has_unknown_consequences"), true, "An honest-unknown passive should surface has_unknown_consequences true.")
	assert_equal(projection.get("consequences_text"), "Consequences of destroying this memory are unknown.", "The honest-unknown line should be surfaced verbatim.")
	# Mechanics are STILL explicit even though the downside is unknown (the GDD line-340 rule).
	assert_false(String(projection.get("exact_mechanical_effects")).strip_edges().is_empty(), "Mechanics must stay explicit even when consequences are unknown.")


func _fails_closed_on_an_unknown_passive_id() -> void:
	var modal: PassiveRewardModalViewModel = _modal()
	var projection: Dictionary = modal.project_passive(&"not_a_real_passive")
	assert_equal(projection.get("has_passive"), false, "An unknown passive id should project identity-absent (has_passive false).")
	assert_equal(projection.get("passive_id"), "", "The identity-absent projection should carry an empty passive id.")
	assert_equal(projection.get("display_name"), "", "The identity-absent projection should carry an empty display name.")
	assert_equal(projection.get("exact_mechanical_effects"), "", "The identity-absent projection should carry empty mechanics.")
	assert_equal(projection.get("has_unknown_consequences"), false, "The identity-absent projection should default the honest-unknown flag to false.")


func _fails_closed_on_a_non_passive_entry() -> void:
	var modal: PassiveRewardModalViewModel = _modal()
	# A weapon-category entry (even with a real-looking content id) is NOT a passive — the modal fail-closes.
	var entry: Dictionary = {"category": "weapon", "content_id": "sword"}
	var projection: Dictionary = modal.project_offer_entry(entry)
	assert_equal(projection.get("has_passive"), false, "A non-passive-category entry should project identity-absent.")
	_assert_exact_keys(projection, "A non-passive-entry projection must carry the SAME MODAL_KEYS set.")


func _fails_closed_on_a_malformed_entry() -> void:
	var modal: PassiveRewardModalViewModel = _modal()
	# An entry missing content_id, and an empty dict, both fail closed.
	var missing_content: Dictionary = modal.project_offer_entry({"category": "passive"})
	assert_equal(missing_content.get("has_passive"), false, "An entry missing content_id should project identity-absent.")
	var empty_entry: Dictionary = modal.project_offer_entry({})
	assert_equal(empty_entry.get("has_passive"), false, "An empty entry should project identity-absent.")
	_assert_exact_keys(empty_entry, "An empty-entry projection must carry the SAME MODAL_KEYS set.")


func _fails_closed_on_a_null_or_absent_input() -> void:
	var modal: PassiveRewardModalViewModel = _modal()
	var empty_id: Dictionary = modal.project_passive(&"")
	assert_equal(empty_id.get("has_passive"), false, "An empty passive id should project identity-absent.")
	_assert_exact_keys(empty_id, "An empty-id projection must carry the SAME MODAL_KEYS set.")


func _uses_the_baseline_repository_by_default() -> void:
	# No-arg construction defaults to the baseline passive repository (the HeroSelectViewModel injection posture).
	var modal: PassiveRewardModalViewModel = PassiveRewardModalViewModel.new()
	var projection: Dictionary = modal.project_passive(&"warrior_blade_and_board")
	assert_equal(projection.get("has_passive"), true, "The default modal should resolve a baseline passive without an injected repository.")


func _projection_leaks_no_live_handle() -> void:
	# The projected dict is plain String/bool data only — no live PassiveDefinition / Resource / Node handle.
	var modal: PassiveRewardModalViewModel = _modal()
	var projection: Dictionary = modal.project_passive(&"pyromancer_arcane_conduit")
	for key: Variant in projection.keys():
		var value: Variant = projection[key]
		assert_false(value is Object, "Projected value for '%s' must not be a live Object handle." % String(key))
