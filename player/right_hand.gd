extends Node2D

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var center = Vector2(get_viewport().size / 2)
		center.y += 6
		var mouse_position = center - event.position
		var direction = (mouse_position - position).normalized()
		if (mouse_position.x < 0):
			rotation = -(PI - direction.angle())
		else:
			rotation = -direction.angle()
