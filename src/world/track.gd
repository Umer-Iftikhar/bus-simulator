class_name Track
extends RefCounted
## A closed-loop road described by a smooth centre line.
##
## Traffic drives one way around the loop on [constant LANE_COUNT] lanes.
## Lane 0 is the right-hand (kerb) lane where bus stops sit; lane 1 is the
## left-hand overtaking lane. "Offset" means distance along the loop in metres.

const LANE_WIDTH := 3.5
const LANE_COUNT := 2
const SHOULDER := 0.6
const BAKE_INTERVAL := 0.5
## Catmull-Rom handle scale; each handle is also capped relative to its segment.
const SMOOTHING := 1.0 / 6.0
const MAX_HANDLE_RATIO := 0.4

var curve := Curve3D.new()
var _length := 0.0


static func from_points(points: PackedVector2Array) -> Track:
	assert(points.size() >= 3, "a track needs at least three control points")
	var track := Track.new()
	track.curve.bake_interval = BAKE_INTERVAL
	var count := points.size()
	for i in count + 1:
		var p := points[i % count]
		var prev := points[(i - 1 + count) % count]
		var next := points[(i + 1) % count]
		var tangent := (next - prev) * SMOOTHING
		var handle_in := tangent.limit_length(p.distance_to(prev) * MAX_HANDLE_RATIO)
		var handle_out := tangent.limit_length(p.distance_to(next) * MAX_HANDLE_RATIO)
		track.curve.add_point(
			Vector3(p.x, 0.0, p.y),
			Vector3(-handle_in.x, 0.0, -handle_in.y),
			Vector3(handle_out.x, 0.0, handle_out.y)
		)
	track._length = track.curve.get_baked_length()
	return track


func length() -> float:
	return _length


func wrap_offset(offset: float) -> float:
	return fposmod(offset, _length)


## Distance travelled going forward from [param from_offset] to [param to_offset].
func distance_ahead(from_offset: float, to_offset: float) -> float:
	return fposmod(to_offset - from_offset, _length)


func position_at(offset: float) -> Vector3:
	return curve.sample_baked(wrap_offset(offset), true)


func forward_at(offset: float) -> Vector3:
	var ahead := position_at(offset + 1.0)
	var behind := position_at(offset - 1.0)
	var dir := ahead - behind
	dir.y = 0.0
	return dir.normalized()


func right_at(offset: float) -> Vector3:
	return forward_at(offset).cross(Vector3.UP).normalized()


## Signed lateral distance from the centre line to the middle of [param lane].
static func lane_lateral(lane: int) -> float:
	return LANE_WIDTH * (0.5 - lane)


func lane_position(lane: int, offset: float) -> Vector3:
	return position_at(offset) + right_at(offset) * lane_lateral(lane)


## Transform for a vehicle in [param lane] at [param offset] (+Z forward).
func vehicle_transform(lane: int, offset: float) -> Transform3D:
	var forward := forward_at(offset)
	var basis := Basis(Vector3.UP.cross(forward), Vector3.UP, forward)
	return Transform3D(basis, lane_position(lane, offset))


func closest_offset(world_pos: Vector3) -> float:
	return curve.get_closest_offset(Vector3(world_pos.x, 0.0, world_pos.z))


## Signed distance to the right of the centre line (positive = right of travel).
func lateral_of(world_pos: Vector3) -> float:
	var offset := closest_offset(world_pos)
	var d := world_pos - position_at(offset)
	d.y = 0.0
	return d.dot(right_at(offset))


func half_width() -> float:
	return LANE_WIDTH * LANE_COUNT / 2.0 + SHOULDER


## Lane containing [param world_pos], or -1 when off the road.
func lane_at(world_pos: Vector3) -> int:
	return lane_for_lateral(lateral_of(world_pos))


func lane_for_lateral(lateral: float) -> int:
	if absf(lateral) > half_width():
		return -1
	return 0 if lateral >= 0.0 else 1


## Heading error between [param direction] and the road at [param offset] (radians, 0..PI).
func heading_error(offset: float, direction: Vector3) -> float:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.is_zero_approx():
		return 0.0
	return forward_at(offset).angle_to(flat.normalized())
