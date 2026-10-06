extends SceneTree
## Dev tool: renders chase / driver / top-down views of a drive session to PNGs.
## Needs a GPU (not headless):
##   godot --path . -s tools/screenshots.gd -- <output_dir> [map_id]
var out_dir := ""
func _init():
	out_dir = OS.get_cmdline_user_args()[0]
	_go.call_deferred()
func _go():
	root.size = Vector2i(1280, 720)
	var map_id := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "harbor"
	var s := DriveSession.create(Maps.get_map(map_id), Catalog.bus_spec("city"), {"seed": 1})
	root.add_child(s)
	for i in 30: await process_frame
	s.bus.set_command(1, 0, 0)
	for i in 90: await physics_frame
	s.bus.set_command(0, 0.3, 0)
	for i in 30: await physics_frame
	for mode in [CameraModes.Mode.CHASE, CameraModes.Mode.DRIVER, CameraModes.Mode.TOP_DOWN]:
		s.camera_rig.set_mode(mode)
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(out_dir + "/%s_%s.png" % [map_id, CameraModes.mode_name(mode)])
	quit()
