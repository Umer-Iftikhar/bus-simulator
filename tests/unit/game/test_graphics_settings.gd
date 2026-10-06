extends TestCase
## Graphics quality presets.

const KEYS := [
	"shadows", "shadow_distance", "msaa", "render_scale", "glow", "view_distance", "mirror_refresh"
]


func test_every_preset_is_complete_and_named() -> void:
	for preset in GraphicsSettings.PRESETS:
		assert_true(GraphicsSettings.is_valid(preset))
		var profile := GraphicsSettings.profile(preset)
		for key in KEYS:
			assert_true(profile.has(key), "%s missing %s" % [preset, key])
		assert_false(GraphicsSettings.display_name(preset).is_empty())
	assert_true(GraphicsSettings.is_valid(GraphicsSettings.DEFAULT))


func test_presets_get_strictly_better_from_low_to_ultra() -> void:
	var previous: Dictionary = {}
	for preset in GraphicsSettings.PRESETS:
		var p := GraphicsSettings.profile(preset)
		if not previous.is_empty():
			assert_ge(p["render_scale"], previous["render_scale"], preset)
			assert_ge(p["shadow_distance"], previous["shadow_distance"], preset)
			assert_gt(p["view_distance"], previous["view_distance"], preset)
			assert_ge(p["msaa"], previous["msaa"], preset)
			assert_le(p["mirror_refresh"], previous["mirror_refresh"], preset)
		previous = p


func test_low_is_a_real_battery_saver() -> void:
	var low := GraphicsSettings.profile("low")
	assert_false(low["shadows"])
	assert_false(low["glow"])
	assert_lt(low["render_scale"], 1.0)
	assert_gt(low["mirror_refresh"], 1)


func test_unknown_preset_uses_default() -> void:
	assert_eq(
		GraphicsSettings.profile("potato"), GraphicsSettings.profile(GraphicsSettings.DEFAULT)
	)
	assert_false(GraphicsSettings.is_valid("potato"))
