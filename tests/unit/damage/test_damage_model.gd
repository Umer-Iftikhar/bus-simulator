extends TestCase
## Localized damage: parts, weights, mirrors, wrecking, speed loss, repair.

var model: DamageModel
var spec := BusSpec.new()


func before_each() -> void:
	model = DamageModel.new()


func test_new_bus_is_pristine() -> void:
	assert_true(model.is_pristine())
	assert_almost_eq(model.overall(), 1.0, 0.0001)
	assert_eq(model.health_percent(), 100)
	assert_eq(model.speed_factor(), 1.0)
	assert_false(model.is_wrecked())
	assert_eq(model.to_dict(), {})


func test_weights_sum_to_one_and_cover_every_part() -> void:
	var total := 0.0
	for part in DamageModel.PARTS:
		total += DamageModel.WEIGHTS[part]
	assert_almost_eq(total, 1.0, 0.0001)


func test_light_contact_is_ignored() -> void:
	assert_eq(model.apply_impact(DamageModel.BODY_FRONT, DamageModel.MIN_IMPACT * 0.9), 0.0)
	assert_true(model.is_pristine())


func test_impact_damages_only_the_hit_panel() -> void:
	var lost := model.apply_impact(DamageModel.BODY_FRONT, 10.0)
	assert_almost_eq(lost, 10.0 * DamageModel.DAMAGE_PER_MS, 0.0001)
	assert_almost_eq(model.health(DamageModel.BODY_FRONT), 1.0 - lost, 0.0001)
	assert_eq(model.health(DamageModel.BODY_REAR), 1.0)
	assert_almost_eq(
		model.overall(), 1.0 - lost * DamageModel.WEIGHTS[DamageModel.BODY_FRONT], 0.0001
	)


func test_harder_hits_do_more_damage() -> void:
	var soft := DamageModel.new()
	soft.apply_impact(DamageModel.BODY_LEFT, 3.0)
	model.apply_impact(DamageModel.BODY_LEFT, 9.0)
	assert_lt(model.health(DamageModel.BODY_LEFT), soft.health(DamageModel.BODY_LEFT))


func test_panel_health_bottoms_out_at_zero() -> void:
	model.apply_impact(DamageModel.BODY_REAR, 500.0)
	assert_eq(model.health(DamageModel.BODY_REAR), 0.0)


func test_mirror_shatters_on_any_real_knock() -> void:
	watch_signals(model)
	model.apply_impact(DamageModel.MIRROR_LEFT, DamageModel.MIRROR_BREAK)
	assert_true(model.is_mirror_broken(DamageModel.MIRROR_LEFT))
	assert_false(model.is_mirror_broken(DamageModel.MIRROR_RIGHT))
	assert_signal_emitted(model, "mirror_shattered")
	assert_eq(get_signal_parameters(model, "mirror_shattered"), [DamageModel.MIRROR_LEFT])
	assert_false(model.is_mirror_broken(DamageModel.BODY_FRONT), "panels aren't mirrors")


func test_unknown_part_is_ignored() -> void:
	assert_eq(model.apply_impact("wing", 50.0), 0.0)
	assert_true(model.is_pristine())


func test_speed_factor_falls_with_health_and_never_below_minimum() -> void:
	var previous := 1.01
	for i in 30:
		model.apply_impact(DamageModel.PARTS[i % 4], 6.0)
		var factor := model.speed_factor()
		assert_le(factor, previous)
		assert_ge(factor, DamageModel.MIN_SPEED_FACTOR)
		previous = factor


func test_wrecked_when_every_panel_is_destroyed() -> void:
	watch_signals(model)
	for part in [DamageModel.BODY_FRONT, DamageModel.BODY_REAR, DamageModel.BODY_LEFT]:
		model.apply_impact(part, 100.0)
	assert_false(model.is_wrecked(), "one panel left")
	model.apply_impact(DamageModel.BODY_RIGHT, 100.0)
	assert_true(model.is_wrecked())
	assert_almost_eq(model.speed_factor(), DamageModel.MIN_SPEED_FACTOR, 0.0001)
	assert_signal_emit_count(model, "wrecked", 1)
	model.apply_impact(DamageModel.MIRROR_LEFT, 5.0)
	assert_signal_emit_count(model, "wrecked", 1, "wrecked only fires once")


func test_signals_on_damage() -> void:
	watch_signals(model)
	model.apply_impact(DamageModel.BODY_FRONT, 5.0)
	assert_signal_emit_count(model, "changed", 1)
	assert_eq(get_signal_parameters(model, "part_damaged")[0], DamageModel.BODY_FRONT)


