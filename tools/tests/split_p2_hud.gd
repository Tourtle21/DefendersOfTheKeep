extends SceneTree
## Player 2's view has its own ability panel and weapon-slot row (drawn in their view, answering from their weapon).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://hu_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var split = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd"))[0]
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p2 = lp.avatars[1]
	var huds: Array = split.get_children().filter(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("ability_hud.gd"))
	ok("one ability panel for player 2, drawn in player 2's view", huds.size() == 1 and huds[0].custom_viewport == split.viewports[1] and huds[0].target == p2)
	var w = huds[0]._weapon()
	ok("it answers from player 2's weapon", w != null and w.cd_info("attack")[2] != "")
	print("  attack name '%s', labels %s, canvas %s" % [w.cd_info("attack")[2], huds[0].key_labels, huds[0].canvas.size])
	ok("it fits player 2's view", huds[0].canvas.size == Vector2(split.viewports[1].size))
	net.give_weapon(p2, "spear")
	await wait(0.3)
	ok("two weapon slots, the new one active", p2.weapon_slots.size() == 2 and p2.active_slot == 1)
	p2.is_in_tower = true
	ok("the panel hides while player 2 is in a tower", huds[0]._weapon() == null)
	quit()
