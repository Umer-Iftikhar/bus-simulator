extends TestCase
## Door animation and headlights on the bus.

var world: FlatWorld
var bus: Bus


func before_each() -> void:
	world = add_child_autofree(FlatWorld.create())
	bus = await world.spawn_bus(self)


func test_doors_start_closed_on_the_kerb_side() -> void:
	assert_false(bus.doors_open)
	assert_vec3_almost_eq(bus.door.position, bus.door_closed_position(), 0.001)
	assert_lt(bus.door.position.x, -bus.spec.width / 2.0 + 0.01, "right (-X) side, toward the kerb")
	assert_gt(bus.door.position.z, 0.0, "front half of the bus")


func test_doors_slide_open_and_closed() -> void:
	bus.open_doors()
	assert_true(bus.doors_open)
	await wait_seconds(Bus.DOOR_TIME + 0.1)
	assert_vec3_almost_eq(bus.door.position, bus.door_open_position(), 0.01)
	bus.close_doors()
	await wait_seconds(Bus.DOOR_TIME + 0.1)
	assert_false(bus.doors_open)
	assert_vec3_almost_eq(bus.door.position, bus.door_closed_position(), 0.01)


func test_door_is_mid_travel_while_animating() -> void:
	bus.open_doors()
	await wait_seconds(Bus.DOOR_TIME / 2.0)
	var travelled := bus.door.position.distance_to(bus.door_closed_position())
	assert_between(travelled, 0.1, Bus.DOOR_TRAVEL - 0.1)


func test_headlights_off_by_default_and_switchable() -> void:
	assert_eq(bus.headlights.size(), 2)
	for lamp in bus.headlights:
		assert_false(lamp.visible)
	bus.set_headlights(true)
	for lamp in bus.headlights:
		assert_true(lamp.visible)
		var shine := -lamp.global_basis.z
		assert_gt(shine.dot(bus.global_basis.z), 0.95, "%s points forward" % lamp.name)
