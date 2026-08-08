extends "res://tests/unit/test_case.gd"

# Story 15.4 (AC2) — the scene-free BOOT-MENU DECISION seam. From a single has-saved-run input it projects the boot
# affordances (offer_continue / offer_new_run / new_run_needs_overwrite_confirm) the BootController renders. This
# pins the exact-key output set + the fail-closed coercion: a saved run offers Continue + flags the overwrite
# confirm; NO saved run offers no Continue + needs no confirm; a MALFORMED probe (a non-bool) is the safe
# no-Continue default (never offer Continue to a run we cannot prove exists). New Run is ALWAYS offered.

const BootMenuViewModel = preload("res://scripts/ui/view_models/boot_menu_view_model.gd")

func run() -> Dictionary:
	_saved_run_offers_continue_and_needs_overwrite_confirm()
	_no_saved_run_offers_no_continue_and_no_confirm()
	_malformed_probe_is_a_safe_no_continue()
	_to_dictionary_pins_the_exact_key_set()
	return result()


# A saved run exists -> Continue is offered, a New Run needs the overwrite confirm, and New Run is still offered.
func _saved_run_offers_continue_and_needs_overwrite_confirm() -> void:
	var view: BootMenuViewModel = BootMenuViewModel.from_has_saved_run(true)
	assert_true(view.offer_continue, "A saved run must offer Continue.")
	assert_true(view.offer_new_run, "A New Run is always offered.")
	assert_true(view.new_run_needs_overwrite_confirm, "A New Run over a saved run must need the overwrite confirm.")


# No saved run -> Continue is NOT offered (AC2: a boot with no saved run must not offer Continue), and a New Run
# needs no confirm (nothing to overwrite). New Run is still offered.
func _no_saved_run_offers_no_continue_and_no_confirm() -> void:
	var view: BootMenuViewModel = BootMenuViewModel.from_has_saved_run(false)
	assert_false(view.offer_continue, "A cold start (no saved run) must NOT offer Continue.")
	assert_true(view.offer_new_run, "A New Run is always offered even with no saved run.")
	assert_false(view.new_run_needs_overwrite_confirm, "With no saved run there is nothing to overwrite — no confirm.")


# Fail-closed: a MALFORMED has-saved-run probe (a non-bool) resolves to the safe no-Continue default (never offer
# Continue to a run we cannot prove exists; never demand a confirm that would clear a non-existent save).
func _malformed_probe_is_a_safe_no_continue() -> void:
	for malformed: Variant in [null, "yes", 1, {}, []]:
		var view: BootMenuViewModel = BootMenuViewModel.from_has_saved_run(malformed)
		assert_false(view.offer_continue, "A malformed has-saved-run probe (%s) must be a safe no-Continue." % str(malformed))
		assert_false(view.new_run_needs_overwrite_confirm, "A malformed probe (%s) must need no overwrite confirm." % str(malformed))
		assert_true(view.offer_new_run, "A malformed probe (%s) still offers a New Run." % str(malformed))


# The exact-key contract: to_dictionary() returns EXACTLY the pinned DICTIONARY_KEYS (a key never silently appears
# or vanishes), and the values reflect the projection.
func _to_dictionary_pins_the_exact_key_set() -> void:
	var data: Dictionary = BootMenuViewModel.from_has_saved_run(true).to_dictionary()
	assert_equal(data.keys().size(), BootMenuViewModel.DICTIONARY_KEYS.size(), "to_dictionary() must have exactly the pinned key count.")
	for key: String in BootMenuViewModel.DICTIONARY_KEYS:
		assert_true(data.has(key), "to_dictionary() must carry the pinned key %s." % key)
	assert_equal(data.get("offer_continue"), true, "The dict must reflect offer_continue.")
	assert_equal(data.get("offer_new_run"), true, "The dict must reflect offer_new_run.")
	assert_equal(data.get("new_run_needs_overwrite_confirm"), true, "The dict must reflect new_run_needs_overwrite_confirm.")
