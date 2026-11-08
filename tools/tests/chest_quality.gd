extends SceneTree
# Chests pay out better the deeper you are: higher tier odds for weapon chests and card drafts.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	game.meta.skills = {}
	game.meta.weapons = []
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap"]
	game.meta.card_tiers = {"fireball": 6, "frost_ring": 6, "barricade": 6, "spike_trap": 6}
	game.meta.fusion_tiers = [3, 4]
	var chain = ["s", "se", "ne", "n", "nw", "sw"]
	for lvl in range(1, 7):
		game.sectors_unlocked = chain.slice(0, lvl)
		var w := {}
		var c := {}
		for i in 3000:
			var t: int = game.weapon_tier_of(game.roll_weapon_entry("spear", game.chest_level()))
			w[t] = w.get(t, 0) + 1
			var ct: int = game.roll_card_tier("fireball", game.chest_level())
			c[ct] = c.get(ct, 0) + 1
		print("level %d (chest odds row %d): weapon tiers %s | card tiers %s" % [lvl, game.chest_level(), w, c])
	game.sectors_unlocked = chain.slice(0, 6)
	var sw := {}
	var cw := {}
	for i in 3000:
		var a: int = game.weapon_tier_of(game.roll_weapon_entry("spear", game.chest_level(1)))
		sw[a] = sw.get(a, 0) + 1
		var b: int = game.weapon_tier_of(game.roll_weapon_entry("spear", game.chest_level()))
		cw[b] = cw.get(b, 0) + 1
	print("level 6, 3000 rolls: chest weapon tiers %s | rainbow sheep weapon tiers %s" % [cw, sw])
	# the sheep itself
	var sheep = load("res://collectables/sheep/rainbow_sheep.gd").new()
	sheep.position = Vector2(0, 300)
	world.add_child(sheep)
	await process_frame
	var picks0 := get_nodes_in_group("pickup").size()
	var chests0 := get_nodes_in_group("chest").size()
	sheep._die()
	await wait(0.3)
	var weapons := 0
	for p in get_nodes_in_group("pickup"):
		if p.item_type in ["sword", "pickaxe", "spear", "hammer", "bow", "daggers"] and p.fixed: weapons += 1
	print("sheep death dropped weapon pickups: ", weapons, " (expect 1) | chest group now ", get_nodes_in_group("chest").size() - chests0, " (60% chance of a boosted card chest)")
	# the real thing: a weapon chest and a card chest
	game.sectors_unlocked = chain.slice(0, 5)
	var best := 1
	for i in 60:
		var chest = load("res://collectables/chest/chest.gd").new()
		chest.kind = "weapon"
		chest.position = Vector2(0, 200)
		world.add_child(chest)
		chest._open()
		await process_frame
		for p in get_nodes_in_group("pickup"):
			if p.fixed and p.bonus > 0:
				best = maxi(best, 1 + p.bonus)
			p.queue_free()
		chest.queue_free()
	print("60 weapon chests at level 5 dropped tools/weapons up to tier ", best + 0, " (a pickup keeps its tier: fixed)")
	game.deck = {}
	game.hand = []
	var drafts := 0
	var tiered := 0
	for i in 40:
		game.draft_active = false
		game.start_draft()
		for e in game.draft_options:
			drafts += 1
			if game.entry_tier(e) > 1: tiered += 1
		var pick: String = game.draft_options[0]
		game.take_draft_card(pick)
	print("40 card chests at level 5: %d options, %d above tier 1, hand now %s" % [drafts, tiered, game.hand.slice(0, 4)])
	game.meta.card_tiers = {"fireball": 2, "frost_ring": 1, "barricade": 1, "spike_trap": 1}
	var over := 0
	for i in 200:
		game.draft_active = false
		game.start_draft()
		for e in game.draft_options:
			if game.entry_tier(e) > game.card_tier(game.entry_id(e)): over += 1
	print("draft options above the unlocked tier (should be 0): ", over)
	quit()
