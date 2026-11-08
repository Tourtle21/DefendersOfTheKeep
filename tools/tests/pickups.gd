extends SceneTree
# Weapon pickups: tooltip text while hovering, and swapping with the active weapon when all slots are full.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func slot_names(hud) -> Array:
	var out := []
	var info = load("res://world/item_info.tres")
	for s in hud.item_slots.get_children():
		out.append(info.items.find_key(s.current_item) if s.has_item else "-")
	return out
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var hud = world.get_node("Hud")
	var info = load("res://world/item_info.tres")
	for slot in hud.item_slots.get_children():
		slot.unequip()
	hud.equipped_items_count = 0
	hud.active_item_slot = -1
	for id in ["sword", "pickaxe", "spear"]:
		hud.equip_item(info.items[id])
	player.equip_item(info.items["spear"])
	print("slots full: ", slot_names(hud), " active slot ", hud.active_item_slot)
	var P := Vector2(-40, 260)
	player.position = P
	# a bow on the ground, stand on it
	var c = load("res://collectables/collectable.tscn").instantiate()
	c.item_type = "bow"
	c.position = P
	world.add_child(c)
	await wait(0.6)
	print("hovering: ", c.hovering)
	print("tooltip: ", c.kit_text().replace("\n", " | "))
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("user://pickup_tooltip.png")
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	c._input(ev)
	await wait(0.4)
	print("after pressing interact: ", slot_names(hud), " | holding: ", player.item.weapon_name if player.item.get("weapon_name") != null else player.item.name)
	var dropped := []
	for n in world.get_children():
		if n is Area2D and n.get("item_type") == "spear":
			dropped.append(n.item_type)
	print("old weapon dropped on the ground: ", dropped)
	var sword_c = load("res://collectables/collectable.tscn").instantiate()
	sword_c.item_type = "daggers"
	print("tooltip of an unplaced pickup (daggers): ", sword_c.kit_text().replace("\n", " | "))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
