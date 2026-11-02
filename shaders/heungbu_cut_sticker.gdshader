shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear, repeat_disable;
uniform vec4 sticker_area = vec4(0.0,0.0,1.0,1.0);
uniform bool enabled = true;
uniform bool sliced = false;
uniform float border_radius = 6.0;
void fragment() {
	if(sliced && collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) discard;
	vec4 ink = texture(illustration,UV);
	float rim = 0.0;
	if (enabled && all(greaterThanEqual(UV,sticker_area.xy)) && all(lessThanEqual(UV,sticker_area.zw))) {
		vec2 pixel=1.0/vec2(textureSize(illustration,0));
		for(int i=0;i<16;i++) {
			float angle=float(i)*6.2831853/16.0;
			vec2 sample_uv=UV+vec2(cos(angle),sin(angle))*pixel*border_radius;
			if(all(greaterThanEqual(sample_uv,vec2(0.0))) && all(lessThanEqual(sample_uv,vec2(1.0)))) rim=max(rim,texture(illustration,sample_uv).a);
		}
	}
	float border=rim*(1.0-ink.a);
	float alpha=ink.a+border;
	ALBEDO=(ink.rgb*ink.a+vec3(0.97,0.94,0.85)*border)/max(alpha,0.0001);
	ALPHA=alpha*COLOR.a;
}
