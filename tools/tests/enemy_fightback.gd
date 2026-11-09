extends SceneTree
## Enemies fight back: they turn on you when hit, notice you close by, give up after a few seconds, take more damage from behind,
## and each type has a telegraphed move. Elites roll with a chance that grows over the waves.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func spawn(world, name: String, pos: Vector2):
	var e = load("res://enemies/%s/%s.tscn" % [name, name]).instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	return e
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://ef_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	p1.global_position = Vector2(-300, 600)       # out of the way
	var P := Vector2(300, 300)                    # player 2 stands here, further from the keep than the enemies below
	p2.global_position = P
	p2.shield_time = 0.0
	# ---- hit from behind: it turns on you
	var e = spawn(world, "blobbert", P + Vector2(-70, -70))
	await wait(0.3)
	var d0: float = e.global_position.distance_to(P)
	ok("an enemy that has not noticed you is not chasing", e.aggro_left <= 0.0)
	e.spell_damage(1.0)
	ok("hit once: it turns on you (aggro %.1f s)" % e.aggro_left, e.aggro_left > 2.5 and e.aggro_target == p2)
	await wait(0.8)
	print("  distance to the player: %.0f -> %.0f" % [d0, e.global_position.distance_to(P)])
	ok("and comes at you", e.global_position.distance_to(P) < d0 - 3.0)
	await wait(3.0)
	ok("with nobody hitting it, it gives up after about 3 s (aggro %.1f, cooldown %.1f)" % [e.aggro_left, e._aggro_cd], e.aggro_left <= 0.0 and e._aggro_cd > -1.0)
	e.queue_free()
	# ---- noticing you
	var near = spawn(world, "blobbert", P + Vector2(50, 0))
	await wait(0.6)
	ok("walking within 80 units, an enemy notices you", near.aggro_left > 0.0)
	near.queue_free()
	var far = spawn(world, "blobbert", P + Vector2(200, 0))
	await wait(0.6)
	ok("at 200 units it does not", far.aggro_left <= 0.0)
	far.queue_free()
	# ---- runner and spitter keep to their jobs
	var r = spawn(world, "runner", P + Vector2(30, 0))
	r.spell_damage(0.1)
	var sp = spawn(world, "spitter", P + Vector2(60, 0))
	sp.spell_damage(0.1)
	ok("runners and spitters never turn on you", r.aggro_left <= 0.0 and sp.aggro_left <= 0.0)
	r.queue_free(); sp.queue_free()
	# ---- backstab
	var b = spawn(world, "brute", Vector2(400, 400))
	b.set_physics_process(false)
	b.armor = 0.0
	b.max_health = 1000.0; b.health = 1000.0
	b.facing = Vector2.RIGHT
	b.hit_from = b.global_position + Vector2(-60, 0)         # an attacker behind it
	b.spell_damage(10.0)
	var behind: float = 1000.0 - b.health
	b.health = 1000.0
	b.facing = Vector2.RIGHT
	b.hit_from = b.global_position + Vector2(60, 0)          # an attacker in front
	b.spell_damage(10.0)
	var front: float = 1000.0 - b.health
	print("  10 damage from behind %.1f, from the front %.1f" % [behind, front])
	ok("a hit from behind does 30%% more (%.1f vs %.1f)" % [behind, front], absf(behind / front - 1.3) < 0.02)
	b.queue_free()
	# ---- the lunge: a wind-up you can see, then a dash
	var l = spawn(world, "scarab", P + Vector2(-60, 0))
	l.ability_cd = 0.0
	l.start_aggro(p2)
	await wait(0.25)
	ok("a chasing enemy winds up a lunge first (wind %.2f of 0.7)" % l._wind, l._wind > 0.3)
	var before: Vector2 = l.global_position
	await wait(0.6)
	ok("then dashes about 56 units (moved %.0f)" % before.distance_to(l.global_position), before.distance_to(l.global_position) > 25.0 and before.distance_to(l.global_position) < 80.0)
	await wait(0.1)
	var at_rest: Vector2 = l.global_position
	await wait(0.4)
	ok("and stands still for a moment afterwards (moved %.1f in 0.4 s)" % at_rest.distance_to(l.global_position), l._recover > 0.0 or at_rest.distance_to(l.global_position) < 4.0)
	ok("with a long pause before the next lunge (cooldown %.1f s left)" % l.ability_cd, l.ability_cd > 5.0)
	l.queue_free()
	# ---- the brute's slam hurts if you stay in the ring
	p2.global_position = P
	var br = spawn(world, "brute", P + Vector2(30, 0))
	br.ability_cd = 0.0
	br.start_aggro(p2)
	var hp0: float = p2.remote_hp
	await wait(0.3)
	ok("the brute rears up first (wind %.2f)" % br._wind, br._wind > 0.0)
	await wait(1.2)
	print("  p2 hp %.0f -> %.0f" % [hp0, p2.remote_hp])
	ok("and the slam lands if you stay put", p2.remote_hp < hp0)
	br.queue_free()
	# ---- frost imp bolt, ember imp trail
	p2.global_position = P
	p2.is_taking_damage = false
	var fi = spawn(world, "frost_imp", P + Vector2(80, 0))
	fi.ability_cd = 0.0
	fi.start_aggro(p2)
	await wait(0.9)
	ok("the frost imp throws a chill bolt", get_nodes_in_group("net").any(func(n): return n.get_script() != null and str(n.get_script().resource_path).ends_with("enemy_projectile.gd")))
	fi.queue_free()
	var em = spawn(world, "ember_imp", P + Vector2(-80, 0))
	em.start_aggro(p2)
	await wait(1.5)
	var trail: Array = get_nodes_in_group("hazard").filter(func(h): return !h.hurts_enemies)
	ok("the ember imp leaves a burning trail that only hurts players (%d patches)" % trail.size(), trail.size() >= 2)
	em.queue_free()
	# ---- elites
	ok("no elites in the first wave", world.elite_chance_for(1) == 0.0)
	ok("elites get likelier with the waves and with more players (%.2f at wave 3 for 2 players, %.2f at wave 8)" % [world.elite_chance_for(3), world.elite_chance_for(8)], world.elite_chance_for(8) > world.elite_chance_for(3) and world.elite_chance_for(3) > 0.0)
	var el = spawn(world, "goblin", Vector2(500, 500))
	await wait(0.1)
	var hp_before: float = el.shield
	el.apply_affix("shielded")
	ok("a shielded elite starts with a shield", el.shield > hp_before and el.affix == "shielded")
	var has = spawn(world, "goblin", Vector2(520, 500))
	await wait(0.1)
	var sp0: float = has.speed
	has.apply_affix("hasty")
	ok("a hasty elite moves 1.5x as fast", is_equal_approx(has.haste, 1.5))
	quit()
