class_name MapDef
extends RefCounted
## Data for one hand-crafted map: road layout and elevation, stops, pay,
## terrain, water, city style, landmarks and backdrop.

var id := ""
var display_name := ""
var description := ""
## Fare paid per delivered passenger.
var fare := 10
var scenery_seed := 1
var points := PackedVector2Array()
## Road height (m) at each control point; empty = flat.
var heights := PackedFloat32Array()
## Stop positions as fractions of the loop (0..1). First = start terminal, last = end terminal.
var stops: Array[float] = []
var stop_names := PackedStringArray()
var traffic_cars := 0

# --- Look -------------------------------------------------------------------
var ground_color := Color(0.35, 0.5, 0.3)
var sky_top := Color(0.35, 0.55, 0.85)
var sky_horizon := Color(0.75, 0.82, 0.9)
var cloud_cover := 0.45
var sun_elevation := 50.0
var night := false

# --- City -------------------------------------------------------------------
## Building style: "nyc", "tokyo", "washington", "islamabad" or "rawalakot".
var style := "nyc"
var building_colors: Array[Color] = [Color(0.8, 0.78, 0.72)]
## Floors (3.2 m each) for street-front buildings; the row behind is taller.
var floors := Vector2i(3, 8)
## Length of a city block between side streets (min, max metres).
var block_length := Vector2(60.0, 90.0)
var side_streets := true
## Chance a plot holds trees instead of a building.
var tree_chance := 0.1
var tree_color := Color(0.2, 0.45, 0.2)
## Pine trees instead of broadleaf trees.
var conifers := false
## Parks (rectangles on the x/z plane) filled with trees and grass.
var parks: Array[Rect2] = []
## {"type": String, "at": Vector2, "rotation": float}
var landmarks: Array[Dictionary] = []

# --- Terrain and water --------------------------------------------------------
## Height (m) of rolling hills / mountains away from the road; 0 = flat city.
var terrain_amplitude := 0.0
## Base plane gradient (rise per metre along x and z).
var terrain_slope := Vector2.ZERO
var water_level := -3.0
var river_bed := -8.0
## {"points": PackedVector2Array, "width": float}
var rivers: Array[Dictionary] = []
## {"center": Vector2, "radius": float}
var lakes: Array[Dictionary] = []
## Control-point index ranges [start, end] whose road is a bridge deck.
var bridges: Array[Vector2i] = []
## "suspension" or "arch"
var bridge_style := "suspension"
## Distant scenery: "skyline", "mountains", "fuji" or "hills_north".
var backdrop := "skyline"
var backdrop_height := 250.0

var _track: Track
var _bridge_ranges: Array[Vector2] = []
var _bridge_ranges_ready := false


func track() -> Track:
	if _track == null:
		_track = Track.from_points(points, heights)
	return _track


func stop_offset(index: int) -> float:
	return stops[index] * track().length()


func stop_name(index: int) -> String:
	if index < stop_names.size():
		return stop_names[index]
	if index == 0:
		return "%s Terminal" % display_name.split(" ")[0]
	if index == stops.size() - 1:
		return "End Terminal"
	return "Stop %d" % index


## Offsets [from, to] of every bridge deck along the loop.
func bridge_ranges() -> Array[Vector2]:
	if _bridge_ranges_ready:
		return _bridge_ranges
	_bridge_ranges_ready = true
	var ranges: Array[Vector2] = _bridge_ranges
	var t := track()
	for bridge in bridges:
		var a := t.closest_offset(Vector3(points[bridge.x].x, 0, points[bridge.x].y))
		var b := t.closest_offset(Vector3(points[bridge.y].x, 0, points[bridge.y].y))
		ranges.append(Vector2(a, b))
	return ranges


func on_bridge(offset: float) -> bool:
	var t := track()
	for r in bridge_ranges():
		if t.distance_ahead(r.x, offset) <= t.distance_ahead(r.x, r.y):
			return true
	return false
