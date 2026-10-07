extends TestCase
## DriveSession composing world, bus, run, HUD and results.

var session: DriveSession


func _start(options := {}) -> void:
	options["seed"] = options.get("seed", 5)
	session = DriveSession.create(Maps.islamabad(), Catalog.bus_spec("city"), options)
	add_child_autofree(session)
	await wait_physics_frames(3)


func test_performance_factors_are_applied_to_the_bus() -> void:
	var perf := {"top_speed": 1.12, "acceleration": 1.3, "brakes": 1.2, "handling": 1.36}
	await _start({"performance": perf})
	assert_eq(session.bus.top_speed_factor, 1.12)
	assert_eq(session.bus.acceleration_factor, 1.3)
	assert_eq(session.bus.brake_factor, 1.2)
	assert_eq(session.bus.handling_factor, 1.36)


func test_defaults_to_stock_performance() -> void:
	await _start()
	assert_eq(session.bus.top_speed_factor, 1.0)
	assert_eq(session.bus.handling_factor, 1.0)


func test_hud_shows_route_information() -> void:
	await _start()
	await wait_process_frames(1)
	assert_true(session.hud.stop_label.text.begins_with("Next: Zero Point"))
	assert_eq(session.hud.passengers_label.text, "Passengers: 0 / 32")
	assert_eq(session.hud.fares_label.text, "Fares: $0")


func test_serving_a_stop_flashes_message_and_updates_passengers() -> void:
	await _start()
	var run := session.run
	var xform := session.world.track.vehicle_transform(0, session.map.stop_offset(0))
	xform.origin.y += 0.3
	session.bus.global_transform = xform
	await wait_seconds(2.0)
	assert_eq(run.route.next_stop, 1)
	assert_true(session.hud.message_label.visible)
	assert_true(session.hud.message_label.text.begins_with("Zero Point:"))
	var expected := "Passengers: %d / 32" % run.route.on_board_count()
	assert_eq(session.hud.passengers_label.text, expected)


func test_finishing_shows_results_and_disables_driving() -> void:
	await _start()
	watch_signals(session)
	session.run.fail_run()
	await wait_process_frames(1)
	assert_signal_emitted(session, "run_finished")
	assert_not_null(session.results_panel)
	assert_false(session.bus.controls_enabled)
	assert_false(session.touch_controls.visible)
	session.results_panel.continue_button.pressed.emit()
	assert_signal_emitted(session, "exit_requested")


func test_same_seed_gives_same_passengers() -> void:
	await _start({"seed": 77})
	var first := []
	for stop in session.run.stops:
		first.append(stop.waiting())
	session.free()
	await _start({"seed": 77})
	var second := []
	for stop in session.run.stops:
		second.append(stop.waiting())
	assert_eq(second, first)
