class_name RuleTrigger
extends RefCounted

# The fixed trigger-window vocabulary for the Sealsworn rules kernel (Story 5.4). This is the SINGLE
# SOURCE OF TRUTH for the ten named windows from the architecture's rules-kernel design
# ([game-architecture.md] Rules And Effects / Rules Kernel Pattern). A passive (and, later, any rule)
# DECLARES the trigger window(s) it fires in from THIS allowlist; PassiveDefinition.validate() reuses
# is_valid_window(...) so a passive can never declare a window outside the fixed vocabulary.
#
# Story 5.4 introduces ONLY this vocabulary + the RulesResolver that collects registered passives by
# window. The combat HOOK sites that ACTUALLY fire these windows (before_attack wired into AttackCommand,
# etc.) are Story 5.5 + Epic 6 — 5.4 owns the registration + the explainable trigger-window RESOLUTION
# seam, not the per-effect operation. Do NOT add windows outside this fixed vocabulary; do NOT renumber
# or rename them (a later epic wires hook sites against these exact ids).
#
# It is a scene-free static-const file (no Node/scene/autoload). The ids are lower_snake StringNames held
# in UPPER_SNAKE consts (the project naming rule).

const RUN_STARTED := &"run_started"
const LEVEL_ENTERED := &"level_entered"
const TURN_STARTED := &"turn_started"
const BEFORE_MOVE := &"before_move"
const AFTER_MOVE := &"after_move"
const BEFORE_ATTACK := &"before_attack"
const DAMAGE_CALCULATED := &"damage_calculated"
const ENEMY_KILLED := &"enemy_killed"
const REWARD_OFFERED := &"reward_offered"
const LEVEL_COMPLETED := &"level_completed"

# The allowlist of every valid trigger window, in the architecture's fixed declaration order. Used by
# is_valid_window(...) and by tests pinning the vocabulary. A duplicate or out-of-vocabulary window id is
# rejected.
const WINDOWS: Array[StringName] = [
	RUN_STARTED,
	LEVEL_ENTERED,
	TURN_STARTED,
	BEFORE_MOVE,
	AFTER_MOVE,
	BEFORE_ATTACK,
	DAMAGE_CALCULATED,
	ENEMY_KILLED,
	REWARD_OFFERED,
	LEVEL_COMPLETED
]

# True when `window_id` is one of the ten fixed trigger windows. PassiveDefinition.validate() calls this
# for EACH declared window (the "explicit trigger windows" AC1 demands). A non-StringName/empty/unknown id
# is rejected.
static func is_valid_window(window_id: StringName) -> bool:
	return WINDOWS.has(window_id)
