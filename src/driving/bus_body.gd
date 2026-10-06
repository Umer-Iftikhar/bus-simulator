class_name BusBody
extends Node3D
## Visual shell of a bus, built from thin panels so the driver can see out:
## painted lower body and roof, dark pillars, see-through glass all round, and
## an interior (floor, dashboard, steering wheel, seats). Physics uses a
## separate single box on the [Bus]; this node is purely visual.
##
## Local axes match the bus: +Z forward, +Y up, +X the bus's left.

const PANEL := 0.06
const ROOF := 0.14
## Belt line (bottom of the windows) as a fraction of the body height.
const BELT := 0.38
const PILLAR_SPACING := 1.5
const SEAT_PITCH := 0.85

var spec: BusSpec
var clearance := 0.55
var paint_material := StandardMaterial3D.new()
var glass_material := StandardMaterial3D.new()
var trim_material := StandardMaterial3D.new()
var painted: Array[MeshInstance3D] = []
var glass: Array[MeshInstance3D] = []
var seats: MultiMeshInstance3D


static func create(bus_spec: BusSpec, body_clearance: float) -> BusBody:
	var body := BusBody.new()
	body.name = "BodyMesh"
	body.spec = bus_spec
	body.clearance = body_clearance
	body._build()
	return body


## Height of the window bottoms (bus-local).
func belt_line() -> float:
	return clearance + (spec.height - clearance) * BELT


func _build() -> void:
	paint_material.metallic = 0.35
	paint_material.roughness = 0.32
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.albedo_color = Color(0.5, 0.58, 0.62, 0.14)
	glass_material.metallic = 0.15
	glass_material.roughness = 0.05
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trim_material.albedo_color = Color(0.06, 0.06, 0.07)
	trim_material.roughness = 0.6
	_build_shell()
	_build_details()
	_build_interior()


func _build_shell() -> void:
	var w := spec.width
	var h := spec.height
	var hl := spec.length / 2.0
	var hw := w / 2.0
	var c := clearance
	var yb := belt_line()
	var window_h := h - ROOF - yb
	var window_y := yb + window_h / 2.0
	var lower_h := yb - c
	var lower_y := c + lower_h / 2.0

	_paint_box(
		"SkirtLeft", Vector3(PANEL, lower_h, spec.length), Vector3(hw - PANEL / 2, lower_y, 0)
	)
	_paint_box(
		"SkirtRight", Vector3(PANEL, lower_h, spec.length), Vector3(-hw + PANEL / 2, lower_y, 0)
	)
	_paint_box("FrontPanel", Vector3(w, lower_h, PANEL), Vector3(0, lower_y, hl - PANEL / 2))
	_paint_box("RearPanel", Vector3(w, lower_h, PANEL), Vector3(0, lower_y, -hl + PANEL / 2))
	_paint_box("Roof", Vector3(w, ROOF, spec.length), Vector3(0, h - ROOF / 2.0, 0))
	if h > 4.0:
		# Double decker: painted band between the decks.
		var band_y := c + (h - c) * 0.56
		for side in [1.0, -1.0]:
			_paint_box(
				"DeckBand",
				Vector3(PANEL + 0.01, 0.32, spec.length),
				Vector3(side * (hw - PANEL / 2), band_y, 0)
			)
		_paint_box(
			"DeckBandFront", Vector3(w, 0.32, PANEL + 0.01), Vector3(0, band_y, hl - PANEL / 2)
		)

	_glass_box(
		"GlassLeft", Vector3(0.02, window_h, spec.length - 0.1), Vector3(hw - 0.03, window_y, 0)
	)
	_glass_box(
		"GlassRight", Vector3(0.02, window_h, spec.length - 0.1), Vector3(-hw + 0.03, window_y, 0)
	)
	_glass_box("Windscreen", Vector3(w - 0.06, window_h, 0.02), Vector3(0, window_y, hl - 0.03))
	_glass_box("RearWindow", Vector3(w - 0.06, window_h, 0.02), Vector3(0, window_y, -hl + 0.03))

	# Pillars: corner posts plus regular posts along both sides.
	for side in [1.0, -1.0]:
		for z in [hl - 0.05, -hl + 0.05]:
			_trim_box(
				"CornerPillar",
				Vector3(0.1, window_h, 0.1),
				Vector3(side * (hw - 0.05), window_y, z)
			)
		var z_pos := hl - 1.6
		while z_pos > -hl + 0.8:
			_trim_box(
				"Pillar",
				Vector3(PANEL + 0.02, window_h, 0.1),
				Vector3(side * (hw - 0.03), window_y, z_pos)
			)
			z_pos -= PILLAR_SPACING


