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
