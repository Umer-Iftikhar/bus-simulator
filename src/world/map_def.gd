class_name MapDef
extends RefCounted
## Data for one hand-crafted map: road layout, stops, pay and scenery theme.

var id := ""
var display_name := ""
var description := ""
## Fare paid per delivered passenger.
var fare := 10
var scenery_seed := 1
var points := PackedVector2Array()
## Stop positions as fractions of the loop (0..1). First = start terminal, last = end terminal.
var stops: Array[float] = []
var traffic_cars := 0
var ground_color := Color(0.35, 0.5, 0.3)
var sky_top := Color(0.35, 0.55, 0.85)
var sky_horizon := Color(0.75, 0.82, 0.9)
var building_colors: Array[Color] = [Color(0.8, 0.78, 0.72)]
var building_height := Vector2(6, 18)
var building_spacing := 28.0
var tree_chance := 0.3
var tree_color := Color(0.2, 0.45, 0.2)
var has_water := false
var sun_elevation := 50.0
var night := false

var _track: Track


func track() -> Track:
	if _track == null:
		_track = Track.from_points(points)
	return _track


func stop_offset(index: int) -> float:
	return stops[index] * track().length()
