shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform sampler2D frame_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 outline_color : source_color = vec4(0.0);
uniform bool upright_card = false;
uniform float neck_length = 0.0;
uniform float clear_glow = 0.0;
uniform vec4 frame_region = vec4(0.0,0.0,1.0,1.0);
uniform vec2 frame_size = vec2(384.0,640.0);
uniform float head_seam = 230.0;
uniform vec2 head_bounds = vec2(110.0,290.0);
uniform sampler2D neck_texture : source_color, filter_linear_mipmap, repeat_disable;
void vertex() {
    float local_y = (UV.y-frame_region.y)/frame_region.w;
    VERTEX.y += neck_length*(1.0-local_y);
    // Rotate around the existing sole anchor, retaining the sprite's local size.
    if (!upright_card) {
        MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
            INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    }
}
void fragment() {
    if (collage_outside_slice(SCREEN_UV, CAMERA_VISIBLE_LAYERS, VIEWPORT_SIZE.y)) { discard; }
    vec4 ink = texture(frame_texture, UV) * COLOR;
    if (neck_length > 0.001) {
        vec2 local_uv = (UV-frame_region.xy)/frame_region.zw;
        float extra = neck_length/0.0032;
        vec2 output_pixel = local_uv*vec2(frame_size.x,frame_size.y+extra);
        vec2 body_pixel = output_pixel-vec2(0.0,extra);
        ink=vec4(0.0);
        bool head_x = output_pixel.x>=head_bounds.x && output_pixel.x<=head_bounds.y;
        // Keep body and hands at their original height; lift only the head crop.
        if(body_pixel.y>=0.0 && body_pixel.y<=frame_size.y && !(head_x && body_pixel.y<head_seam)) {
            ink=texture(frame_texture,frame_region.xy+body_pixel/frame_size*frame_region.zw)*COLOR;
        }
        if(head_x && output_pixel.y<head_seam) {
            vec4 head=texture(frame_texture,frame_region.xy+output_pixel/frame_size*frame_region.zw)*COLOR;
            ink=mix(ink,head,head.a);
        }
        if(output_pixel.y>=head_seam-3.0 && output_pixel.y<=head_seam+extra+3.0 && output_pixel.x>=177.0 && output_pixel.x<=217.0) {
            vec2 neck_uv=vec2((output_pixel.x-177.0)/40.0,(output_pixel.y-head_seam+3.0)/(extra+6.0));
            vec4 neck=texture(neck_texture,vec2(mix(0.36,0.64,neck_uv.x),mix(0.04,0.94,neck_uv.y)));
            ink=mix(ink,neck,neck.a);
        }
    }
    if (outline_color.a > 0.0) {
        vec2 step_uv = 8.0 / vec2(textureSize(frame_texture, 0));
        float border = 0.0;
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                border = max(border, texture(frame_texture, UV + vec2(float(x), float(y)) * step_uv).a);
            }
        }
        float edge_alpha = border * outline_color.a * COLOR.a * (1.0 - ink.a);
        float total = ink.a + edge_alpha;
        ink.rgb = (ink.rgb * ink.a + outline_color.rgb * edge_alpha) / max(total, 0.0001);
        ink.a = total;
    }
    ALBEDO = mix(ink.rgb,vec3(1.0,0.96,0.78),clear_glow*0.85);
    ALPHA = ink.a;
}
