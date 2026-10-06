extends TestCase
## DriveSession reacting to damage: speed loss, HUD, wreck -> failed run.

var session: DriveSession


func _start(options := {}) -> void:
	options["seed"] = 3
	options["traffic"] = options.get("traffic", false)
	session = DriveSession.create(Maps.harbor(), BusSpec.new(), options)
	add_child_autofree(session)
	await wait_physics_frames(3)


func test_starts_pristine_with_full_health_shown() -> void:
	await _start()
	assert_eq(session.damage.health_percent(), 100)
	assert_eq(session.bus.damage_speed_factor, 1.0)
	assert_eq(session.hud.health_label.text, "Bus health: 100%")


func test_existing_damage_is_carried_into_the_session() -> void:
	await _start({"damage": {"body_front": 0.2, "mirror_left": 0.0}})
	assert_lt(session.damage.health_percent(), 100)
	assert_lt(session.bus.damage_speed_factor, 1.0)
	assert_true(session.damage.is_mirror_broken(DamageModel.MIRROR_LEFT))
	assert_ne(session.bus.body_color(), session.bus.get_paint(), "looks beat-up")


func test_impacts_lower_health_top_speed_and_hud() -> void:
	await _start()
	session.bus.impact.emit(DamageModel.BODY_FRONT, 12.0)
	await wait_process_frames(1)
	var percent := session.damage.health_percent()
	assert_lt(percent, 100)
	assert_eq(session.hud.health_label.text, "Bus health: %d%%" % percent)
	assert_lt(session.bus.effective_top_speed(), session.bus.spec.top_speed)


func test_mirror_hit_flashes_message() -> void:
	await _start()
	session.bus.impact.emit(DamageModel.MIRROR_RIGHT, 3.0)
	assert_eq(session.hud.message_label.text, "Right mirror smashed!")


func test_wrecking_the_bus_fails_the_run() -> void:
	await _start()
	watch_signals(session)
	for part in [DamageModel.BODY_FRONT, DamageModel.BODY_REAR]:
		session.bus.impact.emit(part, 100.0)
	for part in [DamageModel.BODY_LEFT, DamageModel.BODY_RIGHT]:
		session.bus.impact.emit(part, 100.0)
	await wait_process_frames(1)
	assert_true(session.damage.is_wrecked())
	assert_signal_emitted(session, "run_finished")
	var result: Dictionary = get_signal_parameters(session, "run_finished")[0]
	assert_true(result["failed"])
	assert_eq(result["payout"], 0)
	assert_false(session.bus.controls_enabled, "undrivable")
	assert_eq(session.results_panel.title.text, "Bus wrecked!")


func test_traffic_option_controls_spawning() -> void:
	await _start({"traffic": true})
	assert_eq(session.traffic.cars.size(), Maps.harbor().traffic_cars)
	session.free()
	await _start({"traffic": false})
	assert_eq(session.traffic.cars.size(), 0)
