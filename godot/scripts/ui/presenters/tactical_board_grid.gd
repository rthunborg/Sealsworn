extends Control

# Story 13.1 (AC1/AC2) — the tile-grid DRAW surface + tap forwarder hosted inside the tactical board region.
# It is a THIN presentation Control: it draws the precomputed op list the TacticalBoardPresenter builds from
# the board VM + the SHARED TacticalBoardZoomState geometry, and forwards a tap PIXEL (local to this Control)
# to the presenter via `cell_tapped`. It owns NO tactical truth and NO geometry math — the fit/hit-test/route
# DECISIONS live in the tested RefCounted seams (TacticalBoardGridFit / TacticalBoardZoomState /
# TacticalBoardTapRouter); this surface only paints what it is told and reports where it was tapped.
#
# Draw discipline (project-context perf rule): ONE draw pass per render() via queue_redraw() — never per-frame
# in _process. Godot's default emulate_mouse_from_touch makes a single InputEventMouseButton handler cover the
# desktop click AND the mobile tap, so there is no separate touch handler to double-fire.

signal cell_tapped(local_position: Vector2)

# Each op is a Dictionary tagged by `kind`:
#   {kind: "fill",    rect: Rect2, color: Color}                     — a filled rect (fog / fallback tile / HP bar)
#   {kind: "texture", rect: Rect2, texture: Texture2D, modulate: Color} — an approved-art tile / sprite
#   {kind: "outline", rect: Rect2, color: Color, width: float}      — a non-color pattern channel (grid / hazard / hero)
# The presenter appends them in paint order (fog/tiles -> occupants -> overlays), so this surface just replays them.
var _ops: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_ops(ops: Array) -> void:
	_ops = ops
	queue_redraw()


func clear_ops() -> void:
	if _ops.is_empty():
		queue_redraw()
		return
	_ops = []
	queue_redraw()


func _draw() -> void:
	for op_value: Variant in _ops:
		if not op_value is Dictionary:
			continue
		var op: Dictionary = op_value
		match String(op.get("kind", "")):
			"fill":
				draw_rect(_rect(op), op.get("color", Color.WHITE), true)
			"texture":
				var texture: Variant = op.get("texture")
				if texture is Texture2D:
					draw_texture_rect(texture, _rect(op), false, op.get("modulate", Color.WHITE))
			"outline":
				draw_rect(_rect(op), op.get("color", Color.WHITE), false, float(op.get("width", 1.0)))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			cell_tapped.emit(button.position)
			accept_event()


func _rect(op: Dictionary) -> Rect2:
	var rect_value: Variant = op.get("rect", Rect2())
	if rect_value is Rect2:
		return rect_value
	return Rect2()
