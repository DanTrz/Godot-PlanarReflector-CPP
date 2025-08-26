@tool
class_name ReflectEffectPrePassGD
extends CompositorEffect

const CB_TYPE := EFFECT_CALLBACK_TYPE_POST_OPAQUE

# --- Controls ---
@export var effect_enabled: bool = true
@export var intersect_height: float = 0.0
@export var reflect_gap_fill: float = 0.0025

# Hole handling
@export var fill_enabled: bool = true
@export_range(1, 96, 1) var fill_radius_px: float = 24
@export_range(0.0, 2.0, 0.01) var fill_aggressiveness: float = 1.0

# --- RD resources ---
var rd: RenderingDevice
var shader: RID
var pipeline: RID
var sampler_rid: RID
var parameter_storage_buffer: RID
var temp_image: RID        # scratch image (same size/format as color)
var temp_sampler: RID

# Performance optimization caches
var cached_uniform_sets: Dictionary = {}
var last_params: PackedFloat32Array = []
var cached_matrix_data: PackedFloat32Array = []
var last_inv_proj_matrix: Projection = Projection()
var last_cam_transform: Transform3D = Transform3D()

# std430 buffer layout:
#  0..1   : vec2  raster_size
#  2      : float intersect_height
#  3      : float reflect_gap_fill
#  4..19  : mat4  inv_proj_mat
# 20..35  : mat4  inv_view_mat
# 36      : float fill_enable (0/1)
# 37      : float fill_radius_px
# 38      : float fill_aggressiveness (0..1)
# 39      : float pass_dir  (0 = horizontal, 1 = vertical)
const PARAM_FLOATS := 40

func _init() -> void:
	effect_callback_type = CB_TYPE
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(self):
			RenderingServer.call_on_render_thread(_free_gpu)

func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return

	# Compile compute shader
	var shader_file: RDShaderFile = load("res://addons/PlanarReflectorCpp/SupportFiles/reflection_effect_prepass_compute.glsl")
	if shader_file:
		var spirv: RDShaderSPIRV = shader_file.get_spirv()
		shader = rd.shader_create_from_spirv(spirv)

	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)

	# Samplers
	var s := RDSamplerState.new()
	s.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	s.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	s.mip_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_rid = rd.sampler_create(s)

	var s_lin := RDSamplerState.new()
	s_lin.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	s_lin.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	s_lin.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	temp_sampler = rd.sampler_create(s_lin)

	# Param buffer
	var data := PackedFloat32Array()
	data.resize(PARAM_FLOATS)
	var bytes := data.to_byte_array()
	parameter_storage_buffer = rd.storage_buffer_create(bytes.size(), bytes)
	
	# Initialize cache arrays
	cached_matrix_data.resize(32) # For both matrices (16 floats each)

func _free_gpu() -> void:
	if rd == null:
		return
	
	# Free cached uniform sets
	for key in cached_uniform_sets:
		var uniform_set_rid = cached_uniform_sets[key]
		if uniform_set_rid.is_valid():
			rd.free_rid(uniform_set_rid)
	cached_uniform_sets.clear()
	
	if temp_image.is_valid():
		rd.free_rid(temp_image)
	if temp_sampler.is_valid():
		rd.free_rid(temp_sampler)
	if sampler_rid.is_valid():
		rd.free_rid(sampler_rid)
	if parameter_storage_buffer.is_valid():
		rd.free_rid(parameter_storage_buffer)
	if pipeline.is_valid():
		rd.free_rid(pipeline)
	if shader.is_valid():
		rd.free_rid(shader)

func _ensure_temp_image(size: Vector2i, like_color: RID) -> void:
	# Create a same-format storage+sampled image for the separable pass
	if temp_image.is_valid():
		var info := rd.texture_get_format(temp_image)
		if info.width == size.x and info.height == size.y:
			return
		rd.free_rid(temp_image)

	var fmt := rd.texture_get_format(like_color)
	var tf := RDTextureFormat.new()
	tf.width = size.x
	tf.height = size.y
	tf.depth = 1
	tf.array_layers = 1
	tf.mipmaps = 1
	tf.samples = RenderingDevice.TEXTURE_SAMPLES_1
	tf.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	tf.format = fmt.format
	tf.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	temp_image = rd.texture_create(tf, RDTextureView.new(), [])
	# No need to initialize contents; we fully overwrite.

