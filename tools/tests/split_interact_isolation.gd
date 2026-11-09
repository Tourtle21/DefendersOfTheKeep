extends SceneTree
## Player 2 standing at a chest / tower door / pickup must not make player 1's interact button act on it.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://ii_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	p1.global_position = Vector2(300, 300)
	# a chest next to player 2 only
	var chest = load("res://collectables/chest/chest.gd").new()
	chest.position = Vector2(150, 150)
	world.add_child(chest)
	p2.global_position = Vector2(150, 150)
	await wait(0.5)
	ok("player 2 beside a chest does not make it hoverable for player 1", !chest.hovering)
	p1.global_position = Vector2(152, 150)
	await wait(0.5)
	ok("player 1 beside it does", chest.hovering)
	p2.global_position = Vector2(600, 600)
	await wait(0.5)
	ok("player 2 walking away does not take that away from player 1", chest.hovering)
	# a tower door
	var door = game.all_towers()[1].get_node("EnterArea")
	p1.global_position = Vector2(300, 300)
	p2.global_position = game.all_towers()[1].global_position + Vector2(0, 14)
	await wait(0.5)
	ok("player 2 at a tower door opens the door but not for player 1's button", !door.open)
	p1.global_position = game.all_towers()[1].global_position + Vector2(0, 14)
	p2.global_position = Vector2(600, 600)
	await wait(0.5)
	ok("player 1 at the door can use it", door.open)
	quit()
