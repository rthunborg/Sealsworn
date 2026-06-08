class_name TacticalBoardZoomState
extends RefCounted

const TacticalPreviewView = preload("res://scripts/ui/view_models/tactical_preview_view.gd")

const DEFAULT_BOARD_SIZE: Vector2i = Vector2i.ZERO
const DEFAULT_CELL_SIZE: Vector2 = Vector2(64.0, 64.0)
const DEFAULT_VIEWPORT_SIZE: Vector2 = Vector2(390.0, 844.0)
const DEFAULT_ORIGIN: Vector2 = Vector2.ZERO
const DEFAULT_ZOOM: float = 1.0
const DEFAULT_MIN_ZOOM: float = 0.75
const DEFAULT_MAX_ZOOM: float = 2.0

var _board_size: Vector2i = DEFAULT_BOARD_SIZE
var _cell_size: Vector2 = DEFAULT_CELL_SIZE
var _viewport_size: Vector2 = DEFAULT_VIEWPORT_SIZE
var _origin: Vector2 = DEFAULT_ORIGIN
var _zoom: float = DEFAULT_ZOOM
var _min_zoom: float = DEFAULT_MIN_ZOOM
var _max_zoom: float = DEFAULT_MAX_ZOOM
var _focused_cell: Variant = null
var _reason: String = "valid"
var _cue_ids: Array[String] = ["zoom_valid"]

func _init(options: Dictionary = {}) -> void:
	_board_size = _board_size_from_options(options)
	_cell_size = _positive_vector2(TacticalPreviewView.field(options, &"cell_size", DEFAULT_CELL_SIZE), DEFAULT_CELL_SIZE)
	_viewport_size = _positive_vector2(TacticalPreviewView.field(options, &"viewport_size", DEFAULT_VIEWPORT_SIZE), DEFAULT_VIEWPORT_SIZE)
	_origin = _vector2_from_value(TacticalPreviewView.field(options, &"origin", DEFAULT_ORIGIN), DEFAULT_ORIGIN)
	_min_zoom = _positive_float(TacticalPreviewView.field(options, &"min_zoom", DEFAULT_MIN_ZOOM), DEFAULT_MIN_ZOOM)
	_max_zoom = _positive_float(TacticalPreviewView.field(options, &"max_zoom", DEFAULT_MAX_ZOOM), DEFAULT_MAX_ZOOM)
	if _max_zoom < _min_zoom:
		_max_zoom = _min_zoom
	var zoom_result: Dictionary = _clamped_zoom(TacticalPreviewView.field(options, &"zoom", DEFAULT_ZOOM), _min_zoom, _max_zoom)
	_zoom = float(zoom_result.get("zoom", DEFAULT_ZOOM))
	_reason = String(zoom_result.get("reason", "valid"))
	_cue_ids = _cue_ids_for_reason(_reason)
	_focused_cell = _focused_cell_from_options(options)


func to_dictionary() -> Dictionary:
	return {
		"zoom": _zoom,
		"min_zoom": _min_zoom,
		"max_zoom": _max_zoom,
		"cell_size": _point(_cell_size),
		"viewport_size": _point(_viewport_size),
		"origin": _point(_origin),
		"board_size": TacticalPreviewView.cell_metadata(_board_size),
		"focused_cell": {} if _focused_cell == null else TacticalPreviewView.cell_metadata(_focused_cell),
		"reason": _reason,
		"cue_ids": _cue_ids.duplicate()
	}


func screen_to_cell(screen_position: Vector2) -> Dictionary:
	if not _has_valid_geometry():
		return _disabled_mapping("invalid_geometry", Vector2i(-1, -1), screen_position)
	if not _is_finite(screen_position.x) or not _is_finite(screen_position.y):
		return _disabled_mapping("invalid_input", Vector2i(-1, -1), screen_position)
	var scaled_cell_size: Vector2 = _scaled_cell_size()
	var local_position: Vector2 = screen_position - _origin
	if local_position.x < 0.0 or local_position.y < 0.0:
		return _disabled_mapping("out_of_bounds", Vector2i(-1, -1), screen_position)
	var cell: Vector2i = Vector2i(
		int(floor(local_position.x / scaled_cell_size.x)),
		int(floor(local_position.y / scaled_cell_size.y))
	)
	if not _in_bounds(cell):
		return _disabled_mapping("out_of_bounds", cell, screen_position)
	return {
		"available": true,
		"reason": "valid",
		"cell": TacticalPreviewView.cell_metadata(cell),
		"screen_position": _point(screen_position),
		"zoom": _zoom
	}


