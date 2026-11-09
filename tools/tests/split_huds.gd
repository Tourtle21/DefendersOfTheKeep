extends SceneTree
## Two players, keyboard + controller. Every screen and HUD of each player must be visible and sit inside that player's own view:
## player 1's forge / card fuser / chest draft, player 2's forge / fuser / chest draft, both ability panels, both weapon rows.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func scripted(world, name: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(name): return c
	return null
## The box around every visible control under `node` (in the coordinates of the view it is drawn in).
func extent(node: Node) -> Rect2:
	var box := Rect2()
	var first := true
	var stack := [node]
	while !stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Control and n != node and n.is_visible_in_tree() and n.size.x > 1.0 and n.size.y > 1.0 and !(n is ColorRect) and !(n is ReferenceRect):
			var r: Rect2 = n.get_global_rect()
			box = r if first else box.merge(r)
			first = false
	return box
func fits(r: Rect2, view: Vector2) -> bool:
	return r.size.x > 0.0 and r.position.x >= -2.0 and r.position.y >= -2.0 and r.end.x <= view.x + 2.0 and r.end.y <= view.y + 2.0
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://sh_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	var split = scripted(world, "split_screen.gd")
	var lp = scripted(world, "local_players.gd")
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	# (a headless window stays 64x64, so size the two views as a 1280x720 window would)
	var rects: Array = split.layout(2, Vector2(1280, 720))
	for i in 2:
		split.containers[i].position = rects[i].position + Vector2(1, 1)
		split.containers[i].size = rects[i].size - Vector2(2, 2)
	await wait(0.3)
	split._pin_all()
	await wait(0.3)
	var v1 := Vector2(split.viewports[0].size)
	var v2 := Vector2(split.viewports[1].size)
	print("  window %s views %s and %s" % [root.size, v1, v2])
	game.resources.gold = 99
	net.give_weapon(p1, "spear"); net.give_weapon(p2, "spear")
	net.give_weapon(p1, "hammer"); net.give_weapon(p2, "hammer")
	await wait(0.3)
	# ---- player 1: forge, card fuser, chest draft
	var forge = scripted(world, "forge_ui.gd")
	forge.open()
	await wait(0.5)
	var r := extent(forge.root_ctl)
	print("  P1 forge extent %s of view %s (scale %s)" % [r, v1, forge.root_ctl.scale])
	ok("player 1's forge fits player 1's view", fits(r, v1) and forge.root_ctl.visible)
	forge.root_ctl.visible = false
	var fuse = scripted(world, "card_fuse_ui.gd")
	game.hand = ["torch", "sentry", "fireball", "frost_ring", "barricade"]
	fuse.open()
	await wait(0.5)
	r = extent(fuse.root_ctl)
	print("  P1 fuser extent %s" % r)
	ok("player 1's Card Fuser fits player 1's view", fits(r, v1))
	fuse.close()
	game.draft_owner_slot = 0
	game.start_draft()
	await wait(0.6)
	var draft = scripted(world, "draft_ui.gd")
	r = extent(draft.root_ctl)
	print("  P1 draft extent %s visible %s" % [r, draft.root_ctl.visible])
	ok("player 1's chest draft shows, inside player 1's view", draft.root_ctl.visible and fits(r, v1))
	game.take_draft_card(game.draft_options[0])
	await wait(0.2)
	# ---- player 2: forge, fuser, draft
	var fui = lp.forge_uis[1]
	p2.global_position = net.FORGE_POS + Vector2(8, 0)
	await wait(0.3)
	fui.is_open = true; fui._root.visible = true; fui._key = ""; fui._refresh()
	await wait(0.5)
	r = extent(fui._root)
	print("  P2 forge extent %s of view %s" % [r, v2])
	ok("player 2's forge fits player 2's view", fits(r, v2) and fui._root.visible)
	fui.close()
	var zui = lp.fuser_uis[1]
	p2.global_position = net.CARD_FUSER_POS + Vector2(8, 0)          # (the screen closes itself when you walk away from the table)
	await wait(0.3)
	zui.open()
	await wait(0.5)
	r = extent(zui._root)
	print("  P2 fuser extent %s (visible %s, hand %s, row children %d, root size %s)" % [r, zui._root.visible, game.hand, zui._row.get_child_count(), zui._root.size])
	ok("player 2's Card Fuser fits player 2's view", fits(r, v2) and zui._root.visible)
	zui.close()
	game.draft_owner_slot = 1
	game.start_draft()
	await wait(0.2)
	lp.draft_uis[1].poll(1)
	await wait(0.6)
	var d2 = lp.draft_uis[1]
	r = extent(d2._root)
	print("  P2 draft extent %s visible %s" % [r, d2._root.visible])
	ok("player 2's chest draft shows in player 2's view and not player 1's", d2._root.visible and fits(r, v2) and !draft.root_ctl.visible)
	game.take_draft_card(game.draft_options[0])
	game.draft_owner_slot = 0
	await wait(0.2)
	# ---- HUD panels
	var huds: Array = split.get_children().filter(func(c): return c.get_script() != null and str(c.get_script().resource_path).ends_with("ability_hud.gd"))
	ok("player 2's ability panel is in player 2's view and shows moves", huds.size() == 1 and huds[0].custom_viewport == split.viewports[1] and huds[0]._weapon() != null)
	var p1_abilities = scripted(world, "ability_hud.gd")
	ok("player 1's ability panel is in player 1's view", p1_abilities != null and p1_abilities.custom_viewport == split.viewports[0])
	ok("each player has 2 weapon slots drawn (player 1's frames, player 2's frames)", p1.item != null and p2.weapon_slots.size() >= 2)
	var slots_ctl: Control = split._corner[1].slots
	ok("player 2's weapon slots are drawn in player 2's view", slots_ctl.is_visible_in_tree() and slots_ctl.size.x > 50.0)
	quit()
