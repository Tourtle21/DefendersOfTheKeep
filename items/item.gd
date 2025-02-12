extends Node2D
class_name Tool

@export var starting_position: Vector2 = Vector2(3, 5)

func _ready() -> void:
	var animation_player = $AnimationPlayer
	if animation_player:
		animation_player.connect("animation_finished", _on_animation_player_animation_finished)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "use_item":
		$AnimationPlayer.play("RESET")
		get_parent().get_parent().is_using_item = false

func equip() -> void:
	position = starting_position
	
func use_item() -> void:
	pass
