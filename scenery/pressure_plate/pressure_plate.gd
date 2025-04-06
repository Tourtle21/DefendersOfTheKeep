extends Area2D

@export var target_object: Node2D
var pressed = false;
var player_count_on_plate = 0

func _on_body_entered(body):
	player_count_on_plate += 1
	if (!pressed):
		$AnimationPlayer.play("press")
		target_object.activate()
		pressed = true
	

func _on_body_exited(body):
	#if body.is_in_group("player"):
	player_count_on_plate -= 1
	if (player_count_on_plate == 0):
		$AnimationPlayer.play_backwards("press")
		target_object.deactive()
		pressed = false
