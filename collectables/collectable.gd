extends Area2D

var player: Node2D
var hovering = false

@export var item_type: String
@export var item_info: Resource

func _ready() -> void:
	$Sprite2D.texture = load(item_info.items[item_type]["texture"])
	$Sprite2D.region_enabled = true
	$Sprite2D.region_rect = Rect2(Vector2.ZERO, Vector2(32, 32))
	$Sprite2D.visible = true

func _input(event: InputEvent) -> void:
	if hovering and event.is_action_pressed("interact"):
		if player.get_parent().get_node("Hud").equip_item(item_info.items[item_type]):
			if (item_info.items[item_type]["type"] == "item" and player.get_parent() != null):
				player.equip_item(item_info.items[item_type])
			queue_free()
		else:
			$AnimationPlayer.play("invalid")
			
func _on_body_entered(body: Node2D) -> void:
	hovering = true
	player = body
	modulate = Color(1.5, 1.5, 0.5)

func _on_body_exited(body: Node2D) -> void:
	hovering = false
	modulate = Color.WHITE
