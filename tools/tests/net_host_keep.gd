extends SceneTree
# Co-op host for the keep test (run with net_client_keep.gd).
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
	game.resources = {"stone": 10, "stick": 4, "gold": 10}
	game.keep_hp = 100.0
	game.mana = 100.0
	game.hand = ["fireball", "fireball", "frost_ring"]
	var dummy = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	dummy.position = Vector2(0, 230)
	world.get_node("Enemies").add_child(dummy)
	dummy.set_physics_process(false)
	dummy.get_node("NavigationTimer").stop()
	dummy.max_health = 30.0
	dummy.health = 30.0
	var seen_split := false
	for i in 26:
		await wait(1.0)
		if net.remote_players.size() > 0:
			var pl = net.remote_players.values()[0]
			if pl.is_in_tower and !seen_split:
				seen_split = true
				print("HOST: client is in the keep -> Game.in_base ", game.in_base, ", host's own keep UI (local_in_base) ", game.local_in_base(), " | host can still attack: ", !game.local_in_base())
	print("HOST: dummy hp after the client's fireball: ", snapped(dummy.health, 0.1), " of 30")
	print("HOST: keep hp ", game.keep_hp, " (was 100, repaired +30) | resources ", game.resources, " | upgrades ", game.upgrade_levels, " | hand ", game.hand, " | client still in keep: ", net.remote_players.size() > 0 and net.remote_players.values()[0].is_in_tower)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
