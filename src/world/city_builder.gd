class_name CityBuilder
extends RefCounted
## Lays out the city along the road: blocks of street-front buildings separated
## by side streets (with zebra crossings), taller rows behind, parks, street
## trees, and style-specific details (NYC water towers and setbacks, Tokyo
## neon, Washington porticos, Islamabad green glass, Rawalakot tin roofs).
##
## Street-front buildings get collision (you can crash into them); rows behind
## are visual only. Every building is recorded in [member buildings].

const FLOOR_HEIGHT := 3.2
const SETBACK := 1.5
const SIDE_STREET_WIDTH := 10.0
const SIDE_STREET_LENGTH := 70.0
const DETAIL_RANGE := 260.0
const BUILDING_RANGE := 900.0
const NEON_COLORS := [
	Color(1.0, 0.15, 0.55),
	Color(0.1, 0.9, 1.0),
	Color(1.0, 0.85, 0.1),
	Color(0.5, 0.2, 1.0),
	Color(0.2, 1.0, 0.4),
	Color(1.0, 0.4, 0.1),
]
## Dry-land margin every object keeps from rivers and lakes (m).
const WATER_MARGIN := 5.0
const TAXI_STYLES := ["nyc"]
const ROOF_COLORS := [Color(0.7, 0.12, 0.1), Color(0.15, 0.45, 0.25), Color(0.15, 0.3, 0.6)]

var map: MapDef
var track: Track
var terrain: Terrain
var root: Node3D
var rng := RandomNumberGenerator.new()
## {"center": Vector3 (ground), "size": Vector3, "yaw": float, "collides": bool}
var buildings: Array[Dictionary] = []
var side_street_count := 0
## Footprints (2D polygons) of side streets, kept clear of trees and cars.
var side_streets: Array[PackedVector2Array] = []
## Parked cars: {"position": Vector3, "yaw": float}
var parked_cars: Array[Dictionary] = []
## Every tree base position (also for tests: no renderer needed).
var tree_positions: Array[Vector3] = []
var _facade: ShaderMaterial
var _clearance := 0.0
var _tree_transforms: Array[Transform3D] = []
var _crown_transforms: Array[Transform3D] = []
var _materials := {}
## Spatial hash of building indices by 50 m cell, for fast overlap checks.
var _grid := {}


static func build(map_def: MapDef, ground: Terrain, parent: Node3D) -> CityBuilder:
	var city := CityBuilder.new()
	city.map = map_def
	city.track = map_def.track()
	city.terrain = ground
	city.root = Node3D.new()
	city.root.name = "Scenery"
	parent.add_child(city.root)
	city.rng.seed = map_def.scenery_seed
	city._facade = WorldLook.building(map_def)
	city._clearance = city.track.half_width() + GameWorld.SIDEWALK_WIDTH + SETBACK
	if map_def.style == "islamabad":
		city._clearance += 10.0  # green verges along Islamabad's avenues
	city._build_frontage()
	city._build_parks()
	city._build_parked_cars()
	city._build_trees()
	return city


# ----------------------------------------------------------------- layout


func _build_frontage() -> void:
	var length := track.length()
	for side in [1.0, -1.0]:
		var offset := rng.randf_range(0.0, 30.0)
		while offset < length:
			var block := rng.randf_range(map.block_length.x, map.block_length.y)
			_build_block(side, offset, minf(offset + block, length))
			offset += block
			if map.side_streets and offset < length:
				_build_side_street(side, offset + SIDE_STREET_WIDTH / 2.0)
				offset += SIDE_STREET_WIDTH


func _build_block(side: float, from: float, to: float) -> void:
	var offset := from
	while offset < to - 6.0:
		var width := minf(rng.randf_range(12.0, 26.0), to - offset)
		var mid := offset + width / 2.0
		if map.on_bridge(mid) or absf(track.grade_at(mid)) > 0.08:
			offset += width
			continue
		if rng.randf() < map.tree_chance:
			_queue_tree_cluster(side, mid)
		else:
			var front_depth := rng.randf_range(12.0, 20.0)
			var floors := rng.randi_range(map.floors.x, map.floors.y)
			_place(side, mid, width - 0.6, front_depth, floors, 0.0, true)
			if map.style != "rawalakot":
				var back_depth := rng.randf_range(14.0, 24.0)
				var back_floors := int(floors * rng.randf_range(1.1, 1.8)) + 1
				if map.style == "washington":
					# Washington's height limit keeps the skyline low.
					back_floors = mini(back_floors, map.floors.y)
				_place(side, mid, width - 0.6, back_depth, back_floors, front_depth + 6.0, false)
		offset += width


