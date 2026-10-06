class_name StopDwell
extends RefCounted
## Decides when the bus has properly pulled up at a stop: it must be inside the
## stop zone and (almost) stationary for [member dwell_time] seconds.

const STOPPED_SPEED := 0.8

var dwell_time := 1.0
var _timer := 0.0


## Returns true exactly once when the stop has been served.
func update(in_zone: bool, speed: float, delta: float) -> bool:
	if in_zone and absf(speed) < STOPPED_SPEED:
		_timer += delta
		if _timer >= dwell_time:
			_timer = 0.0
			return true
	else:
		_timer = 0.0
	return false


func progress() -> float:
	return clampf(_timer / dwell_time, 0.0, 1.0) if dwell_time > 0.0 else 1.0


func reset() -> void:
	_timer = 0.0
