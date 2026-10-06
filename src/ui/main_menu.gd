class_name MainMenu
extends Control
## Title screen. Expanded with map/bus selection and the garage in later slices.

signal drive_requested

var drive_button := Button.new()


func _init() -> void:
	name = "MainMenu"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.11, 0.25, 0.42)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)
	var title := Label.new()
	title.text = "Bus Simulator"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	drive_button.name = "DriveButton"
	drive_button.text = "Drive"
	drive_button.custom_minimum_size = Vector2(260, 80)
	drive_button.add_theme_font_size_override("font_size", 32)
	drive_button.pressed.connect(drive_requested.emit)
	column.add_child(drive_button)
