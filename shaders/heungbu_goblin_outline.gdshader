shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D illustration : source_color, filter_linear, repeat_disable;
uniform vec4 outline_color : source_color = vec4(0.86, 0.08, 0.10, 1.0);
uniform float outline_radius = 4.0;
void fragment() {
	vec4 ink = texture(illustration, UV);
	vec2 texel = 1.0 / vec2(textureSize(illustration, 0));
	float surrounding = ink.a;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 6.2831853 / 16.0;
		vec2 uv = UV + vec2(cos(angle), sin(angle)) * texel * outline_radius;
		if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
			surrounding = max(surrounding, texture(illustration, uv).a);
		}
	}
	float border = surrounding * (1.0 - ink.a) * outline_color.a;
	float alpha = ink.a + border;
	ALBEDO = (ink.rgb * ink.a + outline_color.rgb * border) / max(alpha, 0.0001);
	ALPHA = alpha * COLOR.a;
}
