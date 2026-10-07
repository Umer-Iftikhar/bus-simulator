class_name StreetLife
extends Node3D
## Makes the city feel inhabited: pedestrians strolling the pavements (both
## directions, with a walking bob), and street furniture (benches, bins, flags,
## market stalls). Everything is drawn with MultiMeshes so a hundred people
## cost a handful of draw calls; positions are also kept in plain arrays so
## tests can check them without a renderer.

const WALK_SPEED := Vector2(1.0, 1.7)
const BOB_HEIGHT := 0.05
const STEP_RATE := 9.0
const COAT_COLORS := [
	Color(0.18, 0.22, 0.32),
	Color(0.5, 0.18, 0.16),
	Color(0.28, 0.34, 0.24),
	Color(0.6, 0.55, 0.45),
	Color(0.12, 0.12, 0.14),
	Color(0.7, 0.5, 0.2),
	Color(0.75, 0.75, 0.78),
	Color(0.35, 0.2, 0.4),
]

var map: MapDef
var track: Track
## Per walker: {"offset", "lateral", "speed", "direction", "phase"}
var walkers: Array[Dictionary] = []
## World positions of walkers after the last update.
var walker_positions: Array[Vector3] = []
var furniture_positions: Array[Vector3] = []
var _bodies: MultiMeshInstance3D
var _heads: MultiMeshInstance3D
var _time := 0.0


static func create(map_def: MapDef, city: CityBuilder) -> StreetLife:
	var life := StreetLife.new()
	life.name = "StreetLife"
	life.map = map_def
	life.track = map_def.track()
	var rng := RandomNumberGenerator.new()
	rng.seed = map_def.scenery_seed + 1000
	life._spawn_walkers(rng)
	life._build_walker_meshes()
	life._build_furniture(rng, city)
	life._update_walkers(0.0)
	return life


## Pedestrian count scales with the map's busyness.
func walker_count() -> int:
	return walkers.size()


func _spawn_walkers(rng: RandomNumberGenerator) -> void:
	var count := clampi(int(track.length() / 13.0), 60, 300)
	if map.style == "rawalakot":
		count /= 2
	var pavement := track.half_width() + GameWorld.SIDEWALK_WIDTH / 2.0
	for i in count:
		var side := 1.0 if i % 2 == 0 else -1.0
		(
			walkers
			. append(
				{
					"offset": rng.randf_range(0.0, track.length()),
					"lateral": side * (pavement + rng.randf_range(-0.6, 0.6)),
					"speed": rng.randf_range(WALK_SPEED.x, WALK_SPEED.y),
					"direction": 1.0 if rng.randf() < 0.5 else -1.0,
					"phase": rng.randf() * TAU,
					"color": COAT_COLORS[rng.randi_range(0, COAT_COLORS.size() - 1)],
				}
			)
		)


func _build_walker_meshes() -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.24
	body.height = 1.45
	var cloth := StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo = true
	cloth.roughness = 0.9
	body.material = cloth
	var head := SphereMesh.new()
	head.radius = 0.12
	head.height = 0.24
	head.material = WorldLook.plain(Color(0.78, 0.6, 0.47), 0.8)
	_bodies = _make_multimesh("Pedestrians", body, true)
	_heads = _make_multimesh("PedestrianHeads", head, false)
	for i in walkers.size():
		_bodies.multimesh.set_instance_color(i, walkers[i]["color"])


func _make_multimesh(node_name: String, mesh: Mesh, colors: bool) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = colors
	multimesh.mesh = mesh
	multimesh.instance_count = walkers.size()
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _process(delta: float) -> void:
	_update_walkers(delta)


