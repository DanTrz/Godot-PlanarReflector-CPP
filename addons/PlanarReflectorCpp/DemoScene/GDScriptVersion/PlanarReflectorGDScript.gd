
#GDScript version 
@tool
extends MeshInstance3D

var reflect_camera: Camera3D
var reflect_viewport: SubViewport
var editor_camera: Camera3D = null
@export var main_camera: Camera3D = null

#region EXPORTED VARIABLES
@export var reflection_camera_resolution: Vector2i = Vector2i(1920, 1080):
	set(value):
		reflection_camera_resolution = value
		if is_inside_tree():
			update_reflect_viewport_size()

@export_group("Camera Controls")
@export var ortho_scale_multiplier: float = 1.0
@export var ortho_uv_scale: float = 1.0
@export var auto_detect_camera_mode: bool = true

@export_group("Reflection Layers and Environment")
@export_flags_3d_render var reflection_layers: int = 1
@export var use_custom_environment: bool = false:
	set(value):
		use_custom_environment = value
		if is_inside_tree():
			setup_reflection_environment()
@export var custom_environment: Environment = null

@export_group("Reflection Compositor Effects")
@export var use_custom_compositor: bool = false:
	set(value):
		use_custom_compositor = value
		if is_inside_tree():
			setup_compositor_reflection_effect(reflect_camera)
@export var custom_compositor: Compositor = null
@export var hide_intersect_reflections: bool = true:
	set(value):
		hide_intersect_reflections = value
		if value == true:
			setup_compositor_reflection_effect(reflect_camera)
		else:
			clear_compositor_reflection_effect(reflect_camera)
@export var override_YAxis_height: bool = false:
	set(value):
		override_YAxis_height = value
		if is_inside_tree():
			setup_compositor_reflection_effect(reflect_camera)
@export var new_YAxis_height: float = 0.0:
	set(value):
		new_YAxis_height = value
		if is_inside_tree():
			setup_compositor_reflection_effect(reflect_camera)
@export var fill_reflection_experimental: bool = false:
	set(value):
		fill_reflection_experimental = value
		if is_inside_tree():
			setup_compositor_reflection_effect(reflect_camera)

@export_group("Reflection Offset Control")
@export var enable_reflection_offset: bool = false:
	set(value):
		enable_reflection_offset = value
		if is_inside_tree():
			update_offset_cache()
			set_reflection_camera_transform()
@export var reflection_offset_position: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var reflection_offset_rotation: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var reflection_offset_scale: float = 1.0
@export var offset_blend_mode: int = 0

@export_group("Performance Controls")
@export var update_frequency: int = 2
@export var use_lod: bool = true:
	set(value):
		use_lod = value
		if is_inside_tree():
			update_reflect_viewport_size()
@export var lod_distance_near: float = 8.0:
	set(value):
		lod_distance_near = value
		if is_inside_tree():
			update_reflect_viewport_size()
@export var lod_distance_far: float = 24.0:
	set(value):
		lod_distance_far = value
		if is_inside_tree():
			update_reflect_viewport_size()
@export var lod_resolution_multiplier: float = 0.45:
	set(value):
		lod_resolution_multiplier = value
		if is_inside_tree():
			update_reflect_viewport_size()
#endregion EXPORTED VARIABLES

# Core internal variables
var editor_helper: Node = null
var active_shader_material: ShaderMaterial = null
var reflection_compositor_effect: ReflectEffectPrePassGD = null

# Performance tracking variables
var frame_counter: int = 0
var last_camera_position: Vector3 = Vector3.ZERO
var last_camera_rotation: Basis = Basis()
var position_threshold: float = 0.01
var rotation_threshold: float = 0.001

# Cached calculations
var cached_reflection_plane: Plane = Plane()
var is_layer_one_active: bool = true
var cached_offset_transform: Transform3D = Transform3D.IDENTITY
var last_offset_position: Vector3 = Vector3.ZERO
var last_offset_rotation: Vector3 = Vector3.ZERO

# IMPROVEMENT 1: Enhanced material caching with proper invalidation  
var cached_material_reference: WeakRef = null
var material_cache_valid: bool = false

# IMPROVEMENT 2: Batch shader parameter updates with change detection
var cached_shader_params: Dictionary = {}
var last_reflection_texture: Texture2D = null

