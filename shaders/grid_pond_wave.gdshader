shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_wave_player_mask.gdshaderinc"
uniform sampler2D wave_image : source_color, filter_linear, repeat_disable;
uniform float elapsed = 0.0;
uniform float phase = 0.0;
uniform float rate = 0.4;
uniform float amplitude = 0.018;
uniform float opacity = 1.0;
uniform vec4 crop_uv = vec4(0.0,0.0,1.0,1.0);
uniform sampler2D map_silhouette : filter_linear, repeat_disable;
uniform bool flip_x = false;

uniform bool shore_contact = false;
uniform sampler2D botanical_silhouette : filter_linear, repeat_disable;
uniform vec2 shore_outward_uv = vec2(0.0);
uniform vec2 shore_contact_uv = vec2(0.0);
uniform vec2 shore_frame = vec2(1280.0,720.0);
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
    // Ordinary depth plus the WHOLE map's projected silhouette: water never
    // appears on architecture, even across separate compositing bands.
    vec2 mask_uv=SCREEN_UV;
    if (shore_contact) {
        float push=(8.0+6.0*pow(0.5+0.5*sin(elapsed*0.75+phase),2.0))*shore_frame.y/720.0;
        vec2 outward=normalize(shore_outward_uv*shore_frame);
        float side=dot((SCREEN_UV-shore_contact_uv)*shore_frame,outward);
        // Only the actual bottom-edge strip may overlap. Never reveal paper
        // farther inside a wall or across its walking surface.
        if (side>=-push) { mask_uv+=shore_outward_uv*push; }
    }
    float map_cover=smoothstep(0.05,0.75,texture(map_silhouette,mask_uv).r);
    ALBEDO = painting.rgb;
    float botanical_cover=shore_contact ? smoothstep(0.02,0.45,texture(botanical_silhouette,SCREEN_UV).r) : 0.0;
    ALPHA = painting.a * opacity * (1.0-map_cover)*(1.0-botanical_cover);
}
