extends SceneTree
# Waves grow with the number of players (checked without networking by adding a stand-in player).
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await create_timer(1.0, true, false, true).timeout
	world.get_node("SpawnTimer").start(600.0)
	var picked = [{"name": "blobbert", "amount": 2, "level": 1}]
	for w in [1, 3, 6, 9]:
		game.run_stats.waves = w
		var one := 0
		for e in world.wave_plan(picked):
			one += e.amount
		var extra = Node2D.new()
		extra.add_to_group("player")
		world.add_child(extra)
		var two := 0
		for e in world.wave_plan(picked):
			two += e.amount
		var extra2 = Node2D.new()
		extra2.add_to_group("player")
		world.add_child(extra2)
		var three := 0
		for e in world.wave_plan(picked):
			three += e.amount
		print("wave %d: 1 player %2d enemies | 2 players %2d | 3 players %2d" % [w, one, two, three])
		extra.free()
		extra2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
