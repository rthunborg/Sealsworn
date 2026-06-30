extends "res://tests/unit/test_case.gd"

# Story 7.2 Task 2 — CursedRewardViewModel (the scene-free cursed-reward view model, AC1). Covers: a known-downside
# cursed reward surfaces the clear upside + the clear downside + the known consequence line; an honest-UNKNOWN cursed
# reward surfaces the honest delayed-consequence label (NOT a hidden/blank one); the projection carries the EXACT
# MODAL_KEYS contract (a key never silently appears/vanishes); an unresolved id projects identity-absent (fail-closed);
# and the view model is a PURE read (building it twice from the same definition yields identical data; it mutates
# nothing). Mirrors test_passive_reward_modal_view_model.gd.

const CursedRewardDefinition = preload("res://scripts/content/definitions/cursed_reward_definition.gd")
const CursedRewardRepository = preload("res://scripts/content/repositories/cursed_reward_repository.gd")
const CursedRewardViewModel = preload("res://scripts/ui/view_models/cursed_reward_view_model.gd")

func run() -> Dictionary:
	_a_known_downside_cursed_reward_surfaces_upside_downside_and_consequence()
	_an_honest_unknown_cursed_reward_surfaces_the_honest_label()
	_every_projection_carries_the_exact_modal_keys()
	_an_unresolved_id_projects_identity_absent()
	_the_view_model_is_a_pure_read()
	return result()


# A fixture repository holding a known-downside and an honest-unknown cursed reward.
func _fixture_repository() -> CursedRewardRepository:
	return CursedRewardRepository.create_repository_from_definitions([
		CursedRewardDefinition.new(
			&"known_cursed_reward",
			"Known Cursed Reward",
			"Gain 30 gold of power.",
			"Take on 1 curse.",
			30, 0, 1, 0, 0, 0,
			false,
			"The curse is the whole cost; nothing else is hidden."
		),
		CursedRewardDefinition.new(
			&"honest_unknown_cursed_reward",
			"Honest Unknown Cursed Reward",
			"Restore 2 healing.",
			"Take on 1 corruption.",
			0, 2, 0, 1, 0, 0,
			true,
			"Honestly unknown: a future penalty awaits, but its exact form cannot be read before you accept."
		)
	])


func _a_known_downside_cursed_reward_surfaces_upside_downside_and_consequence() -> void:
	var view_model: CursedRewardViewModel = CursedRewardViewModel.new(_fixture_repository())
	var modal: Dictionary = view_model.project_cursed_reward(&"known_cursed_reward")
	assert_true(bool(modal.get("has_cursed_reward")), "A resolvable cursed reward projects has_cursed_reward == true.")
	assert_equal(String(modal.get("display_name")), "Known Cursed Reward", "The view model surfaces the display name.")
	# AC1: the CLEAR UPSIDE — text + concrete benefit amounts.
	assert_equal(String(modal.get("upside_text")), "Gain 30 gold of power.", "The view model surfaces the clear upside text.")
	assert_equal(int(modal.get("gold_benefit")), 30, "The view model surfaces the concrete gold benefit.")
	assert_equal(int(modal.get("healing_benefit")), 0, "The view model surfaces the healing benefit amount.")
	# AC1: the CLEAR DOWNSIDE — text + concrete penalty amounts.
	assert_equal(String(modal.get("downside_text")), "Take on 1 curse.", "The view model surfaces the clear downside text.")
	assert_equal(int(modal.get("curse_increment")), 1, "The view model surfaces the concrete curse increment.")
	assert_equal(int(modal.get("corruption_increment")), 0, "The view model surfaces the corruption increment.")
	assert_equal(int(modal.get("gold_cost")), 0, "The view model surfaces the gold cost.")
	assert_equal(int(modal.get("healing_cost")), 0, "The view model surfaces the healing cost.")
	# AC1: the honest consequence label — a KNOWN downside line, surfaced.
	assert_false(bool(modal.get("has_delayed_consequences")), "A known-downside cursed reward surfaces has_delayed_consequences == false.")
	assert_false(String(modal.get("consequences_text")).strip_edges().is_empty(), "The known consequence line is surfaced (never blank).")


func _an_honest_unknown_cursed_reward_surfaces_the_honest_label() -> void:
	var view_model: CursedRewardViewModel = CursedRewardViewModel.new(_fixture_repository())
	var modal: Dictionary = view_model.project_cursed_reward(&"honest_unknown_cursed_reward")
	assert_true(bool(modal.get("has_cursed_reward")), "An honest-unknown cursed reward still resolves.")
	# The honest delayed-consequence label is surfaced HONESTLY — has_delayed_consequences == true + a non-blank honest
	# line (NOT a hidden/blank one). This is the AC1 honest-labeling surface.
	assert_true(bool(modal.get("has_delayed_consequences")), "An honest-unknown cursed reward surfaces has_delayed_consequences == true.")
	assert_true(String(modal.get("consequences_text")).contains("unknown"), "The honest delayed-consequence label is surfaced honestly (not hidden/blank).")


func _every_projection_carries_the_exact_modal_keys() -> void:
	var view_model: CursedRewardViewModel = CursedRewardViewModel.new(_fixture_repository())
	# A present projection AND the identity-absent projection both carry EXACTLY the MODAL_KEYS set.
	var present: Dictionary = view_model.project_cursed_reward(&"known_cursed_reward")
	var absent: Dictionary = view_model.project_cursed_reward(&"does_not_exist")
	for modal: Dictionary in [present, absent]:
		assert_equal(modal.keys().size(), CursedRewardViewModel.MODAL_KEYS.size(), "A projection must carry exactly the MODAL_KEYS count.")
		for key: String in CursedRewardViewModel.MODAL_KEYS:
			assert_true(modal.has(key), "A projection must carry the pinned key %s." % key)


func _an_unresolved_id_projects_identity_absent() -> void:
	var view_model: CursedRewardViewModel = CursedRewardViewModel.new(_fixture_repository())
	var modal: Dictionary = view_model.project_cursed_reward(&"does_not_exist")
	assert_false(bool(modal.get("has_cursed_reward")), "An unresolved id projects has_cursed_reward == false (fail-closed).")
	assert_equal(String(modal.get("display_name")), "", "An identity-absent projection has an empty display name.")
	assert_equal(int(modal.get("gold_benefit")), 0, "An identity-absent projection has zeroed amounts.")
	assert_equal(int(modal.get("curse_increment")), 0, "An identity-absent projection has zeroed penalty amounts.")


func _the_view_model_is_a_pure_read() -> void:
	# Building the projection twice from the same definition yields identical data (pure read; deterministic).
	var view_model: CursedRewardViewModel = CursedRewardViewModel.new(_fixture_repository())
	var first: Dictionary = view_model.project_cursed_reward(&"known_cursed_reward")
	var second: Dictionary = view_model.project_cursed_reward(&"known_cursed_reward")
	assert_equal(first, second, "Projecting the same cursed reward twice must yield identical data (pure read).")
	# Mutating the returned dict must not perturb a fresh projection (a fresh dict is returned each call).
	first["display_name"] = "Mutated"
	var third: Dictionary = view_model.project_cursed_reward(&"known_cursed_reward")
	assert_equal(String(third.get("display_name")), "Known Cursed Reward", "A mutation of a returned projection must not perturb a fresh one.")
