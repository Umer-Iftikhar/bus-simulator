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
		Color(1.0, 0.8, 0.1, 0.3) if not is_terminal else Color(0.3, 0.65, 1.0, 0.3)
	)
	paint.roughness = 0.7
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
		_figures.add_child(_person(i))


## A simple standing person: legs, coat and head, in muted everyday colours.
func _person(i: int) -> Node3D:
	var person := Node3D.new()
	person.position = Vector3(0.0, 0.0, -2.0 + i * 0.45)
	var coat_colors := [
		Color(0.2, 0.25, 0.35),
		Color(0.45, 0.2, 0.18),
		Color(0.3, 0.35, 0.25),
		Color(0.55, 0.5, 0.42),
		Color(0.15, 0.15, 0.17),
		Color(0.6, 0.45, 0.2),
	]
	var skin_tones := [Color(0.95, 0.8, 0.68), Color(0.75, 0.55, 0.4), Color(0.45, 0.3, 0.2)]
	var parts := [
		[CapsuleMesh.new(), 0.13, 0.85, 0.42, Color(0.12, 0.13, 0.16)],
		[CapsuleMesh.new(), 0.24, 0.8, 1.1, coat_colors[(i + stop_index * 2) % coat_colors.size()]],
		[SphereMesh.new(), 0.13, 0.26, 1.65, skin_tones[(i * 7 + stop_index) % skin_tones.size()]],
	]
	for part in parts:
		var mesh: PrimitiveMesh = part[0]
		mesh.set("radius", part[1])
		mesh.set("height", part[2])
		var material := StandardMaterial3D.new()
		material.albedo_color = part[4]
		material.roughness = 0.9
		mesh.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position.y = part[3]
		person.add_child(instance)
	return person


func figure_count() -> int:
	return _figures.get_child_count()


func _on_body_entered(body: Node3D) -> void:
	if body is Bus:
		_bus_inside = true


func _on_body_exited(body: Node3D) -> void:
	if body is Bus:
		_bus_inside = false
