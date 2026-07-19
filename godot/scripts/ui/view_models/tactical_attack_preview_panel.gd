class_name TacticalAttackPreviewPanel
extends RefCounted

# Story 14.2 (AC1/AC3 — the F2 fix) — the PURE, SCENE-FREE armed-attack PANEL projection seam. Given a board VM
# read (TacticalBoardViewModel.to_dictionary()), it decides whether an attack is currently ARMED and, if so,
# projects the render-ready panel data the presenter draws: the target cell, the expected damage, the weapon
# reach/shape, the line-of-fire blocker state, the adjacent-ranged warnings, and the confirm/cancel enablement.
#
# It reads ONLY the pinned VM slots `preview` + `commit_flow` + `action_availability` (no new board-VM key, no new
# domain query — the preview was already computed when the attack armed and rides inside the commit-flow state).
# It invents NO command, mutates NOTHING (the input dict is never written), and draws ZERO RNG. The presenter is a
# thin Control that draws this output; the armed-vs-not DECISION and the panel content live here and are unit-tested.
#
# NFR9 (accessibility): `is_armed` + `armed_label` are the NON-COLOR channel — a text label ("ARMED: attack <enemy>
# — <dmg> dmg"), never a hue alone. Every panel line is plain color-independent text.

# The EXACT key set of from_board_vm() (the exact-key discipline — a key never silently appears/vanishes; a test pins it).
const PANEL_KEYS: Array[String] = [
	"is_armed",
	"target_cell",
	"lines",
	"expected_damage",
	"weapon_reach",
	"targeting_shape",
	"blocker_state",
	"warnings",
	"confirm_enabled",
	"cancel_enabled",
	"armed_label"
]

const KIND_ATTACK := "attack"
const MODE_ATTACK_PREVIEW := "attack_preview"


# Project the armed-attack panel from the pinned VM slots. An un-armed board (no attack_preview commit flow, or a
# non-attack preview) projects the empty panel (is_armed == false, no target, no lines) so the presenter renders the
# honest "nothing armed" state, never a fabricated preview.
static func from_board_vm(board_vm: Dictionary) -> Dictionary:
	var preview: Dictionary = _dict(board_vm.get("preview", {}))
	var commit_flow: Dictionary = _dict(board_vm.get("commit_flow", {}))
	var availability: Dictionary = _dict(board_vm.get("action_availability", {}))
	var is_armed: bool = (
		String(preview.get("kind", "")) == KIND_ATTACK
		and String(commit_flow.get("mode", "")) == MODE_ATTACK_PREVIEW
	)
	if not is_armed:
		return _unarmed()

	var metadata: Dictionary = _dict(preview.get("metadata", {}))
	var target_cell: Variant = _cell_or_null(preview.get("target_cell"))
	var target_entity_id: String = String(preview.get("target_entity_id", ""))
	var expected_damage: int = int(metadata.get("expected_damage", metadata.get("expected_base_damage", 0)))
	var weapon_reach: int = int(metadata.get("weapon_reach", 0))
	var targeting_shape: String = String(metadata.get("targeting_shape", ""))
	var blocker_state: String = String(metadata.get("blocker_state", ""))
	var warnings: Array = _warning_texts(metadata.get("warnings", []))
	var confirm_enabled: bool = bool(_entry(availability, "confirm").get("enabled", false))
	var cancel_enabled: bool = bool(_entry(availability, "cancel").get("enabled", false))
	var armed_label: String = "ARMED: attack %s — %d dmg" % [_target_label(target_entity_id, target_cell), expected_damage]
	var lines: Array = _lines(target_entity_id, target_cell, expected_damage, weapon_reach, targeting_shape, blocker_state, warnings)

	return {
		"is_armed": true,
		"target_cell": target_cell,
		"lines": lines,
		"expected_damage": expected_damage,
		"weapon_reach": weapon_reach,
		"targeting_shape": targeting_shape,
		"blocker_state": blocker_state,
		"warnings": warnings,
		"confirm_enabled": confirm_enabled,
		"cancel_enabled": cancel_enabled,
		"armed_label": armed_label
	}


static func _unarmed() -> Dictionary:
	return {
		"is_armed": false,
		"target_cell": null,
		"lines": [],
		"expected_damage": 0,
		"weapon_reach": 0,
		"targeting_shape": "",
		"blocker_state": "",
		"warnings": [],
		"confirm_enabled": false,
		"cancel_enabled": false,
		"armed_label": ""
	}


static func _lines(
	entity_id: String,
	cell: Variant,
	damage: int,
	reach: int,
	shape: String,
	blocker_state: String,
	warnings: Array
) -> Array:
	var lines: Array = []
	lines.append("Target: %s" % _target_label(entity_id, cell))
	lines.append("Expected damage: %d" % damage)
	if shape.is_empty():
		lines.append("Weapon reach: %d" % reach)
	else:
		lines.append("Weapon reach: %d (%s)" % [reach, shape])
	if not blocker_state.is_empty():
		lines.append("Line of fire: %s" % blocker_state)
	for warning_text: Variant in warnings:
		lines.append("Warning: %s" % String(warning_text))
	return lines


static func _target_label(entity_id: String, cell: Variant) -> String:
	if not entity_id.is_empty():
		return entity_id
	if cell is Dictionary:
		var data: Dictionary = cell
		return "(%d,%d)" % [int(data.get("x", 0)), int(data.get("y", 0))]
	return "target"


static func _warning_texts(value: Variant) -> Array:
	var result: Array = []
	if not value is Array:
		return result
	for entry_value: Variant in value:
		if entry_value is Dictionary:
			var entry: Dictionary = entry_value
			var text: String = String(entry.get("text", ""))
			if text.is_empty():
				text = String(entry.get("id", ""))
			if not text.is_empty():
				result.append(text)
		elif entry_value is String or entry_value is StringName:
			var raw: String = String(entry_value)
			if not raw.is_empty():
				result.append(raw)
	return result


static func _entry(availability: Dictionary, key: String) -> Dictionary:
	var value: Variant = availability.get(key, {})
	return value if value is Dictionary else {}


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _cell_or_null(value: Variant) -> Variant:
	if value is Vector2i:
		var vector: Vector2i = value
		return {"x": vector.x, "y": vector.y}
	if value is Dictionary:
		var data: Dictionary = value
		if (data.has("x") or data.has(&"x")) and (data.has("y") or data.has(&"y")):
			return {"x": int(_num(data, "x")), "y": int(_num(data, "y"))}
	return null


static func _num(data: Dictionary, key: String) -> int:
	if data.has(key):
		return int(data[key])
	if data.has(StringName(key)):
		return int(data[StringName(key)])
	return 0
