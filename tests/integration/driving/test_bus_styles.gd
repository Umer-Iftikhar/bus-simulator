extends TestCase
## Visual bus types and how cosmetic choices show up on the bus.


func _bus(bus_id: String) -> Bus:
	var bus := Bus.create(Catalog.bus_spec(bus_id))
	autofree(bus)
	return bus


func test_minibus_has_a_bonnet_and_set_back_cab() -> void:
	var bus := _bus("minibus")
	assert_not_null(bus.body.get_node_or_null("Hood"))
	assert_not_null(bus.body.get_node_or_null("Grille"))
	var screen := bus.body.get_node("Windscreen") as Node3D
	assert_lt(screen.position.z, bus.spec.length / 2.0 - 0.6, "windscreen behind the bonnet")
	assert_lt(screen.rotation.x, -0.1, "raked windscreen")
	var mirror := Bus.mirror_mount(bus.spec, DamageModel.MIRROR_LEFT)
	assert_lt(mirror.z, bus.spec.length / 2.0 - bus.spec.cab_offset(), "mirrors at the cab")


func test_city_bus_is_flat_fronted() -> void:
	var bus := _bus("city")
	assert_null(bus.body.get_node_or_null("Hood"))
	var screen := bus.body.get_node("Windscreen") as Node3D
	assert_almost_eq(screen.rotation.x, 0.0, 0.0001)
	assert_not_null(bus.body.get_node_or_null("RearWindow"))


func test_coach_has_luggage_bays_and_no_rear_window() -> void:
	var bus := _bus("coach")
	assert_null(bus.body.get_node_or_null("RearWindow"), "engine at the back")
	var bays := bus.body.find_children("LuggageDoor*", "", false, false)
	assert_ge(bays.size(), 4)
	assert_lt((bus.body.get_node("Windscreen") as Node3D).rotation.x, -0.1)


func test_double_decker_has_two_decks() -> void:
	var bus := _bus("double_decker")
	assert_not_null(bus.body.get_node_or_null("UpperDeck"))
	assert_not_null(bus.body.get_node_or_null("DeckBandFront"))


func test_stripe_tint_rims_and_roof_apply() -> void:
	var bus := _bus("city")
	assert_false(bus.body.stripes[0].visible, "no stripe by default")
	bus.apply_cosmetics({"stripe": "red", "rims": "gold", "tint": "dark", "roof": "black"})
	for stripe in bus.body.stripes:
		assert_true(stripe.visible)
	assert_eq(
		bus.body.stripe_material.albedo_color, Catalog.cosmetic_entry("stripe", "red")["color"]
	)
	assert_eq(bus.rim_material.albedo_color, Catalog.cosmetic_entry("rims", "gold")["color"])
	assert_gt(bus.body.glass_material.albedo_color.a, 0.4, "dark side windows")
	assert_eq(bus.body.roof.material_override, bus.body.roof_material)
	assert_eq(bus.body.roof_material.albedo_color, Catalog.cosmetic_entry("roof", "black")["color"])


func test_windscreen_is_never_tinted() -> void:
	var bus := _bus("coach")
	bus.apply_cosmetics({"tint": "dark"})
	var screen := bus.body.get_node("Windscreen") as MeshInstance3D
	assert_eq(screen.material_override, bus.body.windscreen_material)
	assert_lt(bus.body.windscreen_material.albedo_color.a, 0.2, "driver can always see out")


func test_default_cosmetics_restore_the_factory_look() -> void:
	var bus := _bus("city")
	bus.apply_cosmetics({"stripe": "gold", "roof": "white", "rims": "chrome"})
	bus.apply_cosmetics({})
	assert_false(bus.body.stripes[0].visible)
	assert_eq(bus.body.roof.material_override, bus.body.paint_material, "roof matches the paint")
	assert_eq(bus.get_paint(), Catalog.bus_entry("city")["color"])


func test_garage_preview_shows_the_selected_bus_in_its_own_world() -> void:
	var preview := add_child_autofree(GaragePreview.new()) as GaragePreview
	preview.show_bus(Catalog.bus_spec("coach"), {"stripe": "gold"})
	assert_eq(preview.bus.spec.id, "coach")
	assert_true(preview.bus.body.stripes[0].visible)
	assert_true(preview.bus.freeze, "display model, not simulated")
	assert_true(preview.viewport.own_world_3d)
	var first := preview.bus
	preview.show_bus(Catalog.bus_spec("minibus"), {})
	assert_false(is_instance_valid(first), "old model replaced")
	var spin := preview.pivot.rotation.y
	await wait_process_frames(5)
	assert_ne(preview.pivot.rotation.y, spin, "turntable spins")
