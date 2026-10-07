extends TestCase
## Traffic cars on a real map, following each other and the player's bus.

var map: MapDef
var world: GameWorld
var bus: Bus
var traffic: TrafficManager


func before_each() -> void:
	map = Maps.islamabad()
	world = add_child_autofree(GameWorld.create(map))
	bus = Bus.create(BusSpec.new())
	world.add_child(bus)
	_place_bus(0, 6.0)
	traffic = TrafficManager.create(map.track(), bus)
	world.add_child(traffic)
	await wait_physics_frames(2)


func _place_bus(lane: int, offset: float) -> void:
	var xform := map.track().vehicle_transform(lane, offset)
	xform.origin.y += 0.3
	bus.global_transform = xform
	bus.linear_velocity = Vector3.ZERO


func _car(lane: int, offset: float, speed: float, desired: float) -> TrafficCar:
	var car := TrafficCar.create(map.track(), lane, offset, Color.RED)
	car.speed = speed
	car.desired_speed = desired
	traffic.cars.append(car)
	traffic.add_child(car)
	return car


func test_spawn_places_cars_in_both_lanes_clear_of_the_bus() -> void:
	traffic.spawn(8, 3, 6.0)
	assert_eq(traffic.cars.size(), 8)
	var lanes := {}
	var track := map.track()
	for car in traffic.cars:
		lanes[car.lane] = true
		var ahead := track.distance_ahead(6.0, car.offset)
		assert_gt(ahead, TrafficManager.SPAWN_CLEAR_AHEAD - 5.0, "not on top of the bus")
		assert_lt(ahead, track.length() - TrafficManager.SPAWN_CLEAR_BEHIND + 5.0)
		assert_between(car.desired_speed, 8.5, 12.5)
		assert_eq(car.collision_layer, Layers.TRAFFIC)
	assert_eq(lanes.size(), 2)


func test_spawn_is_deterministic_per_seed() -> void:
	traffic.spawn(6, 9, 6.0)
	var first := traffic.cars.map(func(c: TrafficCar) -> float: return c.offset)
	var other := TrafficManager.create(map.track(), bus)
	world.add_child(other)
	other.spawn(6, 9, 6.0)
	assert_eq(other.cars.map(func(c: TrafficCar) -> float: return c.offset), first)


func test_cars_stay_on_their_lane_and_drive_forward() -> void:
	traffic.spawn(6, 1, 6.0)
	var start := traffic.cars.map(func(c: TrafficCar) -> float: return c.offset)
	await wait_seconds(10.0)
	var track := map.track()
	for i in traffic.cars.size():
		var car := traffic.cars[i]
		assert_eq(track.lane_at(car.global_position), car.lane, "%s keeps its lane" % car.name)
		assert_almost_eq(
			car.global_position.y, track.position_at(car.offset).y, 0.05, "on the road"
		)
		assert_gt(track.distance_ahead(start[i], car.offset), 50.0, "%s moved on" % car.name)
		assert_le(car.speed, car.desired_speed + 0.1)


func test_cars_never_overlap_over_a_long_drive() -> void:
	traffic.spawn(14, 4, 6.0)
	var track := map.track()
	var tightest := INF
	for step in 60:
		await wait_seconds(1.0)
		for a in traffic.cars:
			for b in traffic.cars:
				if a != b and a.lane == b.lane:
					var gap := track.distance_ahead(a.front_offset(), b.rear_offset())
					if gap < track.length() / 2.0:
						tightest = minf(tightest, gap)
	assert_gt(tightest, 1.0, "closest bumper gap %.2fm" % tightest)


func test_fast_car_slows_behind_slow_car() -> void:
	var slow := _car(0, 300.0, 5.0, 5.0)
	var fast := _car(0, 240.0, 12.0, 12.0)
	await wait_seconds(30.0)
	assert_almost_eq(fast.speed, slow.speed, 0.6, "fast car settles to leader speed")
	var gap := map.track().distance_ahead(fast.front_offset(), slow.rear_offset())
	assert_between(gap, 3.0, 20.0)


func test_car_stops_behind_stationary_bus_in_its_lane() -> void:
	var car := _car(0, map.track().wrap_offset(-60.0), 11.0, 11.0)
	await wait_seconds(15.0)
	assert_lt(car.speed, 0.2, "queued behind the bus")
	var gap := map.track().distance_ahead(car.front_offset(), 6.0 - bus.spec.length / 2.0)
	assert_between(gap, 1.5, 10.0, "stopped a sensible distance back")


func test_car_in_other_lane_passes_stationary_bus() -> void:
	var car := _car(1, map.track().wrap_offset(-60.0), 11.0, 11.0)
	await wait_seconds(12.0)
	assert_gt(car.speed, 8.0, "no reason to stop")
	assert_gt(map.track().distance_ahead(6.0, car.offset), 30.0, "drove past the bus")


func test_car_brakes_for_bus_straddling_lanes() -> void:
	var track := map.track()
	var xform := track.vehicle_transform(0, 6.0)
	xform.origin += track.right_at(6.0) * -Track.LANE_WIDTH / 2.0
	xform.origin.y += 0.3
	bus.global_transform = xform
	var car := _car(1, track.wrap_offset(-60.0), 11.0, 11.0)
	await wait_seconds(15.0)
	assert_lt(car.speed, 0.2, "a bus across both lanes blocks the overtaking lane too")


func test_car_ahead_of_bus_is_not_blocked_by_it() -> void:
	var car := _car(0, 6.0 + bus.spec.length / 2.0 + TrafficCar.LENGTH / 2.0 + 0.5, 0.0, 10.0)
	await wait_seconds(5.0)
	assert_gt(car.speed, 5.0, "drives away from the bus behind it")


func test_nearest_ahead() -> void:
	var near := _car(0, 60.0, 0.0, 0.0)
	_car(0, 120.0, 0.0, 0.0)
	_car(1, 30.0, 0.0, 0.0)
	assert_eq(traffic.nearest_ahead(bus.global_position, 0, 200.0), near)
	assert_null(traffic.nearest_ahead(bus.global_position, 0, 20.0))


func test_cars_have_glowing_head_and_tail_lights() -> void:
	var car := _car(0, 100.0, 0.0, 0.0)
	var glowing := 0
	for child in car.get_children():
		if child is MeshInstance3D:
			var material := (child as MeshInstance3D).mesh.surface_get_material(0)
			if material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled:
				glowing += 1
	assert_eq(glowing, 4, "two headlights, two tail lights")
