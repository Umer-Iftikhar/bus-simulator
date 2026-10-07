extends TestCase
## The next-stop readout, approach banner and stop beacon while driving.

var session: DriveSession


func before_each() -> void:
	session = DriveSession.create(Maps.islamabad(), BusSpec.new(), {"seed": 2, "traffic": false})
	add_child_autofree(session)
	await wait_physics_frames(3)


func _place(offset: float) -> void:
	var xform := session.world.track.vehicle_transform(0, offset)
	xform.origin.y += 0.3
	session.bus.global_transform = xform
	session.bus.linear_velocity = Vector3.ZERO


## Moves the bus forward in hops so the run's progress tracking follows.
func _drive_to(offset: float) -> void:
	var current := session.world.track.closest_offset(session.bus.global_position)
	while session.world.track.distance_ahead(current, offset) > 15.0:
		current += 12.0
		_place(current)
		await wait_physics_frames(2)
	_place(offset)
	await wait_physics_frames(3)
	await wait_process_frames(1)


func test_far_from_a_stop_shows_distance_without_banner() -> void:
	var stop1 := session.map.stop_offset(1)
	await _drive_to(session.map.stop_offset(0))
	await wait_seconds(1.5)
	await _drive_to(stop1 - 520.0)
	var hud := session.hud
	assert_true(hud.stop_label.text.begins_with("Next: Blue Area ("), hud.stop_label.text)
	assert_true(hud.stop_label.text.ends_with(" m)") or hud.stop_label.text.ends_with(" km)"))
	assert_false(hud.approach_panel.visible, "no banner 500 m out")


func test_banner_counts_down_when_a_stop_is_near() -> void:
	await _drive_to(session.map.stop_offset(0))
	await wait_seconds(1.5)
	var stop1 := session.map.stop_offset(1)
	await _drive_to(stop1 - 250.0)
	var hud := session.hud
	assert_true(hud.approach_panel.visible, "banner within 400 m")
	assert_eq(hud.approach_title.text, "BUS STOP AHEAD")
	assert_true(hud.approach_detail.text.begins_with("Blue Area"))
	var far := hud.approach_detail.text
	await _drive_to(stop1 - 80.0)
	assert_ne(hud.approach_detail.text, far, "distance counts down")
	assert_true(hud.approach_detail.text.ends_with(" m"))
	await _drive_to(stop1)
	assert_eq(hud.approach_title.text, "STOP HERE")


func test_only_the_next_stop_has_a_beacon() -> void:
	var stops := session.run.stops
	assert_true(stops[0].is_highlighted())
	for i in range(1, stops.size()):
		assert_false(stops[i].is_highlighted())
	await _drive_to(session.map.stop_offset(0))
	await wait_seconds(1.5)
	assert_false(stops[0].is_highlighted(), "served stop loses its beacon")
	assert_true(stops[1].is_highlighted(), "beacon moves to the next stop")


func test_stop_has_shelter_sign_and_bay() -> void:
	var stop: BusStop = session.run.stops[1]
	for part in [
		"Shelter", "ShelterBack", "ShelterBench", "Timetable", "SignPole", "SignPlate", "BayText"
	]:
		assert_not_null(stop.find_child(part, true, false), part)
