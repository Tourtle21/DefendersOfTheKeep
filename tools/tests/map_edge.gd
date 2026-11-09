extends SceneTree
## Nobody walks off the map: players stop at the edge of the sector cones, and an enemy chasing a player at the edge stays on the map.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://me_test_save.json"
	game._menu_done = true
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var SM = load("res://world/sector_manager.gd")
	ok("the playable outline matches the sector manager's", game.SECTOR_OUTLINE == SM.OUTLINE)
	ok("the keep yard and the open grassland are playable", game.in_playable(Vector2(0, 0)) and game.in_playable(Vector2(0, 500)))
	ok("beside the grassland cone and inside a locked sector is not", !game.in_playable(Vector2(-400, 300)) and !game.in_playable(Vector2(500, 600)))
	var p = world.get_node("Player")
	p.global_position = Vector2(-60, 300)
	await wait(0.3)
	Input.action_press("move_left")
	await wait(4.0)
	Input.action_release("move_left")
	print("  walked left from x=-60: now %s" % p.global_position.round())
	ok("walking left stops at the edge of the grassland (x %.0f), still on the map" % p.global_position.x, game.in_playable(p.global_position) and p.global_position.x > -200.0)
	Input.action_press("move_down")
	Input.action_press("move_left")
	await wait(5.0)
	Input.action_release("move_down")
	Input.action_release("move_left")
	ok("walking down-left along the edge slides and stays on the map %s" % str(p.global_position.round()), game.in_playable(p.global_position) and p.global_position.y > 400.0)
	# a chasing enemy at the edge
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = p.global_position + Vector2(40, 0)
	world.get_node("Enemies").add_child(e)
	p.global_position = Vector2(-60, 300)
	var edge := Vector2(-150, 300)
	e.global_position = Vector2(-120, 300)
	p.global_position = edge                     # the player stands right at the edge; the enemy is chasing from inside
	e.start_aggro(p)
	await wait(3.0)
	ok("the chasing enemy stays on the map (%s)" % str(e.global_position.round()), game.in_playable(e.global_position))
	quit()
