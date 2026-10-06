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
const PILLAR_SPACING := 1.5
const SEAT_PITCH := 0.85
const WINDSCREEN_BELOW_EYE := 0.85
## Cockpit layout relative to the driver's eye (metres).
const DASH_BELOW_EYE := 0.5
const DASH_AHEAD_OF_EYE := 0.62
const WHEEL_BELOW_EYE := 0.5
const WHEEL_AHEAD_OF_EYE := 0.5
const SPEEDO_MAX_KMH := 120.0
## Steering wheel turns per side at full lock.
const WHEEL_LOCK_TURNS := 0.4

var spec: BusSpec
var clearance := 0.55
var paint_material := StandardMaterial3D.new()
var glass_material := StandardMaterial3D.new()
## The windscreen is never tinted (legal requirement, and the driver must see out).
var windscreen_material := StandardMaterial3D.new()
var trim_material := StandardMaterial3D.new()
var painted: Array[MeshInstance3D] = []
var glass: Array[MeshInstance3D] = []
var seats: MultiMeshInstance3D
var roof: MeshInstance3D
var roof_material := StandardMaterial3D.new()
var stripe_material := StandardMaterial3D.new()
var stripes: Array[MeshInstance3D] = []
var head_material := _emissive(Color(1.0, 0.98, 0.9), 0.6)
var tail_material := _emissive(Color(0.9, 0.05, 0.05), 0.4)
var reverse_material := _emissive(Color(1.0, 1.0, 1.0), 0.0)
var gauge_glow := _emissive(Color(0.08, 0.09, 0.1), 0.2)
var gauge_ring := _emissive(Color(0.9, 0.9, 0.85), 0.8)
var arrow_off := _emissive(Color(0.05, 0.25, 0.05), 0.0)
var arrow_on := _emissive(Color(0.2, 1.0, 0.2), 3.0)
## Rotates with the steering input (spins around its local Z axis).
var steering_wheel: Node3D
var speed_needle: Node3D
var rpm_needle: Node3D
var dash_arrows := {}
var gear_label: Label3D
var cabin_light: OmniLight3D


static func create(bus_spec: BusSpec, body_clearance: float) -> BusBody:
	var body := BusBody.new()
	body.name = "BodyMesh"
	body.spec = bus_spec
	body.clearance = body_clearance
	body._build()
	return body


## Height of the window bottoms (bus-local).
func belt_line() -> float:
	return clearance + (spec.height - clearance) * spec.belt_fraction()


## Z of the cab front (the windscreen base); behind the bonnet on a minibus.
func front_z() -> float:
	return spec.length / 2.0 - spec.cab_offset()


## Bottom of the windscreen: never above the side windows, and always well
## below the driver's eye so the road just ahead stays visible (deep
## windscreens, even on a double decker).
func windscreen_bottom() -> float:
	return minf(belt_line(), CameraModes.driver_seat(spec).y - WINDSCREEN_BELOW_EYE)


