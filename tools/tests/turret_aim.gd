extends SceneTree
# Do the tower turrets hit what they shoot at? Shots fired vs hits, for a still enemy and a moving one.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func run_case(world, game, label: String, vel: Vector2, start: Vector2) -> void:
	for t in get_nodes_in_group("turret"): t.ammo = 0
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and !e.is_in_group("boss"): e.queue_free()
	await wait(0.3)
	var tower = null
	for t in get_nodes_in_group("turret"):
		if t.get_parent().position.distance_to(Vector2(0, 0)) < 1000 and game.sector_at(t.get_parent().position) in game.sectors_unlocked: tower = t
	var origin: Vector2 = tower.global_position
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = origin + start
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(false)
	e.get_node("NavigationTimer").stop()
	e.max_health = 5000.0
	e.health = 5000.0
	tower.ammo = 10
	var shots_start: int = tower.ammo
	var t := 0.0
	var p0: Vector2 = e.global_position
	while t < 13.0 and tower.ammo > 0:
		e.global_position += vel * 0.05
		await wait(0.05)
		t += 0.05
	await wait(0.6)
	var fired: int = shots_start - tower.ammo
	var dmg: float = 5000.0 - e.health
	print("%-34s shots fired %2d | damage dealt %5.1f | about %.0f of %d shots hit" % [label, fired, dmg, dmg / 1.5, fired])
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://test_save.json"
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.0)
	world.get_node("SpawnTimer").start(600.0)
	await run_case(world, game, "standing still, 100 px away", Vector2.ZERO, Vector2(0, 100))
	await run_case(world, game, "walking sideways at 25 px/s", Vector2(25, 0), Vector2(-60, 100))
	await run_case(world, game, "walking sideways at 45 px/s", Vector2(45, 0), Vector2(-90, 100))
	await run_case(world, game, "walking toward the tower at 25", Vector2(0, -25), Vector2(40, 125))
	quit()
