extends TestCase
## End-to-end on the new content: choose Downtown and battery-saver mirrors
## from the menu, drive the whole route in heavy traffic, get Downtown fares.

var driver: GameDriver


func before_each() -> void:
	driver = GameDriver.new(self)
	await driver.boot()


func after_each() -> void:
	driver.release_all()
	driver.cleanup_save()


func test_downtown_route_with_battery_saver_mirrors() -> void:
	var menu: MainMenu = driver.main.menu
	await driver.select_option(menu.map_picker, "downtown")
	await driver.select_option(menu.graphics_picker, "low")
	var saved := driver.saved_state()
	assert_eq(saved.selected_map, "downtown")
	assert_eq(saved.graphics(), "low")

	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	assert_eq(session.map.id, "downtown")
	assert_eq(session.mirrors.refresh_interval, 3)
	assert_eq(session.traffic.cars.size(), Maps.downtown().traffic_cars)

	var door_openings := [0]
	var watcher := func(_index: int, _off: int, _on: int, _left: int) -> void:
		door_openings[0] += 1 if session.bus.doors_open else 0
	session.run.stop_served.connect(watcher)
	var pilot := Autopilot.new(session.bus, session.world.track)
	pilot.traffic = session.traffic
	var finished := await pilot.drive_route(get_tree(), session.run)
	assert_true(finished, "Downtown route completed")
	var result := session.run.result()
	assert_true(result["completed"])
	assert_eq(result["missed_stops"], 0)
	assert_eq(result["payout"], result["delivered"] * Maps.downtown().fare)
	assert_eq(door_openings[0], Maps.downtown().stops.size(), "doors opened at every stop")
	assert_eq(session.damage.health_percent(), 100)
	await wait_process_frames(2)
	assert_eq(driver.saved_state().money, result["payout"])


func test_night_map_is_drivable_with_headlights() -> void:
	await driver.select_option(driver.main.menu.map_picker, "pines")
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	assert_true(session.bus.headlights[0].visible)
	driver.key(KEY_W, true)
	await wait_seconds(4.0)
	driver.key(KEY_W, false)
	assert_gt(session.bus.forward_speed(), 5.0)
	assert_ne(session.current_lane(), -1)


func test_choosing_ultra_graphics_from_the_menu() -> void:
	await driver.select_option(driver.main.menu.graphics_picker, "ultra")
	assert_eq(driver.saved_state().graphics(), "ultra", "saved immediately")
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	assert_eq(get_tree().root.msaa_3d, Viewport.MSAA_4X)
	assert_eq(session.mirrors.refresh_interval, 1)
	get_tree().root.msaa_3d = Viewport.MSAA_DISABLED
	get_tree().root.scaling_3d_scale = 1.0
