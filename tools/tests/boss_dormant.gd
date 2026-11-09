extends SceneTree
## Before its sector's fifth wave a boss is not in the world: no hitbox, not an enemy, cannot be hit. Then it arrives.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://bd_test_save.json"
	game._menu_done = true
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var boss = null
	for b in get_nodes_in_group("boss"):
		if b.sector_id == "s": boss = b
	ok("King Blobbert is asleep: hidden, no hitbox, not in the enemy group", !boss.visible and boss.collision_layer == 0 and !boss.is_in_group("enemy"))
	var hp0: float = boss.health
	boss.spell_damage(50.0)
	var WU = load("res://items/weapons/weapon_util.gd")
	var hits: Array = WU.enemies_in_circle(self, boss.global_position, 80.0)
	ok("a weapon or spell at his spot finds nothing there (%d)" % hits.size(), !hits.has(boss))
	for w in range(1, 5):
		world.waves_in_sector = w - 1
		game.run_stats.waves = w - 1
		world.spawn_enemies([], [])
		ok("after wave %d he is still away" % w, !boss.visible and !boss.is_in_group("enemy"))
	world.spawn_enemies([], [])
	await wait(0.4)
	ok("the fifth wave of the sector brings him in", boss.visible and boss.is_in_group("enemy") and boss.collision_layer == 2)
	quit()
