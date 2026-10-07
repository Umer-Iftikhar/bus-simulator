extends TestCase
## Every map must be drivable: an autopilot using the player's input actions
## completes a full lap (bridges, hills and all) without leaving the road or
## rolling over, with the two most demanding buses: the long city bus (widest
## turning circle) and the double decker (heaviest, tallest climber).

const LAP_TIME_LIMIT := 480.0
const HARDEST_BUSES := ["long_city", "double_decker"]


func after_each() -> void:
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")


# One test per map so CI can run the maps in parallel shards.
func test_lap_islamabad() -> void:
	await _laps("islamabad")


func test_lap_washington() -> void:
	await _laps("washington")


func test_lap_rawalakot() -> void:
	await _laps("rawalakot")


func test_lap_tokyo() -> void:
	await _laps("tokyo")


func test_lap_new_york() -> void:
	await _laps("new_york")


func test_there_is_a_lap_test_for_every_map() -> void:
	var methods := (get_script() as Script).get_script_method_list().map(
		func(m: Dictionary) -> String: return m["name"]
	)
	for map_id in Maps.ids():
		assert_has(methods, "test_lap_" + map_id)


func _laps(map_id: String) -> void:
	for bus_id in HARDEST_BUSES:
		await _drive_lap(Maps.get_map(map_id), bus_id)


func _drive_lap(map: MapDef, bus_id: String) -> void:
	var session := DriveSession.create(map, Catalog.bus_spec(bus_id), {"seed": 1, "traffic": false})
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
	var where := "%s on %s" % [bus_id, map.id]
	assert_ge(
		progress,
		track.length(),
		"%s: lap completed (%.0f / %.0f m)" % [where, progress, track.length()]
	)
	assert_eq(off_road, 0, "%s: frames off the road" % where)
	assert_lt(max_lateral_error, Track.LANE_WIDTH, "%s: stays near its lane" % where)
	assert_gt(min_up, 0.9, "%s: never close to rolling" % where)
	session.free()
