extends SceneTree
## When every player is down, enemies keep coming for the crystal (they used to stop dead).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://ad_test_save.json"
	game._menu_done = true
	game._local_devices = [-1, 1]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var lp = world.get_children().filter(func(c): return c.get_script() and str(c.get_script().resource_path).ends_with("local_players.gd"))[0]
	var p1 = world.get_node("Player")
	var p2 = lp.avatars[1]
	p1.global_position = Vector2(400, 700)
	p2.global_position = Vector2(420, 700)
	var e = load("res://enemies/goblin/goblin.tscn").instantiate()
	e.position = Vector2(0, 520)                  # outside the towers' range
	world.get_node("Enemies").add_child(e)
	await wait(0.5)
	var d_alive: float = e.global_position.distance_to(e.center)
	# both players go down
	p1.fall()
	p2.fall()
	await wait(0.4)
	ok("both players are down", p1.downed and p2.downed)
	var before: float = e.global_position.distance_to(e.center)
	await wait(3.0)
	var after: float = e.global_position.distance_to(e.center)
	print("  distance to the crystal: %.0f -> %.0f" % [before, after])
	ok("the enemy keeps walking to the crystal while everyone is down", after < before - 20.0)
	# and with a player standing right in front of it (between it and the keep), it still heads for the crystal until provoked
	p1.respawn()
	p1.global_position = Vector2(0, 360)
	var e2 = load("res://enemies/goblin/goblin.tscn").instantiate()
	e2.position = Vector2(160, 520)
	world.get_node("Enemies").add_child(e2)
	await wait(0.5)
	var tgt: Vector2 = e2.nav_agent.target_position
	print("  enemy target %s (the crystal is near %s, the player is at %s)" % [tgt.round(), e2.center, p1.global_position])
	ok("with a player in front of it, its destination is the crystal, not the player", tgt.distance_to(e2.center) < 40.0)
	quit()
