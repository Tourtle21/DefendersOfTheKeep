extends SceneTree
## "Restart run" in a split-screen game: the new world gets its split screen, players and HUD again, with nothing left over.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func parts() -> Dictionary:
	var w = current_scene
	var out := {"split": 0, "local_players": 0, "huds": 0}
	for c in w.get_children():
		if c.get_script() == null: continue
		var f: String = str(c.get_script().resource_path)
		if f.ends_with("split_screen.gd"): out.split += 1
		if f.ends_with("local_players.gd"): out.local_players += 1
	var sp = w.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd"))
	if !sp.is_empty():
		out.huds = sp[0]._local_huds.size()
	return out
func _initialize() -> void:
	var game = root.get_node("Game")
	var pad = root.get_node("Pad")
	game.save_path = "user://sr_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1, 2]
	change_scene_to_file("res://world/world.tscn")
	await wait(1.5)
	var a := parts()
	ok("first game: one split screen, one set of local players, HUDs for players 2 and 3 %s" % str(a), a.split == 1 and a.local_players == 1 and a.huds == 2 and game.player_count() == 3)
	game.restart_run()
	await wait(2.0)
	var b := parts()
	ok("after Restart run: the same again %s" % str(b), b.split == 1 and b.local_players == 1 and b.huds == 2 and game.player_count() == 3)
	ok("the pad is still in split mode for player 1", pad._split_box != null and is_instance_valid(pad._split_box))
	ok("the wave banners are one per player (3)", get_nodes_in_group("wave_banner").size() == 3)
	quit()
