extends Area2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		get_parent().get_node("AnimationPlayer").play("open_door")

func _on_body_exited(body):
	if body.is_in_group("player"):
		get_parent().get_node("AnimationPlayer").play_backwards("open_door")
