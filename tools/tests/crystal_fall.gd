extends SceneTree
## A player (split-screen player 2 here) who falls while carrying the crystal drops it where they fell; it is not counted as returned.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://cf2_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p2 = lp.avatars[1]
	var crystal = world.get_node("Well/Crystal")
	p2.global_position = Vector2(200, 200)
	crystal._pickup(p2)
	await wait(0.2)
	ok("player 2 carries the crystal (%s)" % crystal.state, crystal.state == "player" and p2.has_crystal)
	p2.take_damage(Vector2(900, 900), 9999.0)
	await wait(0.4)
	print("  crystal state %s at %s, p2 has_crystal %s downed %s" % [crystal.state, crystal.global_position, p2.has_crystal, p2.downed])
	ok("the crystal dropped where they fell, not returned home", crystal.state == "dropped" and crystal.global_position.distance_to(Vector2(200, 200)) < 40.0)
	ok("they no longer count as carrying it", !p2.has_crystal)
	await wait(1.0)
	ok("a downed player cannot pick it straight back up", crystal.state == "dropped")
	quit()
