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
	for n in ["Tower", "Tower2", "Tower5", "Tower6", "Tower7", "Tower8"]:
		var tw = world.get_node(n)
		var area = tw.get_node("EnterArea") if tw.has_node("EnterArea") else null
		if area == null:
			print(n, " no EnterArea"); continue
		player.global_position = tw.global_position + Vector2(0, 30)
		await wait(0.2)
		area.open = true
		var ev := InputEventAction.new(); ev.action = "interact"; ev.pressed = true
		area._input(ev)
		await wait(0.3)
		var inside: Vector2 = player.global_position
		area._input(ev)
		var out0: Vector2 = player.global_position
		await wait(0.3)
		print("%s at %s: inside %s, right after exit %s, 0.3 s later %s" % [n, tw.global_position.round(), inside.round(), out0.round(), player.global_position.round()])
		area.open = false
	quit()
