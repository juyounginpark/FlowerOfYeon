shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 frame_uv = vec4(0.0, 0.0, 0.25, 0.5);
uniform vec4 previous_uv = vec4(0.0, 0.0, 0.25, 0.5);
uniform float frame_blend = 1.0;
void fragment() {
	if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) discard;
	vec4 before = texture(illustration,previous_uv.xy+UV*previous_uv.zw);
	vec4 after = texture(illustration,frame_uv.xy+UV*frame_uv.zw);
	float alpha = mix(before.a,after.a,frame_blend);
	ALBEDO = mix(before.rgb*before.a,after.rgb*after.a,frame_blend)/max(alpha,0.001);
	ALPHA = alpha;
}
