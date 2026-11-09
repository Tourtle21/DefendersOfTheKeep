extends SceneTree
## Window screenshots of the split screen for 2, 3 and 4 players (pass n=2|3|4): the views, player 2's HUD, the keep screen in a tower
## and the Forge. Needs a real window. Writes PNGs to the directory given as out=<dir>.
var N := 2
var OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func shot(name: String) -> void:
	await wait(0.4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s_%dp.png" % [OUT, name, N])
	print("saved ", name, " ", img.get_size())
func scripted(world, f: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(f): return c
	return null
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="): N = int(a.substr(2))
		if a.begins_with("out="): OUT = a.substr(4)
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://shots_test_save.json"
	game._menu_done = true
	game.sectors_unlocked = ["s", "se", "ne"]
	game._local_devices = [-1, 1, 2, 3].slice(0, N)
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(2.0)
	world.get_node("SpawnTimer").start(9999.0)
	for t in game.all_towers():
		t.visible = true
	var lp = scripted(world, "local_players.gd")
	game.resources = {"stone": 30, "stick": 20, "gold": 25}
	for s in range(1, N):
		net.give_weapon(lp.avatars[s], "spear")
	await shot("1_start")
	# a few enemies close by so the fight HUD has something
	for i in 6:
		var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
		e.position = Vector2(60 + i * 25, 150)
		world.get_node("Enemies").add_child(e)
	await wait(1.0)
	await shot("2_enemies")
	# player 2 in a tower
	var towers: Array = game.all_towers()
	var p2 = lp.avatars[1]
	p2.global_position = towers[2].global_position + Vector2(0, 14)
	await wait(0.4)
	net._set_base(p2, true)
	await wait(0.8)
	await shot("3_p2_in_tower")
	net._set_base(p2, false)
	# the forge for player 2
	p2.global_position = net.FORGE_POS + Vector2(8, 0)
	await wait(0.4)
	lp.forge_uis[1].open()
	await wait(0.8)
	await shot("4_p2_forge")
	lp.forge_uis[1].close()
	# player 1's forge
	var forge = scripted(world, "forge_ui.gd")
	forge.open()
	await wait(0.8)
	await shot("5_p1_forge")
	quit()
