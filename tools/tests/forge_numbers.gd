extends SceneTree
# Forge shows weapon numbers (screenshot needs a window).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var info = world.get_node("Collectable").item_info
	var hud = world.get_node("Hud")
	hud.equip_item(game.weapon_info("spear"))
	hud.equip_item(game.weapon_info("spear"))
	game.resources = {"stone": 9, "stick": 9, "gold": 99}
	var fui = null
	for c in world.get_children():
		if c.is_in_group("forge_ui"): fui = c
	fui.open()
	fui._toggle(0)
	fui._toggle(1)
	await wait(0.4)
	print("numbers text: ", fui.numbers.text)
	print("info: ", fui.info_label.text)
	fui.awaken()
	print("after combining: slots ", hud.item_slots.get_children().filter(func(sl): return sl.has_item).map(func(sl): return sl.current_item.entry), " gold ", game.resources.gold)
	if DisplayServer.get_name() != "headless":
		root.get_viewport().get_texture().get_image().save_png("user://forge_numbers.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