func _build() -> void:
	paint_material.metallic = 0.35
	paint_material.roughness = 0.32
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_material.albedo_color = Color(0.5, 0.58, 0.62, 0.14)
	glass_material.metallic = 0.15
	glass_material.roughness = 0.05
	glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	windscreen_material = glass_material.duplicate()
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
	var front := front_z()
	var window_h := h - ROOF - yb
	var window_y := yb + window_h / 2.0
	var lower_h := yb - c
	var lower_y := c + lower_h / 2.0
	var cabin_length := front + hl
	var cabin_mid := (front - hl) / 2.0

	_paint_box(
		"SkirtLeft", Vector3(PANEL, lower_h, spec.length), Vector3(hw - PANEL / 2, lower_y, 0)
	)
	_paint_box(
		"SkirtRight", Vector3(PANEL, lower_h, spec.length), Vector3(-hw + PANEL / 2, lower_y, 0)
	)
	var wb := windscreen_bottom()
	if spec.cab_offset() > 0.0:
		# Van-style bonnet: grille at the very front, bonnet up to the belt line.
		_paint_box("FrontPanel", Vector3(w, yb - c, PANEL), Vector3(0, lower_y, hl - PANEL / 2))
		_paint_box(
			"Hood",
			Vector3(w, 0.08, spec.cab_offset()),
			Vector3(0, yb - 0.04, hl - spec.cab_offset() / 2.0)
		)
		_trim_box("Grille", Vector3(w * 0.55, 0.28, 0.02), Vector3(0, c + 0.55, hl + 0.005))
		_paint_box(
			"CabFront", Vector3(w, wb - c, PANEL), Vector3(0, (c + wb) / 2.0, front - PANEL / 2)
		)
	else:
		_paint_box(
			"FrontPanel", Vector3(w, wb - c, PANEL), Vector3(0, (c + wb) / 2.0, hl - PANEL / 2)
		)
	var rear_height := h - c if spec.style == "coach" else lower_h
	_paint_box(
		"RearPanel",
		Vector3(w, rear_height, PANEL),
		Vector3(0, c + rear_height / 2.0, -hl + PANEL / 2)
	)
	roof = _paint_box_ret(
		"Roof", Vector3(w, ROOF, cabin_length), Vector3(0, h - ROOF / 2.0, cabin_mid)
	)
	if spec.style == "double_decker":
		var band_y := c + (h - c) * 0.56
		for side in [1.0, -1.0]:
			_paint_box(
				"DeckBand",
				Vector3(PANEL + 0.01, 0.32, spec.length),
				Vector3(side * (hw - PANEL / 2), band_y, 0)
			)
		_paint_box(
			"DeckBandFront", Vector3(w, 0.32, PANEL + 0.01), Vector3(0, band_y, front - PANEL / 2)
		)
	if spec.style == "coach":
		# Luggage bay doors along the lower sides.
		for side in [1.0, -1.0]:
			var z := -hl + 1.6
			var bay := 0
			while z < front - 2.5:
				_trim_box(
					"LuggageDoor%d" % bay,
					Vector3(0.015, lower_h * 0.62, 0.03),
					Vector3(side * (hw + 0.008), c + lower_h * 0.42, z)
				)
				z += 1.9
				bay += 1

	var glass_length := cabin_length - 0.1
	_glass_box(
		"GlassLeft", Vector3(0.02, window_h, glass_length), Vector3(hw - 0.03, window_y, cabin_mid)
	)
	_glass_box(
		"GlassRight",
		Vector3(0.02, window_h, glass_length),
		Vector3(-hw + 0.03, window_y, cabin_mid)
	)
	var screen_h := h - ROOF - wb
	var rake := spec.windscreen_rake()
	var screen := _glass_box_ret(
		"Windscreen",
		Vector3(w - 0.06, screen_h / cos(rake), 0.02),
		Vector3(0, wb + screen_h / 2.0, front - 0.03 - screen_h / 2.0 * tan(rake))
	)
	screen.rotation.x = -rake
	screen.material_override = windscreen_material
	if spec.style != "coach":
		_glass_box(
			"RearWindow", Vector3(w - 0.06, window_h, 0.02), Vector3(0, window_y, -hl + 0.03)
		)

	# Pillars: corner posts plus regular posts along both sides.
	for side in [1.0, -1.0]:
		for z in [front - 0.05, -hl + 0.05]:
			_trim_box(
				"CornerPillar",
				Vector3(0.1, window_h, 0.1),
				Vector3(side * (hw - 0.05), window_y, z)
			)
		var z_pos := front - 1.6
		while z_pos > -hl + 0.8:
			_trim_box(
				"Pillar",
				Vector3(PANEL + 0.02, window_h, 0.1),
				Vector3(side * (hw - 0.03), window_y, z_pos)
			)
			z_pos -= PILLAR_SPACING
	# Livery stripe just below the windows (hidden until bought).
	var stripe_y := yb - 0.18
	for side in [1.0, -1.0]:
		_stripe_box(
			"StripeSide",
			Vector3(0.012, 0.16, spec.length),
			Vector3(side * (hw + 0.006), stripe_y, 0)
		)
	_stripe_box(
		"StripeFront", Vector3(w, 0.16, 0.012), Vector3(0, minf(stripe_y, wb - 0.12), hl + 0.006)
	)


func _build_details() -> void:
	var hw := spec.width / 2.0
	var hl := spec.length / 2.0
	var c := clearance
	for z in [hl + 0.04, -hl - 0.04]:
		_trim_box("Bumper", Vector3(spec.width + 0.04, 0.3, 0.12), Vector3(0, c + 0.15, z))
	var head := head_material
	var tail := tail_material
	for side in [1.0, -1.0]:
		_box(
			"ReverseLight",
			Vector3(0.14, 0.12, 0.03),
			Vector3(side * (hw - 0.45), c + 0.6, -hl - 0.01),
			reverse_material
		)
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
	sign.position = Vector3(0, sign_y, front_z() + 0.002)
	add_child(sign)
	var label := Label3D.new()
	label.name = "DestinationText"
	label.text = spec.display_name.to_upper()
	label.font_size = 48
	label.pixel_size = 0.0035
	label.modulate = Color(1.0, 0.65, 0.1)
	label.shaded = false
	label.double_sided = false
	label.position = Vector3(0, sign_y, front_z() + 0.006)
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
	var seat := CameraModes.driver_seat(spec)
	_build_cockpit(seat, yb)

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


