class_name Bus
extends VehicleBody3D
## The player's bus. Built procedurally from a [BusSpec]; driven through
## [method set_command] so keyboard, touch and tests all share one path.
##
## Local axes: +Z is forward, +Y is up, +X is the bus's left-hand side.

signal command_changed
## A collision this physics step: [param part] is a [DamageModel] part name and
## [param impact_speed] the velocity change (m/s) it caused.
signal impact(part: String, impact_speed: float)
signal gear_changed(reverse: bool)

const WHEEL_RADIUS := 0.5
const SUSPENSION_REST := 0.4
const BODY_CLEARANCE := 0.55
## Low centre of mass: engine, chassis and batteries sit under the floor.
const CENTER_OF_MASS_HEIGHT := 0.25
## Largest acceleration normal driving can produce (hard braking, full-lock
## turns); velocity changes beyond this between steps are collisions.
const MAX_DRIVING_ACCEL := 14.0
## How far the side mirror heads stick out beyond the body.
const MIRROR_REACH := 0.35
const MIRROR_HEAD := Vector3(0.12, 0.42, 0.26)
const DOOR_WIDTH := 1.1
const DOOR_TRAVEL := 1.05
const DOOR_TIME := 0.4
## Light switch positions, cycled by L / the LIGHT button.
const LIGHTS_OFF := 0
const LOW_BEAM := 1
const HIGH_BEAM := 2

var spec: BusSpec
var input := DriveInput.new()
## Multiplier on top speed from upgrades (1.0 = stock).
var top_speed_factor := 1.0
## Multiplier on top speed from damage (1.0 = undamaged).
var damage_speed_factor := 1.0
## Multiplier on engine force (acceleration upgrades).
var acceleration_factor := 1.0
## Multiplier on brake force (brake upgrades).
var brake_factor := 1.0
## Multiplier on steering speed (handling upgrades).
var handling_factor := 1.0
## When false the bus ignores commands and holds the brakes (e.g. bus wrecked, run over).
var controls_enabled := true
## Visual shell (panels, glass, interior).
var body: BusBody
## Shared by every wheel hub so a rim upgrade updates all four.
var rim_material := StandardMaterial3D.new()
## Gearbox: false = Drive, true = Reverse.
var reverse_gear := false
## Headlamp setting: [constant LIGHTS_OFF], [constant LOW_BEAM] or [constant HIGH_BEAM].
var light_mode := LIGHTS_OFF
var headlights_on: bool:
	get:
		return light_mode != LIGHTS_OFF
## Indicator lamp state mirrored on the dashboard (set by the session).
var dash_left := false
var dash_right := false
## DamageModel mirror part -> MeshInstance3D showing the mirror glass.
var mirror_glass := {}
var doors_open := false
var door: MeshInstance3D
var headlights: Array[SpotLight3D] = []

var _target_throttle := 0.0
var _target_brake := 0.0
var _target_steer := 0.0
var _paint := Color.WHITE
var _wear := 0.0
var _last_velocity := Vector3.ZERO
var _lamps := {}
var _mirror_sensors := {}
var _panel_overlays := {}


static func create(bus_spec: BusSpec) -> Bus:
	var bus := Bus.new()
	bus.spec = bus_spec
	bus.name = "Bus"
	bus._build()
	return bus


func _build() -> void:
	mass = spec.mass
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.TRAFFIC
	contact_monitor = true
	max_contacts_reported = 8
	can_sleep = false
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, CENTER_OF_MASS_HEIGHT, 0)
	angular_damp = 1.0

	var body_height := spec.height - BODY_CLEARANCE
	var shape := CollisionShape3D.new()
	shape.name = "Hull"
	var box := BoxShape3D.new()
	box.size = Vector3(spec.width, body_height, spec.length)
	shape.shape = box
	shape.position = Vector3(0, BODY_CLEARANCE + body_height / 2.0, 0)
	add_child(shape)

	set_rims(Color(0.75, 0.76, 0.78), 0.8, 0.3)
	body = BusBody.create(spec, BODY_CLEARANCE)
	add_child(body)
	set_paint(spec.color)

	_build_lamps()
	_build_mirrors()
	_build_door(body_height)
	_build_headlights()
	_build_panel_overlays(body_height)

	var half_track := spec.width / 2.0 - 0.15
	var axle := spec.wheelbase() / 2.0
	var attach_y := WHEEL_RADIUS + SUSPENSION_REST - 0.12
	_add_wheel("WheelFL", Vector3(half_track, attach_y, axle), true, false)
	_add_wheel("WheelFR", Vector3(-half_track, attach_y, axle), true, false)
	_add_wheel("WheelRL", Vector3(half_track, attach_y, -axle), false, true)
	_add_wheel("WheelRR", Vector3(-half_track, attach_y, -axle), false, true)


