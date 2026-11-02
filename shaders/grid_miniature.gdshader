shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float focus_y = 0.52;
uniform float sharp_half_width = 0.212;
uniform float blur_transition = 0.224;
uniform float blur_range : hint_range(0.01,1.0) = 0.25;
uniform float maximum_blur_lod = 3.4;
uniform float saturation = 1.08;
uniform float contrast = 1.035;
uniform float strength : hint_range(0.0,1.0) = 0.25;
void fragment() {
	float distance=abs(SCREEN_UV.y-focus_y);
	// Compress each blurred margin toward its screen edge as focus follows the player.
	float edge_distance=SCREEN_UV.y<focus_y ? focus_y : 1.0-focus_y;
	float blur_start=mix(edge_distance,min(sharp_half_width,edge_distance),blur_range);
	float blur=smoothstep(blur_start,blur_start+blur_transition*blur_range,distance)*strength;
	vec3 color=textureLod(screen_texture,SCREEN_UV,blur*maximum_blur_lod).rgb;
	float luminance=dot(color,vec3(0.299,0.587,0.114));
	color=mix(vec3(luminance),color,mix(1.0,saturation,strength));
	color=(color-0.5)*mix(1.0,contrast,strength)+0.5;
	COLOR=vec4(clamp(color,vec3(0.0),vec3(1.0)),1.0);
}
