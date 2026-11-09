extends SceneTree
## Window screenshots of the start menu, the local co-op lobby (keyboard + controller joined) and the collection tabs.
var OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func shot(name: String) -> void:
	await wait(0.5)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("needs a window (screenshots); skipping")
		quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): OUT = a.substr(4)
	var game = root.get_node("Game")
	game.save_path = "user://audit_save.json"
	game.meta["unlocked"] = ["fireball", "frost_ring", "barricade", "spike_trap", "torch", "rejuvenation", "mender", "aegis"]
	game.meta["weapons"] = ["spear"]
	game.meta["weapon_tiers"] = {"pickaxe": 2}
	game.meta["shards"] = 120
	game._menu_done = false
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	var mm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("main_menu.gd"): mm = c
	await shot("m1_main_menu")
	mm.lobby.open()
	mm.lobby._members = [-1, 1]
	mm.lobby.fake_connected = [1]
	mm.lobby._refresh()
	await shot("m2_lobby")
	mm.lobby.close()
	mm.collection.open()
	await shot("m3_collection_cards")
	UiKit_switch(mm.collection.root_ctl, "weapons")
	await shot("m4_collection_weapons")
	UiKit_switch(mm.collection.root_ctl if false else mm.codex.root_ctl if mm.codex != null and mm.codex.root_ctl.visible else mm.collection.root_ctl, "draws")
	await shot("m5_drawn")
	quit()
func UiKit_switch(from: Control, id: String) -> void:
	load("res://ui/cards/ui_kit.gd").switch_tab(from, id)