## Front passenger door on the kerb (right, -X) side; it slides back to open.
func _build_door(body_height: float) -> void:
	door = MeshInstance3D.new()
	door.name = "Door"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, body_height * 0.8, DOOR_WIDTH)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.25, 0.3)
	material.metallic = 0.4
	mesh.material = material
	door.mesh = mesh
	door.position = door_closed_position()
	add_child(door)


func door_closed_position() -> Vector3:
	var body_height := spec.height - BODY_CLEARANCE
	return Vector3(
		-spec.width / 2.0 - 0.04,
		BODY_CLEARANCE + body_height * 0.42,
		spec.length / 2.0 - spec.cab_offset() - 0.6 - DOOR_WIDTH / 2.0
	)


func door_open_position() -> Vector3:
	return door_closed_position() + Vector3(-0.08, 0.0, -DOOR_TRAVEL)


func open_doors() -> void:
	_move_door(true)


func close_doors() -> void:
	_move_door(false)


func _move_door(open: bool) -> void:
	if doors_open == open:
		return
	doors_open = open
	var target := door_open_position() if open else door_closed_position()
	if not is_inside_tree():
		door.position = target
		return
	var tween := create_tween()
	tween.tween_property(door, "position", target, DOOR_TIME)


func _build_headlights() -> void:
	for side in [1.0, -1.0]:
		var lamp := SpotLight3D.new()
		lamp.name = "Headlight%s" % ("L" if side > 0.0 else "R")
		lamp.position = Vector3(side * (spec.width / 2.0 - 0.35), 0.95, spec.length / 2.0 + 0.05)
		# SpotLight3D shines down its -Z; turn it to face the bus's +Z.
		lamp.rotation = Vector3(beam(LOW_BEAM)["pitch"], PI, 0.0)
		lamp.light_color = Color(1.0, 0.95, 0.85)
		lamp.visible = false
		add_child(lamp)
		headlights.append(lamp)
	set_light_mode(light_mode)


## Spot-lamp settings for a beam: low beam dips toward the road ahead,
## high beam throws a narrower, brighter cone much further.
static func beam(mode: int) -> Dictionary:
	if mode == HIGH_BEAM:
		return {"range": 120.0, "angle": 24.0, "energy": 24.0, "pitch": -0.02}
	return {"range": 65.0, "angle": 38.0, "energy": 12.0, "pitch": -0.12}


func set_light_mode(mode: int) -> void:
	light_mode = clampi(mode, LIGHTS_OFF, HIGH_BEAM)
	var settings := beam(light_mode)
	for lamp in headlights:
		lamp.visible = light_mode != LIGHTS_OFF
		lamp.spot_range = settings["range"]
		lamp.spot_angle = settings["angle"]
		lamp.light_energy = settings["energy"]
		lamp.rotation.x = settings["pitch"]
	_update_lights()


## Off -> low beam -> high beam -> off.
func cycle_lights() -> void:
	set_light_mode((light_mode + 1) % 3)


## Switches to low beam (on) or off.
func set_headlights(on: bool) -> void:
	set_light_mode(LOW_BEAM if on else LIGHTS_OFF)


func toggle_headlights() -> void:
	cycle_lights()


## Shifts between Drive and Reverse. Only allowed when (nearly) stopped;
## returns false and changes nothing otherwise.
func set_reverse(reverse: bool) -> bool:
	if reverse == reverse_gear:
		return true
	if not Drivetrain.can_change_gear(forward_speed()):
		return false
	reverse_gear = reverse
	_update_lights()
	gear_changed.emit(reverse_gear)
	return true


func toggle_gear() -> bool:
	return set_reverse(not reverse_gear)


func is_braking() -> bool:
	return input.brake > 0.05


func _update_lights() -> void:
	body.set_lights(headlights_on, is_braking(), reverse_gear, light_mode == HIGH_BEAM)