func test_repair_restores_everything() -> void:
	model.apply_impact(DamageModel.BODY_FRONT, 50.0)
	model.apply_impact(DamageModel.MIRROR_RIGHT, 5.0)
	model.repair()
	assert_true(model.is_pristine())
	assert_false(model.is_mirror_broken(DamageModel.MIRROR_RIGHT))


func test_repair_cost_scales_with_damage_and_bus_price() -> void:
	assert_eq(model.repair_cost("minibus"), 0, "nothing to fix")
	model.apply_impact(DamageModel.BODY_FRONT, 5.0)
	var small := model.repair_cost("minibus")
	model.apply_impact(DamageModel.BODY_FRONT, 10.0)
	var bigger := model.repair_cost("minibus")
	assert_gt(small, 0)
	assert_gt(bigger, small)
	assert_gt(model.repair_cost("double_decker"), bigger, "fancier bus, pricier panels")
	assert_eq(bigger % 10, 0)


func test_broken_mirror_has_flat_repair_cost() -> void:
	model.apply_impact(DamageModel.MIRROR_LEFT, 2.0)
	assert_eq(model.repair_cost("minibus"), 120)


func test_dict_round_trip_and_clamping() -> void:
	model.apply_impact(DamageModel.BODY_LEFT, 7.0)
	model.apply_impact(DamageModel.MIRROR_RIGHT, 7.0)
	var copy := DamageModel.from_dict(model.to_dict())
	assert_eq(copy.parts, model.parts)
	var odd := DamageModel.from_dict({"body_front": 9.0, "body_rear": -1.0, "wing": 0.5})
	assert_eq(odd.health(DamageModel.BODY_FRONT), 1.0)
	assert_eq(odd.health(DamageModel.BODY_REAR), 0.0)
	assert_false(odd.parts.has("wing"))


func test_loaded_wreck_is_known_wrecked_without_signal() -> void:
	var data := {}
	for part in DamageModel.PARTS:
		data[part] = 0.0
	var wreck := DamageModel.from_dict(data)
	assert_true(wreck.is_wrecked())
	watch_signals(wreck)
	wreck.apply_impact(DamageModel.BODY_FRONT, 5.0)
	assert_signal_not_emitted(wreck, "wrecked")


func test_contact_normal_decides_the_face() -> void:
	var mid := Vector3(0.0, spec.height * 0.3, 0.0)
	# Normals point into the bus: a wall ahead pushes back (-Z), etc.
	var cases := {
		DamageModel.BODY_FRONT: Vector3(0, 0, -1),
		DamageModel.BODY_REAR: Vector3(0, 0, 1),
		DamageModel.BODY_LEFT: Vector3(-1, 0, 0),
		DamageModel.BODY_RIGHT: Vector3(1, 0, 0),
	}
	for part in cases:
		assert_eq(DamageModel.part_for_contact(mid, cases[part], spec), part, part)


func test_corner_contacts_follow_the_normal_not_the_point() -> void:
	var front_corner := Vector3(spec.width / 2.0 + 0.05, 0.6, spec.length / 2.0 - 0.05)
	assert_eq(
		DamageModel.part_for_contact(front_corner, Vector3(0, 0, -1), spec), DamageModel.BODY_FRONT
	)
	var rear_corner := Vector3(-spec.width / 2.0, 0.6, -spec.length / 2.0)
	assert_eq(
		DamageModel.part_for_contact(rear_corner, Vector3(0.3, 0, 0.9), spec), DamageModel.BODY_REAR
	)


func test_high_side_hit_near_the_front_breaks_a_mirror() -> void:
	var high_front_left := Vector3(spec.width / 2.0, spec.height * 0.8, spec.length / 2.0 - 0.3)
	var high_front_right := Vector3(-spec.width / 2.0, spec.height * 0.8, spec.length / 2.0 - 0.3)
	assert_eq(
		DamageModel.part_for_contact(high_front_left, Vector3(-1, 0, 0), spec),
		DamageModel.MIRROR_LEFT
	)
	assert_eq(
		DamageModel.part_for_contact(high_front_right, Vector3(1, 0, 0), spec),
		DamageModel.MIRROR_RIGHT
	)


func test_low_or_rearward_side_hits_are_body_panels() -> void:
	var low_front := Vector3(-spec.width / 2.0, 0.6, spec.length / 2.0 - 0.3)
	var high_middle := Vector3(-spec.width / 2.0, spec.height * 0.8, 0.0)
	assert_eq(
		DamageModel.part_for_contact(low_front, Vector3(1, 0, 0), spec), DamageModel.BODY_RIGHT
	)
	assert_eq(
		DamageModel.part_for_contact(high_middle, Vector3(1, 0, 0), spec), DamageModel.BODY_RIGHT
	)
