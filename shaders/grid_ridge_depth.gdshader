shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D ink_texture : source_color, filter_linear, repeat_disable;
uniform vec4 haze_color : source_color = vec4(0.85, 0.80, 0.70, 1.0);
uniform float haze_amount = 0.0;
uniform float opacity = 1.0;
uniform bool foreground = false;
uniform bool soften_base = false;
uniform vec4 crop_uv = vec4(0.0, 0.0, 1.0, 1.0);
void fragment() {
	vec4 ink = texture(ink_texture, UV);
	ALBEDO = mix(ink.rgb, haze_color.rgb, haze_amount);
	ALPHA = ink.a * opacity;
	if (soften_base) {
		float local_y = (UV.y - crop_uv.y) / crop_uv.w;
		ALPHA *= 1.0 - smoothstep(0.58, 0.98, local_y);
	}
	if (foreground) {
		// Keep rooftops readable and let the narrow shoreline remain visible.
		ALPHA *= smoothstep(0.70, 0.75, SCREEN_UV.y);
		ALPHA *= 1.0 - smoothstep(0.975, 1.02, SCREEN_UV.y);
	}
}
