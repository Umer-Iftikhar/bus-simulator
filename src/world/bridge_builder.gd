class_name BridgeBuilder
extends RefCounted
## Builds every bridge on a map: a concrete deck under the road, crash
## barriers (with collision, so buses can't drive off), piers down to the
## river bed, and either suspension towers with cables or stone arches.
## Rods (cables, hangers, spandrels) are batched into MultiMeshes.

const DECK_DEPTH := 1.4
const BARRIER_HEIGHT := 1.1
const PIER_SPACING := 32.0
const TOWER_HEIGHT := 30.0

var map: MapDef
var track: Track
var root: Node3D
var concrete := WorldLook.plain(Color(0.62, 0.61, 0.58), 0.9)
var steel := WorldLook.plain(Color(0.35, 0.38, 0.42), 0.4)
var stone := WorldLook.plain(Color(0.72, 0.68, 0.6), 0.95)
var barrier_faces := PackedVector3Array()
var _rods := {}


static func build(map_def: MapDef, parent: Node3D) -> BridgeBuilder:
	var builder := BridgeBuilder.new()
	builder.map = map_def
	builder.track = map_def.track()
	builder.root = Node3D.new()
	builder.root.name = "Bridges"
	parent.add_child(builder.root)
	if map_def.night:
		builder.steel = WorldLook.glow(Color(0.85, 0.85, 0.95), 1.2)
	for r in map_def.bridge_ranges():
		builder._build_bridge(r.x, r.y)
	builder._finish()
	return builder


func _edge() -> float:
	return track.half_width() + GameWorld.SIDEWALK_WIDTH


func _build_bridge(from: float, to: float) -> void:
	var span := track.distance_ahead(from, to)
	var edge := _edge()
	root.add_child(_beam("Deck", from, span, -edge, edge, 0.0, -DECK_DEPTH, concrete, false))
	for side in [1.0, -1.0]:
		var inner: float = side * (edge - 0.35)
		var outer: float = side * edge
		root.add_child(
			_beam(
				"Barrier",
				from,
				span,
				minf(inner, outer),
				maxf(inner, outer),
				BARRIER_HEIGHT + 0.12,
				0.0,
				concrete,
				true
			)
		)
	var o := PIER_SPACING / 2.0
	while o < span:
		var at := from + o
		for side in [1.0, -1.0]:
			_pier(at, side * (track.half_width() - 1.0))
		o += PIER_SPACING
	if map.bridge_style == "suspension":
		_suspension(from, span)
	else:
		_arches(from, span)


## A solid beam following the road between two lateral offsets, from
## [param top] down to [param bottom] relative to the road surface.
func _beam(
	beam_name: String,
	from: float,
	span: float,
	lat_a: float,
	lat_b: float,
	top: float,
	bottom: float,
	material: Material,
	collide: bool
) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	var o := 0.0
	while o < span:
		var step := minf(2.0, span - o)
		var a := from + o
		var b := a + step
		var pa := track.position_at(a)
		var pb := track.position_at(b)
		var ra := track.right_at(a)
		var rb := track.right_at(b)
		var quads := [
			[lat_a, top, lat_b, top],
			[lat_a, bottom, lat_b, bottom],
			[lat_a, top, lat_a, bottom],
			[lat_b, top, lat_b, bottom],
		]
		for q in quads:
			var a0: Vector3 = pa + ra * q[0] + Vector3.UP * q[1]
			var a1: Vector3 = pa + ra * q[2] + Vector3.UP * q[3]
			var b0: Vector3 = pb + rb * q[0] + Vector3.UP * q[1]
			var b1: Vector3 = pb + rb * q[2] + Vector3.UP * q[3]
			for v in [a0, b0, a1, a1, b0, b1]:
				st.add_vertex(v)
				if collide:
					barrier_faces.append(v)
		o += step
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = beam_name
	instance.mesh = st.commit()
	instance.material_override = material
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	return instance


func _pier(offset: float, lateral: float) -> void:
	var top := track.position_at(offset) + track.right_at(offset) * lateral
	top.y -= DECK_DEPTH
	var height := top.y - map.river_bed
	if height <= 0.5:
		return
	var pier := MeshInstance3D.new()
	pier.name = "Pier"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.9
	mesh.bottom_radius = 1.2
	mesh.height = height
	mesh.material = concrete
	pier.mesh = mesh
	pier.position = top - Vector3.UP * height / 2.0
	root.add_child(pier)


