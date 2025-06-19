extends MeshInstance3D
class_name PlanarReflectorGDSCript

var reflect_camera : Camera3D # .h=ok // .cpp=missing
var reflect_viewport: SubViewport # .h=ok // .cpp=missing
@export var main_camera : Camera3D = null 
@export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080)

# Camera mode parameters
@export_group("Camera Controls")
@export var ortho_scale_multiplier: float = 1.0 #scale the orthographic projection size for the reflection camera.(lower values = bigger reflection)
@export var ortho_uv_scale: float = 1.0 # uv scale (1 = Normal // 0.5 = sample from half of texture (zoomed effect) // 2.0 = Sample larger area (tiled effect) )
@export var auto_detect_camera_mode: bool = true

# Layer and environment control
@export_group("Reflection Layers and Environment")
@export_flags_3d_render var reflection_layers: int = 1
@export var use_custom_environment: bool = true
@export var custom_environment: Environment

# NEW: Reflection Offset Controls
@export_group("Reflection Offset Control")
@export var enable_reflection_offset: bool = false
@export var reflection_offset_position: Vector3 = Vector3(0.0, 0.0, 0.0) # World space offset for reflection camera position
@export var reflection_offset_rotation: Vector3 = Vector3(0.0, 0.0, 0.0) # Euler angles offset for reflection camera rotation (degrees)
@export var reflection_offset_scale: float = 1.0 # Scale factor for offset effect
@export var offset_blend_mode: int = 0 # 0 = Add, 1 = Multiply, 2 = Screen space shift

# Performance parameters
@export_group("Performance Controls")
@export var update_frequency: int = 1 # Update every N frames (1 = every frame, 2 = every other frame)
@export var use_lod: bool = true # Auto reduce reflection resolution based on distance
@export var lod_distance_near: float = 10.0
@export var lod_distance_far: float = 30.0
@export var lod_resolution_multiplier: float = 0.45 # Multiply resolution by this when far

var active_shader_material: ShaderMaterial = null

# Internal optimization variables
var frame_counter: int = 0
var last_camera_position: Vector3
var last_camera_rotation: Basis
var position_threshold: float = 0.01 # Only update if camera moved this much
var rotation_threshold: float = 0.001 # Only update if camera rotated this much

# Advanced reflection calculation cache (for future optimizations)
var cached_reflection_plane: Plane
var is_layer_one_active: bool = true

# NEW: Offset calculation cache
var cached_offset_transform: Transform3D
var last_offset_position: Vector3
var last_offset_rotation: Vector3

func _ready():
	reflect_viewport = SubViewport.new()
	add_child(reflect_viewport)
	reflect_viewport.size = reflection_camera_resolution
	reflect_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reflect_viewport.msaa_3d = Viewport.MSAA_4X
	reflect_viewport.positional_shadow_atlas_size = 2048
	reflect_viewport.own_world_3d = false

	reflect_camera = Camera3D.new()
	reflect_viewport.add_child(reflect_camera)
	
	# Set reflection camera cull mask to exclude unwanted layers
	setup_reflection_layers()
	
	# Copy basic camera properties (but handle environment separately)
	reflect_camera.attributes = main_camera.attributes
	reflect_camera.doppler_tracking = main_camera.doppler_tracking
	
	# Handle environment/sky exclusion
	setup_reflection_environment()
	
	reflect_camera.current = true
	reflect_camera.make_current()
	
	# Initialize offset cache
	update_offset_cache()

func _process(_delta):
	update_viewport()
	if (!main_camera):
		return

	frame_counter += 1
	
	# Update offset cache if needed
	update_offset_cache()
	
	# Skip updates based on frequency and movement threshold
	var should_update = (frame_counter % update_frequency == 0)
	
	if should_update:
		var current_pos = main_camera.global_transform.origin
		var current_basis = main_camera.global_transform.basis
		
		# Check if camera moved/rotated enough to warrant update
		if last_camera_position != Vector3.ZERO:
			var pos_diff = current_pos.distance_to(last_camera_position)
			var rot_diff = current_basis.get_euler().distance_to(last_camera_rotation.get_euler())
			
			if pos_diff < position_threshold and rot_diff < rotation_threshold:
				return # Skip update if camera barely moved
		
		last_camera_position = current_pos
		last_camera_rotation = current_basis
		
		update_reflection_camera()
	
	if Engine.is_editor_hint(): # Force updates in editor to see changes immediately
		update_reflection_camera()

