@tool
extends Node

# This helper provides access to editor internals for the C++ extension
class_name PlanarReflectorEditorHelper

var editor_camera: Camera3D
var editor_viewport: SubViewport

signal editor_camera_changed(camera: Camera3D)

func _ready():
	set_process(false)  # We don't need constant processing

func set_helper_editor_camera(camera: Camera3D) -> void:
	if editor_camera != camera:
		editor_camera = camera
		if camera:
			editor_viewport = camera.get_viewport() as SubViewport
			editor_camera_changed.emit(camera)

func get_editor_camera() -> Camera3D:
	return editor_camera

func get_editor_viewport() -> SubViewport:
	if editor_camera:
		return editor_camera.get_viewport() as SubViewport
	return null

func get_editor_viewport_size() -> Vector2i:
	if editor_viewport:
		return editor_viewport.get_visible_rect().size
	return Vector2i(1920, 1080)  # Fallback size

# Additional helper methods
func is_editor_camera_valid() -> bool:
	return editor_camera != null and is_instance_valid(editor_camera)

func get_editor_camera_transform() -> Transform3D:
	if is_editor_camera_valid():
		return editor_camera.global_transform
	return Transform3D()

func get_editor_camera_projection() -> int:
	if is_editor_camera_valid():
		return editor_camera.projection
	return Camera3D.PROJECTION_PERSPECTIVE

func get_editor_camera_fov() -> float:
	if is_editor_camera_valid():
		return editor_camera.fov
	return 75.0

func get_editor_camera_size() -> float:
	if is_editor_camera_valid():
		return editor_camera.size
	return 1.0

#Compositor Helpers
func create_new_reflection_compositor() -> Compositor:
	var compositor = Compositor.new()
	var compositor_effect = ReflectEffectPrePassGD.new()
	compositor.set_compositor_effects([compositor_effect])
	print("[Planar helper]: Created new reflection compositor with ReflectEffectPrePassGD")
	return compositor


func update_reflection_compositor_effects(camera: Camera3D, params:Dictionary[String, Variant]) -> void:
	print("[Planar helper]: Called update_reflection_compositor_effects on camera: " + camera.name)
	if not camera or not camera.compositor:
		return
	
	if params.size() == 0:
		return
	
	var effects_enable_param:bool = params.get("effect_enabled", true)
	var intersect_height_param:float = params.get("intersect_height", 0.0)
	var fill_enabled_param:bool = params.get("fill_enabled", true)

	var effects = camera.compositor.compositor_effects
	for effect in effects:
		if effect is ReflectEffectPrePassGD:
			effect.effect_enabled = effects_enable_param
			effect.intersect_height = intersect_height_param		
			effect.fill_enabled = fill_enabled_param
			print("[Planar helper]: Updated ReflectEffectPrePassGD on camera: " + camera.name)
			break


func update_reflection_compositor_effects2(param: String) -> void:
	print("[Planar helper]: Called update_reflection_compositor_effects 2: " + param)

func update_reflection_compositor_effects3(camera) -> void:
	print("[Planar helper]: Called update_reflection_compositor_effects 3: " + camera.name)
	if camera is Camera3D:
		print("[Planar helper]: FOUND - Called update_reflection_compositor_effects 3: " + camera.name)
		return

func update_reflection_compositor_effects4(params) -> void:
	print("[Planar helper]: Called update_reflection_compositor_effects 4: " )
	if params is Dictionary:
		print("[Planar helper]: FOUND - Called update_reflection_compositor_effects 4: ")
		for key in params:
			print("[Planar helper]: Key: " + str(key) + " Value: " + str(params[key]))
		return


func update_reflection_compositor_effects5(param: String) -> void:
	print("[Planar helper]: Called update_reflection_compositor_effects 5: " + param)



# comp_effect.intersect_height = new_YAxis_height if override_YAxis_height else global_transform.origin.y
# comp_effect.effect_enabled = true
# comp_effect.fill_enabled = fill_reflection_experimental

# @export var effect_enabled: bool = true
# @export var intersect_height: float = 0.0
# @export var reflect_gap_fill: float = 0.0025

# # Hole handling
# @export var fill_enabled: bool = true