class_name TouchControls
extends Control
## Driving overlay: steering wheel (bottom-left), brake and accelerator
## (bottom-right), plus camera and horn buttons.

signal camera_requested
signal horn_requested
signal menu_requested

const MARGIN := 24.0

var wheel := TouchSteeringWheel.new()
var gas := TouchPedal.new("GAS")
var brake_pedal := TouchPedal.new("BRAKE")
var camera_button := TouchButton.new("CAM")
var horn_button := TouchButton.new("HORN")
var menu_button := TouchButton.new("MENU")


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
	gas.base_color = Color(0.1, 0.45, 0.15, 0.55)
	brake_pedal.base_color = Color(0.5, 0.1, 0.1, 0.55)
	for control in [wheel, gas, brake_pedal, camera_button, horn_button, menu_button]:
		add_child(control)
	camera_button.pressed_down.connect(camera_requested.emit)
	horn_button.pressed_down.connect(horn_requested.emit)
	menu_button.pressed_down.connect(menu_requested.emit)


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


func steer() -> float:
	return wheel.steer


func throttle() -> float:
	return gas.value


func brake() -> float:
	return brake_pedal.value
