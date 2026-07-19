class_name HeroSelectRenderView
extends RefCounted

# Story 14.8 (AC1/AC2/AC3, F13) — the scene-free HERO-SELECT RENDER-DECISION seam: the pure-read RefCounted
# projection the rebuilt hero_select_presenter reads to decide WHAT to render per class row, so the RENDER LOGIC
# (the portrait path incl. the _locked-suffix gotcha, the visible selection state, the locked affordance + its
# unlock cost, the pre-start kit summary) is UNIT-TESTABLE by the scene-free harness (which has NO SceneTree — the
# 14.2/14.3/14.5 posture: steer ALL testable render decisions into a fail-closed RefCounted seam; the .tscn/Control
# presenter is verified BY CONSTRUCTION via the scene-load compile guardrail). The presenter MAPS these decisions to
# Control nodes (a TextureRect per portrait, Labels per kit line, a border + marker per selection); it invents no
# render vocabulary and owns no truth.
#
# ⭐ IT IS A PURE READ over a HeroSelectViewModel (the pinned 5.2/11.6 roster projection + is_class_selectable) plus
# the currently-selected class id. It draws ZERO RNG, submits NO command, emits NO event, mutates NOTHING, and
# leaks no live ClassDefinition / StartingKit handle (it projects plain String/bool/int/Array). The kit summary is
# the STATIC pre-start source ClassStartSummaryViewModel.re_derive_kit / re_derive_resolver (NEVER summarize(run) —
# there is no started run at hero-select), deterministic and RNG-free. It re-pins NOTHING (no domain/save/RNG change).
#
# ⭐ THE PROFILE-UNAWARE POSTURE (Story 14.8 Task 3 — the deliberate defer): the wrapped HeroSelectViewModel is
# constructed PROFILE-UNAWARE by the presenter, so necromancer/shadeblade read locked here even if spend-unlocked.
# That is the standing 11.6/14.4/14.5 profile-threading defer whose owner is the Necromancer/Shadeblade class-kit
# CONTENT story (threading the profile WITHOUT authoring their kits would make a spend-unlocked class read selectable
# while RunStartCommand's kit gate still rejects it — a mis-enabled-start hazard). This seam inherits that unchanged.
#
# ⭐ NON-COLOR CHANNELS (NFR9): the selection state carries is_selected (the presenter draws a border + a text marker,
# not color alone) and the locked state carries a text locked_label (the unlock hint + the numeric cost), never
# color alone. The honest support_id == "none" (Ranger's real baseline SUPPORT_NONE) is projected verbatim — the
# presenter renders it as "No support", NEVER as a missing/error item.

const HeroSelectViewModel = preload("res://scripts/ui/view_models/hero_select_view_model.gd")
const ClassStartSummaryViewModel = preload("res://scripts/ui/view_models/class_start_summary_view_model.gd")
const MetaSpendRules = preload("res://scripts/save/meta_spend_rules.gd")
const RuleTrigger = preload("res://scripts/rules/triggers/rule_trigger.gd")
const RulesResolver = preload("res://scripts/rules/resolver/rules_resolver.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")

# The class-id -> portrait path map (Story 14.8 Dev Notes "the _locked suffix gotcha"): the two locked classes carry
# a `_locked` filename suffix the class id does NOT, so a naive `char.%s.png` format breaks for the pair. All five
# .png + their .png.import sidecars already exist in-repo — 14.8 imports NO new art. The presenter loads each
# DEFENSIVELY at runtime (load()+null->labeled placeholder), never preload, so the compile guardrail stays green on
# an un-imported checkout. A class id absent from this map projects "" (the presenter draws the labeled placeholder).
const PORTRAIT_PATHS: Dictionary = {
	"warrior": "res://assets/characters/char.warrior.png",
	"pyromancer": "res://assets/characters/char.pyromancer.png",
	"ranger": "res://assets/characters/char.ranger.png",
	"necromancer": "res://assets/characters/char.necromancer_locked.png",
	"shadeblade": "res://assets/characters/char.shadeblade_locked.png"
}

# The EXACT per-row key set (the HeroSelectViewModel.ENTRY_KEYS / TacticalBoardViewModel exact-key discipline). A key
# never silently appears/vanishes — a test pins this. Every key is ALWAYS present: a selectable row carries an empty
# locked_label; a locked row carries an empty kit ({}). is_selected is fail-closed false for the no/unknown/locked
# selection.
const ROW_KEYS: Array[String] = [
	"class_id",
	"display_name",
	"selectable",
	"is_selected",
	"portrait_path",
	"locked_label",
	"kit"
]

# The EXACT kit-summary key set for a selectable row (empty {} for a locked row). weapon_id/support_id are the class's
# resolved kit ids (support_id may be the REAL &"none" — Ranger's baseline SUPPORT_NONE, NOT a missing item);
# baseline_hp is the small bounded starting HP; passives are the human-readable explanation strings (the class passive
# THEN the equipment-synergy passive — the stable resolver order).
const KIT_KEYS: Array[String] = [
	"weapon_id",
	"support_id",
	"baseline_hp",
	"passives"
]

var _view_model: HeroSelectViewModel = null
var _selected_class_id: String = ""

