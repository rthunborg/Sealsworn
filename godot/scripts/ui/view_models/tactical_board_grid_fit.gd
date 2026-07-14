class_name TacticalBoardGridFit
extends RefCounted

# Story 13.1 (AC2/AC4) — the PURE, SCENE-FREE grid-fit helper. It computes the square cell size + the
# centered origin that fit a board_width x board_height tile grid into the dominant board-region rect, and
# hands back a TacticalBoardZoomState (the ALREADY-tested pixel<->cell geometry seam, Story 2.4) built from
# that fit — so the DRAW (cell_rect) and the HIT-TEST (screen_to_cell) share ONE geometry object and can
# never disagree (the story's "draw and hit-test MUST share one geometry object" trap).
#
# It owns NO tactical truth, executes NO command, draws ZERO RNG, and adds NO board-VM key. An empty board
# (0-width / 0-height — the between-levels null-board VM) reports available == false so the presenter draws
# NOTHING instead of dividing by zero. This is the AC4 "any new fit/geometry helper is a RefCounted with a
# pinned contract" seam; it is unit-tested without a SceneTree.

const TacticalBoardZoomState = preload("res://scripts/ui/view_models/tactical_board_zoom_state.gd")

var _board_size: Vector2i = Vector2i.ZERO
var _region_position: Vector2 = Vector2.ZERO
var _region_size: Vector2 = Vector2.ZERO
var _cell_size: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _available: bool = false
var _reason: String = "empty_board"

func _init(board_width: int, board_height: int, region: Variant = {}) -> void:
	_board_size = Vector2i(maxi(0, board_width), maxi(0, board_height))
	var rect: Rect2 = _rect_from_value(region)
	_region_position = rect.position
	_region_size = rect.size
	_compute()


# Fit a board_width x board_height grid into a region. `region` accepts a Rect2 or a {x, y, width, height}
# dictionary (the TacticalLayoutProfile region shape) in the DRAW surface's LOCAL space (origin at 0,0 for a
# full-rect child Control).
static func from_region(board_width: int, board_height: int, region: Variant) -> TacticalBoardGridFit:
	return load("res://scripts/ui/view_models/tactical_board_grid_fit.gd").new(board_width, board_height, region)


func _compute() -> void:
	if _board_size.x <= 0 or _board_size.y <= 0:
		_available = false
		_reason = "empty_board"
		return
	if not _is_finite(_region_size.x) or not _is_finite(_region_size.y) or _region_size.x <= 0.0 or _region_size.y <= 0.0:
		_available = false
		_reason = "invalid_region"
		return
	var cell_from_width: float = _region_size.x / float(_board_size.x)
	var cell_from_height: float = _region_size.y / float(_board_size.y)
	_cell_size = minf(cell_from_width, cell_from_height)
	if not _is_finite(_cell_size) or _cell_size <= 0.0:
		_cell_size = 0.0
		_available = false
		_reason = "invalid_region"
		return
	var grid_size: Vector2 = Vector2(_cell_size * float(_board_size.x), _cell_size * float(_board_size.y))
	_origin = _region_position + (_region_size - grid_size) * 0.5
	_available = true
	_reason = "valid"


func available() -> bool:
	return _available


func reason() -> String:
	return _reason


func cell_size() -> float:
	return _cell_size


func origin() -> Vector2:
	return _origin


func board_size() -> Vector2i:
	return _board_size


func grid_size() -> Vector2:
	return Vector2(_cell_size * float(_board_size.x), _cell_size * float(_board_size.y))


# Build the SHARED geometry object used for BOTH the tile draw (cell_rect) and the tap hit-test
# (screen_to_cell). Reuses the tested TacticalBoardZoomState (Story 2.4) at zoom 1.0 — this story extends its
# USE, not its math. Returns null when the fit is unavailable (an empty / degenerate board).
func to_zoom_state(viewport_size: Vector2 = Vector2.ZERO) -> TacticalBoardZoomState:
	if not _available:
		return null
	var resolved_viewport: Vector2 = viewport_size
	if not _is_finite(resolved_viewport.x) or not _is_finite(resolved_viewport.y) or resolved_viewport.x <= 0.0 or resolved_viewport.y <= 0.0:
		resolved_viewport = _region_position + _region_size
	return TacticalBoardZoomState.from_options({
		"board_width": _board_size.x,
		"board_height": _board_size.y,
		"cell_size": Vector2(_cell_size, _cell_size),
		"origin": _origin,
		"viewport_size": resolved_viewport
	})


func to_dictionary() -> Dictionary:
	return {
		"available": _available,
		"reason": _reason,
		"cell_size": _cell_size,
		"origin": _point(_origin),
		"board_size": _point(Vector2(float(_board_size.x), float(_board_size.y))),
		"grid_size": _point(grid_size())
	}


static func _rect_from_value(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	if value is Rect2i:
		var rect_i: Rect2i = value
		return Rect2(float(rect_i.position.x), float(rect_i.position.y), float(rect_i.size.x), float(rect_i.size.y))
	if value is Dictionary:
		var data: Dictionary = value
		return Rect2(
			float(_field(data, &"x", 0.0)),
			float(_field(data, &"y", 0.0)),
			float(_field(data, &"width", 0.0)),
			float(_field(data, &"height", 0.0))
		)
	return Rect2()


static func _field(data: Dictionary, key: StringName, fallback: Variant) -> Variant:
	if data.has(String(key)):
		return data[String(key)]
	if data.has(key):
		return data[key]
	return fallback


static func _point(point: Vector2) -> Dictionary:
	return {
		"x": point.x,
		"y": point.y
	}


static func _is_finite(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
