extends TestCase
## Main menu, garage and results panel wired to real SaveData/Garage objects.

var save: SaveData
var garage: Garage


func before_each() -> void:
	save = SaveData.new_game()
	garage = Garage.new(save)


func test_main_menu_shows_money_and_selection() -> void:
	save.wallet.earn(321)
	var menu := add_child_autofree(MainMenu.create(save, garage)) as MainMenu
	assert_eq(menu.money_label.text, "$321")
	assert_eq(menu.map_picker.item_count, Maps.all().size())
	assert_eq(menu.bus_picker.item_count, 1, "only owned buses are listed")
	assert_eq(menu.bus_picker.get_item_metadata(menu.bus_picker.selected), save.selected_bus)


func test_main_menu_bus_picker_changes_selection() -> void:
	save.wallet.earn(10000)
	garage.buy_bus("city")
	var menu := add_child_autofree(MainMenu.create(save, garage)) as MainMenu
	watch_signals(menu)
	var index := -1
	for i in menu.bus_picker.item_count:
		if menu.bus_picker.get_item_metadata(i) == "city":
			index = i
	menu.bus_picker.select(index)
	menu.bus_picker.item_selected.emit(index)
	assert_eq(save.selected_bus, "city")
	assert_signal_emitted(menu, "selection_changed")


func test_main_menu_buttons_emit_requests() -> void:
	var menu := add_child_autofree(MainMenu.create(save, garage)) as MainMenu
	watch_signals(menu)
	menu.drive_button.pressed.emit()
	menu.garage_button.pressed.emit()
	assert_signal_emitted(menu, "drive_requested")
	assert_signal_emitted(menu, "garage_requested")


func test_garage_disables_what_you_cannot_afford() -> void:
	var menu := add_child_autofree(GarageMenu.create(save, garage)) as GarageMenu
	assert_true(menu.buttons["bus:city"].disabled)
	assert_true(menu.buttons["upgrade:brakes"].disabled)
	assert_true(menu.buttons["paint:ocean"].disabled)
	assert_true(menu.buttons["select:minibus"].disabled, "already selected")


func test_garage_buy_bus_then_select_it() -> void:
	save.wallet.earn(5000)
	var menu := add_child_autofree(GarageMenu.create(save, garage)) as GarageMenu
	watch_signals(menu)
	assert_false(menu.buttons["bus:city"].disabled)
	menu.buttons["bus:city"].pressed.emit()
	await wait_process_frames(1)
	assert_true(save.owns("city"))
	assert_eq(menu.money_label.text, "$%d" % (5000 - Catalog.bus_price("city")))
	assert_signal_emitted(menu, "purchased")
	menu.buttons["select:city"].pressed.emit()
	await wait_process_frames(1)
	assert_eq(save.selected_bus, "city")
	assert_true(menu.buttons["select:city"].disabled)


func test_garage_upgrade_and_paint_buttons() -> void:
	save.wallet.earn(5000)
	var menu := add_child_autofree(GarageMenu.create(save, garage)) as GarageMenu
	menu.buttons["upgrade:top_speed"].pressed.emit()
	await wait_process_frames(1)
	assert_eq(save.upgrade_level("minibus", Catalog.Upgrade.TOP_SPEED), 1)
	assert_eq(menu.feedback_label.text, Garage.RESULT_TEXT[Garage.Result.OK])
	menu.buttons["paint:ocean"].pressed.emit()
	await wait_process_frames(1)
	assert_eq(save.paint("minibus"), "ocean")
	assert_true(menu.buttons["paint:ocean"].disabled, "current paint is shown as applied")


func test_garage_shows_max_when_fully_upgraded() -> void:
	save.owned["minibus"]["upgrades"]["handling"] = Catalog.MAX_UPGRADE_LEVEL
	var menu := add_child_autofree(GarageMenu.create(save, garage)) as GarageMenu
	assert_eq(menu.buttons["upgrade:handling"].text, "MAX")
	assert_true(menu.buttons["upgrade:handling"].disabled)


func test_results_panel_summarises_run() -> void:
	var result := {
		"completed": true,
		"failed": false,
		"delivered": 20,
		"fare": 12,
		"payout": 240,
		"stranded": 3,
		"missed_stops": 1
	}
	var panel := add_child_autofree(ResultsPanel.create(result)) as ResultsPanel
	assert_eq(panel.title.text, "Route complete!")
	assert_true(panel.lines.text.contains("20 passengers"))
	assert_true(panel.lines.text.contains("$240"))
	assert_true(panel.lines.text.contains("Missed stops: 1"))
	watch_signals(panel)
	panel.continue_button.pressed.emit()
	assert_signal_emitted(panel, "continue_pressed")


func test_results_panel_failed_run() -> void:
	var panel := ResultsPanel.create({"failed": true, "payout": 0})
	autofree(panel)
	assert_eq(panel.title.text, "Bus wrecked!")
	assert_true(panel.lines.text.contains("$0"))


func test_every_main_menu_control_is_on_screen() -> void:
	var menu := add_child_autofree(MainMenu.create(save, garage)) as MainMenu
	await wait_process_frames(2)
	var screen := Rect2(Vector2.ZERO, menu.size)
	var controls := [
		menu.studio_label,
		menu.map_picker,
		menu.bus_picker,
		menu.drive_button,
		menu.garage_button,
		menu.graphics_picker,
	]
	for control in controls:
		assert_true(screen.encloses(control.get_global_rect()), "%s on screen" % control.name)


func test_results_panel_is_centred_on_screen() -> void:
	var layer := add_child_autofree(CanvasLayer.new())
	var panel := ResultsPanel.create({"delivered": 1, "fare": 1, "payout": 1})
	layer.add_child(panel)
	await wait_process_frames(2)
	var viewport := panel.get_viewport_rect()
	assert_true(viewport.encloses(panel.get_global_rect()), "fully visible")
	assert_vec3_almost_eq(
		Vector3(panel.get_global_rect().get_center().x, panel.get_global_rect().get_center().y, 0),
		Vector3(viewport.get_center().x, viewport.get_center().y, 0),
		2.0
	)


func test_main_menu_shows_marrij_g() -> void:
	var menu := add_child_autofree(MainMenu.create(save, garage)) as MainMenu
	await wait_process_frames(2)
	var found := menu.find_children("*", "Label", true, false).filter(
		func(l: Label) -> bool: return l.text == "marrij g"
	)
	assert_eq(found.size(), 1, "the words 'marrij g' appear on the main menu")
	var label := found[0] as Label
	assert_true(label.is_visible_in_tree())
	var screen := Rect2(Vector2.ZERO, menu.size)
	assert_true(screen.encloses(label.get_global_rect()), "fully on screen")
	assert_ge(label.get_theme_font_size("font_size"), 28, "big enough to read")
