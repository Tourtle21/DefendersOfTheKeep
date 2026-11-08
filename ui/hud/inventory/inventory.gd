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
	_set_badge(item)
	if current_item.type == "item":
		toggle_active()

func unequip() -> void:
	if is_active:
		toggle_active()
	has_item = false
	current_item = null
	$LeftHand.visible = false
	if has_node("TierBadge"):
		$TierBadge.visible = false

## A small "T2" in the corner of the slot so you can tell which tier of weapon you hold.
func _set_badge(item) -> void:
	var id: String = item.get("id", "") if item.has("id") else str(item_info.items.find_key(item))
	var entry: String = item.get("entry", id)
	var badge: Label
	if has_node("TierBadge"):
		badge = $TierBadge
	else:
		badge = Label.new()
		badge.name = "TierBadge"
		badge.position = Vector2(14, 16)
		badge.z_index = 5
		badge.add_theme_font_size_override("font_size", 20)
		badge.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 6)
		add_child(badge)
	var weapon := id != "" and Fusion.NAMES.has(id) and item.get("type", "") == "item"
	badge.visible = weapon
	if weapon:
		badge.text = "T%d" % Game.weapon_tier_of(entry)

func toggle_active() -> void:
	if (is_active):
		is_active = false
		$Sprite2D.modulate = Color.WHITE
	else: 
		is_active = true
		$Sprite2D.modulate = Color.BLUE
