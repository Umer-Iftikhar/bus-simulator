class_name MainMenu
extends Control
## Title screen: money, map and bus selection, and the way into the garage.

signal drive_requested
signal garage_requested
signal selection_changed

var save: SaveData
var garage: Garage
var money_label := Label.new()
var map_picker := OptionButton.new()
var bus_picker := OptionButton.new()
var map_info := Label.new()
var condition_label := Label.new()
var graphics_picker := OptionButton.new()
var indicator_picker := OptionButton.new()
var studio_label := Label.new()
var drive_button := Button.new()
var garage_button := Button.new()


static func create(save_data: SaveData, shop: Garage) -> MainMenu:
	var menu := MainMenu.new()
	menu.save = save_data
	menu.garage = shop
	menu._build()
	return menu


func _build() -> void:
	name = "MainMenu"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.11, 0.25, 0.42)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size = Vector2(520, 0)
	center.add_child(column)

	var title := Label.new()
	title.text = "Bus Simulator"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	studio_label.name = "Studio"
	studio_label.text = "marrij g"
	studio_label.add_theme_font_size_override("font_size", 34)
	studio_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.25))
	studio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(studio_label)
	money_label.name = "Money"
	money_label.add_theme_font_size_override("font_size", 30)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(money_label)

	map_picker.name = "MapPicker"
	for map in Maps.all():
		map_picker.add_item("%s  ($%d / passenger)" % [map.display_name, map.fare])
		map_picker.set_item_metadata(map_picker.item_count - 1, map.id)
	map_picker.item_selected.connect(_on_map_selected)
	_big(map_picker)
	column.add_child(map_picker)
	map_info.name = "MapInfo"
	map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(map_info)

	bus_picker.name = "BusPicker"
	bus_picker.item_selected.connect(_on_bus_selected)
	_big(bus_picker)
	column.add_child(bus_picker)
	condition_label.name = "Condition"
	condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(condition_label)

	drive_button.name = "DriveButton"
	drive_button.text = "Drive"
	drive_button.pressed.connect(drive_requested.emit)
	_big(drive_button)
	drive_button.custom_minimum_size.y = 84
	column.add_child(drive_button)
	garage_button.name = "GarageButton"
	garage_button.text = "Garage"
	garage_button.pressed.connect(garage_requested.emit)
	_big(garage_button)
	column.add_child(garage_button)
	graphics_picker.name = "Graphics"
	for preset in GraphicsSettings.PRESETS:
		graphics_picker.add_item("Graphics: %s" % GraphicsSettings.display_name(preset))
		graphics_picker.set_item_metadata(graphics_picker.item_count - 1, preset)
	graphics_picker.item_selected.connect(_on_graphics_selected)
	indicator_picker.name = "Indicators"
	indicator_picker.add_item("Indicators: Manual")
	indicator_picker.set_item_metadata(0, "manual")
	indicator_picker.add_item("Indicators: Auto")
	indicator_picker.set_item_metadata(1, "auto")
	indicator_picker.item_selected.connect(_on_indicators_selected)
	# Settings side by side so the menu still fits a phone screen.
	var settings_row := HBoxContainer.new()
	settings_row.name = "Settings"
	settings_row.add_theme_constant_override("separation", 12)
	for picker in [graphics_picker, indicator_picker]:
		picker.custom_minimum_size = Vector2(0, 52)
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.add_theme_font_size_override("font_size", 20)
		settings_row.add_child(picker)
	column.add_child(settings_row)
	refresh()


func _big(control: Control) -> void:
	control.custom_minimum_size = Vector2(0, 64)
	control.add_theme_font_size_override("font_size", 26)


func refresh() -> void:
	money_label.text = "$%d" % save.money
	for i in map_picker.item_count:
		if map_picker.get_item_metadata(i) == save.selected_map:
			map_picker.select(i)
	var map := Maps.get_map(save.selected_map)
	map_info.text = map.description
	bus_picker.clear()
	for bus_id in save.owned_ids():
		var entry := Catalog.bus_entry(bus_id)
		bus_picker.add_item("%s  (%d seats)" % [entry["display_name"], entry["capacity"]])
		bus_picker.set_item_metadata(bus_picker.item_count - 1, bus_id)
		if bus_id == save.selected_bus:
			bus_picker.select(bus_picker.item_count - 1)
	for i in graphics_picker.item_count:
		if graphics_picker.get_item_metadata(i) == save.graphics():
			graphics_picker.select(i)
	indicator_picker.select(1 if save.auto_indicators() else 0)
	var damage := garage.damage_of(save.selected_bus)
	if damage.is_wrecked():
		condition_label.text = "This bus is wrecked — repair it in the Garage"
		drive_button.disabled = true
	else:
		condition_label.text = "Condition: %d%%" % damage.health_percent()
		drive_button.disabled = false


func _on_map_selected(index: int) -> void:
	garage.select_map(map_picker.get_item_metadata(index))
	refresh()
	selection_changed.emit()


func _on_graphics_selected(index: int) -> void:
	save.settings["graphics"] = graphics_picker.get_item_metadata(index)
	selection_changed.emit()


func _on_indicators_selected(index: int) -> void:
	save.settings["indicators"] = indicator_picker.get_item_metadata(index)
	selection_changed.emit()


func _on_bus_selected(index: int) -> void:
	garage.select_bus(bus_picker.get_item_metadata(index))
	refresh()
	selection_changed.emit()
