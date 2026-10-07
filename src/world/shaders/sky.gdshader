shader_type sky;
// Procedural sky: gradient, sun / moon disk, clouds, stars at night, and a
// painted horizon backdrop (mountain ranges, Mount Fuji, northern hills or a
// distant city skyline). Painting the backdrop into the sky keeps it visible
// at any view distance for free. No TIME use, so the sky never re-renders.

uniform vec3 top_color : source_color = vec3(0.3, 0.5, 0.85);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.85, 0.9);
uniform vec3 ground_color : source_color = vec3(0.25, 0.25, 0.25);
uniform float cloud_cover = 0.45;
uniform float night = 0.0;
// 0 none, 1 mountains all round, 2 hills to the north, 3 Fuji, 4 skyline
uniform int backdrop = 0;
// Peak height of the backdrop as an elevation angle (radians).
uniform float backdrop_angle = 0.08;
uniform vec3 backdrop_color : source_color = vec3(0.32, 0.38, 0.46);
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Height of a mountain ridge (0..1) along the horizon.
float ridge(float az, float scale) {
	return fbm(vec2(az * scale + seed, seed * 0.37));
}

void sky() {
	vec3 d = EYEDIR;
	float elev = asin(clamp(d.y, -1.0, 1.0));
	float az = atan(d.x, d.z);

	vec3 col;
	if (d.y >= 0.0) {
		col = mix(horizon_color, top_color, clamp(pow(d.y, 0.45), 0.0, 1.0));
	} else {
		col = mix(horizon_color, ground_color, clamp(-d.y * 5.0, 0.0, 1.0));
	}

	// Sun (or moon) disk with a soft glow.
	float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
	vec3 disk = LIGHT0_COLOR * (night > 0.5 ? 1.2 : 6.0);
	col += disk * smoothstep(0.9993, 0.9997, s);
	col += LIGHT0_COLOR * pow(s, 10.0) * (night > 0.5 ? 0.05 : 0.25);

	// Stars.
	if (night > 0.5 && d.y > 0.0) {
		vec2 cell = floor(d.xz / (d.y + 0.35) * 260.0);
		float star = step(0.9975, hash(cell));
		col += vec3(star) * 0.9 * smoothstep(0.0, 0.25, d.y);
	}

	// Clouds on a virtual plane.
	if (d.y > 0.01) {
		vec2 uv = d.xz / (d.y + 0.12) * 0.55 + vec2(seed);
		float c = fbm(uv * 1.3);
		c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover * 0.35, c);
		vec3 lit = mix(vec3(1.0), horizon_color, 0.25);
		vec3 cloud = mix(lit, horizon_color * 0.35, night);
		col = mix(col, cloud, c * 0.85 * smoothstep(0.01, 0.2, d.y));
	}

	// Horizon backdrop silhouette.
	float top = -1.0;
	bool snow = false;
	if (backdrop == 1) {
		float near_range = backdrop_angle * (0.25 + 0.55 * ridge(az, 2.2));
		float far_range = backdrop_angle * (0.35 + 0.65 * ridge(az + 9.0, 3.4));
		top = max(near_range * 0.8, far_range);
		snow = elev > top - backdrop_angle * 0.14 && top > backdrop_angle * 0.62;
	} else if (backdrop == 2) {
		float north = smoothstep(1.45, 0.35, abs(az));
		top = backdrop_angle * north * (0.55 + 0.45 * ridge(az, 3.0));
	} else if (backdrop == 3) {
		float fuji_az = -1.5708;
		float cone = backdrop_angle * clamp(1.0 - abs(az - fuji_az) / 0.42, 0.0, 1.0);
		cone = min(cone, backdrop_angle * 0.92);
		float hills = backdrop_angle * 0.12 * ridge(az, 5.0);
		top = max(cone, hills);
		snow = cone > hills && elev > backdrop_angle * 0.62;
	} else if (backdrop == 4) {
		float bucket = floor(az * 70.0);
		float h = hash(vec2(bucket, seed));
		top = backdrop_angle * (0.12 + 0.88 * h * h);
		if (hash(vec2(bucket, seed + 3.0)) > 0.94) {
			top *= 1.6;
		}
	}
	if (top > 0.0 && elev < top && elev > -0.03) {
		vec3 c = backdrop_color;
		if (snow) {
			c = vec3(0.92, 0.94, 0.97);
		}
		if (backdrop == 4 && night > 0.5) {
			vec2 window = floor(vec2(az * 900.0, elev * 900.0));
			c += vec3(1.0, 0.75, 0.4) * step(0.86, hash(window)) * 0.9;
		}
		// Atmospheric haze: the lower parts fade into the horizon colour.
		float haze = 0.55 * (1.0 - clamp(elev / max(top, 0.001), 0.0, 1.0));
		c = mix(c, horizon_color, haze);
		col = c * (night > 0.5 ? 0.35 : 1.0) + (backdrop == 4 && night > 0.5 ? c * 0.6 : vec3(0.0));
	}
	COLOR = col;
}
