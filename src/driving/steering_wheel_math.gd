class_name SteeringWheelMath
extends RefCounted
## Geometry for the on-screen steering wheel.

## Rotation of the wheel (radians) that maps to full steering lock: two full
## turns each way, like a real bus wheel.
const DEFAULT_MAX_ANGLE := TAU * 2.0


## Angle of [param point] around [param center], measured clockwise from "up".
static func pointer_angle(center: Vector2, point: Vector2) -> float:
	var d := point - center
	return atan2(d.x, -d.y)


## Adds the pointer's angular movement to the wheel angle, handling the ±PI wrap.
static func accumulate(
	wheel_angle: float, previous: float, current: float, max_angle: float
) -> float:
	var delta := wrapf(current - previous, -PI, PI)
	return clampf(wheel_angle + delta, -max_angle, max_angle)


static func angle_to_steer(wheel_angle: float, max_angle: float) -> float:
	if max_angle <= 0.0:
		return 0.0
	return clampf(wheel_angle / max_angle, -1.0, 1.0)
