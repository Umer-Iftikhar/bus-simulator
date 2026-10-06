extends TestCase
## CameraRig following a live bus.

var world: FlatWorld
var bus: Bus
var rig: CameraRig


func before_each() -> void:
	world = add_child_autofree(FlatWorld.create())
	bus = await world.spawn_bus(self)
	rig = CameraRig.new()
	rig.target = bus
	world.add_child(rig)
	await wait_physics_frames(2)


func _local_camera_pos() -> Vector3:
	return bus.global_transform.affine_inverse() * rig.camera.global_position


func test_camera_becomes_current_and_starts_in_chase_mode() -> void:
	assert_eq(rig.mode, CameraModes.Mode.CHASE)
	assert_true(rig.camera.current)
	assert_lt(_local_camera_pos().z, 0.0, "behind the bus")


func test_chase_camera_follows_moving_bus() -> void:
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(6.0)
	assert_gt(bus.global_position.z, 20.0)
	var local := _local_camera_pos()
	assert_lt(local.z, -bus.spec.length / 2.0, "still behind the bus")
	assert_lt(rig.camera.global_position.distance_to(bus.global_position), 25.0, "keeps up")


func test_cycle_switches_modes_in_order_and_emits_signal() -> void:
	watch_signals(rig)
	rig.cycle()
	assert_eq(rig.mode, CameraModes.Mode.DRIVER)
	rig.cycle()
	assert_eq(rig.mode, CameraModes.Mode.TOP_DOWN)
	rig.cycle()
	assert_eq(rig.mode, CameraModes.Mode.CHASE)
	assert_signal_emit_count(rig, "mode_changed", 3)
	assert_eq(get_signal_parameters(rig, "mode_changed"), [CameraModes.Mode.CHASE])


func test_setting_same_mode_is_a_no_op() -> void:
	watch_signals(rig)
	rig.set_mode(CameraModes.Mode.CHASE)
	assert_signal_not_emitted(rig, "mode_changed")


func test_driver_camera_is_locked_to_the_seat_while_driving() -> void:
	rig.set_mode(CameraModes.Mode.DRIVER)
	bus.set_command(1.0, 0.0, 0.4)
	await wait_seconds(3.0)
	var seat := CameraModes.driver_seat(bus.spec)
	assert_vec3_almost_eq(_local_camera_pos(), seat, 0.35)


func test_top_down_camera_hovers_over_bus() -> void:
	rig.set_mode(CameraModes.Mode.TOP_DOWN)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(3.0)
	var offset := rig.camera.global_position - bus.global_position
	assert_almost_eq(offset.y, CameraModes.TOP_DOWN_HEIGHT, 1.0)
	assert_lt(Vector2(offset.x, offset.z).length(), 3.0, "roughly overhead")


func test_rig_tolerates_target_being_freed() -> void:
	bus.queue_free()
	await wait_physics_frames(3)
	assert_true(is_instance_valid(rig), "rig survives losing its target")
