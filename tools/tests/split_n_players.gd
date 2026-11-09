extends SceneTree
## 3 or 4 local players (pass n=3 or n=4): every player's HUD and screens sit inside their own view, and the basics work.
var N := 3
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func scripted(world, name: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(name): return c
	return null
func axis(dev: int, a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = dev; e.axis = a; e.axis_value = v
	Input.parse_input_event(e)
func tap(dev: int, b: int) -> void:
	var e := InputEventJoypadButton.new()
	e.device = dev; e.button_index = b; e.pressed = true
	Input.parse_input_event(e)
	await wait(0.13)
	e = InputEventJoypadButton.new()
	e.device = dev; e.button_index = b; e.pressed = false
	Input.parse_input_event(e)
	await wait(0.15)
func extent(node: Node) -> Rect2:
	var box := Rect2()
	var first := true
	var stack := [node]
	while !stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Control and n != node and n.is_visible_in_tree() and n.size.x > 1.0 and n.size.y > 1.0 and !(n is ColorRect and n.color.a < 0.5) and !(n is ReferenceRect):
			var r: Rect2 = n.get_global_rect()
			box = r if first else box.merge(r)
			first = false
	return box
func inside(r: Rect2, v: Vector2) -> bool:
	return r.size.x > 0.0 and r.position.x >= -2.0 and r.position.y >= -2.0 and r.end.x <= v.x + 2.0 and r.end.y <= v.y + 2.0
func dummy(world, pos: Vector2):
	var d = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	d.position = pos
	world.get_node("Enemies").add_child(d)
	d.set_physics_process(false)
	d.get_node("NavigationTimer").stop()
	d.max_health = 400.0; d.health = 400.0
	return d
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="): N = int(a.substr(2))
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://np_test_save.json"
	game._menu_done = true
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	game._local_devices = [-1, 1, 2, 3].slice(0, N)
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	for t in game.all_towers():
		t.visible = true
	var split = scripted(world, "split_screen.gd")
	var lp = scripted(world, "local_players.gd")
	var rects: Array = split.layout(N, Vector2(1280, 720))
	for i in N:
		split.containers[i].position = rects[i].position + Vector2(1, 1)
		split.containers[i].size = rects[i].size - Vector2(2, 2)
	await wait(0.3)
	split._pin_all()
	await wait(0.4)
	print("--- %d players: views %s" % [N, split.viewports.map(func(v): return Vector2(v.size))])
	ok("%d views, %d players, team scale %.2f" % [split.viewports.size(), game.player_count(), game.team_scale(game.WAVE_TEAM_SCALE)], split.viewports.size() == N and game.player_count() == N)
	game.resources = {"stone": 40, "stick": 40, "gold": 99}
	var players := [world.get_node("Player")]
	for s in range(1, N):
		players.append(lp.avatars[s])
	for s in N:
		net.give_weapon(players[s], "spear")
	# ---- HUD pieces of players 2..N
	for s in range(1, N):
		var view := Vector2(split.viewports[s].size)
		var hud = split._local_huds[s - 1]
		await wait(0.2)
		ok("player %d: HUD inside their %s view" % [s + 1, view], inside(extent(hud.root), view))
		var ab: Array = split.get_children().filter(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("ability_hud.gd") and c.target == players[s])
		var rect_of := func(c: Control) -> Rect2: return c.get_global_rect()
		var frame: Control = hud.hp_fill.get_parent()
		var apart := func(a: Rect2, b: Rect2) -> bool: return !a.grow(-1.0).intersects(b.grow(-1.0))
		var info_r: Rect2 = hud.info.get_global_rect()
		print("  player %d HUD: resource line %s, keep bar %s, health bar %s" % [s + 1, info_r, rect_of.call(hud.keep_bar), rect_of.call(frame)])
		ok("player %d: resource line, keep bar and health bar do not overlap" % [s + 1], apart.call(info_r, rect_of.call(frame)) and apart.call(info_r, rect_of.call(hud.keep_bar)) and apart.call(rect_of.call(hud.keep_bar), rect_of.call(frame)))
		ok("player %d: ability panel in their own view" % [s + 1], ab.size() == 1 and ab[0].custom_viewport == split.viewports[s] and ab[0].canvas.size == view)
		ok("player %d: weapon slots drawn" % [s + 1], split._corner[s].slots.is_visible_in_tree() and split._corner[s].slots.size.x > 50.0)
	# ---- player 1's big screens in the (smaller) view
	var v1 := Vector2(split.viewports[0].size)
	var forge = scripted(world, "forge_ui.gd")
	forge.open(); await wait(0.5)
	ok("player 1's forge fits their %s view" % v1, inside(extent(forge.root_ctl), v1))
	forge.root_ctl.visible = false
	var fuse = scripted(world, "card_fuse_ui.gd")
	game.hand = ["torch", "sentry", "fireball", "frost_ring", "barricade"]
	fuse.open(); await wait(0.5)
	print("  P1 fuser extent ", extent(fuse.root_ctl), " scale ", fuse.root_ctl.scale)
	ok("player 1's Card Fuser fits", inside(extent(fuse.root_ctl), v1))
	fuse.close()
	# ---- each player's own screens
	for s in range(1, N):
		var view := Vector2(split.viewports[s].size)
		var p = players[s]
		var fui = lp.forge_uis[s]
		p.global_position = net.FORGE_POS + Vector2(8, 0)
		await wait(0.3)
		fui.open(); await wait(0.5)
		ok("player %d: forge fits (%s)" % [s + 1, extent(fui._root).size], inside(extent(fui._root), view) and fui._root.visible)
		fui.close()
		var zui = lp.fuser_uis[s]
		p.global_position = net.CARD_FUSER_POS + Vector2(8, 0)
		await wait(0.3)
		zui.open(); await wait(0.5)
		ok("player %d: Card Fuser fits" % [s + 1], inside(extent(zui._root), view) and zui._root.visible)
		zui.close()
		game.draft_owner_slot = s
		game.start_draft()
		await wait(0.2)
		lp.draft_uis[s].poll(game._local_devices[s])
		await wait(0.5)
		var d = lp.draft_uis[s]
		ok("player %d: chest choice shows in their view only" % [s + 1], d._root.visible and inside(extent(d._root), view) and !scripted(world, "draft_ui.gd").root_ctl.visible)
		game.take_draft_card(game.draft_options[0])
		game.draft_owner_slot = 0
		await wait(0.2)
	# ---- keep screens: each player in their own tower
	var towers: Array = game.all_towers()
	for s in range(1, N):
		var view := Vector2(split.viewports[s].size)
		var p = players[s]
		p.global_position = towers[s].global_position + Vector2(0, 14)
		await wait(0.3)
		await tap(game._local_devices[s], JOY_BUTTON_A)
		await wait(0.4)
		var kui = lp.keep_uis[s]
		var r := extent(kui._root)
		print("  player %d keep screen %s of %s" % [s + 1, r, view])
		ok("player %d: in a tower, keep screen visible and inside their view" % [s + 1], p.is_in_tower and kui._root.visible and inside(r, view))
		var hud2 = split._local_huds[s - 1]
		var cards_r: Rect2 = Rect2(kui._upgrade_box.get_global_rect())
		ok("player %d: upgrade cards sit below the keep bar and clear of the radar" % [s + 1], cards_r.position.y >= hud2.keep_bar.get_global_rect().end.y - 1.0 and !cards_r.intersects(kui._radar.get_global_rect()))
		ok("player %d: upgrade cards (4), radar and hand present" % [s + 1], kui._upgrade_box.get_child_count() == 4 and kui._radar.is_visible_in_tree() and kui._hand_row.get_child_count() == game.hand.size())
		await tap(game._local_devices[s], JOY_BUTTON_DPAD_DOWN)
		var lvl_before: int = game.upgrade_levels.get("max_mana", 0)
		await tap(game._local_devices[s], JOY_BUTTON_Y)
		ok("player %d: D-pad down + Y buys an upgrade" % [s + 1], game.upgrade_levels.get("max_mana", 0) == lvl_before + 1)
		await tap(game._local_devices[s], JOY_BUTTON_A)
		await wait(0.3)
		ok("player %d: A leaves the tower" % [s + 1], !p.is_in_tower)
	# ---- fighting: each player hits an enemy on their aim side with their own controller
	for s in range(1, N):
		var p = players[s]
		p.global_position = Vector2(150 + 90 * s, 400)
		await wait(0.2)
		var d = dummy(world, p.global_position + Vector2(25, 0))
		var dev: int = game._local_devices[s]
		for k in 3:
			axis(dev, JOY_AXIS_TRIGGER_RIGHT, 1.0)
			await wait(0.2)
			axis(dev, JOY_AXIS_TRIGGER_RIGHT, -1.0)
			await wait(0.5)
		ok("player %d (controller %d) hits an enemy in front of them (%.1f of 400)" % [s + 1, dev, d.health], d.health < 400.0)
		d.queue_free()
	quit()
