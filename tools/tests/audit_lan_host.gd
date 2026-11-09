extends SceneTree
# Host for audit_lan_client.gd: walks the joined client's avatar to the Card Fuser, the Forge and into a tower, one stop every ~7 s.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://audit_lan_save.json"
	game._menu_done = true
	var net = root.get_node("Net")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(9999.0)
	game.resources = {"stone": 30, "stick": 20, "gold": 25}
	game.hand = ["torch", "sentry", "fireball", "frost_ring", "barricade"]
	print("HOST: listening -> ", net.host_game())
	for i in 80:
		await wait(0.5)
		if net.remote_players.size() > 0: break
	var pl = net.remote_players.values()[0]
	await wait(3.0)
	net.give_weapon(pl, "spear")
	await wait(3.0)
	pl.global_position = net.CARD_FUSER_POS + Vector2(8, 0)
	print("HOST: avatar at the Card Fuser")
	await wait(7.0)
	pl.global_position = net.FORGE_POS + Vector2(8, 0)
	print("HOST: avatar at the Forge")
	await wait(7.0)
	pl.global_position = game.all_towers()[1].global_position + Vector2(0, 14)
	net._set_base(pl, true)
	print("HOST: avatar in a tower")
	await wait(8.0)
	quit()
