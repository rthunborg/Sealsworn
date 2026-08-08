class_name BootMenuViewModel
extends RefCounted

# Story 15.4 (AC2) — the scene-free BOOT-MENU DECISION seam. From a single input (has-saved-run) it projects the
# boot/menu affordances the BootController renders: whether to offer Continue, whether to offer New Run, and
# whether starting a New Run needs an overwrite confirm (because it would clobber a saved descent). It owns NO run
# truth and NO save policy — it PROJECTS a decision the presenter renders; the presenter reads has-saved-run from
# SaveManager.has_saved_run() (an additive file-existence check — no schema change) and the resume/seat/save-clear
# rides the EXISTING seams.
#
# ⭐ FAIL-CLOSED (AC2 — "a boot with no saved run must NOT offer Continue"; "a false/malformed has-saved-run is a
# safe no-Continue"): the input is coerced to a strict bool. Anything that is not a literal `true` (a non-bool, a
# malformed probe) resolves to FALSE -> no Continue offered, no overwrite confirm needed. A New Run is ALWAYS
# offer-able (you can always start a fresh descent). This is a PURE read: it draws no RNG, mutates nothing, mints
# no event.
#
# ⭐ EXACT-KEY (the ratified seam discipline): to_dictionary() has a pinned key set (DICTIONARY_KEYS) — a key never
# silently appears or vanishes; the presenter reads exactly these keys.

# The stable key set of to_dictionary() (pinned by test). offer_continue gates the Continue affordance;
# offer_new_run gates the New Run affordance (always true); new_run_needs_overwrite_confirm gates the confirm the
# New Run start must pass before clobbering a saved descent.
const DICTIONARY_KEYS: Array[String] = [
	"offer_continue",
	"offer_new_run",
	"new_run_needs_overwrite_confirm"
]

var offer_continue: bool = false
var offer_new_run: bool = true
var new_run_needs_overwrite_confirm: bool = false

# Build the boot-menu decision from a has-saved-run probe. A literal `true` offers Continue + flags the overwrite
# confirm; anything else (false / a non-bool / a malformed probe) is the safe no-Continue default. A New Run is
# always offered.
static func from_has_saved_run(has_saved_run: Variant) -> BootMenuViewModel:
	# Fail-closed coercion: only a literal boolean true counts as "a saved run exists". A non-bool probe is a
	# malformed read -> treat it as no-saved-run (never offer Continue to a run we cannot prove exists).
	var saved: bool = typeof(has_saved_run) == TYPE_BOOL and bool(has_saved_run)
	var view: BootMenuViewModel = load("res://scripts/ui/view_models/boot_menu_view_model.gd").new()
	view.offer_continue = saved
	view.offer_new_run = true
	view.new_run_needs_overwrite_confirm = saved
	return view


# Exact-key projection: plain bool data only (no live handle leaks out). A fresh dictionary each call.
func to_dictionary() -> Dictionary:
	return {
		"offer_continue": offer_continue,
		"offer_new_run": offer_new_run,
		"new_run_needs_overwrite_confirm": new_run_needs_overwrite_confirm
	}
