class_name Indicators
extends RefCounted
## Turn-signal state: toggled by the driver, blinks, and cancels itself once a
## signalled lane change has been completed (or after a long timeout).

## Emitted with the new [enum Turn] value.
signal changed(side: int)

enum Turn { NONE, LEFT, RIGHT }

const BLINK_PERIOD := 0.8
## The bus must sit in the target lane this long before the signal cancels.
const SETTLE_TIME := 1.0
const TIMEOUT := 25.0

var side := Turn.NONE
## Lane the signal is asking to move into, or -1 when there is no such lane.
var target_lane := -1
var _phase := 0.0
var _settled := 0.0
var _elapsed := 0.0


func toggle_left(current_lane: int) -> void:
	_toggle(Turn.LEFT, current_lane)


func toggle_right(current_lane: int) -> void:
	_toggle(Turn.RIGHT, current_lane)


func cancel() -> void:
	if side == Turn.NONE:
		return
	side = Turn.NONE
	target_lane = -1
	changed.emit(side)


func is_active() -> bool:
	return side != Turn.NONE


## Lamp state for the current blink phase.
func lamp_on() -> bool:
	return is_active() and _phase < BLINK_PERIOD / 2.0


func left_lamp() -> bool:
	return side == Turn.LEFT and lamp_on()


func right_lamp() -> bool:
	return side == Turn.RIGHT and lamp_on()


## Advances the blink and checks for auto-cancel. [param current_lane] is the
## lane the bus is in now (-1 when off the road).
func update(delta: float, current_lane: int) -> void:
	if not is_active():
		return
	_phase = fmod(_phase + delta, BLINK_PERIOD)
	_elapsed += delta
	if target_lane != -1 and current_lane == target_lane:
		_settled += delta
		if _settled >= SETTLE_TIME:
			cancel()
			return
	else:
		_settled = 0.0
	if _elapsed >= TIMEOUT:
		cancel()


## Lane a signal toward [param toward] leads to from [param current_lane].
## Lane 0 is the kerb (right) lane and lane 1 the left lane.
static func lane_toward(toward: Turn, current_lane: int) -> int:
	if current_lane < 0:
		return -1
	var target := current_lane + (1 if toward == Turn.LEFT else -1)
	return target if target >= 0 and target < Track.LANE_COUNT else -1


func _toggle(toward: Turn, current_lane: int) -> void:
	if side == toward:
		cancel()
		return
	side = toward
	target_lane = lane_toward(toward, current_lane)
	_phase = 0.0
	_settled = 0.0
	_elapsed = 0.0
	changed.emit(side)
