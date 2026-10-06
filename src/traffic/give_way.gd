class_name GiveWay
extends RefCounted
## Courtesy rule for the player's signalled lane changes: cars in the lane the
## bus is signalling into, and behind it, drop back to open a gap for it.
##
## The yielding car treats the bus as if it were already in its lane, plus an
## extra margin, and never brake-checks harder than a comfortable stop.

## Only cars this far behind the bus (bumper to bumper) react to the signal.
const YIELD_ZONE := 45.0
## Extra room a yielding car leaves behind the bus.
const EXTRA_GAP := 4.0
## Hardest braking a yielding car will use (m/s²).
const MAX_YIELD_DECEL := 3.5


## True when a car in [param car_lane] should yield to a bus signalling into
## [param signal_lane]. [param centre_ahead] is how far the bus's centre is ahead
## of the car's centre along the road.
static func should_yield(
	car_lane: int, signal_lane: int, centre_ahead: float, bus_length: float
) -> bool:
	if signal_lane < 0 or car_lane != signal_lane:
		return false
	return centre_ahead > 0.0 and centre_ahead < YIELD_ZONE + bus_length


## The gap the yielding car should act on: as if the bus were already in its
## lane, minus the courtesy margin. Never negative.
static func virtual_gap(centre_ahead: float, bus_length: float, car_length: float) -> float:
	return maxf(centre_ahead - bus_length / 2.0 - car_length / 2.0 - EXTRA_GAP, 0.0)
