extends TestCase
## The generated world for each map: terrain, water, road, bridges, city,
## street life and landmarks. These are the "is the map believable and sane"
## checks: nothing in the water, nothing floating, nothing blocking the road.


func _build(map: MapDef) -> GameWorld:
	var world := GameWorld.create(map)
	add_child_autofree(world)
	await wait_physics_frames(2)
	return world


func _space(world: GameWorld) -> PhysicsDirectSpaceState3D:
	return world.get_world_3d().direct_space_state


func _ray_down(world: GameWorld, at: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 120.0, at + Vector3.DOWN * 120.0, Layers.WORLD
	)
	return _space(world).intersect_ray(query)


func _flat_road_distance(track: Track, x: float, z: float) -> float:
	var flat := Vector3(x, 0, z)
	var near := track.position_at(track.closest_offset(flat))
	near.y = 0.0
	return flat.distance_to(near)


func _footprint(world: GameWorld, b: Dictionary) -> PackedVector2Array:
	var size := Vector2(b["size"].x, b["size"].z)
	return world.city._corners(b["center"], size, CityBuilder.yaw_forward(b["yaw"]))


func test_every_map_builds_all_layers_and_a_painted_sky() -> void:
	for map in Maps.all():
		var world := await _build(map)
		for child in ["Environment", "Sun", "Ground", "Road", "Scenery", "StreetLife"]:
			assert_not_null(world.get_node_or_null(child), "%s on %s" % [child, map.id])
		for strip in ["Asphalt", "SidewalkLeft", "SidewalkRight", "LaneDivider", "RoadSurface"]:
			assert_not_null(world.get_node("Road").get_node_or_null(strip), strip)
		var env := (world.get_node("Environment") as WorldEnvironment).environment
		var sky := env.sky.sky_material as ShaderMaterial
		assert_not_null(sky, "%s uses the shader sky" % map.id)
		assert_eq(sky.get_shader_parameter("backdrop"), WorldLook.BACKDROPS[map.backdrop])
		assert_gt(sky.get_shader_parameter("backdrop_angle"), 0.0)
		assert_eq(sky.get_shader_parameter("night"), 1.0 if map.night else 0.0)
		world.free()


func test_road_is_driveable_everywhere_at_its_elevation() -> void:
	for map in Maps.all():
		var world := await _build(map)
		var track := world.track
		var offset := 0.0
		while offset < track.length():
			for lane in Track.LANE_COUNT:
				var pos := track.lane_position(lane, offset)
				var hit := _ray_down(world, pos)
				assert_false(hit.is_empty(), "%s: no surface at %.0f" % [map.id, offset])
				if not hit.is_empty():
					var where := "%s road surface at %.0f" % [map.id, offset]
					assert_almost_eq(hit["position"].y, pos.y + 0.02, 0.15, where)
			offset += 20.0
		world.free()


func test_road_grades_stay_bus_friendly() -> void:
	for map in Maps.all():
		var track := map.track()
		var steepest := 0.0
		var offset := 0.0
		while offset < track.length():
			steepest = maxf(steepest, absf(track.grade_at(offset)))
			offset += 3.0
		assert_lt(steepest, 0.08, "%s steepest grade %.1f%%" % [map.id, steepest * 100.0])


func test_bridges_span_water_and_have_barriers() -> void:
	for map in Maps.all():
		if map.bridges.is_empty():
			continue
		var world := await _build(map)
		assert_not_null(world.get_node_or_null("Bridges/BarrierCollision"))
		for r in map.bridge_ranges():
			var mid := r.x + world.track.distance_ahead(r.x, r.y) / 2.0
			var deck := world.track.position_at(mid)
			var below := world.terrain.height_at(deck.x, deck.z)
			assert_gt(deck.y - below, 4.0, "%s deck high above the valley" % map.id)
			assert_true(
				world.terrain.is_water(deck.x, deck.z), "%s water under the bridge" % map.id
			)
			var right := world.track.right_at(mid)
			var edge := deck + right * (world.track.half_width() + 2.3) + Vector3.UP * 0.7
			var query := PhysicsRayQueryParameters3D.create(
				edge - right * 3.0, edge + right * 3.0, Layers.WORLD
			)
			assert_false(_space(world).intersect_ray(query).is_empty(), "%s barrier" % map.id)
		world.free()


