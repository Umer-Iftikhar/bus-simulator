class_name Hud
extends Control
## Heads-up display: speed, camera mode, next stop, passengers, fares and
## short status messages ("3 boarded, 1 alighted").

const MESSAGE_SECONDS := 3.0

var speed_label := Label.new()
var camera_label := Label.new()
var stop_label := Label.new()
var passengers_label := Label.new()
var fares_label := Label.new()
var message_label := Label.new()
var info := VBoxContainer.new()
var _message_timer := 0.0


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
	stop_label.name = "NextStop"
	passengers_label.name = "Passengers"
	fares_label.name = "Fares"
	for label in [speed_label, camera_label, stop_label, passengers_label, fares_label]:
		add_label(label)
	message_label.name = "Message"
	message_label.add_theme_font_size_override("font_size", 28)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.position.y = 110
	_style(message_label)
	add_child(message_label)
	show_speed(0.0)
	show_camera_mode(CameraModes.Mode.CHASE)


func add_label(label: Label) -> void:
	_style(label)
	info.add_child(label)


func _style(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_speed(kmh: float) -> void:
	speed_label.text = "%d km/h" % roundi(kmh)


func show_camera_mode(mode: CameraModes.Mode) -> void:
	camera_label.text = "Camera: %s" % CameraModes.mode_name(mode)


func show_next_stop(stop_name: String, distance: float) -> void:
	if stop_name.is_empty():
		stop_label.text = "Route complete"
	elif distance < 1.0:
		stop_label.text = "Next: %s (here)" % stop_name
	else:
		stop_label.text = "Next: %s (%d m)" % [stop_name, roundi(distance)]


func show_passengers(on_board: int, capacity: int) -> void:
	passengers_label.text = "Passengers: %d / %d" % [on_board, capacity]


func show_fares(amount: int) -> void:
	fares_label.text = "Fares: $%d" % amount


func flash(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	_message_timer = MESSAGE_SECONDS


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.visible = false
