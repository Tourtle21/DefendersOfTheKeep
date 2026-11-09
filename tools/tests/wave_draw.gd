extends SceneTree
# The wave draw plays itself: every outcome is valid and explained; the next wave waits for the last one to be beaten;
# the first boss sleeps until wave 3; the interact key is E.
var fails := 0
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if !ok: fails += 1
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var up = world.get_node("Upgrades")
	# 1. the draw, many times: always at least one enemy, always an account of it
	var bad := 0
	var kinds := {}
	for i in 400:
		var r: Dictionary = up.auto_pick()
		if r.enemies.is_empty() or r.lines.size() < 2: bad += 1
		kinds[r.lines[0]] = true
	check(bad == 0, "400 draws all give enemies and an explanation (%d distinct draws seen)" % kinds.size())
	check(kinds.size() > 3, "the draw varies")
	var sample: Dictionary = up.auto_pick()
	print("   e.g. ", " | ".join(sample.lines))
	# 2. the wave announces itself
	var said := []
	game.announce.connect(func(t): said.append(t))
	world.night_wave = false
	world.get_node("SpawnTimer").start(0.3)          # the real first-wave path
	await wait(0.8)
	world.get_node("SpawnTimer").start(3.0)          # the wave director sets 40 s+: shorten it for the test
	check(said.any(func(t): return "wave 1 starts" in t.to_lower()), "announce says the wave starts: %s" % (said[0] if said.size() > 0 else "-"))
	check(world._banner._title.modulate.a > 0.0 and "STARTS" in world._banner._title.text, "big banner shows: %s" % world._banner._title.text)
	check(!world.get_tree().paused, "no card screen pauses the game")
	# 3. the next wave waits while enemies from the last are alive
	var alive: int = world._wave_alive()
	check(alive > 0, "wave 1 has %d enemies alive" % alive)
	await wait(6.0)                                  # the timer (3 s) has fired
	check(game.run_stats.waves == 1, "wave 2 has NOT started while wave 1 is alive (waves=%d)" % game.run_stats.waves)
	for e in world.get_node("Enemies").get_children(): e.queue_free()
	await wait(2.5)
	check(game.run_stats.waves == 2, "wave 2 starts once wave 1 is cleared (waves=%d)" % game.run_stats.waves)
	# 4. the first boss sleeps early on
	var boss = null
	for b in get_nodes_in_group("boss"):
		if b.sector_id == "s": boss = b
	var player = world.get_node("Player")
	player.global_position = boss.global_position + Vector2(0, -100)
	await wait(0.5)
	check(!boss.awake, "King Blobbert stays asleep early in the run (wave %d)" % game.run_stats.waves)
	game.run_stats.waves = 2
	world.spawn_enemies([], [])                      # wave 3 really starts (the boss arrives with it)
	await wait(0.5)
	check(boss.awake, "and wakes once wave 3 has begun")
	# 5. keys
	var key_ok := false
	for e in InputMap.action_get_events("interact"):
		if e is InputEventKey and e.physical_keycode == KEY_E: key_ok = true
	check(key_ok, "interact is on E")
	var switch_e := false
	for e in InputMap.action_get_events("switch_items"):
		if e is InputEventKey and e.physical_keycode == KEY_E: switch_e = true
	check(!switch_e, "switch weapon is no longer on E")
	print("wave_draw test: %s" % ("PASS" if fails == 0 else "%d FAILED" % fails))
	quit(fails)
