extends TestCase
## End-to-end gameplay loop: pick map and bus -> drive the route stopping at
## every stop -> get paid -> progress is saved and survives a restart.

var driver: GameDriver


func before_each() -> void:
	driver = GameDriver.new(self)


func after_each() -> void:
	driver.release_all()
	driver.cleanup_save()


func _drive(skip: Array = []) -> Dictionary:
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	var pilot := Autopilot.new(session.bus, session.world.track)
	pilot.traffic = session.traffic
	var finished := await pilot.drive_route(get_tree(), session.run, skip)
	assert_true(finished, "route completed by driving")
	assert_gt(session.traffic.cars.size(), 0, "driven in live traffic")
	assert_eq(session.damage.health_percent(), 100, "careful driving in traffic causes no damage")
	await wait_process_frames(2)
	return session.run.result()


func test_full_route_pays_out_and_persists() -> void:
	await driver.boot()
	var result := await _drive()
	assert_true(result["completed"])
	assert_eq(result["missed_stops"], 0)
	assert_gt(result["delivered"], 5, "a full route moves real numbers of people")
	assert_eq(result["payout"], result["delivered"] * Maps.islamabad().fare)
	var session: DriveSession = driver.main.session
	assert_not_null(session.results_panel, "results shown")
	assert_true(session.results_panel.lines.text.contains("$%d" % result["payout"]))
	assert_eq(driver.main.save.money, result["payout"], "paid into the wallet")
	assert_eq(driver.saved_state().money, result["payout"], "written to disk")
	assert_eq(driver.saved_state().stats["runs"], 1)

	await driver.click(session.results_panel.continue_button)
	await wait_process_frames(2)
	assert_not_null(driver.main.menu, "back at the menu")
	assert_eq(driver.main.menu.money_label.text, "$%d" % result["payout"])

	# Restart the game from the same save file: money survives.
	var path := driver.save_path
	driver.main.free()
	await driver.boot(null, path)
	assert_eq(driver.main.save.money, result["payout"])


func test_skipping_a_stop_strands_passengers_and_costs_money() -> void:
	await driver.boot()
	var full := await _drive()
	await driver.click(driver.main.session.results_panel.continue_button)
	await wait_process_frames(2)
	var partial := await _drive([2, 3])
	assert_eq(partial["missed_stops"], 2)
	assert_gt(partial["stranded"], full["stranded"])
	assert_lt(partial["payout"], full["payout"], "same seed, fewer stops served, less pay")
	assert_eq(driver.main.save.money, full["payout"] + partial["payout"])


func test_quitting_mid_route_pays_nothing() -> void:
	await driver.boot()
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	await driver.tap_key(KEY_ESCAPE)
	await wait_process_frames(2)
	assert_eq(driver.main.save.money, 0)
	assert_eq(driver.main.save.stats["runs"], 0)
