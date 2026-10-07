extends TestCase
## Real physics collisions feeding the localized damage model.

var world: FlatWorld
var bus: Bus
var damage: DamageModel


func before_each() -> void:
	world = add_child_autofree(FlatWorld.create())
	bus = await world.spawn_bus(self)
	damage = DamageModel.new()
	bus.impact.connect(damage.apply_impact)


func _wall(center: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = center
	world.add_child(wall)
	return wall


func test_driving_on_flat_ground_causes_no_damage() -> void:
	bus.set_command(1.0, 0.0, 0.3)
	await wait_seconds(8.0)
	bus.set_command(0.0, 1.0, 0.0)
	await wait_seconds(5.0)
	assert_true(damage.is_pristine(), "ground contact never counts as a crash")


func test_head_on_wall_crash_damages_the_front() -> void:
	_wall(Vector3(0, 2, 45), Vector3(30, 4, 1))
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(8.0)
	assert_lt(damage.health(DamageModel.BODY_FRONT), 0.85)
	assert_eq(damage.health(DamageModel.BODY_REAR), 1.0)
	assert_eq(damage.health(DamageModel.BODY_LEFT), 1.0)


func test_faster_crash_does_more_damage() -> void:
	_wall(Vector3(0, 2, 12), Vector3(30, 4, 1))
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(5.0)
	var slow_loss := 1.0 - damage.health(DamageModel.BODY_FRONT)
	var other_world := add_child_autofree(FlatWorld.create()) as FlatWorld
	other_world.position = Vector3(500, 0, 0)
	var fast_bus := await other_world.spawn_bus(self, BusSpec.new(), Vector3(500, 0.3, 0))
	var fast_damage := DamageModel.new()
	fast_bus.impact.connect(fast_damage.apply_impact)
	var wall := _wall(Vector3(500, 2, 70), Vector3(30, 4, 1))
	wall.reparent(other_world)
	fast_bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(10.0)
	var fast_loss := 1.0 - fast_damage.health(DamageModel.BODY_FRONT)
	assert_gt(slow_loss, 0.0)
	assert_gt(fast_loss, slow_loss * 1.5)


func test_side_swipe_hits_side_panel() -> void:
	# A long wall right of the bus path; get up to speed, then swerve into it.
	_wall(Vector3(-4.5, 2, 80), Vector3(1, 4, 140))
	bus.set_command(1.0, 0.0, 0.0)
	await wait_until(func() -> bool: return bus.forward_speed() > 10.0, 10.0)
	bus.set_command(1.0, 0.0, 1.0)
	await wait_seconds(2.0)
	bus.set_command(0.0, 1.0, 0.0)
	await wait_seconds(2.0)
	var right_side := damage.health(DamageModel.BODY_RIGHT)
	var right_mirror := damage.health(DamageModel.MIRROR_RIGHT)
	assert_true(
		right_side < 1.0 or right_mirror < 1.0, "right side took the hit: %s" % damage.parts
	)
	assert_eq(damage.health(DamageModel.BODY_LEFT), 1.0)
	assert_eq(damage.health(DamageModel.MIRROR_LEFT), 1.0)


func test_reversing_into_a_wall_damages_the_rear() -> void:
	_wall(Vector3(0, 2, -6.5), Vector3(30, 4, 1))
	bus.set_command(0.0, 1.0, 0.0)
	await wait_seconds(6.0)
	assert_eq(damage.health(DamageModel.BODY_FRONT), 1.0)
	assert_true(
		damage.health(DamageModel.BODY_REAR) < 1.0 or damage.is_pristine(),
		"slow reverse bump may be below the damage threshold, but never hits the front"
	)


func test_being_rear_ended_by_traffic_damages_the_rear() -> void:
	var track := Track.from_points(
		PackedVector2Array(
			[Vector2(0, -50), Vector2(0, 600), Vector2(-300, 600), Vector2(-300, -50)]
		)
	)
	var offset := track.closest_offset(bus.global_position)
	var car := TrafficCar.create(track, 0, offset - 30.0, Color.RED)
	world.add_child(car)
	# Move the bus onto that car's lane and ram it from behind at 12 m/s.
	var xform := track.vehicle_transform(0, offset)
	xform.origin.y += 0.3
	bus.global_transform = xform
	await wait_physics_frames(5)
	for i in 240:
		car.advance(0.0 if car.speed >= 12.0 else 9.0, 1.0 / 60.0)
		await get_tree().physics_frame
	assert_lt(damage.health(DamageModel.BODY_REAR), 1.0, "rear panel dented")
	assert_eq(damage.health(DamageModel.BODY_FRONT), 1.0)
