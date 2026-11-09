extends SceneTree
## Players 2-4 get a visible aimer that follows only their right stick (the left stick walks, it never aims).
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
	var p2 = lp.avatars[1]
	var mark = lp._aimers[1]
	await wait(0.3)
	ok("the aimer is shown to the right of player 2 by default", mark.visible and mark.global_position.x > p2.global_position.x + 30.0)
	axis(1, JOY_AXIS_RIGHT_Y, -1.0)
	await wait(0.4)
	ok("right stick up moves the aimer above the player", mark.global_position.y < p2.global_position.y - 30.0 and absf(mark.global_position.x - p2.global_position.x) < 5.0)
	axis(1, JOY_AXIS_RIGHT_Y, 0.0)
	axis(1, JOY_AXIS_LEFT_X, -1.0)
	await wait(2.0)
	ok("the left stick walks but never moves the aimer's direction", mark.global_position.y < p2.global_position.y - 30.0 and absf(mark.global_position.x - p2.global_position.x) < 5.0)
	axis(1, JOY_AXIS_LEFT_X, 0.0)
	quit()
