extends StaticBody2D

var is_taking_damage = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func take_damage(position) -> void:
	is_taking_damage = true
	$AnimationPlayer.play("shake")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	$AnimationPlayer.play("RESET")
	is_taking_damage = false
