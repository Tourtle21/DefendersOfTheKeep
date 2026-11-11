extends SceneTree
# Resource generators: activate (keep's stores pay), produce over time, collect all, upgrade; yield skills.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with('sector_manager.gd'): sm = c
	var gens := get_nodes_in_group("generator")
	var kinds := []
	for g in gens: kinds.append(g.resource)
	print("generators in the world: ", gens.size(), " resources ", kinds)
	var g = null
	for x in gens:
		if x.resource == "stone": g = x
	game.carried = {"stone": 0, "stick": 0, "gold": 0}
	game.resources = {"stone": 0, "stick": 0, "gold": 0}
	print("activate with an empty keep: ", g.use(), " level ", g.level)
	game.carried.gold = 50                  # what you carry does not pay any more
	print("activate with carried gold only: ", g.use(), " level ", g.level)
	game.resources = {"stone": 50, "stick": 50, "gold": 30}
	print("activate with 30 gold in the keep: ", g.use(), " level ", g.level, " keep gold left ", game.resources.gold)
	g.progress = g.interval() - 0.1
	await wait(0.5)
	print("stored after a tick: ", g.stored, " interval lvl1 ", g.interval(), " capacity ", g.capacity())
	g.stored = 5
	print("collect: ", g.use(), " carried stone ", game.carried.stone, " stored ", g.stored)
	game.carried.stone = 10
	game.resources = {"stone": 99, "stick": 99, "gold": 99}
	print("upgrade lvl1->2 (cost ", g.upgrade_cost(), "): ", g.use(), " level ", g.level, " interval ", g.interval(), " capacity ", g.capacity(), " keep gold left ", game.resources.gold)
	for i in 5:
		game.resources = {"stone": 99, "stick": 99, "gold": 99}
		g.use()
	print("after repeated upgrades: level ", g.level, " (max 5)")
	game.meta.skills = {"overclock": 4}
	print("interval at max with overclock 4: ", snapped(g.interval(), 0.01))
	# sector generators sleep until the sector opens and produce its resource
	var iron
	for x in gens:
		if x.resource == "iron": iron = x
	print("iron generator sleeping before unlock: ", iron.can_process() == false)
	sm.unlock("se")
	await wait(0.2)
	print("after unlocking the desert: processing ", iron.can_process())
	game.carried = {"gold": 10, "iron": 0}
	iron.use()
	print("iron generator activated: level ", iron.level)
	# yield skills
	game.meta.skills = {"prospector": 5, "deep_veins": 5}
	game.carried = {"stone": 0, "iron": 0, "gold": 0}
	for i in 1000:
		game.pick_up_resource("stone")
		game.pick_up_resource("iron")
	print("1000 stone and 1000 iron with prospector 5 (+50%) and deep veins 5 (+60%): stone ", game.carried.stone, " iron ", game.carried.iron)
	if DisplayServer.get_name() != "headless":
		var player = world.get_node("Player")
		player.global_position = g.global_position + Vector2(0, 20)
		await wait(0.5)
		g.hovering = true
		g.stored = 12
		await wait(0.3)
		root.get_viewport().get_texture().get_image().save_png("user://generator.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
