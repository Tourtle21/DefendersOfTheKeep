extends Area2D
var open = false
var entered = false

func _input(event: InputEvent) -> void:
	if (open or entered) and event.is_action_pressed("interact"):
		entered = !entered
		if entered:
			get_parent().get_parent().get_node("Player").is_in_tower = true
			get_parent().get_parent().get_node("Player").z_index = 1
			get_parent().get_parent().get_node("Player").position = global_position - Vector2(0, 10)
			get_parent().get_parent().get_node("Player").get_node("Camera2D").zoom = Vector2(3, 3)
			get_parent().get_parent().get_node("Player").get_node("Camera2D").position += Vector2(0, 100)
		else:
			get_parent().get_parent().get_node("Player").is_in_tower = false
			get_parent().get_parent().get_node("Player").position = global_position + Vector2(0, 40)
			get_parent().get_parent().get_node("Player").z_index = 0
			get_parent().get_parent().get_node("Player").get_node("Camera2D").zoom = Vector2(5, 5)
			get_parent().get_parent().get_node("Player").get_node("Camera2D").position += Vector2(0, -100)
		get_parent().get_node("Sprite2D2").visible = entered
		get_parent().get_node("CollisionShape2D2").disabled = !entered
		get_parent().get_node("CollisionShape2D3").disabled = !entered
		get_parent().get_node("CollisionShape2D4").disabled = !entered
		get_parent().get_node("CollisionShape2D5").disabled = !entered

func _on_body_entered(body):
	if body.is_in_group("player"):
		open = true
		get_parent().get_node("AnimationPlayer").play("open_door")

func _on_body_exited(body):
	if body.is_in_group("player"):
		open = false
		get_parent().get_node("AnimationPlayer").play_backwards("open_door")
