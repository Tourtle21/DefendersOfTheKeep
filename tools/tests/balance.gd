extends SceneTree
# Balance probe: a "keep-only" bot (casts cards, reloads turrets, repairs) with explorers' supplies
# delivered on a timer. Waves are pulled closer and spaced ~20s apart so a run fits in minutes.
# Usage: Godot --path . --script res://tools/tests/balance.gd [-- afk]   (afk = no bot actions)
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var afk := OS.get_cmdline_args().has("afk") or OS.get_cmdline_user_args().has("afk")
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	var player = world.get_node("Player")
	var up = world.get_node("Upgrades")
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"):
			c.panel.visible = false
	world.get_node("SpawnTimer").start(5.0)
	game.enter_base(player)
	player.is_in_tower = true
	var state := {"result": "", "t": 0.0}      # a dictionary: lambdas capture plain locals by value
	game.run_ended.connect(func(info):
		state.result = info.reason
		state.t = state.t)
	var seen := {}
	var t := 0.0
	var next_supply := 20.0
	var last_wave := 0
	var log := []
	var casts := {}
	while state.result == "" and t < 260.0:
		await wait(0.5)
		t += 0.5
		state.t = t
		# wave-choice screen: flip the first token and start
		if paused and up.visible:
			up.pick_token(0)
			await wait(0.05)
			up._on_button_pressed()
			up.visible = false
		if world.get_node("SpawnTimer").time_left > 20.0:
			world.get_node("SpawnTimer").start(20.0)
		for e in world.get_node("Enemies").get_children():
			if !seen.has(e):
				seen[e] = true
				e.position = e.position * 0.4
		if game.run_stats.waves != last_wave:
			last_wave = game.run_stats.waves
			log.append("wave %d at %3ds: keep %3d, kills %d, enemies alive %d" % [last_wave, int(t), int(game.keep_hp), game.run_stats.kills, world.get_node("Enemies").get_child_count()])
		if afk:
			continue
		# explorers deliver supplies
		if t >= next_supply:
			next_supply += 20.0
			game.resources.stone += 3
			game.resources.stick += 4
			game.resources_changed.emit()
		# keep upkeep
		if game.keep_hp < 110.0:
			game.repair_keep()
		for tur in get_nodes_in_group("turret"):
			if tur.ammo < 4:
				tur.reload()
		# cast the best affordable card at the enemy nearest the keep
		var nearest = null
		for e in world.get_node("Enemies").get_children():
			if is_instance_valid(e) and (nearest == null or e.global_position.length() < nearest.global_position.length()):
				nearest = e
		if nearest != null and nearest.global_position.length() < 260.0 and game.hand.size() > 0:
			var dir: Vector2 = nearest.global_position.normalized()
			var cast_id := ""
			var cast_pos: Vector2 = nearest.global_position
			# builds go in the enemies' path close to the keep, spells hit the nearest enemy
			for id in game.hand:
				if !game.can_cast(id):
					continue
				if game.CARDS[id].kind == "build":
					if cast_id == "" or (game.CARDS[cast_id].kind != "build" and cast_id != "fireball"):
						cast_id = id
						cast_pos = dir * (60.0 if id in ["barricade", "spike_trap"] else 25.0)
				elif cast_id == "" or (id == "fireball" and game.CARDS[cast_id].kind != "build"):
					cast_id = id
					cast_pos = nearest.global_position
			if cast_id != "":
				if game.cast(cast_id, cast_pos, player):
					casts[cast_id] = casts.get(cast_id, 0) + 1
	var builds := get_nodes_in_group("structure").size()
	print("  casts by card: ", casts, " | structures standing at the end: ", builds)
	print(("AFK keep-sitter" if afk else "keep-only bot"), ": ", ("%s at %ds" % [state.result, int(state.t)]) if state.result != "" else "still standing at %ds" % int(t), " | waves ", game.run_stats.waves, " | kills ", game.run_stats.kills, " | keep hp ", int(game.keep_hp))
	for l in log:
		print("  ", l)
	print("  state at end: time_scale ", Engine.time_scale, " paused ", paused, " token screen visible ", up.visible, " spawn timer left ", snapped(world.get_node("SpawnTimer").time_left, 0.1), " stopped ", world.get_node("SpawnTimer").is_stopped())
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
