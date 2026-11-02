shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform float clock = 0.0;
uniform bool disc_halo = false;
void fragment() {
    if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
    vec2 p=(UV-vec2(0.5))*2.0;
    float r=length(p);
    float wave=0.5+0.5*sin(clock*(2.6+COLOR.g*2.4)+COLOR.r*6.283185);
    float pulse=0.04+1.65*pow(wave,5.0);
    vec3 tint=mix(vec3(0.42,0.65,1.0),vec3(1.0,0.88,0.63),COLOR.b);
    float light;
    if(disc_halo) {
        // One soft ring around the plate provides visible light spill without
        // hundreds of real lights, shadow maps or a full-screen bloom pass.
        light=exp(-pow((r-0.78)*12.0,2.0))*0.15;
        tint=vec3(0.35,0.42,1.0);
    } else {
        float core=exp(-r*r*48.0);
        float glow=exp(-r*r*6.0)*0.32;
        float rays=(exp(-abs(p.x)*55.0)+exp(-abs(p.y)*55.0))*exp(-r*3.8)*0.55;
        light=(core+glow+rays)*pulse;
    }
    ALBEDO=tint;
    EMISSION=tint*0.8;
    ALPHA=clamp(light,0.0,1.0)*(1.0-smoothstep(0.8,1.0,r));
}
