extends Node2D

@onready var player = get_parent()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventJoypadMotion:
		var mouse: Vector2 = Pad.world_mouse(self)
		var direction = (mouse - player.position).normalized()
		if (mouse < player.position):
			rotation = (PI - direction.angle())
		else:
			rotation = direction.angle()
