class_name Terrain
extends RefCounted
## Heightfield ground for a map: rolling hills or mountains (noise), a base
## slope, rivers and lakes carved below the water line, and a corridor that
## follows the road's elevation with embankments and cuttings blending into
## the natural ground. Under bridge decks the river valley is left open.

const CELL := 12.0
const MARGIN := 260.0
const BANK := 14.0
## Distance from the road centre that is levelled to the road.
const CORRIDOR := 12.5
## Width of the embankment blend beyond the corridor.
const BLEND := 30.0
## Under a bridge the ground is cut into a valley at least this far below the deck.
const BRIDGE_CLEARANCE := 9.0
const ROCK_COLOR := Color(0.42, 0.4, 0.38)
const SNOW_COLOR := Color(0.95, 0.96, 0.98)

var map: MapDef
var track: Track
var noise := FastNoiseLite.new()
var bounds: Rect2
var columns := 0
var rows := 0
var _bridges: Array[Vector2] = []
## Final heights per grid vertex (row-major), filled by [method prepare].
var _heights := PackedFloat32Array()
var _ready := false


static func create(map_def: MapDef) -> Terrain:
	var terrain := Terrain.new()
	terrain.map = map_def
	terrain.track = map_def.track()
	terrain.noise.seed = map_def.scenery_seed
	terrain.noise.frequency = 0.0035
	terrain.noise.fractal_octaves = 5
	terrain._bridges = map_def.bridge_ranges()
	var rect := Rect2(map_def.points[0], Vector2.ZERO)
	for p in map_def.points:
		rect = rect.expand(p)
	terrain.bounds = rect.grow(MARGIN)
	return terrain


## Ground height ignoring the road (hills, slope, rivers and lakes).
func natural_height(x: float, z: float) -> float:
	var h := map.terrain_slope.x * x + map.terrain_slope.y * z
	if map.terrain_amplitude > 0.0:
		var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
		h += map.terrain_amplitude * pow(n, 1.6)
	return _carve_water(x, z, h)


