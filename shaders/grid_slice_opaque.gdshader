shader_type spatial;
render_mode unshaded,cull_disabled;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform vec4 ink_color : source_color = vec4(1.0);
uniform bool vertex_ink = false;
uniform bool textured = false;
uniform sampler2D ink_texture : source_color, filter_linear, repeat_disable;
void fragment() {
    if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
    vec4 color=ink_color;
    if(vertex_ink) {color*=COLOR;}
    if(textured) {color*=texture(ink_texture,UV);}
    ALBEDO=color.rgb;
}
