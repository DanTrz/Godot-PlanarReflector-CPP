extends Node3D

@export var move_speed: float = 4.0
@onready var cam: Camera3D = %MainCamera3D

func _process(delta: float) -> void:
	# movement
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	if input_vec.length() > 0.0:
		var move_vec := (transform.basis.x * input_vec.x) + (transform.basis.z * input_vec.y)
		move_vec.y = 0

		position += move_vec * move_speed * delta


	
