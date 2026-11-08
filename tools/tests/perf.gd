extends SceneTree
# Stress test: many enemies, hazards, turrets, coins, projectiles, keep UI + radar. Prints frame costs.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func measure(label: String, seconds: float) -> void:
	var proc := []
	var phys := []
	var fps := []
	var t := 0.0
	while t < seconds:
		await wait(0.25)
		t += 0.25
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		fps.append(Performance.get_monitor(Performance.TIME_FPS))
	var avg := func(a): 
		var s := 0.0
		for x in a: s += x
		return s / a.size()
	print("%-34s fps avg %5.1f min %5.1f | process %5.2f ms | physics %5.2f ms | nodes %d | draw calls %d" % [label, avg.call(fps), fps.min(), avg.call(proc), avg.call(phys), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(2.0)
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"):
			c.panel.visible = false
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	player.shield_time = 99999.0
	await measure("idle (baseline)", 3.0)
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	await measure("all sectors open, no enemies", 3.0)
	# a big wave: ~150 enemies, pulled in toward the keep
	game.run_stats.waves = 14
	world.spawn_enemies([{"name": "blobbert", "amount": 40, "level": 2}, {"name": "goblin", "amount": 30, "level": 2}])
	world.get_node("SpawnTimer").stop()
	await wait(0.3)
	for e in world.get_node("Enemies").get_children():
		e.position = e.position * 0.25
	print("enemies alive: ", get_nodes_in_group("enemy").size())
	await measure("%d enemies marching" % get_nodes_in_group("enemy").size(), 4.0)
	game.enter_base(player)
	player.base_zoom = 2.0
	game.mana = 100
	await measure("same + keep UI and radar open", 3.0)
	# coins and projectiles
	var coin = load("res://collectables/gold/gold_coin.gd")
	for i in 60:
		coin.spawn(world, Vector2(randf_range(-100, 100), randf_range(-100, 100)), 1)
	for i in 12:
		game.hand = ["fireball", "fireball", "frost_ring"]
		game.mana = 100
		game.cast("fireball", Vector2(randf_range(-80, 80), randf_range(100, 220)), player)
	await measure("+ 60 coins, spells, turret fire", 4.0)
	# costs of the newer systems
	var builder = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("nav_builder.gd"): builder = c
	var t0 := Time.get_ticks_usec()
	builder.rebuild_now()
	print("navigation bake (%d obstacles), blocking: %.1f ms" % [get_nodes_in_group("nav_obstacle").size(), (Time.get_ticks_usec() - t0) / 1000.0])
	var rep = root.get_node("Rep")
	var nets := get_nodes_in_group("net")
	t0 = Time.get_ticks_usec()
	var total_props := 0
	for n in nets:
		total_props += rep.state_of(n).size()
	var dt: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("co-op replication: reading the state of %d net nodes (%d values) takes %.2f ms per 0.1 s tick" % [nets.size(), total_props, dt])
	print("final: enemies ", get_nodes_in_group("enemy").size(), " hazards ", get_nodes_in_group("hazard").size(), " turrets ", get_nodes_in_group("turret").size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
