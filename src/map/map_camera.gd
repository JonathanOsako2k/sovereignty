class_name MapCamera
extends Camera2D
## Pan/zoom camera for the map. Handles mouse, wheel, trackpad gestures and
## two-finger pinch. A press-and-release without movement is reported as a tap.
##
## Single-finger touch arrives as emulated mouse events (Godot's default
## emulate_mouse_from_touch), so touch is only read directly for pinching.
##
## The world wraps east-west: panning sideways never stops, and the camera's x
## is kept within [0, map width) (MapView draws neighbouring copies of the map).

signal tapped(map_pos: Vector2)
signal view_changed
## Select mode: a one-finger drag draws a box (screen points) instead of panning.
signal box_dragged(from: Vector2, to: Vector2)
signal box_selected(from: Vector2, to: Vector2)

const TAP_SLOP := 14.0
const WHEEL_STEP := 1.15
const MAX_ZOOM := 8.0
const KEY_PAN_SPEED := 900.0

## While on, dragging selects (armies) instead of moving the map; two fingers
## still pinch and zoom.
var select_mode := false

var map_size := Vector2(1600, 1000)
var min_zoom := 0.5

var _dragging := false
var _moved := false
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _touches: Dictionary = {}  # touch index -> screen position
var _gesture_had_multitouch := false
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0
var _pinch_anchor := Vector2.ZERO


func setup(p_map_size: Vector2) -> void:
	map_size = p_map_size
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	position_smoothing_enabled = false
	get_viewport().size_changed.connect(_on_viewport_resized)
	_update_min_zoom()
	recenter()


func view_size() -> Vector2:
	return get_viewport_rect().size


func screen_to_map(screen_pos: Vector2) -> Vector2:
	return position + (screen_pos - view_size() * 0.5) / zoom.x


func map_to_screen(map_pos: Vector2) -> Vector2:
	return (map_pos - position) * zoom.x + view_size() * 0.5


func recenter() -> void:
	_apply(map_size * 0.5, min_zoom)


func zoom_by(factor: float, screen_pos: Variant = null) -> void:
	var anchor_screen: Vector2 = screen_pos if screen_pos != null else view_size() * 0.5
	var anchor_map := screen_to_map(anchor_screen)
	var z := clampf(zoom.x * factor, min_zoom, MAX_ZOOM)
	_apply(anchor_map - (anchor_screen - view_size() * 0.5) / z, z)


func focus_on(map_pos: Vector2, z := -1.0) -> void:
	_apply(map_pos, zoom.x if z <= 0.0 else clampf(z, min_zoom, MAX_ZOOM))


func _apply(center: Vector2, z: float) -> void:
	zoom = Vector2(z, z)
	var half_height := view_size().y * 0.5 / z
	if half_height * 2.0 >= map_size.y:
		center.y = map_size.y * 0.5
	else:
		center.y = clampf(center.y, half_height, map_size.y - half_height)
	center.x = fposmod(center.x, map_size.x)
	position = center
	view_changed.emit()


## Fully zoomed out the map fills the screen height, and the view is never wider
## than one copy of the world (so each place appears at most once on screen).
func _update_min_zoom() -> void:
	var vs := view_size()
	min_zoom = maxf(vs.y / map_size.y, vs.x / map_size.x)


func _on_viewport_resized() -> void:
	_update_min_zoom()
	_apply(position, maxf(zoom.x, min_zoom))


func _process(delta: float) -> void:
	# Desktop convenience: arrow keys / WASD pan.
	var dir := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
	if dir != Vector2.ZERO and get_viewport().gui_get_focus_owner() == null:
		_apply(position + dir * KEY_PAN_SPEED * delta / zoom.x, zoom.x)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_update_pinch()
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor, event.position)
	elif event is InputEventPanGesture:
		_apply(position + event.delta * 12.0 / zoom.x, zoom.x)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_EQUAL, KEY_KP_ADD:
				zoom_by(WHEEL_STEP)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom_by(1.0 / WHEEL_STEP)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			_gesture_had_multitouch = true
			_begin_pinch()
	else:
		_touches.erase(event.index)
		if _touches.size() == 1:
			# Resume single-finger panning from the remaining finger.
			_last_pos = _touches.values()[0]


func _begin_pinch() -> void:
	var pts: Array = _touches.values()
	_pinch_start_distance = maxf(pts[0].distance_to(pts[1]), 1.0)
	_pinch_start_zoom = zoom.x
	_pinch_anchor = screen_to_map((pts[0] + pts[1]) * 0.5)


func _update_pinch() -> void:
	var pts: Array = _touches.values()
	var mid: Vector2 = (pts[0] + pts[1]) * 0.5
	var z := clampf(_pinch_start_zoom * pts[0].distance_to(pts[1]) / _pinch_start_distance, min_zoom, MAX_ZOOM)
	# Keep the map point that started under the fingers' midpoint under it.
	_apply(_pinch_anchor - (mid - view_size() * 0.5) / z, z)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_dragging = true
				_moved = false
				_press_pos = event.position
				_last_pos = event.position
				if _touches.size() <= 1:
					_gesture_had_multitouch = false
			elif _dragging:
				_dragging = false
				var is_tap := not _moved and not _gesture_had_multitouch and event.button_index == MOUSE_BUTTON_LEFT
				if is_tap:
					tapped.emit(screen_to_map(event.position))
				elif select_mode and _moved and not _gesture_had_multitouch:
					box_selected.emit(_press_pos, event.position)
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_by(WHEEL_STEP, event.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_by(1.0 / WHEEL_STEP, event.position)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _dragging or _touches.size() >= 2:
		return
	if not _moved and event.position.distance_to(_press_pos) > TAP_SLOP:
		_moved = true
	if _moved and select_mode and not _gesture_had_multitouch:
		box_dragged.emit(_press_pos, event.position)
	elif _moved:
		_apply(position - (event.position - _last_pos) / zoom.x, zoom.x)
	_last_pos = event.position
