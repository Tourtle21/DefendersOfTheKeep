extends SceneTree
var OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): OUT = a.substr(4)
	var game = root.get_node("Game")
	game.save_path = "user://audit_save.json"
	game.meta["shards"] = 900
	game.meta["skills"] = {"weapon_dmg": 3, "move_speed": 2, "weapon_cd": 1}
	game._menu_done = false
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	var mm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("main_menu.gd"): mm = c
	mm.skills.open()
	await wait(0.8)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/s1_skills.png" % OUT)
	print("saved")
	quit()
