class_name TouchButton
extends Control
## Multi-touch friendly button. Handles screen touches directly so it keeps
## working while other fingers hold the wheel or pedals.

signal pressed_down
signal released

var label := ""
var held := false
var lit := false
var base_color := Color(0.1, 0.12, 0.15, 0.55)
var lit_color := Color(1.0, 0.75, 0.15, 0.85)
## Shape: "box", "round" (bezel + [member icon]), "arrow_left", "arrow_right" or "gear".
var style := "box"
var icon := ""
## Icon tint for round buttons; transparent means the default white.
var glow := Color(0, 0, 0, 0)
var _touch_index := -1


func _init(text := "", min_size := Vector2(96, 72)) -> void:
	label = text
	custom_minimum_size = min_size
	size = min_size
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			held = true
			queue_redraw()
			pressed_down.emit()
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			accept_event()


func _release() -> void:
	_touch_index = -1
	held = false
	queue_redraw()
	released.emit()


func set_lit(value: bool) -> void:
	if lit != value:
		lit = value
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and held:
		_release()


func _draw() -> void:
	match style:
		"round":
			ControlArt.round_button(self, size, held, glow, icon)
			return
		"arrow_left", "arrow_right":
			ControlArt.arrow_button(self, size, held, lit, style == "arrow_left")
			return
		"gear":
			ControlArt.gear_gate(self, size, lit)
			return
	var color := lit_color if lit else base_color
	if held:
		color = color.lightened(0.25)
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
	var font := ThemeDB.fallback_font
	var font_size := 20
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2((size.x - text_size.x) / 2.0, (size.y + text_size.y * 0.6) / 2.0)
	draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
