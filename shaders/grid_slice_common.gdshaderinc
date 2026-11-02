// The pass marker uses visibility bits 8..19, independent of common geometry bit0.
// Godot SCREEN_UV is normalized viewport coordinates: y=0 top, y=1 bottom.
int collage_slice_index(uint visible_layers) {
    // Constant masks avoid a driver-dependent dynamic shift/loop in every
    // fragment. Keep these in sync with screen_slices.gd ART_BIT_START=8.
    // Mask passes (bits 20+) deliberately fall through without clipping.
    if ((visible_layers & uint(256)) != uint(0)) { return 0; }
    if ((visible_layers & uint(512)) != uint(0)) { return 1; }
    if ((visible_layers & uint(1024)) != uint(0)) { return 2; }
    if ((visible_layers & uint(2048)) != uint(0)) { return 3; }
    if ((visible_layers & uint(4096)) != uint(0)) { return 4; }
    if ((visible_layers & uint(8192)) != uint(0)) { return 5; }
    if ((visible_layers & uint(16384)) != uint(0)) { return 6; }
    if ((visible_layers & uint(32768)) != uint(0)) { return 7; }
    if ((visible_layers & uint(65536)) != uint(0)) { return 8; }
    if ((visible_layers & uint(131072)) != uint(0)) { return 9; }
    if ((visible_layers & uint(262144)) != uint(0)) { return 10; }
    if ((visible_layers & uint(524288)) != uint(0)) { return 11; }
    return -1;
}
bool collage_outside_slice(vec2 screen_uv, uint visible_layers, float viewport_height) {
    int band=collage_slice_index(visible_layers);
    if (band<0) { return false; }
    // One physical render-pixel guard on both sides prevents linear upscale
    // from blending two transparent strip borders into a horizontal gap.
    float pixel_row=floor(screen_uv.y*viewport_height);
    float first_row=floor(float(band)*viewport_height/12.0)-1.0;
    float last_row=ceil(float(band+1)*viewport_height/12.0)+1.0;
    return pixel_row<first_row || pixel_row>=last_row;
}
