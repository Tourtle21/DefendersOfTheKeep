extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var player = world.get_node("Player")
	var P := Vector2(-40, 260)
	player.position = P
	var hp = world.get_node("Hud/Control2/ColorRect/Health")
	# --- spitter
	var sp = load("res://enemies/spitter/spitter.tscn").instantiate()
	sp.position = P + Vector2(100, 0)
	world.get_node("Enemies").add_child(sp)
	sp.get_node("NavigationTimer").stop()
	var globs := 0
	var hp0 = hp.size.x
	for i in 60:
		await wait(0.1)
		for c in world.get_children():
			if c.get_script() and str(c.get_script().resource_path).ends_with("enemy_projectile.gd"):
				globs = max(globs, 1)
		player.position = P      # stand still in its sights
	print("spitter fired at the player: ", globs > 0, " | player health bar ", hp0, " -> ", hp.size.x, " (hit by globs)")
	if is_instance_valid(sp): sp.queue_free()
	await wait(0.2)
	# --- splitter
	var spl = load("res://enemies/splitter/splitter.tscn").instantiate()
	spl.position = P + Vector2(60, 0)
	world.get_node("Enemies").add_child(spl)
	spl.set_physics_process(false)
	spl.get_node("NavigationTimer").stop()
	spl.spell_damage(999)
	await wait(0.4)
	var minis := 0
	for e in world.get_node("Enemies").get_children():
		if str(e.get_script().resource_path).ends_with("splitter_mini.gd"): minis += 1
	print("splitter burst into minis: ", minis, " | kills counted so far: ", game.run_stats.kills)
	# --- wave plan
	game.run_stats.waves = 6
	var plan = world.wave_plan([{"name": "blobbert", "amount": 2, "level": 1}])
	var names := []
	for e in plan: names.append("%d %s" % [e.amount, e.name])
	print("wave 6 plan: ", ", ".join(names))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
