extends SceneTree
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var player = world.get_node("Player")
	for deg in [180, 165, 195, 150, 210, 135, 225, 0, 20, 340]:
		var dir := Vector2.RIGHT.rotated(deg_to_rad(deg))
		for mode in ["walk", "dash"]:
			player.global_position = dir * 100.0
			player.dash_time = 0.0
			await wait(0.3)
			var jumps := []
			var last: Vector2 = player.global_position
			var t := 0.0
			while t < 3.0:
				if mode == "dash" and int(t * 20) % 8 == 0:
					player.dash(dir, 110.0, 0.28)
				else:
					Input.action_press("move_left" if dir.x < 0 else "move_right")
				await wait(0.02)
				t += 0.02
				var p: Vector2 = player.global_position
				if p.distance_to(last) > 14.0:
					jumps.append("t=%.2f %s->%s" % [t, last.round(), p.round()])
				last = p
			for a in ["move_left", "move_right"]: Input.action_release(a)
			print("%3d deg %-4s ended %s dist %.0f jumps %s" % [deg, mode, player.global_position.round(), player.global_position.length(), jumps])
	quit()
