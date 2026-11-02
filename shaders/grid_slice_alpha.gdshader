shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform vec4 ink_color : source_color = vec4(1.0);
uniform bool vertex_ink = false;
uniform bool textured = false;
uniform sampler2D ink_texture : source_color, filter_linear, repeat_disable;
uniform sampler2D player_silhouette : filter_linear, repeat_disable;
uniform bool protect_player = false;
void fragment() {
    if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
    vec4 color=ink_color;
    if(vertex_ink) {color*=COLOR;}
    if(textured) {color*=texture(ink_texture,UV);}
    float player = protect_player ? smoothstep(0.05,0.2,texture(player_silhouette,SCREEN_UV).a) : 0.0;
    ALBEDO=color.rgb; ALPHA=color.a*(1.0-player);
}
