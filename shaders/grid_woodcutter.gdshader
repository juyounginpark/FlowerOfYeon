shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity = 1.0;
void fragment() {
    if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
    vec4 ink = texture(illustration,UV);
    ALBEDO = ink.rgb;
    ALPHA = ink.a * opacity;
}
