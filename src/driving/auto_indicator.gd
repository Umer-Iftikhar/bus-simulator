class_name AutoIndicator
extends RefCounted
## Automatic turn signals (the "Automatic" indicator setting). Signals right
## when closing on the next stop, left when pulling out after serving one, and
## toward the neighbouring lane when the bus drifts across at speed. It only
## acts when its wish changes, so the driver can still override by hand.

## Start signalling into the stop this far before it (m).
const STOP_DISTANCE := 90.0
## Signal to pull out for this long after a stop is served (s)...
const PULL_OUT_TIME := 8.0
## ...or until the bus is moving this fast again (m/s).
const PULL_OUT_SPEED := 7.0
## Sideways speed toward another lane that counts as changing lanes (m/s).
const DRIFT_SPEED := 0.8
## Ignore drift below this road speed (m/s), e.g. while manoeuvring.
const DRIFT_MIN_SPEED := 4.0

var _wanted := Indicators.Turn.NONE


## The signal a careful driver would show right now. [param drift] is the
## sideways speed toward the left (+) or right (-) lane; [param since_served]
## the seconds since the last stop was served (INF if none yet).
static func desired(
	distance_to_stop: float, lane: int, speed: float, drift: float, since_served: float
) -> Indicators.Turn:
	if lane < 0:
		return Indicators.Turn.NONE
	if since_served < PULL_OUT_TIME and speed < PULL_OUT_SPEED and lane == 0:
		return Indicators.Turn.LEFT
	if distance_to_stop > 0.5 and distance_to_stop <= STOP_DISTANCE:
		return Indicators.Turn.RIGHT
	if absf(speed) >= DRIFT_MIN_SPEED and absf(drift) >= DRIFT_SPEED:
		var toward := Indicators.Turn.LEFT if drift > 0.0 else Indicators.Turn.RIGHT
		if Indicators.lane_toward(toward, lane) != -1:
			return toward
	return Indicators.Turn.NONE


## Applies a change of wish to [param indicators]. Does nothing while the wish
## is unchanged, so a manual press sticks until the situation changes.
func apply(indicators: Indicators, wish: Indicators.Turn, lane: int) -> void:
	if wish == _wanted:
		return
	if wish == Indicators.Turn.NONE:
		if indicators.side == _wanted:
			indicators.cancel()
	elif indicators.side != wish:
		if wish == Indicators.Turn.LEFT:
			indicators.toggle_left(lane)
		else:
			indicators.toggle_right(lane)
	_wanted = wish
