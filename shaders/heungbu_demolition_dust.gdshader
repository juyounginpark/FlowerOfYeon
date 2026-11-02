shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D cloud_image : source_color, filter_linear, repeat_disable;
uniform float opacity = 0.68;
void fragment() {
	if (collage_outside_slice(SCREEN_UV, CAMERA_VISIBLE_LAYERS, VIEWPORT_SIZE.y)) discard;
	vec4 cloud = texture(cloud_image, UV);
	float gray = dot(cloud.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = vec3(gray * 0.48);
	ALPHA = cloud.a * opacity;
}
