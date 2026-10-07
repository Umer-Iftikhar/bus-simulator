class_name GraphicsSettings
extends RefCounted
## Player-selectable graphics quality. Each preset trades looks for battery
## and frame rate on phones; [method apply] pushes a preset onto a live session.

const PRESETS := ["low", "medium", "high", "ultra"]
const DEFAULT := "medium"
const NAMES := {
	"low": "Low (battery saver)",
	"medium": "Medium",
	"high": "High",
	"ultra": "Ultra",
}
const PROFILES := {
	"low":
	{
		"texture_size": 480,
		"shadows": false,
		"shadow_distance": 0.0,
		"msaa": Viewport.MSAA_DISABLED,
		"render_scale": 0.7,
		"glow": false,
		"view_distance": 350.0,
		"mirror_refresh": 3,
	},
	"medium":
	{
		"texture_size": 720,
		"shadows": true,
		"shadow_distance": 70.0,
		"msaa": Viewport.MSAA_DISABLED,
		"render_scale": 0.85,
		"glow": true,
		"view_distance": 550.0,
		"mirror_refresh": 2,
	},
	"high":
	{
		"texture_size": 1080,
		"shadows": true,
		"shadow_distance": 140.0,
		"msaa": Viewport.MSAA_2X,
		"render_scale": 1.0,
		"glow": true,
		"view_distance": 900.0,
		"mirror_refresh": 1,
	},
	"ultra":
	{
		"texture_size": 1080,
		"shadows": true,
		"shadow_distance": 220.0,
		"msaa": Viewport.MSAA_4X,
		"render_scale": 1.0,
		"glow": true,
		"view_distance": 1400.0,
		"mirror_refresh": 1,
	},
}


static func is_valid(preset: String) -> bool:
	return PROFILES.has(preset)


static func profile(preset: String) -> Dictionary:
	return PROFILES.get(preset, PROFILES[DEFAULT])


static func display_name(preset: String) -> String:
	return NAMES.get(preset, NAMES[DEFAULT])


## Applies [param preset] to a running session's viewport, world, camera and mirrors.
static func apply(
	preset: String, viewport: Viewport, world: GameWorld, camera: Camera3D, mirrors: MirrorRig
) -> void:
	var p := profile(preset)
	viewport.msaa_3d = p["msaa"]
	viewport.scaling_3d_scale = p["render_scale"]
	var sun := world.get_node("Sun") as DirectionalLight3D
	sun.shadow_enabled = p["shadows"]
	sun.directional_shadow_max_distance = maxf(p["shadow_distance"], 1.0)
	var env := (world.get_node("Environment") as WorldEnvironment).environment
	env.glow_enabled = p["glow"]
	camera.far = p["view_distance"]
	if mirrors != null:
		mirrors.refresh_interval = p["mirror_refresh"]
