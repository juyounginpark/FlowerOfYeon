shader_type canvas_item;
render_mode unshaded;

uniform float fog_time = 0.0;
uniform float max_opacity : hint_range(0.0, 0.16) = 0.14;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 page_origin;
uniform float page_scale = 1.0;
uniform float footer_height = 48.0;
uniform vec4 narration_boxes[6];
uniform float narration_visibility[6];
uniform float panel_visibility[3];
uniform vec4 prompt_box;
uniform float prompt_visible = 1.0;

float hash21(vec2 p) {
	highp vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

float billows(vec2 p) {
	float result = 0.0;
	float weight = 0.56;
	for (int i = 0; i < 4; i++) {
		result += noise(p) * weight;
		p = mat2(vec2(1.72, 0.61), vec2(-0.61, 1.72)) * p + vec2(7.3, 4.1);
		weight *= 0.48;
	}
	return result;
}

float outside_box(vec2 p, vec4 box, float feather) {
	vec2 outside = max(max(box.xy - p, p - box.xy - box.zw), vec2(0.0));
	return smoothstep(0.0, feather, length(outside));
}

float outside_ellipse(vec2 p, vec2 center, vec2 radius) {
	return smoothstep(1.0, 1.35, length((p - center) / radius));
}

void fragment() {
	vec2 screen = UV * viewport_size;
	vec2 p = screen / max(viewport_size.y, 1.0);
	float t = fog_time;
	// Layered smoke: slow sideways drift, buoyant lobes and feathered wisps.
	vec2 flow = vec2(-t * 0.036, sin(t * 0.12) * 0.15);
	vec2 domain = p * vec2(3.2, 4.4) + flow;
	vec2 warp = vec2(noise(domain * 0.73 + vec2(2.1, 7.8)), noise(domain * 0.67 + vec2(9.2, 1.4)));
	float cloud = billows(domain + (warp - 0.5) * 1.25);
	float center = 0.46 + sin(p.x * 3.2 + t * 0.16) * 0.07 + sin(t * 0.21) * 0.045;
	float envelope = exp(-pow((p.y - center) / 0.19, 2.0));
	float low_wisp = exp(-pow((p.y - (0.73 + sin(p.x * 4.1 - t * 0.11) * 0.045)) / 0.075, 2.0));
	float lobes = 0.66 + 0.34 * noise(vec2(p.x * 4.5 - t * 0.027, t * 0.008 + 3.0));
	float density = smoothstep(0.23, 0.69, cloud) * (envelope * lobes + low_wisp * 0.42);
	float alpha = min(max_opacity, density * max_opacity * 2.25);

	vec2 page = (screen - page_origin) / max(page_scale, 0.001);
	float safe = 1.0;
	for (int i = 0; i < 6; i++) {
		safe *= mix(1.0, outside_box(page, narration_boxes[i], 20.0), narration_visibility[i]);
	}
	// Same opening fog, with safe masks moved onto the ending illustrations.
	float first = outside_ellipse(page, vec2(425.0, 455.0), vec2(69.0, 73.0));
	float second = outside_ellipse(page, vec2(857.0, 211.0), vec2(100.0, 95.0));
	float third = outside_ellipse(page, vec2(1496.0, 153.0), vec2(103.0, 108.0));
	safe *= mix(1.0, first, panel_visibility[0]);
	safe *= mix(1.0, second, panel_visibility[1]);
	safe *= mix(1.0, third, panel_visibility[2]);
	float body_first = outside_ellipse(page, vec2(290.0, 452.0), vec2(236.0, 270.0));
	float body_second = outside_ellipse(page, vec2(861.0, 453.0), vec2(236.0, 339.0));
	float body_third = outside_ellipse(page, vec2(1461.0, 739.0), vec2(203.0, 158.0));
	safe *= mix(1.0, mix(0.3, 1.0, body_first), panel_visibility[0]);
	safe *= mix(1.0, mix(0.3, 1.0, body_second), panel_visibility[1]);
	safe *= mix(1.0, mix(0.3, 1.0, body_third), panel_visibility[2]);
	safe *= mix(1.0, outside_box(screen, prompt_box, 18.0), prompt_visible);
	float footer = 1.0 - smoothstep(viewport_size.y - footer_height - 10.0, viewport_size.y - footer_height + 2.0, screen.y);
	float edge = smoothstep(0.0, 0.045, UV.y) * (1.0 - smoothstep(0.96, 1.0, UV.y));
	COLOR = vec4(vec3(0.96, 0.98, 0.99), alpha * safe * footer * edge);
}
