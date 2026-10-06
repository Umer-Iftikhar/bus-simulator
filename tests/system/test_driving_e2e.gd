extends TestCase
## End-to-end: boot the game, start driving from the menu and operate the bus
## with keyboard and touch input exactly as a player would.

var driver: GameDriver


func before_each() -> void:
	driver = GameDriver.new(self)
	await driver.boot()


func after_each() -> void:
	driver.release_all()


func _start_drive() -> DriveSession:
	var menu: MainMenu = driver.main.menu
	await driver.click(menu.drive_button)
	await wait_seconds(1.5)
	return driver.main.session


func test_drive_button_starts_a_session_on_the_road() -> void:
	assert_not_null(driver.main.menu, "menu shown on boot")
	var session := await _start_drive()
	assert_not_null(session, "session started")
	assert_false(is_instance_valid(driver.main.menu), "menu closed")
	var bus := session.bus
	assert_eq(session.world.track.lane_at(bus.global_position), 0, "spawned in kerb lane")
	assert_gt(bus.global_transform.basis.y.dot(Vector3.UP), 0.99, "upright")
	assert_true(session.camera_rig.camera.current)
	assert_eq(session.hud.speed_label.text, "0 km/h")


func test_holding_accelerate_key_drives_along_the_road() -> void:
	var session := await _start_drive()
	var bus := session.bus
	var track := session.world.track
	var start := track.closest_offset(bus.global_position)
	driver.key(KEY_W, true)
	await wait_seconds(5.0)
	var travelled := track.distance_ahead(start, track.closest_offset(bus.global_position))
	assert_between(travelled, 15.0, 90.0, "moved forward along the loop")
	assert_ne(track.lane_at(bus.global_position), -1, "still on the road")
	await wait_process_frames(1)
	assert_eq(session.hud.speed_label.text, "%d km/h" % roundi(bus.speed_kmh()))
	driver.key(KEY_W, false)
	driver.key(KEY_S, true)
	var stopped := await wait_until(func() -> bool: return bus.forward_speed() < 0.5, 8.0)
	assert_true(stopped, "brake key stops the bus")


func test_camera_key_cycles_views_and_hud_follows() -> void:
	var session := await _start_drive()
	var expected := [CameraModes.Mode.DRIVER, CameraModes.Mode.TOP_DOWN, CameraModes.Mode.CHASE]
	for mode in expected:
		await driver.tap_key(KEY_C)
		assert_eq(session.camera_rig.mode, mode)
		assert_eq(session.hud.camera_label.text, "Camera: %s" % CameraModes.mode_name(mode))


func test_touch_pedals_and_camera_button() -> void:
	var session := await _start_drive()
	var bus := session.bus
	var controls := session.touch_controls
	driver.touch(controls.gas, true, 0)
	await wait_seconds(3.0)
	assert_gt(bus.forward_speed(), 3.0, "gas pedal accelerates")
	driver.touch(controls.gas, false, 0)
	driver.touch(controls.brake_pedal, true, 1)
	var stopped := await wait_until(func() -> bool: return bus.forward_speed() < 0.5, 8.0)
	assert_true(stopped, "brake pedal stops the bus")
	driver.touch(controls.brake_pedal, false, 1)
	driver.touch(controls.camera_button, true, 2)
	await wait_process_frames(1)
	driver.touch(controls.camera_button, false, 2)
	assert_eq(session.camera_rig.mode, CameraModes.Mode.DRIVER)


func test_horn_plays_when_pressed() -> void:
	var session := await _start_drive()
	await driver.tap_key(KEY_H)
	assert_true(session.horn.playing)


func test_escape_returns_to_menu_and_can_drive_again() -> void:
	var session := await _start_drive()
	await driver.tap_key(KEY_ESCAPE)
	await wait_process_frames(2)
	assert_false(is_instance_valid(session), "session freed")
	assert_not_null(driver.main.menu)
	var second := await _start_drive()
	assert_not_null(second)
	assert_ne(second, session)
	var buses := driver.main.find_children("Bus", "Bus", true, false)
	assert_eq(buses.size(), 1, "exactly one bus after re-entering")
