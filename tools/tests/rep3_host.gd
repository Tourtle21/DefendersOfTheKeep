extends SceneTree
# Late join: the host builds a busy world first, the client joins afterwards and must see all of it.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var net = root.get_node("Net")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	print("HOST: listening -> ", net.host_game())
	var sm = null
	for c in world.get_children():
		if c.get_script() and str(c.get_script().resource_path).ends_with("sector_manager.gd"): sm = c
	for id in ["se", "ne", "n"]: sm.unlock(id)
	var player = world.get_node("Player")
	game.enter_base(player)
	game.mana = 100
	game.resources = {"stone": 40, "stick": 40, "gold": 40, "iron": 10, "frost": 10, "ember": 10}
	for p in [["barricade", Vector2(40, 330)], ["sentry", Vector2(80, 330)], ["frost_totem", Vector2(120, 330)]]:
		game.hand = [p[0]]
		game.cast(p[0], p[1], player)
		await wait(1.1)
	world.spawn_enemies([{"name": "blobbert", "amount": 4, "level": 1}])
	game.keep_hp = 77.0
	game.run_stats.waves = 5
	await wait(3.0)           # the host runs alone for a while, no client yet
	var n := 0
	for x in get_nodes_in_group("net"):
		if !x.has_meta("net_puppet"): n += 1
	print("HOST: busy world before anyone joined: ", n, " net nodes, structures ", get_nodes_in_group("structure").size(), ", enemies ", get_nodes_in_group("enemy").size())
	for i in 60:
		await wait(0.5)
		if net.remote_players.size() > 0: break
	print("HOST: a late joiner arrived")
	await wait(14.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
