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
			_tool_hit(body)
			
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
			_tool_hit(entered_body)
		

## The sword and pickaxe swing hits through this hitbox. A normal hit takes 1; the Damage skill and the tool's tier bonus
## (+20% per awakening, like every other weapon) add that share of the damage that hit did, so they count here too.
func _tool_hit(body: Node) -> void:
	var tool = get_parent()
	var before = body.get("health")
	body.take_damage(tool.get_parent().get_parent().position)
	if before == null or !("bonus_tier" in tool) or !is_instance_valid(body) or !body.has_method("spell_damage"):
		return
	var mult: float = (1.0 + 0.2 * tool.bonus_tier) * (1.0 + Game.bonus("weapon_dmg"))
	var lost: float = float(before) - float(body.get("health"))
	if mult > 1.001 and lost > 0.0 and !body.get("dead"):
		body.spell_damage(lost * (mult - 1.0))
