extends TestCase

var spec := BusSpec.new()


func _bus_xform(yaw: float, origin := Vector3(10, 0, -5)) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), origin)


func test_next_cycles_through_every_mode_and_wraps() -> void:
	var mode: CameraModes.Mode = CameraModes.Mode.CHASE
	var visited := []
	for i in CameraModes.ORDER.size():
		visited.append(mode)
		mode = CameraModes.next(mode)
	assert_eq(mode, CameraModes.Mode.CHASE)
	assert_eq(visited.size(), 3)
	assert_has(visited, CameraModes.Mode.DRIVER)
	assert_has(visited, CameraModes.Mode.TOP_DOWN)


func test_every_mode_has_a_name() -> void:
	for mode in CameraModes.ORDER:
		assert_false(CameraModes.mode_name(mode).is_empty())


func test_chase_camera_is_behind_and_above_and_looks_forward() -> void:
	for yaw in [0.0, 1.0, -2.5]:
		var bus := _bus_xform(yaw)
		var cam := CameraModes.camera_transform(CameraModes.Mode.CHASE, bus, spec)
		var local := bus.affine_inverse() * cam.origin
		assert_lt(local.z, -spec.length / 2.0, "behind the bus")
		assert_gt(local.y, spec.height, "above the roof")
		var view_dir := -cam.basis.z
		assert_gt(view_dir.dot(bus.basis.z), 0.8, "looking the way the bus faces")


func test_driver_camera_sits_inside_the_cab_and_looks_ahead() -> void:
	var bus := _bus_xform(0.7)
	var cam := CameraModes.camera_transform(CameraModes.Mode.DRIVER, bus, spec)
	var local := bus.affine_inverse() * cam.origin
	assert_lt(absf(local.x), spec.width / 2.0)
	assert_between(local.y, 0.5, spec.height)
	assert_between(local.z, 0.0, spec.length / 2.0)
	assert_gt(local.x, 0.0, "left-hand drive seat")
	assert_gt((-cam.basis.z).dot(bus.basis.z), 0.95)


func test_top_down_camera_is_overhead_with_bus_pointing_up_screen() -> void:
	var bus := _bus_xform(2.0)
	var cam := CameraModes.camera_transform(CameraModes.Mode.TOP_DOWN, bus, spec)
	assert_almost_eq(cam.origin.y - bus.origin.y, CameraModes.TOP_DOWN_HEIGHT, 0.001)
	assert_vec3_almost_eq(-cam.basis.z, Vector3.DOWN, 0.001)
	assert_gt(cam.basis.y.dot(bus.basis.z), 0.99, "screen-up matches bus forward")


func test_all_camera_transforms_are_orthonormal() -> void:
	for mode in CameraModes.ORDER:
		var cam := CameraModes.camera_transform(mode, _bus_xform(0.3), spec)
		assert_almost_eq(cam.basis.determinant(), 1.0, 0.001)
