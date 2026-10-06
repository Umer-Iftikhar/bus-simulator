class_name BusSpec
extends RefCounted
## Static description of a bus model: size, capacity and base performance.

var id := "minibus"
var display_name := "Minibus"
var capacity := 12
var mass := 3500.0
## Total engine force (N) shared by the traction wheels at full throttle.
var engine_force := 9000.0
## Brake value applied to VehicleBody3D at full pedal.
var brake_force := 60.0
var max_steer := 0.55
## Top speed in metres per second.
var top_speed := 19.0
var length := 7.0
var width := 2.3
var height := 2.8
var color := Color(0.95, 0.75, 0.2)
## Body style: "minibus", "city", "double_decker" or "coach".
var style := "city"


static func from_dict(data: Dictionary) -> BusSpec:
	var spec := BusSpec.new()
	for key in data:
		if key in spec:
			spec.set(key, data[key])
	return spec


func duplicate_spec() -> BusSpec:
	var copy := BusSpec.new()
	for prop in get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			copy.set(prop["name"], get(prop["name"]))
	return copy


## Length of the bonnet ahead of the cab (vans/minibuses); 0 for flat-fronted buses.
func cab_offset() -> float:
	return 0.9 if style == "minibus" else 0.0


## Windscreen lean-back in radians (minibus and coach have raked screens).
func windscreen_rake() -> float:
	if style == "coach":
		return 0.24
	if style == "minibus":
		return 0.3
	return 0.0


## Window bottoms as a fraction of body height (coaches sit high).
func belt_fraction() -> float:
	return 0.47 if style == "coach" else 0.38


func wheelbase() -> float:
	return length * 0.62


func top_speed_kmh() -> float:
	return top_speed * 3.6
