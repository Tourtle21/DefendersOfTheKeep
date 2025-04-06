extends Node2D

@export var item_info: Resource

var has_item = false
var is_active = false
var current_item = null

func equip(item) -> void:
	has_item = true
	current_item = item
	$LeftHand.texture = load(item.texture)
	$LeftHand.region_enabled = true
	$LeftHand.region_rect = Rect2(Vector2.ZERO, Vector2(32, 32))
	$LeftHand.scale = Vector2(3.5, 3.5)
	$LeftHand.visible = true
	if current_item.type == "item":
		toggle_active()

func toggle_active() -> void:
	if (is_active):
		is_active = false
		$Sprite2D.modulate = Color.WHITE
	else: 
		is_active = true
		$Sprite2D.modulate = Color.BLUE
