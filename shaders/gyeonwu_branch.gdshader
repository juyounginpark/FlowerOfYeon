shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform float growth = 1.0;
uniform float opacity = 1.0;
uniform bool paper_layer = false;
uniform vec4 paper_tint : source_color = vec4(1.0);
void fragment() {
	if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
	// Ink grows from the lower-left root towards the upper-right twigs.
	float distance_from_root = (UV.x + 1.0 - UV.y) * 0.5;
	float reveal = 1.0 - smoothstep(growth - 0.06, growth, distance_from_root);
	if (paper_layer) {
		ALBEDO = paper_tint.rgb;
		ALPHA = COLOR.a * paper_tint.a * opacity * reveal;
	} else {
		vec4 ink = texture(illustration,UV);
		ALBEDO = ink.rgb;
		ALPHA = ink.a * opacity * reveal;
	}
}
