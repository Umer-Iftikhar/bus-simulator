class_name BusStop
extends Area3D
## A stop on the route: an Area3D trigger covering the kerb lane, plus a
## shelter, sign and figures for the passengers waiting there.

const ZONE_LENGTH := 18.0
const MAX_FIGURES := 10

var stop_index := 0
var stop_name := ""
var is_terminal := false
## Distance along the loop where the stop is centred.
var offset := 0.0
var _bus_inside := false
var _figures: Node3D
var _label: Label3D
var _waiting := 0


static func create(
	index: int, title: String, track: Track, at_offset: float, terminal: bool
) -> BusStop:
	var stop := BusStop.new()
	stop.name = "Stop%d" % index
	stop.stop_index = index
	stop.stop_name = title
	stop.is_terminal = terminal
	stop.offset = at_offset
	stop._build(track)
	return stop


func _build(track: Track) -> void:
	collision_layer = Layers.TRIGGERS
	collision_mask = Layers.PLAYER
	monitorable = false
	transform = track.vehicle_transform(0, offset)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(Track.LANE_WIDTH, 4.0, ZONE_LENGTH)
	shape.shape = box
	shape.position.y = 2.0
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Kerb lane marking: a yellow box painted on the road.
	var marking := MeshInstance3D.new()
	marking.name = "Marking"
	var plane := PlaneMesh.new()
	plane.size = Vector2(Track.LANE_WIDTH - 0.4, ZONE_LENGTH)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = (
		Color(1.0, 0.8, 0.1, 0.55) if not is_terminal else Color(0.2, 0.7, 1.0, 0.55)
	)
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plane.material = paint
	marking.mesh = plane
	marking.position.y = 0.04
	add_child(marking)

	# Shelter on the sidewalk to the right (-X in vehicle space).
	var sidewalk_x := -(Track.LANE_WIDTH / 2.0 + Track.SHOULDER + GameWorld.SIDEWALK_WIDTH / 2.0)
	var shelter := MeshInstance3D.new()
	shelter.name = "Shelter"
	var roof := BoxMesh.new()
	roof.size = Vector3(1.6, 0.15, 5.0)
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color(0.25, 0.3, 0.35)
	roof.material = roof_material
	shelter.mesh = roof
	shelter.position = Vector3(sidewalk_x - 0.3, 2.6, 0.0)
	add_child(shelter)

	_label = Label3D.new()
	_label.name = "Sign"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 64
	_label.outline_size = 12
	_label.position = Vector3(sidewalk_x, 3.6, 3.0)
	add_child(_label)

	_figures = Node3D.new()
	_figures.name = "Figures"
	_figures.position = Vector3(sidewalk_x, 0.0, 0.0)
	add_child(_figures)
	set_waiting(0)


func bus_inside() -> bool:
	return _bus_inside


func waiting() -> int:
	return _waiting


## Shows [param count] waiting passengers (capped at [constant MAX_FIGURES] figures).
func set_waiting(count: int) -> void:
	_waiting = count
	_label.text = "%s\n%d waiting" % [stop_name, count] if count > 0 else stop_name
	for child in _figures.get_children():
		child.free()
	for i in mini(count, MAX_FIGURES):
		var figure := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.25
		capsule.height = 1.7
		var cloth := StandardMaterial3D.new()
		cloth.albedo_color = Color.from_hsv(fmod(i * 0.17 + stop_index * 0.31, 1.0), 0.6, 0.85)
		capsule.material = cloth
		figure.mesh = capsule
		figure.position = Vector3(0.0, 0.85, -2.0 + i * 0.45)
		_figures.add_child(figure)


func figure_count() -> int:
	return _figures.get_child_count()


func _on_body_entered(body: Node3D) -> void:
	if body is Bus:
		_bus_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body is Bus:
		_bus_inside = false
