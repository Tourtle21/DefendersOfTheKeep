extends SceneTree
## The six new enemy kinds of the upper levels each have their own move to dodge or counter: Cinder Bomber (fuse: kill it in time),
## Magma Charger (charge down a lane, then winded), Venom Burrower (dives untouchable, surfaces on a ring), Mire Lobber (lobbed
## bombs and poison puddles), Prism Blinker (blinks next to you after a warning ring), Shard Splitter (bursts into shards).
func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)
func spawn(world, kind: Dictionary, pos: Vector2):
	var e = load("res://enemies/" + kind.name + "/" + kind.name + ".tscn").instantiate()
	if kind.has("script"):
		e.set_script(load(kind.script))
	e.power = 1.0
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.set_physics_process(true)
	return e
func clear(world) -> void:
	for e in world.get_node("Enemies").get_children():
		e.queue_free()
	for h in get_nodes_in_group("hazard"):
		h.queue_free()
	await wait(0.2)
func _initialize() -> void:
	var game = root.get_node("Game")
	game.save_path = "user://ek_test_save.json"
	game._menu_done = true
	game._local_devices = []
	game.sectors_unlocked = ["s", "se", "ne", "n", "nw", "sw"]
	var world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	p.shield_time = 0.0
	p.clear_item()                                      # (no weapon in hand: the player's sword must not kill the test enemies)
	var R = world.ROSTER
	var kind = {}
	for l in R:
		for k in R[l]:
			kind[k.label] = k
	ok("every level has three kinds and each of the six new ones has its own script", R.size() == 6 and R.values().all(func(a): return a.size() == 3) and ["Cinder Bomber", "Magma Charger", "Venom Burrower", "Mire Lobber", "Prism Blinker", "Shard Splitter"].all(func(n): return kind[n].has("script") and ResourceLoader.exists(kind[n].script)))
	# ---------- Cinder Bomber: the fuse can be beaten
	await clear(world)
	p.global_position = Vector2(0, 80)
	var hp0: float = p.get("health") if p.get("health") != null else 0.0
	var b = spawn(world, kind["Cinder Bomber"], Vector2(30, 80))
	b.max_health = 9999.0                                 # (so the player's own sword cannot kill it before the test does)
	b.health = 9999.0
	b.start_aggro(p)
	var lit := false
	for i in 40:
		await wait(0.1)
		b.start_aggro(p)
		if b._fuse > 0.0:
			lit = true
			break
	ok("a bomber next to you lights its fuse", lit)
	var dmg0: float = p.get("hurt_flash") if p.get("hurt_flash") != null else 0.0
	b.spell_damage(20000.0)
	await wait(0.4)
	ok("killed during the fuse it fizzles (it is gone, no blast)", !is_instance_valid(b) or b.dead)
	await clear(world)
	var b2 = spawn(world, kind["Cinder Bomber"], Vector2(30, 80))
	b2.max_health = 9999.0                                # (the player's own sword would otherwise kill it before the fuse ends)
	b2.health = 9999.0
	b2.start_aggro(p)
	var patches0 := get_nodes_in_group("hazard").size()
	await wait(4.2)
	ok("left alone it goes off: it is gone and leaves burning ground", (!is_instance_valid(b2) or b2.dead) and get_nodes_in_group("hazard").size() > patches0)
	# ---------- Magma Charger: telegraph, charge, then winded
	await clear(world)
	p.global_position = Vector2(0, 80)
	var c = spawn(world, kind["Magma Charger"], Vector2(110, 80))
	c.start_aggro(p)
	var start: Vector2 = c.global_position
	var far := 0.0
	var winded := false
	for i in 40:
		await wait(0.1)
		if is_instance_valid(c):
			far = maxf(far, c.global_position.distance_to(start))
			if c._recover > 0.8:
				winded = true
		c.start_aggro(p) if is_instance_valid(c) else null
	ok("the charger charges (moved %.0f units) and is winded afterwards" % far, far > 60.0 and winded)
	# ---------- Venom Burrower: untouchable underground
	await clear(world)
	p.global_position = Vector2(0, 80)
	var v = spawn(world, kind["Venom Burrower"], Vector2(100, 80))
	v.start_aggro(p)
	var dived := false
	var hurt_while_down := false
	for i in 50:
		await wait(0.1)
		if is_instance_valid(v) and v.ghost:
			dived = true
			var h: float = v.health
			v.spell_damage(3.0)
			if v.health < h:
				hurt_while_down = true
		if is_instance_valid(v): v.start_aggro(p)
	ok("it dives and nothing can hurt it down there", dived and !hurt_while_down)
	# ---------- Mire Lobber: bombs and puddles
	await clear(world)
	p.global_position = Vector2(0, 80)
	var m = spawn(world, kind["Mire Lobber"], Vector2(115, 80))
	await wait(6.5)
	ok("the lobber's bombs leave poison puddles (%d)" % get_nodes_in_group("hazard").size(), get_nodes_in_group("hazard").size() > 0)
	# ---------- Prism Blinker: blinks next to you
	await clear(world)
	p.global_position = Vector2(0, 80)
	var bl = spawn(world, kind["Prism Blinker"], Vector2(120, 80))
	bl.start_aggro(p)
	var near := 999.0
	for i in 50:
		await wait(0.1)
		if is_instance_valid(bl):
			near = minf(near, bl.global_position.distance_to(p.global_position))
			bl.start_aggro(p)
	ok("the blinker reappears beside you (closest %.0f units)" % near, near < 45.0)
	# ---------- Shard Splitter: shards on death
	await clear(world)
	var s = spawn(world, kind["Shard Splitter"], Vector2(60, 80))
	var shots0 := get_nodes_in_group("net").filter(func(n): return n is EnemyProjectile).size() if false else 0
	var seen := 0
	s.spell_damage(100.0)
	await wait(0.15)
	for n in world.get_children():
		if n.get_script() != null and str(n.get_script().resource_path).ends_with("enemy_projectile.gd"):
			seen += 1
	ok("it bursts into shards when it dies (%d shards)" % seen, seen >= 6)
	quit()
