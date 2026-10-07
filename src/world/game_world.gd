class_name GameWorld
extends Node3D
## The 3D world for one map: sky (with painted horizon), light, terrain with
## rivers and lakes, the road (with real collision, so it can climb hills and
## cross bridges), bridges, the city and its landmarks.
## Everything is generated deterministically from a [MapDef].

const ROAD_STEP := 2.0
const SIDEWALK_WIDTH := 2.5
const KERB_HEIGHT := 0.12
const STREET_LIGHT_SPACING := 45.0
const STREET_LIGHT_HEIGHT := 6.5

var map: MapDef
var track: Track
var terrain: Terrain
var city: CityBuilder
var bridges: BridgeBuilder
var life: StreetLife
var street_light_count := 0
## Where each street light stands (also kept for tests: headless renderers
## do not store MultiMesh instance data).
var street_light_positions: Array[Vector3] = []
var _road_faces := PackedVector3Array()


static func create(map_def: MapDef) -> GameWorld:
	var world := GameWorld.new()
	world.name = "World"
	world.map = map_def
	world.track = map_def.track()
	world._build()
	return world


func _build() -> void:
	_build_environment()
	terrain = Terrain.create(map)
	add_child(terrain.build())
	_build_water()
	_build_road()
	_build_street_lights()
	bridges = BridgeBuilder.build(map, self)
	city = CityBuilder.build(map, terrain, self)
	_build_landmarks()
	life = StreetLife.create(map, city)
	add_child(life)


## Every building placed by the city builder (see [member CityBuilder.buildings]).
func buildings() -> Array[Dictionary]:
	return city.buildings


func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = WorldLook.environment(map)
	add_child(world_env)
	add_child(WorldLook.sun(map))


func _build_water() -> void:
	if map.rivers.is_empty() and map.lakes.is_empty():
		return
	var water := MeshInstance3D.new()
	water.name = "Water"
	var plane := PlaneMesh.new()
	plane.size = terrain.bounds.size
	plane.material = WorldLook.water()
	water.mesh = plane
	var c := terrain.bounds.get_center()
	water.position = Vector3(c.x, map.water_level, c.y)
	add_child(water)


func _build_landmarks() -> void:
	for landmark in map.landmarks:
		var at: Vector2 = landmark["at"]
		var ground := terrain.height_at(at.x, at.y)
		city.root.add_child(
			Landmarks.build(landmark["type"], at, landmark["rotation"], ground, map.night)
		)


func _build_road() -> void:
	var road := Node3D.new()
	road.name = "Road"
	add_child(road)
	var half := track.half_width()
	road.add_child(_strip("Asphalt", -half, half, 0.02, WorldLook.asphalt(), 0.0, 0.0, true))
	var pavement := WorldLook.sidewalk()
	road.add_child(
		_strip("SidewalkRight", half, half + SIDEWALK_WIDTH, KERB_HEIGHT, pavement, 0.0, 0.0, true)
	)
	road.add_child(
		_strip("SidewalkLeft", -half - SIDEWALK_WIDTH, -half, KERB_HEIGHT, pavement, 0.0, 0.0, true)
	)
	var kerb := WorldLook.kerb()
	kerb.cull_mode = BaseMaterial3D.CULL_DISABLED
	road.add_child(_kerb_face("KerbRight", half, kerb))
	road.add_child(_kerb_face("KerbLeft", -half, kerb))
	var paint := WorldLook.road_paint()
	var edge := half - Track.SHOULDER
	road.add_child(_strip("EdgeRight", edge - 0.15, edge, 0.03, paint))
	road.add_child(_strip("EdgeLeft", -edge, -edge + 0.15, 0.03, paint))
	road.add_child(_strip("LaneDivider", -0.08, 0.08, 0.03, paint, 3.0, 9.0))
	# The drivable surface: asphalt and pavements as one trimesh collider.
	var body := StaticBody3D.new()
	body.name = "RoadSurface"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(_road_faces)
	shape.shape = concave
	body.add_child(shape)
	road.add_child(body)


## Builds a ribbon mesh between two lateral offsets along the whole loop.
## When [param dash] > 0 only dashes of that length every [param period] metres are drawn.
func _strip(
	strip_name: String,
	from_lateral: float,
	to_lateral: float,
	height: float,
	material: Material,
	dash := 0.0,
	period := 0.0,
	collide := false
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
			if collide:
				_road_faces.append(v)
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
