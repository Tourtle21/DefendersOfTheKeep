extends SceneTree
# Build cards: cost materials (no mana), place a Structure, structure does its job.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func dummy(world, pos: Vector2):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	e.max_health = 40.0
	e.health = 40.0
	return e
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with('sector_manager.gd'): sm = c
	print("starter deck cards: ", game.unlocked_cards)
	for id in ["se", "ne", "n", "nw", "sw"]:
		sm.unlock(id)
		var combos := []
		for c in game.COMBO_CARDS:
			if c in game.unlocked_cards: combos.append(c)
		print("  after opening ", id, " combos available: ", combos)
	print("after sectors: ", game.unlocked_cards)
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()
	game.enter_base(player)
	var P := Vector2(0, 200)
	for id in ["spike_trap", "barricade", "spike_trap", "sentry", "mender", "iron_wall", "frost_totem", "ember_turret", "thorn_hedge", "crystal_pylon", "storm_spire", "magma_wall", "venom_tower", "prism_tower", "healing_grove"]:
		game.mana = 0
		game.resources = {"stone": 10, "stick": 10, "gold": 10, "iron": 10, "frost": 10, "ember": 10, "moss": 10, "gem": 10}
		game.hand = [id]
		var before = game.resources.duplicate()
		var d = dummy(world, P + Vector2(30, 0))
		player.global_position = P + Vector2(30, 10)
		var hr = world.get_node("Hud/Control2/ColorRect/Health")
		hr.size.x = 100.0
		var ok = game.cast(id, P, player)
		await wait(1.5)
		var st = null
		for s in get_nodes_in_group("structure"):
			if s.global_position.distance_to(P) < 2.0: st = s
		var spent := {}
		for k in before:
			if before[k] != game.resources[k]: spent[k] = before[k] - game.resources[k]
		await wait(1.5)
		if st == null:
			var ps := []
			for s2 in get_nodes_in_group("structure"): ps.append(s2.global_position)
			print("   no structure at ", P, " found: ", ps)
		print(id, " cast=", ok, " placed=", st != null, " spent=", spent, " mana=", game.mana,
			" | enemy hp ", snapped(d.health, 0.1), " slow ", d.slow_mult, " player hp bar ", snapped(hr.size.x, 0.1))
		for s in get_nodes_in_group("structure"): s.queue_free()
		for e in world.get_node("Enemies").get_children(): e.queue_free()
		await wait(0.2)
	game.meta.card_tiers["sentry"] = 6          # merging is limited by the unlocked tier: pretend sentry is maxed
	# tier merge: second sentry card dropped on the first
	game.resources = {"stone": 40, "stick": 40, "gold": 40}
	for i in 8:
		game.hand = ["sentry"]
		game.cast("sentry", P, player)
		await wait(1.0)
	var n := 0
	var tier := 0
	for s in get_nodes_in_group("structure"):
		n += 1
		tier = s.tier
	print("after 8 sentry casts on one spot (two of a tier merge up: expect one tier 4): structures=", n, " tier=", tier, " gold left=", game.resources.gold)
	for s in get_nodes_in_group("structure"): s.queue_free()
	# guards
	game.mana = 100
	game.resources = {"stone": 0, "stick": 0, "gold": 5}
	game.hand = ["guards"]
	var gd = dummy(world, P + Vector2(40, 0))
	print("guards cast: ", game.cast("guards", P, player), " gold left ", game.resources.gold)
	await wait(4.0)
	print("guards alive: ", get_nodes_in_group("guard").size(), " target hp ", snapped(gd.health, 0.1), "/40")
	for e in world.get_node("Enemies").get_children(): e.queue_free()
	for g in get_nodes_in_group("guard"): g.queue_free()
	# charm: two enemies, charm one, the other should get hurt
	game.mana = 100
	game.resources = {"stone": 0, "stick": 0, "gold": 5}
	game.hand = ["charm"]
	var a = dummy(world, P + Vector2(0, 0))
	var b = dummy(world, P + Vector2(90, 0))
	a.set_physics_process(true)
	b.set_physics_process(true)
	print("charm cast: ", game.cast("charm", P + Vector2(-10, 0), player))
	await wait(3.0)
	print("charmed a hp ", snapped(a.health, 0.1), " b hp ", snapped(b.health, 0.1), " (a charm_time ", snapped(a.charm_time, 0.1), ")")
	# unaffordable build is refused
	game.resources = {"stone": 1, "stick": 0, "gold": 0}
	game.hand = ["barricade"]
	print("barricade with 1 stone: ", game.cast("barricade", P, player))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
