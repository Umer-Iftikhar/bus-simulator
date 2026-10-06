class_name ResultsPanel
extends PanelContainer
## End-of-run summary: passengers delivered, pay, and anyone left behind.

signal continue_pressed

var title := Label.new()
var lines := Label.new()
var continue_button := Button.new()


static func create(result: Dictionary) -> ResultsPanel:
	var panel := ResultsPanel.new()
	panel.show_result(result)
	return panel


func _init() -> void:
	name = "ResultsPanel"
	custom_minimum_size = Vector2(520, 320)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	add_child(column)
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	lines.add_theme_font_size_override("font_size", 24)
	column.add_child(lines)
	continue_button.name = "ContinueButton"
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(0, 70)
	continue_button.add_theme_font_size_override("font_size", 28)
	continue_button.pressed.connect(continue_pressed.emit)
	column.add_child(continue_button)


func show_result(result: Dictionary) -> void:
	if result.get("failed", false):
		title.text = "Bus wrecked!"
	else:
		title.text = "Route complete!"
	var text := PackedStringArray()
	text.append(
		"Delivered: %d passengers × $%d" % [result.get("delivered", 0), result.get("fare", 0)]
	)
	text.append("Earned: $%d" % result.get("payout", 0))
	if result.get("stranded", 0) > 0:
		text.append("Left behind / dropped off wrong: %d" % result["stranded"])
	if result.get("missed_stops", 0) > 0:
		text.append("Missed stops: %d" % result["missed_stops"])
	lines.text = "\n".join(text)
