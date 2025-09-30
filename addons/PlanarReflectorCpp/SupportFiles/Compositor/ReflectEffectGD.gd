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
var temp_image: RID
var temp_sampler: RID

# cleanup fix 1: No caching - create/use/discard pattern per frame to avoid accumulation
# This prevents the systematic uniform buffer leaks identified in Issue

# Performance optimization caches
var last_params: PackedFloat32Array = []
var cached_matrix_data: PackedFloat32Array = []
var last_inv_proj_matrix: Projection = Projection()
var last_cam_transform: Transform3D = Transform3D()

const PARAM_FLOATS := 40

func _init() -> void:
	effect_callback_type = CB_TYPE
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)

#TODO(LOW): Fix #Bug - Compositor Effect is either Leaking RID or Errors with  "This function (free) can only be called from the render thread. "
#PREVIOUS CODE NOT WORKING ON SCENE TRANSITION CALL_DEFERRED
# cleanup fix 2: Direct cleanup in NOTIFICATION_PREDELETE to avoid null instance errors
# func _notification(what: int) -> void:
# 	if what == NOTIFICATION_PREDELETE:
# 		# cleanup fix 3: Inline cleanup to prevent null instance function call errors
# 		if rd != null:
			
# 			# cleanup fix 4: Only free root resources - dependency tracking handles the rest
# 			# This prevents "Attempted to free invalid ID" errors from double-freeing
			
# 			# Free temp resources first (no dependencies)
# 			if temp_image.is_valid():
# 				rd.free_rid(temp_image)
# 				temp_image = RID()
			
# 			if temp_sampler.is_valid():
# 				rd.free_rid(temp_sampler)
# 				temp_sampler = RID()
			
# 			if sampler_rid.is_valid():
# 				rd.free_rid(sampler_rid)
# 				sampler_rid = RID()
			
# 			if parameter_storage_buffer.is_valid():
# 				rd.free_rid(parameter_storage_buffer)
# 				parameter_storage_buffer = RID()
			
# 			# Free shader last - this automatically frees pipeline due to dependency tracking
# 			# DO NOT manually free pipeline - this causes double-free errors
# 			if shader.is_valid():
# 				rd.free_rid(shader)
# 				shader = RID()
# 				# pipeline is automatically freed by dependency tracking
				# pipeline = RID()

#TODO - TEMP NEW CODE (Attempting a Workaround) - try to make WORKING ON SCENE TRANSITION CALL_DEFERRED
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Capture RIDs locally before object destruction
		# print("Compositor _notification called for ReflectEffectPrePassGD")
		var cleanup_data = {
			"temp_image": temp_image,
			"temp_sampler": temp_sampler,
			"sampler_rid": sampler_rid,
			"parameter_storage_buffer": parameter_storage_buffer,
			"shader": shader,
			"pipeline": pipeline,
			"rd": rd
			}
		# Pass the cleanup data to render thread
		RenderingServer.call_on_render_thread(_cleanup_resources_static.bind(cleanup_data))

# Static cleanup function that doesn't reference 'self'
static func _cleanup_resources_static(cleanup_data: Dictionary) -> void:
	# print("Compositor cleanup started for ReflectEffectPrePassGD")
	var render_device = cleanup_data.get("rd")
	if not render_device:
		return
	
	# Free temp resources first (no dependencies)
	var temp_image = cleanup_data.get("temp_image")
	if temp_image and temp_image.is_valid():
		render_device.free_rid(temp_image)

	var temp_sampler = cleanup_data.get("temp_sampler")
	if temp_sampler and temp_sampler.is_valid():
		render_device.free_rid(temp_sampler)

	var sampler_rid = cleanup_data.get("sampler_rid")
	if sampler_rid and sampler_rid.is_valid():
		render_device.free_rid(sampler_rid)

	var parameter_storage_buffer = cleanup_data.get("parameter_storage_buffer")
	if parameter_storage_buffer and parameter_storage_buffer.is_valid():
		render_device.free_rid(parameter_storage_buffer)

	# Free shader last - this automatically frees pipeline due to dependency tracking
	var shader = cleanup_data.get("shader")
	if shader and shader.is_valid():
		render_device.free_rid(shader)
	# print("Compositor cleanup ended for ReflectEffectPrePassGD")

func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return

	var shader_file: RDShaderFile = load("uid://c6cyjnip1nl1v")
	if shader_file == null:
		shader_file = load("res://addons/PlanarReflectorCpp/SupportFiles/Compositor/reflection_effect_prepass_compute.glsl")

	if shader_file:
		var spirv: RDShaderSPIRV = shader_file.get_spirv()
		shader = rd.shader_create_from_spirv(spirv)

	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)

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

	var data := PackedFloat32Array()
	data.resize(PARAM_FLOATS)
	var bytes := data.to_byte_array()
	parameter_storage_buffer = rd.storage_buffer_create(bytes.size(), bytes)
	
	cached_matrix_data.resize(32)