func _init(hero_select_view_model: HeroSelectViewModel = null, selected_class_id: StringName = &"") -> void:
	_view_model = hero_select_view_model
	_selected_class_id = String(selected_class_id)


# Project one render-row per class in the wrapped HeroSelectViewModel.classes() order (warrior, pyromancer, ranger,
# necromancer, shadeblade for the baseline). PURE serializable data. A null view model projects an empty roster
# (fail-closed — never a crash). A class id that somehow projects empty is skipped fail-closed (never a half-row),
# mirroring HeroSelectViewModel.classes() (the baseline roster never triggers it).
func rows() -> Array:
	var projected: Array = []
	if _view_model == null:
		return projected
	for entry_value: Variant in _view_model.classes():
		var entry: Dictionary = entry_value
		var class_id: String = String(entry.get("class_id", ""))
		if class_id.is_empty():
			continue
		projected.append(_project_row(entry, class_id))
	return projected


# The AC2 confirm pre-gate passthrough: delegate to the wrapped HeroSelectViewModel (the UI grey-out / confirm-enable
# reads THIS). Fail-closed: a null view model or an unknown/locked id returns false. The AUTHORITATIVE fail-closed
# gate stays RunStartCommand (the UI never becomes authoritative — a mis-enabled confirm still cannot start a run).
func is_class_selectable(query_class_id: StringName) -> bool:
	if _view_model == null:
		return false
	return _view_model.is_class_selectable(query_class_id)


func _project_row(entry: Dictionary, class_id: String) -> Dictionary:
	var selectable: bool = bool(entry.get("selectable", false))
	# is_selected is fail-closed: true ONLY for a SELECTABLE row whose class id == the seam's selected id. An
	# empty/unknown selection marks no row; a locked selected id (defensive — the presenter never selects one) marks
	# no row (agreeing with the authoritative gate, which would reject it).
	var is_selected: bool = selectable and not _selected_class_id.is_empty() and class_id == _selected_class_id
	return {
		"class_id": class_id,
		"display_name": String(entry.get("display_name", "")),
		"selectable": selectable,
		"is_selected": is_selected,
		"portrait_path": String(PORTRAIT_PATHS.get(class_id, "")),
		"locked_label": _locked_label(entry, class_id, selectable),
		"kit": _kit_summary(class_id, selectable)
	}


# The locked affordance text (AC2): empty for a selectable class; for a locked class the unlock hint PLUS the numeric
# unlock cost from MetaSpendRules.class_unlock_cost(class_id) when the id is a known CLASS_UNLOCKS entry (necromancer
# 3 / shadeblade 5 in v0, where unlock_id == class_id), else just the hint (a deterministic presentation read, NOT a
# domain change). A non-color channel (text) — never color alone (NFR9).
func _locked_label(entry: Dictionary, class_id: String, selectable: bool) -> String:
	if selectable:
		return ""
	var hint: String = String(entry.get("unlock_hint", ""))
	var cost: int = MetaSpendRules.class_unlock_cost(class_id)
	if cost >= 0:
		if hint.is_empty():
			return "Unlock: %d Oath Shards" % cost
		return "%s (Unlock: %d Oath Shards)" % [hint, cost]
	return hint


# The pre-start kit summary (AC1) for a SELECTABLE class, else an empty {} (a locked class has no kit — render only
# the locked affordance). Sourced from the STATIC ClassStartSummaryViewModel.re_derive_kit / re_derive_resolver (the
# canonical pre-start re-derive path; deterministic, ZERO RNG, byte-equal to what RunStartCommand would seat) — NEVER
# summarize(run), which needs a STARTED run (none exists at hero-select). re_derive_kit returns null for a
# locked/unknown class (fail-closed) -> an empty kit, which is exactly right. Projects plain String/int/Array (no live
# StartingKit handle leaked out).
func _kit_summary(class_id: String, selectable: bool) -> Dictionary:
	if not selectable:
		return {}
	var kit: StartingKit = ClassStartSummaryViewModel.re_derive_kit(StringName(class_id))
	if kit == null:
		return {}
	return {
		"weapon_id": String(kit.weapon_id),
		"support_id": String(kit.support_id),
		"baseline_hp": kit.baseline_hp,
		"passives": _passive_explanations(class_id)
	}


# The human-readable passive explanation strings for a class, in the stable resolver order: the CLASS passive (its
# before_attack window) THEN the equipment-synergy passive (its run_started window) — the same order
# ClassStartSummaryViewModel.summarize surfaces. A PURE read of the re-derived resolver (no RNG, no mutation). An
# unresolvable class re-derives a null resolver -> empty (fail-closed, defensive — the baseline selectable classes
# always resolve).
func _passive_explanations(class_id: String) -> Array[String]:
	var explanations: Array[String] = []
	var resolver: RulesResolver = ClassStartSummaryViewModel.re_derive_resolver(StringName(class_id))
	if resolver == null:
		return explanations
	explanations.append_array(resolver.explain(RuleTrigger.BEFORE_ATTACK))
	explanations.append_array(resolver.explain(RuleTrigger.RUN_STARTED))
	return explanations
