extends SceneTree
# Co-op host side of the two-process test. Run together with net_client.gd (see README in this folder).
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
	# a few enemies for the snapshots, plus a frozen dummy where the client's spear can reach it
	world.spawn_enemies([{"name": "blobbert", "amount": 3, "level": 1}])
	world.get_node("SpawnTimer").stop()
	var dummy = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	dummy.position = Vector2(70, 0)
	world.get_node("Enemies").add_child(dummy)
	dummy.set_physics_process(false)
	dummy.get_node("NavigationTimer").stop()
	dummy.max_health = 30.0
	dummy.health = 30.0
	var start_pos = null
	for i in 20:
		await wait(1.0)
		if net.remote_players.size() > 0:
			var pl = net.remote_players.values()[0]
			if start_pos == null:
				start_pos = pl.global_position
				print("HOST: client joined, remote player spawned at ", start_pos, " holding ", pl.item.get("weapon_name") if pl.item != null else "nothing")
	var pl2 = net.remote_players.values()[0] if net.remote_players.size() > 0 else null
	print("HOST: remote players ", net.remote_players.size(), " | remote avatar moved from ", start_pos, " to ", pl2.global_position if pl2 else "-")
	print("HOST: dummy health after the client's attacks: ", snapped(dummy.health, 0.1), " of 30")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
