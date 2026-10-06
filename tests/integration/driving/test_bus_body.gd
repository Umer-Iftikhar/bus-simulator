extends TestCase
## The bus's visual shell: glass, shared paint, interior and draw-call budget.

const MAX_BUS_DRAW_ITEMS := 110


func _bus(bus_id := "city") -> Bus:
	var bus := Bus.create(Catalog.bus_spec(bus_id))
	autofree(bus)
	return bus


func test_all_glass_is_see_through_and_casts_no_shadow() -> void:
	var bus := _bus()
	assert_eq(bus.body.glass.size(), 4, "both sides, windscreen, rear window")
	for pane in bus.body.glass:
		var material := pane.material_override as StandardMaterial3D
		assert_ne(material.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, pane.name)
		assert_lt(material.albedo_color.a, 0.5, "%s is mostly clear" % pane.name)
		assert_eq(pane.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func test_painted_panels_share_one_material_that_tracks_paint_and_wear() -> void:
	var bus := _bus()
	assert_gt(bus.body.painted.size(), 4)
	for panel in bus.body.painted:
		assert_eq(panel.material_override, bus.body.paint_material, panel.name)
	bus.set_paint(Color.FOREST_GREEN)
	assert_eq(bus.body_color(), Color.FOREST_GREEN)
	bus.set_wear(1.0)
	assert_ne(bus.body_color(), Color.FOREST_GREEN, "worn paint looks different")
	assert_gt(bus.body.paint_material.roughness, 0.8, "and dull")


func test_interior_has_seats_wheel_and_dashboard() -> void:
	var bus := _bus()
	for part in ["Floor", "Dashboard", "SteeringWheel", "DriverSeat", "Cluster"]:
		assert_not_null(bus.body.find_child(part, true, false), part)
	assert_gt(bus.body.seats.multimesh.instance_count, 12, "rows of passenger seats")


func test_double_decker_has_an_upper_deck_with_more_seats() -> void:
	var single := _bus("long_city")
	var double := _bus("double_decker")
	assert_not_null(double.body.get_node_or_null("UpperDeck"))
	assert_null(single.body.get_node_or_null("UpperDeck"))
	assert_gt(
		double.body.seats.multimesh.instance_count, single.body.seats.multimesh.instance_count
	)


func test_destination_sign_is_readable_from_outside_only() -> void:
	var bus := _bus()
	var label := bus.body.get_node("DestinationText") as Label3D
	assert_eq(label.text, "CITY BUS")
	assert_false(label.double_sided, "no mirrored text across the windscreen")
	assert_is(bus.body.get_node("DestinationSign").mesh, QuadMesh)


func test_lights_glow() -> void:
	var bus := _bus()
	for lamp_name in ["HeadlightLens", "TailLight"]:
		var lamp := bus.body.get_node(lamp_name) as MeshInstance3D
		assert_true((lamp.material_override as StandardMaterial3D).emission_enabled, lamp_name)


func test_bus_stays_within_draw_budget() -> void:
	for bus_id in Catalog.bus_ids():
		var bus := _bus(bus_id)
		var items := bus.find_children("*", "GeometryInstance3D", true, false).size()
		assert_le(items, MAX_BUS_DRAW_ITEMS, "%s visual pieces (seats are one MultiMesh)" % bus_id)
