shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform float opacity : hint_range(0.0, 1.0) = 0.28;
void fragment() {
	if (collage_outside_slice(SCREEN_UV, CAMERA_VISIBLE_LAYERS, VIEWPORT_SIZE.y)) discard;
	float radius = length((UV - vec2(0.5)) * 2.0);
	float soft_edge = 1.0 - smoothstep(0.12, 1.0, radius);
	ALBEDO = vec3(0.12, 0.14, 0.13);
	ALPHA = soft_edge * soft_edge * opacity;
}
