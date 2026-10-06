class_name PlayerInput
extends Node
## Merges keyboard and touch input into bus commands and handles one-shot actions.

signal camera_requested
signal horn_requested
signal pause_requested
signal indicator_left_requested
signal indicator_right_requested
signal gear_requested
signal lights_requested

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
		touch.indicator_left_requested.connect(indicator_left_requested.emit)
		touch.indicator_right_requested.connect(indicator_right_requested.emit)
		touch.gear_requested.connect(gear_requested.emit)
		touch.lights_requested.connect(lights_requested.emit)


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
	elif event.is_action_pressed("indicator_left"):
		indicator_left_requested.emit()
	elif event.is_action_pressed("indicator_right"):
		indicator_right_requested.emit()
	elif event.is_action_pressed("gear"):
		gear_requested.emit()
	elif event.is_action_pressed("headlights"):
		lights_requested.emit()