func test_nothing_stands_in_or_near_water() -> void:
	for map in Maps.all():
		var world := await _build(map)
		var terrain := world.terrain
		var margin := CityBuilder.WATER_MARGIN - 0.01
		for p in world.city.tree_positions:
			assert_gt(terrain.water_distance(p.x, p.z), margin, "%s tree in water %s" % [map.id, p])
			assert_gt(p.y, map.water_level + 0.5, "%s tree below the water line" % map.id)
		for b in world.buildings():
			for corner in _footprint(world, b):
				assert_gt(
					terrain.water_distance(corner.x, corner.y), margin, "%s building" % map.id
				)
		for car in world.city.parked_cars:
			var p: Vector3 = car["position"]
			assert_gt(terrain.water_distance(p.x, p.z), margin, "%s parked car" % map.id)
		for p in world.life.furniture_positions:
			assert_gt(terrain.water_distance(p.x, p.z), margin, "%s furniture" % map.id)
		world.free()


func test_trees_rest_exactly_on_the_ground() -> void:
	for map in Maps.all():
		var world := await _build(map)
		var worst := 0.0
		for p in world.city.tree_positions:
			var hit := _ray_down(world, p + Vector3.UP * 0.3)
			assert_false(hit.is_empty(), "%s tree over nothing" % map.id)
			if not hit.is_empty():
				worst = maxf(worst, absf(p.y + 0.3 - hit["position"].y))
		assert_lt(worst, 0.4, "%s no floating or buried trees (worst %.2fm)" % [map.id, worst])
		world.free()


func test_nothing_blocks_the_road_or_side_streets() -> void:
	for map in Maps.all():
		var world := await _build(map)
		var track := world.track
		var clear := track.half_width() + GameWorld.SIDEWALK_WIDTH
		for b in world.buildings():
			var footprint := _footprint(world, b)
			for corner in footprint:
				var d := _flat_road_distance(track, corner.x, corner.y)
				assert_gt(d, clear, "%s building on the road" % map.id)
			for street in world.city.side_streets:
				var overlap := Geometry2D.intersect_polygons(footprint, street).size()
				assert_eq(overlap, 0, "%s building on a side street" % map.id)
		for p in world.city.tree_positions:
			assert_gt(_flat_road_distance(track, p.x, p.z), clear, "%s tree on the road" % map.id)
			for street in world.city.side_streets:
				var on_street := Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), street)
				assert_false(on_street, "%s tree on a side street" % map.id)
		world.free()


func test_buildings_never_overlap_each_other() -> void:
	for map in Maps.all():
		var world := await _build(map)
		var list := world.buildings()
		var polys: Array[PackedVector2Array] = []
		for b in list:
			polys.append(_footprint(world, b))
		var overlaps := 0
		for i in polys.size():
			for j in range(i + 1, polys.size()):
				if list[i]["center"].distance_to(list[j]["center"]) > 60.0:
					continue
				if Geometry2D.intersect_polygons(polys[i], polys[j]).size() > 0:
					overlaps += 1
		assert_eq(overlaps, 0, "%s overlapping buildings" % map.id)
		world.free()


func test_cities_are_dense_and_alive() -> void:
	var expectations := {
		"new_york": [300, 150],
		"tokyo": [250, 150],
		"washington": [180, 150],
		"islamabad": [150, 120],
		"rawalakot": [30, 60],
	}
	for map in Maps.all():
		var world := await _build(map)
		var want: Array = expectations[map.id]
		assert_gt(world.buildings().size(), want[0], "%s buildings" % map.id)
		assert_gt(world.life.walker_count(), want[1], "%s pedestrians" % map.id)
		assert_gt(world.life.furniture_positions.size(), 20, "%s street furniture" % map.id)
		assert_gt(world.city.tree_count(), 20, "%s greenery" % map.id)
		if map.side_streets:
			assert_gt(world.city.side_street_count, 15, "%s side streets" % map.id)
			assert_gt(world.city.parked_cars.size(), 50, "%s parked cars" % map.id)
		world.free()


