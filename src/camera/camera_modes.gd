class_name CameraModes
extends RefCounted
## Camera angles the player cycles through, and where each one sits.

enum Mode { CHASE, DRIVER, TOP_DOWN }

const ORDER := [Mode.CHASE, Mode.DRIVER, Mode.TOP_DOWN]
const NAMES := {Mode.CHASE: "Chase", Mode.DRIVER: "Driver", Mode.TOP_DOWN: "Top-down"}
const TOP_DOWN_HEIGHT := 38.0
const DRIVER_EYE_MAX := 2.35


static func next(mode: Mode) -> Mode:
	var index := ORDER.find(mode)
	return ORDER[(index + 1) % ORDER.size()]


static func mode_name(mode: Mode) -> String:
	return NAMES[mode]


## Global transform for the camera (looking down its -Z) given the bus transform.
static func camera_transform(mode: Mode, bus_xform: Transform3D, spec: BusSpec) -> Transform3D:
	var forward := bus_xform.basis.z
	match mode:
		Mode.DRIVER:
			var eye := bus_xform * driver_seat(spec)
			var look := eye + forward * 12.0 + Vector3.DOWN * 0.8
			return Transform3D(Basis(), eye).looking_at(look, Vector3.UP)
		Mode.TOP_DOWN:
			var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
			if flat_forward.is_zero_approx():
				flat_forward = Vector3.FORWARD
			var eye := bus_xform.origin + Vector3.UP * TOP_DOWN_HEIGHT
			return Transform3D(Basis(), eye).looking_at(bus_xform.origin, flat_forward)
		_:
			var eye := bus_xform * Vector3(0.0, spec.height + 2.2, -(spec.length / 2.0 + 7.5))
			var look := bus_xform * Vector3(0.0, 1.6, spec.length / 2.0 + 4.0)
			return Transform3D(Basis(), eye).looking_at(look, Vector3.UP)


## Driver's eye point in bus-local space (left-hand drive: +X is the bus's left).
## Drivers sit low at the front, even in a double decker.
static func driver_seat(spec: BusSpec) -> Vector3:
	var eye_height := minf(spec.height * 0.78, DRIVER_EYE_MAX)
	return Vector3(spec.width / 2.0 - 0.6, eye_height, spec.length / 2.0 - 1.1)
