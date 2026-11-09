extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(900.0)
	var player = world.get_node("Player")
	game.announce.connect(func(t): print("   announce: ", t))
	player.global_position = Vector2(45, 110)
	Input.action_press("move_down")
	for i in 110:
		await wait(0.25)
		var col := ""
		for k in player.get_slide_collision_count():
			col += str(player.get_slide_collision(k).get_collider().name) + " "
		game.announce.connect(func(t): pass) if false else null
		if i % 4 == 0: print("t=%.2f pos %s vel %s hits %s" % [i * 0.25, player.global_position.round(), player.velocity.round(), col])
	quit()
