class_name RunController
extends Node
## Drives one route run in the 3D world: places the stops, tracks how far the
## bus has travelled, detects when it pulls up at (or drives past) the next
## stop, and reports the result when the end terminal is served.

signal stop_served(stop_index: int, alighted: int, boarded: int, left_behind: int)
signal stop_missed(stop_index: int)
signal run_finished(result: Dictionary)

## Extra distance past a stop zone before the stop counts as missed.
const PASS_MARGIN := 3.0

var map: MapDef
var bus: Bus
var track: Track
var route: RouteRun
var stops: Array[BusStop] = []
var dwell := StopDwell.new()
## Distance travelled along the loop since the run started (negative when reversing).
var progress := 0.0
var finished := false
var _run_seed := 0
var _last_offset := 0.0
var _stop_progress: Array[float] = []


static func create(map_def: MapDef, target_bus: Bus, run_seed: int) -> RunController:
	var controller := RunController.new()
	controller.name = "RunController"
	controller.map = map_def
	controller.bus = target_bus
	controller.track = map_def.track()
	controller._run_seed = run_seed
	return controller


func _ready() -> void:
	var stop_count := map.stops.size()
	for i in stop_count:
		var terminal := i == 0 or i == stop_count - 1
		var stop := BusStop.create(i, map.stop_name(i), track, map.stop_offset(i), terminal)
		stops.append(stop)
		add_child(stop)
	var riders := PassengerGenerator.generate(stop_count, _run_seed)
	route = RouteRun.create(stop_count, bus.spec.capacity, map.fare, riders)
	_last_offset = track.closest_offset(bus.global_position)
	for i in stop_count:
		_stop_progress.append(track.distance_ahead(_last_offset, map.stop_offset(i)))
	for stop in stops:
		stop.set_waiting(route.waiting_at(stop.stop_index))


func next_stop() -> BusStop:
	return null if route.is_finished() else stops[route.next_stop]


## Metres from the bus to the next stop along the road (0 when inside its zone).
func distance_to_next_stop() -> float:
	if route.is_finished():
		return 0.0
	return maxf(_stop_progress[route.next_stop] - progress, 0.0)


func _physics_process(delta: float) -> void:
	if finished or not is_instance_valid(bus):
		return
	_track_progress()
	var index := route.next_stop
	var stop := stops[index]
	if dwell.update(stop.bus_inside(), bus.forward_speed(), delta):
		_serve(index)
	elif not route.is_terminal(index) and _passed(index):
		route.skip_stop(index)
		dwell.reset()
		stop.set_waiting(0)
		stop_missed.emit(index)


func _track_progress() -> void:
	var offset := track.closest_offset(bus.global_position)
	var forward := track.distance_ahead(_last_offset, offset)
	var backward := track.distance_ahead(offset, _last_offset)
	if forward <= backward:
		progress += forward
	else:
		progress -= backward
	_last_offset = offset


func _passed(index: int) -> bool:
	var clear_of_zone := BusStop.ZONE_LENGTH / 2.0 + bus.spec.length / 2.0 + PASS_MARGIN
	return progress > _stop_progress[index] + clear_of_zone


func _serve(index: int) -> void:
	var outcome := route.serve_stop(index)
	stops[index].set_waiting(route.waiting_at(index))
	stop_served.emit(index, outcome["alighted"], outcome["boarded"], outcome["left_behind"])
	if route.is_finished():
		_finish()


## Ends the run without pay (e.g. the bus was wrecked).
func fail_run() -> void:
	if finished:
		return
	route.fail()
	_finish()


func _finish() -> void:
	finished = true
	run_finished.emit(result())


func result() -> Dictionary:
	return {
		"map": map.id,
		"completed": route.is_finished() and not route.failed,
		"failed": route.failed,
		"delivered": route.delivered,
		"stranded": route.stranded_count(),
		"missed_stops": route.missed_stops.size(),
		"fare": route.fare,
		"payout": route.payout(),
	}
