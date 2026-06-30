extends "res://tests/unit/test_case.gd"

# Story 7.4 Task 4 — AffinityViewModel (the scene-free affinity view model, AC1 readable surface). Covers: a real
# affinity surfaces the display name + explanation + recorded tactical rules + visual tags; the neutral affinity
# surfaces is_neutral == true + an EMPTY tactical_rules list (AC3); every projection carries the EXACT MODAL_KEYS
# contract (a key never silently appears/vanishes) + each rule carries the EXACT RULE_KEYS; an unresolved id projects
# identity-absent (fail-closed); and the view model is a PURE read (building it twice yields identical data; it mutates
# nothing). Mirrors test_cursed_reward_view_model.gd.

const AffinityDefinition = preload("res://scripts/content/definitions/affinity_definition.gd")
const AffinityRepository = preload("res://scripts/content/repositories/affinity_repository.gd")
const AffinityViewModel = preload("res://scripts/ui/view_models/affinity_view_model.gd")

func run() -> Dictionary:
	_a_real_affinity_surfaces_display_explanation_rules_and_tags()
	_the_neutral_affinity_surfaces_is_neutral_and_empty_rules()
	_every_projection_carries_the_exact_modal_keys()
	_each_rule_carries_the_exact_rule_keys()
	_an_unresolved_id_projects_identity_absent()
	_the_view_model_is_a_pure_read()
	return result()


func _baseline_view_model() -> AffinityViewModel:
	return AffinityViewModel.new(AffinityRepository.create_baseline_repository())


func _a_real_affinity_surfaces_display_explanation_rules_and_tags() -> void:
	var view_model: AffinityViewModel = _baseline_view_model()
	var modal: Dictionary = view_model.project_affinity(&"scorched")
	assert_true(bool(modal.get("has_affinity")), "A resolvable affinity projects has_affinity == true.")
	assert_equal(String(modal.get("affinity_id")), "scorched", "The view model surfaces the affinity id.")
	assert_equal(String(modal.get("display_name")), "Scorched", "The view model surfaces the display name.")
	assert_false(String(modal.get("explanation")).strip_edges().is_empty(), "The view model surfaces the explanation text (AC1).")
	assert_false(bool(modal.get("is_neutral")), "A real affinity surfaces is_neutral == false.")
	# AC1: the recorded tactical_rules are surfaced as descriptive data.
	var rules: Array = modal.get("tactical_rules")
	assert_true(rules.size() >= 1, "The view model surfaces the recorded tactical rules (AC1).")
	assert_false(String((rules[0] as Dictionary).get("rule_id")).is_empty(), "A surfaced rule carries a rule_id.")
	assert_false(String((rules[0] as Dictionary).get("description")).strip_edges().is_empty(), "A surfaced rule carries a description.")
	# AC1: the visual tags (the art/cue hooks).
	var tags: Array = modal.get("visual_tags")
	assert_true(tags.has("scorched"), "The view model surfaces the scorched visual tag (the art/cue hook).")


func _the_neutral_affinity_surfaces_is_neutral_and_empty_rules() -> void:
	var view_model: AffinityViewModel = _baseline_view_model()
	var modal: Dictionary = view_model.project_affinity(AffinityDefinition.AFFINITY_NONE)
	assert_true(bool(modal.get("has_affinity")), "The neutral affinity still resolves.")
	assert_true(bool(modal.get("is_neutral")), "AC3: the neutral affinity surfaces is_neutral == true.")
	assert_true((modal.get("tactical_rules") as Array).is_empty(), "AC3: the neutral affinity surfaces an EMPTY tactical_rules list (no affinity side effects).")
	assert_false(String(modal.get("explanation")).strip_edges().is_empty(), "The neutral affinity surfaces a neutral explanation (never blank).")


func _every_projection_carries_the_exact_modal_keys() -> void:
	var view_model: AffinityViewModel = _baseline_view_model()
	# A present projection AND the identity-absent projection both carry EXACTLY the MODAL_KEYS set.
	var present: Dictionary = view_model.project_affinity(&"darkness")
	var absent: Dictionary = view_model.project_affinity(&"does_not_exist")
	for modal: Dictionary in [present, absent]:
		assert_equal(modal.keys().size(), AffinityViewModel.MODAL_KEYS.size(), "A projection must carry exactly the MODAL_KEYS count.")
		for key: String in AffinityViewModel.MODAL_KEYS:
			assert_true(modal.has(key), "A projection must carry the pinned key %s." % key)


func _each_rule_carries_the_exact_rule_keys() -> void:
	var view_model: AffinityViewModel = _baseline_view_model()
	var modal: Dictionary = view_model.project_affinity(&"flooded_conductive")
	for rule_value: Variant in (modal.get("tactical_rules") as Array):
		var rule: Dictionary = rule_value
		assert_equal(rule.keys().size(), AffinityViewModel.RULE_KEYS.size(), "A surfaced rule must carry exactly the RULE_KEYS count.")
		for key: String in AffinityViewModel.RULE_KEYS:
			assert_true(rule.has(key), "A surfaced rule must carry the pinned key %s." % key)


func _an_unresolved_id_projects_identity_absent() -> void:
	var view_model: AffinityViewModel = _baseline_view_model()
	var modal: Dictionary = view_model.project_affinity(&"does_not_exist")
	assert_false(bool(modal.get("has_affinity")), "An unresolved id projects has_affinity == false (fail-closed).")
	assert_equal(String(modal.get("display_name")), "", "An identity-absent projection has an empty display name.")
	assert_true((modal.get("tactical_rules") as Array).is_empty(), "An identity-absent projection has an empty tactical_rules list.")
	assert_true((modal.get("visual_tags") as Array).is_empty(), "An identity-absent projection has an empty visual_tags list.")


func _the_view_model_is_a_pure_read() -> void:
	# Building the projection twice from the same repository yields identical data (pure read; deterministic).
	var view_model: AffinityViewModel = _baseline_view_model()
	var first: Dictionary = view_model.project_affinity(&"cursed")
	var second: Dictionary = view_model.project_affinity(&"cursed")
	assert_equal(first, second, "Projecting the same affinity twice must yield identical data (pure read).")
	# Mutating the returned dict must not perturb a fresh projection (a fresh dict is returned each call).
	first["display_name"] = "Mutated"
	(first.get("tactical_rules") as Array).clear()
	var third: Dictionary = view_model.project_affinity(&"cursed")
	assert_equal(String(third.get("display_name")), "Cursed", "A mutation of a returned projection must not perturb a fresh one.")
	assert_true((third.get("tactical_rules") as Array).size() >= 1, "A mutation of a returned projection's rules must not perturb a fresh one.")
