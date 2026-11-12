extends SceneTree
## Tier abilities of the towers Crystal Pylon, Storm Spire, Venom Tower, Prism Tower and Sunspire (docs/card_tiers/<card>.md).
## One section per card; `-- only=<card id>` runs one. Every section also checks the draw: each tier is redrawn while it stands.
var game
var world
var only := ""
var seen := []                       # [kind, radius, width, length] of every WeaponFx seen since the last clear

func wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout
func ok(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n)

func dummy(pos: Vector2, hp := 99999.0):
	var e = load("res://enemies/blobbert/blobbert.tscn").instantiate()
	e.position = pos
	world.get_node("Enemies").add_child(e)
	e.global_position = pos
	e.max_health = hp
	e.health = hp
	e.set_physics_process(false)
	return e

func tower(id: String, tier: int, pos: Vector2):
	var d: Dictionary = game.stats_of(game.make_entry(id, tier, game.twist_for(id, tier)))
	var st = load("res://cards/structure.gd").new()
	st.setup(d, pos)
	world.add_child(st)
	return st

## Watch the one-shot effects for `secs`.
func watch(secs: float) -> void:
	var t := 0.0
	while t < secs:
		scan()
		await wait(0.05)
		t += 0.05

func scan() -> void:
	for n in world.get_children():
		var sc = n.get_script()
		if sc != null and str(sc.resource_path).ends_with("fx.gd"):
			var key := [str(n.kind), snappedf(float(n.radius), 0.1), snappedf(float(n.width), 0.1), snappedf(float(n.length), 1.0)]
			if !(key in seen):
				seen.append(key)

func saw(kind: String, radius := -1.0, width := -1.0) -> bool:
	for k in seen:
		if k[0] == kind and (radius < 0.0 or absf(k[1] - radius) < 0.5) and (width < 0.0 or absf(k[2] - width) < 0.5):
			return true
	return false

func clear_world() -> void:
	for n in world.get_children():
		if n.is_in_group("structure") or n.is_in_group("enemy"):
			n.queue_free()
	for n in root.get_tree().get_nodes_in_group("enemy"):
		n.queue_free()
	await wait(0.2)

func lost(e) -> float:
	return 99999.0 - e.health

func draws(id: String, label: String) -> void:
	# every tier stands and is redrawn for a moment: the engine logs a SCRIPT ERROR when a draw function breaks
	var sts := []
	for t in range(1, 7):
		var st = tower(id, t, Vector2(-300 + t * 90, 100))
		st.tier = t
		sts.append(st)
	for st in sts:
		st.queue_redraw()
	await wait(0.4)
	var good := true
	for st in sts:
		good = good and is_instance_valid(st)
	ok(label + " all six tiers draw (watch the log for SCRIPT ERROR)", good)
	for st in sts:
		st.queue_free()
	await wait(0.1)

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("only="):
			only = a.substr(5)
	game = root.get_node("Game")
	game.save_path = "user://tier_towers_save.json"
	game._menu_done = true
	game._local_devices = []
	world = load("res://world/world.tscn").instantiate()
	root.add_child(world)
	await wait(1.2)
	world.get_node("SpawnTimer").start(9999.0)
	var p = world.get_node("Player")
	p.clear_item()
	p.global_position = Vector2(0, 600)
	if only == "" or only == "crystal_pylon":
		await pylon()
	if only == "" or only == "storm_spire":
		await spire()
	quit()

# ---------------------------------------------------------------- Crystal Pylon
func pylon() -> void:
	var id := "crystal_pylon"
	# 1. shardburst: the fourth hit on one target bursts the shards for a bigger blow
	var ratios := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, Vector2(0, 200))
		var e = dummy(Vector2(0, 160))
		await wait(2.6)
		ratios[t] = lost(e) / maxf(1.0, float(st._shots) * float(st.data.damage))
		st.queue_free()
	ok("pylon t2 shardburst: damage per shot %.2f vs %.2f at tier 1" % [ratios[2], ratios[1]], ratios[2] > ratios[1] * 1.3)
	# 2. resonant link
	var shots := {}
	for case in ["alone", "partner", "far"]:
		await clear_world()
		var a = tower(id, 3, Vector2(0, 200))
		if case == "partner":
			tower(id, 3, Vector2(80, 200))
		if case == "far":
			tower(id, 3, Vector2(150, 200))
		dummy(Vector2(0, 150))
		await wait(6.0)
		shots[case] = a._shots
	ok("pylon t3 link: shots in 6 s alone %d, with a partner at 80 px %d, with one at 150 px %d" % [shots.alone, shots.partner, shots.far], shots.partner >= shots.alone + 2 and absi(shots.far - shots.alone) <= 1)
	# 3. laser lance on the tenth shot: a dummy 100 px along the line takes five times a shot
	await clear_world()
	seen.clear()
	var st4 = tower(id, 4, Vector2(0, 200))
	var a1 = dummy(Vector2(0, 175))
	var far = dummy(Vector2(0, 100))
	var guard := 0.0
	while st4._shots < 10 and guard < 8.0:
		scan()
		await wait(0.05)
		guard += 0.05
	await watch(0.4)
	var dd: float = st4.data.damage
	ok("pylon t4 lance: the far dummy on the line took %.1f (a shot is %.1f, lance %.1f), width-8 beam seen %s" % [lost(far), dd, dd * 5.0, saw("line", -1.0, 8.0)], lost(far) >= dd * 4.5 and saw("line", -1.0, 8.0))
	# 4. brilliance: the light is twice as wide and enemies in it are dazzled
	await clear_world()
	var s4 = tower(id, 4, Vector2(0, 200))
	var s5 = tower(id, 5, Vector2(-200, 200))
	var in_light = dummy(Vector2(-200, 140))
	await wait(0.6)
	var base5: float = float(game.scaled(id, 5).light)
	ok("pylon t5 brilliance: light %.0f vs %.0f at tier 4 (base at tier 5 %.0f), dummy exposed %s" % [s5.light_radius, s4.light_radius, base5, in_light.has_meta("exposed_until")], absf(s5.light_radius - base5 * 2.0) < 1.0 and s5.light_radius > s4.light_radius * 1.9 and in_light.has_meta("exposed_until"))
	# 5. starfall and everything before it (stacks, lance) at tier 6
	await clear_world()
	seen.clear()
	var s6 = tower(id, 6, Vector2(0, 200))
	var hurt := []
	for i in 6:
		hurt.append(dummy(Vector2(-60 + i * 24, 150 + (i % 2) * 20)))
	var super_seen := false
	var t := 0.0
	var lite = load("res://cards/structure_tiers_c.gd")
	while t < 11.0:
		scan()
		if lite.interval_crystal_pylon(s6) < 0.51:
			super_seen = true
		await wait(0.05)
		t += 0.05
	var rings := 0
	for k in seen:
		if k[0] == "ring" and absf(k[1] - 14.0) < 0.5:
			rings += 1
	var falls := 0
	for k in seen:
		if k[0] == "fall":
			falls += 1
	var all_hurt := true
	for e in hurt:
		all_hurt = all_hurt and lost(e) > float(s6.data.damage) * 2.0
	ok("pylon t6 starfall: crystals fell (fx %d), all six hurt %s, supercharge seen %s" % [falls, all_hurt, super_seen], falls >= 1 and all_hurt and super_seen)
	ok("pylon t6 keeps the lance (width 8 %s, %d shots) and the shard burst (flash 22 %s)" % [saw("line", -1.0, 8.0), s6._shots, saw("flash", 22.0)], saw("line", -1.0, 8.0) and saw("flash", 22.0))
	await clear_world()
	await draws(id, "pylon")