func _get_or_create_uniform_set(color_tex: RID, depth_tex: RID, pass_type: int, temp_image_rid: RID) -> RID:
	# Create a unique key for this combination
	var key = str(color_tex.get_id()) + "_" + str(depth_tex.get_id()) + "_" + str(pass_type) + "_" + str(temp_image_rid.get_id())
	
	if key in cached_uniform_sets:
		return cached_uniform_sets[key]
	
	# Create new uniform set
	var u_params := RDUniform.new()
	u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_params.binding = 0
	u_params.add_id(parameter_storage_buffer)

	var u_color_write := RDUniform.new()
	u_color_write.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_color_write.binding = 1
	if pass_type == 1: # vertical pass writes to color
		u_color_write.add_id(color_tex)
	else: # horizontal pass dummy binding
		u_color_write.add_id(temp_image_rid)

	var u_depth := RDUniform.new()
	u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_depth.binding = 2
	u_depth.add_id(sampler_rid)
	u_depth.add_id(depth_tex)

	var u_src_color := RDUniform.new()
	u_src_color.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_src_color.binding = 3
	u_src_color.add_id(sampler_rid)
	u_src_color.add_id(color_tex)

	var u_temp_image := RDUniform.new()
	u_temp_image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_temp_image.binding = 4
	u_temp_image.add_id(temp_image_rid)

	var u_temp_sampler := RDUniform.new()
	u_temp_sampler.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_temp_sampler.binding = 5
	u_temp_sampler.add_id(temp_sampler)
	u_temp_sampler.add_id(temp_image_rid)

	var uniform_set: RID = rd.uniform_set_create([u_params, u_color_write, u_depth, u_src_color, u_temp_image, u_temp_sampler], shader, 0)
	cached_uniform_sets[key] = uniform_set
	return uniform_set

func _update_params_if_changed(new_params: PackedFloat32Array) -> bool:
	# Quick check if parameters have changed
	if last_params.size() == new_params.size():
		var changed = false
		for i in range(new_params.size()):
			if abs(last_params[i] - new_params[i]) > 0.0001: # Small epsilon for float comparison
				changed = true
				break
		if not changed:
			return false
	
	# Parameters changed, update buffer
	var bytes = new_params.to_byte_array()
	rd.buffer_update(parameter_storage_buffer, 0, bytes.size(), bytes)
	last_params = new_params.duplicate()
	return true

func _cache_matrix_data(inv_proj: Projection, cam_xform: Transform3D) -> bool:
	# Check if matrices have changed significantly
	var proj_changed = false
	var transform_changed = false
	
	if last_inv_proj_matrix != inv_proj:
		last_inv_proj_matrix = inv_proj
		proj_changed = true
		
		# Cache inverse projection matrix data
		cached_matrix_data[0]  = inv_proj.x.x; cached_matrix_data[1]  = inv_proj.x.y
		cached_matrix_data[2]  = inv_proj.x.z; cached_matrix_data[3]  = inv_proj.x.w
		cached_matrix_data[4]  = inv_proj.y.x; cached_matrix_data[5]  = inv_proj.y.y
		cached_matrix_data[6]  = inv_proj.y.z; cached_matrix_data[7]  = inv_proj.y.w
		cached_matrix_data[8]  = inv_proj.z.x; cached_matrix_data[9]  = inv_proj.z.y
		cached_matrix_data[10] = inv_proj.z.z; cached_matrix_data[11] = inv_proj.z.w
		cached_matrix_data[12] = inv_proj.w.x; cached_matrix_data[13] = inv_proj.w.y
		cached_matrix_data[14] = inv_proj.w.z; cached_matrix_data[15] = inv_proj.w.w
	
	if not last_cam_transform.is_equal_approx(cam_xform):
		last_cam_transform = cam_xform
		transform_changed = true
		
		# Cache camera transform data
		cached_matrix_data[16] = cam_xform.basis.x.x; cached_matrix_data[17] = cam_xform.basis.x.y
		cached_matrix_data[18] = cam_xform.basis.x.z; cached_matrix_data[19] = 0.0
		cached_matrix_data[20] = cam_xform.basis.y.x; cached_matrix_data[21] = cam_xform.basis.y.y
		cached_matrix_data[22] = cam_xform.basis.y.z; cached_matrix_data[23] = 0.0
		cached_matrix_data[24] = cam_xform.basis.z.x; cached_matrix_data[25] = cam_xform.basis.z.y
		cached_matrix_data[26] = cam_xform.basis.z.z; cached_matrix_data[27] = 0.0
		cached_matrix_data[28] = cam_xform.origin.x;  cached_matrix_data[29] = cam_xform.origin.y
		cached_matrix_data[30] = cam_xform.origin.z;  cached_matrix_data[31] = 1.0
	
	return proj_changed or transform_changed

