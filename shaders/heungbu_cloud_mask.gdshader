shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
uniform sampler2D cloud_image : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D house_image : source_color, filter_linear_mipmap, repeat_disable;
uniform float cloud_opacity = 1.0;
uniform bool column_cover = false;
uniform vec4 house_rect = vec4(0.0);
uniform float house_opacity = 0.0;
void fragment() {
    vec4 ink = texture(cloud_image, UV);
    float cover = 0.0;
    if (house_opacity > 0.0 && house_rect.z > 0.0 && house_rect.w > 0.0) {
        vec2 uv = (SCREEN_UV - house_rect.xy) / house_rect.zw;
        if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
            cover = texture(house_image, uv).a * house_opacity;
        }
    }
    float veil = column_cover ? smoothstep(0.68, 0.82, SCREEN_UV.y) * 0.96 : cloud_opacity;
    ALBEDO = ink.rgb;
    ALPHA = ink.a * veil * (1.0 - cover);
}
