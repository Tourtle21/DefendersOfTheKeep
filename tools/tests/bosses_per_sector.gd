extends SceneTree
## Every boss arrives only with the fifth wave of its own sector, never as soon as the sector opens; the wave countdown is fed.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func boss_of(id: String):
	for b in get_nodes_in_group("boss"):
		if b.sector_id == id: return b
	return null
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://bps_test_save.json"
	game._menu_done = true
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var sm = world.get_node_or_null("SectorManager")
	if sm == null:
		for c in world.get_children():
			if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	await wait(0.3)
	print("  countdown text: '%s'" % game.wave_timer_text())
	ok("the wave countdown is fed (%s)" % game.wave_timer_text(), game.wave_eta_s > 0 and game.wave_timer_text().contains("wave 1 in"))
	var order := ["s", "se", "ne", "n", "nw", "sw"]
	for i in order.size():
		var id: String = order[i]
		if i > 0:
			sm.unlock(id)                        # the previous boss was beaten: this sector opens
			await wait(0.2)
		var boss = boss_of(id)
		ok("%s: the boss is NOT there when its sector opens (hidden %s, enemy %s, hitbox %d)" % [id, !boss.visible, boss.is_in_group("enemy"), boss.collision_layer], !boss.visible and !boss.is_in_group("enemy") and boss.collision_layer == 0)
		ok("%s: waves in the sector reset to 0 (%d)" % [id, world.waves_in_sector], world.waves_in_sector == 0)
		for w in 4:
			world.spawn_enemies([], [])
			for e in world.get_node("Enemies").get_children():
				if !(e.is_in_group("boss")): e.queue_free()
		ok("%s: after four waves he is still away" % id, !boss.visible)
		world.spawn_enemies([], [])
		await wait(0.2)
		ok("%s: the fifth wave brings him in" % id, boss.visible and boss.is_in_group("enemy") and boss.collision_layer == 2)
		for e in world.get_node("Enemies").get_children():
			if !(e.is_in_group("boss")): e.queue_free()
	quit()
