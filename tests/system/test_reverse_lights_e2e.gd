extends TestCase
## End-to-end: reversing with the gear key / button and switching lights,
## played through real input events.

var driver: GameDriver
var session: DriveSession


func before_each() -> void:
	driver = GameDriver.new(self)
	await driver.boot()
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	session = driver.main.session


func after_each() -> void:
	driver.release_all()
	driver.cleanup_save()


func test_reverse_out_of_a_spot_with_the_gear_key() -> void:
	var bus := session.bus
	var start := bus.global_position
	await driver.tap_key(KEY_R)
	assert_true(bus.reverse_gear, "R selects reverse at a standstill")
	assert_true(session.hud.speed_label.text.ends_with("R"))
	assert_eq(session.touch_controls.gear_button.label, "R")
	driver.key(KEY_W, true)
	await wait_seconds(4.0)
	assert_lt(bus.forward_speed(), -1.0, "gas drives backwards in reverse")
	assert_ge(bus.forward_speed(), -Drivetrain.REVERSE_TOP_SPEED * 1.05, "slowly")
	var moved := bus.global_position - start
	assert_lt(moved.dot(bus.forward_vector()), -2.0, "bus moved backwards")
	assert_gt(bus.body.reverse_material.emission_energy_multiplier, 1.0, "reverse lights on")

	await driver.tap_key(KEY_R)
	assert_true(bus.reverse_gear, "can't shift while rolling")
	assert_eq(session.hud.message_label.text, "Stop the bus to change gear")

	driver.key(KEY_W, false)
	driver.key(KEY_S, true)
	await wait_until(func() -> bool: return absf(bus.forward_speed()) < 0.2, 6.0)
	driver.key(KEY_S, false)
	await driver.tap_key(KEY_R)
	assert_false(bus.reverse_gear, "back into drive once stopped")
	driver.key(KEY_W, true)
	await wait_seconds(3.0)
	assert_gt(bus.forward_speed(), 2.0, "and drives forward again")


func test_touch_gear_and_light_buttons() -> void:
	var controls := session.touch_controls
	driver.touch(controls.gear_button, true)
	await wait_process_frames(1)
	driver.touch(controls.gear_button, false)
	assert_true(session.bus.reverse_gear)
	driver.touch(controls.lights_button, true, 1)
	await wait_process_frames(1)
	driver.touch(controls.lights_button, false, 1)
	assert_eq(session.bus.light_mode, Bus.LOW_BEAM)
	await wait_physics_frames(2)
	assert_true(controls.lights_button.lit)
	assert_eq(controls.lights_button.glow, ControlArt.LOW_BEAM, "green low-beam icon")
	await driver.tap_key(KEY_L)
	assert_eq(session.bus.light_mode, Bus.HIGH_BEAM, "L switches to high beam")
	await wait_physics_frames(2)
	assert_eq(controls.lights_button.icon, "light_high")
	assert_eq(controls.lights_button.glow, ControlArt.HIGH_BEAM, "blue high-beam icon")
	await driver.tap_key(KEY_L)
	assert_false(session.bus.headlights_on, "and off again")
	await wait_physics_frames(2)
	assert_false(controls.lights_button.lit)


func test_night_map_starts_with_lights_on() -> void:
	await driver.tap_key(KEY_ESCAPE)
	await wait_process_frames(2)
	await driver.select_option(driver.main.menu.map_picker, "tokyo")
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var bus: Bus = driver.main.session.bus
	assert_true(bus.headlights_on)
	assert_true(bus.body.cabin_light.visible)
	driver.key(KEY_S, true)
	await wait_physics_frames(10)
	assert_gt(bus.body.tail_material.emission_energy_multiplier, 3.0, "brake lights glow")
