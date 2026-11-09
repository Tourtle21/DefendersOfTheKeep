extends Area2D
var open = false
var entered = false

func _input(event: InputEvent) -> void:
	if (open or entered) and event.is_action_pressed("interact"):
		if !entered and Game.tower_taken(get_parent(), get_parent().get_parent().get_node("Player")):
			Game.announce.emit("That tower is already in use.")          # one person per tower
			return
		entered = !entered
		if entered:
			get_parent().get_parent().get_node("Player").is_in_tower = true
			Game.enter_base(get_parent().get_parent().get_node("Player"))
			get_parent().get_parent().get_node("Player").z_index = 1
			get_parent().get_parent().get_node("Player").position = global_position - Vector2(0, 10)
			get_parent().get_parent().get_node("Player").base_zoom = 2.0
			get_parent().get_parent().get_node("Player").get_node("Camera2D").position += Vector2(0, 100)
		else:
			get_parent().get_parent().get_node("Player").is_in_tower = false
			Game.exit_base(get_parent().get_parent().get_node("Player"))
			var out: Vector2 = global_position + Vector2(0, 40)
			if out.length() > 110.0 and !Game.gate_open(out.angle()):
				out = out.normalized() * 110.0         # stepping out must not land beyond the keep's edge (it would snap you back)
			get_parent().get_parent().get_node("Player").position = out
			get_parent().get_parent().get_node("Player").z_index = 0
			get_parent().get_parent().get_node("Player").base_zoom = 5.0
			get_parent().get_parent().get_node("Player").get_node("Camera2D").position += Vector2(0, -100)
		get_parent().get_node("Sprite2D2").visible = entered
		get_parent().get_node("CollisionShape2D2").disabled = !entered
		get_parent().get_node("CollisionShape2D3").disabled = !entered
		get_parent().get_node("CollisionShape2D4").disabled = !entered
		get_parent().get_node("CollisionShape2D5").disabled = !entered

## Jump between towers while you stay inside the keep: the old tower closes, this one opens around you.
func teleport_leave() -> void:
	entered = false
	_show_interior(false)

func teleport_arrive(player: Node) -> void:
	entered = true
	player.global_position = global_position - Vector2(0, 10)
	_show_interior(true)

func _show_interior(on: bool) -> void:
	get_parent().get_node("Sprite2D2").visible = on
	for n in ["CollisionShape2D2", "CollisionShape2D3", "CollisionShape2D4", "CollisionShape2D5"]:
		get_parent().get_node(n).disabled = !on

func _on_body_entered(body):
	if body.is_in_group("player"):
		open = true
		get_parent().get_node("AnimationPlayer").play("open_door")

func _on_body_exited(body):
	if body.is_in_group("player"):
		open = false
		get_parent().get_node("AnimationPlayer").play_backwards("open_door")