## Places one building beside the road. Returns false when the plot is unusable.
func _place(
	side: float, offset: float, width: float, depth: float, floors: int, behind: float, front: bool
) -> bool:
	var forward := track.forward_at(offset)
	var right := track.right_at(offset)
	var lateral := side * (_clearance + behind + depth / 2.0)
	var flat_center := track.position_at(offset) + right * lateral
	flat_center.y = 0.0
	var size := Vector3(width, floors * FLOOR_HEIGHT, depth)
	if not _plot_is_free(flat_center, Vector2(width, depth), forward):
		return false
	var ground_y := _lowest_ground(flat_center, Vector2(width, depth), forward)
	if ground_y < map.water_level + 0.5:
		return false
	var center := Vector3(flat_center.x, ground_y, flat_center.z)
	# Local +X runs along the road, local +Z points to the road's right.
	var yaw := atan2(-forward.z, forward.x)
	buildings.append({"center": center, "size": size, "yaw": yaw, "collides": front})
	_grid_add(buildings.size() - 1, center)
	_make_building(center, size, yaw, front, side)
	return true


func _plot_is_free(center: Vector3, footprint: Vector2, forward: Vector3) -> bool:
	var radius := footprint.length() / 2.0
	var nearest := track.position_at(track.closest_offset(center))
	nearest.y = 0.0
	if center.distance_to(nearest) - radius * 0.75 < _clearance - 0.2:
		return false
	for corner in _corners(center, footprint, forward):
		if terrain.water_distance(corner.x, corner.y) < WATER_MARGIN:
			return false
		var c3 := Vector3(corner.x, 0, corner.y)
		var near_corner := track.position_at(track.closest_offset(c3))
		near_corner.y = 0.0
		if c3.distance_to(near_corner) < _clearance - 0.5:
			return false
	for landmark in map.landmarks:
		if Vector2(center.x, center.z).distance_to(landmark["at"]) < radius + 70.0:
			return false
	for park in map.parks:
		if park.grow(4.0).has_point(Vector2(center.x, center.z)):
			return false
	var mine := _corners(center, footprint, forward)
	for street in side_streets:
		if Geometry2D.intersect_polygons(mine, street).size() > 0:
			return false
	for index in _nearby(center):
		var other: Dictionary = buildings[index]
		var other_size := Vector2(other["size"].x, other["size"].z)
		if (
			Vector2(center.x, center.z).distance_to(Vector2(other["center"].x, other["center"].z))
			> (radius + other_size.length() / 2.0)
		):
			continue
		var theirs := _corners(other["center"], other_size, CityBuilder.yaw_forward(other["yaw"]))
		if Geometry2D.intersect_polygons(mine, theirs).size() > 0:
			return false
	return true


static func yaw_forward(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / 50.0), floori(p.z / 50.0))


func _grid_add(index: int, p: Vector3) -> void:
	var key := _cell(p)
	if not _grid.has(key):
		_grid[key] = []
	_grid[key].append(index)


func _nearby(p: Vector3) -> Array:
	var found := []
	var c := _cell(p)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			found.append_array(_grid.get(c + Vector2i(dx, dz), []))
	return found


func _corners(center: Vector3, footprint: Vector2, forward: Vector3) -> PackedVector2Array:
	# footprint.x runs along the road (width), footprint.y across it (depth).
	var c := Vector2(center.x, center.z)
	var along := Vector2(forward.x, forward.z).normalized() * footprint.x / 2.0
	var across := Vector2(-forward.z, forward.x).normalized() * footprint.y / 2.0
	return PackedVector2Array(
		[c + along + across, c + along - across, c - along - across, c - along + across]
	)


func _lowest_ground(center: Vector3, footprint: Vector2, forward: Vector3) -> float:
	var lowest := terrain.height_at(center.x, center.z)
	for corner in _corners(center, footprint, forward):
		lowest = minf(lowest, terrain.height_at(corner.x, corner.y))
	return lowest


# ----------------------------------------------------------------- buildings


