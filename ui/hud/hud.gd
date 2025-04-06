extends CanvasLayer

@export var item_slots: Control
@export var resource_slots: Control
@export var player: CharacterBody2D

var active_item_slot = -1
var equipped_items_count = 0

var equipped_resources_count = 0

func _input(event):
	if event.is_action_pressed("switch_items"):
		if equipped_items_count > 1:
			item_slots.get_children()[active_item_slot].toggle_active()
			active_item_slot += 1
			if active_item_slot == 2:
				active_item_slot = 0
			while !item_slots.get_children()[active_item_slot].has_item:
				active_item_slot += 1
			item_slots.get_children()[active_item_slot].toggle_active()
			player.equip_item(item_slots.get_children()[active_item_slot].current_item)
			

func equip_item(item) -> bool:
	var equippable = false
	if item.type == "item":
		var i = 0
		for item_slot in item_slots.get_children():
			if !item_slot.has_item:
				equippable = true
				item_slot.equip(item)
				equipped_items_count += 1
				if (active_item_slot != -1):
					item_slots.get_children()[active_item_slot].toggle_active()
				active_item_slot = i
				break
			i += 1
	elif item.type == "resource":
		for resource_slot in resource_slots.get_children():
			if !resource_slot.has_item:
				equippable = true
				resource_slot.equip(item)
				equipped_resources_count += 1
				break
	return equippable
