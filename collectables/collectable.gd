extends Area2D

var item: Node2D
var dropped = true

@export var texture: Texture

func _ready() -> void:
	item = get_parent()

func _on_body_entered(body: Node2D) -> void:
	if (dropped):
		dropped = false
		item.get_parent().remove_child(item)
		if (body.get_parent() != null):
			body.get_parent().get_node("Hud").get_node("Control").get_node("LeftHand").texture = texture
			body.get_parent().get_node("Hud").get_node("Control").get_node("LeftHand").region_enabled = true
			body.get_parent().get_node("Hud").get_node("Control").get_node("LeftHand").region_rect = Rect2(Vector2.ZERO, Vector2(32, 32))
			body.get_parent().get_node("Hud").get_node("Control").get_node("LeftHand").visible = true
			body.equip_item(item)
