shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform vec2 origin_uv = vec2(0.5,0.15);
uniform float wall_height = 19.6;
uniform float picture_height = 6.0;
uniform vec4 wall_tint : source_color = vec4(0.72,0.55,0.46,1.0);
float grain(vec2 p) {
    return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);
}
void fragment() {
    if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) discard;
    vec2 art_uv=vec2(UV.x,UV.y*wall_height/picture_height);
    vec3 pigment=texture(illustration,mix(vec2(0.07,0.035),vec2(0.93,0.965),clamp(art_uv,vec2(0.0),vec2(1.0)))).rgb;
    float lower_fade=smoothstep(0.88,1.15,art_uv.y);
    pigment=mix(pigment,vec3(0.76,0.68,0.51),lower_fade);
    float paper= smoothstep(0.53,0.86,dot(pigment,vec3(0.299,0.587,0.114)));
    vec3 soaked=mix(pigment*0.90,mix(pigment,wall_tint.rgb,0.42),paper);
    float noise=grain(floor(UV*vec2(150.0,700.0)));
    float front=length((UV-origin_uv)*vec2(0.7,1.0))+(noise-0.5)*0.055;
    float reveal=1.0-smoothstep(progress*1.6-0.12,progress*1.6+0.08,front);
    float edge=smoothstep(0.0,0.012,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
    ALBEDO=soaked;
    ALPHA=reveal*smoothstep(0.0,0.13,progress)*edge*0.94;
}
