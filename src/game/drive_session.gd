class_name DriveSession
extends Node3D
## One driving session on a map: builds the world, spawns the bus, runs the
## route and wires the camera, HUD, touch controls and player input together.
##
## Options (all optional):
##   "performance": {top_speed, acceleration, brakes, handling} multipliers
##   "seed": int seed for passengers and traffic (random when absent)
##   "damage": DamageModel dictionary the bus starts with (default pristine)
##   "traffic": bool, spawn AI traffic (default true)
##   "mirror_refresh": int, render mirrors every Nth frame (default 1)
##   "graphics": GraphicsSettings preset name (overrides mirror_refresh)
##   "cosmetics": {category: item id} visual customisation

signal run_finished(result: Dictionary)
signal exit_requested

const SPAWN_OFFSET := 6.0
## How long the doors stay open after a stop is served.
const DOOR_OPEN_SECONDS := 1.5

var map: MapDef
var spec: BusSpec
var options := {}
var world: GameWorld
var bus: Bus
var horn: Horn
var camera_rig: CameraRig
var player_input: PlayerInput
var run: RunController
var damage: DamageModel
var traffic: TrafficManager
var indicators := Indicators.new()
var mirrors: MirrorRig
var mirror_panel: MirrorPanel
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
	if options.has("cosmetics"):
		bus.apply_cosmetics(options["cosmetics"])
	_apply_performance(options.get("performance", {}))
	horn = Horn.new()
	bus.add_child(horn)
	bus.set_headlights(map.night)
	mirrors = MirrorRig.create(bus, options.get("mirror_refresh", 1))
	bus.add_child(mirrors)

	camera_rig = CameraRig.new()
	camera_rig.target = bus
	add_child(camera_rig)

	var run_seed: int = options.get("seed", randi())
	run = RunController.create(map, bus, run_seed)
	add_child(run)

	traffic = TrafficManager.create(world.track, bus)
	add_child(traffic)
	if options.get("traffic", true):
		traffic.spawn(map.traffic_cars, run_seed, SPAWN_OFFSET)

	damage = DamageModel.from_dict(options.get("damage", {}))

	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	mirror_panel = MirrorPanel.new()
	mirror_panel.visible = false
	ui.add_child(mirror_panel)
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
	camera_rig.mode_changed.connect(_on_camera_mode_changed)
	player_input.indicator_left_requested.connect(
		func() -> void: indicators.toggle_left(current_lane())
	)
	player_input.indicator_right_requested.connect(
		func() -> void: indicators.toggle_right(current_lane())
	)
	player_input.gear_requested.connect(_on_gear_requested)
	player_input.lights_requested.connect(bus.toggle_headlights)
	bus.gear_changed.connect(_on_gear_changed)
	run.stop_served.connect(_on_stop_served)
	run.stop_missed.connect(_on_stop_missed)
	run.run_finished.connect(_on_run_finished)
	bus.impact.connect(_on_impact)
	damage.changed.connect(_on_damage_changed)
	damage.part_damaged.connect(bus.set_part_health)
	damage.mirror_shattered.connect(_on_mirror_shattered)
	damage.wrecked.connect(_on_wrecked)
	_on_damage_changed()
	_show_initial_damage()
	if options.has("graphics"):
		GraphicsSettings.apply(
			options["graphics"], get_viewport(), world, camera_rig.camera, mirrors
		)
	_refresh_hud()


## Where the bus starts: kerb lane, just past the start of the loop, wheels just above ground.
func spawn_transform() -> Transform3D:
	var xform := world.track.vehicle_transform(0, SPAWN_OFFSET)
	xform.origin.y = 0.3
	return xform


## Lane the bus is in (-1 when off the road).
func current_lane() -> int:
	return world.track.lane_at(bus.global_position)


func _physics_process(delta: float) -> void:
	indicators.update(delta, current_lane())
	var left := indicators.left_lamp()
	var right := indicators.right_lamp()
	bus.set_indicator_lamps(left, right)
	bus.dash_left = left
	bus.dash_right = right
	touch_controls.show_headlights(bus.headlights_on)
	touch_controls.show_indicators(left, right)
	traffic.signal_lane = indicators.target_lane


func _on_gear_requested() -> void:
	if not bus.toggle_gear():
		hud.flash("Stop the bus to change gear")


func _on_gear_changed(reverse: bool) -> void:
	hud.show_gear(reverse)
	touch_controls.show_gear(reverse)


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


func _on_impact(part: String, impact_speed: float) -> void:
	if not run.finished:
		damage.apply_impact(part, impact_speed)


func _on_damage_changed() -> void:
	bus.damage_speed_factor = damage.speed_factor()
	bus.set_wear(1.0 - damage.overall())
	hud.show_health(damage.health_percent())


func _show_initial_damage() -> void:
	for part in DamageModel.PARTS:
		bus.set_part_health(part, damage.health(part))
	for part in DamageModel.MIRRORS:
		_show_mirror(part)
	mirror_panel.bind(mirrors)


func _show_mirror(part: String) -> void:
	var is_broken := damage.is_mirror_broken(part)
	mirrors.set_broken(part, is_broken)
	mirror_panel.set_broken(part, is_broken)
	bus.set_mirror_image(part, mirrors.texture(part), is_broken)


## Mirrors matter most from the driver's seat, so the mirror views show there.
func _on_camera_mode_changed(mode: CameraModes.Mode) -> void:
	mirror_panel.visible = mode == CameraModes.Mode.DRIVER


func _on_mirror_shattered(part: String) -> void:
	_show_mirror(part)
	hud.flash("%s mirror smashed!" % ("Left" if part == DamageModel.MIRROR_LEFT else "Right"))


func _on_wrecked() -> void:
	hud.flash("Bus wrecked!")
	run.fail_run()


func _on_stop_served(stop_index: int, alighted: int, boarded: int, left_behind: int) -> void:
	bus.open_doors()
	get_tree().create_timer(DOOR_OPEN_SECONDS, false, true).timeout.connect(_close_doors)
	var text := "%s: %d on, %d off" % [map.stop_name(stop_index), boarded, alighted]
	if left_behind > 0:
		text += " — bus full, %d left behind" % left_behind
	hud.flash(text)


func _close_doors() -> void:
	if is_instance_valid(bus):
		bus.close_doors()


func _on_stop_missed(stop_index: int) -> void:
	hud.flash("Missed %s!" % map.stop_name(stop_index))


func _on_run_finished(result: Dictionary) -> void:
	bus.controls_enabled = false
	touch_controls.visible = false
	results_panel = ResultsPanel.create(result)
	results_panel.continue_pressed.connect(exit_requested.emit)
	ui.add_child(results_panel)
	run_finished.emit(result)
