extends TestCase
## The driver's cockpit (dashboard, gauges, steering wheel) and the bus lights.

var world: FlatWorld
var bus: Bus


func before_each() -> void:
	world = add_child_autofree(FlatWorld.create())
	bus = await world.spawn_bus(self, Catalog.bus_spec("city"))


## Angle (degrees) between the driver camera's view direction and [param node].
func _angle_from_view(node: Node3D) -> float:
	var cam := CameraModes.camera_transform(CameraModes.Mode.DRIVER, bus.global_transform, bus.spec)
	var to_node := (node.global_position - cam.origin).normalized()
	return rad_to_deg((-cam.basis.z).angle_to(to_node))


func _below_view(node: Node3D) -> bool:
	var cam := CameraModes.camera_transform(CameraModes.Mode.DRIVER, bus.global_transform, bus.spec)
	return (node.global_position - cam.origin).dot(cam.basis.y) < 0.0


func test_dashboard_and_wheel_are_in_the_driver_camera_view() -> void:
	var half_fov := 75.0 / 2.0
	for part in ["Cluster", "SteeringWheel"]:
		var node := bus.body.find_child(part, true, false) as Node3D
		var angle := _angle_from_view(node)
		assert_lt(angle, half_fov, "%s visible (%.1f deg off-centre)" % [part, angle])
		assert_gt(angle, 10.0, "%s sits low, out of the way of the road" % part)
		assert_true(_below_view(node), "%s is in the lower part of the view" % part)


func test_every_bus_type_shows_its_dashboard() -> void:
	for bus_id in Catalog.bus_ids():
		var other := Bus.create(Catalog.bus_spec(bus_id))
		world.add_child(other)
		other.global_position = Vector3(30, 0.3, 0)
		var cam := CameraModes.camera_transform(
			CameraModes.Mode.DRIVER, other.global_transform, other.spec
		)
		var cluster := other.body.find_child("Cluster", true, false) as Node3D
		var angle := rad_to_deg((-cam.basis.z).angle_to(cluster.global_position - cam.origin))
		assert_lt(angle, 37.5, "%s cluster in view" % bus_id)
		other.free()


func test_speedometer_and_rev_needles_follow_the_bus() -> void:
	var resting_speed := bus.body.speed_needle.rotation.z
	var resting_revs := bus.body.rpm_needle.rotation.z
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(5.0)
	assert_lt(bus.body.speed_needle.rotation.z, resting_speed - 0.3, "speedo swings clockwise")
	assert_lt(bus.body.rpm_needle.rotation.z, resting_revs, "revs rise")
	var expected := BusBody.needle_angle(bus.speed_kmh() / BusBody.SPEEDO_MAX_KMH)
	assert_almost_eq(bus.body.speed_needle.rotation.z, expected, 0.05)


func test_needle_angle_sweeps_270_degrees() -> void:
	assert_almost_eq(BusBody.needle_angle(0.0), deg_to_rad(135.0), 0.0001)
	assert_almost_eq(BusBody.needle_angle(1.0), deg_to_rad(-135.0), 0.0001)
	assert_almost_eq(BusBody.needle_angle(5.0), deg_to_rad(-135.0), 0.0001, "pinned at max")


func test_steering_wheel_turns_with_input() -> void:
	bus.set_command(0.0, 0.0, 1.0)
	await wait_seconds(1.5)
	var turned := bus.body.steering_wheel.rotation.z
	assert_almost_eq(turned, -bus.input.steer * BusBody.WHEEL_LOCK_TURNS * TAU, 0.001)
	assert_lt(turned, -1.0, "right lock turns the wheel clockwise")
	bus.set_command(0.0, 0.0, 0.0)
	await wait_seconds(2.0)
	assert_almost_eq(bus.body.steering_wheel.rotation.z, 0.0, 0.01, "self-centres")


