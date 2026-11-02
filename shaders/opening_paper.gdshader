shader_type canvas_item;
render_mode unshaded;

uniform vec2 paper_center;
uniform vec2 paper_size;
uniform float phase = 0.0;
uniform float unfold : hint_range(0.0, 1.0) = 0.0;
uniform float idle_frame : hint_range(0.0, 1.0) = 0.0;
uniform bool shadow_pass = false;
// Optional clean frame for scans containing dark or tan exterior margins.
uniform float white_border_pixels = 0.0;
varying vec2 paper_point;

vec2 hash22(vec2 p) {
	// Keep the hash dot products in range on mediump canvas renderers.
	// Fine grain uses page-pixel coordinates, much larger than crease cells.
	p = mod(p, vec2(32.0));
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float soft_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash22(cell).x, hash22(cell + vec2(1.0, 0.0)).x, f.x),
		mix(hash22(cell + vec2(0.0, 1.0)).x, hash22(cell + vec2(1.0, 1.0)).x, f.x), f.y);
}

// Uneven polygonal folds, inspired by the shallow, irregular creases in
// the supplied paper photo. The same fold network has two held poses.
float crease_height(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	float frame_sign = idle_frame * 2.0 - 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 seed = hash22(cell + offset + vec2(phase));
			vec2 point = 0.15 + seed * 0.70 + sin(seed * 19.0) * frame_sign * 0.035;
			float distance = length(offset + point - f);
			if (distance < first) {
				second = first;
				first = distance;
			} else {
				second = min(second, distance);
			}
		}
	}
	float gap = second - first;
	return gap * 2.8 - exp(-gap * 22.0) * 0.55;
}

void vertex() {
	paper_point = VERTEX;
	vec2 local = VERTEX - paper_center;
	float open = 1.0 - pow(1.0 - unfold, 3.0);
	float crumple = pow(1.0 - unfold, 2.0);
	vec2 folds = vec2(
		sin(local.y * 0.052 + phase) * 34.0 + sin(local.x * 0.075 + local.y * 0.026) * 17.0,
		sin(local.x * 0.059 - phase) * 29.0 + cos(local.y * 0.081 - local.x * 0.031) * 18.0);
	vec2 spread = local * vec2(mix(0.045, 1.0, open), mix(0.075, 1.0, open));
	float angle = crumple * (0.18 * sin(phase + 0.8));
	spread = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * spread;
	vec2 seed = local / 84.0 + vec2(phase, -phase);
	float frame_sign = idle_frame * 2.0 - 1.0;
	vec2 wrinkles = vec2(soft_noise(seed + vec2(frame_sign * 0.11, 0.0)),
		soft_noise(seed.yx + vec2(9.0, frame_sign * 0.13))) * 2.0 - 1.0;
	VERTEX = paper_center + spread + folds * crumple + wrinkles * 2.1 * smoothstep(0.8, 1.0, unfold);
}

void fragment() {
	vec4 ink = texture(TEXTURE, UV);
	float crumple = pow(1.0 - unfold, 1.4);
	vec2 local = paper_point - paper_center;
	float ridge_a = sin(local.x * 0.075 + local.y * 0.026);
	float ridge_b = sin(local.y * 0.081 - local.x * 0.031);
	float valley = pow(1.0 - abs(ridge_a), 7.0) + pow(1.0 - abs(ridge_b), 9.0);
	float lighting = 1.0 + crumple * (0.17 * ridge_a + 0.12 * ridge_b - 0.35 * valley);
	float height = crease_height(paper_point / 73.0) * 5.0
		+ crease_height(paper_point / 29.0 + vec2(17.0, 9.0)) * 0.75;
	vec3 normal = normalize(vec3(-dFdx(height) * 1.5, -dFdy(height) * 1.5, 1.0));
	vec3 light = normalize(vec3(-0.55, -0.70, 1.5));
	float paper_light = clamp(dot(normal, light) / light.z, 0.84, 1.09);
	float grain = (hash22(floor(paper_point * 0.7)).x - 0.5) * 0.007;
	lighting *= mix(1.0, mix(1.0, paper_light, 0.24) + grain, smoothstep(0.75, 1.0, unfold));
	float appear = smoothstep(0.0, 0.07, unfold);
	if (shadow_pass) {
		COLOR = vec4(0.17, 0.12, 0.07, ink.a * 0.13 * appear);
	} else {
		vec3 painted = ink.rgb * lighting;
		if (white_border_pixels > 0.0) {
			vec2 to_edge = paper_size * 0.5 - abs(local);
			float distance_to_edge = min(to_edge.x, to_edge.y);
			float white_frame = 1.0 - smoothstep(white_border_pixels - 0.5, white_border_pixels + 0.5, distance_to_edge);
			painted = mix(painted, vec3(1.0), white_frame);
		}
		COLOR = vec4(painted, ink.a * appear);
	}
}
