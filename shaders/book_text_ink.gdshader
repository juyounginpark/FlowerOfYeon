shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 page_rect;
uniform sampler2D ink_mask : filter_linear, repeat_disable;
void fragment() {
	vec2 p=(FRAGCOORD.xy-page_rect.xy)/page_rect.zw;
	float grain=texture(ink_mask,clamp(p,vec2(0.0),vec2(1.0))).r;
	float fibers=sin(p.x*93.0+sin(p.y*61.0))*0.018;
	float distance=p.x+(grain-0.5)*0.13+fibers;
	float front=mix(-0.18,1.22,progress);
	float wet=smoothstep(distance-0.09,distance+0.07,front);
	float settled=smoothstep(distance+0.015,distance+0.19,front);
	COLOR.rgb=mix(COLOR.rgb*0.72,COLOR.rgb,settled);
	COLOR.a*=wet*smoothstep(0.0,0.05,progress);
}
