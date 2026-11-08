extends SceneTree
# Host for net_client_shots.gd: places a few structures (one partly fed toward the next tier, one with a twist).
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
	game.meta.card_tiers = {"fireball": 6, "frost_ring": 6, "barricade": 6, "spike_trap": 6, "sentry": 6}
	print("HOST: listening -> ", net.host_game())
	for i in 60:
		await wait(0.5)
		if net.remote_players.size() > 0: break
	var spots := [["barricade", 3, "regrow", Vector2(-50, 120)], ["sentry", 2, "twin_shot", Vector2(0, 120)], ["spike_trap", 1, "", Vector2(50, 120)], ["barricade", 4, "regrow", Vector2(100, 120)]]
	var made := []
	for s in spots:
		var st = load("res://cards/structure.gd").new()
		st.setup(game.stats_of(game.make_entry(s[0], s[1], s[2])), s[3])
		world.add_child(st)
		st.tier = s[1]
		st.points = st.tier_points(s[1]) if s[1] > 1 else 1
		made.append(st)
	made[0].absorb(1)             # barricade tier 3, fed one tier 1 card
	made[3].absorb(3)
	for t in get_nodes_in_group("turret"): t.ammo = 0
	print("HOST: structures: ", get_nodes_in_group("structure").size(), " | fed: ", made[0].points, "/", made[0].tier_points(made[0].tier + 1) if made[0].has_method("tier_points") else "?")
	await wait(20.0)
	quit()
