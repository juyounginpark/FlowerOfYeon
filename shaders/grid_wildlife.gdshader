shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D animal_sheet : source_color, filter_linear, repeat_disable;
uniform float opacity = 0.7;
uniform float ground_y = 0.65;
uniform float haze = 0.1;
uniform vec4 haze_color : source_color = vec4(0.85, 0.80, 0.70, 1.0);
void fragment() {
	vec4 ink = texture(animal_sheet, UV);
	ALBEDO = mix(ink.rgb, haze_color.rgb, haze);
	// Only the part emerging above the ridge is visible during takeoff/landing.
	ALPHA = ink.a * opacity * (1.0 - smoothstep(ground_y - 0.008, ground_y + 0.008, SCREEN_UV.y));
}
