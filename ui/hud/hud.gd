extends CanvasLayer

@export var item_slots: Control
@export var resource_slots: Control
@export var player: CharacterBody2D

var active_item_slot = -1
var equipped_items_count = 0

var equipped_resources_count = 0

var slots_widget: Control          # the compact weapon frames bottom-left, the same widget players 2 to 4 have (ui/hud/weapon_slots.gd)

func _ready() -> void:
	item_slots.visible = false         # the big frames still do the bookkeeping, but the compact widget is what is shown
	slots_widget = Control.new()
	slots_widget.set_script(preload("res://ui/hud/weapon_slots.gd"))
	add_child(slots_widget)

## The weapons in your hands as entries, in slot order: [{slot, entry}]
func held_entries() -> Array:
	var out := []
	var frames = item_slots.get_children()
	for i in frames.size():
		if frames[i].has_item:
			var item: Dictionary = frames[i].current_item
			var id = item.get("id", "")
			if id == "":
				id = frames[i].item_info.items.find_key(item)         # the starting tools carry no id of their own
			out.append({"slot": i, "entry": item.get("entry", id)})
	return out

func _process(_delta: float) -> void:
	if slots_widget == null:
		return
	var held := held_entries()
	var active := 0
	for n in held.size():
		if held[n].slot == active_item_slot:
			active = n
	slots_widget.slots = held.map(func(h): return h.entry)
	slots_widget.active = active

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

## After the weapon in your hand left, pick up another one you still hold (or none).
func equip_any() -> void:
	var slots = item_slots.get_children()
	for i in slots.size():
		if slots[i].has_item:
			if active_item_slot != -1 and active_item_slot != i:
				slots[active_item_slot].toggle_active()
			if !slots[i].is_active:
				slots[i].toggle_active()
			active_item_slot = i
			player.equip_item(slots[i].current_item)
			return
	player.clear_item()

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
