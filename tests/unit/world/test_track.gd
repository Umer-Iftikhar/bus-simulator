extends TestCase
## Geometry of the road centre line and lanes.

var track: Track


func before_each() -> void:
	track = Track.from_points(
		PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 200), Vector2(0, 200)])
	)


func _mid_first_side() -> float:
	return track.closest_offset(Vector3(100, 0, 0))


func test_length_is_close_to_control_polygon_perimeter() -> void:
	# The spline passes through every corner, bulging slightly outside the polygon.
	assert_between(track.length(), 800.0, 800.0 * 1.12)


func test_curve_passes_through_control_points() -> void:
	for corner in [Vector3(200, 0, 0), Vector3(200, 0, 200), Vector3(0, 0, 200)]:
		var nearest := track.position_at(track.closest_offset(corner))
		assert_vec3_almost_eq(nearest, corner, 0.3)


func test_loop_is_closed() -> void:
	assert_vec3_almost_eq(track.position_at(0.0), track.position_at(track.length()), 0.01)
	assert_vec3_almost_eq(track.position_at(-10.0), track.position_at(track.length() - 10.0), 0.01)


func test_wrap_offset_and_distance_ahead() -> void:
	var length := track.length()
	assert_almost_eq(track.wrap_offset(length + 5.0), 5.0, 0.001)
	assert_almost_eq(track.wrap_offset(-5.0), length - 5.0, 0.001)
	assert_almost_eq(track.distance_ahead(10.0, 30.0), 20.0, 0.001)
	assert_almost_eq(track.distance_ahead(length - 10.0, 10.0), 20.0, 0.001, "wraps the seam")


func test_forward_and_right_are_unit_horizontal_and_perpendicular() -> void:
	var step := track.length() / 37.0
	for i in 37:
		var offset := i * step
		var forward := track.forward_at(offset)
		var right := track.right_at(offset)
		assert_almost_eq(forward.length(), 1.0, 0.001)
		assert_almost_eq(right.length(), 1.0, 0.001)
		assert_almost_eq(forward.y, 0.0, 0.0001)
		assert_almost_eq(forward.dot(right), 0.0, 0.001)


func test_direction_on_first_side() -> void:
	var offset := _mid_first_side()
	assert_vec3_almost_eq(track.forward_at(offset), Vector3(1, 0, 0), 0.05)
	assert_vec3_almost_eq(track.right_at(offset), Vector3(0, 0, 1), 0.05, "right of +X is +Z")


func test_lane_lateral_offsets() -> void:
	assert_almost_eq(Track.lane_lateral(0), Track.LANE_WIDTH / 2, 0.0001)
	assert_almost_eq(Track.lane_lateral(1), -Track.LANE_WIDTH / 2, 0.0001)


func test_lane_positions_round_trip_through_lateral_and_lane_at() -> void:
	var step := track.length() / 23.0
	for i in 23:
		var offset := i * step
		for lane in Track.LANE_COUNT:
			var pos := track.lane_position(lane, offset)
			assert_almost_eq(track.lateral_of(pos), Track.lane_lateral(lane), 0.2)
			assert_eq(track.lane_at(pos), lane)


func test_lane_at_is_minus_one_off_road() -> void:
	var offset := _mid_first_side()
	var far := track.position_at(offset) + track.right_at(offset) * (track.half_width() + 3.0)
	assert_eq(track.lane_at(far), -1)
	assert_eq(track.lane_for_lateral(-track.half_width() - 0.1), -1)
	assert_eq(track.lane_for_lateral(0.0), 0)


func test_closest_offset_round_trip() -> void:
	for offset in [5.0, 120.0, 333.0, track.length() - 3.0]:
		var found := track.closest_offset(track.position_at(offset))
		var error := minf(track.distance_ahead(found, offset), track.distance_ahead(offset, found))
		assert_lt(error, 0.6, "offset %s" % offset)


func test_vehicle_transform_faces_along_road_and_is_orthonormal() -> void:
	var offset := _mid_first_side()
	var xform := track.vehicle_transform(0, offset)
	assert_vec3_almost_eq(xform.basis.z, track.forward_at(offset), 0.001)
	assert_vec3_almost_eq(xform.basis.y, Vector3.UP, 0.001)
	assert_almost_eq(xform.basis.determinant(), 1.0, 0.001)
	assert_vec3_almost_eq(xform.origin, track.lane_position(0, offset), 0.001)
	assert_vec3_almost_eq(xform.basis.x, -track.right_at(offset), 0.001, "+X is vehicle's left")


func test_heading_error() -> void:
	var offset := _mid_first_side()
	var forward := track.forward_at(offset)
	assert_almost_eq(track.heading_error(offset, forward), 0.0, 0.001)
	assert_almost_eq(track.heading_error(offset, -forward), PI, 0.001)
	assert_almost_eq(track.heading_error(offset, track.right_at(offset)), PI / 2, 0.001)
	assert_eq(track.heading_error(offset, Vector3.UP), 0.0, "vertical vector is ignored")
