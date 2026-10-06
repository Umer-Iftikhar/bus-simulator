class_name GaragePreview
extends SubViewportContainer
## A turntable showing the selected bus with its current customisation, in
## its own little lit world so the garage menu can show off purchases live.

const SPIN_SPEED := 0.45

var viewport := SubViewport.new()
var pivot := Node3D.new()
var camera := Camera3D.new()
var bus: Bus


func _init() -> void:
	name = "GaragePreview"
	stretch = true
	custom_minimum_size = Vector2(0, 250)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 30, 0)
	key.light_energy = 1.4
	viewport.add_child(key)
	var floor_disc := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 9.0
	disc.bottom_radius = 9.0
	disc.height = 0.1
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.32, 0.33, 0.36)
	floor_material.metallic = 0.3
	floor_material.roughness = 0.4
	disc.material = floor_material
	floor_disc.mesh = disc
	floor_disc.position.y = -0.1
	viewport.add_child(floor_disc)
	viewport.add_child(pivot)
	viewport.add_child(camera)
	camera.current = true


## Shows [param spec] wearing [param choices] ({category: item id}).
func show_bus(spec: BusSpec, choices: Dictionary) -> void:
	if is_instance_valid(bus):
		bus.free()
	bus = Bus.create(spec)
	bus.freeze = true
	bus.set_physics_process(false)
	pivot.add_child(bus)
	bus.position = Vector3(0, 0.05, 0)
	bus.apply_cosmetics(choices)
	var distance := spec.length * 0.95 + 3.0
	camera.position = Vector3(distance * 0.75, spec.height * 0.9 + 1.0, distance * 0.75)
	camera.look_at(Vector3(0, spec.height * 0.45, 0), Vector3.UP)


func _process(delta: float) -> void:
	pivot.rotate_y(SPIN_SPEED * delta)
