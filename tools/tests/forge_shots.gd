extends SceneTree
## Needs a window. Screenshots of the forge (hands and storage in separate areas) and the on-the-spot merge hint.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func scripted(world, name: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(name): return c
	return null
func shot(name: String) -> void:
	get_root().get_viewport().get_texture().get_image().save_png("user://" + name + ".png")
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://fs_test_save.json"
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	var hud = world.get_node("Hud")
	var forge = scripted(world, "forge_ui.gd")
	game.resources = {"stone": 30, "stick": 20, "gold": 50}
	game.note_weapon_tier("hammer", 1)
	game.note_weapon_tier("spear", 1)
	game.note_weapon_tier("sword", 1)
	for id in ["hammer", "spear"]:
		var info = game.weapon_info(id)
		if hud.equip_item(info):
			p.equip_item(info)
	game._forge_store = ["spear", "hammer", "bow"]
	p.global_position = Vector2(300, 300)
	await wait(0.8)
	shot("merge_hint")
	forge.open()
	await wait(0.6)
	shot("forge_areas")
	print("saved to ", ProjectSettings.globalize_path("user://"))
	quit()
