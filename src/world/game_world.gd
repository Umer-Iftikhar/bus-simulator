class_name GameWorld
extends Node3D
## The 3D world for one map: sky, light, ground, road surface and scenery.
## Everything is generated deterministically from a [MapDef].

const GROUND_MARGIN := 250.0
const ROAD_STEP := 2.0
const SIDEWALK_WIDTH := 2.5
const BUILDING_SETBACK := 5.0
const KERB_HEIGHT := 0.12
const STREET_LIGHT_SPACING := 45.0
const STREET_LIGHT_HEIGHT := 6.5

var map: MapDef
var track: Track
## Footprints of generated buildings (for tests and traffic sanity checks).
var building_rects: Array[Rect2] = []
var street_light_count := 0
## Where each street light stands (also kept for tests: headless renderers
## do not store MultiMesh instance data).
var street_light_positions: Array[Vector3] = []
var _building_material: ShaderMaterial
var _trunk_material: StandardMaterial3D
var _leaf_materials: Array[StandardMaterial3D] = []


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
	_build_street_lights()
	_build_scenery()


func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = WorldLook.environment(map)
	add_child(world_env)
	add_child(WorldLook.sun(map))


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
	plane.material = WorldLook.ground(map)
	mesh_instance.mesh = plane
	mesh_instance.position = Vector3(center.x, 0.0, center.y)
	ground.add_child(mesh_instance)
	add_child(ground)
	if map.has_water:
		var water := MeshInstance3D.new()
		water.name = "Water"
		var water_plane := PlaneMesh.new()
		water_plane.size = Vector2(bounds.size.x * 3.0, bounds.size.y * 3.0)
		water_plane.material = WorldLook.water()
		water.mesh = water_plane
		water.position = Vector3(center.x, -0.4, center.y)
		add_child(water)


func _build_road() -> void:
	var road := Node3D.new()
	road.name = "Road"
	add_child(road)
	var half := track.half_width()
	road.add_child(_strip("Asphalt", -half, half, 0.02, WorldLook.asphalt()))
	var pavement := WorldLook.sidewalk()
	road.add_child(_strip("SidewalkRight", half, half + SIDEWALK_WIDTH, KERB_HEIGHT, pavement))
	road.add_child(_strip("SidewalkLeft", -half - SIDEWALK_WIDTH, -half, KERB_HEIGHT, pavement))
	var kerb := WorldLook.kerb()
	kerb.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.add_child(_kerb_face("KerbRight", half, kerb))
	road.add_child(_kerb_face("KerbLeft", -half, kerb))
	var paint := WorldLook.road_paint()
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


## The vertical face of a kerb at [param lateral], from the road up to the sidewalk.
func _kerb_face(face_name: String, lateral: float, material: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	var length := track.length()
	var offset := 0.0
	while offset < length:
		var end := minf(offset + ROAD_STEP, length)
		var a := track.position_at(offset) + track.right_at(offset) * lateral
		var b := track.position_at(end) + track.right_at(end) * lateral
		var up := Vector3.UP * KERB_HEIGHT
		st.set_normal(-track.right_at(offset) * signf(lateral))
		for v in [a, b, a + up, a + up, b, b + up]:
			st.add_vertex(v)
		offset = end
	var instance := MeshInstance3D.new()
	instance.name = face_name
	instance.mesh = st.commit()
	return instance


## Street lights along the kerb-side pavement, drawn as two MultiMeshes (poles
## and lamp heads) to keep draw calls low on phones. Heads glow at night.
func _build_street_lights() -> void:
	var transforms: Array[Transform3D] = []
	var lateral := track.half_width() + SIDEWALK_WIDTH - 0.4
	var offset := STREET_LIGHT_SPACING / 2.0
	while offset < track.length():
		var forward := track.forward_at(offset)
		var basis := Basis(Vector3.UP.cross(forward), Vector3.UP, forward)
		transforms.append(
			Transform3D(basis, track.position_at(offset) + track.right_at(offset) * lateral)
		)
		offset += STREET_LIGHT_SPACING
	street_light_count = transforms.size()
	for xform in transforms:
		street_light_positions.append(xform.origin)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.1
	pole.height = STREET_LIGHT_HEIGHT
	pole.material = WorldLook.plain(Color(0.3, 0.31, 0.33), 0.5)
	var head := BoxMesh.new()
	head.size = Vector3(1.6, 0.14, 0.4)
	if map.night:
		head.material = WorldLook.glow(Color(1.0, 0.85, 0.6), 4.0)
	else:
		head.material = WorldLook.plain(Color(0.35, 0.36, 0.38), 0.5)
	var lights := Node3D.new()
	lights.name = "StreetLights"
	add_child(lights)
	# Poles stand at the pavement; heads overhang toward the road (-X in road space).
	var pole_offset := Transform3D(Basis(), Vector3(0, STREET_LIGHT_HEIGHT / 2.0, 0))
	var head_offset := Transform3D(Basis(), Vector3(0.7, STREET_LIGHT_HEIGHT, 0))
	lights.add_child(_multimesh("Poles", pole, transforms, pole_offset))
	lights.add_child(_multimesh("Heads", head, transforms, head_offset))


func _multimesh(
	mesh_name: String, mesh: Mesh, transforms: Array[Transform3D], local: Transform3D
) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i] * local)
	var instance := MultiMeshInstance3D.new()
	instance.name = mesh_name
	instance.multimesh = multimesh
	return instance


