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

func script_is(n: Node, file: String) -> bool:
	return n.get_script() != null and str(n.get_script().resource_path).ends_with(file)

func count_nodes(file: String) -> int:
	var c := 0
	for n in world.get_children():
		if script_is(n, file):
			c += 1
	return c

## Spells in the world that are copies of the card `id` (a building borrowing a spell).
func spells_of(id: String) -> int:
	var c := 0
	for n in world.get_children():
		if script_is(n, "spell.gd") and str(n.data.get("id", "")) == id:
			c += 1
	return c

func clear_world() -> void:
	for n in world.get_children():
		if n.is_in_group("structure") or n.is_in_group("enemy") or script_is(n, "projectile.gd") or script_is(n, "hazard.gd") or script_is(n, "spell.gd"):
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
	if only == "" or only == "magma_wall":
		await magma()
	if only == "" or only == "venom_tower":
		await venom()
	if only == "" or only == "prism_tower":
		await prism()
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

# ---------------------------------------------------------------- Magma Wall
func magma() -> void:
	var id := "magma_wall"
	var tc = load("res://cards/structure_tiers_c.gd")
	# 1. molten cracks: whoever chewed keeps burning after it is led away
	var after := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, Vector2(0, 200))
		var e = dummy(Vector2(0, 225))
		await wait(1.2)
		e.global_position = Vector2(0, 700)
		var h0: float = e.health
		await wait(1.8)
		after[t] = h0 - e.health
		st.queue_free()
	ok("magma t2 cracks: burning after leaving the wall %.2f (tier 1: %.2f)" % [after[2], after[1]], after[2] > 0.5 and after[1] < 0.1)
	# 2. lava spit
	await clear_world()
	var s3 = tower(id, 3, Vector2(0, 200))
	var d3 = dummy(Vector2(70, 200))
	var glob := false
	var t := 0.0
	while t < 3.6:
		glob = glob or count_nodes("projectile.gd") > 0
		await wait(0.05)
		t += 0.05
	ok("magma t3 spit: a glob flew %s, the dummy at 70 px lost %.1f" % [glob, lost(d3)], glob and lost(d3) > 0.5)
	# 3. heat wall
	var lose := {}
	for tt in [3, 4]:
		await clear_world()
		var sh = tower(id, tt, Vector2(0, 200))
		var dh = dummy(Vector2(35, 200))
		await wait(1.6)
		lose[tt] = lost(dh)
		if tt == 4:
			ok("magma t4 heat wall: dummy at 35 px lost %.1f (tier 3: %.1f), the wall is a light %s" % [lose[4], lose[3], sh.is_in_group("light")], lose[4] > lose[3] + 5.0 and sh.is_in_group("light") and sh.light_radius > 0.0)
	# 4. eruption at two thirds and one third
	await clear_world()
	seen.clear()
	var s5 = tower(id, 5, Vector2(0, 200))
	var d5 = dummy(Vector2(30, 200))
	await wait(0.3)
	s5.hp = s5.max_hp * 0.6
	await watch(0.5)
	var first := spells_of("lava_pool")
	var flash1 := saw("flash", 55.0)
	s5.hp = s5.max_hp * 0.3
	await watch(0.5)
	var second := spells_of("lava_pool")
	s5.hp = s5.max_hp * 0.2
	await watch(0.5)
	ok("magma t5 eruption: pools after 60%% %d, after 30%% %d, after 20%% (no new one) %d, flash %s, dummy hurt %.1f" % [first, second, spells_of("lava_pool"), flash1, lost(d5)], first == 1 and second == 2 and spells_of("lava_pool") == 2 and flash1 and lost(d5) > 10.0)
	# 5. magma core: rage below 30%, and a full pool when it falls
	await clear_world()
	var s6 = tower(id, 6, Vector2(0, 200))
	var chewer = dummy(Vector2(0, 225))
	await wait(0.6)
	var calm: float = chewer.get_meta("mw_burn_dmg", 0.0)
	s6.hp = s6.max_hp * 0.25
	await wait(1.2)
	var raged: float = chewer.get_meta("mw_burn_dmg", 0.0)
	ok("magma t6 rage: burn damage %.2f calm, %.2f below 30%%, rage %s" % [calm, raged, tc.magma_rage(s6)], raged > calm * 1.9 and tc.magma_rage(s6))
	var before := spells_of("lava_pool")
	s6.hp = 0.0
	await wait(0.9)
	ok("magma t6 core: the wall is gone %s and a lava pool lies where it stood (%d more)" % [!is_instance_valid(s6), spells_of("lava_pool") - before], !is_instance_valid(s6) and spells_of("lava_pool") > before)
	await clear_world()
	await draws(id, "magma")

