extends TestCase
## End-to-end turn-signal setting: pick "Indicators: Auto" in the main menu,
## then drive into a stop and away again. The bus signals right into the stop
## and left to pull out on its own; with "Manual" it never signals by itself.

var driver: GameDriver
var pilot: Autopilot


func before_each() -> void:
	driver = GameDriver.new(self)
	await driver.boot()


func after_each() -> void:
	if pilot != null:
		pilot.release()
	driver.release_all()
	driver.cleanup_save()


## Drives to the next stop, serves it and pulls away. Returns every signal
## side seen, tagged "approach" (before serving) or "leave" (after).
func _serve_next_stop(session: DriveSession) -> Dictionary:
	# No traffic, so lane drift comes only from the bus.
	for car in session.traffic.cars:
		car.queue_free()
	session.traffic.cars.clear()
	pilot = Autopilot.new(session.bus, session.world.track)
	var run := session.run
	var index := run.route.next_stop
	pilot.stop_at = run.map.stop_offset(index)
	var seen := {"approach": {}, "leave": {}}
	var phase := "approach"
	var leave_ticks := 0
	for i in 240 * 60:
		pilot.step()
		await get_tree().physics_frame
		if phase == "approach" and run.route.next_stop != index:
			phase = "leave"
			pilot.stop_at = -1.0
		if phase == "leave":
			leave_ticks += 1
			if leave_ticks > 10 * 60:
				break
		seen[phase][session.indicators.side] = true
	pilot.release()
	return seen


func test_auto_indicators_signal_into_and_out_of_a_stop() -> void:
	await driver.select_option(driver.main.menu.indicator_picker, "auto")
	assert_true(driver.saved_state().auto_indicators(), "setting saved")
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	assert_not_null(session.auto_indicator)
	var seen := await _serve_next_stop(session)
	assert_true(seen["approach"].has(Indicators.Turn.RIGHT), "signals right into the stop")
	assert_true(seen["leave"].has(Indicators.Turn.LEFT), "signals left to pull out")
	assert_eq(session.indicators.side, Indicators.Turn.NONE, "and switches off once under way")


func test_manual_indicators_stay_off_unless_pressed() -> void:
	assert_false(driver.saved_state().auto_indicators(), "manual by default")
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	assert_null(session.auto_indicator)
	var seen := await _serve_next_stop(session)
	assert_eq(seen["approach"].keys(), [Indicators.Turn.NONE])
	assert_eq(seen["leave"].keys(), [Indicators.Turn.NONE])
