shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D cloud_image : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 ink_tint : source_color = vec4(1.0);
void fragment() {
    vec4 ink = texture(cloud_image, UV);
    ALBEDO = ink.rgb * ink_tint.rgb;
    // Feather into the lower columns without veiling the playable platforms.
    ALPHA = ink.a * smoothstep(0.68, 0.82, SCREEN_UV.y) * 0.96;
}