func _build_scenery() -> void:
	_building_material = WorldLook.building(map)
	_trunk_material = WorldLook.plain(Color(0.33, 0.23, 0.15), 1.0)
	for shade in [-0.12, 0.0, 0.12]:
		_leaf_materials.append(WorldLook.plain(map.tree_color.lightened(shade), 0.95))
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
	mesh_instance.name = "Facade"
	var mesh := BoxMesh.new()
	mesh.size = size
	var color: Color = map.building_colors[rng.randi_range(0, map.building_colors.size() - 1)]
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _building_material
	mesh_instance.set_instance_shader_parameter("wall_color", color)
	mesh_instance.set_instance_shader_parameter("building_seed", float(building_rects.size()))
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
	# Deterministic per-tree variation from its position.
	var vary := absf(sin(center.x * 12.9898 + center.z * 78.233))
	var scale := 0.8 + vary * 0.6
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.2
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 3.0 * scale
	trunk_mesh.material = _trunk_material
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.5 * scale
	tree.add_child(trunk)
	var leaves := _leaf_materials[int(vary * 100.0) % _leaf_materials.size()]
	if map.conifers:
		for tier in 3:
			var cone := MeshInstance3D.new()
			var cone_mesh := CylinderMesh.new()
			cone_mesh.top_radius = 0.0
			cone_mesh.bottom_radius = (2.2 - tier * 0.55) * scale
			cone_mesh.height = 3.0 * scale
			cone_mesh.material = leaves
			cone.mesh = cone_mesh
			cone.position.y = (3.2 + tier * 1.6) * scale
			tree.add_child(cone)
	else:
		for blob in 3:
			var crown := MeshInstance3D.new()
			var crown_mesh := SphereMesh.new()
			crown_mesh.radius = (1.7 - blob * 0.3) * scale
			crown_mesh.height = crown_mesh.radius * 1.8
			crown_mesh.radial_segments = 16
			crown_mesh.rings = 8
			crown_mesh.material = leaves
			crown.mesh = crown_mesh
			var angle := blob * 2.1 + vary * 6.0
			crown.position = Vector3(cos(angle) * 0.7, (3.6 + blob * 0.7) * scale, sin(angle) * 0.7)
			tree.add_child(crown)
	parent.add_child(tree)


## True when a circle of [param radius] around [param center] keeps [param clearance]
## metres from the road centre line everywhere on the loop.
func _clear_of_road(center: Vector3, radius: float, clearance: float) -> bool:
	var nearest := track.position_at(track.closest_offset(center))
	nearest.y = 0.0
	return Vector3(center.x, 0.0, center.z).distance_to(nearest) - radius >= clearance - 0.01
