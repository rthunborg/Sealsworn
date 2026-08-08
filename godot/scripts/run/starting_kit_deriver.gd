class_name StartingKitDeriver
extends RefCounted

# Story 15.4 (CRUX-3) — the RESUME-TIME STARTING-KIT RE-DERIVATION seam. The route-position save persists the
# selected class id (nested in route_state — RunState.SELECTED_CLASS_ID_KEY) but deliberately does NOT persist
# the full StartingKit (RunState.starting_kit is "re-derived from the class id on restore"). A run rebuilt via
# RunResumeService.resume_route_position therefore carries starting_kit == null, and CombatLoadout.for_run(run)
# falls open to the driver default (LiveCombatResolver.DEFAULT_HERO_HP 60 / sword / no support) — so a resumed
# Warrior/Pyromancer/Ranger would fight at 60 HP with a sword instead of its class kit (AC2's "run intact" fails).
#
# This seam re-derives the applied StartingKit from a selected class id using the EXACT SAME ClassRepository ->
# StartingKit resolution RunStartCommand._resolve_starting_kit used at record time (a pure content read, ZERO
# RNG). RunOrchestrator.start_from calls it on the seat path so ANY restored run is made whole before it plays.
#
# ⭐ FINGERPRINT-SAFE (AC3): every pinned seed-regression fingerprint rides either the pure run_to_completion
# auto-resolve (no board, no kit read) or the hands-off play_hands_off_to_run_end driver (which uses
# DEFAULT_HERO_HP, not the kit — run_flow_controller.gd), so populating run.starting_kit on a resumed run touches
# NO pinned artifact. This seam draws ZERO gameplay RNG.
#
# ⭐ FALL-OPEN (no crash): an EMPTY class id (a legacy / seed-only run) or an UNKNOWN class id (one that does not
# resolve through the repository) yields null — the caller keeps the driver-default loadout, unchanged. v0's
# three resumable classes (warrior/pyromancer/ranger) are STATICALLY selectable, so no profile overlay is needed
# here (the deferred ClassStartSummaryViewModel.re_derive_kit profile-awareness item is NOT reopened —
# necromancer/shadeblade carry no kit and cannot start/resume in v0).

const ClassRepository = preload("res://scripts/content/repositories/class_repository.gd")
const ClassDefinition = preload("res://scripts/content/definitions/class_definition.gd")
const StartingKit = preload("res://scripts/run/starting_kit.gd")

# Re-derive the applied StartingKit from a selected class id (the same content read RunStartCommand recorded).
# Returns null for an empty / unknown class id (the fall-open driver-default path). The repository defaults to the
# baseline roster (the SAME roster RunStartCommand resolves against); a test may inject a fixture repository.
static func for_class_id(class_id: StringName, class_repository: ClassRepository = null) -> StartingKit:
	if class_id == &"":
		return null
	var repository: ClassRepository = class_repository if class_repository != null else ClassRepository.create_baseline_repository()
	if repository == null:
		return null
	var def: ClassDefinition = repository.get_class_definition(class_id)
	if def == null:
		return null
	# Mirror RunStartCommand._resolve_starting_kit VERBATIM: the resolved weapon/support ids + baseline_hp + the
	# two passive-id references, recorded from the class definition. A pure read — no RNG, no mutation, no command.
	return StartingKit.new(
		class_id,
		def.starting_weapon_id,
		def.starting_support_id,
		def.baseline_hp,
		def.class_passive_id,
		def.equipment_synergy_passive_id
	)
