extends Area2D

@export var dropped = true

func _on_body_entered(body):
	if body.is_in_group("player") and dropped:
		body.get_node("Pickaxe").visible = true
		get_parent().get_node("Hud").get_node("Control").get_node("LeftHand").visible = true
		queue_free()

func _on_body_exited(body):
	print("Exited")
