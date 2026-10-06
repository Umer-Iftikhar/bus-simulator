extends TestCase
## Night maps, door animation at stops and the mirror quality setting.

var session: DriveSession


func _start(map: MapDef, options := {}) -> void:
	options["seed"] = 4
	options["traffic"] = false
	session = DriveSession.create(map, BusSpec.new(), options)
	add_child_autofree(session)
	await wait_physics_frames(3)


func test_night_map_turns_headlights_on_and_dims_the_sun() -> void:
	await _start(Maps.pines())
	for lamp in session.bus.headlights:
		assert_true(lamp.visible)
	var sun := session.world.get_node("Sun") as DirectionalLight3D
	assert_lt(sun.light_energy, 0.5)


func test_day_map_keeps_headlights_off() -> void:
	await _start(Maps.harbor())
	for lamp in session.bus.headlights:
		assert_false(lamp.visible)


func test_doors_open_when_a_stop_is_served_then_close() -> void:
	await _start(Maps.harbor())
	var xform := session.world.track.vehicle_transform(0, session.map.stop_offset(0))
	xform.origin.y = 0.3
	session.bus.global_transform = xform
	var opened := await wait_until(func() -> bool: return session.bus.doors_open, 3.0)
	assert_true(opened, "doors open at the stop")
	assert_eq(session.run.route.next_stop, 1)
	var closed := await wait_until(
		func() -> bool: return not session.bus.doors_open, DriveSession.DOOR_OPEN_SECONDS + 1.0
	)
	assert_true(closed, "doors close again before driving off")


func test_every_map_builds_a_playable_session() -> void:
	for map in Maps.all():
		await _start(map)
		assert_eq(session.run.stops.size(), map.stops.size(), map.id)
		assert_eq(session.world.track.lane_at(session.bus.global_position), 0, map.id)
		session.free()


func test_main_menu_mirror_quality_picker_updates_settings() -> void:
	var save := SaveData.new_game()
	var menu := add_child_autofree(MainMenu.create(save, Garage.new(save))) as MainMenu
	watch_signals(menu)
	menu.mirror_quality_picker.select(1)
	menu.mirror_quality_picker.item_selected.emit(1)
	assert_eq(save.settings["mirror_quality"], "low")
	assert_signal_emitted(menu, "selection_changed")
