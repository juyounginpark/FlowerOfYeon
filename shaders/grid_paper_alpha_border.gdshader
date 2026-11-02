shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D source_ink : filter_linear, repeat_disable;
uniform vec2 source_size;
uniform float source_scale;
uniform float radius = 3.2;
uniform vec2 shadow_offset = vec2(0.0);
uniform bool sliced = false;
uniform float opacity = 1.0;
uniform vec4 border_tint : source_color = vec4(1.0);
uniform sampler2D player_silhouette : filter_linear, repeat_disable;
uniform bool protect_player = false;
varying vec2 paper_point;
void vertex() { paper_point = vec2(VERTEX.x, -VERTEX.y) - shadow_offset; }
float ink_at(vec2 point) {
    vec2 uv = point / source_scale / source_size + vec2(0.5);
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
    return smoothstep(0.12, 0.3, texture(source_ink, uv).a);
}
void fragment() {
    if (sliced && collage_outside_slice(SCREEN_UV, CAMERA_VISIBLE_LAYERS, VIEWPORT_SIZE.y)) discard;
    float coverage = ink_at(paper_point);
    for (int i=0; i<16; i++) {
        float angle=float(i)*6.2831853/16.0;
        coverage=max(coverage,ink_at(paper_point+vec2(cos(angle),sin(angle))*radius));
    }
    ALBEDO=COLOR.rgb*border_tint.rgb;
    float player = protect_player ? smoothstep(0.05,0.2,texture(player_silhouette,SCREEN_UV).a) : 0.0;
    ALPHA=COLOR.a*coverage*opacity*(1.0-player);
}
