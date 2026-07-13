shader_type spatial;
render_mode depth_draw_opaque, cull_back;

#include "res://addons/PlanarReflectorCpp/SupportFiles/Shaders/planar_reflection_clip_object.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.8, 0.3, 0.15, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.65;

void fragment() {
	planar_reflection_clip(CAMERA_VISIBLE_LAYERS, CAMERA_POSITION_WORLD, (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	ALBEDO = base_color.rgb;
	ROUGHNESS = roughness_value;
}
