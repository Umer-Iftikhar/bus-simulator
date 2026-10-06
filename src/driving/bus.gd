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

const WHEEL_RADIUS := 0.5
const SUSPENSION_REST := 0.4
const BODY_CLEARANCE := 0.55
## Low centre of mass: engine, chassis and batteries sit under the floor.
const CENTER_OF_MASS_HEIGHT := 0.25
## Largest acceleration normal driving can produce (hard braking, full-lock
## turns); velocity changes beyond this between steps are collisions.
const MAX_DRIVING_ACCEL := 14.0

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

var _target_throttle := 0.0
var _target_brake := 0.0
var _target_steer := 0.0
var _body_mesh: MeshInstance3D
var _paint := Color.WHITE
var _wear := 0.0
var _last_velocity := Vector3.ZERO
var _lamps := {}


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

	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "BodyMesh"
	var body_box := BoxMesh.new()
	body_box.size = box.size
	_body_mesh.mesh = body_box
	_body_mesh.position = shape.position
	add_child(_body_mesh)
	set_paint(spec.color)
	_build_windows(body_height)

	_build_lamps()

	var half_track := spec.width / 2.0 - 0.15
	var axle := spec.wheelbase() / 2.0
	var attach_y := WHEEL_RADIUS + SUSPENSION_REST - 0.12
	_add_wheel("WheelFL", Vector3(half_track, attach_y, axle), true, false)
	_add_wheel("WheelFR", Vector3(-half_track, attach_y, axle), true, false)
	_add_wheel("WheelRL", Vector3(half_track, attach_y, -axle), false, true)
	_add_wheel("WheelRR", Vector3(-half_track, attach_y, -axle), false, true)


func _build_windows(body_height: float) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.15, 0.22, 0.3)
	glass.metallic = 0.3
	glass.roughness = 0.15
	var strip_y := BODY_CLEARANCE + body_height * 0.68
	for side in [1.0, -1.0]:
		var window := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.04, body_height * 0.32, spec.length * 0.86)
		mesh.material = glass
		window.mesh = mesh
		window.position = Vector3(side * (spec.width / 2.0 + 0.01), strip_y, -0.1)
		add_child(window)
	var windscreen := MeshInstance3D.new()
	var front := BoxMesh.new()
	front.size = Vector3(spec.width * 0.9, body_height * 0.42, 0.04)
	front.material = glass
	windscreen.mesh = front
	windscreen.name = "Windscreen"
	windscreen.position = Vector3(0, BODY_CLEARANCE + body_height * 0.66, spec.length / 2.0 + 0.01)
	add_child(windscreen)


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
	return (_body_mesh.material_override as StandardMaterial3D).albedo_color


func _update_body_material() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = _paint.lerp(Color(0.25, 0.22, 0.2), _wear * 0.7)
	material.roughness = lerpf(0.45, 0.95, _wear)
	_body_mesh.material_override = material


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
			var local_point := to_local * state.get_contact_local_position(i)
			best_part = DamageModel.part_for_contact(local_point, to_local.basis * normal, spec)
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
	input.update(_target_throttle, _target_brake, _target_steer, delta)
	var speed := forward_speed()
	var top := effective_top_speed()
	var drive := Drivetrain.compute(
		input.throttle,
		input.brake,
		speed,
		top,
		spec.engine_force * acceleration_factor / 2.0,
		spec.brake_force * brake_factor
	)
	engine_force = drive["engine_force"]
	brake = drive["brake"]
	# Steering is "left positive" in VehicleBody3D, our input is "right positive".
	steering = -input.steer * Drivetrain.steer_limit(spec.max_steer, speed, top)
