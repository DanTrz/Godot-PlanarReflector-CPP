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