func setup_reflection_layers():
	#Configure which layers the reflection camera can see
	var cull_mask = reflection_layers
	reflect_camera.cull_mask = cull_mask
	
	# Check if layer 1 is active (bit 0 = layer 1)
	if cull_mask & (1 << (1 - 1)):
		is_layer_one_active = true
	else:
		is_layer_one_active = false
		print("Layer 1 not active, make sure to add the layers to the scene Lights cull masks")

func setup_reflection_environment():
	#Set up environment for reflection camera
	if use_custom_environment:
		var reflection_env = Environment.new()
		if custom_environment:
			reflection_env = custom_environment
		else:
			# Auto-generate clean environment
			reflection_env.background_mode = Environment.BG_CLEAR_COLOR
			# Copy lighting settings from main environment but exclude sky contribution
			if main_camera.environment:
				# Copy ambient light but not from sky
				if main_camera.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY:
					reflection_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
					reflection_env.ambient_light_color = Color(0.4, 0.4, 0.4) # Neutral gray
					reflection_env.ambient_light_energy = 0.3
				else:
					reflection_env.ambient_light_source = main_camera.environment.ambient_light_source
					reflection_env.ambient_light_color = main_camera.environment.ambient_light_color
					reflection_env.ambient_light_energy = main_camera.environment.ambient_light_energy
				
				# Copy other lighting but disable sky-dependent effects
				if main_camera.environment.has_method("get_fog_enabled"):
					reflection_env.fog_enabled = false # Disable fog to avoid sky color bleeding
		
		reflect_camera.environment = reflection_env
	else:
		# Use main camera environment as-is
		reflect_camera.environment = main_camera.environment

func calculate_reflection_plane() -> Plane:
	#Calculate the reflection plane with optional offset and perturbation
	var reflection_transform = global_transform * Transform3D().rotated(Vector3.RIGHT, PI/2)
	var plane_origin = reflection_transform.origin
	var plane_normal = reflection_transform.basis.z.normalized()
	return Plane(plane_normal, plane_origin.dot(plane_normal))

func update_reflection_camera():
	# Update camera projection based on main camera
	update_camera_projection()

	# Calculate reflection plane (with advanced features)
	var reflection_plane = calculate_reflection_plane()
	cached_reflection_plane = reflection_plane
	
	var cam_pos = main_camera.global_transform.origin
	
	var proj_pos := reflection_plane.project(cam_pos)
	var mirrored_pos = cam_pos + (proj_pos - cam_pos) * 2.0
	
	# NEW: Create base reflection transform
	var base_reflection_transform = Transform3D()
	base_reflection_transform.origin = mirrored_pos
	base_reflection_transform.basis = Basis(
		main_camera.basis.x.normalized().bounce(reflection_plane.normal).normalized(),
		main_camera.basis.y.normalized().bounce(reflection_plane.normal).normalized(),
		main_camera.basis.z.normalized().bounce(reflection_plane.normal).normalized()
	)
	
	# Apply reflection offset
	var final_reflection_transform = apply_reflection_offset(base_reflection_transform)
	# Set the final transform
	reflect_camera.global_transform = final_reflection_transform
	# Pass parameters to shader
	update_shader_parameters()