func _ensure_temp_image(size: Vector2i, like_color: RID) -> void:
	if temp_image.is_valid():
		var info := rd.texture_get_format(temp_image)
		if info.width == size.x and info.height == size.y:
			return
		rd.free_rid(temp_image)
		temp_image = RID()

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

# cleanup fix 5: Create-use-discard pattern for uniform sets to prevent accumulation
func _create_uniform_set(color_tex: RID, depth_tex: RID, pass_type: int, temp_image_rid: RID) -> RID:
	var uniforms: Array[RDUniform] = []

	var u_params := RDUniform.new()
	u_params.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u_params.binding = 0
	u_params.add_id(parameter_storage_buffer)
	uniforms.append(u_params)

	var u_color_write := RDUniform.new()
	u_color_write.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_color_write.binding = 1
	if pass_type == 1:
		u_color_write.add_id(color_tex)
	else:
		u_color_write.add_id(temp_image_rid)
	uniforms.append(u_color_write)

	var u_depth := RDUniform.new()
	u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_depth.binding = 2
	u_depth.add_id(sampler_rid)
	u_depth.add_id(depth_tex)
	uniforms.append(u_depth)

	var u_src_color := RDUniform.new()
	u_src_color.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_src_color.binding = 3
	u_src_color.add_id(sampler_rid)
	u_src_color.add_id(color_tex)
	uniforms.append(u_src_color)

	var u_temp_image := RDUniform.new()
	u_temp_image.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u_temp_image.binding = 4
	u_temp_image.add_id(temp_image_rid)
	uniforms.append(u_temp_image)

	var u_temp_sampler := RDUniform.new()
	u_temp_sampler.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u_temp_sampler.binding = 5
	u_temp_sampler.add_id(temp_sampler)
	u_temp_sampler.add_id(temp_image_rid)
	uniforms.append(u_temp_sampler)

	# Create uniform set - will be automatically freed by GPU after use
	# DO NOT manually free these - GPU handles cleanup automatically
	return rd.uniform_set_create(uniforms, shader, 0)

func _update_params_if_changed(new_params: PackedFloat32Array) -> bool:
	if last_params.size() == new_params.size():
		var changed = false
		for i in range(new_params.size()):
			if abs(last_params[i] - new_params[i]) > 0.0001:
				changed = true
				break
		if not changed:
			return false
	
	var bytes = new_params.to_byte_array()
	rd.buffer_update(parameter_storage_buffer, 0, bytes.size(), bytes)
	last_params = new_params.duplicate()
	return true

func _cache_matrix_data(inv_proj: Projection, cam_xform: Transform3D) -> bool:
	var proj_changed = false
	var transform_changed = false
	
	if last_inv_proj_matrix != inv_proj:
		last_inv_proj_matrix = inv_proj
		proj_changed = true
		
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

		var params := PackedFloat32Array()
		params.resize(PARAM_FLOATS)
		params[0] = float(size.x)
		params[1] = float(size.y)
		params[2] = intersect_height
		params[3] = reflect_gap_fill

		var inv_proj := p_render_data.get_render_scene_data().get_cam_projection().inverse()
		var cam_xform: Transform3D = p_render_data.get_render_scene_data().get_cam_transform()
		
		_cache_matrix_data(inv_proj, cam_xform)
		
		for i in range(32):
			params[4 + i] = cached_matrix_data[i]

		params[36] = 1.0 if fill_enabled else 0.0
		params[37] = float(fill_radius_px)
		params[38] = clamp(fill_aggressiveness, 0.0, 1.0)

		# PASS 1: horizontal
		params[39] = 0.0
		_update_params_if_changed(params)
		
		#  cleanup fix 6: Create uniform set for immediate use only
		var uniform_set_h: RID = _create_uniform_set(color_tex, depth_tex, 0, temp_image)

		var cl1 := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl1, pipeline)
		rd.compute_list_bind_uniform_set(cl1, uniform_set_h, 0)
		rd.compute_list_dispatch(cl1, x_groups, y_groups, 1)
		rd.compute_list_end()
		# Uniform set is automatically cleaned up by GPU after use

		# PASS 2: vertical
		params[39] = 1.0
		var bytes2 := params.to_byte_array()
		rd.buffer_update(parameter_storage_buffer, 0, bytes2.size(), bytes2)

		var uniform_set_v: RID = _create_uniform_set(color_tex, depth_tex, 1, temp_image)

		var cl2 := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl2, pipeline)
		rd.compute_list_bind_uniform_set(cl2, uniform_set_v, 0)
		rd.compute_list_dispatch(cl2, x_groups, y_groups, 1)
		rd.compute_list_end()
		# Uniform set is automatically cleaned up by GPU after use