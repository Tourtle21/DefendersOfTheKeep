extends SceneTree
func _initialize() -> void:
	var game = root.get_node("Game")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await create_timer(0.5, true, false, true).timeout
	game.hit_stop(0.3)
	await create_timer(0.1, true, false, true).timeout
	print("mid hit-stop time scale: ", Engine.time_scale)
	await create_timer(0.4, true, false, true).timeout
	print("after: ", Engine.time_scale)
	# and a real heavy hit through the weapon helper
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = Vector2(0, 300)
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	var util = load("res://items/weapons/weapon_util.gd")
	util.hit(e, 6.0, Vector2(0, 280))
	await create_timer(0.02, true, false, true).timeout
	print("scale right after a 6-damage hit: ", Engine.time_scale)
	await create_timer(0.3, true, false, true).timeout
	print("restored: ", Engine.time_scale)
	quit()