func update_shader_parameters():
	#Update all shader parameters including advanced features
	if active_shader_material == null:
		active_shader_material = get_active_material(0)
	
	var material: ShaderMaterial = active_shader_material

	if material == null:
		printerr("Material not found or is not shader material")
		return
	
	# Core reflection texture
	material.set_shader_parameter("reflection_screen_texture", reflect_viewport.get_texture())
	
	# Camera mode detection
	var is_orthogonal = false
	if Engine.is_editor_hint(): # Force perspective in editor
		is_orthogonal = false
	else:
		is_orthogonal = (main_camera.projection == Camera3D.PROJECTION_ORTHOGONAL)

	material.set_shader_parameter("is_orthogonal_camera", is_orthogonal)
	material.set_shader_parameter("ortho_uv_scale", ortho_uv_scale)
	
	# Pass reflection offset info to shader for additional effects
	material.set_shader_parameter("reflection_offset_enabled", enable_reflection_offset)
	material.set_shader_parameter("reflection_offset_position", reflection_offset_position)
	material.set_shader_parameter("reflection_offset_scale", reflection_offset_scale)
	material.set_shader_parameter("reflection_plane_normal", cached_reflection_plane.normal)
	material.set_shader_parameter("reflection_plane_distance", cached_reflection_plane.d)
	material.set_shader_parameter("planar_surface_y", global_transform.origin.y)

func update_camera_projection():
	if auto_detect_camera_mode:
		reflect_camera.projection = main_camera.projection
		if Engine.is_editor_hint(): # Force perspective in editor
			reflect_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	
	if reflect_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		reflect_camera.size = main_camera.size * ortho_scale_multiplier
	else:
		reflect_camera.fov = main_camera.fov

func update_viewport() -> void:
	var target_size = get_viewport().size
	
	# Apply LOD based on distance
	if use_lod and main_camera:
		var distance = global_transform.origin.distance_to(main_camera.global_transform.origin)
		var lod_factor = 1.0
		
		if distance > lod_distance_near:
			var lerp_factor = clamp((distance - lod_distance_near) / (lod_distance_far - lod_distance_near), 0.0, 1.0)
			lod_factor = lerp(1.0, lod_resolution_multiplier, lerp_factor)
		
		target_size = Vector2i(target_size * lod_factor)
		target_size.x = max(target_size.x, 128) # Minimum resolution
		target_size.y = max(target_size.y, 128)
	
	reflect_viewport.size = target_size

func apply_reflection_offset(base_transform: Transform3D) -> Transform3D:
	#Apply reflection offset to the base reflection transform#
	if not enable_reflection_offset:
		return base_transform
	
	var result_transform = base_transform
	
	match offset_blend_mode:
		0: # Add mode - simple addition of offset
			result_transform.origin += cached_offset_transform.origin
			# Apply rotational offset
			if reflection_offset_rotation != Vector3.ZERO:
				result_transform.basis = result_transform.basis * cached_offset_transform.basis
		
		1: # Multiply mode - relative to current transform
			result_transform = result_transform * cached_offset_transform
		
		2: # Screen space shift mode - offset relative to camera view
			if main_camera:
				var view_offset = main_camera.global_transform.basis * cached_offset_transform.origin
				result_transform.origin += view_offset
				result_transform.basis = result_transform.basis * cached_offset_transform.basis
	
	return result_transform

func update_offset_cache():
	#Update the cached offset transform when offset parameters change
	if not enable_reflection_offset:
		cached_offset_transform = Transform3D.IDENTITY
		return
	
	# Check if offset parameters changed
	if (last_offset_position != reflection_offset_position or 
		last_offset_rotation != reflection_offset_rotation):
		
		# Create offset transform
		var offset_basis = Basis()
		offset_basis = offset_basis.rotated(Vector3.RIGHT, deg_to_rad(reflection_offset_rotation.x))
		offset_basis = offset_basis.rotated(Vector3.UP, deg_to_rad(reflection_offset_rotation.y))
		offset_basis = offset_basis.rotated(Vector3.FORWARD, deg_to_rad(reflection_offset_rotation.z))
		
		cached_offset_transform = Transform3D(offset_basis, reflection_offset_position * reflection_offset_scale)
		
		last_offset_position = reflection_offset_position
		last_offset_rotation = reflection_offset_rotation
