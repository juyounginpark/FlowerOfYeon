shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
#include "res://shaders/grid_wave_player_mask.gdshaderinc"
uniform sampler2D board_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity = 1.0;
void fragment() {
	if (wave_overlaps_player(SCREEN_UV)) { discard; }
	vec4 ink = texture(board_texture, UV);
	ALBEDO = ink.rgb;
	ALPHA = ink.a * opacity;
}
