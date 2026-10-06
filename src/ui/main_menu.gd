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
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	column.custom_minimum_size = Vector2(520, 0)
	add_child(column)

	var title := Label.new()
	title.text = "Bus Simulator"
	title.add_theme_font_size_override("font_size", 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
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


func _on_map_selected(index: int) -> void:
	garage.select_map(map_picker.get_item_metadata(index))
	refresh()
	selection_changed.emit()


func _on_bus_selected(index: int) -> void:
	garage.select_bus(bus_picker.get_item_metadata(index))
	refresh()
	selection_changed.emit()
