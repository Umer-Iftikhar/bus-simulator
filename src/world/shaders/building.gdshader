shader_type spatial;
// Building facade: photo brick or concrete walls (picked per building) with a
// procedural grid of windows per floor, a darker ground floor and a concrete
// roof. Lit windows glow at night. Colours are per-instance so every building
// shares one material.

instance uniform vec4 wall_color : source_color = vec4(0.8, 0.78, 0.72, 1.0);
instance uniform float building_seed = 0.0;
uniform vec4 glass_color : source_color = vec4(0.16, 0.22, 0.3, 1.0);
uniform float floor_height = 3.2;
uniform float window_spacing = 2.4;
uniform float night = 0.0;
uniform sampler2D brick_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D brick_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Fraction of buildings faced in brick; the rest are rendered concrete.
uniform float brick_share = 0.3;
// Metres covered by one copy of each wall texture.
uniform float brick_tile = 2.0;
uniform float concrete_tile = 3.0;

varying vec3 local_pos;
varying vec3 local_normal;
varying float world_y;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec3 albedo = wall_color.rgb;
	float roughness = 0.85;
	float metallic = 0.0;
	vec3 emission = vec3(0.0);
	vec3 normal_map = vec3(0.5, 0.5, 1.0);
	bool brick = hash(vec2(building_seed, 7.3)) < brick_share;
	if (abs(local_normal.y) < 0.5) {
		float u = abs(local_normal.x) > abs(local_normal.z) ? local_pos.z : local_pos.x;
		float v = world_y;
		if (brick) {
			vec2 wall_uv = vec2(u, v) / brick_tile;
			// Natural brick, nudged toward the building colour.
			albedo = texture(brick_albedo, wall_uv).rgb * mix(vec3(1.0), wall_color.rgb * 1.5, 0.3);
			normal_map = texture(brick_normal, wall_uv).rgb;
		} else {
			vec2 wall_uv = vec2(u, v) / concrete_tile;
			albedo = texture(concrete_albedo, wall_uv).rgb * wall_color.rgb * 1.7;
			normal_map = texture(concrete_normal, wall_uv).rgb;
		}
		float cell_u = fract(u / window_spacing);
		float cell_v = fract(v / floor_height);
		float level = floor(v / floor_height);
		// Subtle per-floor variation keeps facades from looking flat.
		albedo *= 0.92 + 0.08 * hash(vec2(level, building_seed));
		bool is_window = cell_u > 0.18 && cell_u < 0.82 && cell_v > 0.3 && cell_v < 0.82;
		if (level < 1.0) {
			// Ground floor: shopfront band.
			albedo *= 0.55;
			is_window = cell_u > 0.08 && cell_u < 0.92 && cell_v > 0.15 && cell_v < 0.75;
		}
		if (is_window) {
			albedo = glass_color.rgb * (0.85 + 0.3 * hash(vec2(floor(u / window_spacing), level + building_seed)));
			roughness = 0.08;
			metallic = 0.5;
			normal_map = vec3(0.5, 0.5, 1.0);
			float pick = hash(vec2(floor(u / window_spacing) + building_seed, level));
			float lit = step(0.68, pick);
			vec3 warm = mix(vec3(1.0, 0.72, 0.4), vec3(0.85, 0.9, 1.0), step(0.9, pick));
			emission = warm * lit * night * 0.9;
		}
	} else {
		vec2 roof_uv = local_pos.xz / concrete_tile;
		albedo = texture(concrete_albedo, roof_uv).rgb * 0.75;
		normal_map = texture(concrete_normal, roof_uv).rgb;
		roughness = 0.95;
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission;
	NORMAL_MAP = normal_map;
	NORMAL_MAP_DEPTH = 0.7;
}
