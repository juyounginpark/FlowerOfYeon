shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform vec4 ink_color : source_color = vec4(0.46,0.35,0.23,1.0);
uniform bool corner = false;
uniform sampler2D corner_image : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
void fragment() {
	if(collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) {discard;}
	if(corner && texture(corner_image,UV).a<0.25) {discard;}
	ALBEDO=ink_color.rgb;
}
