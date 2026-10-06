extends TestCase
## End-to-end mirrors: drive under an overhanging sign that only the right
## mirror clips -> it shatters (cracked view, no longer rendering) while the
## bus keeps going -> damage is saved -> repaired in the garage -> next drive
## the mirror works again.

var driver: GameDriver


func before_each() -> void:
	driver = GameDriver.new(self)
	var save := SaveData.new_game()
	save.wallet.earn(1000)
	await driver.boot(save)


func after_each() -> void:
	driver.release_all()
	driver.cleanup_save()


func _start_drive() -> DriveSession:
	await driver.click(driver.main.menu.drive_button)
	await wait_seconds(1.0)
	var session: DriveSession = driver.main.session
	for car in session.traffic.cars:
		car.queue_free()
	session.traffic.cars.clear()
	return session


## A sign hanging over the kerb at mirror height, beside the kerb lane.
func _hang_sign(session: DriveSession, at_offset: float) -> void:
	var track := session.world.track
	var spec := session.bus.spec
	var body_edge := Track.lane_lateral(0) + spec.width / 2.0
	var inner := body_edge + 0.2
	var outer := inner + 1.5
	var mirror_y := Bus.mirror_mount(spec, DamageModel.MIRROR_RIGHT).y
	var sign := StaticBody3D.new()
	sign.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(outer - inner, 1.0, 0.5)
	shape.shape = box
	sign.add_child(shape)
	var xform := track.vehicle_transform(0, at_offset)
	xform.origin = track.position_at(at_offset) + track.right_at(at_offset) * (inner + outer) / 2.0
	xform.origin.y = mirror_y + 0.2
	sign.transform = xform
	session.world.add_child(sign)


func test_clipped_mirror_shatters_then_is_repaired() -> void:
	var session := await _start_drive()
	await driver.tap_key(KEY_C)
	assert_true(session.mirror_panel.visible, "driver's view shows the mirrors")
	assert_true(session.mirrors.is_rendering(MirrorRig.RIGHT))

	var start := session.world.track.closest_offset(session.bus.global_position)
	_hang_sign(session, start + 60.0)
	var pilot := Autopilot.new(session.bus, session.world.track)
	pilot.cruise_speed = 9.0
	var smashed := false
	for i in 60 * 15:
		pilot.step()
		await get_tree().physics_frame
		if session.damage.is_mirror_broken(DamageModel.MIRROR_RIGHT):
			smashed = true
			break
	await wait_physics_frames(30)
	pilot.release()
	assert_true(smashed, "right mirror clipped the sign")
	assert_gt(session.bus.forward_speed(), 4.0, "bus carried on")
	assert_false(session.damage.is_mirror_broken(DamageModel.MIRROR_LEFT))
	for part in [DamageModel.BODY_FRONT, DamageModel.BODY_LEFT, DamageModel.BODY_RIGHT]:
		assert_eq(session.damage.health(part), 1.0, "%s untouched" % part)
	assert_eq(session.hud.message_label.text, "Right mirror smashed!")
	var right_view := session.mirror_panel.views[MirrorRig.RIGHT] as MirrorView
	assert_true(right_view.broken, "cracks over the right mirror view")
	assert_false(session.mirrors.is_rendering(MirrorRig.RIGHT), "reduced visibility on that side")
	assert_true(session.mirrors.is_rendering(MirrorRig.LEFT))

	await driver.tap_key(KEY_ESCAPE)
	await wait_process_frames(2)
	var saved := DamageModel.from_dict(driver.saved_state().damage(Catalog.STARTER_BUS))
	assert_true(saved.is_mirror_broken(DamageModel.MIRROR_RIGHT), "broken mirror saved")

	await driver.click(driver.main.menu.garage_button)
	await wait_process_frames(2)
	var garage: GarageMenu = driver.main.garage_menu
	assert_eq(garage.buttons["repair"].text, "Repair $120", "flat price for a mirror")
	await driver.click(garage.buttons["repair"])
	await wait_process_frames(2)
	assert_eq(driver.main.save.money, 1000 - 120)
	await driver.click(driver.main.garage_menu.back_button)
	await wait_process_frames(2)

	var next := await _start_drive()
	assert_true(next.mirrors.is_rendering(MirrorRig.RIGHT), "mirror works again after repair")
	assert_false((next.mirror_panel.views[MirrorRig.RIGHT] as MirrorView).broken)
