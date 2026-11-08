extends SceneTree
# Window test: the ambient sheep at the well next to a rainbow sheep, to compare size and look.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.hints_enabled = false
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("help_ui.gd"): c.panel.visible = false
	var player = world.get_node("Player")
	player.global_position = Vector2(-10, 30)
	var rs = load("res://collectables/sheep/rainbow_sheep.gd").new()
	rs.position = Vector2(-70, -18)
	world.add_child(rs)
	rs.set_physics_process(false)
	await wait(1.0)
	var sheep = world.get_node("Sheep")
	print("ambient sheep at ", sheep.global_position, " scale ", sheep.scale, " sprite scale ", sheep.get_node("Sprite2D").scale, " global ", sheep.get_node("Sprite2D").global_scale)
	print("rainbow sheep at ", rs.global_position, " sprite global scale ", rs._sprite.global_scale)
	var cam = player.get_node("Camera2D")
	cam.zoom = Vector2(3, 3)
	cam.global_position = Vector2(-55, 0)
	await wait(0.6)
	root.get_viewport().get_texture().get_image().save_png("user://sheep_compare.png")
	quit()
