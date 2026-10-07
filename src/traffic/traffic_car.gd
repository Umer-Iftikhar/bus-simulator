class_name TrafficCar
extends AnimatableBody3D
## An AI car locked to one lane of the loop. Its motion is computed by
## [TrafficManager]; as an AnimatableBody3D it shoves the bus physically when
## they collide, so crashes into traffic cause real impacts.

const LENGTH := 4.4
const WIDTH := 1.85
const HEIGHT := 1.5

var track: Track
var lane := 0
## Centre of the car, metres along the loop.
var offset := 0.0
var speed := 0.0
var desired_speed := 11.0
## True while the car is dropping back to let the signalling bus in.
var yielding := false
var color := Color.WHITE


static func create(
	on_track: Track, start_lane: int, start_offset: float, paint: Color
) -> TrafficCar:
	var car := TrafficCar.new()
	car.track = on_track
	car.lane = start_lane
	car.offset = on_track.wrap_offset(start_offset)
	car.color = paint
	car._build()
	car.place()
	return car


func _build() -> void:
	collision_layer = Layers.TRAFFIC
	collision_mask = 0
	sync_to_physics = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HEIGHT - 0.3, LENGTH)
	shape.shape = box
	shape.position.y = 0.3 + (HEIGHT - 0.3) / 2.0
	add_child(shape)
	TrafficCar.build_visuals(self, color)


## Car shape on [param parent]: painted lower body, tinted glass cabin with a
## painted roof, four wheels, bumpers and head/tail lights. A positive
## [param fade_distance] hides the car beyond that range (parked cars).
## The parts of a car in car-local space: [{"name", "mesh", "transform",
## "material" (or null when the part takes the car's paint)}]. Shared by
## moving traffic (one node per part) and parked cars (one MultiMesh per part).
static func part_specs() -> Array[Dictionary]:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.13, 0.17)
	glass.metallic = 0.6
	glass.roughness = 0.08
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.06)
	dark.roughness = 0.7
	var head := _glow(Color(1.0, 0.97, 0.88), 2.0)
	var tail := _glow(Color(0.85, 0.05, 0.05), 1.5)
	var half := LENGTH / 2.0
	var specs: Array[Dictionary] = []
	var box := func(part_name: String, size: Vector3, at: Vector3, material: Variant) -> void:
		var mesh := BoxMesh.new()
		mesh.size = size
		specs.append(
			{
				"name": part_name,
				"mesh": mesh,
				"transform": Transform3D(Basis(), at),
				"material": material
			}
		)
	box.call("Body", Vector3(WIDTH, 0.62, LENGTH), Vector3(0, 0.66, 0), null)
	box.call("Cabin", Vector3(WIDTH * 0.86, 0.5, LENGTH * 0.5), Vector3(0, 1.22, -0.25), glass)
	box.call("Roof", Vector3(WIDTH * 0.84, 0.06, LENGTH * 0.46), Vector3(0, 1.48, -0.25), null)
	box.call("BumperFront", Vector3(WIDTH + 0.02, 0.18, 0.08), Vector3(0, 0.45, half + 0.03), dark)
	box.call("BumperRear", Vector3(WIDTH + 0.02, 0.18, 0.08), Vector3(0, 0.45, -half - 0.03), dark)
	for side in [1.0, -1.0]:
		var tag := "L" if side > 0.0 else "R"
		box.call(
			"Head" + tag, Vector3(0.38, 0.14, 0.04), Vector3(side * 0.6, 0.78, half + 0.01), head
		)
		box.call(
			"Tail" + tag, Vector3(0.38, 0.14, 0.04), Vector3(side * 0.6, 0.8, -half - 0.01), tail
		)
		for z in [half - 0.85, -half + 0.85]:
			var tyre := CylinderMesh.new()
			tyre.top_radius = 0.33
			tyre.bottom_radius = 0.33
			tyre.height = 0.24
			var at := Vector3(side * (WIDTH / 2.0 - 0.12), 0.33, z)
			(
				specs
				. append(
					{
						"name": "Wheel",
						"mesh": tyre,
						"transform": Transform3D(Basis(Vector3.BACK, PI / 2.0), at),
						"material": dark,
					}
				)
			)
	return specs


static func paint_material(color: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.45
	paint.roughness = 0.3
	return paint


## Builds a car's parts as child nodes of [param parent].
static func build_visuals(parent: Node3D, color: Color) -> void:
	var paint := paint_material(color)
	for spec in part_specs():
		var mesh: PrimitiveMesh = spec["mesh"]
		mesh.material = spec["material"] if spec["material"] != null else paint
		var instance := MeshInstance3D.new()
		instance.name = spec["name"]
		instance.mesh = mesh
		instance.transform = spec["transform"]
		parent.add_child(instance)


static func _glow(light_color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = light_color
	material.emission_enabled = true
	material.emission = light_color
	material.emission_energy_multiplier = energy
	return material


## World-space velocity along the road.
func velocity() -> Vector3:
	return track.forward_at(offset) * speed


func front_offset() -> float:
	return offset + LENGTH / 2.0


func rear_offset() -> float:
	return offset - LENGTH / 2.0


## Integrates speed/position for one step with acceleration [param accel].
func advance(accel: float, delta: float) -> void:
	speed = maxf(0.0, speed + accel * delta)
	offset = track.wrap_offset(offset + speed * delta)
	place()


func place() -> void:
	global_transform = track.vehicle_transform(lane, offset)
