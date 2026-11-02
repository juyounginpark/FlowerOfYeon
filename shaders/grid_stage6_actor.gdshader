shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity = 1.0;
uniform vec4 ink_tint : source_color = vec4(1.0);
uniform vec4 hidden_region = vec4(0.0);
uniform bool billboard = false;
void vertex() {
    if (billboard) {
        MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
            INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    }
}
void fragment() {
    if (hidden_region.z > 0.0 && UV.x >= hidden_region.x && UV.y >= hidden_region.y
        && UV.x <= hidden_region.x + hidden_region.z && UV.y <= hidden_region.y + hidden_region.w) { discard; }
    vec4 ink = texture(illustration, UV) * COLOR;
    ALBEDO = ink.rgb * ink_tint.rgb;
    ALPHA = ink.a * opacity * ink_tint.a;
}
