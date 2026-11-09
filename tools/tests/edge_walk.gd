extends SceneTree
# Walk the player outward in several directions and log every sudden jump in position, plus bosses that wake.
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
	for dir in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		player.global_position = Vector2(0, 30)
		await wait(0.3)
		var last: Vector2 = player.global_position
		var jumps := 0
		var maxd := 0.0
		var t := 0.0
		print("walking ", dir)
		while t < 14.0:
			Input.action_press("move_down" if dir == Vector2.DOWN else "move_up" if dir == Vector2.UP else "move_left" if dir == Vector2.LEFT else "move_right")
			await wait(0.05)
			t += 0.05
			var p: Vector2 = player.global_position
			if p.distance_to(last) > 12.0:
				jumps += 1
				print("   JUMP at t=%.2f from %s to %s" % [t, last.round(), p.round()])
			maxd = max(maxd, p.length())
			last = p
		for a in ["move_down", "move_up", "move_left", "move_right"]: Input.action_release(a)
		print("   max distance from keep %.0f, jumps %d, ended at %s, hp bar %s" % [maxd, jumps, player.global_position.round(), world.get_node("Hud/Control2/ColorRect/Health").size.x])
	for b in get_nodes_in_group("boss"):
		print("boss ", b.boss_name, " awake=", b.awake, " at ", b.global_position.round())
	quit()
