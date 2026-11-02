shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
#include "res://shaders/grid_wave_player_mask.gdshaderinc"
uniform sampler2D fish_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool textured = true;
uniform bool billboard = false;
void vertex() {
    if (billboard) {
        MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
            INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    }
}
void fragment() {
    // The player is composited across twelve bands; priority alone is insufficient.
    if (wave_overlaps_player(SCREEN_UV)) { discard; }
    vec4 ink = COLOR;
    if (textured) { ink *= texture(fish_texture, UV); }
    ALBEDO = ink.rgb;
    ALPHA = ink.a;
}
