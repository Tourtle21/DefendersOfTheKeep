extends SceneTree
## Player 2's screens carry the same pieces as player 1's: HUD (resources, keep bar, health bar), the keep screen
## (upgrade cards, radar, mana bar with label, draw bar, hand), wave banner and crystal alert, all inside their own view.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func scripted(world, name: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(name): return c
	return null
func extent(node: Node) -> Rect2:
	var box := Rect2()
	var first := true
	var stack := [node]
	while !stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Control and n != node and n.is_visible_in_tree() and n.size.x > 1.0 and n.size.y > 1.0 and !(n is ColorRect and n.color.a < 0.5):
			var r: Rect2 = n.get_global_rect()
			box = r if first else box.merge(r)
			first = false
	return box
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://pa_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var split = scripted(world, "split_screen.gd")
	var lp = scripted(world, "local_players.gd")
	var rects: Array = split.layout(2, Vector2(1280, 720))
	for i in 2:
		split.containers[i].position = rects[i].position + Vector2(1, 1)
		split.containers[i].size = rects[i].size - Vector2(2, 2)
	await wait(0.3)
	split._pin_all()
	await wait(0.3)
	var view := Vector2(split.viewports[1].size)
	var p2 = lp.avatars[1]
	game.resources = {"stone": 12, "stick": 5, "gold": 9}
	# always-on HUD
	var hud = split._local_huds[0]
	await wait(0.3)
	print("  HUD text: ", hud.info.text, " | ", hud.keep_lbl.text, " | hp fill ", hud.hp_fill.size.x)
	ok("player 2's HUD shows what they carry and the keep's pool", hud.info.text.contains("Carrying:") and hud.info.text.contains("Keep:") and hud.info.text.contains("12 stone"))
	ok("it has the keep bar and a full health bar", hud.keep_lbl.text.begins_with("Keep ") and is_equal_approx(hud.hp_fill.size.x, 228.0))
	var r := extent(hud.root)
	ok("the HUD sits inside player 2's view %s" % str(r), r.position.x >= -2.0 and r.end.x <= view.x + 2.0 and r.position.y >= -2.0 and r.end.y <= view.y + 2.0)
	p2.take_damage(Vector2(900, 900), 30.0)
	await wait(0.15)
	ok("a hit flashes player 2's view red and lowers their bar", hud.flash.color.a > 0.0 and hud.hp_fill.size.x < 228.0)
	var banners: Array = get_nodes_in_group("wave_banner")
	ok("each player has a wave banner (2)", banners.size() == 2)
	var alerts: Array = split.get_children().filter(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("crystal_alert.gd"))
	ok("player 2 has a crystal alert for their own view", alerts.size() == 1 and alerts[0].view == split.viewports[1])
	# the keep screen
	var tower = game.all_towers()[2]
	p2.global_position = tower.global_position + Vector2(0, 14)
	await wait(0.4)
	net._set_base(p2, true)
	await wait(0.4)
	lp.keep_uis[1].poll(1, 0.016)
	await wait(0.4)
	var kui = lp.keep_uis[1]
	var up_n: int = kui._upgrade_box.get_child_count()
	r = extent(kui._root)
	print("  keep screen extent %s of view %s; upgrade cards %d; hand %d; radar %s" % [r, view, up_n, kui._hand_row.get_child_count(), kui._radar.size])
	ok("the keep screen is showing with Repair + 3 upgrade cards, a radar and the hand", kui._root.visible and up_n == 4 and kui._radar.is_visible_in_tree() and kui._hand_row.get_child_count() == game.hand.size())
	ok("its mana bar says 'Mana x / y' and the draw bar is there", kui._mana_label.text.begins_with("Mana ") and kui._draw_bar.is_visible_in_tree())
	ok("everything on the keep screen fits inside player 2's view", r.position.x >= -2.0 and r.end.x <= view.x + 2.0 and r.position.y >= -2.0 and r.end.y <= view.y + 2.0)
	quit()
