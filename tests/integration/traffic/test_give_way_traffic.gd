extends TestCase
## Traffic reacting to the bus's signalled lane changes.

var map: MapDef
var track: Track
var world: GameWorld
var bus: Bus
var traffic: TrafficManager


func before_each() -> void:
	map = Maps.harbor()
	track = map.track()
	world = add_child_autofree(GameWorld.create(map))
	bus = Bus.create(Catalog.bus_spec("city"))
	world.add_child(bus)
	var xform := track.vehicle_transform(0, 200.0)
	xform.origin.y = 0.3
	bus.global_transform = xform
	traffic = TrafficManager.create(track, bus)
	world.add_child(traffic)
	await wait_physics_frames(3)


func _car(lane: int, offset: float, speed: float) -> TrafficCar:
	var car := TrafficCar.create(track, lane, offset, Color.BLUE)
	car.speed = speed
	car.desired_speed = speed
	traffic.cars.append(car)
	traffic.add_child(car)
	return car


func _gap_behind_bus(car: TrafficCar) -> float:
	var bus_rear := track.closest_offset(bus.global_position) - bus.spec.length / 2.0
	return track.distance_ahead(car.front_offset(), bus_rear)


func test_without_signal_car_in_other_lane_drives_past() -> void:
	var car := _car(1, 170.0, 11.0)
	await wait_seconds(6.0)
	assert_false(car.yielding)
	assert_gt(car.speed, 10.5)
	assert_gt(track.distance_ahead(200.0, car.offset), 20.0, "passed the bus")


func test_signalling_makes_car_behind_in_target_lane_drop_back() -> void:
	var car := _car(1, 170.0, 11.0)
	traffic.signal_lane = 1
	await wait_seconds(8.0)
	assert_true(car.yielding)
	assert_lt(car.speed, 0.5, "stopped to let the stationary bus out")
	var gap := _gap_behind_bus(car)
	assert_between(gap, GiveWay.EXTRA_GAP, 25.0, "left a gap behind the bus to merge into")


func test_yielding_never_brake_checks() -> void:
	var car := _car(1, 186.0, 12.0)
	var slowest_change := 0.0
	traffic.signal_lane = 1
	var previous := car.speed
	for i in 240:
		await get_tree().physics_frame
		slowest_change = minf(slowest_change, (car.speed - previous) * 60.0)
		previous = car.speed
	assert_ge(slowest_change, -GiveWay.MAX_YIELD_DECEL - 0.01, "comfortable braking only")


func test_cars_ahead_and_in_other_lane_ignore_the_signal() -> void:
	var ahead := _car(1, 215.0, 10.0)
	var other_lane := _car(0, 120.0, 10.0)
	traffic.signal_lane = 1
	await wait_seconds(3.0)
	assert_false(ahead.yielding)
	assert_gt(ahead.speed, 9.5)
	assert_false(other_lane.yielding, "same lane as bus: follows normally instead")


func test_cancelling_the_signal_releases_the_car() -> void:
	var car := _car(1, 170.0, 11.0)
	traffic.signal_lane = 1
	await wait_seconds(6.0)
	traffic.signal_lane = -1
	await wait_seconds(6.0)
	assert_false(car.yielding)
	assert_gt(car.speed, 8.0, "carries on once the bus stops signalling")


func test_bus_merges_into_opened_gap_without_contact() -> void:
	var car := _car(1, 165.0, 11.0)
	traffic.signal_lane = 1
	await wait_seconds(6.0)
	var damage := DamageModel.new()
	bus.impact.connect(damage.apply_impact)
	var player := PlayerInput.new()
	player.bus = bus
	world.add_child(player)
	var pilot := Autopilot.new(bus, track)
	pilot.lane = 1
	pilot.cruise_speed = 6.0
	for i in 60 * 8:
		pilot.step()
		await get_tree().physics_frame
	pilot.release()
	assert_eq(track.lane_at(bus.global_position), 1, "bus is now in the left lane")
	assert_true(damage.is_pristine(), "no collision during the merge")
	assert_gt(_gap_behind_bus(car), 1.0, "car still behind the bus")
