shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear, repeat_disable;
uniform bool cut_enabled = false;
uniform vec2 cut_range = vec2(0.0);
void fragment() {
    if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
    vec4 ink = texture(illustration, UV);
    float edge = 0.0;
    if (cut_enabled && UV.y >= cut_range.x && UV.y <= cut_range.y) {
        vec2 texel = 1.0 / vec2(textureSize(illustration, 0));
        edge = max(texture(illustration, UV + vec2(texel.x * 17.0, 0.0)).a,
                   texture(illustration, UV - vec2(texel.x * 17.0, 0.0)).a);
        edge = smoothstep(0.06, 0.2, edge);
    }
    ALBEDO = mix(vec3(0.98, 0.89, 0.64), ink.rgb, ink.a);
    ALPHA = max(ink.a, edge);
}
