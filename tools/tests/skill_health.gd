extends SceneTree
## The Vitality skill: the same hit takes a smaller share of health (player 1's bar and a co-op avatar's hp), healing too.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	var net = root.get_node("Net")
	game.save_path = "user://sh2_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p1 = world.get_node("Player")
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p2 = lp.avatars[1]
	var bar = world.get_node("Hud/Control2/ColorRect/Health")
	var lost := []
	for lvl in [0, 5]:
		game.meta.skills["vitality"] = lvl
		bar.size.x = 228.0
		p1.is_taking_damage = false; p1.shield_time = 0.0
		p1.take_damage(Vector2(500, 500), 30.0)
		var l1: float = 228.0 - bar.size.x
		p2.remote_hp = 228.0
		p2.is_taking_damage = false; p2.shield_time = 0.0
		p2.take_damage(Vector2(500, 500), 30.0)
		lost.append([snappedf(l1, 0.1), snappedf(228.0 - p2.remote_hp, 0.1)])
		await wait(0.7)
	print("  a 30-damage hit costs (player 1, player 2): without the skill %s, with Vitality x5 %s" % [lost[0], lost[1]])
	ok("Vitality x5 cuts the share of health lost by a third (1/1.5) for both players", is_equal_approx(lost[0][0], 30.0) and absf(lost[1][0] - 20.0) < 0.2 and absf(lost[1][1] - 20.0) < 0.2)
	quit()
