shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear, repeat_disable;
uniform float opacity = 1.0;
uniform bool clip_to_slice = true;
void fragment() {
    if (clip_to_slice && collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
    vec4 ink = texture(illustration,UV);
    vec2 step_uv = max(vec2(3.0) / vec2(textureSize(illustration,0)),fwidth(UV)*2.5);
    float edge = 0.0;
    for (int i=0;i<8;i++) {
        float angle=float(i)*0.785398163;
        edge=max(edge,texture(illustration,UV+vec2(cos(angle),sin(angle))*step_uv).a);
    }
    edge=smoothstep(0.08,0.3,edge);
    ALBEDO=mix(vec3(0.8,0.045,0.025),ink.rgb,smoothstep(0.05,0.8,ink.a));
    ALPHA=max(ink.a,edge)*opacity;
}
