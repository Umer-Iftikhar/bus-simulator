class_name RouteRun
extends RefCounted
## Pure state of one run along a route: who waits where, who is on board,
## which stops were served or missed, and what the run pays.
##
## Stops are served strictly in order. Stop 0 is the start terminal and the
## last stop is the end terminal; serving the end terminal completes the run.

signal stop_served(stop_index: int, alighted: int, boarded: int, left_behind: int)
signal stop_missed(stop_index: int)
signal finished

var stop_count := 0
var capacity := 0
var fare := 0
var passengers: Array[Passenger] = []
var next_stop := 0
var delivered := 0
var missed_stops: Array[int] = []
var failed := false


static func create(
	stops: int, bus_capacity: int, fare_per_passenger: int, riders: Array[Passenger]
) -> RouteRun:
	assert(stops >= 2, "a route needs two terminals")
	var run := RouteRun.new()
	run.stop_count = stops
	run.capacity = bus_capacity
	run.fare = fare_per_passenger
	run.passengers = riders
	return run


func is_finished() -> bool:
	return next_stop >= stop_count


func is_terminal(stop_index: int) -> bool:
	return stop_index == stop_count - 1


func on_board() -> Array[Passenger]:
	var riding: Array[Passenger] = []
	for p in passengers:
		if p.state == Passenger.State.ON_BOARD:
			riding.append(p)
	return riding


func on_board_count() -> int:
	return on_board().size()


func waiting_at(stop_index: int) -> int:
	var count := 0
	for p in passengers:
		if p.state == Passenger.State.WAITING and p.board_stop == stop_index:
			count += 1
	return count


func stranded_count() -> int:
	var count := 0
	for p in passengers:
		if p.state == Passenger.State.STRANDED:
			count += 1
	return count


## Passengers alight (paying if this is their stop), then waiting passengers board.
## Returns {"alighted", "boarded", "left_behind"}.
func serve_stop(stop_index: int) -> Dictionary:
	if is_finished() or failed or stop_index != next_stop:
		return {"alighted": 0, "boarded": 0, "left_behind": 0}
	var alighted := 0
	for p in on_board():
		if p.dest_stop == stop_index:
			p.state = Passenger.State.DELIVERED
			delivered += 1
			alighted += 1
		elif p.dest_stop < stop_index:
			# Their stop was missed: they get off here, annoyed, without paying.
			p.state = Passenger.State.STRANDED
			alighted += 1
	var boarded := 0
	var left_behind := 0
	var seats := capacity - on_board_count()
	for p in passengers:
		if p.state != Passenger.State.WAITING or p.board_stop != stop_index:
			continue
		if boarded < seats:
			p.state = Passenger.State.ON_BOARD
			boarded += 1
		else:
			p.state = Passenger.State.STRANDED
			left_behind += 1
	next_stop += 1
	stop_served.emit(stop_index, alighted, boarded, left_behind)
	if is_finished():
		finished.emit()
	return {"alighted": alighted, "boarded": boarded, "left_behind": left_behind}


## The bus drove past [param stop_index] without stopping. Terminals cannot be skipped.
func skip_stop(stop_index: int) -> bool:
	if is_finished() or failed or stop_index != next_stop or is_terminal(stop_index):
		return false
	for p in passengers:
		if p.state == Passenger.State.WAITING and p.board_stop == stop_index:
			p.state = Passenger.State.STRANDED
	missed_stops.append(stop_index)
	next_stop += 1
	stop_missed.emit(stop_index)
	return true


## The bus was wrecked: the run ends with no pay.
func fail() -> void:
	failed = true


func earnings_so_far() -> int:
	return delivered * fare


func payout() -> int:
	if failed or not is_finished():
		return 0
	return delivered * fare
