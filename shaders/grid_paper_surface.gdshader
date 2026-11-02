shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/grid_slice_common.gdshaderinc"
uniform vec4 top_color : source_color = vec4(0.937,0.886,0.749,1.0);
uniform vec4 rose_color : source_color = vec4(0.749,0.592,0.518,1.0);
uniform vec4 sage_color : source_color = vec4(0.490,0.545,0.475,1.0);
varying vec3 face_normal;
void vertex() {face_normal=NORMAL;}
void fragment() {
	if(collage_outside_slice(SCREEN_UV,CAMERA_VISIBLE_LAYERS,VIEWPORT_SIZE.y)) {discard;}
	vec3 face;
	if(abs(face_normal.y)>.5) {face=top_color.rgb;}
	else if(abs(face_normal.x)>.5) {face=rose_color.rgb;}
	else {face=sage_color.rgb;}
	if(face_normal.y>.5 && COLOR.r>COLOR.g*1.25) {face=mix(face,rose_color.rgb,.28);}
	ALBEDO=face;
}