# ---------------------------------------------------------------- Storm Spire
func spire() -> void:
	var id := "storm_spire"
	# 1. static chain: the second dummy 35 px from the nearest one is hurt and slowed by every bolt
	var got := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, Vector2(0, 200))
		var a = dummy(Vector2(0, 160))
		var b = dummy(Vector2(0, 125))
		await wait(1.5)
		got[t] = lost(b)
		st.queue_free()
	ok("spire t2 chain: dummy 35 px behind the target lost %.1f (tier 1: %.1f)" % [got[2], got[1]], got[2] > 1.0 and got[1] < 0.5)
	# 2. conductor: the second hit on the same target discharges it onto its neighbour
	await clear_world()
	seen.clear()
	var s3 = tower(id, 3, Vector2(0, 200))
	var a3 = dummy(Vector2(0, 160))
	var n3 = dummy(Vector2(20, 150))
	await watch(1.2)
	ok("spire t3 conductor: discharge ring r30 seen %s, neighbour at 20 px lost %.1f (a shot is %.1f)" % [saw("ring", 30.0), lost(n3), s3.data.damage], saw("ring", 30.0) and lost(n3) >= float(s3.data.damage) * 1.5)
	# 3. thunderclap: everything within 70 px is stunned
	await clear_world()
	seen.clear()
	var s4 = tower(id, 4, Vector2(0, 200))
	var close := [dummy(Vector2(40, 200)), dummy(Vector2(-50, 190))]
	var far = dummy(Vector2(0, 100))
	var stunned := 0
	var t := 0.0
	while t < 7.0:
		scan()
		stunned = maxi(stunned, int(close[0].slow_mult <= 0.0 and close[0].slow_time > 0.0) + int(close[1].slow_mult <= 0.0 and close[1].slow_time > 0.0))
		await wait(0.05)
		t += 0.05
	ok("spire t4 thunderclap: flash 70 seen %s, both close dummies stunned at once %d, first took %.1f" % [saw("flash", 70.0), stunned, lost(close[0])], saw("flash", 70.0) and stunned == 2)
	# 4. skybolt on the toughest dummy
	await clear_world()
	seen.clear()
	var s5 = tower(id, 5, Vector2(0, 200))
	var weak = dummy(Vector2(0, 150), 5000.0)
	var tough = dummy(Vector2(50, 150), 99999.0)
	await watch(3.6)
	var sky := false
	for k in seen:
		if k[0] == "bolt" and absf(k[3] - 120.0) < 1.5:
			sky = true
	ok("spire t5 skybolt: a 120 px bolt seen %s, the toughest dummy lost %.1f" % [sky, lost(tough)], sky and lost(tough) >= float(s5.data.damage) * 4.0)
	# 5. tempest: a gale slows everything in range, and the bolt chains through a row of five
	await clear_world()
	var s6 = tower(id, 6, Vector2(0, 200))
	var row := []
	for i in 5:
		row.append(dummy(Vector2(-60 + i * 30, 150)))
	await wait(1.0)
	var hits := 0
	for e in row:
		if lost(e) > 0.0:
			hits += 1
	ok("spire t6 tempest: gale slows %.2f, %d of 5 in the row were hit" % [row[0].slow_mult, hits], row[0].slow_mult <= 0.71 and hits >= 4)
	await clear_world()
	var s6b = tower(id, 6, Vector2(0, 200))
	seen.clear()
	var c1 = dummy(Vector2(0, 160))
	var c2 = dummy(Vector2(0, 120))
	var c3 = dummy(Vector2(15, 150))
	await watch(7.0)
	ok("spire t6 keeps clap (flash 70 %s), conductor (ring 30 %s)" % [saw("flash", 70.0), saw("ring", 30.0)], saw("flash", 70.0) and saw("ring", 30.0))
	await clear_world()
	await draws(id, "spire")