## Bus-local centre of a side mirror head ([constant DamageModel.MIRROR_LEFT] or RIGHT).
static func mirror_mount(bus_spec: BusSpec, part: String) -> Vector3:
	var side := 1.0 if part == DamageModel.MIRROR_LEFT else -1.0
	var x := side * (bus_spec.width / 2.0 + MIRROR_REACH - MIRROR_HEAD.x / 2.0)
	var cab_front := bus_spec.length / 2.0 - bus_spec.cab_offset()
	return Vector3(x, bus_spec.height * 0.68, cab_front - 0.35)


## Side mirrors: an arm and head on each front corner, plus a sensor that
## shatters the mirror when it clips something. Mirrors break away rather than
## stopping the bus, so they are Area3D sensors, not solid collision shapes.
func _build_mirrors() -> void:
	var housing := StandardMaterial3D.new()
	housing.albedo_color = Color(0.1, 0.1, 0.1)
	for part in DamageModel.MIRRORS:
		var mount := mirror_mount(spec, part)
		var side := signf(mount.x)
		var arm := MeshInstance3D.new()
		arm.name = "MirrorArm_" + part
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(MIRROR_REACH, 0.05, 0.05)
		arm_mesh.material = housing
		arm.mesh = arm_mesh
		arm.position = Vector3(
			side * (spec.width / 2.0 + MIRROR_REACH / 2.0), mount.y + 0.15, mount.z
		)
		add_child(arm)
		var head := MeshInstance3D.new()
		head.name = "MirrorHead_" + part
		var head_mesh := BoxMesh.new()
		head_mesh.size = MIRROR_HEAD
		head_mesh.material = housing
		head.mesh = head_mesh
		head.position = mount
		add_child(head)
		var glass := MeshInstance3D.new()
		glass.name = "MirrorGlass_" + part
		var quad := QuadMesh.new()
		quad.size = Vector2(MIRROR_HEAD.x * 0.85, MIRROR_HEAD.y * 0.9)
		glass.mesh = quad
		# The quad faces -Z (backward), toward the driver.
		glass.position = mount + Vector3(0, 0, -MIRROR_HEAD.z / 2.0 - 0.005)
		glass.rotation = Vector3(0, PI, 0)
		add_child(glass)
		mirror_glass[part] = glass
		set_mirror_image(part, null)

		var sensor := Area3D.new()
		sensor.name = "MirrorSensor_" + part
		sensor.collision_layer = 0
		sensor.collision_mask = Layers.WORLD | Layers.TRAFFIC
		# Must stay monitorable: Godot treats non-monitorable areas as static in
		# the broadphase, and static-static pairs (sensor vs building) never form.
		sensor.monitorable = true
		var sensor_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = MIRROR_HEAD + Vector3(0.04, 0.04, 0.04)
		sensor_shape.shape = box
		sensor.add_child(sensor_shape)
		sensor.position = mount
		sensor.body_entered.connect(_on_mirror_touched.bind(part))
		add_child(sensor)
		_mirror_sensors[part] = sensor


## Shows [param texture] (a mirror camera's view) on the mirror glass, flipped
## like a real mirror; null shows dark glass. [param broken] shows cracked glass.
func set_mirror_image(part: String, texture: Texture2D, broken := false) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if broken:
		material.albedo_color = Color(0.18, 0.18, 0.2)
	elif texture != null:
		material.albedo_texture = texture
		material.uv1_scale = Vector3(-1, 1, 1)
	else:
		material.albedo_color = Color(0.45, 0.55, 0.65)
	(mirror_glass[part] as MeshInstance3D).material_override = material


func _on_mirror_touched(body: Node3D, part: String) -> void:
	if body == self:
		return
	var other_velocity := Vector3.ZERO
	if body is TrafficCar:
		other_velocity = (body as TrafficCar).velocity()
	var relative := (linear_velocity - other_velocity).length()
	if relative >= DamageModel.MIRROR_BREAK:
		impact.emit(part, relative)


## Thin dark skins over each body panel; their opacity shows panel damage.
func _build_panel_overlays(body_height: float) -> void:
	var y := BODY_CLEARANCE + body_height / 2.0
	var hl := spec.length / 2.0 + 0.015
	var hw := spec.width / 2.0 + 0.015
	var panels := {
		DamageModel.BODY_FRONT:
		[Vector3(0, y, hl), Vector3(spec.width * 0.96, body_height * 0.9, 0.01)],
		DamageModel.BODY_REAR:
		[Vector3(0, y, -hl), Vector3(spec.width * 0.96, body_height * 0.9, 0.01)],
		DamageModel.BODY_LEFT:
		[Vector3(hw, y, 0), Vector3(0.01, body_height * 0.9, spec.length * 0.96)],
		DamageModel.BODY_RIGHT:
		[Vector3(-hw, y, 0), Vector3(0.01, body_height * 0.9, spec.length * 0.96)],
	}
	for part in panels:
		var overlay := MeshInstance3D.new()
		overlay.name = "Dents_" + part
		var box := BoxMesh.new()
		box.size = panels[part][1]
		overlay.mesh = box
		overlay.position = panels[part][0]
		add_child(overlay)
		_panel_overlays[part] = overlay
		set_part_health(part, 1.0)


