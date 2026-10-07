class_name Hud
extends Control
## Heads-up display: speed, camera mode, next stop, passengers, fares and
## short status messages ("3 boarded, 1 alighted").

const MESSAGE_SECONDS := 3.0
## The "bus stop ahead" banner appears within this distance of the next stop.
const APPROACH_DISTANCE := 400.0

var speed_label := Label.new()
var camera_label := Label.new()
var stop_label := Label.new()
var passengers_label := Label.new()
var fares_label := Label.new()
var health_label := Label.new()
var message_label := Label.new()
var info := VBoxContainer.new()
var approach_panel := PanelContainer.new()
var approach_title := Label.new()
var approach_detail := Label.new()
var _message_timer := 0.0
var _reverse := false
var _last_kmh := 0.0


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
	health_label.name = "Health"
	var labels := [
		speed_label,
		camera_label,
		stop_label,
		passengers_label,
		fares_label,
		health_label,
	]
	for label in labels:
		add_label(label)
	message_label.name = "Message"
	message_label.add_theme_font_size_override("font_size", 28)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.position.y = 110
	_style(message_label)
	add_child(message_label)
	_build_approach_panel()
	show_speed(0.0)
	show_camera_mode(CameraModes.Mode.CHASE)
	show_gear(false)


func add_label(label: Label) -> void:
	_style(label)
	info.add_child(label)


func _style(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_speed(kmh: float) -> void:
	_last_kmh = kmh
	speed_label.text = "%d km/h  %s" % [roundi(kmh), "R" if _reverse else "D"]


func show_camera_mode(mode: CameraModes.Mode) -> void:
	camera_label.text = "Camera: %s" % CameraModes.mode_name(mode)


func _build_approach_panel() -> void:
	approach_panel.name = "ApproachPanel"
	approach_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.25, 0.55, 0.85)
	style.border_color = Color(1.0, 0.82, 0.1)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	approach_panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	approach_panel.add_child(column)
	approach_title.name = "ApproachTitle"
	approach_title.add_theme_font_size_override("font_size", 22)
	approach_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.1))
	approach_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	approach_detail.name = "ApproachDetail"
	approach_detail.add_theme_font_size_override("font_size", 34)
	approach_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for label in [approach_title, approach_detail]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
	approach_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	approach_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	approach_panel.position.y = 150
	approach_panel.visible = false
	add_child(approach_panel)


## "850 m" below a kilometre (rounded to 10 m beyond 100 m), "1.2 km" above.
static func format_distance(metres: float) -> String:
	var m := maxf(metres, 0.0)
	if m >= 1000.0:
		return "%.1f km" % (m / 1000.0)
	if m >= 100.0:
		return "%d m" % (roundi(m / 10.0) * 10)
	return "%d m" % roundi(m)


func show_next_stop(stop_name: String, distance: float) -> void:
	if stop_name.is_empty():
		stop_label.text = "Route complete"
		approach_panel.visible = false
		return
	if distance < 1.0:
		stop_label.text = "Next: %s (here)" % stop_name
	else:
		stop_label.text = "Next: %s (%s)" % [stop_name, format_distance(distance)]
	approach_panel.visible = distance <= APPROACH_DISTANCE
	if distance < 1.0:
		approach_title.text = "STOP HERE"
		approach_detail.text = stop_name
	else:
		approach_title.text = "BUS STOP AHEAD"
		approach_detail.text = "%s  ·  %s" % [stop_name, format_distance(distance)]


func show_passengers(on_board: int, capacity: int) -> void:
	passengers_label.text = "Passengers: %d / %d" % [on_board, capacity]


func show_fares(amount: int) -> void:
	fares_label.text = "Fares: $%d" % amount


## The gear shows next to the speed: D (drive) or R (reverse).
func show_gear(reverse: bool) -> void:
	_reverse = reverse
	show_speed(_last_kmh)


func show_health(percent: int) -> void:
	health_label.text = "Bus health: %d%%" % percent
	var color := Color.WHITE
	if percent < 35:
		color = Color(1.0, 0.35, 0.3)
	elif percent < 70:
		color = Color(1.0, 0.8, 0.3)
	health_label.add_theme_color_override("font_color", color)


func flash(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	_message_timer = MESSAGE_SECONDS


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.visible = false
