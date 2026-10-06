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
var camera_button := TouchButton.new("CAM")
var horn_button := TouchButton.new("HORN")
var menu_button := TouchButton.new("MENU")
var indicator_left_button := TouchButton.new("<", Vector2(96, 64))
var indicator_right_button := TouchButton.new(">", Vector2(96, 64))
var gear_button := TouchButton.new("D", Vector2(110, 64))
var lights_button := TouchButton.new("LIGHT", Vector2(96, 72))


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
	gas.base_color = Color(0.1, 0.45, 0.15, 0.55)
	brake_pedal.base_color = Color(0.5, 0.1, 0.1, 0.55)
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
	gear_button.position = Vector2(gas.position.x, gas.position.y - gear_button.size.y - 14.0)
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


func show_headlights(on: bool) -> void:
	lights_button.set_lit(on)


func steer() -> float:
	return wheel.steer


func throttle() -> float:
	return gas.value


func brake() -> float:
	return brake_pedal.value
