extends Area2D
## The door of a tower for player 1. Entering and leaving is Net._set_base, the same rule every other player uses; this only
## adds what is player 1's own: the camera, the draw order and the interior picture.
var open = false
var entered = false

func _input(event: InputEvent) -> void:
	if (open or entered) and event.is_action_pressed("interact") and !Game.menu_open():
		var player = get_parent().get_parent().get_node("Player")
		if !Net._set_base(player, !entered):
			return
		entered = player.is_in_tower
		player.z_index = 1 if entered else 0
		player.base_zoom = 2.0 if entered else 5.0
		player.get_node("Camera2D").position += Vector2(0, 100 if entered else -100)
		_show_interior(entered)

## Jump between towers while you stay inside the keep: the old tower closes, this one opens around you.
func teleport_leave() -> void:
	entered = false
	_show_interior(false)

func teleport_arrive(player: Node) -> void:
	entered = true
	player.global_position = get_parent().global_position + Net.TOWER_SEAT
	_show_interior(true)

func _show_interior(on: bool) -> void:
	get_parent().get_node("Sprite2D2").visible = on
	for n in ["CollisionShape2D2", "CollisionShape2D3", "CollisionShape2D4", "CollisionShape2D5"]:
		get_parent().get_node(n).disabled = !on

func _on_body_entered(body):
	if body.is_in_group("player"):
		if !body.get("remote_controlled"):
			open = true                           # only player 1's interact button works the door (see Game.has_local_player)
		get_parent().get_node("AnimationPlayer").play("open_door")

func _on_body_exited(body):
	if body.is_in_group("player"):
		open = Game.has_local_player(self)
		var anyone := false
		for b in get_overlapping_bodies():
			if b.is_in_group("player"):
				anyone = true
		if !anyone:
			get_parent().get_node("AnimationPlayer").play_backwards("open_door")
