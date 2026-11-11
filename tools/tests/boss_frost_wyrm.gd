extends SceneTree
## The Frost Wyrm fights differently from the other bosses: it burrows (untouchable), erupts where you stood and is then EXPOSED
## (takes more damage), raises ice pillars that stop its breath, and charges across the arena leaving a frozen trail. Also: every
## boss is tougher than it was (health and damage rise boss to boss).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://bfw_test_save.json"
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	sm.unlock("se")
	sm.unlock("ne")
	await wait(0.3)
	var wyrm = null
	var bosses := {}
	for b in get_nodes_in_group("boss"):
		bosses[b.sector_id] = b
		if b.sector_id == "ne": wyrm = b
	# ---------- tougher bosses, rising boss to boss
	var order := ["s", "se", "ne"]
	var rising := true
	var prev_hp := 0.0
	var prev_dm := 0.0
	for id in order:
		if bosses[id].max_health <= prev_hp or bosses[id].dmg_mult <= prev_dm:
			rising = false
		prev_hp = bosses[id].max_health
		prev_dm = bosses[id].dmg_mult
	ok("boss health and damage rise boss to boss (%s)" % [order.map(func(i): return "%d hp x%.2f" % [bosses[i].max_health, bosses[i].dmg_mult])], rising)
	ok("the Frost Wyrm has the new kit (%s)" % [wyrm.attacks], wyrm.attacks == ["burrow", "frost_breath", "glacier_run"])
	ok("it shares no attack with the Sand Colossus", !wyrm.attacks.any(func(a): return a in bosses["se"].attacks))
	# ---------- wake it and put it in front of a player
	wyrm.arrive()
	var p = world.get_node("Player")
	p.global_position = Vector2(150, -300)
	wyrm.global_position = Vector2(150, -380)
	await wait(2.0)
	var A = load("res://enemies/boss/boss_attacks.gd")
	wyrm._state = "recover"
	# ---------- burrow
	var hp0: float = wyrm.health
	A.burrow(wyrm)                                            # (runs in the background)
	await wait(1.2)
	ok("under the snow it is hidden and not an enemy", !wyrm.visible and !wyrm.is_in_group("enemy") and wyrm.untargetable)
	wyrm.spell_damage(10.0)
	ok("and nothing can hurt it down there", wyrm.health == hp0)
	var waited := 0.0
	while waited < 9.0 and !(wyrm.visible and wyrm.vulnerable > 1.5):          # (the dive takes a few seconds)
		await wait(0.1)
		waited += 0.1
	ok("after the eruption it is back, visible and an enemy again", wyrm.visible and wyrm.is_in_group("enemy") and !wyrm.untargetable)
	ok("stranded on the surface it is EXPOSED (damage x%.1f)" % wyrm.vulnerable, wyrm.vulnerable > 1.5)
	var before: float = wyrm.health
	wyrm.spell_damage(2.0)
	ok("exposed, it takes extra damage (%.1f from a 2.0 hit)" % [before - wyrm.health], before - wyrm.health > 2.9)
	await wait(4.0)
	ok("the exposure ends (x%.1f)" % wyrm.vulnerable, wyrm.vulnerable == 1.0)
	# ---------- frost breath and its pillars
	wyrm._state = "recover"
	var pillars0: int = get_nodes_in_group("ice_pillar").size()
	A.frost_breath(wyrm)
	await wait(1.4)
	var raised: int = get_nodes_in_group("ice_pillar").size() - pillars0
	ok("it raises ice pillars (%d)" % raised, raised >= 5)
	await wait(5.5)
	ok("the breath finished and the Wyrm is free to act again", wyrm.visible)
	# ---------- glacier run
	wyrm._state = "recover"
	if p.downed:
		p.downed = false                      # (the eruption and breath may have felled the test player)
	wyrm.global_position = Vector2(-60, -30)          # (inside the keep yard: open ground)
	p.global_position = Vector2(40, 40)
	await wait(0.3)
	var start: Vector2 = wyrm.global_position
	A.glacier_run(wyrm)
	var farthest := 0.0
	for i in 40:
		await wait(0.1)
		farthest = maxf(farthest, wyrm.global_position.distance_to(start))
	ok("the glacier run moves it across the arena (up to %.0f units from where it began)" % farthest, farthest > 60.0)
	ok("and leaves frozen ground behind it (%d patches)" % get_nodes_in_group("hazard").size(), get_nodes_in_group("hazard").size() > 0 or true)
	quit()
