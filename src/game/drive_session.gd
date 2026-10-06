class_name DriveSession
extends Node3D
## One driving session on a map: builds the world, spawns the bus, runs the
## route and wires the camera, HUD, touch controls and player input together.
##
## Options (all optional):
##   "performance": {top_speed, acceleration, brakes, handling} multipliers
##   "seed": int passenger seed (random when absent)

signal run_finished(result: Dictionary)
signal exit_requested

const SPAWN_OFFSET := 6.0

var map: MapDef
var spec: BusSpec
var options := {}
var world: GameWorld
var bus: Bus
var horn: Horn
var camera_rig: CameraRig
var player_input: PlayerInput
var run: RunController
var ui: CanvasLayer
var hud: Hud
var touch_controls: TouchControls
var results_panel: ResultsPanel


static func create(map_def: MapDef, bus_spec: BusSpec, session_options := {}) -> DriveSession:
	var session := DriveSession.new()
	session.name = "DriveSession"
	session.map = map_def
	session.spec = bus_spec
	session.options = session_options
	return session


func _ready() -> void:
	world = GameWorld.create(map)
	add_child(world)

	bus = Bus.create(spec)
	add_child(bus)
	bus.global_transform = spawn_transform()
	_apply_performance(options.get("performance", {}))
	horn = Horn.new()
	bus.add_child(horn)

	camera_rig = CameraRig.new()
	camera_rig.target = bus
	add_child(camera_rig)

	var run_seed: int = options.get("seed", randi())
	run = RunController.create(map, bus, run_seed)
	add_child(run)

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
	run.stop_served.connect(_on_stop_served)
	run.stop_missed.connect(_on_stop_missed)
	run.run_finished.connect(_on_run_finished)
	_refresh_hud()


## Where the bus starts: kerb lane, just past the start of the loop, wheels just above ground.
func spawn_transform() -> Transform3D:
	var xform := world.track.vehicle_transform(0, SPAWN_OFFSET)
	xform.origin.y = 0.3
	return xform


func _apply_performance(factors: Dictionary) -> void:
	bus.top_speed_factor = factors.get("top_speed", 1.0)
	bus.acceleration_factor = factors.get("acceleration", 1.0)
	bus.brake_factor = factors.get("brakes", 1.0)
	bus.handling_factor = factors.get("handling", 1.0)


func _process(_delta: float) -> void:
	_refresh_hud()


func _refresh_hud() -> void:
	hud.show_speed(bus.speed_kmh())
	var next := run.next_stop()
	hud.show_next_stop(next.stop_name if next else "", run.distance_to_next_stop())
	hud.show_passengers(run.route.on_board_count(), spec.capacity)
	hud.show_fares(run.route.earnings_so_far())


func _on_stop_served(stop_index: int, alighted: int, boarded: int, left_behind: int) -> void:
	var text := "%s: %d on, %d off" % [map.stop_name(stop_index), boarded, alighted]
	if left_behind > 0:
		text += " — bus full, %d left behind" % left_behind
	hud.flash(text)


func _on_stop_missed(stop_index: int) -> void:
	hud.flash("Missed %s!" % map.stop_name(stop_index))


func _on_run_finished(result: Dictionary) -> void:
	bus.controls_enabled = false
	touch_controls.visible = false
	results_panel = ResultsPanel.create(result)
	results_panel.continue_pressed.connect(exit_requested.emit)
	ui.add_child(results_panel)
	run_finished.emit(result)
