class_name Autopilot
extends RefCounted
## Test helper that drives a [Bus] around a [Track] through the *player's*
## input actions (accelerate / brake / steer_left / steer_right), so system
## tests exercise exactly the same code path as a human on a keyboard.

const LOOKAHEAD := 14.0
const STEER_GAIN := 2.6
const COMFORT_DECEL := 1.6

var bus: Bus
var track: Track
## Optional: when set, the autopilot keeps a safe distance from cars ahead.
var traffic: TrafficManager
var lane := 0
var cruise_speed := 11.0
## Offset (m along loop) to stop at, or -1 to keep driving.
var stop_at := -1.0


func _init(target_bus: Bus, target_track: Track) -> void:
	bus = target_bus
	track = target_track


## Call once per physics frame.
func step() -> void:
	var offset := track.closest_offset(bus.global_position)
	var aim := track.lane_position(lane, offset + LOOKAHEAD)
	var local := bus.global_transform.affine_inverse() * aim
	var angle := atan2(local.x, local.z)
	_set_axis(clampf(-angle * STEER_GAIN, -1.0, 1.0))

	var target_speed := cruise_speed
	if stop_at >= 0.0:
		var remaining := track.distance_ahead(offset, stop_at)
		if remaining > track.length() - 20.0:
			remaining = 0.0
		target_speed = minf(cruise_speed, sqrt(2.0 * COMFORT_DECEL * maxf(remaining - 1.0, 0.0)))
	target_speed = minf(target_speed, _traffic_limit())
	var speed := bus.forward_speed()
	if target_speed < 0.3:
		_set_pedals(0.0, 1.0 if speed > 0.05 else 0.0)
	elif speed < target_speed - 0.5:
		_set_pedals(1.0, 0.0)
	elif speed > target_speed + 1.0:
		_set_pedals(0.0, clampf((speed - target_speed) / 4.0, 0.2, 1.0))
	else:
		_set_pedals(0.35, 0.0)


## Drives to and pulls up at every remaining stop of [param run] in order.
## [param skip] lists stop indices to drive straight past. Returns true when
## the run finished within the time limit.
func drive_route(
	tree: SceneTree, run: RunController, skip: Array = [], seconds_per_stop := 240.0
) -> bool:
	while not run.finished:
		var index := run.route.next_stop
		stop_at = -1.0 if skip.has(index) else run.map.stop_offset(index)
		var ticks := int(seconds_per_stop * Engine.physics_ticks_per_second)
		var advanced := false
		for i in ticks:
			step()
			await tree.physics_frame
			if run.finished or run.route.next_stop != index:
				advanced = true
				break
		if not advanced:
			release()
			return false
	release()
	stop_at = -1.0
	return true


## Highest safe speed given the nearest car ahead in our lane.
func _traffic_limit() -> float:
	if traffic == null:
		return INF
	var car := traffic.nearest_ahead(bus.global_position, lane, 80.0)
	if car == null:
		return INF
	var bus_front := track.closest_offset(bus.global_position) + bus.spec.length / 2.0
	var gap := track.distance_ahead(bus_front, car.rear_offset())
	if gap > 70.0:
		return INF
	return maxf(
		0.0,
		minf(
			car.speed + (gap - 10.0) * 0.4,
			sqrt(2.0 * COMFORT_DECEL * maxf(gap - 6.0, 0.0)) + car.speed
		)
	)


func stopped() -> bool:
	return absf(bus.forward_speed()) < 0.3


func release() -> void:
	for action in ["accelerate", "brake", "steer_left", "steer_right"]:
		Input.action_release(action)


func _set_pedals(throttle: float, brake: float) -> void:
	_press("accelerate", throttle)
	_press("brake", brake)


func _set_axis(value: float) -> void:
	_press("steer_right", maxf(value, 0.0))
	_press("steer_left", maxf(-value, 0.0))


static func _press(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)
