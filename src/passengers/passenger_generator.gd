class_name PassengerGenerator
extends RefCounted
## Deterministically creates the passengers waiting along a route.

const MIN_PER_STOP := 10
const MAX_PER_STOP := 22
## Share of riders commuting to the end terminal; the rest pick any later stop.
## Long trips keep big buses full, which is what makes buying up pay off.
const TERMINAL_BIAS := 0.45


## One batch of passengers for a route of [param stop_count] stops. Nobody waits
## at the final terminal; every destination lies further along the route.
static func generate(
	stop_count: int, seed_value: int, min_per_stop := MIN_PER_STOP, max_per_stop := MAX_PER_STOP
) -> Array[Passenger]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var passengers: Array[Passenger] = []
	for stop in stop_count - 1:
		var count := rng.randi_range(min_per_stop, max_per_stop)
		for i in count:
			var dest := stop_count - 1
			if rng.randf() >= TERMINAL_BIAS:
				dest = rng.randi_range(stop + 1, stop_count - 1)
			passengers.append(Passenger.make(passengers.size(), stop, dest))
	return passengers
