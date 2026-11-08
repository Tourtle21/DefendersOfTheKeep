extends SceneTree
# Reward counts by level (none before the first wave is past), the win reward, and the six legendaries.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func dummy(world, pos: Vector2, hp := 5000.0):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	e.max_health = hp
	e.health = hp
	return e
func fresh(game) -> void:
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "torch"]
	game.meta.card_tiers = {}
	game.meta.weapons = []
	game.meta.pending = []
	game.meta.shards = 0
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var player = world.get_node("Player")
	var chain = ["s", "se", "ne", "n", "nw", "sw"]
	# ---- how many cards a run earns
	var table := []
	for lvl in range(1, 7):
		fresh(game)
		game.sectors_unlocked = chain.slice(0, lvl)
		game.run_stats = {"kills": 0, "gold": 0, "waves": 1, "bosses": 0}
		var none: int = game.make_rewards().size()
		fresh(game)
		game.run_stats.waves = 3
		var r: Array = game.make_rewards()
		table.append("level %d: first wave not passed -> %d cards, past it -> %d (expected %d)" % [lvl, none, r.size(), game.REWARD_COUNT[lvl]])
	print("\n".join(table))
	# ---- winning
	fresh(game)
	game.sectors_unlocked = chain.slice(0, 6)
	game.run_stats.waves = 12
	var won: Array = game.make_rewards(true)
	var leg := won.filter(func(e): return e.get("legendary", false))
	print("win: ", won.size(), " entries = ", won.size() - leg.size(), " cards + ", leg.size(), " legendary: ", leg.map(func(e): return "%s %s (%s, costs %s)" % [e.kind, e.id, e.result, e.get("cost", "-")]))
	var owned_leg := func(): return game.LEGENDARY_CARDS.filter(func(id): return id in game.meta.unlocked).size() + game.LEGENDARY_WEAPONS.filter(func(id): return id in game.meta.weapons).size()
	print("owned right after the win (it is an offer you pay for): ", owned_leg.call(), " | waiting in the vault: ", game.meta.pending.filter(func(e): return e.get("legendary", false)).size())
	game.meta.shards = 100
	print("unlock with 100 Shards: ", game.unlock_offer(leg[0]))
	game.meta.shards = 1000
	print("unlock with 1000 Shards: ", game.unlock_offer(leg[0]), " | owned now ", owned_leg.call(), " | Shards left ", game.meta.shards)
	for i in 5:
		var w: Array = game.make_rewards(true)
		var l = w[w.size() - 1]
		if i == 3:
			print("converting one instead: +", game.convert_offer(l), " Shards")
		else:
			game.unlock_offer(l)
	print("after 6 wins: owned ", owned_leg.call(), " of 6 (one was converted, so it can come again)")
	var seventh: Array = game.make_rewards(true)
	var last = seventh[seventh.size() - 1]
	print("another win: legendary entry is ", last.result, " for ", last.get("cost", last.shards))
	# not offered before they are won
	fresh(game)
	var leaked := 0
	for i in 60:
		game.run_stats.waves = 3
		game.sectors_unlocked = chain.slice(0, 6)
		for e in game.make_rewards():
			if e.id in game.LEGENDARY_CARDS or e.id in game.LEGENDARY_WEAPONS: leaked += 1
		game.meta.pending = []
	print("legendaries offered in 60 normal level-6 runs (should be 0): ", leaked)
	fresh(game)
	print("can buy a legendary card: ", game.can_buy_card("sunspire"), " | upgrade cost tier 1->2: sunspire ", (func(): game.meta.unlocked.append("sunspire"); return game.card_upgrade_cost("sunspire")).call(), " vs sentry ", game.card_upgrade_cost("sentry"))
	# ---- the legendary cards in play
	game.meta.unlocked = ["fireball", "frost_ring", "barricade", "spike_trap", "torch"] + game.LEGENDARY_CARDS
	game.meta.card_tiers = {"meteor_shower": 3, "stasis": 3, "sunspire": 3, "phoenix_shrine": 3}
	game.enter_base(player)
	player.is_in_tower = true
	game.mana = 300
	game.resources = {"stone": 50, "stick": 50, "gold": 50, "iron": 9, "frost": 9, "ember": 9, "moss": 9, "gem": 9}
	for id in game.LEGENDARY_CARDS:
		print(id, " tier 1 / 3: ", [1, 3].map(func(t): return game.card_numbers(id, t).filter(func(n): return n.label in ["Damage", "Meteors", "Radius", "Lasts (s)", "Light radius", "Healing/sec", "Range", "Shots/sec"]).map(func(n): return n.label + "=" + n.text)))
	var target = dummy(world, Vector2(0, 330))
	var others = [dummy(world, Vector2(25, 335)), dummy(world, Vector2(-25, 325))]
	game.hand = ["meteor_shower"]
	game.cast("meteor_shower", Vector2(0, 330), player)
	await wait(9.0)
	print("meteor shower: centre dummy lost ", snappedf(5000.0 - target.health, 0.1), " | neighbours lost ", others.map(func(e): return snappedf(5000.0 - e.health, 0.1)))
	for e in [target] + others: e.health = 5000.0
	game.hand = ["stasis"]
	game.cast("stasis", Vector2(0, 330), player)
	await wait(4.2)
	print("stasis field: enemy slow_mult inside ", target.slow_mult, " (0 = frozen) | exposed ", target.has_meta("exposed_until"))
	await wait(4.0)
	print("after it ends: slow_mult ", target.slow_mult)
	game.hand = ["sunspire"]
	game.cast("sunspire", Vector2(150, 300), player)
	await wait(5.0)
	var spire = null
	for s in get_nodes_in_group("structure"):
		if s.kind == "sentry" and s.global_position.distance_to(Vector2(150, 300)) < 30.0: spire = s
	var foe = dummy(world, Vector2(150, 400))
	await wait(3.0)
	print("sunspire: placed ", spire != null, " | light radius ", (spire.light_radius if spire != null else 0), " | shot the enemy 100 px away for ", snappedf(5000.0 - foe.health, 0.1))
	game.hand = ["phoenix_shrine"]
	game.cast("phoenix_shrine", Vector2(-150, 300), player)
	await wait(5.0)
	var shrine = null
	for s in get_nodes_in_group("structure"):
		if s.kind == "mender" and s.global_position.distance_to(Vector2(-150, 300)) < 30.0: shrine = s
	print("phoenix shrine: placed ", shrine != null, " | radius ", (shrine.radius if shrine != null else 0), " | light ", (shrine.light_radius if shrine != null else 0), " | heals ", (snappedf(shrine.data.heal_per_sec, 0.1) if shrine != null else 0), "/s")
	game.exit_base(player)
	player.is_in_tower = false
	# ---- the legendary weapons
	for wid in ["dawnbringer", "voidreaver"]:
		for tier_entry in [wid, wid + ":2"]:
			player.equip_item(game.weapon_info(tier_entry))
			await wait(0.3)
			var w = player.item
			var d1 = dummy(world, player.global_position + Vector2(25, 0))
			var d2 = dummy(world, player.global_position + Vector2(60, 5))
			player.remote_controlled = true
			player.remote_input = {"move": Vector2(1, 0), "aim": player.global_position + Vector2(100, 0), "attack": false, "ability": false, "dash": false, "ultimate": false}
			await wait(0.2)                                  # let the weapon pick up the new aim
			w.use_item()
			await wait(0.3)
			var atk := snappedf(5000.0 - d1.health, 0.1)
			w.use_dash()
			await wait(0.5)
			w.use_ability()
			await wait(1.0)
			w.use_ultimate()
			await wait(3.2)
			print("%s (tier %d): attack hit for %.1f | ability unlocked %s ultimate unlocked %s | enemies lost %.1f and %.1f in total | glow radius %.0f" % [wid, w.tier, atk, w.ability_unlocked(), w.ultimate_unlocked(), 5000.0 - d1.health, 5000.0 - d2.health, w.light_radius])
			d1.queue_free()
			d2.queue_free()
			player.remote_controlled = false
			await wait(0.2)
	fresh(game)
	game.meta.weapons = ["dawnbringer"]
	print("weapon chest pool once Dawnbringer is owned: ", game.weapon_pool())
	quit()
