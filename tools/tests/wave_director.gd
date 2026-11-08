extends SceneTree
# The real wave director, sped up: a bot flips a token and presses Start each time the wave screen appears.
# Logs the game-clock time of every wave, its kind and size, and how far apart they are.
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await create_timer(1.0, true, false, true).timeout
	Engine.time_scale = 20.0
	var up = world.get_node("Upgrades")
	var log := []
	var last_waves := 0
	var elapsed := 0.0
	var start_clock: float = world.clock
	var first_screen := -1.0
	while elapsed < 1000.0 and log.size() < 8:
		await create_timer(0.05, true, false, true).timeout
		elapsed += 0.05 * Engine.time_scale
		if up.visible and !up.get_node("Control/Button").visible and !up.finished:
			if first_screen < 0.0: first_screen = world.clock
			up.pick_token(0)
		if up.visible and up.get_node("Control/Button").visible:
			up._on_button_pressed()
		if game.run_stats.waves != last_waves:
			last_waves = game.run_stats.waves
			var n := 0
			for e in get_nodes_in_group("enemy"):
				if is_instance_valid(e) and !e.is_in_group("boss"): n += 1
			log.append("wave %d at clock %.0f s (%s), %d enemies" % [last_waves, world.clock, "night" if game.night_wave_now else "day", n])
			for e in get_nodes_in_group("enemy"):
				if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()      # keep the bot's world light
	Engine.time_scale = 1.0
	print("first wave screen at clock ", snappedf(first_screen, 1.0), " s (setup time)")
	for l in log: print(l)
	var gaps := []
	var prev := -1.0
	for l in log:
		var c := float(l.get_slice("clock ", 1).get_slice(" s", 0))
		if prev >= 0.0: gaps.append(snappedf(c - prev, 1.0))
		prev = c
	print("gaps between waves: ", gaps)
	quit()
