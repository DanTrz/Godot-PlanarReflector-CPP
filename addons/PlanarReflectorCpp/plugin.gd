@tool
extends EditorPlugin

const PLUGIN_NAME = "PlanarReflectorCPP"
const EDITOR_HELPER_NAME = "PlanarReflectorEditorHelper"

const planar_editor_helper_path:String = "res://addons/PlanarReflectorCpp/planar_reflector_editor_helper.gd"

var editor_camera_helper:Node
var current_editor_camera: Camera3D

func _enter_tree():
	#print("PlanarReflectorCPP Plugin: Entering tree")

	# Create and add the editor camera helper as a singleton
	editor_camera_helper = load(planar_editor_helper_path).new()
	editor_camera_helper.name = EDITOR_HELPER_NAME

	# Add to editor's scene root so it persists
	var editor_viewport = EditorInterface.get_editor_main_screen()
	if editor_viewport:
		editor_viewport.add_child(editor_camera_helper)
		# Make it a singleton accessible from C++
		Engine.register_singleton(EDITOR_HELPER_NAME, editor_camera_helper)

	# Node icons are registered by the .gdextension [icons] section.
	#print("PlanarReflectorCPP class is available (registered via GDExtension)")

func _exit_tree():
	#print("PlanarReflectorCPP Plugin: Exiting tree")
	
	# Remove singleton
	if Engine.has_singleton(EDITOR_HELPER_NAME):
		Engine.unregister_singleton(EDITOR_HELPER_NAME)
	
	# Remove helper
	if editor_camera_helper and is_instance_valid(editor_camera_helper):
		#print("PlanarReflectorCPP Plugin: editor_camera_helper queue_free")
		editor_camera_helper.queue_free()

func _handles(object) -> bool:
	if object == null:
		return false
	return object.get_class() == "PlanarReflectorCPP"

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	# print("PlanarReflectorCPP Plugin: _forward_3d_gui_input detected")
	update_editor_camera_new(viewport_camera)
	# update_editor_camera(viewport_camera)
	return EditorPlugin.AFTER_GUI_INPUT_PASS

#Recent active version to call planar reflectors nodes and set the camera
func update_editor_camera_new(viewport_camera: Camera3D):
	if viewport_camera == null:
		return
	current_editor_camera = viewport_camera
	if editor_camera_helper:
		editor_camera_helper.set_helper_editor_camera(viewport_camera)
	for node in get_tree().get_nodes_in_group("planar_reflectors"):
		if node.get_class() != "PlanarReflectorCPP":
			continue
		if node.has_method("set_editor_camera") and node.get_active_camera() != viewport_camera:
			node.set_editor_camera(viewport_camera)

#BAKRUP VERSION NOT IN USE
func update_editor_camera(viewport_camera: Camera3D):
	if viewport_camera and viewport_camera != current_editor_camera:
		current_editor_camera = viewport_camera

		if editor_camera_helper:
			editor_camera_helper.set_helper_editor_camera(viewport_camera)

		# Update all PlanarReflectorCPP nodes in the scene
		var nodes = get_tree().get_nodes_in_group("planar_reflectors")
		#print("PlanarReflectorCPP Plugin: nodes found in planar_reflectors = " + str(nodes.size()))
		for node in nodes:
			if node.has_method("set_editor_camera"):
				node.set_editor_camera(viewport_camera)
				#print("PlanarReflectorCPP Plugin: set_editor_camera for: " + viewport_camera.name + " on: " + node.name)

func _make_visible(visible: bool):
	# Called when selecting/deselecting a PlanarReflectorCPP node
	pass

# Optional: Add configuration options in Project Settings
func _get_plugin_name():
	return PLUGIN_NAME
