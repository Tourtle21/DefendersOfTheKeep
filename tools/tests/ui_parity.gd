extends SceneTree
## UI parity guard. Every shared screen is built through each front-end that has it (player 1, a split-screen player,
## a LAN client view fed a fake snapshot) with the same data at the same view size, and the trees must match:
## the same visible node kinds in the same order, the same texts (controller-button prefixes and input hints aside)
## and the same card sizes. A new screen must use one builder in ui/ and add itself here (see CLAUDE.md).
const V := Vector2(638, 718)          # one half of a 1280 x 720 window (the views keep a 1 px gap)
var fails := 0
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
	if !c:
		fails += 1
func scripted(world, name: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(name): return c
	return null

## Controller labels ("X   Fuse") and input hints differ by design; everything else must not.
func norm(t: String) -> String:
	var re := RegEx.create_from_string("^[ABXY] +")
	t = re.sub(t, "")
	var cut := t.find("   Left stick")
	return t.substr(0, cut) if cut >= 0 else t

## The shape of a screen: one line per visible Control (depth, kind, text, and the size of cards).
func sig(n: Node, depth := 0) -> Array:
	var out := []
	for c in n.get_children():
		if !(c is Control) or !c.visible or c is ReferenceRect or c.has_meta("parity_skip"):
			continue
		var line := "%d %s" % [depth, c.get_class()]
		if c is Label or c is Button:
			line += " '%s'" % norm(c.text)
		if c.get_script() != null and (str(c.get_script().resource_path).ends_with("tier_card.gd") or str(c.get_script().resource_path).ends_with("card_view.gd")):
			line += " %s" % str((c.size * c.scale).round())
		out.append(line)
		out.append_array(sig(c, depth + 1))
	return out

func same(name: String, a: Array, b: Array) -> void:
	var diff := ""
	for i in maxi(a.size(), b.size()):
		var x: String = a[i] if i < a.size() else "<none>"
		var y: String = b[i] if i < b.size() else "<none>"
		if x != y:
			diff = "line %d: %s  vs  %s" % [i, x, y]
			break
	ok("%s (%d nodes)%s" % [name, a.size(), "" if diff == "" else "  first difference " + diff], diff == "" and a.size() > 3)

func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://parity_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = scripted(world, "local_players.gd")
	var p2 = lp.avatars[1]
	var split = scripted(world, "split_screen.gd")
	var rects: Array = split.layout(2, Vector2(1280, 720))            # (a headless window stays tiny: size the views as a 1280 x 720 window would)
	for i in 2:
		split.containers[i].position = rects[i].position + Vector2(1, 1)
		split.containers[i].size = rects[i].size - Vector2(2, 2)
	await wait(0.3)
	split._pin_all()
	await wait(0.3)
	print("  views %s and %s" % [split.viewports[0].size, split.viewports[1].size])
	game.resources = {"stone": 30, "stick": 20, "gold": 99}
	var hud = world.get_node("Hud")                                   # the same two weapons in both players' hands
	for slot in hud.item_slots.get_children():
		slot.unequip()
	hud.equipped_items_count = 0
	var info = load("res://world/item_info.tres")
	hud.equip_item(info.items["spear"]); hud.equip_item(info.items["hammer"])
	p2.weapon_slots = ["spear", "hammer"]
	game._forge_store = ["bow"]
	game.hand = ["torch", "sentry", "fireball", "fireball"]
	var hand0: Array = game.hand.duplicate()
	await wait(0.3)
	# ---- Forge: player 1 vs player 2
	var forge = scripted(world, "forge_ui.gd")
	forge.open(); forge.fit_view(V)
	var fui = lp.forge_uis[1]
	p2.global_position = net.FORGE_POS + Vector2(8, 0)
	fui.open(); fui.fit(V); fui._refresh()
	await wait(0.6)
	var forge_p1 := sig(forge.view)
	same("Forge: player 1 = player 2", forge_p1, sig(fui.view))
	ok("Forge: same fit level (%d / %d)" % [forge.view.level, fui.view.level], forge.view.level == fui.view.level)
	forge.close(); fui.close()
	# ---- Card Fuser
	var fuse = scripted(world, "card_fuse_ui.gd")
	fuse.open(); fuse.fit_view(V); fuse._refresh()
	var zui = lp.fuser_uis[1]
	p2.global_position = net.CARD_FUSER_POS + Vector2(8, 0)
	zui.open(); zui.fit(V); zui._refresh()
	await wait(0.6)
	var fuser_p1 := sig(fuse.view)
	same("Card Fuser: player 1 = player 2", fuser_p1, sig(zui.view))
	fuse.close(); zui.close()
	# ---- chest draft
	game.draft_owner_slot = 0
	game.start_draft()
	await wait(0.3)
	var draft = scripted(world, "draft_ui.gd")
	draft.fit_view(V); draft.view.render()
	var dui = lp.draft_uis[1]
	dui.view.fit(V); dui.view.render(-1)
	await wait(0.8)
	var draft_p1 := sig(draft.view)
	var options: Array = game.draft_options.duplicate()
	same("chest draft: player 1 = player 2", draft_p1, sig(dui.view))
	# ---- HUD top and keep pieces (player 1's base_ui vs player 2's local HUD / keep screen)
	var bui = scripted(world, "base_ui.gd")
	var hud2 = scripted(lp.get_parent(), "split_screen.gd")._local_huds[0]
	var HudKit = load("res://ui/hud/hud_kit.gd")
	HudKit.fit_top(bui.top, V); HudKit.fit_top(hud2.top, V)
	HudKit.set_top(bui.top, game.carried, game.resources, game.keep_hp, game.keep_max())
	HudKit.set_top(hud2.top, game.carried, game.resources, game.keep_hp, game.keep_max())
	await wait(0.2)
	var top_of := func(t: Dictionary) -> Array:
		return [t.info.text, t.info.get_theme_font_size("font_size"), t.keep_lbl.text, t.keep_bar.offset_top, t.keep_bar.offset_left, t.wave.position.y, t.banner.offset_top]
	same("HUD top: player 1 = player 2", top_of.call(bui.top).map(str) + ["", "", ""], top_of.call(hud2.top).map(str) + ["", "", ""])
	var kui = lp.keep_uis[1]
	kui._upg_key = ""; kui._rebuild_upgrades()
	bui._rebuild_upgrades()
	ok("upgrade cards: player 1 and player 2 size them by one rule (%s / %s)" % [bui.upgrade_box.get_child(0).size, kui._upgrade_box.get_child(0).size],
		bui.upgrade_box.get_child(0).size == kui._upgrade_box.get_child(0).size)
	game.draft_active = false
	game.draft_options = []
	# ---- LAN client: the same screens from a fake snapshot
	world.queue_free()
	await wait(0.5)
	game.draft_options = options
	game.draft_active = true
	game.hand = hand0
	var cv = load("res://net/client_view.gd").new()
	cv.scripted_input = true
	cv.screen_size = V
	root.add_child(cv)
	var me: int = cv.multiplayer.get_unique_id()
	net.last_snapshot = {"t": 1, "players": [{"id": me, "pos": net.FORGE_POS, "hp": 1.0, "base": false, "slots": ["spear", "hammer"], "active": 0,
		"near_forge": true, "near_fuser": true, "down": 0, "carried": {"stone": 0, "stick": 0, "gold": 0}}],
		"roster": {me: "Sam"}, "lobby": false, "draft": [], "forge": net.FORGE_POS, "fuser": net.CARD_FUSER_POS, "keep": game.keep_hp, "keep_max": game.keep_max(),
		"mana": 0, "max_mana": 10, "wave": 1, "hand": game.hand, "deck": game.deck, "resources": game.resources, "store": ["bow"], "sectors": ["s"]}
	await wait(0.3)
	cv.open_forge()
	await wait(0.6)
	same("Forge: player 1 = LAN client", forge_p1, sig(cv.forge_view))
	cv.forge_view.visible = false
	cv.fuser_view.visible = true
	await wait(0.6)
	same("Card Fuser: player 1 = LAN client", fuser_p1, sig(cv.fuser_view))
	cv.fuser_view.visible = false
	net.last_snapshot.draft = options
	net.last_snapshot.t = 2
	await wait(0.9)
	same("chest draft: player 1 = LAN client", draft_p1, sig(cv.draft_view))
	print("ui_parity: %s" % ("all screens match" if fails == 0 else "%d FAIL" % fails))
	cv.queue_free()
	quit()