# IMPROVEMENT 3: Optimized viewport size checking
var cached_viewport_size: Vector2i = Vector2i.ZERO
var last_viewport_check_frame: int = -1
var viewport_check_frequency: int = 5

# IMPROVEMENT 5: Cached reflection plane calculations
var last_global_transform: Transform3D = Transform3D.IDENTITY
var reflection_plane_cache_valid: bool = false
var last_distance_check: float = -1.0
var cached_lod_factor: float = 1.0

func _ready() -> void:
	intial_setup()

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		# IMPROVEMENT 5: Invalidate reflection plane cache when transform changes
		reflection_plane_cache_valid = false
		if reflect_camera and reflect_camera.compositor:
			set_reflection_effect(get_reflection_effect(reflect_camera.compositor))

func intial_setup() -> void:
	# Core Setup - KEEP ORIGINAL WORKING STRUCTURE
	add_to_group("planar_reflectors")
	find_editor_helper()
	setup_reflection_camera_and_viewport()
	update_offset_cache()

	# Initialize performance caches
	invalidate_all_caches()

	# Regular update loop
	update_reflect_viewport_size()
	set_reflection_camera_transform()

func _process(_delta: float) -> void:
	# Keep original structure but add safety checks
	if not is_inside_tree():
		return
	
	frame_counter += 1
	update_offset_cache()
	
	# IMPROVEMENT 3: Less frequent viewport size updates with safety
	if viewport_check_frequency > 0 and frame_counter % viewport_check_frequency == 0:
		update_reflect_viewport_size()
	
	var should_update: bool = (update_frequency > 0 and frame_counter % update_frequency == 0)
	if should_update:
		var active_cam: Camera3D = editor_camera if Engine.is_editor_hint() else main_camera
		if active_cam and should_update_reflection(active_cam):
			set_reflection_camera_transform()

func setup_reflection_camera_and_viewport() -> void:
	# KEEP YOUR ORIGINAL WORKING STRUCTURE - NO CHANGES TO VIEWPORT CREATION ORDER
	reflect_viewport = SubViewport.new()
	reflect_viewport.name = "ReflectionViewPort"
	add_child(reflect_viewport)
	reflect_viewport.size = reflection_camera_resolution
	reflect_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reflect_viewport.msaa_3d = Viewport.MSAA_DISABLED
	reflect_viewport.positional_shadow_atlas_size = 2048
	reflect_viewport.own_world_3d = false
	reflect_viewport.transparent_bg = true
	reflect_viewport.handle_input_locally = false

	# Setup the reflection camera
	reflect_camera = Camera3D.new()
	reflect_viewport.add_child(reflect_camera)
	
	# Setup the reflection camera cull mask / layers
	var cull_mask: int = reflection_layers
	reflect_camera.cull_mask = cull_mask
	is_layer_one_active = bool(cull_mask & (1 << 0))
	if not is_layer_one_active:
		print("Layer 1 not active, make sure to add the layers to the scene Lights cull masks")
	
	# Copy main camera properties to reflection camera
	if main_camera:
		reflect_camera.attributes = main_camera.attributes
		reflect_camera.doppler_tracking = main_camera.doppler_tracking
	reflect_camera.current = true
	reflect_camera.make_current()

	# After camera setup, we can set the camera environment
	setup_reflection_environment()

	# Setup the reflection camera CompositorEffect
	if hide_intersect_reflections:
		setup_compositor_reflection_effect(reflect_camera)
	else:
		clear_compositor_reflection_effect(reflect_camera)

func setup_reflection_environment() -> void:
	# Prepare or copy the environment for the reflection camera
	var reflection_env: Environment = Environment.new()
	if use_custom_environment:
		if custom_environment:
			reflection_env = custom_environment
	else:
		reflection_env.background_mode = Environment.BG_CLEAR_COLOR
		reflection_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		reflection_env.ambient_light_color = Color.LIGHT_GRAY
		reflection_env.ambient_light_energy = 1
	
	reflect_camera.environment = reflection_env

