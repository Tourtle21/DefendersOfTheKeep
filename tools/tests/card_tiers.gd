extends SceneTree
# Cards carry tiers: rare draws by skill level, merging identical cards, copies from drafts, the unlocked-tier ceiling.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(600.0)
	game.meta.card_tiers = {"fireball": 6, "frost_ring": 6, "barricade": 6, "spike_trap": 6}
	game.start_run()
	print("entries: ", game.entry_id("fireball:3"), " tier ", game.entry_tier("fireball:3"), " | plain ", game.entry_id("fireball"), " tier ", game.entry_tier("fireball"), " | make ", game.make_entry("fireball", 2))
	# rare draws by skill level
	for lvl in 6:
		game.meta.skills = {"rare_draw": lvl} if lvl > 0 else {}
		var counts := {1: 0, 2: 0, 3: 0, 4: 0}
		for i in 6000:
			counts[game.roll_card_tier("fireball")] += 1
		print("Rare Draws level ", lvl, ": tier 2 %.1f%%, tier 3 %.1f%%, tier 4 %.1f%%" % [counts[2] / 60.0, counts[3] / 60.0, counts[4] / 60.0])
	game.meta.skills = {"rare_draw": 5}
	game.meta.card_tiers["fireball"] = 2
	var counts2 := {1: 0, 2: 0, 3: 0, 4: 0}
	for i in 4000: counts2[game.roll_card_tier("fireball")] += 1
	print("same level 5 skill but fireball unlocked only to tier 2: tier 3+ draws = ", counts2[3] + counts2[4], " (capped)")
	# merging
	game.meta.card_tiers["fireball"] = 3
	game.hand = ["fireball", "fireball", "frost_ring"]
	print("merge two tier 1 fireballs: ", game.merge_hand(0, 1), " -> hand ", game.hand)
	game.hand = ["fireball:2", "fireball:2"]
	print("merge two tier 2: ", game.merge_hand(0, 1), " -> hand ", game.hand)
	game.hand = ["fireball:3", "fireball:3"]
	print("merge two tier 3 with unlocked tier 3 (blocked): ", game.merge_hand(0, 1), " -> hand ", game.hand)
	game.hand = ["fireball", "fireball:2"]
	print("different tiers cannot merge: ", game.merge_hand(0, 1))
	# a higher tier card is stronger
	print("fireball damage tier 1 / 2 / 3: ", game.stats_of("fireball").damage, " / ", game.stats_of("fireball:2").damage, " / ", game.stats_of("fireball:3").damage)
	# casting a tier 2 card
	var player = world.get_node("Player")
	game.enter_base(player)
	game.mana = 100
	game.hand = ["fireball:2"]
	print("cast a tier 2 fireball: ", game.cast("fireball:2", Vector2(0, 250), player), " | hand now ", game.hand)
	# draft duplicates
	game.hand = ["fireball"]
	game.deck = {"fireball": 1, "frost_ring": 1, "barricade": 1, "spike_trap": 1}
	game.draft_active = true
	game.take_draft_card("fireball")
	print("draft a duplicate fireball: deck ", game.deck.get("fireball"), " copies, hand ", game.hand)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
