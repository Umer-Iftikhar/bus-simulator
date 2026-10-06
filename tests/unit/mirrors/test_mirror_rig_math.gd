extends TestCase
## Mirror placement, refresh scheduling and the performance budget.

var spec := BusSpec.new()


func _bus(yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(5, 0, -3))


func test_mirror_resolution_stays_within_mobile_budget() -> void:
	assert_le(MirrorRig.total_pixels(), MirrorRig.PIXEL_BUDGET)
	assert_le(MirrorRig.SIDE_RESOLUTION.x, 256, "low resolution by design")
	assert_le(MirrorRig.REAR_RESOLUTION.x, 320)


func test_refresh_every_frame_by_default() -> void:
	for frame in 10:
		assert_true(MirrorRig.should_refresh(frame, 1))
	assert_true(MirrorRig.should_refresh(7, 0), "invalid interval treated as every frame")


func test_reduced_refresh_rate() -> void:
	var refreshed := []
	for frame in 9:
		if MirrorRig.should_refresh(frame, 3):
			refreshed.append(frame)
	assert_eq(refreshed, [0, 3, 6])


func test_side_mirrors_mount_outside_the_body_near_the_front() -> void:
	for part in DamageModel.MIRRORS:
		var mount := Bus.mirror_mount(spec, part)
		assert_gt(absf(mount.x), spec.width / 2.0, "%s sticks out" % part)
		assert_between(mount.z, spec.length / 2.0 - 1.0, spec.length / 2.0)
		assert_between(mount.y, spec.height * 0.5, spec.height)
	var left := Bus.mirror_mount(spec, DamageModel.MIRROR_LEFT)
	var right := Bus.mirror_mount(spec, DamageModel.MIRROR_RIGHT)
	assert_gt(left.x, 0.0, "+X is the bus's left")
	assert_almost_eq(left.x, -right.x, 0.0001, "symmetric")


func test_every_mirror_camera_looks_backwards() -> void:
	for yaw in [0.0, 1.3, -2.0]:
		var bus := _bus(yaw)
		for view in MirrorRig.VIEWS:
			var cam := MirrorRig.camera_transform(view, bus, spec)
			var looking := -cam.basis.z
			assert_gt(looking.dot(-bus.basis.z), 0.95, "%s faces rearward" % view)


func test_side_mirrors_angle_outward() -> void:
	var bus := _bus()
	var left_look := -MirrorRig.camera_transform(MirrorRig.LEFT, bus, spec).basis.z
	var right_look := -MirrorRig.camera_transform(MirrorRig.RIGHT, bus, spec).basis.z
	assert_gt(left_look.dot(bus.basis.x), 0.05, "left mirror sees the left lane")
	assert_lt(right_look.dot(bus.basis.x), -0.05, "right mirror sees the kerb side")


func test_mirror_cameras_sit_at_their_mirrors() -> void:
	var bus := _bus(0.4)
	for part in DamageModel.MIRRORS:
		var cam := MirrorRig.camera_transform(part, bus, spec)
		assert_vec3_almost_eq(cam.origin, bus * Bus.mirror_mount(spec, part), 0.001)
	var rear := MirrorRig.camera_transform(MirrorRig.REAR, bus, spec)
	var rear_local := bus.affine_inverse() * rear.origin
	assert_lt(rear_local.z, -spec.length / 2.0, "rear camera at the back")
	assert_lt((-rear.basis.z).y, 0.0, "rear camera tilts slightly down")
