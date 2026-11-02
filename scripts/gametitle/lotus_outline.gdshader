shader_type canvas_item;

uniform float hover_amount : hint_range(0.0, 1.0) = 0.0;
uniform float width_texels : hint_range(0.0, 20.0) = 8.73;

void fragment() {
	vec4 original = COLOR;
	float nearby_alpha = original.a;
	for (int i = 0; i < 16; i++) {
		float angle = float(i) * 6.28318530718 / 16.0;
		vec2 sample_uv = UV + vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * width_texels;
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, sample_uv).a);
	}
	// White lies behind the original silhouette, preserving its colors and alpha edges.
	float outline_alpha = nearby_alpha * hover_amount * (1.0 - original.a);
	float alpha = original.a + outline_alpha;
	vec3 rgb = (original.rgb * original.a + vec3(1.0) * outline_alpha) / max(alpha, 0.00001);
	COLOR = vec4(rgb, alpha);
}
