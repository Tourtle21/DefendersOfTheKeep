extends SceneTree
## Players 2-4 get a yellow aimer drawn in their own view only; only their right stick moves it (the left stick walks).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func axis(dev: int, a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = dev; e.axis = a; e.axis_value = v
	Input.parse_input_event(e)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://am_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var split = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd"))[0]
	var p2 = lp.avatars[1]
	await wait(0.3)
	var pt: Vector2 = lp.aim_world_point(1)
	ok("by default the aimer is to the right of player 2", pt.x > p2.global_position.x + 30.0 and absf(pt.y - p2.global_position.y) < 1.0)
	var aimer: Control = split._corner[1].aimer
	ok("it is drawn in player 2's own view (not in the shared world)", aimer.get_parent().get_parent().custom_viewport == split.viewports[1] and aimer.is_visible_in_tree())
	axis(1, JOY_AXIS_RIGHT_Y, -1.0)
	await wait(0.4)
	pt = lp.aim_world_point(1)
	ok("right stick up moves it above the player", pt.y < p2.global_position.y - 30.0 and absf(pt.x - p2.global_position.x) < 5.0)
	axis(1, JOY_AXIS_RIGHT_Y, 0.0)
	axis(1, JOY_AXIS_LEFT_X, -1.0)
	await wait(2.0)
	pt = lp.aim_world_point(1)
	ok("the left stick walks but never moves the aimer's direction", pt.y < p2.global_position.y - 30.0 and absf(pt.x - p2.global_position.x) < 5.0)
	axis(1, JOY_AXIS_LEFT_X, 0.0)
	quit()
