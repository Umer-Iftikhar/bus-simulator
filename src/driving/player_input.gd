class_name PlayerInput
extends Node
## Merges keyboard and touch input into bus commands and handles one-shot actions.

signal camera_requested
signal horn_requested
signal pause_requested

var bus: Bus
var touch: TouchControls


func _init() -> void:
	name = "PlayerInput"


func _ready() -> void:
	InputSetup.ensure_actions()
	if touch != null:
		touch.camera_requested.connect(camera_requested.emit)
		touch.horn_requested.connect(horn_requested.emit)
		touch.menu_requested.connect(pause_requested.emit)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(bus):
		return
	var throttle := Input.get_action_strength("accelerate")
	var brake := Input.get_action_strength("brake")
	var steer := Input.get_axis("steer_left", "steer_right")
	if touch != null:
		throttle = maxf(throttle, touch.throttle())
		brake = maxf(brake, touch.brake())
		if absf(touch.steer()) > absf(steer):
			steer = touch.steer()
	bus.set_command(throttle, brake, steer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_cycle"):
		camera_requested.emit()
	elif event.is_action_pressed("horn"):
		horn_requested.emit()
	elif event.is_action_pressed("pause"):
		pause_requested.emit()