func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if p_effect_callback_type != CB_TYPE:
		return
	if not effect_enabled:
		return
	if rd == null or not shader.is_valid() or not pipeline.is_valid() or not sampler_rid.is_valid():
		return

	var rsb := p_render_data.get_render_scene_buffers()
	if rsb == null:
		return

	var size: Vector2i = rsb.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	var x_groups: int = int((size.x + 7) / 8)
	var y_groups: int = int((size.y + 7) / 8)

	var view_count: int = rsb.get_view_count()
	for view in range(view_count):
		var color_tex: RID = rsb.get_color_layer(view)
		var depth_tex: RID = rsb.get_depth_layer(view)
		if not color_tex.is_valid() or not depth_tex.is_valid():
			continue

		_ensure_temp_image(size, color_tex)

		# Base params (shared by both passes)
		var params := PackedFloat32Array()
		params.resize(PARAM_FLOATS)
		params[0] = float(size.x)
		params[1] = float(size.y)
		params[2] = intersect_height
		params[3] = reflect_gap_fill

		# Optimized: Use cached matrix data and only recalculate if changed
		var inv_proj := p_render_data.get_render_scene_data().get_cam_projection().inverse()
		var cam_xform: Transform3D = p_render_data.get_render_scene_data().get_cam_transform()
		
		var matrices_changed = _cache_matrix_data(inv_proj, cam_xform)
		
		# Copy cached matrix data to params array
		for i in range(32):
			params[4 + i] = cached_matrix_data[i]

		params[36] = 1.0 if fill_enabled else 0.0
		params[37] = float(fill_radius_px)
		params[38] = clamp(fill_aggressiveness, 0.0, 1.0)

		# ---------- PASS 1: horizontal -> write temp_image ----------
		params[39] = 0.0  # pass_dir = horizontal
		
		# Optimized: Only update buffer if parameters actually changed
		var params_changed = _update_params_if_changed(params)
		
		# Get or create cached uniform set for horizontal pass
		var uniform_set_h: RID = _get_or_create_uniform_set(color_tex, depth_tex, 0, temp_image)

		var cl1 := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl1, pipeline)
		rd.compute_list_bind_uniform_set(cl1, uniform_set_h, 0)
		rd.compute_list_dispatch(cl1, x_groups, y_groups, 1)
		rd.compute_list_end()

		# ---------- PASS 2: vertical -> read temp, write color ----------
		params[39] = 1.0  # pass_dir = vertical
		
		# Update buffer for vertical pass (only pass_dir changed)
		var bytes2 := params.to_byte_array()
		rd.buffer_update(parameter_storage_buffer, 0, bytes2.size(), bytes2)

		# Get or create cached uniform set for vertical pass
		var uniform_set_v: RID = _get_or_create_uniform_set(color_tex, depth_tex, 1, temp_image)

		var cl2 := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl2, pipeline)
		rd.compute_list_bind_uniform_set(cl2, uniform_set_v, 0)
		rd.compute_list_dispatch(cl2, x_groups, y_groups, 1)
		rd.compute_list_end()
	