# ---------------------------------------------------------------- Venom Tower
func venom() -> void:
	var id := "venom_tower"
	# 1. toxin stacks: the focused enemy melts, per shot much more than without
	var per := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, Vector2(0, 200))
		var e = dummy(Vector2(0, 150))
		await wait(5.0)
		var shots: int = st._shots
		var unit: float = float(st.data.damage) + float(st.data.poison)
		st.queue_free()
		await wait(2.6)
		per[t] = lost(e) / maxf(1.0, float(shots)) / unit
	ok("venom t2 stacks: damage per shot (in units of a plain shot) %.2f vs %.2f at tier 1" % [per[2], per[1]], per[2] > per[1] * 1.25)
	# 2. spore pods: a poisoned enemy that dies leaves a cloud
	var pods := {}
	for t in [2, 3]:
		await clear_world()
		var st2 = tower(id, t, Vector2(0, 200))
		var e2 = dummy(Vector2(0, 150), 3.0)
		await wait(4.0)
		pods[t] = spells_of("poison_cloud")
	ok("venom t3 pods: clouds after a poisoned enemy fell: tier 3 %d, tier 2 %d" % [pods[3], pods[2]], pods[3] >= 1 and pods[2] == 0)
	# 3. acid spit on the densest group
	await clear_world()
	seen.clear()
	var s4 = tower(id, 4, Vector2(0, 200))
	var cl := [dummy(Vector2(0, 150)), dummy(Vector2(18, 140)), dummy(Vector2(-16, 144))]
	var patch := false
	var t3 := 0.0
	while t3 < 5.2:
		scan()
		patch = patch or count_nodes("hazard.gd") > 0
		await wait(0.05)
		t3 += 0.05
	var hurt3 := true
	for e in cl:
		hurt3 = hurt3 and lost(e) > 0.0
	ok("venom t4 acid: ring 22 seen %s, a slow patch lies there %s, all three hurt %s" % [saw("ring", 22.0), patch, hurt3], saw("ring", 22.0) and patch and hurt3)
	# 4. contagion: B was never shot, yet it sickens next to A
	var got := {}
	for t in [4, 5]:
		await clear_world()
		var st5 = tower(id, t, Vector2(0, 200))
		var a = dummy(Vector2(0, 160))
		var c = dummy(Vector2(-45, 170))
		var b = dummy(Vector2(0, 130))
		await wait(2.7)
		got[t] = lost(b)
	ok("venom t5 contagion: the neighbour lost %.1f without being shot (tier 4: %.1f)" % [got[5], got[4]], got[5] > 0.5 and got[4] < 0.1)
	# 5. plague spire (and the earlier tiers still working)
	await clear_world()
	seen.clear()
	var s6 = tower(id, 6, Vector2(0, 200))
	var grp := [dummy(Vector2(0, 150)), dummy(Vector2(18, 140)), dummy(Vector2(-16, 144)), dummy(Vector2(5, 128))]
	await watch(15.6)
	ok("venom t6 plague: flash 40 seen %s, a cloud exists (%d), acid ring still seen %s, stacks shown %d" % [saw("flash", 40.0), spells_of("poison_cloud"), saw("ring", 22.0), s6.vis.get("stack_pos", []).size()], saw("flash", 40.0) and spells_of("poison_cloud") >= 1 and saw("ring", 22.0) and s6.vis.get("stack_pos", []).size() >= 1)
	await clear_world()
	await draws(id, "venom")

# ---------------------------------------------------------------- Prism Tower
## The most `line` fx of width `w` alive at once (a burst of rays shows twelve).
func lines_alive(w: float) -> int:
	var n := 0
	for c in world.get_children():
		if script_is(c, "fx.gd") and str(c.kind) == "line" and absf(float(c.width) - w) < 0.1:
			n += 1
	return n

