global uniform float planar_water_height;
global uniform uint planar_reflection_camera_bit;

const float PLANAR_REFLECTION_CLIP_BIAS = 0.001;

void planar_reflection_clip(
	uint camera_visible_layers,
	vec3 camera_position_world,
	vec3 world_position
) {
	bool has_marker =
		(camera_visible_layers & planar_reflection_camera_bit) != 0u;
	bool camera_is_below_water =
		camera_position_world.y < planar_water_height;

	if (
		has_marker
		&& camera_is_below_water
		&& world_position.y < planar_water_height - PLANAR_REFLECTION_CLIP_BIAS
	) {
		discard;
	}
}
