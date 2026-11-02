shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled;
uniform sampler2D illustration : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 root_point = vec2(0.0);
uniform float growth = 0.0;
void vertex() {
    VERTEX.xy=root_point+(VERTEX.xy-root_point)*vec2(mix(0.18,1.0,growth),max(0.01,growth));
}
void fragment() {
    vec4 ink=texture(illustration,UV);
    ALBEDO=ink.rgb;
    ALPHA=ink.a*smoothstep(0.0,0.18,growth);
}
