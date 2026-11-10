extends SceneTree
## A slow, watchable tour of the 2-player split screen in a real window: both HUDs, a fight, the merge hint, both Forges,
## a chest for each player, and both players in a tower. Each stage is held for HOLD seconds (hold=<s>, default 6) and a
## PNG is saved to out=<dir> (default user://). Pass n=3 or n=4 to tour more players.
var N := 2
var HOLD := 6.0
var OUT := "user://"
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func scripted(world, f: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(f): return c
	return null
func stage(label: String, name: String) -> void:
	print("=== ", label)
	await wait(0.5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/tour_%s.png" % [OUT, name])
	await wait(HOLD)
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("needs a window")
		quit()
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="): N = int(a.substr(2))
		if a.begins_with("hold="): HOLD = float(a.substr(5))
		if a.begins_with("out="): OUT = a.substr(4)
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://tour_test_save.json"
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
	var hud = world.get_node("Hud")
	var p1 = world.get_node("Player")
	game.resources = {"stone": 30, "stick": 20, "gold": 40}
	game.note_weapon_tier("hammer", 1)
	game.note_weapon_tier("spear", 1)
	# a few cards, with a duplicate so the x2 shows on the chest screen
	game.hand = [game.make_entry("fireball", 1, ""), game.make_entry("fireball", 1, ""), game.make_entry("flare", 1, ""), game.make_entry("sentry", 1, "")]
	game.hand_changed.emit()
	for s in range(1, N):
		net.give_weapon(lp.avatars[s], "spear")
	await stage("1. START: every player's HUD (health, keep, resources, weapon slots, ability panel, wave timer)", "1_start")
	for i in 6:
		var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
		e.position = Vector2(60 + i * 25, 150)
		world.get_node("Enemies").add_child(e)
	await stage("2. A FIGHT: enemies close by, health bars and aimers", "2_fight")
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	# merge hint: everybody holds hammer + spear
	for id in ["hammer", "spear"]:
		var info = game.weapon_info(id)
		if hud.equip_item(info):
			p1.equip_item(info)
	for s in range(1, N):
		lp.avatars[s].weapon_slots = ["hammer", "spear"]
	p1.global_position = Vector2(150, 220)
	await wait(0.6)
	var fu = scripted(world, "forge_ui.gd")
	print("   p1 merge hint: visible=%s rect=%s viewport=%s text=%s" % [fu._merge_hint.visible, fu._merge_hint.get_global_rect(), fu._merge_hint.get_viewport().size, fu._merge_hint.text])
	await stage("3. MERGE HINT: two held weapons that fuse show a hint by the weapon slots", "3_merge_hint")
	# forges
	var forge = scripted(world, "forge_ui.gd")
	game._forge_store = ["spear", "hammer", "bow"]
	p1.global_position = net.FORGE_POS + Vector2(8, 0)
	forge.open()
	await stage("4. PLAYER 1 FORGE (hands and the forge's storage in separate areas)", "4_p1_forge")
	forge.root_ctl.visible = false
	for s in range(1, N):
		var av = lp.avatars[s]
		av.global_position = net.FORGE_POS + Vector2(8, 0)
		await wait(0.4)
		lp.forge_uis[s].open()
		await stage("5. PLAYER %d FORGE" % (s + 1), "5_p%d_forge" % (s + 1))
		lp.forge_uis[s].close()
		av.global_position = Vector2(-150 - 40 * s, 220)
	game._forge_store = []
	# chests: player 1, then each other player
	for s in N:
		game.draft_owner_slot = s
		game.start_draft()
		await stage("6. CHEST for player %d (their cards with x2, Combine when a pair can go up)" % (s + 1), "6_chest_p%d" % (s + 1))
		if game.draft_active and !game.draft_options.is_empty():
			game.take_draft_card(game.draft_options[0])
		await wait(0.5)
	game.draft_owner_slot = 0
	# towers
	var towers: Array = game.all_towers()
	for s in N:
		var pl = p1 if s == 0 else lp.avatars[s]
		pl.global_position = towers[mini(s, towers.size() - 1)].global_position + Vector2(0, 14)
		await wait(0.4)
		net._set_base(pl, true)
		await stage("7. TOWER HUD for player %d (cards, mana, upgrades)" % (s + 1), "7_tower_p%d" % (s + 1))
		net._set_base(pl, false)
	print("=== tour finished")
	quit()