func prism() -> void:
	var id := "prism_tower"
	# 1. spectrum: red burns, blue chills, yellow exposes (the tower is frozen right after the shot so nothing else interferes)
	var res := {}
	for case in [["t1", 1, 0], ["red", 2, 0], ["blue", 2, 1], ["yellow", 2, 2]]:
		await clear_world()
		var st = tower(id, case[1], Vector2(0, 200))
		st._shots = case[2]
		var e = dummy(Vector2(0, 150))
		var guard := 0.0
		while st._shots == case[2] and guard < 3.0:
			await wait(0.02)
			guard += 0.02
		st.set_physics_process(false)
		var h0: float = e.health
		await wait(1.3)
		res[case[0]] = [h0 - e.health, e.slow_mult, e.has_meta("exposed_until") and load("res://items/weapons/weapon_util.gd").is_exposed(e)]
	ok("prism t2 spectrum: red burns %.2f (tier 1 %.2f), blue slow %.2f, yellow exposed %s" % [res.red[0], res.t1[0], res.blue[1], res.yellow[2]], res.red[0] > res.t1[0] + 1.5 and res.blue[1] <= 0.51 and res.yellow[2] == true)
	# 2. focus lens: a lone enemy takes a double hit
	var per := {}
	for case in ["lone", "crowd"]:
		await clear_world()
		var st2 = tower(id, 3, Vector2(0, 200))
		var e2 = dummy(Vector2(0, 150))
		if case == "crowd":
			dummy(Vector2(80, 190))
		await wait(2.2)
		per[case] = lost(e2) / maxf(1.0, float(st2._shots)) / float(st2.data.damage)
	ok("prism t3 focus: damage per shot in shots: alone %.2f, in a crowd %.2f" % [per.lone, per.crowd], per.lone > per.crowd * 1.4)
	# 3. prismatic burst on the eighth shot
	await clear_world()
	var s4 = tower(id, 4, Vector2(0, 200))
	dummy(Vector2(0, 180))
	dummy(Vector2(25, 190))
	var far3 = dummy(Vector2(-43.3, 217))              # 50 px from the hub, 150 degrees: only a ray reaches it
	var before := 0.0
	var rays := 0
	var guard2 := 0.0
	while s4._shots < 8 and guard2 < 9.0:
		if s4._shots == 7:
			before = lost(far3)
		rays = maxi(rays, lines_alive(2.0))
		await wait(0.02)
		guard2 += 0.02
	for i in 10:
		rays = maxi(rays, lines_alive(2.0))
		await wait(0.02)
	ok("prism t4 burst: twelve rays seen (%d at once), the dummy off to the side lost %.1f after, %.1f before (a ray is %.1f)" % [rays, lost(far3), before, s4.data.damage * 0.8], rays >= 12 and lost(far3) >= float(s4.data.damage) * 0.7 and before < 0.01)
	# 4. refraction: the shot bends to the neighbour and once more
	var third := {}
	for t in [4, 5]:
		await clear_world()
		var st5 = tower(id, t, Vector2(0, 200))
		dummy(Vector2(0, 150))
		dummy(Vector2(50, 150))
		var c5 = dummy(Vector2(100, 150))
		await wait(1.8)
		third[t] = lost(c5)
	ok("prism t5 refraction: the third dummy (never aimed at) lost %.1f (tier 4: %.1f)" % [third[5], third[4]], third[5] > 0.5 and third[4] < 0.1)
	# 5. spectrum lance
	await clear_world()
	seen.clear()
	var s6 = tower(id, 6, Vector2(0, 200))
	var boss = dummy(Vector2(0, 150), 99999.0)
	var behind = dummy(Vector2(0, 80), 60000.0)
	var side = dummy(Vector2(60, 170), 50000.0)
	var wide := 0
	var t := 0.0
	var h_boss: float = boss.health
	while t < 15.6:
		scan()
		wide = maxi(wide, lines_alive(18.0))
		await wait(0.05)
		t += 0.05
	var dmg6: float = s6.data.damage
	ok("prism t6 lance: width-18 beam seen %s, the toughest lost %.0f and the one behind it %.0f (a lance is %.0f), bursts still fire (ripple 40 %s)" % [wide > 0, 99999.0 - boss.health, 60000.0 - behind.health, dmg6 * 8.0, saw("ripple", 40.0)], wide > 0 and 99999.0 - boss.health >= dmg6 * 8.0 and 60000.0 - behind.health >= dmg6 * 8.0 and saw("ripple", 40.0))
	await clear_world()
	await draws(id, "prism")
