shader_type spatial;
// Terrain: photo-textured ground (grass or paving) with dirt patches, bare
// rock on cliffs and mountain tops, and snow on the highest peaks. Vertex
// colour tints the ground per map; UV2 carries rock (x) and snow (y) cover.

uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D patch_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D patch_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D patch_mask : filter_linear, repeat_enable;
// Metres covered by one copy of the ground texture.
uniform float base_tile = 3.0;
uniform float rock_tile = 8.0;
uniform float patch_amount = 0.35;
// How strongly the per-map vertex colour tints the photo texture.
uniform float tint = 0.55;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = world_pos.xz / base_tile;
	float mask = texture(patch_mask, world_pos.xz * 0.004).r;
	float dirt = smoothstep(0.9 - patch_amount, 1.1 - patch_amount, mask);
	vec3 ground = mix(texture(base_albedo, uv).rgb, texture(patch_albedo, uv * 0.8).rgb, dirt);
	vec3 ground_n = mix(texture(base_normal, uv).rgb, texture(patch_normal, uv * 0.8).rgb, dirt);
	// Tint toward the map ground colour while keeping the photo detail.
	ground = mix(ground, ground * COLOR.rgb * 2.2, tint);

	// Rock: projected sideways on cliffs, from above on gentle mountain tops.
	vec3 an = abs(world_normal);
	vec2 side_uv = (an.x > an.z ? world_pos.zy : world_pos.xy) / rock_tile;
	vec2 top_uv = world_pos.xz / rock_tile;
	float steep = smoothstep(0.55, 0.8, 1.0 - an.y);
	vec3 rock = mix(texture(rock_albedo, top_uv).rgb, texture(rock_albedo, side_uv).rgb, steep);
	vec3 rock_n = mix(texture(rock_normal, top_uv).rgb, texture(rock_normal, side_uv).rgb, steep);
	float rockiness = clamp(max(UV2.x, smoothstep(0.35, 0.6, 1.0 - world_normal.y)), 0.0, 1.0);

	vec3 albedo = mix(ground, rock, rockiness);
	vec3 normal_map = mix(ground_n, rock_n, rockiness);
	albedo = mix(albedo, vec3(0.9, 0.92, 0.96), UV2.y);
	ALBEDO = albedo;
	NORMAL_MAP = mix(normal_map, vec3(0.5, 0.5, 1.0), UV2.y * 0.7);
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = mix(0.95, 0.8, rockiness);
}
