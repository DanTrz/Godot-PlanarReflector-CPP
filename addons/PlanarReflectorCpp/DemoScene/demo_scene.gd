extends Node3D
@onready var label_fps: Label = %LabelFPS

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	label_fps.text = str(Engine.get_frames_per_second())
	pass
