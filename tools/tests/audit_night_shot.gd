extends SceneTree
var OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("needs a window (screenshots); skipping")
		quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): OUT = a.substr(4)
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://audit_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = false
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	world.clock = 160.0                       # full night
	for i in 5:
		var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
		e.position = Vector2(-60 + i * 30, 160)
		world.get_node("Enemies").add_child(e)
		e.set_physics_process(false)
	lp.avatars[1].global_position = Vector2(0, 150)
	await wait(1.5)
	print("night level ", game.night_level)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/n1_night_2p.png" % OUT)
	print("saved")
	quit()
