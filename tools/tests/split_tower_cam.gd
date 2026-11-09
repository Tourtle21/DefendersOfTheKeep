extends SceneTree
## Player 2 goes into a tower on a controller: nobody's camera should shake or jump, and zoom follows ui_scale.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func tap(dev: int, b: int) -> void:
	var e := InputEventJoypadButton.new()
	e.device = dev; e.button_index = b; e.pressed = true
	Input.parse_input_event(e)
	await wait(0.1)
	e = InputEventJoypadButton.new()
	e.device = dev; e.button_index = b; e.pressed = false
	Input.parse_input_event(e)
	await wait(0.1)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://tc_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var split = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd"))[0]
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	var t = game.all_towers()[0]
	p2.global_position = t.global_position + Vector2(0, 25)
	await wait(0.3)
	var maxoff := [0.0, 0.0]
	var zoom0: Array = [split.cameras[0].zoom, split.cameras[1].zoom]
	var pos0: Array = [split.cameras[0].global_position, split.cameras[1].global_position]
	await tap(1, JOY_BUTTON_A)
	var trace := []
	for i in 90:
		await wait(0.016)
		for s in 2:
			maxoff[s] = maxf(maxoff[s], split.cameras[s].offset.length())
		trace.append([split.cameras[1].global_position, p2.global_position, split.cameras[1].zoom.x, p2.get_node("Camera2D").position])
	for i in [0, 1, 2, 3, 10, 30, 60, 89]:
		print("  t%d cam2 %s p2 %s zoom %.3f pcamlocal %s" % [i, trace[i][0], trace[i][1], trace[i][2], trace[i][3]])
	print("  p2 in tower: %s; camera offsets seen: %s; zoom before %s after %s" % [p2.is_in_tower, maxoff, zoom0, [split.cameras[0].zoom, split.cameras[1].zoom]])
	print("  p1 camera pos %s -> %s, p1 base_zoom %s, p1 in tower %s" % [pos0[0], split.cameras[0].global_position, p1.base_zoom, p1.is_in_tower])
	var steady := true
	for t in trace:
		if t[0].distance_to(trace[0][0]) > 0.01:
			steady = false
	ok("player 2's view holds still for 90 frames in the tower (it flipped +-0.5 every frame before)", steady)
	ok("player 2 is in the tower", p2.is_in_tower)
	ok("no camera shake for anybody", maxoff[0] < 0.01 and maxoff[1] < 0.01)
	ok("player 1's camera and zoom did not change", split.cameras[0].zoom == zoom0[0] and split.cameras[0].global_position.distance_to(pos0[0]) < 5.0 and !p1.is_in_tower)
	quit()
