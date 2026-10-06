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
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(WIDTH, 0.8, LENGTH)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	mesh.material = paint
	body.mesh = mesh
	body.position.y = 0.7
	add_child(body)
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(WIDTH * 0.9, 0.6, LENGTH * 0.5)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.15, 0.2, 0.28)
	cabin_mesh.material = glass
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 1.3, -0.2)
	add_child(cabin)


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
