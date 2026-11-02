shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform float clock = 0.0;
void fragment() {
    if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
    vec4 ink=texture(illustration,UV);
    float r=length(UV-vec2(0.488,0.5));
    float luminance=dot(ink.rgb,vec3(0.299,0.587,0.114));
    // The painted constellations remain legible under cool light from the disc.
    vec3 night=mix(vec3(0.045,0.055,0.12),vec3(0.35,0.40,0.57),luminance);
    float pulse=0.86+0.14*sin(clock*0.7);
    float rim=exp(-pow((r-0.47)*105.0,2.0));
    float inner=exp(-r*r*9.0)*0.14;
    ALBEDO=night;
    EMISSION=vec3(0.24,0.40,0.85)*(rim*0.65+inner)*pulse;
    ALPHA=ink.a*(1.0-smoothstep(0.491,0.502,r));
}
