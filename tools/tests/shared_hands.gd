extends SceneTree
## Player 1 (weapons in the HUD slots) and a split-screen player (weapon_slots) go through the SAME Net functions for everything
## about their hands: held list, give, pickup (merge), store in the forge, take out, craft. Both are run through one script of
## steps and must end up in the same state.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func scripted(world, name: String):
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with(name): return c
	return null
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://sh_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = scripted(world, "local_players.gd")
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	var hud = world.get_node("Hud")
	game.note_weapon_tier("hammer", 1)
	game.note_weapon_tier("spear", 1)
	game.resources = {"stone": 40, "stick": 40, "gold": 99}
	game.meta.weapon_tiers["hammer"] = 2
	var results := {}
	for who in [[p1, "player 1"], [p2, "player 2"]]:
		var pl = who[0]
		var name: String = who[1]
		game._forge_store = []
		if pl == p1:
			for fr in hud.item_slots.get_children():
				hud.remove_slot(fr.get_index())
		else:
			pl.weapon_slots = []
		var log := []
		net.give_weapon(pl, "hammer")
		net.give_weapon(pl, "spear")
		log.append(net.held_of(pl).duplicate())
		ok("%s: holds hammer and spear (%s)" % [name, str(net.held_of(pl))], net.held_of(pl).size() == 2)
		ok("%s: stores the hammer in the forge" % name, net.toggle_store(pl, "held", 0) and game._forge_store == ["hammer"] and net.held_of(pl).size() == 1)
		log.append(net.held_of(pl).duplicate())
		ok("%s: takes it back out" % name, net.toggle_store(pl, "store", 0) and game._forge_store.is_empty() and net.held_of(pl).size() == 2)
		var made: bool = net.craft(pl, "held", 0, "held", 1)
		ok("%s: crafts the pair (%s)" % [name, str(net.held_of(pl))], made and net.held_of(pl).size() == 1)
		log.append(net.held_of(pl).duplicate())
		net.give_weapon(pl, "hammer")
		net.pickup_weapon(pl, game.make_weapon_entry("hammer", 0, ""))
		ok("%s: picking up a second hammer merges (%s)" % [name, str(net.held_of(pl))], net.held_of(pl).size() == 2 and game.weapon_tier_of(net.held_of(pl)[1]) == 2)
		log.append(net.held_of(pl).duplicate())
		results[name] = log
	ok("both players end every step in the same state", str(results["player 1"]) == str(results["player 2"]))
	if str(results["player 1"]) != str(results["player 2"]):
		print("  p1 ", results["player 1"], "\n  p2 ", results["player 2"])
	quit()
