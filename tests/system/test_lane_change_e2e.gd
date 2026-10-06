extends TestCase
## End-to-end give-way: a car is coming up fast in the left lane. Signal with
## the indicator key and it drops back so the bus can merge safely; don't
## signal and it simply drives past.

var driver: GameDriver
var session: DriveSession
var car: TrafficCar
var pilot: Autopilot


func before_each() -> void:
	driver = GameDriver.new(self)
	await driver.boot()
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	session = driver.main.session
	# Replace random traffic with one known car in the left lane, behind the bus.
	for existing in session.traffic.cars:
		existing.queue_free()
	session.traffic.cars.clear()
	var track := session.world.track
	var bus_offset := track.closest_offset(session.bus.global_position)
	car = TrafficCar.create(track, 1, bus_offset - 35.0, Color.MAGENTA)
	car.speed = 12.0
	car.desired_speed = 12.0
	session.traffic.cars.append(car)
	session.traffic.add_child(car)
	pilot = Autopilot.new(session.bus, track)
	pilot.cruise_speed = 6.0


func after_each() -> void:
	pilot.release()
	driver.release_all()
	driver.cleanup_save()


func _drive(seconds: float) -> void:
	for i in int(seconds * 60):
		pilot.step()
		await get_tree().physics_frame


func _car_is_behind_bus() -> bool:
	var track := session.world.track
	var bus_offset := track.closest_offset(session.bus.global_position)
	return track.distance_ahead(car.offset, bus_offset) < 100.0


func test_signalled_merge_is_given_way() -> void:
	await _drive(1.0)
	await driver.tap_key(KEY_Q)
	assert_eq(session.indicators.side, Indicators.Turn.LEFT)
	await _drive(3.0)
	assert_true(car.yielding, "car saw the indicator and is giving way")
	assert_true(_car_is_behind_bus(), "car held back instead of overtaking")
	pilot.lane = 1
	await _drive(7.0)
	assert_eq(session.current_lane(), 1, "bus merged into the left lane")
	assert_eq(session.damage.health_percent(), 100, "no collision")
	assert_true(_car_is_behind_bus(), "car is following behind the bus")
	assert_false(session.indicators.is_active(), "indicator cancelled after the lane change")
	assert_false(session.bus.is_lamp_lit("front_left"))


func test_without_signal_traffic_does_not_give_way() -> void:
	await _drive(6.0)
	assert_false(car.yielding)
	assert_false(_car_is_behind_bus(), "car overtook the unsignalling bus")
