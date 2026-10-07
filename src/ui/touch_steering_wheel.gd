class_name TouchSteeringWheel
extends Control
## On-screen steering wheel: drag around the rim to turn it; it springs back
## to centre when released. [member steer] is -1 (full left) .. 1 (full right).

const RETURN_SPEED := 10.0

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
	ControlArt.wheel(self, _center(), minf(size.x, size.y) / 2.0, wheel_angle)
