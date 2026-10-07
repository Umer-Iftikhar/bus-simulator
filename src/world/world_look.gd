class_name WorldLook
extends RefCounted
## Visual style of the world: lighting, sky and the textured materials used by
## [GameWorld]. Surfaces use real photo textures (CC0, see
## assets/textures/LICENSE.md) in three sizes picked by the graphics setting.

const BUILDING_SHADER := preload("res://src/world/shaders/building.gdshader")
const TERRAIN_SHADER := preload("res://src/world/shaders/terrain.gdshader")
const SKY_SHADER := preload("res://src/world/shaders/sky.gdshader")
const BACKDROPS := {"none": 0, "mountains": 1, "hills_north": 2, "fuji": 3, "skyline": 4}
## Horizon backdrops are drawn as if this far away (m) to turn heights into angles.
const BACKDROP_DISTANCE := 4000.0
const TEXTURE_DIR := "res://assets/textures"
const TEXTURE_SETS := ["asphalt", "paving", "brick", "concrete", "grass", "rock", "dirt"]
## Square texture sizes shipped for every set (px).
const TEXTURE_SIZES := [480, 720, 1080]
## Roughness maps carry little detail, so only the smallest size ships.
const ROUGHNESS_SIZE := 480
## Share of brick (rather than concrete) buildings per city style.
const BRICK_SHARE := {
	"nyc": 0.55, "washington": 0.45, "rawalakot": 0.3, "islamabad": 0.15, "tokyo": 0.1
}

## Texture size in use (px); set from the graphics preset before a world is built.
static var texture_size := 720


## The sky: gradient, sun/moon, clouds, stars and the map's painted horizon.
static func sky_material(map: MapDef) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("top_color", map.sky_top)
	material.set_shader_parameter("horizon_color", map.sky_horizon)
	material.set_shader_parameter("ground_color", map.ground_color.darkened(0.5))
	material.set_shader_parameter("cloud_cover", map.cloud_cover)
	material.set_shader_parameter("night", 1.0 if map.night else 0.0)
	material.set_shader_parameter("backdrop", BACKDROPS.get(map.backdrop, 0))
	material.set_shader_parameter("backdrop_angle", atan(map.backdrop_height / BACKDROP_DISTANCE))
	var far := Color(0.3, 0.36, 0.44) if map.backdrop != "skyline" else Color(0.42, 0.45, 0.52)
	if map.night:
		far = far.darkened(0.6)
	material.set_shader_parameter("backdrop_color", far)
	material.set_shader_parameter("seed", float(map.scenery_seed % 97) * 0.13)
	return material


static func environment(map: MapDef) -> Environment:
	var sky := Sky.new()
	sky.sky_material = sky_material(map)
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.3 if map.night else 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.6 if map.night else 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9 if map.night else 0.35
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	env.fog_enabled = true
	env.fog_light_color = map.sky_horizon
	env.fog_density = 0.004 if map.night else 0.0022
	env.fog_aerial_perspective = 0.4
	env.fog_sky_affect = 0.3
	return env


static func sun(map: MapDef) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-map.sun_elevation, 35.0, 0.0)
	# At night this is moonlight: weak, cool, but enough to read the road.
	light.light_energy = 0.55 if map.night else 1.25
	light.light_color = Color(0.6, 0.7, 1.0) if map.night else Color(1.0, 0.96, 0.88)
	light.shadow_enabled = true
	light.shadow_blur = 1.5
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 140.0
	return light


## A tileable grey-scale noise texture, generated once per material.
static func noise_texture(frequency: float, seed_value: int, size := 256) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = size
	texture.height = size
	texture.seamless = true
	texture.noise = noise
	return texture


## Material with a subtle noisy texture, projected in world space so meshes
## need no UVs. [param scale] is texture repeats per metre.
static func textured(
	color: Color,
	roughness: float,
	variation: float,
	scale: float,
	seed_value: int,
	frequency := 0.03
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var ramp := Gradient.new()
	ramp.set_color(0, color.darkened(variation))
	ramp.set_color(1, color.lightened(variation * 0.6))
	var texture := noise_texture(frequency, seed_value)
	texture.color_ramp = ramp
	material.albedo_texture = texture
	material.roughness = roughness
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


## Path of a texture file. [param kind] is "albedo", "normal" or "rough".
static func texture_path(set_name: String, kind: String, size := -1) -> String:
	if size < 0:
		size = texture_size
	if kind == "rough":
		size = ROUGHNESS_SIZE
	return "%s/%s_%s_%d.jpg" % [TEXTURE_DIR, set_name, kind, size]


static func texture(set_name: String, kind: String) -> Texture2D:
	return load(texture_path(set_name, kind)) as Texture2D


## A photo-textured material projected in world space (meshes need no UVs).
## [param tile] is how many metres one copy of the texture covers.
static func surface(set_name: String, tint: Color, tile: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture(set_name, "albedo")
	material.albedo_color = tint
	material.normal_enabled = true
	material.normal_texture = texture(set_name, "normal")
	material.normal_scale = 0.8
	material.roughness_texture = texture(set_name, "rough")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / tile
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


static func asphalt() -> StandardMaterial3D:
	return surface("asphalt", Color(0.85, 0.85, 0.87), 4.0)


static func sidewalk() -> StandardMaterial3D:
	return surface("paving", Color(0.95, 0.94, 0.92), 2.5)


static func kerb() -> StandardMaterial3D:
	return surface("concrete", Color.WHITE, 1.5)


## Terrain: grass with dirt patches (paving in dense cities), rock on cliffs.
static func terrain(map: MapDef) -> ShaderMaterial:
	var urban := map.style in ["nyc", "tokyo"]
	var base := "paving" if urban else "grass"
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	material.set_shader_parameter("base_albedo", texture(base, "albedo"))
	material.set_shader_parameter("base_normal", texture(base, "normal"))
	material.set_shader_parameter("patch_albedo", texture("dirt", "albedo"))
	material.set_shader_parameter("patch_normal", texture("dirt", "normal"))
	material.set_shader_parameter("rock_albedo", texture("rock", "albedo"))
	material.set_shader_parameter("rock_normal", texture("rock", "normal"))
	material.set_shader_parameter("patch_mask", noise_texture(0.02, map.scenery_seed))
	material.set_shader_parameter("base_tile", 2.5 if urban else 3.0)
	material.set_shader_parameter("patch_amount", 0.15 if urban else 0.35)
	return material


static func ground(map: MapDef) -> StandardMaterial3D:
	return textured(map.ground_color, 1.0, 0.18, 0.05, map.scenery_seed, 0.06)


static func road_paint() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.92, 0.86)
	material.roughness = 0.6
	return material


static func water() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.08, 0.3, 0.45)
	material.metallic = 0.4
	material.roughness = 0.04
	material.normal_enabled = true
	material.normal_texture = noise_texture(0.05, 3)
	material.normal_texture.as_normal_map = true
	material.normal_scale = 0.4
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.05
	return material


static func building(map: MapDef) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BUILDING_SHADER
	material.set_shader_parameter("night", 1.0 if map.night else 0.0)
	material.set_shader_parameter("brick_albedo", texture("brick", "albedo"))
	material.set_shader_parameter("brick_normal", texture("brick", "normal"))
	material.set_shader_parameter("concrete_albedo", texture("concrete", "albedo"))
	material.set_shader_parameter("concrete_normal", texture("concrete", "normal"))
	material.set_shader_parameter("brick_share", BRICK_SHARE.get(map.style, 0.3))
	return material


static func plain(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
