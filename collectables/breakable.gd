extends StaticBody2D

@export var health = 1
@export var min_drops = 2
@export var max_drops = 2
@export var drop_type: String
var is_taking_damage = false

var collectable_path = "res://collectables/collectable.tscn"

func take_damage(position) -> void:
	is_taking_damage = true
	health -= 1
	$AudioStreamPlayer2D.play()
	if (health <= 0):
		drop_items()
		queue_free()
	$AnimationPlayer.play("shake")

func drop_items() -> void:
	var random_amount = randi_range(min_drops, max_drops)
	for i in range(random_amount):
		var collectable_scene = load(collectable_path)
		if collectable_scene:
			var collectable = collectable_scene.instantiate()
			collectable.position = position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
			collectable.item_type = drop_type
			get_parent().get_parent().add_child(collectable)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	$AnimationPlayer.play("RESET")
	is_taking_damage = false
