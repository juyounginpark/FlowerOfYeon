shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "res://shaders/grid_wave_player_mask.gdshaderinc"
uniform sampler2D ink_texture : source_color, filter_linear, repeat_disable;
void fragment() {
    if (wave_overlaps_player(SCREEN_UV)) { discard; }
	vec4 ink = texture(ink_texture, UV);
	ALBEDO = ink.rgb;
	ALPHA = ink.a * smoothstep(0.92, 0.975, SCREEN_UV.y) * 0.88;
}
