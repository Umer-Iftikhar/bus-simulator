extends TestCase
## End-to-end shopping: earn -> garage -> buy/upgrade/paint -> the next drive
## uses the new bus with its upgrades, and everything is saved.

var driver: GameDriver


func before_each() -> void:
	driver = GameDriver.new(self)
	var rich := SaveData.new_game()
	rich.wallet.earn(10000)
	await driver.boot(rich)


func after_each() -> void:
	driver.release_all()
	driver.cleanup_save()


func _open_garage() -> GarageMenu:
	await driver.click(driver.main.menu.garage_button)
	await wait_process_frames(2)
	return driver.main.garage_menu


func test_buy_select_upgrade_and_paint_then_drive() -> void:
	var garage := await _open_garage()
	assert_not_null(garage, "garage opened from the menu")
	await driver.click(garage.buttons["bus:city"])
	await wait_process_frames(1)
	await driver.click(garage.buttons["select:city"])
	await wait_process_frames(1)
	await driver.click(garage.buttons["upgrade:top_speed"])
	await wait_process_frames(1)
	await driver.click(garage.buttons["paint:ocean"])
	await wait_process_frames(1)

	var spent: int = (
		Catalog.bus_price("city")
		+ Catalog.upgrade_price(Catalog.Upgrade.TOP_SPEED, 0, "city")
		+ Catalog.paint_entry("ocean")["price"]
	)
	assert_eq(driver.main.save.money, 10000 - spent)
	var on_disk := driver.saved_state()
	assert_true(on_disk.owns("city"), "purchase saved immediately")
	assert_eq(on_disk.selected_bus, "city")
	assert_eq(on_disk.upgrade_level("city", Catalog.Upgrade.TOP_SPEED), 1)
	assert_eq(on_disk.paint("city"), "ocean")

	await driver.click(garage.back_button)
	await wait_process_frames(2)
	var menu: MainMenu = driver.main.menu
	assert_eq(menu.bus_picker.get_item_metadata(menu.bus_picker.selected), "city")
	await driver.click(menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	assert_eq(session.bus.spec.id, "city")
	assert_eq(session.bus.spec.capacity, 32)
	assert_almost_eq(session.bus.top_speed_factor, 1.06, 0.0001)
	assert_eq(session.bus.get_paint(), Catalog.paint_entry("ocean")["color"])


func test_cannot_buy_what_you_cannot_afford() -> void:
	var garage := await _open_garage()
	assert_true(garage.buttons["bus:double_decker"].disabled)
	await driver.click(garage.buttons["bus:double_decker"])
	assert_false(driver.main.save.owns("double_decker"))
	assert_eq(driver.main.save.money, 10000)


func test_switching_map_from_menu_is_saved() -> void:
	var menu: MainMenu = driver.main.menu
	var last_map: String = Maps.ids()[-1]
	await driver.select_option(menu.map_picker, last_map)
	assert_eq(driver.saved_state().selected_map, last_map)


func test_customise_stripe_rims_tint_and_roof_then_drive() -> void:
	var garage := await _open_garage()
	for key in ["stripe:gold", "rims:chrome", "tint:smoke", "roof:white"]:
		assert_true(garage.buttons.has(key), "%s offered" % key)
		await driver.click(driver.main.garage_menu.buttons[key])
		await wait_process_frames(2)
	var preview_bus: Bus = driver.main.garage_menu.preview.bus
	assert_true(preview_bus.body.stripes[0].visible, "preview updated live")
	var on_disk := driver.saved_state()
	assert_eq(on_disk.cosmetic("minibus", "stripe"), "gold")
	assert_eq(on_disk.cosmetic("minibus", "rims"), "chrome")
	assert_eq(on_disk.cosmetic("minibus", "tint"), "smoke")
	assert_eq(on_disk.cosmetic("minibus", "roof"), "white")
	var spent := 0
	for pair in [["stripe", "gold"], ["rims", "chrome"], ["tint", "smoke"], ["roof", "white"]]:
		spent += Catalog.cosmetic_entry(pair[0], pair[1])["price"]
	assert_eq(driver.main.save.money, 10000 - spent)

	await driver.click(driver.main.garage_menu.back_button)
	await wait_process_frames(2)
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var bus: Bus = driver.main.session.bus
	assert_true(bus.body.stripes[0].visible)
	assert_eq(bus.rim_material.albedo_color, Catalog.cosmetic_entry("rims", "chrome")["color"])
	assert_eq(bus.body.roof.material_override, bus.body.roof_material)
