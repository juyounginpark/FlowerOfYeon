shader_type canvas_item;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform float aspect = 1.0;
uniform sampler2D ink_mask : filter_linear, repeat_disable;
void fragment() {
	vec2 p=(UV-vec2(.5))*vec2(aspect,1.0);
	float angle=atan(p.y,p.x);
	float fibers=sin(angle*13.0+sin(angle*7.0))*0.016+sin(UV.x*79.0+UV.y*53.0)*0.006;
	float distance=length(p)+fibers;
	float radius=progress*(length(vec2(aspect,1.0))*.55+.1);
	float reveal=1.0-smoothstep(radius-.055,radius+.035,distance);
	vec2 mask_uv=(UV-.5)/max(.04,progress*1.8)+.5;
	float paint=texture(ink_mask,clamp(mask_uv,vec2(0),vec2(1))).r;
	paint*=step(0.0,mask_uv.x)*step(mask_uv.x,1.0)*step(0.0,mask_uv.y)*step(mask_uv.y,1.0);
	reveal*=mix(smoothstep(.01,.8,paint),1.0,smoothstep(.7,1.0,progress));
	float rim=exp(-pow((distance-radius+.025)*32.0,2.0))*(1.0-progress)*.34;
	vec4 paper=texture(TEXTURE,UV);
	paper.rgb=mix(paper.rgb,vec3(.16,.19,.14),rim);
	COLOR=vec4(paper.rgb,paper.a*reveal*smoothstep(0.0,.07,progress));
}
