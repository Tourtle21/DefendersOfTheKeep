extends SceneTree
# Co-op gaps: a client uses a generator with its own loot; the host restarts the run and clients get avatars back.
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
	for i in 40:
		await wait(0.5)
		if net.remote_players.size() > 0: break
	await wait(1.0)
	if net.remote_players.is_empty():
		print("HOST: no client joined (start rep2_client after the host); nothing to check")
		quit()
		return
	var pl = net.remote_players.values()[0]
	var gen = null
	for g in get_nodes_in_group("generator"):
		if g.resource == "stone": gen = g
	pl.global_position = gen.global_position + Vector2(0, 8)
	pl.carried = {"gold": 10, "stone": 0, "stick": 0}
	game.resources = {"gold": 10, "stone": 10, "stick": 10}          # generators are paid from the keep's stores
	print("HOST: avatar next to the stone generator with 10 gold; generator level ", gen.level)
	var t := 0.0
	while gen.level == 0 and t < 20.0:
		await wait(0.25)
		t += 0.25
	print("HOST: after the client's interact: generator level ", gen.level, " | avatar gold left ", pl.carried.get("gold"), " | host's own carried gold untouched: ", game.carried.get("gold", 0))
	gen.stored = 6
	t = 0.0
	while gen.stored > 0 and t < 20.0:
		await wait(0.25)
		t += 0.25
	print("HOST: after collecting: stored ", gen.stored, " | avatar stone ", pl.carried.get("stone", 0))
	# restart the run: a fresh world replaces the old one
	var old_id: int = net.remote_players.keys()[0]
	world.queue_free()
	await wait(0.3)
	var world2 = load("res://world/world.tscn").instantiate()
	root.add_child(world2)
	await wait(2.0)
	world2.get_node("SpawnTimer").start(600.0)
	print("HOST: after the restart: remote avatars ", net.remote_players.size(), " (same peer: ", net.remote_players.has(old_id), ") avatar in the new world: ", net.remote_players.size() > 0 and is_instance_valid(net.remote_players.values()[0]) and world2.is_ancestor_of(net.remote_players.values()[0]))
	await wait(10.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
