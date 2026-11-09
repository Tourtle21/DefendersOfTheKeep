extends SceneTree
## Split screen, keyboard + mouse player 1 in a tower: a card cast at the mouse lands where the mouse is in player 1's view.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	var pad = root.get_node("Pad")
	game.save_path = "user://ca_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var split = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("split_screen.gd"))[0]
	var bui = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("base_ui.gd"))[0]
	var vp: SubViewport = split.viewports[0]
	var box: Control = split.containers[0]
	var p1 = world.get_node("Player")
	# (a pushed mouse event does not move the headless window's pointer, so compare the two conversions at wherever it is)
	var want: Vector2 = vp.get_canvas_transform().affine_inverse() * pad.screen_mouse(root)
	var got: Vector2 = bui._world_mouse()
	print("  want %s got %s main-camera transform would give %s" % [want, got, root.get_canvas_transform().affine_inverse() * pad.screen_mouse(root)])
	ok("the card cast point uses player 1's view, like the sword", got.distance_to(want) < 0.01 and got.distance_to(pad.world_mouse(p1)) < 0.01)
	quit()
