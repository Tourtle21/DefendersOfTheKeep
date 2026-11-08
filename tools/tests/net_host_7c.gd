extends SceneTree
# Co-op host for the lobby + per-player carry test (run with net_client_7c.gd).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var net = root.get_node("Net")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	print("HOST: listening -> ", net.host_game())
	net.lobby = true
	var timer = world.get_node("SpawnTimer")
	timer.paused = true
	timer.start(4.0)       # would fire after 4s, but the lobby holds it
	for spec in [["stone", Vector2(30, 5)]]:
		var c = load("res://collectables/collectable.tscn").instantiate()
		c.item_type = spec[0]
		c.position = spec[1]
		world.add_child(c)
	load("res://collectables/gold/gold_coin.gd").spawn(world, Vector2(30, 0), 1)
	game.resources = {"stone": 0, "stick": 0, "gold": 0}
	for i in 30:
		await wait(1.0)
		if i == 9:
			print("HOST: after 10s in the lobby: waves started ", game.run_stats.waves, " (0 = lobby is holding them), timer paused ", timer.paused)
			net.start_game()
			print("HOST: Start pressed -> lobby ", net.lobby, ", timer paused ", timer.paused)
	print("HOST: the host's own carried load untouched: ", game.carried, " | keep pool now: ", game.resources)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