## Signed distance to the nearest river or lake edge (negative inside water).
func water_distance(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := INF
	for river in map.rivers:
		var points: PackedVector2Array = river["points"]
		for i in points.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
			best = minf(best, p.distance_to(closest) - river["width"] / 2.0)
	for lake in map.lakes:
		best = minf(best, p.distance_to(lake["center"]) - lake["radius"])
	return best


func is_water(x: float, z: float) -> bool:
	return water_distance(x, z) < 0.0


func _carve_water(x: float, z: float, h: float) -> float:
	if map.rivers.is_empty() and map.lakes.is_empty():
		return h
	var d := water_distance(x, z)
	if d < 0.0:
		return minf(h, map.river_bed)
	if d < BANK:
		return lerpf(minf(h, map.river_bed), h, smoothstep(0.0, BANK, d))
	return h


func _under_bridge(offset: float) -> bool:
	for r in _bridges:
		if track.distance_ahead(r.x, offset) <= track.distance_ahead(r.x, r.y):
			return true
	return false


## Ground height including the road corridor. After [method prepare] this is a
## fast bilinear lookup in the grid; before it, an exact (slower) evaluation.
func height_at(x: float, z: float) -> float:
	if not _ready:
		return exact_height_at(x, z)
	var gx := clampf((x - bounds.position.x) / CELL, 0.0, columns - 1.001)
	var gz := clampf((z - bounds.position.y) / CELL, 0.0, rows - 1.001)
	var c := int(gx)
	var r := int(gz)
	var fx := gx - c
	var fz := gz - r
	var i := r * columns + c
	# Interpolate on the same two triangles the mesh uses (split along the
	# i+1 / i+columns diagonal), so objects sit exactly on the visible ground.
	if fx + fz <= 1.0:
		return (
			_heights[i]
			+ (_heights[i + 1] - _heights[i]) * fx
			+ ((_heights[i + columns] - _heights[i]) * fz)
		)
	var h11 := _heights[i + columns + 1]
	return h11 + (_heights[i + columns] - h11) * (1.0 - fx) + (_heights[i + 1] - h11) * (1.0 - fz)


## Computes the height grid. The road's influence is "stamped" in by walking
## the road and updating nearby cells, which is far cheaper than searching the
## curve for every vertex.
func prepare() -> void:
	columns = int(ceil(bounds.size.x / CELL)) + 1
	rows = int(ceil(bounds.size.y / CELL)) + 1
	var count := columns * rows
	var road_distance := PackedFloat32Array()
	road_distance.resize(count)
	road_distance.fill(INF)
	var road_height := PackedFloat32Array()
	road_height.resize(count)
	var bridge := PackedByteArray()
	bridge.resize(count)
	var reach := CORRIDOR + BLEND + CELL
	var offset := 0.0
	while offset < track.length():
		var p := track.position_at(offset)
		var under := 1 if _under_bridge(offset) else 0
		var c0 := maxi(int(floor((p.x - reach - bounds.position.x) / CELL)), 0)
		var c1 := mini(int(ceil((p.x + reach - bounds.position.x) / CELL)), columns - 1)
		var r0 := maxi(int(floor((p.z - reach - bounds.position.y) / CELL)), 0)
		var r1 := mini(int(ceil((p.z + reach - bounds.position.y) / CELL)), rows - 1)
		for r in range(r0, r1 + 1):
			var z := bounds.position.y + r * CELL
			for c in range(c0, c1 + 1):
				var x := bounds.position.x + c * CELL
				var d := Vector2(x - p.x, z - p.z).length()
				var i := r * columns + c
				if d < road_distance[i]:
					road_distance[i] = d
					road_height[i] = p.y - 0.15
					bridge[i] = under
		offset += 2.0
	_heights.resize(count)
	for r in rows:
		for c in columns:
			var i := r * columns + c
			var x := bounds.position.x + c * CELL
			var z := bounds.position.y + r * CELL
			var natural := natural_height(x, z)
			var d := road_distance[i]
			if bridge[i] == 1:
				# A valley under the deck: never let a hillside swallow the bridge.
				_heights[i] = minf(natural, road_height[i] - BRIDGE_CLEARANCE)
			elif d >= CORRIDOR + BLEND:
				_heights[i] = natural
			elif d <= CORRIDOR:
				_heights[i] = road_height[i]
			else:
				var t := smoothstep(CORRIDOR, CORRIDOR + BLEND, d)
				_heights[i] = lerpf(road_height[i], natural, t)
	_ready = true


## Exact ground height including the road corridor (no grid).
func exact_height_at(x: float, z: float) -> float:
	var natural := natural_height(x, z)
	var flat := Vector3(x, 0.0, z)
	var offset := track.closest_offset(flat)
	var centre := track.position_at(offset)
	var road_h := centre.y - 0.15
	centre.y = 0.0
	var d := flat.distance_to(centre)
	if d >= CORRIDOR + BLEND:
		return natural
	if _under_bridge(offset):
		return natural
	if d <= CORRIDOR:
		return road_h
	return lerpf(road_h, natural, smoothstep(CORRIDOR, CORRIDOR + BLEND, d))


func _color_for(h: float, slope: float) -> Color:
	var base := map.ground_color
	if h < map.water_level + 1.5:
		base = base.lerp(Color(0.55, 0.5, 0.38), 0.6)  # muddy banks
	var rockiness := clampf((slope - 0.45) * 2.0, 0.0, 1.0)
	if map.terrain_amplitude > 60.0:
		rockiness = maxf(rockiness, clampf((h - 110.0) / 60.0, 0.0, 1.0) * 0.7)
	var color := base.lerp(ROCK_COLOR, rockiness)
	if h > 170.0:
		color = color.lerp(SNOW_COLOR, clampf((h - 170.0) / 40.0, 0.0, 1.0))
	return color


## Builds the visible mesh and its collision as one StaticBody named "Ground".
func build() -> StaticBody3D:
	if not _ready:
		prepare()
	var heights := _heights
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rows:
		for c in columns:
			var h := heights[r * columns + c]
			var hx := heights[r * columns + mini(c + 1, columns - 1)]
			var hz := heights[mini(r + 1, rows - 1) * columns + c]
			var slope := Vector2(hx - h, hz - h).length() / CELL
			st.set_color(_color_for(h, slope))
			st.add_vertex(Vector3(bounds.position.x + c * CELL, h, bounds.position.y + r * CELL))
	for r in rows - 1:
		for c in columns - 1:
			var i := r * columns + c
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + columns)
			st.add_index(i + 1)
			st.add_index(i + columns + 1)
			st.add_index(i + columns)
	st.generate_normals()
	# Fine-grained texture: paving in the big cities, grass and earth elsewhere.
	var urban := map.style in ["nyc", "tokyo"]
	var scale := 0.35 if urban else 0.12
	var material := WorldLook.textured(Color.WHITE, 1.0, 0.1, scale, map.scenery_seed, 0.18)
	material.vertex_color_use_as_albedo = true
	st.set_material(material)
	var mesh := st.commit()
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var visual := MeshInstance3D.new()
	visual.name = "TerrainMesh"
	visual.mesh = mesh
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(mesh.get_faces())
	shape.shape = concave
	body.add_child(shape)
	return body