func cell_to_screen(cell: Vector2i) -> Dictionary:
	if not _has_valid_geometry():
		return _disabled_mapping("invalid_geometry", cell, Vector2.ZERO)
	if not _in_bounds(cell):
		return _disabled_mapping("out_of_bounds", cell, Vector2.ZERO)
	var scaled_cell_size: Vector2 = _scaled_cell_size()
	var screen_position: Vector2 = _origin + Vector2(
		(float(cell.x) + 0.5) * scaled_cell_size.x,
		(float(cell.y) + 0.5) * scaled_cell_size.y
	)
	return {
		"available": true,
		"reason": "valid",
		"cell": TacticalPreviewView.cell_metadata(cell),
		"screen_position": _point(screen_position),
		"zoom": _zoom
	}


func cell_rect(cell: Vector2i) -> Dictionary:
	if not _has_valid_geometry():
		return _disabled_rect("invalid_geometry", cell)
	if not _in_bounds(cell):
		return _disabled_rect("out_of_bounds", cell)
	var scaled_cell_size: Vector2 = _scaled_cell_size()
	var position: Vector2 = _origin + Vector2(float(cell.x) * scaled_cell_size.x, float(cell.y) * scaled_cell_size.y)
	return {
		"available": true,
		"reason": "valid",
		"cell": TacticalPreviewView.cell_metadata(cell),
		"position": _point(position),
		"size": _point(scaled_cell_size),
		"zoom": _zoom
	}


func with_zoom(new_zoom: float, anchor_screen: Vector2 = Vector2.ZERO, focused_cell: Variant = null) -> TacticalBoardZoomState:
	var focus_cell: Vector2i = _resolved_focus_cell(anchor_screen, focused_cell)
	var zoom_result: Dictionary = _clamped_zoom(new_zoom, _min_zoom, _max_zoom)
	var resolved_zoom: float = float(zoom_result.get("zoom", _zoom))
	var scaled_cell_size: Vector2 = _cell_size * resolved_zoom
	var new_origin: Vector2 = anchor_screen - Vector2(
		(float(focus_cell.x) + 0.5) * scaled_cell_size.x,
		(float(focus_cell.y) + 0.5) * scaled_cell_size.y
	)
	return load("res://scripts/ui/view_models/tactical_board_zoom_state.gd").new({
		"board_size": _board_size,
		"cell_size": _cell_size,
		"viewport_size": _viewport_size,
		"origin": new_origin,
		"zoom": new_zoom,
		"min_zoom": _min_zoom,
		"max_zoom": _max_zoom,
		"focused_cell": focus_cell
	})


static func from_options(options: Dictionary = {}) -> TacticalBoardZoomState:
	return load("res://scripts/ui/view_models/tactical_board_zoom_state.gd").new(options)


func _resolved_focus_cell(anchor_screen: Vector2, focused_cell: Variant) -> Vector2i:
	var explicit_focus: Variant = focused_cell
	if explicit_focus == null:
		explicit_focus = _focused_cell
	var parsed_focus: Variant = _cell_from_value_or_null(explicit_focus)
	if parsed_focus is Vector2i and _in_bounds(parsed_focus):
		return parsed_focus
	var mapped: Dictionary = screen_to_cell(anchor_screen)
	if bool(mapped.get("available", false)):
		return _cell_from_value_or_null(mapped.get("cell", {}))
	return Vector2i.ZERO


func _has_valid_geometry() -> bool:
	return _board_size.x > 0 and _board_size.y > 0 and _cell_size.x > 0.0 and _cell_size.y > 0.0 and _zoom > 0.0


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _board_size.x and cell.y < _board_size.y


func _scaled_cell_size() -> Vector2:
	return _cell_size * _zoom


