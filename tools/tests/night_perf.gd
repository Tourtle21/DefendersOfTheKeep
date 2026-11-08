extends SceneTree
# Window test: frame rate at day vs night with many enemies and many lights.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func fps_over(secs: float) -> float:
	var frames0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await wait(secs)
	return (Engine.get_frames_drawn() - frames0) * 1000.0 / (Time.get_ticks_msec() - t0)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta.hints_enabled = false
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	var player = world.get_node("Player")
	player.global_position = Vector2(0, 150)
	var names := ["blobbert", "goblin", "brute", "scarab", "runner"]
	for i in 220:
		var n: String = names[i % names.size()]
		var e = load("res://enemies/%s/%s.tscn" % [n, n]).instantiate()
		e.position = Vector2(randf_range(-160, 160), randf_range(190, 330))
		world.get_node("Enemies").add_child(e)
	var lights := []
	for i in 45:
		var l = load("res://world/light_source.gd").new()
		l.position = Vector2(-150 + (i % 15) * 22, 175 + (i % 3) * 30)
		l.light_radius = 70.0
		l.life = 0.0
		world.add_child(l)
		lights.append(l)
	game.mana = 100
	world.clock = 20.0
	await wait(2.0)
	var day := await fps_over(3.0)
	world.clock = 230.0
	await wait(1.5)
	var night := await fps_over(3.0)
	print("FPS with 220 enemies and 45 lights: day %.0f | night %.0f (%.0f%% of day)" % [day, night, 100.0 * night / day])
	quit()
