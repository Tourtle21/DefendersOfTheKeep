extends SceneTree
## The real flow: the world is built first (menu up, no devices), then the lobby picks keyboard + a controller and starts.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://sl_test_save.json"
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var count := func(): return world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd")).size()
	ok("world built with no devices: no split screen yet", count.call() == 0)
	game._local_devices = [-1, 1]                 # keyboard + controller 2, as the lobby would set
	world.start_split_screen()
	world.start_split_screen()                    # a second call must not build another
	await wait(0.5)
	ok("keyboard + controller: exactly one split screen", count.call() == 1)
	var split = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd"))[0]
	ok("two views", split.viewports.size() == 2 and split.containers[0].size.x < root.get_visible_rect().size.x)
	ok("two players", game.player_count() == 2)
	quit()
