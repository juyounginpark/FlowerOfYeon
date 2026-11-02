uniform sampler2D player_silhouette : filter_linear, repeat_disable;
uniform bool protect_player = false;
bool wave_overlaps_player(vec2 uv) {
    return protect_player && texture(player_silhouette, uv).a > 0.001;
}
