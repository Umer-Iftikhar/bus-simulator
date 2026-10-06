shader_type spatial;
// Procedural building facade: a grid of windows per floor, a darker ground
// floor and a darker roof. Lit windows glow at night. Colours are per-instance
// so every building shares one material.

instance uniform vec4 wall_color : source_color = vec4(0.8, 0.78, 0.72, 1.0);
instance uniform float building_seed = 0.0;
uniform vec4 glass_color : source_color = vec4(0.16, 0.22, 0.3, 1.0);
uniform float floor_height = 3.2;
uniform float window_spacing = 2.4;
uniform float night = 0.0;

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
	if (abs(local_normal.y) < 0.5) {
		float u = abs(local_normal.x) > abs(local_normal.z) ? local_pos.z : local_pos.x;
		float v = world_y;
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
			float lit = step(0.55, hash(vec2(floor(u / window_spacing) + building_seed, level)));
			emission = vec3(1.0, 0.82, 0.5) * lit * night * 2.0;
		}
	} else {
		albedo *= 0.55;
		roughness = 0.95;
	}
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission;
}
