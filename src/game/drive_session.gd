class_name DriveSession
extends Node3D
## One driving session on a map: builds the world, spawns the bus and wires
## the camera, HUD, touch controls and player input together.

signal exit_requested

const SPAWN_OFFSET := 6.0

var map: MapDef
var spec: BusSpec
var world: GameWorld
var bus: Bus
var horn: Horn
var camera_rig: CameraRig
var player_input: PlayerInput
var ui: CanvasLayer
var hud: Hud
var touch_controls: TouchControls


static func create(map_def: MapDef, bus_spec: BusSpec) -> DriveSession:
	var session := DriveSession.new()
	session.name = "DriveSession"
	session.map = map_def
	session.spec = bus_spec
	return session


func _ready() -> void:
	world = GameWorld.create(map)
	add_child(world)

	bus = Bus.create(spec)
	add_child(bus)
	bus.global_transform = spawn_transform()
	horn = Horn.new()
	bus.add_child(horn)

	camera_rig = CameraRig.new()
	camera_rig.target = bus
	add_child(camera_rig)

	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	touch_controls = TouchControls.new()
	ui.add_child(touch_controls)

	player_input = PlayerInput.new()
	player_input.bus = bus
	player_input.touch = touch_controls
	add_child(player_input)

	player_input.camera_requested.connect(camera_rig.cycle)
	player_input.horn_requested.connect(horn.honk)
	player_input.pause_requested.connect(exit_requested.emit)
	camera_rig.mode_changed.connect(hud.show_camera_mode)


## Where the bus starts: kerb lane, just past the start of the loop, wheels just above ground.
func spawn_transform() -> Transform3D:
	var xform := world.track.vehicle_transform(0, SPAWN_OFFSET)
	xform.origin.y = 0.3
	return xform


func _process(_delta: float) -> void:
	hud.show_speed(bus.speed_kmh())
