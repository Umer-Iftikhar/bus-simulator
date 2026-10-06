class_name GarageMenu
extends Control
## The shop: buy buses, upgrade the selected bus and give it a paint job.

signal back_requested
signal purchased

var save: SaveData
var garage: Garage
var money_label := Label.new()
var feedback_label := Label.new()
var bus_list := VBoxContainer.new()
var detail := VBoxContainer.new()
var back_button := Button.new()
## Buttons by key ("bus:<id>", "select:<id>", "upgrade:<key>", "paint:<id>") for tests.
var buttons := {}


static func create(save_data: SaveData, shop: Garage) -> GarageMenu:
	var menu := GarageMenu.new()
	menu.save = save_data
	menu.garage = shop
	menu._build()
	return menu


func _build() -> void:
	name = "GarageMenu"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.16, 0.18, 0.22)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	back_button.name = "BackButton"
	back_button.text = "< Back"
	back_button.custom_minimum_size = Vector2(140, 56)
	back_button.pressed.connect(back_requested.emit)
	header.add_child(back_button)
	money_label.name = "Money"
	money_label.add_theme_font_size_override("font_size", 30)
	money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(money_label)
	feedback_label.name = "Feedback"
	header.add_child(feedback_label)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	root.add_child(columns)
	columns.add_child(_scroll(bus_list))
	columns.add_child(_scroll(detail))
	refresh()


func _scroll(content: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


func refresh() -> void:
	money_label.text = "$%d" % save.money
	buttons.clear()
	for child in bus_list.get_children() + detail.get_children():
		child.free()
	_heading(bus_list, "Buses")
	for bus_id in Catalog.bus_ids():
		_add_bus_row(bus_id)
	var current := save.selected_bus
	_heading(detail, "Upgrades — %s" % Catalog.bus_entry(current)["display_name"])
	for kind in Catalog.UPGRADE_KEYS:
		_add_upgrade_row(current, kind)
	_heading(detail, "Paint")
	var paints := HFlowContainer.new()
	detail.add_child(paints)
	for paint_id in Catalog.paint_ids():
		_add_paint_button(paints, current, paint_id)


func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	parent.add_child(label)


func _add_bus_row(bus_id: String) -> void:
	var entry := Catalog.bus_entry(bus_id)
	var row := HBoxContainer.new()
	bus_list.add_child(row)
	var label := Label.new()
	label.text = "%s — %d seats" % [entry["display_name"], entry["capacity"]]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 52)
	if not save.owns(bus_id):
		button.text = "Buy $%d" % entry["price"]
		button.disabled = not save.wallet.can_afford(entry["price"])
		button.pressed.connect(func() -> void: _apply(garage.buy_bus(bus_id)))
		buttons["bus:%s" % bus_id] = button
	elif save.selected_bus == bus_id:
		button.text = "Selected"
		button.disabled = true
		buttons["select:%s" % bus_id] = button
	else:
		button.text = "Select"
		button.pressed.connect(func() -> void: _apply(garage.select_bus(bus_id)))
		buttons["select:%s" % bus_id] = button
	row.add_child(button)


func _add_upgrade_row(bus_id: String, kind: Catalog.Upgrade) -> void:
	var row := HBoxContainer.new()
	detail.add_child(row)
	var level := save.upgrade_level(bus_id, kind)
	var label := Label.new()
	label.text = "%s  %d/%d" % [Catalog.UPGRADE_NAMES[kind], level, Catalog.MAX_UPGRADE_LEVEL]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var price := garage.next_upgrade_price(bus_id, kind)
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 52)
	button.text = "MAX" if price < 0 else "+ $%d" % price
	button.disabled = price < 0 or not save.wallet.can_afford(price)
	button.pressed.connect(func() -> void: _apply(garage.buy_upgrade(bus_id, kind)))
	buttons["upgrade:%s" % Catalog.upgrade_key(kind)] = button
	row.add_child(button)


func _add_paint_button(parent: Control, bus_id: String, paint_id: String) -> void:
	var entry := Catalog.paint_entry(paint_id)
	var owned: bool = save.owned[bus_id]["paints"].has(paint_id)
	var button := Button.new()
	button.custom_minimum_size = Vector2(150, 52)
	if save.paint(bus_id) == paint_id:
		button.text = "%s ✓" % entry["display_name"]
		button.disabled = true
	elif owned:
		button.text = entry["display_name"]
	else:
		button.text = "%s $%d" % [entry["display_name"], entry["price"]]
		button.disabled = not save.wallet.can_afford(entry["price"])
	button.add_theme_color_override(
		"font_color", Catalog.paint_color(bus_id, paint_id).lightened(0.3)
	)
	button.pressed.connect(func() -> void: _apply(garage.buy_paint(bus_id, paint_id)))
	buttons["paint:%s" % paint_id] = button
	parent.add_child(button)


func _apply(result: Garage.Result) -> void:
	feedback_label.text = Garage.RESULT_TEXT[result]
	if result == Garage.Result.OK:
		purchased.emit()
	refresh.call_deferred()
