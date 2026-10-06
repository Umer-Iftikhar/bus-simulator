extends TestCase
## Regression: from the driver's seat the road ahead must be visible. Rays are
## cast from the driver's eye across the forward field of view and must not
## hit any opaque part of the bus (an opaque windscreen once blocked the view).

const YAW_LIMIT := 20.0
const PITCH_MIN := -12.0
const PITCH_MAX := 4.0


## Transform of [param node] relative to [param bus] (works outside the tree).
func _to_bus(node: Node3D, bus: Bus) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != bus and current is Node3D:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


func _is_opaque(instance: GeometryInstance3D) -> bool:
	var material: Material = instance.material_override
	if material == null and instance is MeshInstance3D:
		var mesh := (instance as MeshInstance3D).mesh
		if mesh is PrimitiveMesh:
			material = (mesh as PrimitiveMesh).material
	if material is BaseMaterial3D:
		return (material as BaseMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	return true


func _occluders(bus: Bus) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for node in bus.find_children("*", "GeometryInstance3D", true, false):
		var instance := node as GeometryInstance3D
		if not instance.visible or not _is_opaque(instance):
			continue
		var aabb: AABB
		if instance is MeshInstance3D and (instance as MeshInstance3D).mesh != null:
			aabb = (instance as MeshInstance3D).mesh.get_aabb()
		elif instance is MultiMeshInstance3D:
			aabb = (instance as MultiMeshInstance3D).multimesh.get_aabb()
		else:
			continue
		found.append({"name": String(instance.name), "aabb": _to_bus(instance, bus) * aabb})
	return found


func _blockers(bus: Bus) -> PackedStringArray:
	var spec := bus.spec
	var eye_xform := CameraModes.camera_transform(
		CameraModes.Mode.DRIVER, Transform3D.IDENTITY, spec
	)
	var eye := eye_xform.origin
	var occluders := _occluders(bus)
	var blocked := PackedStringArray()
	var yaw := -YAW_LIMIT
	while yaw <= YAW_LIMIT:
		var pitch := PITCH_MIN
		while pitch <= PITCH_MAX:
			var dir := (
				eye_xform.basis * Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0))
			)
			var ray: Vector3 = -dir.z
			for occluder in occluders:
				var hit = (occluder["aabb"] as AABB).intersects_ray(eye, ray)
				if hit != null and (hit as Vector3).distance_to(eye) < 30.0:
					var entry := "%s (yaw %d, pitch %d)" % [occluder["name"], yaw, pitch]
					if not blocked.has(entry):
						blocked.append(entry)
			pitch += 4.0
		yaw += 5.0
	return blocked


func test_every_bus_has_a_clear_view_ahead_from_the_driver_seat() -> void:
	for bus_id in Catalog.bus_ids():
		var bus := Bus.create(Catalog.bus_spec(bus_id))
		autofree(bus)
		var blocked := _blockers(bus)
		assert_eq(blocked.size(), 0, "%s driver view blocked by: %s" % [bus_id, ", ".join(blocked)])


func test_view_stays_clear_when_bus_is_damaged() -> void:
	var bus := Bus.create(Catalog.bus_spec("city"))
	autofree(bus)
	for part in DamageModel.PARTS:
		bus.set_part_health(part, 0.1)
	bus.set_wear(0.9)
	assert_eq(_blockers(bus).size(), 0, "dents and grime never black out the windscreen")


func test_the_check_detects_an_opaque_windscreen() -> void:
	# Guard the guard: an opaque pane where the windscreen is must be caught.
	var bus := Bus.create(Catalog.bus_spec("minibus"))
	autofree(bus)
	var pane := bus.body.get_node("Windscreen") as MeshInstance3D
	var opaque := StandardMaterial3D.new()
	opaque.albedo_color = Color.BLACK
	pane.material_override = opaque
	var blocked := _blockers(bus)
	assert_gt(blocked.size(), 0)
	assert_true(blocked[0].begins_with("Windscreen"), str(blocked))


func test_driver_eye_is_inside_the_cab_for_every_bus() -> void:
	for bus_id in Catalog.bus_ids():
		var spec := Catalog.bus_spec(bus_id)
		var eye := CameraModes.driver_seat(spec)
		var bus := Bus.create(spec)
		autofree(bus)
		assert_between(eye.y, bus.body.belt_line() + 0.3, spec.height - BusBody.ROOF - 0.1, bus_id)
		assert_le(eye.y, CameraModes.DRIVER_EYE_MAX, "%s driver sits low" % bus_id)
