shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
        INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
        INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}
void fragment() {
    if (collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) { discard; }
    vec2 p=abs(UV*2.0-1.0);
    float glow=pow(max(0.0,1.0-length(p)),2.0);
    float glint=pow(max(0.0,1.0-min(p.x,p.y)*12.0),3.0)*max(0.0,1.0-max(p.x,p.y));
    ALBEDO=vec3(1.0,0.60,0.06);
    EMISSION=vec3(1.0,0.43,0.04)*0.15;
    ALPHA=min(1.0,glow*1.8+glint*.8)*COLOR.a;
}