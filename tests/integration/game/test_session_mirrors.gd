extends TestCase
## Mirrors and panel damage wired through the drive session.

var session: DriveSession


func _start(options := {}) -> void:
	options["seed"] = 8
	options["traffic"] = false
	session = DriveSession.create(Maps.islamabad(), BusSpec.new(), options)
	add_child_autofree(session)
	await wait_physics_frames(3)


func test_mirrors_attached_and_panel_bound() -> void:
	await _start()
	assert_not_null(session.mirrors)
	assert_eq(session.mirrors.bus, session.bus)
	for view in MirrorRig.VIEWS:
		var shown := (session.mirror_panel.views[view] as MirrorView).image.texture
		assert_eq(shown, session.mirrors.texture(view), "%s shown on HUD" % view)
	for part in DamageModel.MIRRORS:
		var glass := session.bus.mirror_glass[part] as MeshInstance3D
		var material := glass.material_override as StandardMaterial3D
		assert_eq(material.albedo_texture, session.mirrors.texture(part), "%s glass live" % part)


func test_mirror_panel_shows_only_in_driver_view() -> void:
	await _start()
	assert_false(session.mirror_panel.visible)
	session.camera_rig.set_mode(CameraModes.Mode.DRIVER)
	assert_true(session.mirror_panel.visible)
	session.camera_rig.set_mode(CameraModes.Mode.TOP_DOWN)
	assert_false(session.mirror_panel.visible)


func test_saved_broken_mirror_starts_broken() -> void:
	await _start({"damage": {"mirror_left": 0.0, "body_rear": 0.5}})
	assert_false(session.mirrors.is_rendering(MirrorRig.LEFT))
	assert_true(session.mirrors.is_rendering(MirrorRig.RIGHT))
	assert_true((session.mirror_panel.views[MirrorRig.LEFT] as MirrorView).broken)
	assert_almost_eq(session.bus.panel_damage_alpha(DamageModel.BODY_REAR), 0.375, 0.001)


func test_smashing_a_mirror_mid_drive() -> void:
	await _start()
	session.bus.impact.emit(DamageModel.MIRROR_RIGHT, 6.0)
	await wait_process_frames(2)
	assert_false(session.mirrors.is_rendering(MirrorRig.RIGHT))
	assert_true((session.mirror_panel.views[MirrorRig.RIGHT] as MirrorView).broken)
	var glass := session.bus.mirror_glass[DamageModel.MIRROR_RIGHT] as MeshInstance3D
	assert_null((glass.material_override as StandardMaterial3D).albedo_texture)
	assert_eq(session.hud.message_label.text, "Right mirror smashed!")


func test_panel_hits_show_on_the_body() -> void:
	await _start()
	session.bus.impact.emit(DamageModel.BODY_LEFT, 15.0)
	assert_gt(session.bus.panel_damage_alpha(DamageModel.BODY_LEFT), 0.3)
	assert_eq(session.bus.panel_damage_alpha(DamageModel.BODY_RIGHT), 0.0)


func test_mirror_refresh_option_is_passed_to_rig() -> void:
	await _start({"mirror_refresh": 2})
	assert_eq(session.mirrors.refresh_interval, 2)


func test_mirror_views_do_not_cover_touch_controls_or_hud() -> void:
	await _start()
	session.camera_rig.set_mode(CameraModes.Mode.DRIVER)
	await wait_process_frames(2)
	var tc := session.touch_controls
	var widgets: Array[Control] = [
		tc.wheel,
		tc.gas,
		tc.brake_pedal,
		tc.camera_button,
		tc.horn_button,
		tc.menu_button,
		tc.indicator_left_button,
		tc.indicator_right_button,
		tc.gear_button,
		tc.lights_button,
	]
	var info := session.hud.info.get_global_rect()
	for view in session.mirror_panel.views.values():
		var mirror := (view as Control).get_global_rect()
		assert_false(mirror.intersects(info), "%s covers the HUD text" % view.name)
		for widget in widgets:
			assert_false(
				mirror.intersects(widget.get_global_rect()),
				"%s covers %s" % [view.name, widget.name]
			)