func _make_building(center: Vector3, size: Vector3, yaw: float, front: bool, side: float) -> void:
	var node: Node3D
	if front:
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position.y = size.y / 2.0
		body.add_child(shape)
		node = body
	else:
		node = Node3D.new()
	node.name = "Building%d" % buildings.size()
	node.position = center
	node.rotation.y = yaw
	root.add_child(node)
	# Extend the walls a few metres below ground so slopes never show a gap.
	var foundation := 4.0
	var color: Color = map.building_colors[rng.randi_range(0, map.building_colors.size() - 1)]
	var main := _facade_box(
		node, Vector3(size.x, size.y + foundation, size.z), size.y / 2.0 - foundation / 2.0, color
	)
	main.name = "Facade"
	match map.style:
		"nyc":
			_nyc_details(node, size, color)
		"tokyo":
			_tokyo_details(node, size, side)
		"washington":
			_washington_details(node, size, side)
		"islamabad":
			_islamabad_details(node, size)
		"rawalakot":
			_rawalakot_roof(node, size)


func _facade_box(parent: Node3D, size: Vector3, y: float, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _facade
	instance.set_instance_shader_parameter("wall_color", color)
	instance.set_instance_shader_parameter("building_seed", float(buildings.size()))
	instance.position.y = y
	instance.visibility_range_end = BUILDING_RANGE
	parent.add_child(instance)
	return instance


func _detail(
	parent: Node3D, mesh: PrimitiveMesh, at: Vector3, material: Material
) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.visibility_range_end = DETAIL_RANGE
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _mat(key: String, color: Color, emission := 0.0, metallic := 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := (
		WorldLook.glow(color, emission) if emission > 0.0 else WorldLook.plain(color, 0.7)
	)
	material.metallic = metallic
	_materials[key] = material
	return material


func _nyc_details(node: Node3D, size: Vector3, color: Color) -> void:
	if size.y > 45.0 and rng.randf() < 0.6:
		# Setback tower rising from the podium.
		var tower := Vector3(size.x * 0.65, size.y * rng.randf_range(0.3, 0.6), size.z * 0.65)
		_facade_box(node, tower, size.y + tower.y / 2.0, color.darkened(0.08))
	elif rng.randf() < 0.45:
		# Classic wooden rooftop water tower on legs.
		var tank := CylinderMesh.new()
		tank.top_radius = 1.6
		tank.bottom_radius = 1.6
		tank.height = 3.2
		_detail(
			node,
			tank,
			Vector3(size.x * 0.2, size.y + 4.2, 0),
			_mat("tank", Color(0.45, 0.32, 0.22))
		)
		_detail(
			node,
			_box(Vector3(2.8, 2.6, 2.8)),
			Vector3(size.x * 0.2, size.y + 1.3, 0),
			_mat("legs", Color(0.15, 0.15, 0.15))
		)
	if rng.randf() < 0.5:
		_detail(
			node,
			_box(Vector3(3.0, 1.6, 2.0)),
			Vector3(-size.x * 0.25, size.y + 0.8, size.z * 0.2),
			_mat("hvac", Color(0.55, 0.56, 0.58))
		)


func _tokyo_details(node: Node3D, size: Vector3, side: float) -> void:
	# The road lies on the building's -Z side (side 1) or +Z side (side -1).
	var street_z := -side * (size.z / 2.0 + 0.25)
	var sign_count := rng.randi_range(1, 3)
	for i in sign_count:
		var color: Color = NEON_COLORS[rng.randi_range(0, NEON_COLORS.size() - 1)]
		var tall := rng.randf_range(6.0, minf(16.0, size.y * 0.7))
		var x := rng.randf_range(-size.x * 0.4, size.x * 0.4)
		_detail(
			node,
			_box(Vector3(1.2, tall, 0.4)),
			Vector3(x, rng.randf_range(4.0, maxf(size.y - tall, 4.5)) + tall / 2.0, street_z),
			_mat("neon%s" % color.to_html(), color, 4.0)
		)
	if rng.randf() < 0.4:
		var color: Color = NEON_COLORS[rng.randi_range(0, NEON_COLORS.size() - 1)]
		_detail(
			node,
			_box(Vector3(size.x * 0.7, 4.0, 0.4)),
			Vector3(0, size.y + 2.5, 0),
			_mat("board%s" % color.to_html(), color, 3.0)
		)


func _washington_details(node: Node3D, size: Vector3, side: float) -> void:
	if rng.randf() < 0.5:
		# Classical portico: a row of columns and a pediment on the street face.
		var street_z := -side * (size.z / 2.0 + 1.2)
		var column := CylinderMesh.new()
		column.top_radius = 0.35
		column.bottom_radius = 0.4
		column.height = 7.0
		var count := maxi(int(size.x / 3.0), 3)
		var marble := _mat("marble", Color(0.95, 0.94, 0.9))
		for i in count:
			var x := -size.x * 0.4 + i * size.x * 0.8 / (count - 1)
			_detail(node, column.duplicate(), Vector3(x, 3.5, street_z), marble)
		_detail(
			node,
			_box(Vector3(size.x * 0.88, 1.2, 2.6)),
			Vector3(0, 7.6, street_z + side * 0.6),
			marble
		)
	_detail(
		node,
		_box(Vector3(size.x + 0.4, 0.8, size.z + 0.4)),
		Vector3(0, size.y + 0.4, 0),
		_mat("parapet", Color(0.82, 0.8, 0.76))
	)


func _islamabad_details(node: Node3D, size: Vector3) -> void:
	if rng.randf() < 0.5:
		var glass := _mat("green_glass", Color(0.25, 0.45, 0.42), 0.0, 0.6)
		glass.roughness = 0.1
		_detail(
			node,
			_box(Vector3(size.x * 0.4, size.y * 0.8, size.z + 0.3)),
			Vector3(size.x * 0.2, size.y * 0.45, 0),
			glass
		)
	_detail(
		node,
		_box(Vector3(size.x + 0.6, 0.6, size.z + 0.6)),
		Vector3(0, size.y + 0.3, 0),
		_mat("trim", Color(0.85, 0.83, 0.8))
	)


func _rawalakot_roof(node: Node3D, size: Vector3) -> void:
	# Pitched tin roof: a triangular prism along the building.
	var prism := PrismMesh.new()
	prism.size = Vector3(size.z + 0.8, 2.2, size.x + 0.8)
	var color: Color = ROOF_COLORS[rng.randi_range(0, ROOF_COLORS.size() - 1)]
	var roof := _detail(
		node, prism, Vector3(0, size.y + 1.1, 0), _mat("roof%s" % color.to_html(), color, 0.0, 0.5)
	)
	roof.rotation.y = PI / 2.0
	roof.visibility_range_end = BUILDING_RANGE


# ----------------------------------------------------------------- streets


func _build_side_street(side: float, offset: float) -> void:
	if map.on_bridge(offset) or absf(track.grade_at(offset)) > 0.04:
		return
	var right := track.right_at(offset)
	var start_lateral := side * (track.half_width() + GameWorld.SIDEWALK_WIDTH)
	var start := track.position_at(offset) + right * start_lateral
	var end := start + right * side * SIDE_STREET_LENGTH
	for p in [end, start.lerp(end, 0.5)]:
		var near := track.position_at(track.closest_offset(p))
		if Vector2(p.x, p.z).distance_to(Vector2(near.x, near.z)) < track.half_width() + 12.0:
			return
		if terrain.is_water(p.x, p.z):
			return
	var along := track.forward_at(offset) * (SIDE_STREET_WIDTH / 2.0 + 1.0)
	var footprint := PackedVector2Array(
		[
			Vector2(start.x + along.x, start.z + along.z),
			Vector2(start.x - along.x, start.z - along.z),
			Vector2(end.x - along.x, end.z - along.z),
			Vector2(end.x + along.x, end.z + along.z),
		]
	)
	# Only lay the street if no building already stands in its way (on bends,
	# back-row plots fan out across where the street would go).
	for p in [start, start.lerp(end, 0.5), end]:
		for index in _nearby(p):
			var other: Dictionary = buildings[index]
			var size := Vector2(other["size"].x, other["size"].z)
			var poly := _corners(other["center"], size, CityBuilder.yaw_forward(other["yaw"]))
			if Geometry2D.intersect_polygons(poly, footprint).size() > 0:
				return
	side_street_count += 1
	side_streets.append(footprint)
	_queue_parked_cars(start, end, right * side, track.forward_at(offset))
	var street := MeshInstance3D.new()
	street.name = "SideStreet%d" % side_street_count
	var mesh := _box(Vector3(SIDE_STREET_WIDTH, 0.06, SIDE_STREET_LENGTH))
	mesh.material = WorldLook.asphalt()
	street.mesh = mesh
	var mid := start.lerp(end, 0.5)
	mid.y = start.y - 0.02
	street.position = mid
	street.rotation.y = atan2(right.x, right.z)
	street.visibility_range_end = BUILDING_RANGE
	root.add_child(street)
	_zebra(offset)


## A zebra crossing across the main road at [param offset].
func _zebra(offset: float) -> void:
	var paint := _mat("zebra", Color(0.93, 0.93, 0.9))
	var forward := track.forward_at(offset)
	var right := track.right_at(offset)
	var centre := track.position_at(offset)
	var half := track.half_width() - Track.SHOULDER
	var lateral := -half + 0.4
	var zebra := Node3D.new()
	zebra.name = "Zebra"
	root.add_child(zebra)
	while lateral < half:
		var bar := MeshInstance3D.new()
		var mesh := _box(Vector3(0.5, 0.02, 3.0))
		mesh.material = paint
		bar.mesh = mesh
		bar.position = centre + right * lateral + Vector3.UP * 0.035
		bar.rotation.y = atan2(forward.x, forward.z)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		zebra.add_child(bar)
		lateral += 1.0


# ----------------------------------------------------------------- greenery


func _queue_tree_cluster(side: float, offset: float) -> void:
	for i in 3:
		var lateral := side * (_clearance + rng.randf_range(2.0, 18.0))
		var along := offset + rng.randf_range(-6.0, 6.0)
		var p := track.position_at(along) + track.right_at(along) * lateral
		_queue_tree(p.x, p.z)


## True when a round object of [param radius] at (x, z) would sit in water,
## on the road or a side street, inside a building or on a landmark.
func is_blocked(x: float, z: float, radius: float) -> bool:
	if terrain.water_distance(x, z) < WATER_MARGIN + radius:
		return true
	if terrain.height_at(x, z) < map.water_level + 1.0:
		return true
	var p := Vector2(x, z)
	for landmark in map.landmarks:
		if p.distance_to(landmark["at"]) < 60.0 + radius:
			return true
	for street in side_streets:
		if Geometry2D.is_point_in_polygon(p, street):
			return true
	var flat := Vector3(x, 0, z)
	for index in _nearby(flat):
		var other: Dictionary = buildings[index]
		var other_size := Vector2(other["size"].x + radius * 2.0, other["size"].z + radius * 2.0)
		var poly := _corners(other["center"], other_size, CityBuilder.yaw_forward(other["yaw"]))
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func _queue_tree(x: float, z: float) -> void:
	if is_blocked(x, z, 2.5):
		return
	var flat := Vector3(x, 0, z)
	var near := track.position_at(track.closest_offset(flat))
	near.y = 0.0
	if flat.distance_to(near) < track.half_width() + GameWorld.SIDEWALK_WIDTH + 1.5:
		return
	# Sink the trunk a little so it never shows a gap on slopes.
	var y := terrain.height_at(x, z) - 0.3
	var scale := rng.randf_range(0.8, 1.4)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
	_tree_transforms.append(Transform3D(basis, Vector3(x, y, z)))
	tree_positions.append(Vector3(x, y, z))


func _build_parks() -> void:
	var grass := WorldLook.plain(map.ground_color.lightened(0.12), 1.0)
	for park in map.parks:
		var lawn := MeshInstance3D.new()
		lawn.name = "Park"
		var plane := PlaneMesh.new()
		plane.size = park.size
		plane.material = grass
		lawn.mesh = plane
		var c := park.get_center()
		lawn.position = Vector3(c.x, terrain.height_at(c.x, c.y) + 0.08, c.y)
		root.add_child(lawn)
		var count := int(park.get_area() / 260.0)
		for i in count:
			var x := rng.randf_range(park.position.x + 4.0, park.end.x - 4.0)
			var z := rng.randf_range(park.position.y + 4.0, park.end.y - 4.0)
			var clear := true
			for landmark in map.landmarks:
				if Vector2(x, z).distance_to(landmark["at"]) < 45.0:
					clear = false
			if clear:
				_queue_tree(x, z)
	if map.style == "rawalakot":
		# Pine forest on the hillsides beyond the town.
		for i in 900:
			var x := rng.randf_range(terrain.bounds.position.x, terrain.bounds.end.x)
			var z := rng.randf_range(terrain.bounds.position.y, terrain.bounds.end.y)
			var flat := Vector3(x, 0, z)
			var near := track.position_at(track.closest_offset(flat))
			near.y = 0.0
			if flat.distance_to(near) > 45.0 and terrain.natural_height(x, z) < 150.0:
				_queue_tree(x, z)
	if map.style in ["washington", "islamabad"]:
		# Street trees lining the avenues.
		var offset := 6.0
		while offset < track.length():
			if not map.on_bridge(offset):
				for side in [1.0, -1.0]:
					var lateral: float = (
						side * (track.half_width() + GameWorld.SIDEWALK_WIDTH + 2.5)
					)
					var p := track.position_at(offset) + track.right_at(offset) * lateral
					_queue_tree(p.x, p.z)
			offset += 18.0


## All trees drawn as two MultiMeshes (trunks and crowns): cheap on phones.
func _build_trees() -> void:
	# Final pass: trees queued early may since have had a street or building
	# placed over them.
	var kept: Array[Transform3D] = []
	tree_positions.clear()
	for xform in _tree_transforms:
		var p := xform.origin
		if not is_blocked(p.x, p.z, 2.0):
			kept.append(xform)
			tree_positions.append(p)
	_tree_transforms = kept
	if _tree_transforms.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.3
	trunk.height = 3.0
	trunk.material = WorldLook.plain(Color(0.33, 0.23, 0.15), 1.0)
	var crown: PrimitiveMesh
	if map.conifers:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 2.2
		cone.height = 7.0
		crown = cone
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 2.2
		sphere.height = 3.8
		sphere.radial_segments = 12
		sphere.rings = 6
		crown = sphere
	crown.material = WorldLook.plain(map.tree_color, 0.95)
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var crown_lift := 6.0 if map.conifers else 4.4
	for xform in _tree_transforms:
		trunks.append(xform * Transform3D(Basis(), Vector3(0, 1.5, 0)))
		crowns.append(xform * Transform3D(Basis(), Vector3(0, crown_lift, 0)))
	root.add_child(_multimesh("TreeTrunks", trunk, trunks))
	root.add_child(_multimesh("TreeCrowns", crown, crowns))


## Cars parked along both kerbs of a side street.
func _queue_parked_cars(start: Vector3, end: Vector3, outward: Vector3, along: Vector3) -> void:
	var length := start.distance_to(end)
	var d := 8.0
	while d < length - 6.0:
		for kerb in [1.0, -1.0]:
			if rng.randf() < 0.55:
				var p: Vector3 = (
					start + outward * d + along * kerb * (SIDE_STREET_WIDTH / 2.0 - 1.3)
				)
				p.y = terrain.height_at(p.x, p.z) + 0.03
				if terrain.water_distance(p.x, p.z) > WATER_MARGIN:
					parked_cars.append({"position": p, "yaw": atan2(outward.x, outward.z)})
		d += 6.0


## All parked cars on the map as one MultiMesh per car part (paint via
## per-instance colour): a dozen draw calls however many cars are parked.
func _build_parked_cars() -> void:
	if parked_cars.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "ParkedCars"
	root.add_child(holder)
	var car_transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for car in parked_cars:
		var color: Color = TrafficManager.COLORS[rng.randi_range(
			0, TrafficManager.COLORS.size() - 1
		)]
		if map.style in TAXI_STYLES and rng.randf() < 0.35:
			color = Color(1.0, 0.78, 0.05)
		car["color"] = color
		colors.append(color)
		car_transforms.append(Transform3D(Basis(Vector3.UP, car["yaw"]), car["position"]))
	var painted := StandardMaterial3D.new()
	painted.vertex_color_use_as_albedo = true
	painted.metallic = 0.45
	painted.roughness = 0.3
	for spec in TrafficCar.part_specs():
		var mesh: PrimitiveMesh = spec["mesh"]
		var takes_paint: bool = spec["material"] == null
		mesh.material = painted if takes_paint else spec["material"]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = takes_paint
		multimesh.mesh = mesh
		multimesh.instance_count = car_transforms.size()
		var local: Transform3D = spec["transform"]
		for i in car_transforms.size():
			multimesh.set_instance_transform(i, car_transforms[i] * local)
			if takes_paint:
				multimesh.set_instance_color(i, colors[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Parked" + spec["name"]
		instance.multimesh = multimesh
		instance.visibility_range_end = 300.0
		holder.add_child(instance)


func tree_count() -> int:
	return _tree_transforms.size()


static func _multimesh(
	node_name: String, mesh: Mesh, transforms: Array[Transform3D]
) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	return instance
