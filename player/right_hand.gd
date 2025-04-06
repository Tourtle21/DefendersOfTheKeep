extends Node2D

@onready var player = get_parent()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var direction = (get_global_mouse_position() - player.position).normalized()
		if (get_global_mouse_position() < player.position):
			rotation = (PI - direction.angle())
		else:
			rotation = direction.angle()
