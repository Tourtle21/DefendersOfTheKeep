extends SceneTree
## The gong above the well (a hit starts the next wave at once), the per-level enemy roster (three kinds per level phased in over the
## five waves, older kinds buffed but weaker than the new ones), chests only offering owned cards from open sectors, and
## players 2-4 reaching things exactly as far as player 1.
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
	game.save_path = "user://gr_test_save.json"
	game._menu_done = true
	game._local_devices = []
	game.fix_meta()
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "torch", "sandstorm", "blizzard", "mender"]
	game.unlocked_cards = game.meta.unlocked.duplicate()
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.5)
	var player = world.get_node("Player")
	# ---------- chest pool: owned cards only, and only from open sectors
	game.sectors_unlocked = ["s"]
	var bad := 0
	for i in 40:
		game.draft_active = false
		game.start_draft()
		for e in game.draft_options:
			var id: String = game.entry_id(e)
			if !game.owns_card(id) or !game.card_available(id):
				bad += 1
	game.draft_active = false
	ok("chests only offer cards you own from open sectors (%d bad in 40 chests)" % bad, bad == 0)
	# ---------- the gong
	var gong = scripted(world, "gong.gd")
	ok("the gong stands above the well", gong != null and gong.position.y < world.get_node("Well").position.y - 20.0)
	var timer: Timer = world.get_node("SpawnTimer")
	timer.start(9999.0)
	await wait(0.3)
	var waves0: int = game.run_stats.waves
	gong.ring()                                               # interacting with it
	await wait(1.0)
	ok("ringing the gong starts the next wave right away (waves %d -> %d)" % [waves0, game.run_stats.waves], game.run_stats.waves == waves0 + 1)
	var count: int = world.get_node("Enemies").get_child_count()
	ok("the wave brought enemies (%d)" % count, count > 0)
	var w1: int = game.run_stats.waves
	gong.ring()                                               # a second ring right away does nothing (it is still ringing)
	await wait(0.3)
	ok("a second ring while it sounds does not call another wave", game.run_stats.waves == w1)
	ok("the gong has its own sound", root.get_node("Sfx").streams.has("gong") and root.get_node("Sfx").streams["gong"].data.size() > 100000)
	ok("a player can interact with it: it is solid and has a reach", gong.collision_layer == 4 and gong.REACH > 0.0)
	# split-screen players and LAN clients ring it through Net._interact
	await wait(4.2)
	var w2: int = game.run_stats.waves
	var avatar = player
	avatar.global_position = gong.global_position + Vector2(0, 14)
	net._interact(avatar)
	await wait(0.6)
	ok("interacting next to it (Net._interact) rings it and starts a wave (%d -> %d)" % [w2, game.run_stats.waves], game.run_stats.waves == w2 + 1)
	await wait(4.2)
	avatar.global_position = Vector2(300, 300)
	var w3: int = game.run_stats.waves
	net._interact(avatar)
	await wait(0.4)
	ok("interacting far from it does nothing", game.run_stats.waves == w3)
	# ---------- the roster
	var W = world
	game.sectors_unlocked = ["s"]
	var seen := {}
	for k in range(1, 6):
		world.waves_in_sector = k
		var plan: Array = world.wave_plan()
		var names := plan.map(func(e): return e.label)
		seen[k] = names
	ok("level 1, wave 1: only the first kind (%s)" % [seen[1]], seen[1].size() == 1 and seen[1][0] == "Goblin")
	ok("level 1, wave 2: two kinds (%s)" % [seen[2]], seen[2].size() == 2)
	ok("level 1, wave 3: still two kinds (%s)" % [seen[3]], seen[3].size() == 2)
	ok("level 1, wave 4: all three kinds, a wave before the boss (%s)" % [seen[4]], seen[4].size() == 3)
	ok("level 1, wave 5 (the boss wave): all three kinds (%s)" % [seen[5]], seen[5].size() == 3)
	game.sectors_unlocked = ["s", "se", "ne"]
	world.waves_in_sector = 5
	var plan3: Array = world.wave_plan()
	var labels := plan3.map(func(e): return e.label)
	ok("level 3 boss wave: the 3 new kinds plus every older kind (%d kinds)" % plan3.size(), plan3.size() == 9 and "Brute" in labels and "Goblin" in labels and "Runner" in labels)
	var p_new := 0.0
	var p_old2 := 0.0
	var p_old1 := 0.0
	for e in plan3:
		if e.level == 3 and e.name == "brute": p_new = e.power
		if e.level == 2 and e.name == "golem": p_old2 = e.power
		if e.level == 1 and e.name == "goblin": p_old1 = e.power
	ok("new kinds are tougher than level-2 kinds, which are tougher than level-1 kinds (%.2f > %.2f > %.2f)" % [p_new, p_old2, p_old1], p_new > p_old2 and p_old2 > p_old1)
	var p_l1_alone := float(world.kind_power(1, 1))
	ok("older kinds get stronger as levels open (goblin %.2f at level 1 -> %.2f at level 3)" % [p_l1_alone, p_old1], p_old1 > p_l1_alone + 0.2)
	var never := true
	for front in range(1, 7):
		for l in range(1, front):
			if world.kind_power(l, front) >= world.kind_power(front, front):
				never = false
	ok("an older kind is never as strong as the front level's own kinds", never)
	world.waves_in_sector = 1
	game.sectors_unlocked = ["s", "se"]
	var plan2: Array = world.wave_plan()
	var first_l2 = plan2.filter(func(e): return e.level == 2)
	ok("level 2, wave 1: just the first new kind (%s), plus the level-1 kinds" % [first_l2.map(func(e): return e.label)], first_l2.size() == 1 and plan2.size() == 4)
	# power really reaches the enemy
	var e1 = load("res://enemies/brute/brute.tscn").instantiate()
	var base_hp := 0.0
	e1.power = 2.0
	e1.position = Vector2(600, 600)
	world.get_node("Enemies").add_child(e1)
	var e0 = load("res://enemies/brute/brute.tscn").instantiate()
	e0.position = Vector2(650, 600)
	world.get_node("Enemies").add_child(e0)
	await wait(0.3)
	ok("power 2 doubles an enemy's health and touch damage (%.1f vs %.1f hp, %.0f vs %.0f dmg)" % [e1.max_health, e0.max_health, e1.contact_damage, e0.contact_damage], absf(e1.max_health / e0.max_health - 2.0) < 0.01 and absf(e1.contact_damage / e0.contact_damage - 2.0) < 0.01)
	# ---------- reach
	ok("players 2-4 reach the Forge only where player 1's area does (%.0f)" % net.STATION_REACH, net.STATION_REACH <= 32.0)
	quit()
