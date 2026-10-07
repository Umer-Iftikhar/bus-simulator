class_name TrafficManager
extends Node3D
## Spawns AI cars on the loop and drives them each physics step. Every car
## follows the nearest vehicle ahead in its lane — another car, or the
## player's bus when the bus overlaps that lane — using [CarFollow].
## This is the deliberately "dumb first" traffic from the design doc: fixed
## lanes, no lane changes.

const COLORS := [
	Color(0.8, 0.1, 0.1),
	Color(0.1, 0.3, 0.8),
	Color(0.9, 0.9, 0.9),
	Color(0.15, 0.15, 0.15),
	Color(0.2, 0.6, 0.3),
	Color(0.95, 0.6, 0.1),
]
## How far ahead cars look for a leader.
const LOOK_AHEAD := 150.0
## Cars are not spawned this close (behind, ahead) to the bus's start position.
const SPAWN_CLEAR_BEHIND := 25.0
const SPAWN_CLEAR_AHEAD := 70.0
## Extra lateral margin when deciding which lanes the bus occupies.
const LANE_MARGIN := 0.3

var track: Track
var bus: Bus
## Lane the player is signalling into (see [Indicators]); -1 when not signalling.
var signal_lane := -1
## When set, a share of cars wear this colour (NYC yellow cabs).
var taxi_color := Color.TRANSPARENT
var cars: Array[TrafficCar] = []
var follow := CarFollow.new()


static func create(on_track: Track, player_bus: Bus) -> TrafficManager:
	var manager := TrafficManager.new()
	manager.name = "Traffic"
	manager.track = on_track
	manager.bus = player_bus
	return manager


## Places [param count] cars spread over both lanes, clear of [param bus_offset].
func spawn(count: int, seed_value: int, bus_offset: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var length := track.length()
	var usable := length - SPAWN_CLEAR_BEHIND - SPAWN_CLEAR_AHEAD
	for i in count:
		var lane := i % Track.LANE_COUNT
		var slot := float(i) / count
		var offset := bus_offset + SPAWN_CLEAR_AHEAD + usable * slot + rng.randf_range(-4.0, 4.0)
		var color: Color = COLORS[i % COLORS.size()]
		if taxi_color != Color.TRANSPARENT and rng.randf() < 0.4:
			color = taxi_color
		var car := TrafficCar.create(track, lane, offset, color)
		car.name = "Car%d" % i
		car.desired_speed = rng.randf_range(8.5, 12.5)
		car.speed = car.desired_speed * 0.6
		cars.append(car)
		add_child(car)


func _physics_process(delta: float) -> void:
	var bus_state := _bus_state()
	var accelerations: Array[float] = []
	for car in cars:
		var leader := _leader_of(car, bus_state)
		var accel := follow.acceleration(
			car.speed, car.desired_speed, leader["gap"], leader["speed"]
		)
		car.yielding = leader["yield"]
		if car.yielding:
			accel = maxf(accel, -GiveWay.MAX_YIELD_DECEL)
		accelerations.append(accel)
	for i in cars.size():
		cars[i].advance(accelerations[i], delta)


## Gap and speed of whatever is directly ahead of [param car] in its lane.
func _leader_of(car: TrafficCar, bus_state: Dictionary) -> Dictionary:
	var best_gap := INF
	var best_speed := 0.0
	var yielding := false
	for other in cars:
		if other == car or other.lane != car.lane:
			continue
		var gap := track.distance_ahead(car.front_offset(), other.rear_offset())
		if gap < best_gap and gap < LOOK_AHEAD:
			best_gap = gap
			best_speed = other.speed
	if not bus_state.is_empty() and car.lane in bus_state["lanes"]:
		# Only a bus whose centre is ahead of the car's centre is an obstacle;
		# overlapping bumpers mean "stop now" (gap 0).
		var ahead := track.distance_ahead(car.offset, bus_state["center"])
		if ahead < LOOK_AHEAD:
			var gap := maxf(ahead - bus_state["length"] / 2.0 - TrafficCar.LENGTH / 2.0, 0.0)
			if gap < best_gap:
				best_gap = gap
				best_speed = maxf(bus_state["speed"], 0.0)
	elif not bus_state.is_empty():
		var ahead := track.distance_ahead(car.offset, bus_state["center"])
		if GiveWay.should_yield(car.lane, signal_lane, ahead, bus_state["length"]):
			var gap := GiveWay.virtual_gap(ahead, bus_state["length"], TrafficCar.LENGTH)
			if gap < best_gap:
				best_gap = gap
				best_speed = maxf(bus_state["speed"], 0.0)
				yielding = true
	return {"gap": best_gap, "speed": best_speed, "yield": yielding}


func _bus_state() -> Dictionary:
	if not is_instance_valid(bus):
		return {}
	var offset := track.closest_offset(bus.global_position)
	var lateral := track.lateral_of(bus.global_position)
	var lanes := lanes_occupied(lateral, bus.spec.width / 2.0 + LANE_MARGIN)
	return {
		"center": offset,
		"length": bus.spec.length,
		"speed": bus.forward_speed(),
		"lanes": lanes,
	}


## Lanes overlapped by a vehicle centred [param lateral] metres right of the
## centre line with half-width [param half_width].
static func lanes_occupied(lateral: float, half_width: float) -> Array[int]:
	var lanes: Array[int] = []
	for lane in Track.LANE_COUNT:
		var centre := Track.lane_lateral(lane)
		if absf(lateral - centre) < Track.LANE_WIDTH / 2.0 + half_width:
			lanes.append(lane)
	return lanes


## Car ahead of [param world_pos] in [param lane] within [param max_distance], if any.
func nearest_ahead(world_pos: Vector3, lane: int, max_distance: float) -> TrafficCar:
	var from := track.closest_offset(world_pos)
	var best: TrafficCar = null
	var best_distance := max_distance
	for car in cars:
		if car.lane != lane:
			continue
		var distance := track.distance_ahead(from, car.rear_offset())
		if distance < best_distance:
			best_distance = distance
			best = car
	return best