func test_street_front_buildings_collide_back_rows_are_visual_only() -> void:
	var world := await _build(Maps.new_york())
	var front := world.buildings().filter(func(b: Dictionary) -> bool: return b["collides"])
	var back := world.buildings().filter(func(b: Dictionary) -> bool: return not b["collides"])
	assert_gt(front.size(), 50)
	assert_gt(back.size(), 50)
	var target: Dictionary = front[0]
	var hit := _ray_down(world, target["center"] + Vector3.UP * target["size"].y * 0.5)
	assert_false(hit.is_empty(), "street-front building has collision")


func test_pedestrians_walk_on_the_pavements() -> void:
	var world := await _build(Maps.tokyo())
	var track := world.track
	var start := world.life.walker_positions.duplicate()
	await wait_seconds(3.0)
	var moved := 0
	var low := track.half_width() + 0.3
	var high := track.half_width() + GameWorld.SIDEWALK_WIDTH
	for i in world.life.walker_positions.size():
		var p: Vector3 = world.life.walker_positions[i]
		assert_between(absf(track.lateral_of(p)), low, high, "on the pavement")
		if p.distance_to(start[i]) > 2.0:
			moved += 1
	assert_eq(moved, world.life.walker_positions.size(), "everyone is walking")


func test_parked_cars_line_side_streets_and_new_york_has_cabs() -> void:
	var world := await _build(Maps.new_york())
	var clear := world.track.half_width() + GameWorld.SIDEWALK_WIDTH
	for car in world.city.parked_cars:
		var p: Vector3 = car["position"]
		assert_gt(_flat_road_distance(world.track, p.x, p.z), clear, "off the main road")
	var taxis := world.city.parked_cars.filter(
		func(c: Dictionary) -> bool: return c["color"] == Color(1.0, 0.78, 0.05)
	)
	assert_gt(taxis.size(), 10, "New York has yellow cabs")


func test_landmarks_are_built_clear_of_road_and_water() -> void:
	for map in Maps.all():
		var world := await _build(map)
		for landmark in map.landmarks:
			var node := world.city.root.get_node_or_null("Landmark_" + landmark["type"])
			assert_not_null(node, "%s %s" % [map.id, landmark["type"]])
			var at: Vector2 = landmark["at"]
			assert_gt(_flat_road_distance(world.track, at.x, at.y), 60.0, "%s landmark" % map.id)
			assert_false(world.terrain.is_water(at.x, at.y))
		world.free()


func test_generation_is_deterministic() -> void:
	var first := await _build(Maps.washington())
	var centres := first.buildings().map(func(b: Dictionary) -> Vector3: return b["center"])
	var trees := first.city.tree_positions.duplicate()
	first.free()
	var second := await _build(Maps.washington())
	assert_eq(second.buildings().map(func(b: Dictionary) -> Vector3: return b["center"]), centres)
	assert_eq(second.city.tree_positions, trees)


func test_street_lights_line_the_kerb() -> void:
	var world := await _build(Maps.islamabad())
	assert_gt(world.street_light_count, 30)
	for pos in world.street_light_positions:
		assert_eq(world.track.lane_at(pos), -1, "lamp posts stand off the road")


func test_night_map_glows_and_day_maps_do_not() -> void:
	var night := await _build(Maps.tokyo())
	var head := (night.get_node("StreetLights/Heads") as MultiMeshInstance3D).multimesh.mesh
	assert_true((head.surface_get_material(0) as StandardMaterial3D).emission_enabled)
	assert_true((night.get_node("Environment") as WorldEnvironment).environment.glow_enabled)
	night.free()
	var day := await _build(Maps.islamabad())
	var day_head := (day.get_node("StreetLights/Heads") as MultiMeshInstance3D).multimesh.mesh
	assert_false((day_head.surface_get_material(0) as StandardMaterial3D).emission_enabled)


func test_world_builds_quickly_enough_for_a_phone() -> void:
	for map in Maps.all():
		var t0 := Time.get_ticks_msec()
		var world := GameWorld.create(map)
		var elapsed := Time.get_ticks_msec() - t0
		world.free()
		assert_lt(elapsed, 4000, "%s built in %d ms" % [map.id, elapsed])
