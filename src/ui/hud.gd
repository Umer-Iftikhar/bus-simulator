class_name Hud
extends Control
## Heads-up display: speed and camera mode. Later slices add run information.

var speed_label := Label.new()
var camera_label := Label.new()
var info := VBoxContainer.new()


func _init() -> void:
	name = "Hud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.position = Vector2(24, 20)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	speed_label.name = "Speed"
	speed_label.add_theme_font_size_override("font_size", 34)
	camera_label.name = "CameraMode"
	for label in [speed_label, camera_label]:
		add_label(label)
	show_speed(0.0)
	show_camera_mode(CameraModes.Mode.CHASE)


func add_label(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(label)


func show_speed(kmh: float) -> void:
	speed_label.text = "%d km/h" % roundi(kmh)


func show_camera_mode(mode: CameraModes.Mode) -> void:
	camera_label.text = "Camera: %s" % CameraModes.mode_name(mode)
