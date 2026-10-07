class_name TouchControls
extends Control
## Driving overlay: steering wheel (bottom-left), brake and accelerator
## (bottom-right), plus camera and horn buttons.

signal camera_requested
signal horn_requested
signal menu_requested
signal indicator_left_requested
signal indicator_right_requested
signal gear_requested
signal lights_requested

const MARGIN := 24.0

var wheel := TouchSteeringWheel.new()
var gas := TouchPedal.new("GAS")
var brake_pedal := TouchPedal.new("BRAKE")
var camera_button := TouchButton.new("CAM", Vector2(80, 80))
var horn_button := TouchButton.new("HORN", Vector2(84, 84))
var menu_button := TouchButton.new("MENU", Vector2(72, 72))
var indicator_left_button := TouchButton.new("<", Vector2(96, 60))
var indicator_right_button := TouchButton.new(">", Vector2(96, 60))
var gear_button := TouchButton.new("D", Vector2(76, 120))
var lights_button := TouchButton.new("LIGHT", Vector2(80, 80))
## Matches [member Bus.light_mode]: 0 off, 1 low beam, 2 high beam.
var light_mode := 0


func _init() -> void:
	name = "TouchControls"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel.name = "Wheel"
	gas.name = "Gas"
	brake_pedal.name = "Brake"
	camera_button.name = "CameraButton"
	horn_button.name = "HornButton"
	menu_button.name = "MenuButton"
	indicator_left_button.name = "IndicatorLeft"
	indicator_right_button.name = "IndicatorRight"
	gear_button.name = "GearButton"
	lights_button.name = "LightsButton"
	# Accelerator: tall and narrow. Brake: a wide pad.
	gas.custom_minimum_size = Vector2(92, 190)
	gas.size = gas.custom_minimum_size
	brake_pedal.custom_minimum_size = Vector2(160, 150)
	brake_pedal.size = brake_pedal.custom_minimum_size
	brake_pedal.wide = true
	for pair in [
		[camera_button, "camera"],
		[horn_button, "horn"],
		[menu_button, "menu"],
		[lights_button, "light"],
	]:
		pair[0].style = "round"
		pair[0].icon = pair[1]
	indicator_left_button.style = "arrow_left"
	indicator_right_button.style = "arrow_right"
	gear_button.style = "gear"
	for control in [
		wheel,
		gas,
		brake_pedal,
		camera_button,
		horn_button,
		menu_button,
		indicator_left_button,
		indicator_right_button,
		gear_button,
		lights_button,
	]:
		add_child(control)
	camera_button.pressed_down.connect(camera_requested.emit)
	horn_button.pressed_down.connect(horn_requested.emit)
	menu_button.pressed_down.connect(menu_requested.emit)
	indicator_left_button.pressed_down.connect(indicator_left_requested.emit)
	indicator_right_button.pressed_down.connect(indicator_right_requested.emit)
	gear_button.pressed_down.connect(gear_requested.emit)
	lights_button.pressed_down.connect(lights_requested.emit)


func _ready() -> void:
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var area := size
	wheel.position = Vector2(MARGIN, area.y - wheel.size.y - MARGIN)
	gas.position = Vector2(area.x - gas.size.x - MARGIN, area.y - gas.size.y - MARGIN)
	brake_pedal.position = Vector2(
		gas.position.x - brake_pedal.size.x - 18.0, area.y - brake_pedal.size.y - MARGIN
	)
	camera_button.position = Vector2(area.x - camera_button.size.x - MARGIN, MARGIN)
	horn_button.position = Vector2(wheel.position.x + wheel.size.x + 18.0, area.y - 96.0)
	menu_button.position = Vector2((area.x - menu_button.size.x) / 2.0, MARGIN)
	gear_button.position = Vector2(
		area.x - gear_button.size.x - MARGIN, gas.position.y - gear_button.size.y - 14.0
	)
	lights_button.position = Vector2(camera_button.position.x - lights_button.size.x - 14.0, MARGIN)
	var above_wheel := wheel.position.y - indicator_left_button.size.y - 14.0
	indicator_left_button.position = Vector2(wheel.position.x, above_wheel)
	indicator_right_button.position = Vector2(
		wheel.position.x + wheel.size.x - indicator_right_button.size.x, above_wheel
	)


func show_indicators(left_on: bool, right_on: bool) -> void:
	indicator_left_button.set_lit(left_on)
	indicator_right_button.set_lit(right_on)


## Shows the selected gear on the gear button (lit in reverse).
func show_gear(reverse: bool) -> void:
	gear_button.label = "R" if reverse else "D"
	gear_button.set_lit(reverse)
	gear_button.queue_redraw()


## Shows the light switch: green low-beam icon, blue high-beam icon, white when off.
func show_lights(mode: int) -> void:
	if mode == light_mode:
		return
	light_mode = mode
	lights_button.icon = "light_high" if mode == 2 else "light"
	lights_button.glow = [Color(0, 0, 0, 0), ControlArt.LOW_BEAM, ControlArt.HIGH_BEAM][mode]
	lights_button.set_lit(mode != 0)
	lights_button.queue_redraw()


func steer() -> float:
	return wheel.steer


func throttle() -> float:
	return gas.value


func brake() -> float:
	return brake_pedal.value
