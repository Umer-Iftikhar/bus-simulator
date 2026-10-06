class_name TouchSteeringWheel
extends Control
## On-screen steering wheel: drag around the rim to turn it; it springs back
## to centre when released. [member steer] is -1 (full left) .. 1 (full right).

const RETURN_SPEED := 6.0

var max_angle := SteeringWheelMath.DEFAULT_MAX_ANGLE
var wheel_angle := 0.0
var steer: float:
	get:
		return SteeringWheelMath.angle_to_steer(wheel_angle, max_angle)

var _touch_index := -1
var _last_pointer := 0.0


func _init(diameter := 230.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_held() -> bool:
	return _touch_index != -1


func _center() -> Vector2:
	return size / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_last_pointer = SteeringWheelMath.pointer_angle(_center(), touch.position)
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			var pointer := SteeringWheelMath.pointer_angle(_center(), drag.position)
			wheel_angle = SteeringWheelMath.accumulate(
				wheel_angle, _last_pointer, pointer, max_angle
			)
			_last_pointer = pointer
			queue_redraw()
			accept_event()


func _process(delta: float) -> void:
	if _touch_index == -1 and not is_zero_approx(wheel_angle):
		wheel_angle = move_toward(wheel_angle, 0.0, RETURN_SPEED * delta)
		queue_redraw()


func _draw() -> void:
	var c := _center()
	var radius := minf(size.x, size.y) / 2.0 - 6.0
	draw_circle(c, radius, Color(0.08, 0.08, 0.1, 0.45))
	draw_arc(c, radius, 0.0, TAU, 64, Color(0.9, 0.9, 0.9, 0.85), 14.0, true)
	for spoke in [-PI / 2.0, PI / 2.0, PI]:
		var dir := Vector2.from_angle(spoke + wheel_angle)
		draw_line(c, c + dir * radius, Color(0.9, 0.9, 0.9, 0.7), 10.0, true)
	var marker := Vector2.from_angle(-PI / 2.0 + wheel_angle) * radius
	draw_circle(c + marker, 10.0, Color(1.0, 0.6, 0.1))
	draw_circle(c, radius * 0.22, Color(0.2, 0.2, 0.22, 0.9))
