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
	for p in [Vector2(-118, 20), Vector2(0, 0)]:
		player.global_position = p
		await wait(0.6)
		root.get_viewport().get_texture().get_image().save_png("/tmp/edge_%d.png" % int(p.x))
	quit()
