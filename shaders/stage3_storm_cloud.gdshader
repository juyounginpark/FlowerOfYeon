shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;

uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 ink_tint : source_color = vec4(1.0);
uniform float opacity = 1.0;

void fragment() {
    vec4 ink = texture(illustration, UV);
    ALBEDO = ink.rgb * ink_tint.rgb;
    ALPHA = ink.a * opacity;
}
