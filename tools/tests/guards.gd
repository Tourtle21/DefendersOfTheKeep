extends SceneTree
## Guards have health instead of a timer, hit lightly, and draw enemies: an enemy that comes near one turns on it and hurts it.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://gd_test_save.json"
	game._menu_done = true
	game._local_devices = []
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	p.clear_item()
	p.global_position = Vector2(0, 400)                  # far away: the enemy has only the guard to go for
	var card: Dictionary = game.CARDS["guards"]
	ok("the card has health and no lifetime (hp %s, damage %s)" % [card.get("hp"), card.damage], card.has("hp") and !card.has("duration") and card.damage <= 1.5)
	var guard = load("res://cards/guard.gd").new()
	guard.setup(game.scaled("guards", 1), Vector2(0, 200))
	world.add_child(guard)
	await wait(0.2)
	await wait(20.0)
	ok("a guard does not time out (still here after 20 s, hp %.0f)" % guard.hp, is_instance_valid(guard) and guard.hp == guard.max_hp)
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = Vector2(30, 200)
	world.get_node("Enemies").add_child(e)
	e.max_health = 99999.0
	e.health = 99999.0
	e.set_physics_process(true)
	var took := false
	var hp0: float = guard.hp
	var hits := []
	var saw_windup := false
	var last := 0
	for i in 80:
		await wait(0.05)
		if is_instance_valid(guard) and guard._windup > 0.0:
			saw_windup = true
		if is_instance_valid(guard) and guard.strikes > last:
			hits.append(i * 0.05)
			last = guard.strikes
		if is_instance_valid(e) and e.aggro_target == guard:
			took = true
	var gaps_ok := hits.size() >= 1 and hits.size() <= 5
	for k in range(1, hits.size()):
		if hits[k] - hits[k - 1] < 0.8:
			gaps_ok = false
	ok("the guard swings: a wind-up first (%s), then separate slashes at %s, never a constant stream" % [saw_windup, str(hits)], saw_windup and gaps_ok)
	ok("the enemy turns on the guard (aggro target)", took)
	ok("the guard takes damage and fights back (hp %.1f of %.1f)" % [guard.hp if is_instance_valid(guard) else 0.0, hp0], !is_instance_valid(guard) or guard.hp < hp0)
	await wait(25.0)
	ok("with nothing to kill the enemy, the guard falls when its health runs out", !is_instance_valid(guard))
	quit()
