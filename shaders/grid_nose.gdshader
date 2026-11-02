shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear, repeat_disable;
uniform vec4 crop = vec4(0.025,0.44,0.95,0.15);
uniform float reveal = 0.0;
uniform float tip_fraction = 0.1;
uniform float sever = -1.0;
uniform float end_u = 1.0;
void fragment() {
	if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) {discard;}
	if (sever>=0.0 && abs(UV.x-sever)<0.008) {discard;}
	if (UV.x>end_u) {discard;}
	float shaft_end=1.0-tip_fraction;
	float u=UV.x<shaft_end ? mix(0.0,0.94*reveal,UV.x/shaft_end) : mix(0.94,1.0,(UV.x-shaft_end)/tip_fraction);
	vec4 ink=texture(illustration,crop.xy+vec2(u,UV.y)*crop.zw);
	ALBEDO=ink.rgb;ALPHA=ink.a;
}
