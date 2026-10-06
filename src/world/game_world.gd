class_name GameWorld
extends Node3D
## The 3D world for one map: sky, light, ground, road surface and scenery.
## Everything is generated deterministically from a [MapDef].

const GROUND_MARGIN := 250.0
const ROAD_STEP := 2.0
const SIDEWALK_WIDTH := 2.5
const BUILDING_SETBACK := 5.0

var map: MapDef
var track: Track
## Footprints of generated buildings (for tests and traffic sanity checks).
var building_rects: Array[Rect2] = []


static func create(map_def: MapDef) -> GameWorld:
	var world := GameWorld.new()
	world.name = "World"
	world.map = map_def
	world.track = map_def.track()
	world._build()
	return world


func _build() -> void:
	_build_environment()
	_build_ground()
	_build_road()
	_build_scenery()


func _build_environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = map.sky_top
	sky_material.sky_horizon_color = map.sky_horizon
	sky_material.ground_horizon_color = map.sky_horizon
	sky_material.ground_bottom_color = map.ground_color.darkened(0.4)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35 if map.night else 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = map.sky_horizon
	env.fog_density = 0.0015
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-map.sun_elevation, 35.0, 0.0)
	sun.light_energy = 0.25 if map.night else 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _bounds() -> Rect2:
	var rect := Rect2(map.points[0], Vector2.ZERO)
	for p in map.points:
		rect = rect.expand(p)
	return rect.grow(GROUND_MARGIN)


func _build_ground() -> void:
	var bounds := _bounds()
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = Layers.WORLD
	ground.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(bounds.size.x, 2.0, bounds.size.y)
	shape.shape = box
	var center := bounds.get_center()
	shape.position = Vector3(center.x, -1.0, center.y)
	ground.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = bounds.size
	plane.material = _material(map.ground_color, 0.95)
	mesh_instance.mesh = plane
	mesh_instance.position = Vector3(center.x, 0.0, center.y)
	ground.add_child(mesh_instance)
	add_child(ground)
	if map.has_water:
		var water := MeshInstance3D.new()
		water.name = "Water"
		var water_plane := PlaneMesh.new()
		water_plane.size = Vector2(bounds.size.x * 3.0, bounds.size.y * 3.0)
		water_plane.material = _material(Color(0.15, 0.4, 0.6), 0.1)
		water.mesh = water_plane
		water.position = Vector3(center.x, -0.4, center.y)
		add_child(water)


func _build_road() -> void:
	var road := Node3D.new()
	road.name = "Road"
	add_child(road)
	var half := track.half_width()
	road.add_child(_strip("Asphalt", -half, half, 0.02, _material(Color(0.2, 0.2, 0.22), 0.9)))
	var kerb := _material(Color(0.62, 0.62, 0.6), 0.9)
	road.add_child(_strip("SidewalkRight", half, half + SIDEWALK_WIDTH, 0.12, kerb))
	road.add_child(_strip("SidewalkLeft", -half - SIDEWALK_WIDTH, -half, 0.12, kerb))
	var paint := _material(Color(0.95, 0.95, 0.9), 0.6)
	var edge := half - Track.SHOULDER
	road.add_child(_strip("EdgeRight", edge - 0.15, edge, 0.03, paint))
	road.add_child(_strip("EdgeLeft", -edge, -edge + 0.15, 0.03, paint))
	road.add_child(_strip("LaneDivider", -0.08, 0.08, 0.03, paint, 3.0, 9.0))


