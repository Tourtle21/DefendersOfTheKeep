extends SceneTree
# Co-op host side of the forge-storage test. Run together with net_forge_client.gd (see README in this folder):
#   Godot --headless --path . --script res://tools/tests/net_forge_host.gd &
#   Godot --headless --path . --script res://tools/tests/net_forge_client.gd
# The client drops a spear into the forge and combines two hammers (one held, one stored); the host checks the result.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("HOST PASS " if c else "HOST FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var net = root.get_node("Net")
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	game.resources.gold = 99
	game.resources.stone = 99
	game.resources.stick = 99
	game.note_weapon_tier("hammer", 2)
	print("HOST: listening -> ", net.host_game())
	var pl = null
	for i in 25:
		await wait(1.0)
		if net.remote_players.size() > 0:
			pl = net.remote_players.values()[0]
			break
	if pl == null:
		print("HOST FAIL nobody joined")
		quit()
		return
	pl.weapon_slots.clear()
	net.give_weapon(pl, "hammer")
	net.give_weapon(pl, "spear")
	game._forge_store = ["hammer"]
	pl.global_position = net.FORGE_POS + Vector2(8, 0)
	print("HOST: avatar at the forge with hammer + spear in hand and a hammer stored")
	await wait(6.5)
	print("HOST: hands now ", pl.weapon_slots, "  stored ", game._forge_store)
	ok("the spear was dropped into the forge", "spear" in game._forge_store and !("spear" in pl.weapon_slots))
	ok("a held hammer and the stored one were combined into a tier 2 hammer", pl.weapon_slots.any(func(e): return game.entry_id(e) == "hammer" and game.weapon_tier_of(e) == 2) and !("hammer" in game._forge_store))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	quit()
