class_name TouchVirtualJoystick
extends Control

## VirtualJoystick.gd
## Touch-based virtual analog stick for mobile and web touchscreen platforms.
## Calculates normalized direction vector and handles touch drag/release with deadzone.

signal movement_vector_changed(vector: Vector2)

@export var max_radius: float = 40.0
@export var deadzone: float = 0.1
@export var base_color: Color = Color(0.2, 0.25, 0.35, 0.5)
@export var handle_color: Color = Color(0.85, 0.9, 1.0, 0.8)

var _is_touching: bool = false
var _touch_index: int = -1
var _center_position: Vector2 = Vector2.ZERO
var _handle_offset: Vector2 = Vector2.ZERO
var _current_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Ensure control accepts mouse/touch input
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center_position = size / 2.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_center_position = size / 2.0
		queue_redraw()


func _draw() -> void:
	# Draw outer base ring
	draw_circle(_center_position, max_radius, base_color)
	draw_arc(_center_position, max_radius, 0.0, TAU, 32, base_color.lightened(0.3), 2.0)

	# Draw inner touch handle knob
	var knob_pos := _center_position + _handle_offset
	draw_circle(knob_pos, max_radius * 0.4, handle_color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not _is_touching:
			_start_touch(event.index, event.position)
			accept_event()
		elif not event.pressed and event.index == _touch_index:
			_end_touch()
			accept_event()

	elif event is InputEventScreenDrag:
		if _is_touching and event.index == _touch_index:
			_update_handle(event.position)
			accept_event()

	# Also support mouse drag for desktop debugging/testing
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not _is_touching:
				_start_touch(0, event.position)
				accept_event()
			elif not event.pressed and _is_touching:
				_end_touch()
				accept_event()

	elif event is InputEventMouseMotion:
		if _is_touching and _touch_index == 0:
			_update_handle(event.position)
			accept_event()


func _start_touch(index: int, touch_pos: Vector2) -> void:
	_is_touching = true
	_touch_index = index
	_update_handle(touch_pos)


func _update_handle(target_pos: Vector2) -> void:
	var delta := target_pos - _center_position
	var distance := delta.length()

	if distance > max_radius:
		_handle_offset = delta.normalized() * max_radius
	else:
		_handle_offset = delta

	# Deadzone calculation
	var normalized_dist := _handle_offset.length() / max_radius
	if normalized_dist < deadzone:
		_current_vector = Vector2.ZERO
	else:
		_current_vector = _handle_offset.normalized() * ((normalized_dist - deadzone) / (1.0 - deadzone))

	movement_vector_changed.emit(_current_vector)
	queue_redraw()


func _end_touch() -> void:
	_is_touching = false
	_touch_index = -1
	_handle_offset = Vector2.ZERO
	_current_vector = Vector2.ZERO
	movement_vector_changed.emit(Vector2.ZERO)
	queue_redraw()


func get_current_vector() -> Vector2:
	return _current_vector
