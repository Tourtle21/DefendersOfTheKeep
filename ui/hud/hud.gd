extends CanvasLayer

@export var item_slots: Control
@export var resource_slots: Control
@export var player: CharacterBody2D

var active_item_slot = -1
var equipped_items_count = 0

var equipped_resources_count = 0

func _input(event):
	if event.is_action_pressed("switch_items") and equipped_items_count > 1:
		var slots = item_slots.get_children()
		var n = slots.size()
		for step in range(1, n + 1):
			var cand = (active_item_slot + step) % n
			if slots[cand].has_item:
				if cand != active_item_slot:
					slots[active_item_slot].toggle_active()
					active_item_slot = cand
					slots[cand].toggle_active()
					player.equip_item(slots[cand].current_item)
				break

func remove_slot(i: int) -> void:
	var slot = item_slots.get_children()[i]
	if !slot.has_item:
		return
	slot.unequip()
	equipped_items_count -= 1
	if active_item_slot == i:
		active_item_slot = -1

## All three slots are full: replace the active weapon with `new_item`.
## Returns the weapon that was swapped out (or null if there was nothing to swap).
func swap_active(new_item):
	var idx: int = active_item_slot if active_item_slot != -1 else 0
	var slot = item_slots.get_children()[idx]
	var old = slot.current_item
	if old == null:
		return null
	remove_slot(idx)
	equip_item(new_item)
	return old

func equip_item(item) -> bool:
	var equippable = false
	if item.has("id"):
		Game.mark_seen(str(item.id), "weapon")            # a weapon you have held counts as met
		if item.has("entry"):
			Game.note_weapon_tier(str(item.id), Game.weapon_tier_of(str(item.entry)))     # so does the tier you found it at
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