func _build_details() -> void:
	var hw := spec.width / 2.0
	var hl := spec.length / 2.0
	var c := clearance
	for z in [hl + 0.04, -hl - 0.04]:
		_trim_box("Bumper", Vector3(spec.width + 0.04, 0.3, 0.12), Vector3(0, c + 0.15, z))
	var head := _emissive(Color(1.0, 0.98, 0.9), 1.5)
	var tail := _emissive(Color(0.9, 0.05, 0.05), 1.2)
	for side in [1.0, -1.0]:
		_box(
			"HeadlightLens",
			Vector3(0.34, 0.18, 0.03),
			Vector3(side * (hw - 0.45), c + 0.48, hl + 0.01),
			head
		)
		_box(
			"TailLight",
			Vector3(0.18, 0.4, 0.03),
			Vector3(side * (hw - 0.2), c + 0.6, -hl - 0.01),
			tail
		)
	# Destination sign above the windscreen.
	var sign_y := spec.height - ROOF - 0.1
	# A one-sided quad: from inside the cab its back face is culled, so it never
	# blocks the driver's view out of the windscreen.
	var sign := MeshInstance3D.new()
	sign.name = "DestinationSign"
	var quad := QuadMesh.new()
	quad.size = Vector2(spec.width * 0.7, 0.18)
	sign.mesh = quad
	sign.material_override = trim_material
	sign.position = Vector3(0, sign_y, hl + 0.002)
	add_child(sign)
	var label := Label3D.new()
	label.name = "DestinationText"
	label.text = spec.display_name.to_upper()
	label.font_size = 48
	label.pixel_size = 0.0035
	label.modulate = Color(1.0, 0.65, 0.1)
	label.shaded = false
	label.double_sided = false
	label.position = Vector3(0, sign_y, hl + 0.006)
	add_child(label)
	# Roof air-conditioning unit.
	var ac := StandardMaterial3D.new()
	ac.albedo_color = Color(0.8, 0.8, 0.82)
	ac.roughness = 0.5
	_box(
		"AirCon",
		Vector3(spec.width * 0.6, 0.2, spec.length * 0.22),
		Vector3(0, spec.height + 0.1, -0.5),
		ac
	)


func _build_interior() -> void:
	var hw := spec.width / 2.0
	var hl := spec.length / 2.0
	var c := clearance
	var yb := belt_line()
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.22, 0.23, 0.25)
	floor_material.roughness = 0.9
	_box(
		"Floor",
		Vector3(spec.width - 0.12, 0.05, spec.length - 0.12),
		Vector3(0, c + 0.05, 0),
		floor_material
	)
	_trim_box("Dashboard", Vector3(spec.width - 0.15, 0.32, 0.55), Vector3(0, yb - 0.14, hl - 0.34))

	var seat := CameraModes.driver_seat(spec)
	var wheel := MeshInstance3D.new()
	wheel.name = "SteeringWheel"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.17
	torus.outer_radius = 0.21
	torus.material = trim_material
	wheel.mesh = torus
	wheel.position = Vector3(seat.x, seat.y - 0.62, seat.z + 0.42)
	wheel.rotation = Vector3(deg_to_rad(60.0), 0, 0)
	add_child(wheel)

	var fabric := StandardMaterial3D.new()
	fabric.albedo_color = Color(0.12, 0.2, 0.42)
	fabric.roughness = 0.95
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.44, 0.95, 0.42)
	seat_mesh.material = fabric
	_box("DriverSeat", seat_mesh.size, Vector3(seat.x, c + 0.5, seat.z - 0.35), fabric)

	var floors: Array[float] = [c]
	if spec.height > 4.0:
		# Double decker: an upper deck floor with its own rows of seats.
		var upper := c + (spec.height - c) * 0.56 + 0.16
		_box(
			"UpperDeck",
			Vector3(spec.width - 0.12, 0.08, spec.length - 0.5),
			Vector3(0, upper, -0.2),
			floor_material
		)
		floors.append(upper)
	var transforms: Array[Transform3D] = []
	for floor_y in floors:
		var z := seat.z - 1.4
		while z > -hl + 0.5:
			for x in [hw - 0.35, hw - 0.8, -hw + 0.35, -hw + 0.8]:
				transforms.append(Transform3D(Basis(), Vector3(x, floor_y + 0.5, z)))
			z -= SEAT_PITCH
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = seat_mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	seats = MultiMeshInstance3D.new()
	seats.name = "Seats"
	seats.multimesh = multimesh
	add_child(seats)


func _box(box_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance


func _paint_box(box_name: String, size: Vector3, at: Vector3) -> void:
	painted.append(_box(box_name, size, at, paint_material))


func _glass_box(box_name: String, size: Vector3, at: Vector3) -> void:
	var pane := _box(box_name, size, at, glass_material)
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.append(pane)


func _trim_box(box_name: String, size: Vector3, at: Vector3) -> void:
	_box(box_name, size, at, trim_material)


static func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