## Dashboard, gauge cluster and steering wheel, raised into the driver's
## lower field of view so they are visible from the driver's-seat camera.
func _build_cockpit(eye: Vector3, yb: float) -> void:
	var hl := spec.length / 2.0
	var dash_top := eye.y - DASH_BELOW_EYE
	var dash_back := eye.z + DASH_AHEAD_OF_EYE
	var dash_front := front_z() - 0.12
	var dash_bottom := yb - 0.3
	var dash := StandardMaterial3D.new()
	dash.albedo_color = Color(0.13, 0.13, 0.14)
	dash.roughness = 0.75
	_box(
		"Dashboard",
		Vector3(spec.width - 0.15, dash_top - dash_bottom, dash_front - dash_back),
		Vector3(0, (dash_top + dash_bottom) / 2.0, (dash_front + dash_back) / 2.0),
		dash
	)
	# Instrument cluster: a hooded panel facing the driver.
	var cluster := Node3D.new()
	cluster.name = "Cluster"
	add_child(cluster)
	cluster.position = Vector3(eye.x, dash_top + 0.1, dash_back + 0.12)
	_face(cluster, eye)
	var panel := _child_box(cluster, "ClusterPanel", Vector3(0.44, 0.17, 0.04), Vector3.ZERO, dash)
	panel.position.z = 0.02
	speed_needle = _gauge(cluster, "Speedometer", Vector3(-0.11, 0.0, 0.0))
	rpm_needle = _gauge(cluster, "Tachometer", Vector3(0.11, 0.0, 0.0))
	for side in ["left", "right"]:
		var x := -0.035 if side == "left" else 0.035
		var arrow := _child_box(
			cluster,
			"DashArrow_" + side,
			Vector3(0.025, 0.018, 0.01),
			Vector3(x, 0.06, -0.01),
			arrow_off
		)
		dash_arrows[side] = arrow
	gear_label = Label3D.new()
	gear_label.name = "GearDisplay"
	gear_label.text = "D"
	gear_label.font_size = 64
	gear_label.pixel_size = 0.0005
	gear_label.modulate = Color(1.0, 0.6, 0.1)
	gear_label.shaded = false
	gear_label.double_sided = false
	gear_label.position = Vector3(0, -0.045, -0.012)
	gear_label.rotation = Vector3(0, PI, 0)
	cluster.add_child(gear_label)
	# Steering wheel on its column, between the driver and the cluster.
	var column := Node3D.new()
	column.name = "SteeringColumn"
	add_child(column)
	column.position = Vector3(eye.x, eye.y - WHEEL_BELOW_EYE, eye.z + WHEEL_AHEAD_OF_EYE)
	_face(column, eye)
	steering_wheel = Node3D.new()
	steering_wheel.name = "SteeringWheel"
	column.add_child(steering_wheel)
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.215
	torus.material = trim_material
	rim.mesh = torus
	rim.rotation = Vector3(PI / 2.0, 0, 0)
	steering_wheel.add_child(rim)
	for angle in [0.0, PI / 2.0, PI]:
		var spoke := _child_box(
			steering_wheel, "Spoke", Vector3(0.19, 0.03, 0.02), Vector3.ZERO, trim_material
		)
		spoke.rotation = Vector3(0, 0, angle)
		spoke.position = Vector3(cos(angle), sin(angle), 0) * -0.095
	var hub := _child_box(steering_wheel, "Hub", Vector3(0.09, 0.09, 0.05), Vector3.ZERO, dash)
	hub.position.z = 0.01
	_child_box(column, "Column", Vector3(0.06, 0.06, 0.35), Vector3(0, 0, 0.2), trim_material)
	cabin_light = OmniLight3D.new()
	cabin_light.name = "CabinLight"
	cabin_light.position = Vector3(0, spec.height - ROOF - 0.15, 0)
	cabin_light.omni_range = spec.length * 0.6
	cabin_light.light_energy = 0.7
	cabin_light.light_color = Color(1.0, 0.95, 0.85)
	cabin_light.shadow_enabled = false
	cabin_light.visible = false
	add_child(cabin_light)


