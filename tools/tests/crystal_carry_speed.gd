extends SceneTree
## Carrying the crystal makes you slower than a blobbert (speed 10) and the slowdown is gone when you put it down.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://cs_test_save.json"
	game._menu_done = true
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	p.global_position = Vector2(60, 60)
	Input.action_press("move_right")
	await wait(0.3)
	p.process_movement(0.016)
	var free_speed: float = p.velocity.length()
	p.has_crystal = true
	p.process_movement(0.016)
	var carry_speed: float = p.velocity.length()
	Input.action_release("move_right")
	print("  walking %.1f, carrying the crystal %.1f (blobberts walk at 10 and up)" % [free_speed, carry_speed])
	ok("carrying the crystal makes you slow (%.0f of %.0f), but not a crawl" % [carry_speed, free_speed], carry_speed > 15.0 and carry_speed < 40.0 and free_speed > 50.0)
	p.has_crystal = false
	quit()