func _disabled_mapping(reason: String, cell: Vector2i, screen_position: Vector2) -> Dictionary:
	return {
		"available": false,
		"reason": reason,
		"cell": TacticalPreviewView.cell_metadata(cell),
		"screen_position": _point(screen_position),
		"zoom": _zoom
	}


func _disabled_rect(reason: String, cell: Vector2i) -> Dictionary:
	return {
		"available": false,
		"reason": reason,
		"cell": TacticalPreviewView.cell_metadata(cell),
		"position": _point(Vector2.ZERO),
		"size": _point(Vector2.ZERO),
		"zoom": _zoom
	}


static func _board_size_from_options(options: Dictionary) -> Vector2i:
	var board_size_value: Variant = TacticalPreviewView.field(options, &"board_size", null)
	var parsed_board_size: Variant = _cell_from_value_or_null(board_size_value)
	if parsed_board_size is Vector2i:
		return parsed_board_size
	var width: int = int(TacticalPreviewView.field(options, &"board_width", DEFAULT_BOARD_SIZE.x))
	var height: int = int(TacticalPreviewView.field(options, &"board_height", DEFAULT_BOARD_SIZE.y))
	return Vector2i(max(0, width), max(0, height))


static func _focused_cell_from_options(options: Dictionary) -> Variant:
	var focused_value: Variant = TacticalPreviewView.field(options, &"focused_cell", null)
	var parsed_focus: Variant = _cell_from_value_or_null(focused_value)
	if parsed_focus is Vector2i:
		return parsed_focus
	return null


static func _cell_from_value_or_null(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if value is Dictionary:
		var data: Dictionary = value
		if not TacticalPreviewView.has_field(data, &"x") or not TacticalPreviewView.has_field(data, &"y"):
			return null
		var x_value: Variant = TacticalPreviewView.field(data, &"x")
		var y_value: Variant = TacticalPreviewView.field(data, &"y")
		if not _is_numeric(x_value) or not _is_numeric(y_value):
			return null
		var x_float: float = float(x_value)
		var y_float: float = float(y_value)
		if not _is_finite(x_float) or not _is_finite(y_float):
			return null
		return Vector2i(
			int(x_float),
			int(y_float)
		)
	return null


static func _positive_vector2(value: Variant, fallback: Vector2) -> Vector2:
	var result: Vector2 = _vector2_from_value(value, fallback)
	if result.x <= 0.0 or result.y <= 0.0:
		return fallback
	return result


static func _vector2_from_value(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		var vector: Vector2 = value
		if _is_finite(vector.x) and _is_finite(vector.y):
			return vector
	if value is Vector2i:
		var vector_i: Vector2i = value
		return Vector2(float(vector_i.x), float(vector_i.y))
	if value is Dictionary:
		var data: Dictionary = value
		var x_value: Variant = TacticalPreviewView.field(data, &"x", fallback.x)
		var y_value: Variant = TacticalPreviewView.field(data, &"y", fallback.y)
		if _is_numeric(x_value) and _is_numeric(y_value):
			var parsed: Vector2 = Vector2(float(x_value), float(y_value))
			if _is_finite(parsed.x) and _is_finite(parsed.y):
				return parsed
	return fallback


static func _positive_float(value: Variant, fallback: float) -> float:
	if not _is_numeric(value):
		return fallback
	var numeric_value: float = float(value)
	if not _is_finite(numeric_value) or numeric_value <= 0.0:
		return fallback
	return numeric_value


static func _clamped_zoom(value: Variant, min_zoom: float, max_zoom: float) -> Dictionary:
	var numeric_value: float = _positive_float(value, DEFAULT_ZOOM)
	if numeric_value < min_zoom:
		return {
			"zoom": min_zoom,
			"reason": "clamped_min"
		}
	if numeric_value > max_zoom:
		return {
			"zoom": max_zoom,
			"reason": "clamped_max"
		}
	return {
		"zoom": numeric_value,
		"reason": "valid"
	}


static func _cue_ids_for_reason(reason: String) -> Array[String]:
	match reason:
		"clamped_min":
			return ["zoom_clamped_min"]
		"clamped_max":
			return ["zoom_clamped_max"]
		_:
			return ["zoom_valid"]


static func _point(point: Vector2) -> Dictionary:
	return {
		"x": point.x,
		"y": point.y
	}


static func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
