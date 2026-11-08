extends SceneTree
# Day/night cycle, the wave schedule, the night shroud and everything that lights it up.
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
func lost(e, f: Callable) -> float:
	e.health = 5000.0
	f.call()
	return snappedf(5000.0 - e.health, 0.01)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var player = world.get_node("Player")
	# ---- the clock
	var W = world.get_script()
	print("--- night level by clock (cycle 300 s): ", [0, 100, 150, 175, 200, 230, 260, 280, 299].map(func(c): return "%d:%.2f" % [c, W.night_for(c)]))
	var dark_secs := 0
	for c in 300:
		if W.night_for(c) > 0.5: dark_secs += 1
	print("seconds per cycle that are more than half dark: ", dark_secs, " | full day lasts until ", 150, " s (old cycle: dark after 30 s)")
	# wave schedule over two cycles, from the real director
	world.clock = 50.0
	world.night_wave = false
	var times := [50.0]
	var kinds := ["day"]
	var t := 50.0
	for i in 5:
		world.night_wave = !world.night_wave
		var gap: float = world.seconds_until(W.NIGHT_WAVE_AT if world.night_wave else W.DAY_WAVE_AT)
		t += gap
		world.clock = t
		times.append(t)
		kinds.append("night" if world.night_wave else "day")
	print("wave times (s): ", times.map(func(x): return snappedf(x, 1.0)), " kinds ", kinds)
	var gaps := []
	for i in range(1, times.size()): gaps.append(snappedf(times[i] - times[i - 1], 1.0))
	print("gaps between waves (s): ", gaps, " (old: 15 to 60)")
	print("title: ", world.wave_title())
	world.clock = 0.0
	# ---- the shroud (the world's clock drives night_level, so park it at midnight or midday)
	var midnight := func(): world.clock = 230.0; game.night_level = 1.0
	var midday := func(): world.clock = 20.0; game.night_level = 0.0
	midday.call()
	var far = dummy(world, Vector2(700, 700))
	var day := lost(far, func(): far.spell_damage(10.0, "", false))
	midnight.call()
	var dark := lost(far, func(): far.spell_damage(10.0, "", false))
	var fire := lost(far, func(): far.spell_damage(10.0, "fire", false))
	var near = dummy(world, player.global_position + Vector2(20, 0))
	var lit_near := lost(near, func(): near.spell_damage(10.0, "", false))
	print("10 damage: day %.1f | night in the dark %.1f | night, fire damage %.1f | night standing near you %.1f" % [day, dark, fire, lit_near])
	far.set_meta("lit_until", 0.0)
	# a torch lights the area
	var torch = load("res://cards/structure.gd").new()
	torch.setup(game.stats_of("torch"), Vector2(700, 640))
	world.add_child(torch)
	await wait(0.2)
	midnight.call()
	var with_torch := lost(far, func(): far.spell_damage(10.0, "", false))
	print("torch 60 px away: light radius %.0f, in the light %.1f damage | in group light %s" % [torch.light_radius, with_torch, torch.is_in_group("light")])
	torch.queue_free()
	await wait(0.2)
	# a fire weapon lights what it hits
	player.equip_item(game.weapon_info("torch"))
	await wait(0.3)
	midnight.call()
	print("torch weapon: light radius ", player.item.light_radius, " | player light ", game.player_light(player), " | unlit enemy lit after a hit: ", (func():
		far.set_meta("lit_until", 0.0)
		load("res://items/weapons/weapon_util.gd").hit(far, 1.0, far.global_position + Vector2(-5, 0))
		return game.is_lit(far)).call())
	player.equip_item(game.weapon_info("sword"))
	await wait(0.3)
	print("sword (no glow): player light ", game.player_light(player))
	# ---- what defences see in the dark
	midnight.call()
	var s = dummy(world, Vector2(-700, 700))
	var sentry_pos := Vector2(-700, 620)
	print("sentry sees an unlit enemy 80 px away at night: ", game.defence_sees(s, sentry_pos), " | at 40 px: ", game.defence_sees(s, Vector2(-700, 660)))
	var tr = load("res://cards/structure.gd").new()
	tr.setup(game.stats_of("torch"), Vector2(-700, 690))
	world.add_child(tr)
	await wait(0.2)
	midnight.call()
	print("with a torch beside it: ", game.defence_sees(s, sentry_pos))
	tr.queue_free()
	midday.call()
	print("daylight: ", game.defence_sees(s, sentry_pos))
	# ---- cards
	for id in ["torch", "flare"]:
		var c: Dictionary = game.CARDS[id]
		print(id, ": ", c.name, " | tiers t1/t3/t6: ", [1, 3, 6].map(func(t): return game.card_numbers(id, t).filter(func(n): return n.label in ["Light radius", "Radius", "Lasts (s)", "Health"]).map(func(n): return n.label + "=" + n.text)))
	print("torch is a starter card: ", "torch" in game.STARTER_CARDS, " | in a fresh save: ", "torch" in game.meta.unlocked)
	# ---- draws at night
	game.deck = {"fireball": 1, "frost_ring": 1, "torch": 1, "barricade": 1, "spike_trap": 1, "flare": 1}
	game.hand = []
	for lvl in [0.0, 1.0]:
		game.night_level = lvl
		var counts := {}
		for i in 4000:
			game.hand = []
			var e: String = game.entry_id(game.draw_card())
			counts[e] = counts.get(e, 0) + 1
		var light_cards: int = counts.get("fireball", 0) + counts.get("flare", 0) + counts.get("torch", 0)
		print("draws at night level %.0f (4000 draws): %s | light cards %.0f%%" % [lvl, counts, light_cards / 40.0])
	# ---- flare spell (cards are played from inside the keep)
	game.enter_base(player)
	player.is_in_tower = true
	midnight.call()
	game.mana = 100
	game.resources = {"stone": 9, "stick": 9, "gold": 9}
	game.hand = ["flare"]
	game.cast("flare", Vector2(300, 700), player)
	await wait(7.0)
	midnight.call()
	var lights := get_nodes_in_group("light").filter(func(n): return n.get("light_radius") != null and n.light_radius > 0.0 and n.global_position.distance_to(Vector2(300, 700)) < 5.0)
	print("flare landed: light sources there: ", lights.size(), " radius ", (lights[0].light_radius if lights.size() > 0 else 0))
	game.hand = ["fireball"]
	game.cast("fireball", Vector2(-300, 700), player)
	await wait(6.0)
	print("fireball blast left a light there: ", get_nodes_in_group("light").filter(func(n): return str(n.get_script().resource_path).ends_with("light_source.gd") and n.global_position.distance_to(Vector2(-300, 700)) < 5.0).size() > 0)
	game.exit_base(player)
	player.is_in_tower = false
	# ---- the dash goes where you move
	midday.call()
	player.equip_item(game.weapon_info("spear"))
	await wait(0.3)
	player.remote_controlled = true
	player.remote_input = {"move": Vector2(0, 1), "aim": player.global_position + Vector2(-100, 0), "attack": false, "ability": false, "dash": false, "ultimate": false}
	await wait(0.2)
	player.item.use_dash()
	print("moving down, mouse to the left: dash velocity ", player.dash_velocity.normalized().snapped(Vector2(0.01, 0.01)), " (down is 0,1)")
	await wait(0.4)
	player.remote_input = {"move": Vector2.ZERO, "aim": player.global_position + Vector2(-100, 0), "attack": false, "ability": false, "dash": false, "ultimate": false}
	await wait(0.6)
	player.item._dash_cd = 0.0
	player.item.use_dash()
	print("standing still, mouse to the left: dash velocity ", player.dash_velocity.normalized().snapped(Vector2(0.01, 0.01)), " (falls back to the mouse)")
	player.equip_item(game.weapon_info("pickaxe"))
	await wait(0.3)
	player.remote_input = {"move": Vector2(1, 0), "aim": player.global_position + Vector2(-100, 0), "attack": false, "ability": false, "dash": false, "ultimate": false}
	await wait(0.2)
	player.item.use_dash()
	print("pickaxe, moving right, mouse left: dash velocity ", player.dash_velocity.normalized().snapped(Vector2(0.01, 0.01)))
	quit()
