class_name TacticalBoardTapRouter
extends RefCounted

# Story 13.1 (AC2/AC4) — the PURE, SCENE-FREE tap-routing DECISION seam. Given a hit-test mapping (the
# TacticalBoardZoomState.screen_to_cell result) and the board VM read (cells + occupants), it decides the
# player's tap INTENT — move / attack / inspect / none — so the presenter can route it into the EXISTING
# interactive_* board-presenter seams. It invents NO command, mutates NOTHING, draws ZERO RNG, and reads
# ONLY the VM's already-pinned fields (no new board-VM key).
#
# IMPORTANT — this seam picks the INTENT, not the legality: an "empty_reachable" move whose path is actually
# too far is still routed to interactive_submit_move, where the MoveCommand fail-closes (rejects, mutates
# nothing, no turn advance) — the command owns reachability, this seam owns the move-vs-attack-vs-inspect
# choice (the story's "put the DECISION in a RefCounted seam" AC4 requirement). The two-step attack arm ->
# commit lives inside the session's TacticalAttackCommitFlow; a tap on an already-armed enemy cell is the
# CONFIRMING commit (is_commit == true), a first tap on an enemy arms the preview — both route to attack.

const INTENT_MOVE := "move"
const INTENT_ATTACK := "attack"
const INTENT_INSPECT := "inspect"
const INTENT_NONE := "none"

const ENTITY_TYPE_ENEMY := "enemy"


# Decide the tap intent. `cell_mapping` is the screen_to_cell result ({available, cell:{x,y}, ...});
# `board_vm` is TacticalBoardViewModel.to_dictionary(); `armed_attack_cell` is the currently-armed attack
# target (a Vector2i or {x,y} dict, or null when no attack is armed) so a re-tap on the armed enemy reports
# is_commit == true. An unavailable mapping (out-of-bounds / invalid-geometry / NaN) is a safe no-op.
static func decide(cell_mapping: Dictionary, board_vm: Dictionary, armed_attack_cell: Variant = null) -> Dictionary:
	if not bool(cell_mapping.get("available", false)):
		return _decision(INTENT_NONE, {}, false, "unavailable")

	var cell: Dictionary = _cell_dict(cell_mapping.get("cell", {}))

	# An occupant on the tapped cell decides move-vs-attack-vs-inspect first. Occupants come pre-filtered to
	# VISIBLE occupied cells by the VM — do not re-derive visibility.
	var occupant: Dictionary = _occupant_at(board_vm, cell)
	if not occupant.is_empty():
		if String(occupant.get("entity_type", "")) == ENTITY_TYPE_ENEMY and bool(occupant.get("is_alive", false)):
			var is_commit: bool = _same_cell(armed_attack_cell, cell)
			return _decision(INTENT_ATTACK, cell, is_commit, "commit" if is_commit else "arm")
		# The hero's own cell (a player-faction occupant) or a non-attackable body -> inspect (safe, no mutation).
		return _decision(INTENT_INSPECT, cell, false, "occupant_inspect")

	# No occupant: fall back to the cell terrain/visibility. A hidden/memory cell (or a cell not in the VM)
	# cannot be a confident move target -> inspect. A visible, occupancy-blocking cell (a wall) -> inspect.
	var cell_view: Dictionary = _cell_view_at(board_vm, cell)
	if String(cell_view.get("visibility_state", "hidden")) != "visible":
		return _decision(INTENT_INSPECT, cell, false, "not_visible")
	if bool(cell_view.get("terrain_blocks_occupancy", false)):
		return _decision(INTENT_INSPECT, cell, false, "blocked_terrain")
	return _decision(INTENT_MOVE, cell, false, "empty_reachable")


static func _decision(intent: String, cell: Dictionary, is_commit: bool, reason: String) -> Dictionary:
	return {
		"intent": intent,
		"available": intent != INTENT_NONE,
		"cell": cell.duplicate(true),
		"is_commit": is_commit,
		"reason": reason
	}


static func _cell_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		var data: Dictionary = value
		return {
			"x": int(_field(data, &"x", 0)),
			"y": int(_field(data, &"y", 0))
		}
	if value is Vector2i:
		var vector: Vector2i = value
		return {
			"x": vector.x,
			"y": vector.y
		}
	return {
		"x": 0,
		"y": 0
	}


static func _occupant_at(board_vm: Dictionary, cell: Dictionary) -> Dictionary:
	var occupants: Variant = board_vm.get("occupants", [])
	if not occupants is Array:
		return {}
	for occ_value: Variant in occupants:
		if not occ_value is Dictionary:
			continue
		var occ: Dictionary = occ_value
		if _same_cell(occ.get("position", {}), cell):
			return occ
	return {}


static func _cell_view_at(board_vm: Dictionary, cell: Dictionary) -> Dictionary:
	var cells: Variant = board_vm.get("cells", [])
	if not cells is Array:
		return {}
	for cell_value: Variant in cells:
		if not cell_value is Dictionary:
			continue
		var cell_view: Dictionary = cell_value
		if _same_cell(cell_view.get("position", {}), cell):
			return cell_view
	return {}


static func _same_cell(candidate: Variant, cell: Dictionary) -> bool:
	var target_x: int = int(_field(cell, &"x", -2147483648))
	var target_y: int = int(_field(cell, &"y", -2147483648))
	if candidate is Vector2i:
		var vector: Vector2i = candidate
		return vector.x == target_x and vector.y == target_y
	if candidate is Dictionary:
		var data: Dictionary = candidate
		if not (data.has("x") or data.has(&"x")) or not (data.has("y") or data.has(&"y")):
			return false
		return int(_field(data, &"x", -2147483648)) == target_x and int(_field(data, &"y", -2147483648)) == target_y
	return false


static func _field(data: Dictionary, key: StringName, fallback: Variant) -> Variant:
	if data.has(String(key)):
		return data[String(key)]
	if data.has(key):
		return data[key]
	return fallback
