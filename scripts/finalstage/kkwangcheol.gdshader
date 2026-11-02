shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"

uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 frame_uv = vec4(0.0, 0.0, 0.25, 0.5);

void fragment() {
	if (collage_outside_slice(SCREEN_UV, CAMERA_VISIBLE_LAYERS, VIEWPORT_SIZE.y)) { discard; }
	vec4 ink = texture(illustration, frame_uv.xy + UV * frame_uv.zw);
	ALBEDO = ink.rgb;
	ALPHA = ink.a;
}
