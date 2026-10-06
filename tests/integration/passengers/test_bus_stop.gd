extends TestCase
## BusStop Area3D trigger detecting the bus, plus its waiting-passenger display.

var world: FlatWorld
var track: Track
var stop: BusStop


func before_each() -> void:
	world = add_child_autofree(FlatWorld.create())
	track = Track.from_points(
		PackedVector2Array([Vector2(0, 0), Vector2(600, 0), Vector2(600, 300), Vector2(0, 300)])
	)
	stop = BusStop.create(2, "Market St", track, 200.0, false)
	world.add_child(stop)


func _bus_at(lane: int, offset: float) -> Bus:
	var bus := Bus.create(BusSpec.new())
	world.add_child(bus)
	var xform := track.vehicle_transform(lane, offset)
	xform.origin.y = 0.3
	bus.global_transform = xform
	await wait_physics_frames(6)
	return bus


func test_stop_sits_in_the_kerb_lane() -> void:
	assert_eq(track.lane_at(stop.global_position), 0)
	assert_eq(stop.collision_mask, Layers.PLAYER)


func test_detects_bus_parked_in_zone() -> void:
	await _bus_at(0, 200.0)
	assert_true(stop.bus_inside())


func test_ignores_bus_in_the_other_lane_or_far_away() -> void:
	await _bus_at(1, 200.0)
	await _bus_at(0, 260.0)
	assert_false(stop.bus_inside())


func test_detects_bus_leaving() -> void:
	var bus := await _bus_at(0, 200.0)
	var xform := track.vehicle_transform(0, 300.0)
	xform.origin.y = 0.3
	bus.global_transform = xform
	await wait_physics_frames(6)
	assert_false(stop.bus_inside())


func test_waiting_figures_and_sign() -> void:
	stop.set_waiting(4)
	assert_eq(stop.figure_count(), 4)
	assert_eq(stop.waiting(), 4)
	assert_true((stop.get_node("Sign") as Label3D).text.contains("4 waiting"))
	stop.set_waiting(25)
	assert_eq(stop.figure_count(), BusStop.MAX_FIGURES, "figures are capped")
	stop.set_waiting(0)
	assert_eq(stop.figure_count(), 0)
	assert_eq((stop.get_node("Sign") as Label3D).text, "Market St")