func calculate_reflection_plane() -> Plane:
	# IMPROVEMENT 5: Cache reflection plane calculations when transform unchanged
	if not is_inside_tree():
		return Plane()
		
	var current_transform = global_transform
	if reflection_plane_cache_valid and current_transform.is_equal_approx(last_global_transform):
		return cached_reflection_plane
	
	var reflection_transform: Transform3D = current_transform * Transform3D().rotated(Vector3.RIGHT, PI/2)
	var plane_origin: Vector3 = reflection_transform.origin
	var plane_normal: Vector3 = reflection_transform.basis.z.normalized()
	
	cached_reflection_plane = Plane(plane_normal, plane_origin.dot(plane_normal))
	last_global_transform = current_transform
	reflection_plane_cache_valid = true
	
	return cached_reflection_plane

func set_reflection_camera_transform() -> void:
	if not is_inside_tree():
		return
		
	var active_camera: Camera3D = main_camera
	find_editor_helper()
	if Engine.is_editor_hint():
		if editor_camera:
			active_camera = editor_camera
			active_camera.name = "EditorCamera"

	if active_camera == null:
		return
		
	update_camera_projection()
	var reflection_plane: Plane = calculate_reflection_plane()
	var cam_pos: Vector3 = active_camera.global_transform.origin
	var proj_pos: Vector3 = reflection_plane.project(cam_pos)
	var mirrored_pos: Vector3 = cam_pos + (proj_pos - cam_pos) * 2.0
	var base_reflection_transform: Transform3D = Transform3D()
	base_reflection_transform.origin = mirrored_pos
	var main_basis: Basis = active_camera.global_transform.basis
	var n: Vector3 = reflection_plane.normal
	var reflection_basis: Basis = Basis(
		main_basis.x.normalized().bounce(n).normalized(),
		main_basis.y.normalized().bounce(n).normalized(),
		main_basis.z.normalized().bounce(n).normalized()
	)
	base_reflection_transform.basis = reflection_basis
	var final_reflection_transform: Transform3D = apply_reflection_offset(base_reflection_transform)
	reflect_camera.global_transform = final_reflection_transform
	
	# To ensure sync, we update shaders after the camera render data is updated
	update_shader_parameters()

