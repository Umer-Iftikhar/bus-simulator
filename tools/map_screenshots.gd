extends SceneTree
## Dev tool: renders chase, driver and aerial views of every map and prints
## build times. Needs a GPU (not headless):
##   godot --path . -s tools/map_screenshots.gd -- <output_dir>
func _init():
	_go.call_deferred()
func _go():
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	for map in Maps.all():
		var t0 := Time.get_ticks_msec()
		var s := DriveSession.create(map, Catalog.bus_spec("city"), {"seed": 1, "graphics": "high"})
		root.add_child(s)
		print("%s built in %d ms, buildings=%d trees=%d" % [map.id, Time.get_ticks_msec() - t0, s.world.buildings().size(), s.world.city.tree_count()])
		for i in 20: await process_frame
		s.bus.set_command(1, 0, 0)
		for i in 120: await physics_frame
		s.bus.set_command(0, 0.4, 0)
		for i in 20: await physics_frame
		for mode in [CameraModes.Mode.CHASE, CameraModes.Mode.DRIVER]:
			s.camera_rig.set_mode(mode)
			for i in 10: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out + "/%s_%s.png" % [map.id, CameraModes.mode_name(mode)])
		var cam := Camera3D.new(); s.add_child(cam)
		var c := s.world.terrain.bounds.get_center()
		cam.far = 4000
		cam.global_position = Vector3(c.x - 300, 380, c.y - 700)
		cam.look_at(Vector3(c.x, 0, c.y))
		cam.make_current()
		for i in 10: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/%s_aerial.png" % map.id)
		s.free()
		await process_frame
	quit()
