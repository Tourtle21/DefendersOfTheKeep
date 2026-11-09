extends SceneTree
## Window screenshots of the single-player screens: the keep (tower) screen with the controller highlight, the Card Fuser,
## the chest choice and the end-of-run screen.
var OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func shot(name: String) -> void:
	await wait(0.5)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [OUT, name])
	print("saved ", name)
func scripted(world, f: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(f): return c
	return null
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): OUT = a.substr(4)
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://audit_save.json"
	game.meta["unlocked"] = ["fireball", "frost_ring", "barricade", "spike_trap", "torch", "rejuvenation", "mender"]
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	scripted(world, "help_ui.gd").panel.visible = false
	var p = world.get_node("Player")
	game.resources = {"stone": 30, "stick": 20, "gold": 25}
	game.hand = ["torch", "sentry", "fireball", "frost_ring", "barricade"]
	# 1. the keep screen (in a tower), with the controller highlight on an upgrade
	var t = game.all_towers()[0]
	p.global_position = t.global_position + Vector2(0, 14)
	t.get_node("EnterArea").open = true
	await wait(0.4)
	net._set_base(p, true)
	root.get_node("Pad")._set_using(true)
	game._keep_sel = 2
	game.keep_sel_changed.emit()
	await wait(0.6)
	await shot("u1_keep_screen")
	net._set_base(p, false)
	await wait(0.3)
	# 2. the Card Fuser
	var fuse = scripted(world, "card_fuse_ui.gd")
	fuse.open()
	fuse._toggle(0)
	fuse._toggle(1)
	await shot("u2_card_fuser")
	fuse.close()
	# 3. the chest choice
	game.draft_owner_slot = 0
	game.start_draft()
	await shot("u3_chest_choice")
	game.take_draft_card(game.draft_options[0])
	# 4. the end-of-run screen
	game.run_stats = {"kills": 40, "gold": 60, "waves": 6, "bosses": 1}
	game.sectors_unlocked = ["s", "se", "ne"]
	game.end_run("The keep has fallen")
	await wait(1.2)
	await shot("u4_run_end")
	quit()
