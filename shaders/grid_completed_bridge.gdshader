shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D player_silhouette : filter_linear, repeat_disable;
uniform float opacity = 1.0;
void fragment() {
    vec4 ink = texture(illustration, UV);
    float player = smoothstep(0.05, 0.2, texture(player_silhouette, SCREEN_UV).a);
    ALBEDO = ink.rgb;
    ALPHA = ink.a * opacity * (1.0 - player);
}
