extends TestCase
## The generated world for each map: structure, collision and road clearance.


func _build(map: MapDef) -> GameWorld:
	var world := GameWorld.create(map)
	add_child_autofree(world)
	await wait_physics_frames(2)
	return world


func test_world_contains_environment_light_ground_road_and_scenery() -> void:
	for map in Maps.all():
		var world := await _build(map)
		for child in ["Environment", "Sun", "Ground", "Road", "Scenery"]:
			assert_not_null(world.get_node_or_null(child), "%s missing on %s" % [child, map.id])
		var road := world.get_node("Road")
		for strip in ["Asphalt", "SidewalkLeft", "SidewalkRight", "LaneDivider"]:
			var mesh := (road.get_node(strip) as MeshInstance3D).mesh
			assert_gt(mesh.get_faces().size(), 0, "%s has geometry" % strip)
		world.free()


func test_scenery_is_generated_and_deterministic() -> void:
	var map := Maps.harbor()
	var first := await _build(map)
	var count := first.building_rects.size()
	var rects := first.building_rects.duplicate()
	first.free()
	var second := await _build(map)
	assert_gt(count, 10, "a town needs buildings")
	assert_eq(second.building_rects, rects, "same seed, same town")


func test_no_building_blocks_the_road() -> void:
	for map in Maps.all():
		var world := await _build(map)
		var limit := world.track.half_width() + GameWorld.SIDEWALK_WIDTH
		for rect in world.building_rects:
			var center := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
			var lateral := absf(world.track.lateral_of(center))
			assert_gt(lateral - rect.size.x / 2.0, limit, "building intrudes on %s road" % map.id)
		world.free()


func test_ground_collides_under_every_part_of_the_road() -> void:
	var world := await _build(Maps.harbor())
	var space := world.get_world_3d().direct_space_state
	var track := world.track
	var offset := 0.0
	while offset < track.length():
		for lane in Track.LANE_COUNT:
			var pos := track.lane_position(lane, offset)
			var query := PhysicsRayQueryParameters3D.create(
				pos + Vector3.UP * 20.0, pos + Vector3.DOWN * 5.0, Layers.WORLD
			)
			var hit := space.intersect_ray(query)
			assert_false(hit.is_empty(), "no ground at offset %.0f" % offset)
			if not hit.is_empty():
				assert_almost_eq(
					hit["position"].y, 0.0, 0.01, "road is clear and flat at %.0f" % offset
				)
		offset += 25.0


func test_scenery_bodies_are_on_world_layer() -> void:
	var world := await _build(Maps.harbor())
	for body in world.get_node("Scenery").get_children():
		assert_eq((body as StaticBody3D).collision_layer, Layers.WORLD)


func test_street_lights_line_the_kerb_as_multimeshes() -> void:
	var world := await _build(Maps.harbor())
	var lights := world.get_node("StreetLights")
	assert_gt(world.street_light_count, 10)
	for part in ["Poles", "Heads"]:
		var multimesh := (lights.get_node(part) as MultiMeshInstance3D).multimesh
		assert_eq(multimesh.instance_count, world.street_light_count)
	assert_eq(world.street_light_positions.size(), world.street_light_count)
	for pos in world.street_light_positions:
		assert_eq(world.track.lane_at(pos), -1, "lamp posts stand off the road")
		assert_gt(world.track.lateral_of(pos), 0.0, "on the kerb side, where the stops are")


func test_street_light_heads_glow_only_at_night() -> void:
	var day := await _build(Maps.harbor())
	var day_head := (day.get_node("StreetLights/Heads") as MultiMeshInstance3D).multimesh.mesh
	assert_false((day_head.surface_get_material(0) as StandardMaterial3D).emission_enabled)
	day.free()
	var night := await _build(Maps.pines())
	var night_head := (night.get_node("StreetLights/Heads") as MultiMeshInstance3D).multimesh.mesh
	assert_true((night_head.surface_get_material(0) as StandardMaterial3D).emission_enabled)


func test_buildings_share_the_facade_shader_with_per_building_colours() -> void:
	var world := await _build(Maps.downtown())
	var shared: Material = null
	var colours := {}
	for body in world.get_node("Scenery").get_children():
		var facade := body.get_node_or_null("Facade") as MeshInstance3D
		if facade == null:
			continue
		if shared == null:
			shared = facade.material_override
		assert_eq(facade.material_override, shared, "one material for all buildings")
		colours[facade.get_instance_shader_parameter("wall_color")] = true
	assert_is(shared, ShaderMaterial)
	assert_gt(colours.size(), 1, "but each building keeps its own colour")


func test_road_has_textured_asphalt_and_kerb_faces() -> void:
	var world := await _build(Maps.harbor())
	var asphalt := (world.get_node("Road/Asphalt") as MeshInstance3D).mesh.surface_get_material(0)
	assert_not_null((asphalt as StandardMaterial3D).albedo_texture)
	for kerb in ["KerbLeft", "KerbRight"]:
		var mesh := (world.get_node("Road/" + kerb) as MeshInstance3D).mesh
		assert_gt(mesh.get_faces().size(), 0, kerb)


func test_night_map_is_dark_but_readable() -> void:
	var world := await _build(Maps.pines())
	var env := (world.get_node("Environment") as WorldEnvironment).environment
	var sun := world.get_node("Sun") as DirectionalLight3D
	assert_lt(sun.light_energy, 1.0)
	assert_gt(sun.light_energy, 0.3, "moonlight, not pitch black")
	assert_gt(env.ambient_light_energy, 0.5)
	assert_true(env.glow_enabled, "lit windows and lamps bloom")


func test_pine_map_grows_conifers() -> void:
	var world := await _build(Maps.pines())
	var cones := 0
	for tree in world.get_node("Scenery").get_children():
		for child in tree.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is CylinderMesh:
				if ((child as MeshInstance3D).mesh as CylinderMesh).top_radius == 0.0:
					cones += 1
	assert_gt(cones, 10)
