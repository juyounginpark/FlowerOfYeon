shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D mountain_image : source_color, filter_linear, repeat_disable;
uniform vec4 crop_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float opacity = 0.8;
uniform vec4 ink_tint : source_color = vec4(1.0);
void fragment() {
	vec4 ink = texture(mountain_image, crop_uv.xy + UV * crop_uv.zw);
	// The ridge emerges above the cloud bed; its base dissolves into the mist.
	float mist = 1.0 - smoothstep(0.22, 0.82, UV.y);
	ALBEDO = ink.rgb * ink_tint.rgb;
	ALPHA = ink.a * mist * opacity;
}
