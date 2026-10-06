extends TestCase
## End-to-end damage loop: crash in traffic -> slower, beat-up bus -> damage
## saved -> optional repair in the garage -> wrecked buses can't be driven.

var driver: GameDriver


func before_each() -> void:
	driver = GameDriver.new(self)


func after_each() -> void:
	driver.release_all()
	driver.cleanup_save()


func _save_with(money: int, damage: Dictionary) -> SaveData:
	var save := SaveData.new_game()
	save.wallet.earn(money)
	save.owned[Catalog.STARTER_BUS]["damage"] = damage
	return save


func _wrecked() -> Dictionary:
	var parts := {}
	for part in DamageModel.PARTS:
		parts[part] = 0.0
	return parts


func test_ramming_traffic_damages_the_bus_and_damage_is_saved() -> void:
	await driver.boot()
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	var track := session.world.track
	var target := session.traffic.nearest_ahead(session.bus.global_position, 0, 2000.0)
	assert_not_null(target, "there is a car ahead in our lane")
	# A reckless driver: flat out down the kerb lane, ignoring the car ahead.
	var pilot := Autopilot.new(session.bus, track)
	pilot.cruise_speed = 30.0
	var crashed := false
	for i in 60 * 60:
		pilot.step()
		await get_tree().physics_frame
		if session.damage.health(DamageModel.BODY_FRONT) < 1.0:
			crashed = true
			break
	pilot.release()
	assert_true(crashed, "rear-ended the traffic ahead")
	var percent := session.damage.health_percent()
	assert_lt(percent, 100)
	await wait_process_frames(1)
	assert_eq(session.hud.health_label.text, "Bus health: %d%%" % percent)
	assert_lt(session.bus.damage_speed_factor, 1.0, "a dented bus is slower")

	await driver.tap_key(KEY_ESCAPE)
	await wait_process_frames(2)
	var saved := DamageModel.from_dict(driver.saved_state().damage(Catalog.STARTER_BUS))
	assert_eq(saved.health_percent(), percent, "damage persisted even though the run was abandoned")
	assert_eq(driver.main.menu.condition_label.text, "Condition: %d%%" % percent)


func test_repair_in_garage_restores_bus_for_a_price() -> void:
	await driver.boot(_save_with(5000, {"body_front": 0.3, "mirror_right": 0.0}))
	var cost: int = driver.main.garage.repair_cost(Catalog.STARTER_BUS)
	assert_gt(cost, 0)
	await driver.click(driver.main.menu.garage_button)
	await wait_process_frames(2)
	var garage: GarageMenu = driver.main.garage_menu
	assert_eq(garage.buttons["repair"].text, "Repair $%d" % cost)
	await driver.click(garage.buttons["repair"])
	await wait_process_frames(2)
	assert_eq(driver.main.save.money, 5000 - cost)
	assert_eq(driver.saved_state().damage(Catalog.STARTER_BUS), {})
	assert_eq(driver.main.garage_menu.buttons["repair"].text, "Mint")


func test_damaged_bus_still_drives_but_slower() -> void:
	await driver.boot(_save_with(0, {"body_front": 0.1, "body_left": 0.2}))
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	assert_not_null(session, "repairing is optional")
	assert_lt(session.bus.effective_top_speed(), session.bus.spec.top_speed * 0.9)


func test_wrecked_bus_cannot_drive_until_repaired() -> void:
	await driver.boot(_save_with(20000, _wrecked()))
	var menu: MainMenu = driver.main.menu
	assert_true(menu.drive_button.disabled)
	assert_true(menu.condition_label.text.contains("wrecked"))
	await driver.click(menu.drive_button)
	await wait_process_frames(2)
	assert_null(driver.main.session, "no session for a wrecked bus")
	driver.main.start_drive()
	await wait_process_frames(2)
	assert_null(driver.main.session, "even when forced, start_drive refuses")

	await driver.click(driver.main.menu.garage_button)
	await wait_process_frames(2)
	await driver.click(driver.main.garage_menu.buttons["repair"])
	await wait_process_frames(2)
	await driver.click(driver.main.garage_menu.back_button)
	await wait_process_frames(2)
	assert_false(driver.main.menu.drive_button.disabled)
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	assert_not_null(driver.main.session)
	assert_eq(driver.main.session.damage.health_percent(), 100)
