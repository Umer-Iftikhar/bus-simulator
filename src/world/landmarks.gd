class_name Landmarks
extends RefCounted
## Procedural landmarks that make each city recognisable: an obelisk and a
## domed capitol (Washington), a tent-roofed mosque with four minarets
## (Islamabad), a red lattice tower (Tokyo), an Art Deco spire tower (NYC)
## and a reflecting pool. Each sits on the ground with a collision footprint.

const TYPES := ["obelisk", "capitol", "reflecting_pool", "mosque", "tokyo_tower", "empire"]


static func build(
	type: String, at: Vector2, rotation: float, ground_y: float, night: bool
) -> Node3D:
	var root := StaticBody3D.new()
	root.name = "Landmark_" + type
	root.collision_layer = Layers.WORLD
	root.collision_mask = 0
	root.position = Vector3(at.x, ground_y, at.y)
	root.rotation.y = rotation
	match type:
		"obelisk":
			_obelisk(root)
		"capitol":
			_capitol(root)
		"reflecting_pool":
			_pool(root)
		"mosque":
			_mosque(root)
		"tokyo_tower":
			_tokyo_tower(root, night)
		"empire":
			_empire(root, night)
	return root


static func _mat(color: Color, roughness := 0.6, emission := 0.0) -> StandardMaterial3D:
	var material := (
		WorldLook.glow(color, emission) if emission > 0.0 else WorldLook.plain(color, roughness)
	)
	return material


static func _add(
	parent: Node3D, mesh: PrimitiveMesh, at: Vector3, material: Material
) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)
	return instance


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _frustum(bottom: float, top: float, height: float, sides := 4) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


static func _collider(parent: Node3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	parent.add_child(shape)


static func _obelisk(root: Node3D) -> void:
	var marble := _mat(Color(0.95, 0.94, 0.9), 0.5)
	_add(root, _box(Vector3(14, 2, 14)), Vector3(0, 1, 0), marble)
	var shaft := _add(root, _frustum(5.5, 3.8, 88.0), Vector3(0, 46, 0), marble)
	shaft.rotation.y = PI / 4.0
	var tip := _add(root, _frustum(3.8, 0.0, 6.0), Vector3(0, 93, 0), marble)
	tip.rotation.y = PI / 4.0
	_collider(root, Vector3(9, 96, 9))


static func _capitol(root: Node3D) -> void:
	var marble := _mat(Color(0.96, 0.95, 0.92), 0.5)
	_add(root, _box(Vector3(110, 22, 34)), Vector3(0, 11, 0), marble)
	_add(root, _box(Vector3(46, 8, 40)), Vector3(0, 26, 0), marble)
	var drum := CylinderMesh.new()
	drum.top_radius = 15.0
	drum.bottom_radius = 15.0
	drum.height = 14.0
	_add(root, drum, Vector3(0, 37, 0), marble)
	var dome := SphereMesh.new()
	dome.radius = 15.5
	dome.height = 24.0
	dome.is_hemisphere = true
	_add(root, dome, Vector3(0, 44, 0), marble)
	_add(root, _frustum(2.5, 2.5, 7.0, 12), Vector3(0, 59, 0), marble)
	var column := CylinderMesh.new()
	column.top_radius = 0.9
	column.bottom_radius = 1.0
	column.height = 16.0
	for i in 12:
		_add(root, column.duplicate(), Vector3(-22 + i * 4.0, 8, 19), marble)
	_collider(root, Vector3(110, 60, 40))


static func _pool(root: Node3D) -> void:
	var stone := _mat(Color(0.75, 0.73, 0.68), 0.9)
	_add(root, _box(Vector3(140, 0.5, 26)), Vector3(0, 0.25, 0), stone)
	var water := WorldLook.water()
	_add(root, _box(Vector3(136, 0.1, 22)), Vector3(0, 0.55, 0), water)


static func _mosque(root: Node3D) -> void:
	var marble := _mat(Color(0.96, 0.96, 0.95), 0.4)
	var gold := _mat(Color(0.85, 0.7, 0.3), 0.3)
	_add(root, _box(Vector3(130, 1.5, 130)), Vector3(0, 0.75, 0), _mat(Color(0.82, 0.8, 0.76), 0.8))
	# Faisal Mosque's prayer hall: a tall eight-sided tent shape.
	var hall := _add(root, _frustum(32.0, 0.0, 42.0, 8), Vector3(0, 22.5, 0), marble)
	hall.rotation.y = PI / 8.0
	_add(root, _frustum(1.0, 0.0, 4.0, 8), Vector3(0, 45.5, 0), gold)
	for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var at := Vector3(corner.x * 48.0, 0, corner.y * 48.0)
		var minaret := CylinderMesh.new()
		minaret.top_radius = 1.4
		minaret.bottom_radius = 2.0
		minaret.height = 80.0
		minaret.radial_segments = 12
		_add(root, minaret, at + Vector3(0, 40.0, 0), marble)
		_add(root, _frustum(1.6, 0.0, 7.0, 12), at + Vector3(0, 83.5, 0), marble)
		_add(root, _frustum(2.6, 2.6, 1.2, 12), at + Vector3(0, 66.0, 0), marble)
	_collider(root, Vector3(70, 45, 70))


static func _tokyo_tower(root: Node3D, night: bool) -> void:
	var red := _mat(Color(0.9, 0.25, 0.08), 0.5, 1.6 if night else 0.0)
	var white := _mat(Color(0.95, 0.95, 0.95), 0.5, 1.2 if night else 0.0)
	var sections := [
		[24.0, 14.0, 40.0, red],
		[14.0, 8.5, 34.0, white],
		[8.5, 5.0, 30.0, red],
		[5.0, 2.8, 24.0, white],
		[2.8, 1.2, 22.0, red],
	]
	var y := 0.0
	for s in sections:
		var piece := _add(root, _frustum(s[0], s[1], s[2]), Vector3(0, y + s[2] / 2.0, 0), s[3])
		piece.rotation.y = PI / 4.0
		y += s[2]
	_add(root, _box(Vector3(17, 6, 17)), Vector3(0, 62, 0), white)
	_add(root, _box(Vector3(9, 4, 9)), Vector3(0, 116, 0), white)
	_add(root, _frustum(0.5, 0.1, 28.0, 6), Vector3(0, y + 14.0, 0), red)
	_collider(root, Vector3(30, 60, 30))


static func _empire(root: Node3D, night: bool) -> void:
	var stone := _mat(Color(0.7, 0.68, 0.62), 0.7)
	var tiers := [[52.0, 70.0], [40.0, 110.0], [30.0, 80.0], [20.0, 40.0], [12.0, 20.0]]
	var y := 0.0
	for tier in tiers:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(tier[0], tier[1], tier[0] * 0.7)
		var facade := ShaderMaterial.new()
		facade.shader = WorldLook.BUILDING_SHADER
		facade.set_shader_parameter("night", 1.0 if night else 0.0)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = facade
		instance.set_instance_shader_parameter("wall_color", Color(0.72, 0.7, 0.64))
		instance.position.y = y + tier[1] / 2.0
		root.add_child(instance)
		y += tier[1]
	_add(root, _frustum(3.0, 0.4, 45.0, 8), Vector3(0, y + 22.5, 0), stone)
	_collider(root, Vector3(52, y, 36))
