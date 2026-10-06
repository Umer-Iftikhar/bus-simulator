class_name Passenger
extends RefCounted
## A metro-style passenger with a fixed boarding stop and destination stop.

enum State { WAITING, ON_BOARD, DELIVERED, STRANDED }

var id := 0
var board_stop := 0
var dest_stop := 0
var state := State.WAITING


static func make(passenger_id: int, from_stop: int, to_stop: int) -> Passenger:
	assert(to_stop > from_stop, "destination must be after the boarding stop")
	var p := Passenger.new()
	p.id = passenger_id
	p.board_stop = from_stop
	p.dest_stop = to_stop
	return p
