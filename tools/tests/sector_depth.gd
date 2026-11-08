extends SceneTree
# Sector depth: hazards, native enemy mixes, boss intro, volley and quake attacks.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func count_script(world, suffix: String) -> int:
	var n := 0
	for c in world.find_children("*", "", true, false):
		if c.get_script() and str(c.get_script().resource_path).ends_with(suffix):
			n += 1
	return n
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
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	var by_kind := {}
	for h in get_nodes_in_group("hazard"):
		by_kind[h.kind] = by_kind.get(h.kind, 0) + 1
	print("hazards built: ", by_kind)

	# --- hazard effects
	var slow_h = null; var burn_h = null; var heal_h = null
	for h in get_nodes_in_group("hazard"):
		if h.kind == "slow" and slow_h == null: slow_h = h
		if h.kind == "burn" and burn_h == null: burn_h = h
		if h.kind == "heal" and heal_h == null: heal_h = h
	print("slow_at inside a quicksand patch: ", get_nodes_in_group("hazard")[0].slow_at(self, slow_h.global_position), " | outside: ", slow_h.slow_at(self, Vector2(0, 0)))
	var hp = world.get_node("Hud/Control2/ColorRect/Health")
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]      # open every gate (no natives) so the player can stand in each sector
	for sid in ["se", "ne", "n", "nw", "sw"]:
		sm._wake(sid)      # sectors sleep until unlocked; wake them like unlock() does
	player.shield_time = 0.0
	player.position = burn_h.global_position
	var hp0 = hp.size.x
	await wait(2.6)
	print("standing in lava: health ", hp0, " -> ", hp.size.x, " (burns)")
	player.is_taking_damage = false
	player.position = heal_h.global_position
	var hp1 = hp.size.x
	await wait(2.0)
	print("standing in a crystal shrine: health ", hp1, " -> ", hp.size.x, " (heals)")
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = burn_h.global_position
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	player.position = Vector2(0, 30)
	await wait(2.2)
	print("enemy in lava lost ", snapped(10.0 - e.health, 0.1), " hp")

	# --- native mixes (start again from a single open sector so unlock() runs for real)
	game.sectors_unlocked = ["s"]
	for id in ["se", "ne", "n", "nw", "sw"]:
		var before := {}
		for k in ["scarab", "spitter", "splitter", "runner", "brute"]:
			before[k] = count_script(world, "/%s.gd" % k)
		sm.unlock(id)
		await wait(0.2)
		var added := []
		for k in ["scarab", "spitter", "splitter", "runner", "brute"]:
			var d = count_script(world, "/%s.gd" % k) - before[k]
			if d > 0: added.append("%d %s" % [d, k])
		print("unlocking ", id, " spawns natives: ", ", ".join(added))

	# --- boss intro, volley, quake
	var boss = sm._bosses["se"]
	player.shield_time = 9999.0
	player.position = boss.position + Vector2(0, -120)
	await wait(0.3)
	print("boss intro: state ", boss._state, " awake ", boss.awake)
	await wait(1.6)
	print("after the intro: state ", boss._state)
	boss.attacks = ["volley"]
	boss._timer = 0.0
	await wait(2.2)
	var globs := count_script(world, "enemy_projectile.gd")
	print("volley fired projectiles: ", globs, " (alive)")
	player.shield_time = 0.0
	boss.attacks = ["quake"]
	boss._timer = 0.0
	boss._state = "chase"
	var hp2 = hp.size.x
	for i in 40:
		# stand where the middle ring passes (radius = body_radius * 2.9)
		player.position = boss.position + Vector2(boss.body_radius * 2.9, 0)
		player.is_taking_damage = false
		await wait(0.1)
	print("quake rings hurt a player standing on them: health ", hp2, " -> ", hp.size.x)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
