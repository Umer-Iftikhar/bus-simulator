extends TestCase
## Mirror hardware on the bus: protruding heads that break on contact without
## stopping the bus, and body panels that show their damage.

var world: FlatWorld
var bus: Bus
var damage: DamageModel


func before_each() -> void:
	world = add_child_autofree(FlatWorld.create())
	bus = await world.spawn_bus(self)
	damage = DamageModel.new()
	bus.impact.connect(damage.apply_impact)


## A static block spanning [param from_y]..[param to_y] and [param from_x]..[param to_x]
## (world X), centred at z = [param z].
func _block(from_x: float, to_x: float, from_y: float, to_y: float, z: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(to_x - from_x, to_y - from_y, 0.6)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3((from_x + to_x) / 2.0, (from_y + to_y) / 2.0, z)
	world.add_child(body)


func _mirror_band() -> Vector2:
	var y := Bus.mirror_mount(bus.spec, DamageModel.MIRROR_LEFT).y
	return Vector2(y - 0.35, y + 0.6)


func test_mirror_parts_exist_and_protrude() -> void:
	for part in DamageModel.MIRRORS:
		assert_not_null(bus.get_node_or_null("MirrorHead_" + part))
		assert_not_null(bus.get_node_or_null("MirrorSensor_" + part))
		var glass := bus.mirror_glass[part] as MeshInstance3D
		assert_not_null(glass)
		var reach := absf(glass.position.x) + Bus.MIRROR_HEAD.x / 2.0
		assert_gt(reach, bus.spec.width / 2.0 + 0.2)


func test_clipping_an_overhang_with_the_mirror_smashes_it_but_bus_carries_on() -> void:
	var band := _mirror_band()
	var right_edge := -bus.spec.width / 2.0
	# Overhang outside the body on the right (-X), only at mirror height: the
	# body clears it by 20 cm, the mirror head (35 cm reach) does not.
	_block(right_edge - 1.5, right_edge - 0.2, band.x, band.y, 30.0)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(6.0)
	assert_true(damage.is_mirror_broken(DamageModel.MIRROR_RIGHT), "right mirror smashed")
	assert_false(damage.is_mirror_broken(DamageModel.MIRROR_LEFT))
	for part in [DamageModel.BODY_FRONT, DamageModel.BODY_LEFT, DamageModel.BODY_RIGHT]:
		assert_eq(damage.health(part), 1.0, "%s untouched" % part)
	assert_gt(bus.forward_speed(), 8.0, "mirrors break away, they don't stop a bus")
	assert_gt(bus.global_position.z, 31.0, "drove on past the overhang")


func test_obstacle_below_mirror_height_misses_it() -> void:
	var band := _mirror_band()
	var right_edge := -bus.spec.width / 2.0
	_block(right_edge - 1.5, right_edge - 0.2, 0.0, band.x - 0.4, 30.0)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(6.0)
	assert_true(damage.is_pristine())


func test_creeping_past_an_obstacle_does_not_break_mirror() -> void:
	var band := _mirror_band()
	var right_edge := -bus.spec.width / 2.0
	_block(right_edge - 1.5, right_edge - 0.2, band.x, band.y, 3.0)
	# Creep forward slowly into it.
	for i in 60 * 6:
		bus.set_command(0.15 if bus.forward_speed() < 0.5 else 0.0, 0.0, 0.0)
		await get_tree().physics_frame
	assert_false(damage.is_mirror_broken(DamageModel.MIRROR_RIGHT), "a gentle nudge is fine")


func test_panel_overlays_show_damage() -> void:
	assert_eq(bus.panel_damage_alpha(DamageModel.BODY_FRONT), 0.0)
	bus.set_part_health(DamageModel.BODY_FRONT, 0.2)
	assert_almost_eq(bus.panel_damage_alpha(DamageModel.BODY_FRONT), 0.6, 0.001)
	assert_true((bus.get_node("Dents_body_front") as MeshInstance3D).visible)
	assert_eq(bus.panel_damage_alpha(DamageModel.BODY_REAR), 0.0, "other panels unaffected")
	bus.set_part_health(DamageModel.BODY_FRONT, 1.0)
	assert_false((bus.get_node("Dents_body_front") as MeshInstance3D).visible)


func test_mirror_glass_shows_image_or_cracks() -> void:
	var texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
	bus.set_mirror_image(DamageModel.MIRROR_LEFT, texture)
	var glass := bus.mirror_glass[DamageModel.MIRROR_LEFT] as MeshInstance3D
	var material := glass.material_override as StandardMaterial3D
	assert_eq(material.albedo_texture, texture)
	assert_eq(material.uv1_scale.x, -1.0, "mirror image is flipped")
	bus.set_mirror_image(DamageModel.MIRROR_LEFT, texture, true)
	material = glass.material_override as StandardMaterial3D
	assert_null(material.albedo_texture, "shattered glass shows no image")
