extends SceneTree
# Balance curve (a tier N is worth more than the 2^(N-1) cards merged into it), twists, and the structure feeding meter.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func dummy(world, pos: Vector2):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	e.max_health = 5000.0
	e.health = 5000.0
	return e
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.card_tiers = {}
	for id in game.CARDS: game.meta.card_tiers[id] = 6
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	print("--- balance: output of ONE tier-N card vs the 2^(N-1) tier-1 cards that make it ---")
	for t in range(1, 5):
		var s = game.scaled("sentry", t)
		var s1 = game.scaled("sentry", 1)
		var dps: float = s.damage / s.interval
		var dps1: float = s1.damage / s1.interval
		var b = game.scaled("barricade", t)
		var f = game.scaled("fireball", t)
		var fz = game.scaled("lava_pool", t)
		var tr = game.scaled("spike_trap", t)
		print("tier %d (worth %d cards): sentry dps %.1fx (range %.0f), barricade hp %.1fx, fireball damage %.1fx and area %.1fx, lava pool dps %.1fx, spike trap dmg %.1fx x uses %.1fx" % [t, 1 << (t - 1), dps / dps1, s.range, b.hp / game.scaled("barricade", 1).hp, f.damage / game.scaled("fireball", 1).damage, pow(f.radius / game.scaled("fireball", 1).radius, 2), fz.dps / game.scaled("lava_pool", 1).dps, tr.damage / game.scaled("spike_trap", 1).damage, float(tr.uses) / game.scaled("spike_trap", 1).uses])
	print("--- twists are fixed per card and tier ---")
	for id in ["fireball", "sentry", "barricade", "frost_ring"]:
		print(id, range(1, 7).map(func(t): return game.twist_for(id, t)))
	for id in ["spear", "bow", "lance"]:
		print(id, range(1, 7).map(func(t): return game.weapon_twist(id, t)))
	var stable := true
	for i in 200:
		if game.twist_for("sentry", 4) != game.twist_for("sentry", 4) or game.weapon_twist("spear", 5) != game.weapon_twist("spear", 5):
			stable = false
	print("deterministic: ", stable, " tier 1 has none: ", game.twist_for("sentry", 1) == "" and game.weapon_twist("spear", 1) == "")
	# spell twists
	var e1 = dummy(world, Vector2(0, 260))
	game.enter_base(player)
	game.mana = 100
	for tw in ["", "twin", "echo", "aftermath", "shrapnel"]:
		e1.health = 5000.0
		var entry: String = game.make_entry("fireball", 2, tw)
		game.hand = [entry]
		game.mana = 100
		var haz0 := get_nodes_in_group("hazard").size()
		game.cast(entry, e1.global_position, player)
		await wait(3.2)
		print("fireball tier 2 with twist '", tw, "': damage dealt ", snapped(5000.0 - e1.health, 0.1), ", new hazard patches ", get_nodes_in_group("hazard").size() - haz0)
		for h in get_nodes_in_group("hazard"):
			if h.lifetime > 0.0: h.queue_free()
		await wait(0.3)
	# structure twists
	var structs := {}
	for pair in [["barricade", "thorned"], ["barricade", "regrow"], ["spike_trap", "rearm"], ["sentry", "twin_shot"], ["sentry", "blast_shot"], ["mender", "wide_field"], ["frost_totem", "deep_freeze"]]:
		var c = game.stats_of(game.make_entry(pair[0], 2, pair[1]))
		var st = load("res://cards/structure.gd").new()
		st.setup(c, Vector2(randf_range(-200, 200), 900))
		world.add_child(st)
		structs[pair[1]] = st
		await wait(0.1)
	print("thorned barricade thorns: ", snapped(structs.thorned.data.get("thorns", 0.0), 0.1), " | blast_shot sentry burst: ", snapped(structs.blast_shot.data.get("burst", 0.0), 0.1), " | wide mender radius ", snapped(structs.wide_field.radius, 1.0), " (base ", game.scaled("mender", 2).radius, ") | deep freeze slow ", snapped(structs.deep_freeze.data.slow, 0.01), " vs ", snapped(game.scaled("frost_totem", 2).slow, 0.01))
	var rg = structs.regrow
	rg.hp = 1.0
	await wait(2.0)
	print("regrow barricade healed from 1.0 to ", snapped(rg.hp, 0.1), " in 2 s")
	# twin shot: two enemies near a sentry
	var ts = structs.twin_shot
	ts.position = Vector2(0, 700)
	var ea = dummy(world, Vector2(20, 700))
	var eb = dummy(world, Vector2(-25, 700))
	for tur in get_nodes_in_group("turret"): tur.ammo = 0
	await wait(1.6)
	print("twin shot sentry: enemy A took ", snapped(5000.0 - ea.health, 0.1), ", enemy B took ", snapped(5000.0 - eb.health, 0.1), " (both hit by one volley)")
	# feeding meter
	for s in get_nodes_in_group("structure"): s.queue_free()
	await wait(0.3)
	game.resources = {"stone": 99, "stick": 99, "gold": 99}
	game.mana = 100
	var placed := []
	for i in 8:
		game.hand = ["barricade"]
		game.cast("barricade", Vector2(300, 300), player)
		await wait(1.0)
		var wall = null
		for s in get_nodes_in_group("structure"):
			if s.global_position.distance_to(Vector2(300, 300)) < 30.0: wall = s
		if wall != null: placed.append("%d casts: tier %d, %d/%d points, needs %d more" % [i + 1, wall.tier, wall.points - wall.tier_points(wall.tier), wall.tier_points(wall.tier), wall.needs()])
	print("feeding tier 1 barricade cards into one spot:\n   ", "\n   ".join(placed))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