func _update_walkers(delta: float) -> void:
	_time += delta
	walker_positions.clear()
	for i in walkers.size():
		var w: Dictionary = walkers[i]
		var direction: float = w["direction"]
		var speed: float = w["speed"]
		var lateral: float = w["lateral"]
		var offset := track.wrap_offset(float(w["offset"]) + speed * direction * delta)
		w["offset"] = offset
		var forward := track.forward_at(offset) * direction
		var pos := track.position_at(offset) + track.right_at(offset) * lateral
		pos.y += GameWorld.KERB_HEIGHT
		var phase: float = w["phase"]
		var bob := absf(sin(_time * STEP_RATE * speed / 1.4 + phase)) * BOB_HEIGHT
		var basis := Basis(Vector3.UP.cross(forward).normalized(), Vector3.UP, forward)
		_bodies.multimesh.set_instance_transform(
			i, Transform3D(basis, pos + Vector3.UP * (0.97 + bob))
		)
		_heads.multimesh.set_instance_transform(
			i, Transform3D(basis, pos + Vector3.UP * (1.83 + bob))
		)
		walker_positions.append(pos)


func _build_furniture(rng: RandomNumberGenerator, city: CityBuilder) -> void:
	var benches: Array[Transform3D] = []
	var bins: Array[Transform3D] = []
	var poles: Array[Transform3D] = []
	var flags: Array[Transform3D] = []
	var outer := track.half_width() + GameWorld.SIDEWALK_WIDTH - 0.35
	var offset := 20.0
	while offset < track.length():
		if not map.on_bridge(offset):
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			var forward := track.forward_at(offset)
			var basis := Basis(
				Vector3.UP.cross(forward).normalized() * -side, Vector3.UP, forward * -side
			)
			var pos := track.position_at(offset) + track.right_at(offset) * side * outer
			pos.y += GameWorld.KERB_HEIGHT
			if not city.is_blocked(pos.x, pos.z, 1.2):
				benches.append(Transform3D(basis, pos + Vector3.UP * 0.25))
				furniture_positions.append(pos)
				var bin_pos := pos + forward * 2.2
				bins.append(Transform3D(Basis(), bin_pos + Vector3.UP * 0.45))
		offset += rng.randf_range(35.0, 55.0)
	if map.style in ["washington", "islamabad"]:
		var o := 60.0
		while o < track.length():
			if not map.on_bridge(o):
				var pos := track.position_at(o) - track.right_at(o) * outer
				pos.y += GameWorld.KERB_HEIGHT
				if not city.is_blocked(pos.x, pos.z, 1.0):
					poles.append(Transform3D(Basis(), pos + Vector3.UP * 4.0))
					var forward := track.forward_at(o)
					var flag_basis := Basis(
						forward, Vector3.UP, Vector3.UP.cross(forward).normalized()
					)
					flags.append(Transform3D(flag_basis, pos + Vector3.UP * 7.0 + forward * 0.8))
					furniture_positions.append(pos)
			o += 120.0
	var bench_mesh := BoxMesh.new()
	bench_mesh.size = Vector3(1.6, 0.5, 0.5)
	bench_mesh.material = WorldLook.plain(Color(0.4, 0.27, 0.15), 0.8)
	var bin_mesh := CylinderMesh.new()
	bin_mesh.top_radius = 0.28
	bin_mesh.bottom_radius = 0.25
	bin_mesh.height = 0.9
	bin_mesh.material = WorldLook.plain(Color(0.15, 0.3, 0.2), 0.6)
	add_child(CityBuilder._multimesh("Benches", bench_mesh, benches))
	add_child(CityBuilder._multimesh("Bins", bin_mesh, bins))
	if not poles.is_empty():
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.05
		pole_mesh.bottom_radius = 0.07
		pole_mesh.height = 8.0
		pole_mesh.material = WorldLook.plain(Color(0.85, 0.85, 0.85), 0.4)
		var flag_mesh := BoxMesh.new()
		flag_mesh.size = Vector3(1.6, 1.0, 0.03)
		var colors := (
			[Color(0.0, 0.4, 0.15)] if map.style == "islamabad" else [Color(0.7, 0.1, 0.15)]
		)
		flag_mesh.material = WorldLook.plain(colors[0], 0.8)
		add_child(CityBuilder._multimesh("FlagPoles", pole_mesh, poles))
		add_child(CityBuilder._multimesh("Flags", flag_mesh, flags))
