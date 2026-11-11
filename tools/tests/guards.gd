extends SceneTree
## Guards have health instead of a timer, hit lightly, and draw enemies: an enemy that comes near one turns on it and hurts it.
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func mk(world, pos: Vector2):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.global_position = pos
	e.max_health = 99999.0
	e.health = 99999.0
	e.set_physics_process(true)
	return e
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
	# ---------- tiers: each one looks and fights differently
	for g0 in world.get_children():
		if g0.is_in_group("guard"):
			g0.queue_free()
	for e0 in world.get_node("Enemies").get_children():
		e0.queue_free()
	await wait(0.3)
	var stats := []
	for t in range(1, 7):
		stats.append(game.stats_of(game.make_entry("guards", t, "")))
	ok("health, damage and the number of guards grow with the tier (hp %s, damage %s, count %s)" % [str(stats.map(func(s): return snappedf(s.hp, 0.1))), str(stats.map(func(s): return snappedf(s.damage, 0.01))), str(stats.map(func(s): return int(s.count)))],
		range(1, 6).all(func(i): return stats[i].hp > stats[i - 1].hp and stats[i].damage > stats[i - 1].damage and stats[i].count >= stats[i - 1].count) and stats[5].count > stats[0].count)
	var dealt := {}
	for t in range(1, 7):
		var gd = load("res://cards/guard.gd").new()
		gd.setup(stats[t - 1], Vector2(300, 300))
		world.add_child(gd)
		var front = mk(world, Vector2(314, 300))               # in front, in reach
		var back = mk(world, Vector2(286, 300))                # behind the guard (a whirl reaches it)
		var line = mk(world, Vector2(366, 300))                # down the line, out of reach (a sword beam reaches it)
		for en in [front, back, line]:
			en.set_physics_process(false)                     # (held in place)
		await wait(0.2)
		gd._aim = Vector2.RIGHT
		var waited := 0.0
		while gd.strikes < 1 and waited < 3.0:
			await wait(0.05)
			waited += 0.05
		await wait(0.5)
		dealt[t] = [snappedf(99999.0 - front.health, 0.01), snappedf(99999.0 - back.health, 0.01), snappedf(99999.0 - line.health, 0.01), gd.strikes]
		gd.queue_free()
		for en in [front, back, line]:
			en.queue_free()
		await wait(0.3)
	print("  damage dealt (front, behind, down the line) per tier: ", dealt)
	ok("tier 3 follows each swing with a second strike (front %.2f vs %.2f at tier 1)" % [dealt[3][0], dealt[1][0]], dealt[3][0] > dealt[1][0] * 1.8)
	ok("tier 5 sends a sword beam down the line, lower tiers do not (%.2f vs %.2f)" % [dealt[5][2], dealt[4][2]], dealt[5][2] > 0.0 and dealt[2][2] == 0.0)
	ok("tier 6 whirls all round: it hits what is behind it, tier 1 does not (%.2f vs %.2f)" % [dealt[6][1], dealt[1][1]], dealt[6][1] > 0.0 and dealt[1][1] == 0.0)
	var arts := []
	for t in range(1, 7):
		var gd2 = load("res://cards/guard.gd").new()
		gd2.setup(stats[t - 1], Vector2(0, 700))
		arts.append([gd2.tier, gd2.scale.x, gd2.reach(), gd2.pull])
	ok("each tier is bigger and reaches further, a Captain draws enemies from afar %s" % str(arts), arts[5][1] > arts[0][1] and arts[5][2] > arts[0][2] and arts[3][3] > 0.0 and arts[0][3] == 0.0)
	quit()