## A round gauge (dial + needle) in [param parent]'s XY plane. Returns the needle pivot.
func _gauge(parent: Node3D, gauge_name: String, at: Vector3) -> Node3D:
	var dial := MeshInstance3D.new()
	dial.name = gauge_name
	var disc := CylinderMesh.new()
	disc.top_radius = 0.06
	disc.bottom_radius = 0.06
	disc.height = 0.01
	disc.material = gauge_glow
	dial.mesh = disc
	dial.rotation = Vector3(PI / 2.0, 0, 0)
	dial.position = at
	parent.add_child(dial)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.058
	torus.outer_radius = 0.066
	torus.material = gauge_ring
	ring.mesh = torus
	ring.rotation = Vector3(PI / 2.0, 0, 0)
	ring.position = at + Vector3(0, 0, -0.006)
	parent.add_child(ring)
	var pivot := Node3D.new()
	pivot.name = gauge_name + "Needle"
	pivot.position = at + Vector3(0, 0, -0.01)
	parent.add_child(pivot)
	var needle_material := _emissive(Color(1.0, 0.25, 0.1), 1.5)
	_child_box(pivot, "Needle", Vector3(0.008, 0.05, 0.004), Vector3(0, 0.025, 0), needle_material)
	return pivot


## Points [param node]'s -Z axis at [param target] (both bus-local).
static func _face(node: Node3D, target: Vector3) -> void:
	node.transform = Transform3D(Basis(), node.position).looking_at(target, Vector3.UP)


func _child_box(
	parent: Node3D, box_name: String, size: Vector3, at: Vector3, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance


## Live dashboard: speedometer, rev counter, steering wheel, indicator arrows, gear.
func update_dashboard(
	speed_kmh: float, steer: float, throttle: float, left_on: bool, right_on: bool, reverse: bool
) -> void:
	speed_needle.rotation.z = needle_angle(speed_kmh / SPEEDO_MAX_KMH)
	var revs := clampf(0.25 + throttle * 0.45 + speed_kmh / SPEEDO_MAX_KMH * 0.3, 0.0, 1.0)
	rpm_needle.rotation.z = needle_angle(revs)
	steering_wheel.rotation.z = -steer * WHEEL_LOCK_TURNS * TAU
	(dash_arrows["left"] as MeshInstance3D).material_override = arrow_on if left_on else arrow_off
	(dash_arrows["right"] as MeshInstance3D).material_override = arrow_on if right_on else arrow_off
	gear_label.text = "R" if reverse else "D"


## Needle rotation for a 0..1 reading: sweeps 270 degrees clockwise.
static func needle_angle(fraction: float) -> float:
	return deg_to_rad(135.0) - clampf(fraction, 0.0, 1.0) * deg_to_rad(270.0)


## Exterior and cabin lights. [param braking]/[param reverse] drive the rear lamps.
func set_lights(headlights_on: bool, braking: bool, reverse: bool) -> void:
	head_material.emission_energy_multiplier = 4.0 if headlights_on else 0.6
	var tail_energy := 0.4
	if headlights_on:
		tail_energy = 1.5
	if braking:
		tail_energy = 6.0
	tail_material.emission_energy_multiplier = tail_energy
	reverse_material.emission_energy_multiplier = 5.0 if reverse else 0.0
	reverse_material.albedo_color = Color(1, 1, 1) if reverse else Color(0.6, 0.6, 0.6)
	gauge_glow.emission_energy_multiplier = 1.2 if headlights_on else 0.4
	cabin_light.visible = headlights_on


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


func _paint_box_ret(box_name: String, size: Vector3, at: Vector3) -> MeshInstance3D:
	var instance := _box(box_name, size, at, paint_material)
	painted.append(instance)
	return instance


func _glass_box_ret(box_name: String, size: Vector3, at: Vector3) -> MeshInstance3D:
	_glass_box(box_name, size, at)
	return glass[-1]


func _stripe_box(box_name: String, size: Vector3, at: Vector3) -> void:
	var stripe := _box(box_name, size, at, stripe_material)
	stripe.visible = false
	stripes.append(stripe)


## Livery stripe colour, or null for none.
func set_stripe(color: Variant) -> void:
	for stripe in stripes:
		stripe.visible = color != null
	if color != null:
		stripe_material.albedo_color = color
		stripe_material.metallic = 0.3
		stripe_material.roughness = 0.35


## Roof colour, or null to match the body paint.
func set_roof(color: Variant) -> void:
	if color == null:
		roof.material_override = paint_material
		return
	roof_material.albedo_color = color
	roof_material.roughness = 0.4
	roof.material_override = roof_material


## Window tint: higher [param darkness] (0..1) makes glass darker and more opaque.
func set_tint(darkness: float) -> void:
	var d := clampf(darkness, 0.0, 1.0)
	glass_material.albedo_color = Color(0.5, 0.58, 0.62, 0.14).lerp(Color(0.04, 0.05, 0.06, 0.6), d)


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
