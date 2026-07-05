extends "res://scripts/run/run_state.gd"

# Story 11.2 (AC4 Task 4) — a TEST-ONLY RunState subclass that FORCES CompleteRunCommand._resolve_completed's step-2
# transition (NODE_RESOLUTION -> COMPLETED) to FAIL while letting step 1 (ACTIVE_ROUTE -> NODE_RESOLUTION) succeed, so the
# otherwise-UNREACHABLE atomicity restore (run.phase = phase_before at complete_run_command.gd:243) is DRIVEN for real.
#
# WHY A SUBCLASS: the two-step's step-2 edge is ALWAYS legal from NODE_RESOLUTION (RunState._legal_next_phases), so the
# restore never fires in the live flow — it is a defensive-correctness branch (the Epic-9 retro T3 item). The live victory
# path (AC3) drives the ACTIVE_ROUTE -> NODE_RESOLUTION -> COMPLETED two-step for real, so this forcing seam makes step 2
# reject (ONLY the COMPLETED target) to prove the command restores the run to byte-identical phase_before (ACTIVE_ROUTE) on
# a step-2 failure. It overrides ONLY transition_to for the COMPLETED target; every other transition (incl. step 1)
# delegates to the real RunState.transition_to unchanged, and can_transition_to is UNCHANGED so CompleteRunCommand.validate()
# still classifies + admits the completion normally. The test builds + seats it (no self-referencing factory here).

# The target phase whose transition is forced to fail (the step-2 COMPLETED edge).
const FORCED_FAIL_PHASE := &"completed"

# Records that the step-2 rejection actually fired (the test asserts it — proves step 2 was reached, not a step-1 short).
var forced_step_two_rejected: bool = false


# Override: reject ONLY the COMPLETED transition (step 2); delegate everything else to the real RunState.transition_to. The
# rejection mirrors the real transition_to error shape (a structured ActionResult, ZERO mutation) so the command's step-2
# failure branch runs its restore exactly as a genuine illegal edge would.
func transition_to(next_phase: StringName):
	if next_phase == FORCED_FAIL_PHASE:
		forced_step_two_rejected = true
		return ActionResult.error(&"invalid_run_transition", {
			"from": String(phase),
			"to": String(next_phase),
			"forced": true
		})
	return super(next_phase)