## Builds a ribbon mesh between two lateral offsets along the whole loop.
## When [param dash] > 0 only dashes of that length every [param period] metres are drawn.
func _strip(
	strip_name: String,
	from_lateral: float,
	to_lateral: float,
	height: float,
	material: Material,
	dash := 0.0,
	period := 0.0
) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	var length := track.length()
	var offset := 0.0
	while offset < length:
		var step := ROAD_STEP
		if dash > 0.0:
			step = dash
		var end := minf(offset + step, length)
		var a := track.position_at(offset)
		var b := track.position_at(end)
		var ra := track.right_at(offset)
		var rb := track.right_at(end)
		var lift := Vector3.UP * height
		var a0 := a + ra * from_lateral + lift
		var a1 := a + ra * to_lateral + lift
		var b0 := b + rb * from_lateral + lift
		var b1 := b + rb * to_lateral + lift
		st.set_normal(Vector3.UP)
		for v in [a0, b0, a1, a1, b0, b1]:
			st.add_vertex(v)
		offset += period if dash > 0.0 else step
	var instance := MeshInstance3D.new()
	instance.name = strip_name
	instance.mesh = st.commit()
	return instance


func _build_scenery() -> void:
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	var rng := RandomNumberGenerator.new()
	rng.seed = map.scenery_seed
	var clearance := track.half_width() + SIDEWALK_WIDTH + BUILDING_SETBACK
	var offset := 0.0
	while offset < track.length():
		for side in [1.0, -1.0]:
			var size := Vector3(
				rng.randf_range(8.0, 16.0),
				rng.randf_range(map.building_height.x, map.building_height.y),
				rng.randf_range(8.0, 14.0)
			)
			var lateral: float = side * (clearance + size.x / 2.0 + rng.randf_range(0.0, 6.0))
			var center := track.position_at(offset) + track.right_at(offset) * lateral
			if rng.randf() < map.tree_chance:
				_try_place_tree(scenery, center, clearance)
			else:
				_try_place_building(scenery, rng, center, offset, size, clearance)
		offset += map.building_spacing


func _try_place_building(
	parent: Node3D,
	rng: RandomNumberGenerator,
	center: Vector3,
	offset: float,
	size: Vector3,
	clearance: float
) -> void:
	var forward := track.forward_at(offset)
	var basis := Basis(Vector3.UP.cross(forward), Vector3.UP, forward)
	var radius := Vector2(size.x, size.z).length() / 2.0
	if not _clear_of_road(center, radius, clearance):
		return
	var footprint := Rect2(
		Vector2(center.x, center.z) - Vector2.ONE * radius, Vector2.ONE * radius * 2
	)
	for existing in building_rects:
		if existing.intersects(footprint):
			return
	building_rects.append(footprint)
	var body := StaticBody3D.new()
	body.name = "Building%d" % building_rects.size()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.transform = Transform3D(basis, center + Vector3.UP * size.y / 2.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var color: Color = map.building_colors[rng.randi_range(0, map.building_colors.size() - 1)]
	mesh.material = _material(color, 0.85)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)
	parent.add_child(body)


func _try_place_tree(parent: Node3D, center: Vector3, clearance: float) -> void:
	if not _clear_of_road(center, 2.0, clearance - BUILDING_SETBACK + 1.0):
		return
	var tree := StaticBody3D.new()
	tree.collision_layer = Layers.WORLD
	tree.collision_mask = 0
	tree.position = center
	var shape := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.35
	trunk_shape.height = 3.0
	shape.shape = trunk_shape
	shape.position.y = 1.5
	tree.add_child(shape)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 3.0
	trunk_mesh.material = _material(Color(0.4, 0.28, 0.18), 1.0)
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.5
	tree.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radius = 2.0
	crown_mesh.height = 3.6
	crown_mesh.material = _material(map.tree_color, 1.0)
	crown.mesh = crown_mesh
	crown.position.y = 4.2
	tree.add_child(crown)
	parent.add_child(tree)


## True when a circle of [param radius] around [param center] keeps [param clearance]
## metres from the road centre line everywhere on the loop.
func _clear_of_road(center: Vector3, radius: float, clearance: float) -> bool:
	var nearest := track.position_at(track.closest_offset(center))
	nearest.y = 0.0
	return Vector3(center.x, 0.0, center.z).distance_to(nearest) - radius >= clearance - 0.01


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