## Shows a panel's damage: grime and dents fade in as its health drops.
func set_part_health(part: String, health: float) -> void:
	if not _panel_overlays.has(part):
		return
	var overlay := _panel_overlays[part] as MeshInstance3D
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.18, 0.14, 0.1, (1.0 - clampf(health, 0.0, 1.0)) * 0.75)
	material.roughness = 1.0
	overlay.material_override = material
	overlay.visible = health < 1.0


func panel_damage_alpha(part: String) -> float:
	var overlay := _panel_overlays[part] as MeshInstance3D
	return (overlay.material_override as StandardMaterial3D).albedo_color.a


func _build_lamps() -> void:
	var x := spec.width / 2.0 - 0.12
	var z := spec.length / 2.0 + 0.03
	var y := BODY_CLEARANCE + 0.45
	var spots := {
		"front_left": Vector3(x, y, z),
		"rear_left": Vector3(x, y, -z),
		"front_right": Vector3(-x, y, z),
		"rear_right": Vector3(-x, y, -z),
	}
	for lamp_name in spots:
		var lamp := MeshInstance3D.new()
		lamp.name = "Lamp_" + lamp_name
		var box := BoxMesh.new()
		box.size = Vector3(0.22, 0.14, 0.06)
		lamp.mesh = box
		lamp.position = spots[lamp_name]
		add_child(lamp)
		_lamps[lamp_name] = lamp
	set_indicator_lamps(false, false)


## Lights the left and/or right indicator lamps (front and rear).
func set_indicator_lamps(left_on: bool, right_on: bool) -> void:
	for lamp_name in _lamps:
		var lit: bool = left_on if lamp_name.ends_with("left") else right_on
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.55, 0.0) if lit else Color(0.35, 0.22, 0.1)
		material.emission_enabled = lit
		material.emission = Color(1.0, 0.6, 0.1)
		material.emission_energy_multiplier = 3.0
		(_lamps[lamp_name] as MeshInstance3D).material_override = material


func is_lamp_lit(lamp_name: String) -> bool:
	var lamp := _lamps[lamp_name] as MeshInstance3D
	return (lamp.material_override as StandardMaterial3D).emission_enabled


func _add_wheel(wheel_name: String, at: Vector3, steering: bool, traction: bool) -> void:
	var wheel := VehicleWheel3D.new()
	wheel.name = wheel_name
	wheel.position = at
	wheel.use_as_steering = steering
	wheel.use_as_traction = traction
	wheel.wheel_radius = WHEEL_RADIUS
	wheel.wheel_rest_length = SUSPENSION_REST
	wheel.suspension_travel = 0.3
	wheel.suspension_stiffness = 22.0
	wheel.suspension_max_force = spec.mass * 12.0
	# Damping near critical for the stiffness above, so the bus settles without bouncing.
	wheel.damping_compression = 2.8
	wheel.damping_relaxation = 3.4
	wheel.wheel_friction_slip = 1.4
	wheel.wheel_roll_influence = 0.05
	var tyre := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = WHEEL_RADIUS
	cylinder.bottom_radius = WHEEL_RADIUS
	cylinder.height = 0.35
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.08, 0.08, 0.08)
	cylinder.material = rubber
	tyre.mesh = cylinder
	tyre.rotation = Vector3(0, 0, PI / 2.0)
	wheel.add_child(tyre)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = WHEEL_RADIUS * 0.55
	hub_mesh.bottom_radius = WHEEL_RADIUS * 0.55
	hub_mesh.height = 0.37
	hub_mesh.material = rim_material
	hub.mesh = hub_mesh
	hub.rotation = Vector3(0, 0, PI / 2.0)
	wheel.add_child(hub)
	add_child(wheel)


