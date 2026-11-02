shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;

uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D sprite_mask : filter_linear, repeat_disable;
uniform bool use_sprite_mask = false;
uniform float pose_phase = 0.0;
uniform float pose_amplitude = 0.0;
uniform float actor_height = 1.0;
uniform bool swimming = false;
uniform float waterline = 0.8;

void vertex() {
	float upper = clamp(VERTEX.y / actor_height + 0.5, 0.0, 1.0);
	float breath = sin(pose_phase) * pose_amplitude;
	VERTEX.y += breath * upper;
	VERTEX.x += breath * VERTEX.x / actor_height * 0.4;
}

void fragment() {
	vec4 ink = texture(illustration, UV) * COLOR;
	if (use_sprite_mask) { ink.a *= texture(sprite_mask, UV).r; }
	float visibility = 1.0;
	if (swimming) {
		// Reveal the existing animated water behind the submerged clothing.
		float lap = sin(UV.x * 9.42478 + pose_phase) * 0.014;
		lap += sin(UV.x * 20.1062 - pose_phase) * 0.006;
		visibility = 1.0 - smoothstep(waterline - 0.035, waterline + 0.035, UV.y - lap);
	}
	ALBEDO = ink.rgb;
	ALPHA = ink.a * visibility;
}
