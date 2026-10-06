extends TestCase
## Every map must be drivable end to end: an autopilot using the player's input
## actions completes a full lap without leaving the road or rolling the bus.

const LAP_TIME_LIMIT := 240.0


func after_each() -> void:
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")


func test_autopilot_completes_a_lap_on_every_map() -> void:
	for map in Maps.all():
		await _drive_lap(map)


func _drive_lap(map: MapDef) -> void:
	var session := DriveSession.create(map, BusSpec.new())
	add_child_autofree(session)
	await wait_seconds(1.0)
	var bus := session.bus
	var track := session.world.track
	var pilot := Autopilot.new(bus, track)
	var last_offset := track.closest_offset(bus.global_position)
	var progress := 0.0
	var off_road := 0
	var min_up := 1.0
	var max_lateral_error := 0.0
	var ticks := int(LAP_TIME_LIMIT * Engine.physics_ticks_per_second)
	for i in ticks:
		pilot.step()
		await get_tree().physics_frame
		var offset := track.closest_offset(bus.global_position)
		var step := track.distance_ahead(last_offset, offset)
		if step < 50.0:
			progress += step
		last_offset = offset
		if track.lane_at(bus.global_position) == -1:
			off_road += 1
		var lateral := track.lateral_of(bus.global_position)
		max_lateral_error = maxf(max_lateral_error, absf(lateral - Track.lane_lateral(0)))
		min_up = minf(min_up, bus.global_transform.basis.y.dot(Vector3.UP))
		if progress >= track.length():
			break
	pilot.release()
	var where := "map %s" % map.id
	assert_ge(
		progress,
		track.length(),
		"%s: lap completed (%.0f / %.0f m)" % [where, progress, track.length()]
	)
	assert_eq(off_road, 0, "%s: frames off the road" % where)
	assert_lt(max_lateral_error, Track.LANE_WIDTH, "%s: stays near its lane" % where)
	assert_gt(min_up, 0.9, "%s: never close to rolling" % where)
	session.free()
