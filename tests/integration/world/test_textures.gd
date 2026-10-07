extends TestCase
## Photo textures: every set ships in 480 / 720 / 1080, imports as a mipmapped
## GPU texture, and the world's surfaces use the size the graphics preset picks.


func after_each() -> void:
	WorldLook.texture_size = 720


func test_every_texture_ships_in_every_size() -> void:
	for set_name in WorldLook.TEXTURE_SETS:
		for size in WorldLook.TEXTURE_SIZES:
			for kind in ["albedo", "normal"]:
				var path := WorldLook.texture_path(set_name, kind, size)
				var texture := load(path) as Texture2D
				assert_not_null(texture, path)
				if texture != null:
					assert_eq(texture.get_width(), size, path)
					assert_eq(texture.get_height(), size, path)
		var rough := load(WorldLook.texture_path(set_name, "rough")) as Texture2D
		assert_not_null(rough, "%s roughness" % set_name)


func test_textures_import_compressed_with_mipmaps() -> void:
	for set_name in WorldLook.TEXTURE_SETS:
		var path := WorldLook.texture_path(set_name, "albedo", 1080)
		var config := ConfigFile.new()
		assert_eq(config.load(path + ".import"), OK, path)
		assert_eq(config.get_value("params", "compress/mode"), 2, "%s VRAM compressed" % path)
		assert_true(config.get_value("params", "mipmaps/generate"), "%s mipmaps" % path)
		var normal := ConfigFile.new()
		normal.load(WorldLook.texture_path(set_name, "normal", 1080) + ".import")
		assert_eq(normal.get_value("params", "compress/normal_map"), 1, "%s normal map" % set_name)


func test_textures_are_credited() -> void:
	var credits := FileAccess.get_file_as_string(WorldLook.TEXTURE_DIR + "/LICENSE.md")
	assert_true(credits.contains("CC0"))
	for set_name in WorldLook.TEXTURE_SETS:
		assert_true(credits.contains("`%s_*`" % set_name), set_name)


func test_road_pavement_and_kerb_use_photo_textures() -> void:
	for material in [WorldLook.asphalt(), WorldLook.sidewalk(), WorldLook.kerb()]:
		assert_not_null(material.albedo_texture)
		assert_true(material.normal_enabled)
		assert_not_null(material.normal_texture)
		assert_not_null(material.roughness_texture)
		assert_true(material.uv1_world_triplanar, "no UVs needed")
	assert_eq(
		WorldLook.asphalt().albedo_texture.resource_path,
		WorldLook.texture_path("asphalt", "albedo", 720)
	)


func test_texture_size_follows_the_graphics_setting() -> void:
	for preset in GraphicsSettings.PRESETS:
		var session := DriveSession.create(
			Maps.islamabad(), BusSpec.new(), {"seed": 1, "traffic": false, "graphics": preset}
		)
		add_child_autofree(session)
		var size: int = GraphicsSettings.profile(preset)["texture_size"]
		assert_eq(WorldLook.texture_size, size, preset)
		var node := session.world.find_child("Asphalt", true, false)
		var road := node as MeshInstance3D
		if road == null:
			road = node.find_children("*", "MeshInstance3D", true, false)[0]
		var material := road.material_override as StandardMaterial3D
		if material == null:
			material = road.mesh.surface_get_material(0) as StandardMaterial3D
		assert_eq(material.albedo_texture.get_width(), size, "%s road texture" % preset)
		session.free()


func test_terrain_blends_ground_dirt_and_rock() -> void:
	for map in [Maps.rawalakot(), Maps.new_york()]:
		var material := WorldLook.terrain(map)
		for param in [
			"base_albedo",
			"base_normal",
			"patch_albedo",
			"patch_normal",
			"rock_albedo",
			"rock_normal"
		]:
			assert_not_null(material.get_shader_parameter(param), "%s %s" % [map.id, param])
	var city := WorldLook.terrain(Maps.new_york()).get_shader_parameter("base_albedo") as Texture2D
	var hills := (
		WorldLook.terrain(Maps.rawalakot()).get_shader_parameter("base_albedo") as Texture2D
	)
	assert_true(city.resource_path.contains("paving"), "paved ground in New York")
	assert_true(hills.resource_path.contains("grass"), "grassy ground in Rawalakot")


func test_buildings_are_brick_or_concrete() -> void:
	var material := WorldLook.building(Maps.new_york())
	for param in ["brick_albedo", "brick_normal", "concrete_albedo", "concrete_normal"]:
		assert_not_null(material.get_shader_parameter(param), param)
	var nyc: float = material.get_shader_parameter("brick_share")
	var tokyo: float = WorldLook.building(Maps.tokyo()).get_shader_parameter("brick_share")
	assert_gt(nyc, tokyo, "New York has more brick than Tokyo")


func test_terrain_mesh_carries_rock_cover_and_tangents() -> void:
	var ground := Terrain.create(Maps.rawalakot()).build()
	add_child_autofree(ground)
	var mesh := (ground.find_child("TerrainMesh", true, false) as MeshInstance3D).mesh
	var arrays := mesh.surface_get_arrays(0)
	assert_not_null(arrays[Mesh.ARRAY_TANGENT], "tangents for normal maps")
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var rocky := 0
	for cover in uv2:
		if cover.x > 0.5:
			rocky += 1
	assert_gt(rocky, 0, "Rawalakot has rocky slopes")
