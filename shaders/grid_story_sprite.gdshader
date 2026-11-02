shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity = 1.0;
uniform vec4 frame_region = vec4(0.0,0.0,1.0,1.0);
uniform vec4 ink_tint : source_color = vec4(1.0);
void fragment() {
    if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
    vec4 ink = texture(illustration,frame_region.xy + UV * frame_region.zw);
    ALBEDO = ink.rgb * ink_tint.rgb;
    ALPHA = ink.a * opacity;
}
