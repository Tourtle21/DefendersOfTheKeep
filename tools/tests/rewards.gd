extends SceneTree
# End-of-run rewards: one card per level reached, all kept, duplicates become Shards,
# tiers and items limited to the level reached. Card tiers, Shard upgrades, collection UI.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func fresh_meta(game) -> void:
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "torch"]
	game.meta.card_tiers = {}
	game.meta.weapons = []
	game.meta.shards = 0
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var chain = ["s", "se", "ne", "n", "nw", "sw"]
	for lvl in range(1, 7):
		var violations := 0
		var skipped_tier := 0
		var counts := {"offer": 0, "upgrade": 0, "spare": 0, "converted": 0}
		var count_ok := true
		for trial in 40:
			fresh_meta(game)
			# a random collection: some cards owned at random tiers
			for id in game.CARDS:
				if randf() < 0.5 and game.card_level(id) <= 6 and !game.is_legendary_card(id):
					if !(id in game.meta.unlocked): game.meta.unlocked.append(id)
					game.meta.card_tiers[id] = randi_range(1, 6)
			var before: Dictionary = game.meta.card_tiers.duplicate()
			var owned_before: Array = game.meta.unlocked.duplicate()
			game.sectors_unlocked = chain.slice(0, lvl)
			game.run_stats.waves = 3
			var r: Array = game.make_rewards()
			if r.size() != game.REWARD_COUNT[lvl]: count_ok = false
			for e in r:
				counts[e.result] = counts.get(e.result, 0) + 1
				if e.kind == "card":
					if game.card_level(e.id) > lvl: violations += 1
					var owned: bool = e.id in owned_before
					var cur: int = before.get(e.id, 1) if owned else 0
					if e.result == "offer" and (owned or e.tier != 1): skipped_tier += 1
					if e.result == "upgrade" and (!owned or e.tier != cur + 1 or e.tier > lvl): skipped_tier += 1
				elif e.kind == "weapon" and game.WEAPON_LEVEL[e.id] > lvl:
					violations += 1
		print("level ", lvl, ": count ok ", count_ok, ", realm violations ", violations, ", tier-skipping rewards ", skipped_tier, ", results ", counts)
	# the economy
	print("--- economy (Shards) ---")
	var runs := {"first run (wave 3, level 1)": [{"kills": 15, "gold": 10, "waves": 3, "bosses": 0}, 1], "decent run (wave 8, level 2)": [{"kills": 50, "gold": 60, "waves": 8, "bosses": 1}, 2], "level 4 run (wave 9)": [{"kills": 64, "gold": 90, "waves": 9, "bosses": 3}, 4], "level 6 run (wave 16)": [{"kills": 140, "gold": 250, "waves": 16, "bosses": 6}, 6]}
	for label in runs:
		game.run_stats = runs[label][0]
		game.sectors_unlocked = chain.slice(0, runs[label][1])
		print("  %-30s earns %d Shards" % [label, game.shards_for_run()])
	print("  card unlock prices by realm 1..6: ", range(1, 7).map(func(l): return int(round(16.0 * pow(l, 1.5)))))
	print("  card upgrade prices tier 1->2 .. 5->6: ", range(1, 6).map(func(t): return int(round(8.0 * pow(t, 1.5)))), " total ", range(1, 6).map(func(t): return int(round(8.0 * pow(t, 1.5)))).reduce(func(a, b): return a + b))
	print("  weapons ", game.WEAPON_UNLOCK_COSTS, " | fusion tiers ", game.FUSION_TIER_COSTS, " | win bonus 30")
	# offers: need Shards to unlock, can be converted
	fresh_meta(game)
	game.sectors_unlocked = chain.slice(0, 3)
	var offers: Array = game.make_rewards().filter(func(e): return e.result == "offer")
	print("offers (not auto-unlocked): ", offers.size(), " owned after draw: ", game.meta.unlocked.size(), " (4 = nothing auto-added)")
	if offers.size() >= 2:
		var o1 = offers[0]
		var o2 = offers[1]
		game.meta.shards = 0
		print("unlock '", o1.id, "' with 0 shards (cost ", o1.cost, "): ", game.unlock_offer(o1))
		game.meta.shards = o1.cost + 1
		print("unlock with ", game.meta.shards, " shards: ", game.unlock_offer(o1), " owned ", game.owns_card(o1.id) or (o1.id in game.meta.weapons), " shards left ", game.meta.shards, " result ", o1.result)
		var before: int = game.meta.shards
		print("convert '", o2.id, "': +", game.convert_offer(o2), " shards ", before, " -> ", game.meta.shards, " result ", o2.result, ", convert again: +", game.convert_offer(o2))
	# upgrade path
	fresh_meta(game)
	game.meta.shards = 400
	for i in 6:
		print("  upgrade fireball -> ", game.upgrade_card("fireball"), " tier ", game.card_tier("fireball"), " shards ", game.meta.shards)
	print("fireball numbers t1: ", game.card_numbers("fireball", 1).map(func(n): return n.label + "=" + n.text))
	print("fireball numbers t6: ", game.card_numbers("fireball", 6).map(func(n): return n.label + "=" + n.text))
	# new run starts the deck at permanent tiers
	game.meta.card_tiers["fireball"] = 4
	game.start_run()
	print("new run deck (every card starts at tier 1, ceiling is the unlocked tier ", game.card_tier("fireball"), "): ", game.deck, " fireball damage ", game.stats("fireball").damage)
	# screenshots of the run end screen and collection
	fresh_meta(game)
	game.run_stats = {"kills": 90, "gold": 200, "waves": 14, "bosses": 3}
	game.sectors_unlocked = chain.slice(0, 5)
	game.meta.shards = 40
	game.end_run("The keep has fallen")
	await wait(0.6)
	if DisplayServer.get_name() != "headless":
		root.get_viewport().get_texture().get_image().save_png("user://rewards_end.png")
	var ui = null
	for c in world.get_children():
		if c is CanvasLayer and c.get("collection") != null: ui = c
	ui.collection.selected = "fireball"
	ui.collection.open()
	await wait(0.6)
	if DisplayServer.get_name() != "headless":
		root.get_viewport().get_texture().get_image().save_png("user://rewards_collection.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
