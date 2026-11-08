extends Area2D
class_name Hitbox

var entered = false
var entered_body : Node2D

func _on_body_entered(body: Node2D) -> void:
	var owner_slow = get_parent().get("slow_mult")
	if owner_slow != null and owner_slow <= 0.0:
		return
	if !body.is_taking_damage:
		if (get_parent().get_parent().get_parent() == get_tree().root):
			get_parent().attack()
			body.take_damage(get_parent().position)
		else:
			body.take_damage(get_parent().get_parent().get_parent().position)
			
	entered = true
	entered_body = body
	


func _on_body_exited(body: Node2D) -> void:
	entered = false

func _process(delta: float) -> void:
	var owner_slow = get_parent().get("slow_mult")
	if owner_slow != null and owner_slow <= 0.0:
		return
	if entered and !entered_body.is_taking_damage:
		if (get_parent().get_parent().get_parent() == get_tree().root):
			get_parent().attack()
			entered_body.take_damage(get_parent().position)
		else:
			entered_body.take_damage(get_parent().get_parent().get_parent().position)
		
