extends Node2D

@onready var player = get_parent()

func _input(event: InputEvent) -> void:
	if player.remote_controlled:
		return                                   # a co-op avatar aims with its own input (see _process), not with the host's mouse
	if event is InputEventMouseMotion or event is InputEventJoypadMotion:
		_aim_at(Pad.world_mouse(self))

## Co-op avatars (LAN clients and split-screen players 2 to 4) point their weapon at their own aim point.
func _process(_delta: float) -> void:
	if player.remote_controlled:
		_aim_at(player.aim_point())

func _aim_at(mouse: Vector2) -> void:
	var direction = (mouse - player.position).normalized()
	if (mouse < player.position):
		rotation = (PI - direction.angle())
	else:
		rotation = direction.angle()
