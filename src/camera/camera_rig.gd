class_name CameraRig
extends Node3D
## Follows the bus with the selected camera angle. The chase camera lags
## smoothly behind; the driver camera is rigidly attached to the seat.

signal mode_changed(mode: CameraModes.Mode)

const CHASE_SMOOTHING := 6.0
const TOP_DOWN_SMOOTHING := 10.0

var target: Bus
var mode: CameraModes.Mode = CameraModes.Mode.CHASE
var camera: Camera3D


func _init() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 70.0
	camera.far = 900.0
	add_child(camera)


func _ready() -> void:
	camera.make_current()
	snap()


func cycle() -> void:
	set_mode(CameraModes.next(mode))


func set_mode(new_mode: CameraModes.Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	camera.fov = 75.0 if mode == CameraModes.Mode.DRIVER else 70.0
	snap()
	mode_changed.emit(mode)


## Jumps straight to the desired transform (used on spawn and mode switches).
func snap() -> void:
	if is_instance_valid(target) and target.is_inside_tree():
		camera.global_transform = _desired()


func _desired() -> Transform3D:
	return CameraModes.camera_transform(mode, target.global_transform, target.spec)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	var desired := _desired()
	match mode:
		CameraModes.Mode.DRIVER:
			camera.global_transform = desired
		_:
			var rate := CHASE_SMOOTHING if mode == CameraModes.Mode.CHASE else TOP_DOWN_SMOOTHING
			var weight := 1.0 - exp(-rate * delta)
			camera.global_transform = camera.global_transform.interpolate_with(desired, weight)
