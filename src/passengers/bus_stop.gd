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
var _beacon: Node3D


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

	_build_bay()
	_build_shelter()
	_build_beacon()

	_label = Label3D.new()
	_label.name = "Sign"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 64
	_label.outline_size = 12
	_label.position = Vector3(_sidewalk_x(), 4.2, 3.0)
	add_child(_label)

	_figures = Node3D.new()
	_figures.name = "Figures"
	_figures.position = Vector3(_sidewalk_x(), GameWorld.KERB_HEIGHT, 0.0)
	add_child(_figures)
	set_waiting(0)


## Centre of the pavement beside the stop (bus-local: -X is the kerb side).
static func _sidewalk_x() -> float:
	return -(Track.LANE_WIDTH / 2.0 + Track.SHOULDER + GameWorld.SIDEWALK_WIDTH / 2.0)


static func _mat(color: Color, roughness := 0.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _part(
	part_name: String, mesh: PrimitiveMesh, at: Vector3, material: Material
) -> MeshInstance3D:
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	return instance


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


## The bus bay: a painted box outline with "BUS" lettering on the road.
func _build_bay() -> void:
	var color := Color(1.0, 0.82, 0.1) if not is_terminal else Color(0.35, 0.7, 1.0)
	var paint := _mat(color, 0.7)
	var half_w := Track.LANE_WIDTH / 2.0 - 0.25
	var half_l := ZONE_LENGTH / 2.0
	_part("BayFront", _box(Vector3(half_w * 2.0, 0.02, 0.2)), Vector3(0, 0.035, half_l), paint)
	_part("BayBack", _box(Vector3(half_w * 2.0, 0.02, 0.2)), Vector3(0, 0.035, -half_l), paint)
	for side in [1.0, -1.0]:
		_part(
			"BaySide",
			_box(Vector3(0.2, 0.02, ZONE_LENGTH)),
			Vector3(side * half_w, 0.035, 0),
			paint
		)
	var tint := StandardMaterial3D.new()
	tint.albedo_color = Color(color.r, color.g, color.b, 0.16)
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var fill := PlaneMesh.new()
	fill.size = Vector2(half_w * 2.0, ZONE_LENGTH)
	_part("Marking", fill, Vector3(0, 0.03, 0), tint)
	var word := Label3D.new()
	word.name = "BayText"
	word.text = "BUS STOP" if not is_terminal else "TERMINAL"
	word.font_size = 96
	word.pixel_size = 0.012
	word.modulate = color
	word.shaded = true
	word.rotation = Vector3(-PI / 2.0, PI, 0)
	word.position = Vector3(0, 0.05, 3.5)
	add_child(word)


## A real-looking shelter: posts, roof, back wall, glass side, bench,
## timetable board and a tall pole sign.
func _build_shelter() -> void:
	var x := _sidewalk_x()
	var kerb := GameWorld.KERB_HEIGHT
	var frame := _mat(Color(0.2, 0.22, 0.25), 0.4)
	frame.metallic = 0.6
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.7, 0.75, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.05
	var back := x - 0.85
	_part("Shelter", _box(Vector3(1.9, 0.12, 5.2)), Vector3(x - 0.2, kerb + 2.6, 0), frame)
	for z in [-2.5, 2.5]:
		for px in [back, x + 0.6]:
			_part("ShelterPost", _box(Vector3(0.08, 2.55, 0.08)), Vector3(px, kerb + 1.3, z), frame)
	_part("ShelterBack", _box(Vector3(0.04, 2.0, 5.0)), Vector3(back, kerb + 1.25, 0), glass)
	_part("ShelterSide", _box(Vector3(1.4, 2.0, 0.04)), Vector3(x - 0.15, kerb + 1.25, -2.5), glass)
	_part(
		"ShelterBench",
		_box(Vector3(0.45, 0.08, 2.4)),
		Vector3(back + 0.3, kerb + 0.5, 0.6),
		_mat(Color(0.45, 0.3, 0.18), 0.8)
	)
	var advert := _mat(Color(0.95, 0.92, 0.85), 0.5)
	advert.emission_enabled = true
	advert.emission = Color(0.95, 0.92, 0.85)
	advert.emission_energy_multiplier = 0.4
	_part(
		"Timetable", _box(Vector3(0.06, 1.2, 0.9)), Vector3(back + 0.05, kerb + 1.4, -1.6), advert
	)
	# Pole sign at the front of the stop, where the bus doors stop.
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.05
	pole.height = 3.2
	_part("SignPole", pole, Vector3(x + 0.7, kerb + 1.6, ZONE_LENGTH / 2.0 - 1.5), frame)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.38
	disc.bottom_radius = 0.38
	disc.height = 0.05
	var plate := _part(
		"SignPlate",
		disc,
		Vector3(x + 0.7, kerb + 3.0, ZONE_LENGTH / 2.0 - 1.5),
		_mat(Color(0.1, 0.35, 0.75), 0.4)
	)
	plate.rotation = Vector3(0, 0, PI / 2.0)
	var letters := Label3D.new()
	letters.name = "SignLetters"
	letters.text = "BUS"
	letters.font_size = 48
	letters.pixel_size = 0.006
	letters.outline_size = 0
	letters.position = Vector3(x + 0.74, kerb + 3.0, ZONE_LENGTH / 2.0 - 1.5)
	letters.rotation = Vector3(0, PI / 2.0, 0)
	add_child(letters)


## A tall glowing marker shown above the next stop so you can find it from afar.
func _build_beacon() -> void:
	_beacon = Node3D.new()
	_beacon.name = "Beacon"
	_beacon.position = Vector3(0, 0, 0)
	add_child(_beacon)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.2, 1.0, 0.45, 0.5)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(0.2, 1.0, 0.45)
	glow.emission_energy_multiplier = 2.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var arrow := CylinderMesh.new()
	arrow.top_radius = 1.0
	arrow.bottom_radius = 0.0
	arrow.height = 1.6
	arrow.material = glow
	var tip := MeshInstance3D.new()
	tip.name = "Arrow"
	tip.mesh = arrow
	tip.position.y = 7.0
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beacon.add_child(tip)
	_beacon.visible = false


## Marks this stop as the next one to serve.
func set_highlighted(on: bool) -> void:
	_beacon.visible = on


func is_highlighted() -> bool:
	return _beacon.visible


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