## Desired pedal and steering positions. Values are clamped by [DriveInput].
func set_command(throttle: float, brake_pedal: float, steer_target: float) -> void:
	if (
		throttle == _target_throttle
		and brake_pedal == _target_brake
		and steer_target == _target_steer
	):
		return
	_target_throttle = throttle
	_target_brake = brake_pedal
	_target_steer = steer_target
	command_changed.emit()


func set_rims(color: Color, metallic: float, roughness: float) -> void:
	rim_material.albedo_color = color
	rim_material.metallic = metallic
	rim_material.roughness = roughness


## Applies a full set of cosmetic choices ({category: item id}, see [Catalog]).
func apply_cosmetics(choices: Dictionary) -> void:
	var paint_id: String = choices.get("paint", "stock")
	set_paint(Catalog.paint_color(spec.id, paint_id))
	var stripe := Catalog.cosmetic_entry("stripe", choices.get("stripe", "none"))
	body.set_stripe(stripe.get("color"))
	var rims := Catalog.cosmetic_entry("rims", choices.get("rims", "steel"))
	set_rims(rims["color"], rims["metallic"], rims["roughness"])
	var tint := Catalog.cosmetic_entry("tint", choices.get("tint", "clear"))
	body.set_tint(tint["darkness"])
	var roof := Catalog.cosmetic_entry("roof", choices.get("roof", "body"))
	body.set_roof(roof.get("color"))


func set_paint(paint: Color) -> void:
	_paint = paint
	_update_body_material()


func get_paint() -> Color:
	return _paint


## Visual wear from 0 (pristine) to 1 (wrecked): the paint dulls and darkens.
func set_wear(amount: float) -> void:
	_wear = clampf(amount, 0.0, 1.0)
	_update_body_material()


func body_color() -> Color:
	return body.paint_material.albedo_color


## All painted panels share one material, so paint and wear update in one place.
func _update_body_material() -> void:
	body.paint_material.albedo_color = _paint.lerp(Color(0.25, 0.22, 0.2), _wear * 0.7)
	body.paint_material.roughness = lerpf(0.32, 0.95, _wear)
	body.paint_material.metallic = lerpf(0.35, 0.05, _wear)


## Signed speed along the bus's forward axis in m/s (negative when reversing).
func forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)


func speed_kmh() -> float:
	return absf(forward_speed()) * 3.6


func effective_top_speed() -> float:
	return spec.top_speed * top_speed_factor * damage_speed_factor


func forward_vector() -> Vector3:
	return global_transform.basis.z


## Detects crashes. Godot reports contact impulses a step late, so a glancing
## hit that bounces clear would go unseen; instead the bus's own sudden
## velocity change (beyond what driving forces could cause) measures the
## impact, and the contact normals say which part took it.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var jump := (state.linear_velocity - _last_velocity).length()
	_last_velocity = state.linear_velocity
	var sudden := jump - MAX_DRIVING_ACCEL * state.step
	var to_local := global_transform.affine_inverse()
	var best_part := ""
	var best_impulse := -1.0
	var impulse_dv := 0.0
	for i in state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		if normal.y > 0.7:
			continue
		var impulse := state.get_contact_impulse(i).length()
		impulse_dv += impulse / mass
		if impulse > best_impulse:
			best_impulse = impulse
			best_part = DamageModel.panel_for_normal(to_local.basis * normal)
	if best_part.is_empty():
		return
	var strength := maxf(sudden, impulse_dv)
	if strength >= DamageModel.MIN_IMPACT:
		impact.emit(best_part, strength)


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		input.reset()
		engine_force = 0.0
		brake = spec.brake_force * brake_factor
		steering = move_toward(steering, 0.0, delta)
		return
	input.steer_rate = 2.0 * handling_factor
	var speed := forward_speed()
	var top := effective_top_speed()
	var speed_ratio := absf(speed) / top if top > 0.0 else 0.0
	input.update(_target_throttle, _target_brake, _target_steer, delta, speed_ratio)
	var drive := Drivetrain.compute(
		input.throttle,
		input.brake,
		speed,
		top,
		spec.engine_force * acceleration_factor / 2.0,
		spec.brake_force * brake_factor,
		reverse_gear
	)
	engine_force = drive["engine_force"]
	brake = drive["brake"]
	# Steering is "left positive" in VehicleBody3D, our input is "right positive".
	steering = -input.steer * Drivetrain.steer_limit(spec.max_steer, speed, top)
	_update_lights()
	body.update_dashboard(
		speed_kmh(), input.steer, input.throttle, dash_left, dash_right, reverse_gear
	)
