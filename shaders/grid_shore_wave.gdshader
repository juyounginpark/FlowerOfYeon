shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
#include "res://shaders/grid_wave_player_mask.gdshaderinc"
uniform sampler2D wave_image : source_color, filter_linear, repeat_disable;
uniform float elapsed = 0.0;
uniform float phase = 0.0;
uniform float rate = 0.4;
uniform float amplitude = 0.018;
uniform float opacity = 1.0;
uniform vec4 crop_uv = vec4(0.0,0.0,1.0,1.0);
uniform bool flip_x = false;
uniform bool shore_contact = false;
uniform sampler2D map_silhouette : filter_linear, repeat_disable;
uniform sampler2D walking_silhouette : filter_linear, repeat_disable;
uniform vec2 edge_start;
uniform vec2 edge_end;
uniform vec2 edge_up;
uniform vec2 frame_size;
uniform sampler2D botanical_silhouette : filter_linear, repeat_disable;
uniform bool protect_paper = true;
void vertex() {
    // Subdivided painted sheet bends with two overlapping spine-like waves.
    // Root/base moves least; upper contours and crests flex independently.
    float weight = 0.25 + 0.75 * (1.0-UV.y);
    float t = elapsed * rate + phase;
    VERTEX.y += amplitude * weight * (sin(UV.x*6.283185+t) + 0.45*sin(UV.x*12.56637-t*0.63));
    VERTEX.x += amplitude * 0.50 * sin(UV.y*3.141593+t*0.7) * weight;
}
void fragment() {
    if (wave_overlaps_player(SCREEN_UV)) { discard; }
    vec2 painted_uv=vec2(flip_x ? 1.0-UV.x : UV.x,UV.y);
    vec4 painting = texture(wave_image, crop_uv.xy+painted_uv*crop_uv.zw);
    // Only the finite quadrilateral directly above THIS bottom edge can lap
    // onto its wall. Other architecture and all walkable tops occlude it.
    vec2 along=edge_end-edge_start;
    vec2 rel=SCREEN_UV-edge_start;
    float det=along.x*edge_up.y-along.y*edge_up.x;
    float u=0.0; float v=-1.0;
    if (abs(det)>0.0000001) {
        u=(rel.x*edge_up.y-rel.y*edge_up.x)/det;
        v=(along.x*rel.y-along.y*rel.x)/det;
    }
    float allowed=(u>=0.0 && u<=1.0 && v>=0.0 && v<=1.0) ? 1.0 : 0.0;
    float top_cover=smoothstep(0.02,0.5,texture(walking_silhouette,SCREEN_UV).r);
    float architecture_cover=smoothstep(0.05,0.75,texture(map_silhouette,SCREEN_UV).r);
    float wrong_intrusion=max(top_cover,architecture_cover*(1.0-allowed));
    ALBEDO = painting.rgb;
    float botanical_cover=(protect_paper && shore_contact) ? smoothstep(0.02,0.45,texture(botanical_silhouette,SCREEN_UV).r) : 0.0;
    ALPHA = painting.a * opacity * (1.0-botanical_cover)*(1.0-wrong_intrusion);
}