func test_dash_shows_indicators_and_gear() -> void:
	bus.dash_left = true
	assert_true(bus.set_reverse(true))
	await wait_physics_frames(2)
	var left := bus.body.dash_arrows["left"] as MeshInstance3D
	var right := bus.body.dash_arrows["right"] as MeshInstance3D
	assert_eq(left.material_override, bus.body.arrow_on)
	assert_eq(right.material_override, bus.body.arrow_off)
	assert_eq(bus.body.gear_label.text, "R")


func test_gear_change_refused_while_moving() -> void:
	watch_signals(bus)
	bus.set_command(1.0, 0.0, 0.0)
	await wait_seconds(3.0)
	assert_false(bus.set_reverse(true), "can't shift into reverse at speed")
	assert_false(bus.reverse_gear)
	assert_signal_not_emitted(bus, "gear_changed")
	bus.set_command(0.0, 1.0, 0.0)
	await wait_until(func() -> bool: return absf(bus.forward_speed()) < 0.2, 8.0)
	assert_true(bus.toggle_gear())
	assert_true(bus.reverse_gear)
	assert_eq(get_signal_parameters(bus, "gear_changed"), [true])


func test_headlights_light_up_the_road_and_cabin() -> void:
	assert_false(bus.headlights_on)
	bus.toggle_headlights()
	assert_true(bus.headlights_on)
	for lamp in bus.headlights:
		assert_true(lamp.visible)
		assert_ge(lamp.light_energy, 10.0, "bright enough to see the road at night")
		assert_ge(lamp.spot_range, 60.0)
	assert_true(bus.body.cabin_light.visible, "cabin lit at night")
	assert_gt(bus.body.head_material.emission_energy_multiplier, 2.0, "lenses glow")
	bus.set_headlights(false)
	assert_false(bus.body.cabin_light.visible)


func test_light_switch_cycles_off_low_high_off() -> void:
	assert_eq(bus.light_mode, Bus.LIGHTS_OFF)
	bus.cycle_lights()
	assert_eq(bus.light_mode, Bus.LOW_BEAM)
	var low_range := bus.headlights[0].spot_range
	var low_angle := bus.headlights[0].spot_angle
	var low_pitch := bus.headlights[0].rotation.x
	assert_eq(bus.body.high_beam_lamp.material_override, bus.body.high_beam_off)
	bus.cycle_lights()
	assert_eq(bus.light_mode, Bus.HIGH_BEAM)
	assert_true(bus.headlights_on)
	for lamp in bus.headlights:
		assert_true(lamp.visible)
		assert_gt(lamp.spot_range, low_range * 1.5, "high beam reaches much further")
		assert_lt(lamp.spot_angle, low_angle, "in a tighter cone")
		assert_gt(lamp.rotation.x, low_pitch, "aimed up toward the horizon")
	assert_eq(bus.body.high_beam_lamp.material_override, bus.body.high_beam_on, "blue tell-tale")
	bus.cycle_lights()
	assert_eq(bus.light_mode, Bus.LIGHTS_OFF)
	assert_false(bus.headlights_on)
	for lamp in bus.headlights:
		assert_false(lamp.visible)


func test_low_beam_dips_toward_the_road() -> void:
	bus.set_headlights(true)
	assert_eq(bus.light_mode, Bus.LOW_BEAM)
	for lamp in bus.headlights:
		assert_lt(lamp.rotation.x, -0.05, "pitched down so it does not dazzle")


func test_brake_lights_brighten_when_braking() -> void:
	bus.set_command(0.0, 0.0, 0.0)
	await wait_physics_frames(5)
	var idle := bus.body.tail_material.emission_energy_multiplier
	bus.set_command(0.0, 1.0, 0.0)
	await wait_physics_frames(10)
	var braking := bus.body.tail_material.emission_energy_multiplier
	assert_gt(braking, idle * 3.0)


func test_reverse_lights_only_in_reverse() -> void:
	assert_eq(bus.body.reverse_material.emission_energy_multiplier, 0.0)
	bus.set_reverse(true)
	assert_gt(bus.body.reverse_material.emission_energy_multiplier, 1.0)
	bus.set_reverse(false)
	assert_eq(bus.body.reverse_material.emission_energy_multiplier, 0.0)
