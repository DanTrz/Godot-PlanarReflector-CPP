shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_toon,specular_toon;

//render_mode unshaded, cull_disabled, blend_mix;
//

uniform sampler2D reflection_screen_texture : source_color, filter_linear;
uniform vec4 water_color : source_color = vec4(0.08, 0.32, 0.42, 0.72);
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.75;
uniform bool reflection_flip_x = true;
uniform float debug_selection_highlight : hint_range(0.0, 1.0) = 0.0;
uniform vec3 debug_selection_color : source_color = vec3(1.0, 0.18, 0.02);

void fragment() {
	vec2 reflection_uv = SCREEN_UV;
	if (reflection_flip_x) {
		reflection_uv.x = 1.0 - reflection_uv.x;
	}
	vec3 reflection = texture(reflection_screen_texture, reflection_uv).rgb;
	ALBEDO = mix(water_color.rgb, reflection, reflection_strength);
	ALBEDO = mix(ALBEDO, debug_selection_color, debug_selection_highlight * 0.65);
	EMISSION = debug_selection_color * debug_selection_highlight * 0.35;
	ALPHA = water_color.a;
}
