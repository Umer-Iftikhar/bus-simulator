extends TestCase
## MirrorRig viewports and cameras attached to a moving bus.

var world: FlatWorld
var bus: Bus
var rig: MirrorRig


func before_each() -> void:
	world = add_child_autofree(FlatWorld.create())
	bus = await world.spawn_bus(self)


func _attach(interval := 1) -> void:
	rig = MirrorRig.create(bus, interval)
	bus.add_child(rig)
	await wait_process_frames(2)


func test_creates_three_low_res_viewports_sharing_the_world() -> void:
	await _attach()
	assert_eq(rig.viewports.size(), 3)
	for view in MirrorRig.VIEWS:
		var viewport := rig.viewports[view] as SubViewport
		var expected := (
			MirrorRig.REAR_RESOLUTION if view == MirrorRig.REAR else MirrorRig.SIDE_RESOLUTION
		)
		assert_eq(viewport.size, expected)
		assert_false(viewport.own_world_3d)
		assert_eq(viewport.find_world_3d(), bus.get_world_3d(), "%s renders the real scene" % view)
		assert_true((rig.cameras[view] as Camera3D).current)
		assert_not_null(rig.texture(view))
		assert_true(rig.is_rendering(view))


func test_cameras_follow_the_bus_through_a_turn() -> void:
	await _attach()
	bus.set_command(1.0, 0.0, 0.7)
	await wait_seconds(4.0)
	await wait_process_frames(1)
	for view in MirrorRig.VIEWS:
		var expected := MirrorRig.camera_transform(view, bus.global_transform, bus.spec)
		var camera := rig.cameras[view] as Camera3D
		assert_vec3_almost_eq(camera.global_position, expected.origin, 0.6, view)
		assert_gt(
			(-camera.global_basis.z).dot(-bus.global_basis.z), 0.9, "%s still looks back" % view
		)


func test_broken_mirror_stops_rendering() -> void:
	await _attach()
	rig.set_broken(MirrorRig.RIGHT, true)
	await wait_process_frames(3)
	assert_false(rig.is_rendering(MirrorRig.RIGHT))
	var right := rig.viewports[MirrorRig.RIGHT] as SubViewport
	assert_eq(right.render_target_update_mode, SubViewport.UPDATE_DISABLED, "GPU work stopped")
	assert_true(rig.is_rendering(MirrorRig.LEFT))
	assert_true(rig.is_rendering(MirrorRig.REAR), "interior mirror can't be clipped")
	rig.set_broken(MirrorRig.RIGHT, false)
	await wait_process_frames(1)
	assert_true(rig.is_rendering(MirrorRig.RIGHT))


func test_reduced_refresh_renders_every_third_frame() -> void:
	await _attach(3)
	var modes := []
	for i in 6:
		await wait_process_frames(1)
		modes.append((rig.viewports[MirrorRig.LEFT] as SubViewport).render_target_update_mode)
	var once := modes.filter(func(m: int) -> bool: return m == SubViewport.UPDATE_ONCE)
	assert_eq(once.size(), 2, "two refreshes in six frames: %s" % str(modes))


func test_mirror_view_cracks_when_broken() -> void:
	var view := add_child_autofree(MirrorView.new()) as MirrorView
	view.name = "mirror_left"
	assert_eq(view.crack_count(), 0)
	view.set_broken(true)
	assert_gt(view.crack_count(), 5)
	assert_lt(view.image.modulate.v, 0.5, "visibility reduced")
	view.set_broken(false)
	assert_eq(view.crack_count(), 0)
	assert_eq(view.image.modulate, Color.WHITE)


func test_mirror_view_shows_a_flipped_image() -> void:
	await _attach()
	var view := add_child_autofree(MirrorView.new()) as MirrorView
	view.set_texture(rig.texture(MirrorRig.REAR))
	assert_eq(view.image.texture, rig.texture(MirrorRig.REAR))
	assert_true(view.image.flip_h)
