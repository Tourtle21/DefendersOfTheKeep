extends SceneTree
# Co-op host for the loot/forge test (run with net_client_loot.gd).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	game.meta = {"shards": 0, "unlocked": ["fireball", "frost_ring"], "best_wave": 0, "recipes_seen": []}
	var net = root.get_node("Net")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	game.unlocked_cards = ["fireball", "aegis", "gold_magnet"]
	game.resources = {"stone": 0, "stick": 0, "gold": 40}
	world.get_node("Player").position = Vector2(-100, -60)       # the host's own player is far away
	print("HOST: listening -> ", net.host_game())
	var chest = load("res://collectables/chest/chest.gd").new()
	chest.position = Vector2(30, 12)
	chest.kind = "card"
	world.add_child(chest)
	for spec in [["bow", Vector2(30, 0)], ["shield", Vector2(30, -8)]]:
		var c = load("res://collectables/collectable.tscn").instantiate()
		c.item_type = spec[0]
		c.position = spec[1]
		world.add_child(c)
	var checked := false
	for i in 28:
		await wait(1.0)
		if net.remote_players.size() > 0 and !checked and i >= 2:
			checked = true
			var pl = net.remote_players.values()[0]
			var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
			e.position = pl.global_position + Vector2(40, 30)
			world.get_node("Enemies").add_child(e)
			e.set_physics_process(false)
			var t = e._target_player()
			print("HOST: enemy near the client targets: ", t.name, " (the host's own player is far away) -> ", t == pl)
			e.queue_free()
	var pl2 = net.remote_players.values()[0] if net.remote_players.size() > 0 else null
	print("HOST: deck after the client's draft pick: ", game.deck)
	print("HOST: client weapon slots now: ", pl2.weapon_slots if pl2 else "(client left)", " | gold ", game.resources.gold, " (40 - 10 for the fusion) | recipes seen ", game.meta.recipes_seen)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
