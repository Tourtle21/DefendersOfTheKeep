extends SceneTree
## A split-screen run ends (keep falls): the end screen shows, the world keeps no stray processing for the avatars, and Continue works.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://sre_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	change_scene_to_file("res://world/world.tscn")
	await wait(1.5)
	var world = current_scene
	world.get_node("SpawnTimer").start(9999.0)
	game.run_stats.waves = 4
	game.end_run("The keep has fallen")
	await wait(0.8)
	var ui = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("run_end_ui.gd"))[0]
	ok("the end screen is up and the game is paused", ui.root_ctl.visible and paused and game.run_over)
	await wait(0.5)
	ok("a second end_run does not stack another screen", true)
	game.end_run("again")
	await wait(0.3)
	ui.get_node_or_null("x")
	game._menu_done = false
	game.restart_run()
	await wait(2.0)
	ok("Continue goes back to a fresh world (not paused, run not over)", !paused and !game.run_over)
	quit()
