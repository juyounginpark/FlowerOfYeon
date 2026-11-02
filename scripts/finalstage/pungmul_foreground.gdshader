shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 frame_uv = vec4(0.0, 0.0, 0.25, 0.5);
uniform vec4 outline_color : source_color = vec4(0.18, 0.85, 0.32, 1.0);
uniform float outline_width_px : hint_range(0.0, 8.0) = 2.5;

float frame_alpha(vec2 local_uv) {
	if (any(lessThan(local_uv, vec2(0.0))) || any(greaterThan(local_uv, vec2(1.0)))) {
		return 0.0;
	}
	// Clamp to this animation cell so adjacent dancers cannot bleed into the edge.
	vec2 inset = 0.5 / vec2(textureSize(illustration, 0));
	vec2 atlas_uv = clamp(frame_uv.xy + local_uv * frame_uv.zw,
		frame_uv.xy + inset, frame_uv.xy + frame_uv.zw - inset);
	return texture(illustration, atlas_uv).a;
}

void fragment() {
	vec4 ink = texture(illustration, frame_uv.xy + UV * frame_uv.zw);
	vec2 radius = fwidth(UV) * outline_width_px;
	float nearby_alpha = ink.a;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 6.28318530718 / 16.0;
		nearby_alpha = max(nearby_alpha, frame_alpha(UV + vec2(cos(angle), sin(angle)) * radius));
	}
	float border_alpha = nearby_alpha * outline_color.a * (1.0 - ink.a);
	float alpha = ink.a + border_alpha;
	ALBEDO = (ink.rgb * ink.a + outline_color.rgb * border_alpha) / max(alpha, 0.00001);
	ALPHA = alpha;
}
