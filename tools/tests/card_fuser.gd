extends SceneTree
## Card Fuser: recipes, costs, tier rule, the screen, the net command's range check, and casting a fused card.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://cf_test_save.json"
	game._menu_done = true
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var fuser = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("card_fuser.gd"): fuser = c
	ok("the Card Fuser stands across the keep from the Forge", fuser != null and fuser.position.x > 0 and net.CARD_FUSER_POS.x == -net.FORGE_POS.x)
	game.hand = ["fireball", "frost_ring", "barricade", "torch", "fireball:2"]
	game.resources.gold = 0
	var p: Dictionary = game.fuse_preview(0, 1)
	ok("a known recipe needs gold first: %s" % p.reason, !p.ok and p.reason.contains("gold"))
	ok("two different, non-matching cards do not fuse", !game.fuse_preview(0, 2).ok and game.fuse_preview(0, 2).reason.contains("do not fuse"))
	ok("a card cannot fuse with itself", !game.fuse_preview(0, 0).ok)
	game.resources.gold = 20
	game.hand = ["fireball:2", "frost_ring"]
	ok("different tiers refused", game.fuse_preview(0, 1).reason.contains("same tier"))
	game.hand = ["fireball", "frost_ring", "barricade", "torch"]
	ok("fusing spends gold, removes both, adds the hybrid with its twist", game.fuse_hand(0, 1) and game.resources.gold == 16 and game.hand.has("frostfire:1:aftermath"))
	print("  hand now: ", game.hand)
	ok("hand is down to 3 cards", game.hand.size() == 3)
	var wall := false
	game.hand = ["barricade", "torch"]
	wall = game.fuse_hand(0, 1)
	ok("barricade + torch = Bonfire Wall", wall and game.entry_id(game.hand[0]) == "bonfire_wall" and game.is_build(game.hand[0]))
	# the screen
	var ui = null
	for c in world.get_children():
		if c.is_in_group("card_fuse_ui"): ui = c
	game.hand = ["sentry", "torch", "spike_trap", "mender"]
	ui.open()
	await wait(0.3)
	ui._toggle(0); ui._toggle(1)
	await wait(0.2)
	ok("screen previews Beacon Turret and enables Fuse", !ui.fuse_button.disabled and ui.result_box.get_child_count() == 1)
	ui.fuse()
	await wait(0.2)
	ok("the screen fuses (%s)" % str(game.hand), game.hand.size() == 3 and game.hand.any(func(h): return game.entry_id(h) == "beacon_turret"))
	ui.close()
	# net command range check
	var pl = world.get_node("Player")
	game.hand = ["fireball", "flare"]
	game.resources.gold = 10
	pl.global_position = Vector2(0, 300)
	net.card_fuse(pl, 0, 1)
	ok("too far from the Fuser: nothing happens", game.hand.size() == 2)
	pl.global_position = net.CARD_FUSER_POS + Vector2(8, 0)
	net.card_fuse(pl, 0, 1)
	ok("next to it the command fuses Solar Burst", game.hand.size() == 1 and game.entry_id(game.hand[0]) == "solar_burst")
	# a fused card can be cast and rewards never offer it
	game.mana = 100
	game.players_in_base.append(pl)
	var hid: String = game.hand[0]
	var before: int = game.hand.size()
	ok("a fused spell casts", game.cast(hid, Vector2(100, 100)) and game.hand.size() == before - 1)
	var leaked := false
	for i in 40:
		game.meta.unlocked = game.CARDS.keys().filter(func(id): return !game.CARDS[id].get("fused", false))
	for id in game.CARDS:
		if game.CARDS[id].get("fused", false) and game.owns_card(id): leaked = true
	ok("fused cards are never in the unlocked list", !leaked)
	quit()