func _suspension(from: float, span: float) -> void:
	var edge := _edge() + 0.8
	var towers := [from + span * 0.22, from + span * 0.78]
	for side in [1.0, -1.0]:
		var lateral: float = side * edge
		var tops: Array[Vector3] = []
		for t in towers:
			var base := track.position_at(t) + track.right_at(t) * lateral
			var leg := MeshInstance3D.new()
			leg.name = "TowerLeg"
			var mesh := BoxMesh.new()
			var height := TOWER_HEIGHT + (base.y - map.river_bed)
			mesh.size = Vector3(1.8, height, 1.8)
			mesh.material = stone if map.bridge_style == "suspension" and not map.night else steel
			leg.mesh = mesh
			leg.position = Vector3(base.x, map.river_bed + height / 2.0, base.z)
			root.add_child(leg)
			tops.append(Vector3(base.x, base.y + TOWER_HEIGHT, base.z))
		# Main cable: anchors at the deck ends, up over the towers, sagging between.
		var start := track.position_at(from) + track.right_at(from) * lateral + Vector3.UP
		var end := (
			track.position_at(from + span) + track.right_at(from + span) * lateral + Vector3.UP
		)
		var points: Array[Vector3] = [start, tops[0]]
		for i in range(1, 12):
			var t := i / 12.0
			var p: Vector3 = tops[0].lerp(tops[1], t)
			p.y -= TOWER_HEIGHT * 0.8 * (1.0 - pow(2.0 * t - 1.0, 2.0))
			points.append(p)
		points.append(tops[1])
		points.append(end)
		for i in points.size() - 1:
			_rod(points[i], points[i + 1], 0.35, "cable")
		# Vertical hangers from the cable down to the deck.
		for i in range(1, points.size() - 1):
			var p := points[i]
			var deck := track.position_at(track.closest_offset(p))
			deck = deck + track.right_at(track.closest_offset(p)) * lateral
			if p.y - deck.y > 1.5:
				_rod(p, Vector3(p.x, deck.y + 1.0, p.z), 0.12, "cable")
	for t in towers:
		var a := track.position_at(t) + track.right_at(t) * edge
		var b := track.position_at(t) - track.right_at(t) * edge
		_rod(a + Vector3.UP * TOWER_HEIGHT, b + Vector3.UP * TOWER_HEIGHT, 1.4, "tower_beam")


func _arches(from: float, span: float) -> void:
	for side in [1.0, -1.0]:
		var lateral: float = side * (track.half_width() - 1.0)
		var previous := Vector3.ZERO
		var count := 16
		for i in count + 1:
			var t := float(i) / count
			var o := from + span * t
			var deck := track.position_at(o) + track.right_at(o) * lateral
			var rise := (deck.y - DECK_DEPTH - map.river_bed) * pow(sin(PI * t), 0.6)
			var p := Vector3(deck.x, map.river_bed + rise, deck.z)
			if i > 0:
				_rod(previous, p, 1.1, "arch")
			# Spandrel columns from the arch up to the deck.
			if i % 2 == 0 and deck.y - DECK_DEPTH - p.y > 0.8:
				_rod(p, Vector3(p.x, deck.y - DECK_DEPTH, p.z), 0.6, "arch")
			previous = p


## Queues a box-shaped rod from [param a] to [param b] for MultiMesh batching.
func _rod(a: Vector3, b: Vector3, thickness: float, kind: String) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var dir := (b - a) / length
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up).scaled(Vector3(thickness, thickness, length))
	if not _rods.has(kind):
		_rods[kind] = []
	_rods[kind].append(Transform3D(basis, (a + b) / 2.0))


func _finish() -> void:
	var materials := {"cable": steel, "tower_beam": stone, "arch": stone}
	for kind in _rods:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		mesh.material = materials[kind]
		var transforms: Array[Transform3D] = []
		transforms.assign(_rods[kind])
		root.add_child(CityBuilder._multimesh("Rods_" + kind, mesh, transforms))
	if not barrier_faces.is_empty():
		var body := StaticBody3D.new()
		body.name = "BarrierCollision"
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = true
		concave.set_faces(barrier_faces)
		shape.shape = concave
		body.add_child(shape)
		root.add_child(body)


func rod_count() -> int:
	var count := 0
	for kind in _rods:
		count += _rods[kind].size()
	return count