func update_shader_parameters() -> void:
	# IMPROVEMENT 1: Enhanced material caching with proper invalidation
	if not is_material_cache_valid():
		refresh_material_cache()
	
	var material: ShaderMaterial = get_cached_material()
	if material == null:
		return
	
	# IMPROVEMENT 2: Batch shader parameter updates with change detection
	var reflection_texture = reflect_viewport.get_texture()
	var is_orthogonal: bool = false
	if Engine.is_editor_hint():
		is_orthogonal = reflect_camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	else:
		is_orthogonal = (main_camera and main_camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	
	# Prepare all parameters in a dictionary for batch comparison
	var new_params = {
		"reflection_screen_texture": reflection_texture,
		"is_orthogonal_camera": is_orthogonal,
		"ortho_uv_scale": ortho_uv_scale,
		"reflection_offset_enabled": enable_reflection_offset,
		"reflection_offset_position": reflection_offset_position,
		"reflection_offset_scale": reflection_offset_scale,
		"reflection_plane_normal": cached_reflection_plane.normal,
		"reflection_plane_distance": cached_reflection_plane.d,
		"planar_surface_y": global_transform.origin.y
	}
	
	# Only update parameters that have changed
	for param_name in new_params:
		var new_value = new_params[param_name]
		if not cached_shader_params.has(param_name) or not _values_equal(cached_shader_params[param_name], new_value):
			material.set_shader_parameter(param_name, new_value)
			cached_shader_params[param_name] = new_value

func update_camera_projection() -> void:
	var active_cam: Camera3D = editor_camera if Engine.is_editor_hint() else main_camera
	if active_cam == null:
		return
	if auto_detect_camera_mode:
		reflect_camera.projection = active_cam.projection
	if reflect_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		reflect_camera.size = active_cam.size * ortho_scale_multiplier
	else:
		reflect_camera.fov = active_cam.fov

func update_reflect_viewport_size() -> void:
	# IMPROVEMENT 3: Optimized viewport size checking frequency  
	if frame_counter - last_viewport_check_frame < viewport_check_frequency:
		return
	last_viewport_check_frame = frame_counter
	
	var target_size: Vector2i = get_target_viewport_size()
	var active_cam: Camera3D = editor_camera if Engine.is_editor_hint() else main_camera
	
	if use_lod and active_cam:
		target_size = apply_lod_to_size(target_size, active_cam)
	
	# Only update if size actually changed
	if cached_viewport_size != target_size:
		reflect_viewport.size = target_size
		cached_viewport_size = target_size

func apply_reflection_offset(base_transform: Transform3D) -> Transform3D:
	if not enable_reflection_offset:
		return base_transform
	var result_transform: Transform3D = base_transform
	
	match offset_blend_mode:
		0:
			result_transform.origin += cached_offset_transform.origin
			if reflection_offset_rotation != Vector3.ZERO:
				result_transform.basis = result_transform.basis * cached_offset_transform.basis
		1:
			result_transform = result_transform * cached_offset_transform
		2:
			if main_camera:
				var view_offset: Vector3 = main_camera.global_transform.basis * cached_offset_transform.origin
				result_transform.origin += view_offset
				result_transform.basis = result_transform.basis * cached_offset_transform.basis
	return result_transform

func update_offset_cache() -> void:
	if not enable_reflection_offset:
		cached_offset_transform = Transform3D.IDENTITY
		return
	
	# Optimized: Only recalculate if values actually changed
	if (last_offset_position.is_equal_approx(reflection_offset_position) and 
		last_offset_rotation.is_equal_approx(reflection_offset_rotation)):
		return
		
	var offset_basis: Basis = Basis()
	offset_basis = offset_basis.rotated(Vector3.RIGHT, deg_to_rad(reflection_offset_rotation.x))
	offset_basis = offset_basis.rotated(Vector3.UP, deg_to_rad(reflection_offset_rotation.y))
	offset_basis = offset_basis.rotated(Vector3.FORWARD, deg_to_rad(reflection_offset_rotation.z))
	cached_offset_transform = Transform3D(offset_basis, reflection_offset_position * reflection_offset_scale)
	last_offset_position = reflection_offset_position
	last_offset_rotation = reflection_offset_rotation

#region PERFORMANCE IMPROVEMENT HELPER FUNCTIONS

# IMPROVEMENT 1: Enhanced material caching
func is_material_cache_valid() -> bool:
	if not material_cache_valid or cached_material_reference == null:
		return false
	return cached_material_reference.get_ref() != null

func refresh_material_cache() -> void:
	if mesh == null or get_surface_override_material_count() == 0:
		cached_material_reference = null
		material_cache_valid = false
		return

	var material = get_active_material(0)
	if material != null and material is ShaderMaterial:
		cached_material_reference = weakref(material)
		material_cache_valid = true
	else:
		cached_material_reference = null
		material_cache_valid = false

func get_cached_material() -> ShaderMaterial:
	if is_material_cache_valid():
		return cached_material_reference.get_ref() as ShaderMaterial
	return null

# IMPROVEMENT 2: Helper for value comparison
func _values_equal(a, b) -> bool:
	if a == b:
		return true
	if a is Vector3 and b is Vector3:
		return a.is_equal_approx(b)
	if a is float and b is float:
		return is_equal_approx(a, b)
	return false

# IMPROVEMENT 3: Helper functions for viewport calculations
func get_target_viewport_size() -> Vector2i:
	var target_size: Vector2i
	if Engine.is_editor_hint() and editor_helper and editor_helper.has_method("get_editor_viewport_size"):
		var result = editor_helper.call("get_editor_viewport_size")
		if typeof(result) == TYPE_VECTOR2I:
			target_size = result
		else:
			target_size = get_viewport().get_visible_rect().size
	else:
		target_size = get_viewport().get_visible_rect().size
	return target_size

func apply_lod_to_size(target_size: Vector2i, active_cam: Camera3D) -> Vector2i:
	if not is_inside_tree():
		return target_size
		
	var distance: float = global_transform.origin.distance_to(active_cam.global_transform.origin)
	
	# Cache LOD calculations when distance hasn't changed much
	if abs(distance - last_distance_check) > 1.0:
		var lod_factor: float = 1.0
		if distance > lod_distance_near:
			var lerp_factor: float = clamp((distance - lod_distance_near) / (lod_distance_far - lod_distance_near), 0.0, 1.0)
			lod_factor = lerp(1.0, lod_resolution_multiplier, lerp_factor)
		cached_lod_factor = lod_factor
		last_distance_check = distance
	
	var result_size = Vector2i(target_size * cached_lod_factor)
	result_size.x = max(result_size.x, 128)
	result_size.y = max(result_size.y, 128)
	return result_size

# IMPROVEMENT 5: Enhanced reflection update detection
func should_update_reflection(active_cam: Camera3D) -> bool:
	if not active_cam or not is_inside_tree():
		return false
		
	var current_pos: Vector3 = active_cam.global_transform.origin
	var current_basis: Basis = active_cam.global_transform.basis
	
	# Optimized: Use is_equal_approx for faster comparison (FIXED - removed extra parameters)
	if last_camera_position != Vector3.ZERO:
		if current_pos.is_equal_approx(last_camera_position):
			var current_euler = current_basis.get_euler()
			var last_euler = last_camera_rotation.get_euler()
			if current_euler.is_equal_approx(last_euler):
				return false
	
	last_camera_position = current_pos
	last_camera_rotation = current_basis
	return true

func invalidate_all_caches() -> void:
	material_cache_valid = false
	cached_material_reference = null
	cached_shader_params.clear()
	reflection_plane_cache_valid = false
	last_viewport_check_frame = -1
	cached_viewport_size = Vector2i.ZERO

#endregion

#region EDITOR AND PLUGIN HELPER METHODS
func find_editor_helper() -> void:
	if Engine.is_editor_hint():
		if Engine.has_singleton("PlanarReflectorEditorHelper"):
			editor_helper = Engine.get_singleton("PlanarReflectorEditorHelper")

func set_editor_camera(viewport_camera: Camera3D) -> void:
	editor_camera = viewport_camera
	# Invalidate caches when editor camera changes
	invalidate_all_caches()
	update_reflect_viewport_size()
	set_reflection_camera_transform()

func is_planar_reflector_active() -> bool:
	return true

func get_active_camera() -> Camera3D:
	return main_camera
#endregion

#region REFLECTION COMPOSITOR AND REFLECTION MASK METHODS

func setup_compositor_reflection_effect(reflect_cam: Camera3D) -> void:
	if use_custom_compositor and custom_compositor:
		reflect_cam.compositor = custom_compositor
		var active_effect = reflect_cam.compositor.compositor_effects[0] if reflect_cam.compositor.compositor_effects.size() > 0 else null
		if active_effect is ReflectEffectPrePassGD:
			reflect_cam.compositor.set_compositor_effects([set_reflection_effect(active_effect)])
	else:
		if reflect_cam.compositor == null:
			create_new_compositor_effect(reflect_cam)
		else:
			var active_effect = reflect_cam.compositor.compositor_effects[0] if reflect_cam.compositor.compositor_effects.size() > 0 else null
			if active_effect is ReflectEffectPrePassGD:
				set_reflection_effect(active_effect)

func create_new_compositor_effect(reflect_cam: Camera3D) -> void:
	if reflect_cam.compositor:
		clear_compositor_reflection_effect(reflect_cam)
	
	reflect_cam.compositor = Compositor.new()
	var prepass_effect := ReflectEffectPrePassGD.new()
	reflect_cam.compositor.set_compositor_effects([set_reflection_effect(prepass_effect)])

func set_reflection_effect(comp_effect: CompositorEffect) -> CompositorEffect:
	if comp_effect is ReflectEffectPrePassGD:
		comp_effect.intersect_height = new_YAxis_height if override_YAxis_height else global_transform.origin.y
		comp_effect.effect_enabled = true
		comp_effect.fill_enabled = fill_reflection_experimental
		return comp_effect
	return null

func clear_compositor_reflection_effect(reflect_cam: Camera3D) -> void:
	if reflect_cam.compositor:
		reflect_cam.compositor.compositor_effects.clear()	
		reflect_cam.compositor = null

func get_reflection_effect(comp: Compositor) -> Variant:
	if comp == null:
		return null
	for effect in comp.compositor_effects:
		if effect is ReflectEffectPrePassGD:
			return effect
	return null

#endregion