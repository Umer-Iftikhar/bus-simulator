class_name Track
extends RefCounted
## A closed-loop road described by a smooth centre line.
##
## Traffic drives one way around the loop on [constant LANE_COUNT] lanes.
## Lane 0 is the right-hand (kerb) lane where bus stops sit; lane 1 is the
## left-hand overtaking lane. "Offset" means distance along the loop in metres.
##
## The centre line is laid out on the flat (x, z) plane; road elevation is a
## separate smooth height profile along the loop (hills, bridge ramps), so
## offsets, lanes and lateral distances are unaffected by slopes.

const LANE_WIDTH := 3.5
const LANE_COUNT := 2
const SHOULDER := 0.6
const BAKE_INTERVAL := 0.5
## Catmull-Rom handle scale; each handle is also capped relative to its segment.
const SMOOTHING := 1.0 / 6.0
const MAX_HANDLE_RATIO := 0.4

var curve := Curve3D.new()
var _length := 0.0
## Control-point heights and their offsets along the loop.
var _heights := PackedFloat32Array()
var _height_offsets := PackedFloat32Array()


static func from_points(points: PackedVector2Array, heights := PackedFloat32Array()) -> Track:
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
	if heights.size() == count:
		track._heights = heights
		for p in points:
			track._height_offsets.append(track.curve.get_closest_offset(Vector3(p.x, 0.0, p.y)))
		track._height_offsets[0] = 0.0
	return track


## Road surface height at [param offset]: a cubic Hermite spline through the
## control-point heights, so slopes change smoothly (no kinks at ramp ends).
func elevation_at(offset: float) -> float:
	var count := _heights.size()
	if count == 0:
		return 0.0
	var o := wrap_offset(offset)
	var i := count - 1
	for k in count:
		var start := _height_offsets[k]
		var end := _length if k == count - 1 else _height_offsets[k + 1]
		if o >= start and o < end:
			i = k
			break
	var j := (i + 1) % count
	var start_offset := _height_offsets[i]
	var segment := distance_ahead(start_offset, _height_offsets[j])
	if segment <= 0.0:
		segment = _length
	var t := distance_ahead(start_offset, o) / segment
	var t2 := t * t
	var t3 := t2 * t
	return (
		(2.0 * t3 - 3.0 * t2 + 1.0) * _heights[i]
		+ (t3 - 2.0 * t2 + t) * segment * _slope(i)
		+ (-2.0 * t3 + 3.0 * t2) * _heights[j]
		+ (t3 - t2) * segment * _slope(j)
	)


func _slope(k: int) -> float:
	var count := _heights.size()
	var prev := (k - 1 + count) % count
	var next := (k + 1) % count
	var span := distance_ahead(_height_offsets[prev], _height_offsets[next])
	return (_heights[next] - _heights[prev]) / span if span > 0.0 else 0.0


## Road gradient (rise over run) at [param offset].
func grade_at(offset: float) -> float:
	return (elevation_at(offset + 2.0) - elevation_at(offset - 2.0)) / 4.0


func has_elevation() -> bool:
	return not _heights.is_empty()


func length() -> float:
	return _length


func wrap_offset(offset: float) -> float:
	return fposmod(offset, _length)


## Distance travelled going forward from [param from_offset] to [param to_offset].
func distance_ahead(from_offset: float, to_offset: float) -> float:
	return fposmod(to_offset - from_offset, _length)


func position_at(offset: float) -> Vector3:
	var flat := curve.sample_baked(wrap_offset(offset), true)
	flat.y = elevation_at(offset)
	return flat


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


## Transform for a vehicle in [param lane] at [param offset] (+Z forward),
## pitched to follow the slope of the road.
func vehicle_transform(lane: int, offset: float) -> Transform3D:
	var flat := forward_at(offset)
	var forward := (flat + Vector3.UP * grade_at(offset)).normalized()
	var side := Vector3.UP.cross(flat).normalized()
	var up := forward.cross(side).normalized()
	return Transform3D(Basis(side, up, forward), lane_position(lane, offset))


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
