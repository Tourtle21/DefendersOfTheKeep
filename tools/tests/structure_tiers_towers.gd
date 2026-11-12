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
	if only == "" or only == "healing_grove":
		await grove()
	if only == "" or only == "sunspire":
		await sunspire()
	if only == "" or only == "phoenix_shrine":
		await phoenix()
	if only == "" or only == "healing_lantern":
		await lantern()
	if only == "" or only == "beacon_turret":
		await beacon()
	if only == "" or only == "bonfire_wall":
		await bonfire()
	if only == "" or only == "spiked_sentry":
		await spiked_sentry()
	if only == "" or only == "spiked_wall":
		await spiked_wall()
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

# ---------------------------------------------------------------- Healing Grove
func health_bar():
	return world.get_node("Player").get_parent().get_node("Hud/Control2/ColorRect/Health")

func hurt_player(px: float) -> void:
	health_bar().size.x = px

func grove() -> void:
	var id := "healing_grove"
	var p = world.get_node("Player")
	var pos := Vector2(0, 200)
	# 1. regrowth: the healing goes on for a while after leaving the field
	var gain := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, pos)
		p.global_position = pos
		hurt_player(100.0)
		await wait(0.5)
		p.global_position = Vector2(400, 200)
		await wait(0.1)
		var h0: float = health_bar().size.x
		await wait(1.5)
		gain[t] = health_bar().size.x - h0
	ok("grove t2 regrowth: health gained 1.5 s after stepping out %.1f (tier 1: %.1f)" % [gain[2], gain[1]], gain[2] > 4.0 and gain[1] < 0.5)
	# 2. orchard: a fruit ripens; a hurt player eats it for 15% of their health
	await clear_world()
	var s3 = tower(id, 3, pos)
	p.global_position = Vector2(400, 200)
	hurt_player(100.0)
	s3._timers["fruit"] = 9.6
	await wait(0.8)
	var fruit: Array = s3.vis.get("fruit_pos", [])
	var n_fruit := fruit.size()
	var eaten := 0.0
	if n_fruit > 0:
		p.global_position = pos + fruit[0]
		await wait(0.1)
		eaten = health_bar().size.x - 100.0
	ok("grove t3 orchard: %d fruit lay in the field, eating it healed %.1f (15%% is %.1f), %d left" % [n_fruit, eaten, 0.15 * 228.0, s3.vis.get("fruit_pos", []).size()], n_fruit == 1 and eaten > 25.0 and eaten < 45.0 and s3.vis.get("fruit_pos", []).size() == 0)
	# 3. roots: slowed to 65%
	await clear_world()
	var s4 = tower(id, 4, pos)
	p.global_position = Vector2(400, 200)
	var d4 = dummy(pos + Vector2(30, 0))
	await wait(0.4)
	ok("grove t4 roots: dummy in the field has slow %.2f" % d4.slow_mult, d4.slow_mult <= 0.66)
	# 4. blossom pulse: a sudden jump of 1.5 x heal per second, confusion gone
	await clear_world()
	seen.clear()
	var s5 = tower(id, 5, pos)
	var f5: float = load("res://cards/structure_tiers_c.gd").budget_mult(s5)
	p.global_position = pos + Vector2(10, 0)
	p.confused_time = 5.0
	hurt_player(228.0)
	await wait(0.1)
	s5._timers["bloom"] = 7.98
	hurt_player(60.0)
	var jump := 0.0
	var last: float = health_bar().size.x
	var tt := 0.0
	while tt < 1.8:
		scan()
		await wait(0.02)
		tt += 0.02
		var h: float = health_bar().size.x
		jump = maxf(jump, h - last)
		last = h
	ok("grove t5 pulse: biggest jump %.1f of the 168 missing (a plain frame heals %.1f), ripple %s, confusion %.1f" % [jump, float(s5.data.heal_per_sec) * 0.02, saw("ripple", s5.radius), p.confused_time], jump >= 100.0 and saw("ripple", s5.radius) and p.confused_time <= 0.0)
	# 5. seed of life: a fallen player is called back (once in forty seconds)
	await clear_world()
	var s6 = tower(id, 6, pos)
	var f6: float = load("res://cards/structure_tiers_c.gd").budget_mult(s6)
	p.global_position = Vector2(400, 200)
	hurt_player(228.0)
	p.fall()
	s6._timers["seed"] = 39.9
	await wait(0.4)
	var first: float = p.respawn_left
	p.respawn()
	p.fall()
	await wait(0.4)
	var second: float = p.respawn_left
	p.respawn()
	p.global_position = Vector2(0, 600)
	ok("grove t6 seed: wait after falling cut to %.1f, a second fall right after waits %.1f" % [first, second], first <= 3.0 and second > 20.0)
	# 6. budget: the grove still gives out (the World Tree counts half)
	ok("grove budget factor: tier 5 %.1f, tier 6 %.1f" % [f5, f6], f5 == 1.0 and f6 == 0.5)
	await clear_world()
	var s6b = tower(id, 6, pos)
	s6b._heal_budget = 6.0
	p.global_position = pos
	hurt_player(50.0)
	await wait(2.5)
	ok("grove t6 still runs out of healing (gone: %s)" % [!is_instance_valid(s6b)], !is_instance_valid(s6b) or s6b.is_queued_for_deletion())
	p.global_position = Vector2(0, 600)
	hurt_player(228.0)
	await clear_world()
	await draws(id, "grove")

# ---------------------------------------------------------------- Sunspire
func lit_now(e) -> bool:
	return e.has_meta("lit_until") and float(e.get_meta("lit_until")) > Time.get_ticks_msec() / 1000.0

func sunspire() -> void:
	var id := "sunspire"
	var tc = load("res://cards/structure_tiers_c.gd")
	var p = world.get_node("Player")
	var pos := Vector2(0, 200)
	# 1. solar flare: the target burns on and is lit (the tower is frozen after its first shot)
	var res := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, pos)
		var e = dummy(Vector2(0, 160))
		var guard := 0.0
		while st._shots == 0 and guard < 3.0:
			await wait(0.02)
			guard += 0.02
		st.set_physics_process(false)
		var h0: float = e.health
		await wait(1.6)
		res[t] = [h0 - e.health, lit_now(e)]
	ok("sunspire t2 flare: burning %.1f after the shot (tier 1: %.1f), lit %s" % [res[2][0], res[1][0], res[2][1]], res[2][0] > res[1][0] + 1.0 and res[2][1])
	# 2. solar lance: a dummy far along the line, never aimed at, takes three shots' worth
	await clear_world()
	seen.clear()
	var s3 = tower(id, 3, pos)
	dummy(Vector2(0, 170))
	dummy(Vector2(35, 170))
	var far = dummy(Vector2(0, 50))
	s3._timers["lance"] = 4.0
	var guard2 := 0.0
	while s3._shots == 0 and guard2 < 3.0:
		scan()
		await wait(0.02)
		guard2 += 0.02
	s3.set_physics_process(false)
	await watch(0.4)
	var dd: float = s3.data.damage
	ok("sunspire t3 lance: width-10 beam seen %s, the far dummy lost %.1f (3 x %.1f = %.1f)" % [saw("line", -1.0, 10.0), lost(far), dd, 3.0 * dd], saw("line", -1.0, 10.0) and lost(far) >= 2.7 * dd and lost(far) <= 3.6 * dd)
	# 3. radiant pulse: the ring hurts what is close and heals a hurt player inside
	await clear_world()
	seen.clear()
	var s4 = tower(id, 4, pos)
	var near = dummy(Vector2(60, 200))
	p.global_position = pos + Vector2(0, 40)
	health_bar().size.x = 100.0
	s4._timers["pulse"] = 5.99
	await watch(0.12)
	var gained: float = health_bar().size.x - 100.0
	ok("sunspire t4 pulse: ring 80 seen %s, dummy at 60 px lost %.1f (2.5 x %.1f), the player gained %.1f" % [saw("ring", 80.0), lost(near), s4.data.damage, gained], saw("ring", 80.0) and lost(near) >= 2.4 * float(s4.data.damage) and gained > 8.0)
	p.global_position = Vector2(0, 600)
	health_bar().size.x = 228.0
	# 4. heliostats: four mirrors fire in turn (the tower itself is frozen, so only the mirrors act)
	await clear_world()
	seen.clear()
	var s5 = tower(id, 5, pos)
	var lone = dummy(Vector2(0, 120))
	s5.set_physics_process(false)
	var mirror_lines := 0
	for i in 9:
		tc.tick_sunspire(s5, 0.25)
		s5._age += 0.25
		await wait(0.02)
		for c in world.get_children():
			if script_is(c, "fx.gd") and str(c.kind) == "line" and absf(float(c.width) - 1.5) < 0.1:
				mirror_lines = maxi(mirror_lines, 1)
		scan()
	var shots_lines := 0
	for k in seen:
		if k[0] == "line" and absf(k[2] - 1.5) < 0.1:
			shots_lines += 1
	ok("sunspire t5 heliostats: mirror beams seen %s, the lone dummy lost %.1f from the mirrors alone (4 x 0.5 x %.1f = %.1f)" % [mirror_lines > 0, lost(lone), s5.data.damage, 2.0 * float(s5.data.damage)], mirror_lines > 0 and lost(lone) >= 1.9 * float(s5.data.damage) * 0.9)
	# 5. high noon: a pillar of light, everything in range hurt and lit, the tower fires faster for ten seconds
	await clear_world()
	seen.clear()
	var s6 = tower(id, 6, pos)
	var crowd := [dummy(Vector2(0, 120)), dummy(Vector2(90, 180)), dummy(Vector2(-120, 140))]
	s6._timers["noon"] = 19.95
	await watch(0.5)
	var all_lit := true
	var all_hurt := true
	for e in crowd:
		all_lit = all_lit and lit_now(e)
		all_hurt = all_hurt and lost(e) >= 5.5 * float(s6.data.damage)
	ok("sunspire t6 noon: pillar seen %s, all lit %s, all hurt %s, interval factor %.2f" % [saw("pillar"), all_lit, all_hurt, tc.interval_mult(s6)], saw("pillar") and all_lit and all_hurt and tc.interval_mult(s6) <= 0.71)
	await watch(6.3)
	ok("sunspire t6 keeps the lance (width 10 %s) and the pulse (ring 80 %s)" % [saw("line", -1.0, 10.0), saw("ring", 80.0)], saw("line", -1.0, 10.0) and saw("ring", 80.0))
	await clear_world()
	await draws(id, "sunspire")

# ---------------------------------------------------------------- Phoenix Shrine
func phoenix() -> void:
	var id := "phoenix_shrine"
	var p = world.get_node("Player")
	var pos := Vector2(0, 200)
	var far := Vector2(500, 200)
	p.global_position = far
	# 1. purifying flame: whatever stands in the field is scorched
	var loss := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, pos)
		var e = dummy(pos + Vector2(60, 0))
		await wait(2.6)
		loss[t] = lost(e)
	ok("phoenix t2 scorch: the dummy in the field lost %.1f (tier 1: %.1f)" % [loss[2], loss[1]], loss[2] > loss[1] + 1.0)
	# 2. ashes: an enemy that dies in the field heals the hurt players in it by 6%
	var jump := {}
	for t in [2, 3]:
		await clear_world()
		var st2 = tower(id, t, pos)
		var e2 = dummy(pos + Vector2(60, 0), 1.0)
		p.global_position = pos + Vector2(20, 0)
		health_bar().size.x = 30.0
		var best := 0.0
		var last: float = health_bar().size.x
		var tt := 0.0
		while tt < 1.0:
			await wait(0.02)
			tt += 0.02
			var h: float = health_bar().size.x
			best = maxf(best, h - last)
			last = h
		jump[t] = best
	ok("phoenix t3 ashes: biggest jump %.1f at tier 3 (6%% is %.1f), %.1f at tier 2" % [jump[3], 0.06 * 228.0, jump[2]], jump[3] >= 10.0 and jump[2] < 8.0)
	p.global_position = far
	# 3. phoenix dive: heals the most hurt player a fifth and bursts around them
	await clear_world()
	seen.clear()
	var s4 = tower(id, 4, pos)
	var hps4: float = s4.data.heal_per_sec
	p.global_position = pos + Vector2(40, 60)
	var near = dummy(pos + Vector2(60, 60))
	var away = dummy(pos + Vector2(-60, 60))
	s4._timers["dive"] = 4.5
	var gain := 0.0
	var t3 := 0.0
	while t3 < 1.2:
		scan()
		health_bar().size.x = 60.0
		await wait(0.02)
		t3 += 0.02
		gain = maxf(gain, health_bar().size.x - 60.0)
	ok("phoenix t4 dive: biggest gain in a step %.1f (20%% is %.1f), line streak seen %s, the dummy next to the player lost %.1f more than the one away (burst %.1f)" % [gain, 0.2 * 228.0, saw("line", -1.0, 4.0), lost(near) - lost(away), hps4 * 0.5], gain >= 40.0 and saw("line", -1.0, 4.0) and lost(near) - lost(away) >= hps4 * 0.4)
	# 4. second life: saved once, not again within 45 s
	await clear_world()
	seen.clear()
	var s5 = tower(id, 5, pos)
	p.global_position = pos + Vector2(10, 0)
	health_bar().size.x = 15.0
	await watch(0.15)
	var saved_hp: float = health_bar().size.x
	var shield: float = p.shield_time
	health_bar().size.x = 15.0
	await wait(0.04)
	var again: float = health_bar().size.x
	ok("phoenix t5 second life: health %.0f after the first save (70%% is %.0f), shield %.1f, a second time within 45 s only %.0f, pillar seen %s" % [saved_hp, 0.7 * 228.0, shield, again, saw("pillar")], saved_hp >= 0.7 * 228.0 - 1.0 and shield >= 2.0 and again < 100.0 and saw("pillar"))
	p.shield_time = 0.0
	p.global_position = far
	# 5. phoenix song when the shrine is spent
	await clear_world()
	seen.clear()
	var s6 = tower(id, 6, pos)
	var hps6: float = s6.data.heal_per_sec
	p.global_position = pos + Vector2(0, 50)
	health_bar().size.x = 50.0
	var d6 = dummy(pos + Vector2(100, 0))
	await wait(0.1)
	var before6 := lost(d6)
	s6._expire()
	await watch(0.15)
	ok("phoenix t6 song: health %.0f, shield %.1f, flash 95 seen %s, the dummy took %.1f more (6 x %.1f = %.1f)" % [health_bar().size.x, p.shield_time, saw("flash", 95.0), lost(d6) - before6, hps6, hps6 * 6.0], health_bar().size.x >= 227.0 and p.shield_time >= 3.5 and saw("flash", 95.0) and lost(d6) - before6 >= hps6 * 5.0)
	p.shield_time = 0.0
	p.global_position = far
	# 6. the budget still spends the shrine (and the glow of its last breath is published)
	await clear_world()
	var s5b = tower(id, 5, pos)
	s5b._heal_budget = 30.0
	p.global_position = pos
	health_bar().size.x = 40.0
	await wait(0.3)
	var charge_seen: float = s5b.charge if is_instance_valid(s5b) else 1.0
	await wait(1.0)
	ok("phoenix budget: the shrine is spent and gone %s (its charge reached %.2f)" % [!is_instance_valid(s5b) or s5b.is_queued_for_deletion(), charge_seen], !is_instance_valid(s5b) or s5b.is_queued_for_deletion())
	p.global_position = Vector2(0, 600)
	health_bar().size.x = 228.0
	await clear_world()
	await draws(id, "phoenix")

# ---------------------------------------------------------------- Healing Lantern
func lantern() -> void:
	var id := "healing_lantern"
	var p = world.get_node("Player")
	var pos := Vector2(0, 200)
	var far := Vector2(500, 200)
	p.global_position = far
	# 1. wisp: the hurt player heals about half again as fast once the wisp has arrived
	var rate := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, pos)
		p.global_position = pos + Vector2(30, 0)
		health_bar().size.x = 40.0
		await wait(1.0)
		var h0: float = health_bar().size.x
		await wait(0.8)
		rate[t] = (health_bar().size.x - h0) / 0.8 / float(st.data.heal_per_sec)
		if t == 2:
			rate["wisp"] = st.vis.get("wisp", Vector2.ZERO)
	ok("lantern t2 wisp: healing %.2f x the field rate (tier 1: %.2f), wisp at %s" % [rate[2], rate[1], str(rate["wisp"])], rate[2] > rate[1] + 0.35 and rate[1] < 1.2)
	p.global_position = far
	# 2. revealing light
	await clear_world()
	var s3 = tower(id, 3, pos)
	var d3 = dummy(pos + Vector2(30, 0))
	await wait(0.6)
	var lit: bool = d3.has_meta("lit_until") and float(d3.get_meta("lit_until")) > Time.get_ticks_msec() / 1000.0
	ok("lantern t3 revealing light: dummy lit %s, slow %.2f" % [lit, d3.slow_mult], lit and d3.slow_mult <= 0.86)
	# 3. guiding light
	await clear_world()
	var s4 = tower(id, 4, pos)
	p.global_position = pos + Vector2(20, 0)
	health_bar().size.x = 100.0
	await wait(0.1)
	var shield1: float = p.shield_time
	p.shield_time = 0.0
	health_bar().size.x = 100.0
	await wait(0.1)
	var shield2: float = p.shield_time
	ok("lantern t4 guiding light: shield %.2f when hurt below half, %.2f the second time within 15 s" % [shield1, shield2], shield1 > 1.0 and shield2 < 0.1)
	p.shield_time = 0.0
	p.global_position = far
	health_bar().size.x = 228.0
	# 4. spirit lanterns
	await clear_world()
	seen.clear()
	var s5 = tower(id, 5, pos)
	var d5 = dummy(pos + Vector2(30, 0))
	await watch(1.5)
	ok("lantern t5 spirits: a warm beam seen %s, the dummy lost %.1f (one zap is %.1f)" % [saw("line", -1.0, 2.0), lost(d5), 0.6 * float(s5.data.heal_per_sec)], saw("line", -1.0, 2.0) and lost(d5) >= 0.55 * float(s5.data.heal_per_sec))
	# 5. dawn
	await clear_world()
	seen.clear()
	var s6 = tower(id, 6, pos)
	var hps6: float = s6.data.heal_per_sec
	var big: float = s6.radius * 1.5
	var d6 = dummy(pos + Vector2(s6.radius * 1.2, 0))           # outside the field, inside 1.5 x
	p.global_position = pos + Vector2(s6.radius * 1.2, 20)
	health_bar().size.x = 60.0
	s6._timers["dawn"] = 19.95
	await watch(0.2)
	var lit6: bool = d6.has_meta("lit_until") and float(d6.get_meta("lit_until")) > Time.get_ticks_msec() / 1000.0 + 5.0
	ok("lantern t6 dawn: flash %.0f seen %s, health %.0f (25%% of 228 = 57 more than 60), the dummy lost %.1f (3 x %.1f), lit for long %s, light %.0f" % [big, saw("flash", big), health_bar().size.x, lost(d6), hps6, lit6, s6.light_radius], saw("flash", big) and health_bar().size.x >= 110.0 and lost(d6) >= hps6 * 2.7 and lit6 and s6.light_radius > float(game.scaled(id, 6).light) * 1.2)
	p.global_position = Vector2(0, 600)
	health_bar().size.x = 228.0
	# 6. the budget still spends it
	await clear_world()
	var s3b = tower(id, 3, pos)
	s3b._heal_budget = 5.0
	p.global_position = pos
	health_bar().size.x = 50.0
	await wait(1.2)
	ok("lantern budget: spent and gone %s" % [!is_instance_valid(s3b) or s3b.is_queued_for_deletion()], !is_instance_valid(s3b) or s3b.is_queued_for_deletion())
	p.global_position = Vector2(0, 600)
	health_bar().size.x = 228.0
	await clear_world()
	await draws(id, "lantern")

# ---------------------------------------------------------------- Beacon Turret
func beacon() -> void:
	var id := "beacon_turret"
	var tc = load("res://cards/structure_tiers_c.gd")
	var pos := Vector2(0, 200)
	# 1. signal fire: the target burns on and is lit (the turret is frozen after its first shot)
	var res := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, pos)
		var e = dummy(Vector2(0, 160))
		var guard := 0.0
		while st._shots == 0 and guard < 3.0:
			await wait(0.02)
			guard += 0.02
		st.set_physics_process(false)
		var h0: float = e.health
		await wait(1.6)
		res[t] = [h0 - e.health, e.has_meta("lit_until") and float(e.get_meta("lit_until")) > Time.get_ticks_msec() / 1000.0]
	ok("beacon t2 signal fire: burning %.1f after the shot (tier 1: %.1f), lit %s" % [res[2][0], res[1][0], res[2][1]], res[2][0] > res[1][0] + 1.0 and res[2][1])
	# 2. sweeping beam: a dummy that is neither target nor twin is hit as the beam passes
	await clear_world()
	var s3 = tower(id, 3, pos)
	dummy(Vector2(0, 220))
	dummy(Vector2(-30, 200))
	var swept = dummy(Vector2(0, 150))                    # straight up: bearing -PI/2
	s3._age = (-PI / 2.0 - 0.35 + TAU) / 1.3
	await wait(0.1)
	var before := lost(swept)
	await wait(0.5)
	ok("beacon t3 sweep: the dummy off the shot lines lost %.1f before the beam came, %.1f after (a pass is %.1f)" % [before, lost(swept), 0.8 * float(s3.data.damage)], lost(swept) - before >= 0.7 * float(s3.data.damage))
	# 3. flare shell on the sixth shot
	await clear_world()
	var s4 = tower(id, 4, pos)
	dummy(Vector2(0, 160))
	var guard3 := 0.0
	while s4._shots < 6 and guard3 < 6.0:
		await wait(0.02)
		guard3 += 0.02
	await wait(0.3)
	var flare_ok := false
	for n in world.get_children():
		if script_is(n, "spell.gd") and str(n.data.get("id", "")) == "flare" and n.data.get("copy", false) == true:
			flare_ok = true
	ok("beacon t4 flare shell: a flare copy exists after %d shots %s" % [s4._shots, flare_ok], flare_ok)
	# 4. alarm horn: three enemies, one blast
	await clear_world()
	var s5 = tower(id, 5, pos)
	var crowd := [dummy(Vector2(0, 150)), dummy(Vector2(30, 160)), dummy(Vector2(-30, 160))]
	var rng: float = s5.data.range
	s5._timers["horn"] = 11.9
	var ids := {}
	var slowed := false
	var tt := 0.0
	while tt < 2.0:
		for n in world.get_children():
			if script_is(n, "fx.gd") and str(n.kind) == "ripple" and absf(float(n.radius) - rng) < 0.5:
				ids[n.get_instance_id()] = true
		await wait(0.05)
		tt += 0.05
		var all_slow := true
		for e in crowd:
			all_slow = all_slow and e.slow_mult <= 0.71
		slowed = slowed or all_slow
	ok("beacon t5 horn: %d blast(s) in 2 s, all three slowed %s (%.2f %.2f %.2f)" % [ids.size(), slowed, crowd[0].slow_mult, crowd[1].slow_mult, crowd[2].slow_mult], ids.size() == 1 and slowed)
	# 5. searchlight on the toughest, with everything before it
	await clear_world()
	seen.clear()
	var s6 = tower(id, 6, pos)
	var boss = dummy(Vector2(0, 140), 99999.0)
	var weak = dummy(Vector2(50, 160), 40000.0)
	s6._timers["search"] = 14.95
	var marked := false
	var slow_seen := 1.0
	var t6 := 0.0
	while t6 < 4.6:
		scan()
		marked = marked or boss.has_meta("marked_until")
		slow_seen = minf(slow_seen, boss.slow_mult)
		await wait(0.05)
		t6 += 0.05
	var dd: float = s6.data.damage
	ok("beacon t6 searchlight: the toughest lost %.1f in 4.6 s (3 x %.1f x 4 s = %.1f), marked %s, held slow %.2f, thick beam seen %s" % [lost(boss), dd, 12.0 * dd, marked, slow_seen, saw("line", -1.0, 14.0)], lost(boss) >= 8.0 * dd and marked and slow_seen <= 0.51 and saw("line", -1.0, 14.0))
	await clear_world()
	await draws(id, "beacon")

# ---------------------------------------------------------------- Bonfire Wall
func fx_count(kind: String, radius: float) -> int:
	var n := 0
	for c in world.get_children():
		if script_is(c, "fx.gd") and str(c.kind) == kind and absf(float(c.radius) - radius) < 0.5:
			n += 1
	return n

func bonfire() -> void:
	var id := "bonfire_wall"
	var pos := Vector2(0, 200)
	# 1. scorching flames: a dummy near the wall but not chewing burns
	var loss := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, pos)
		var e = dummy(pos + Vector2(28, 0))
		await wait(1.6)
		loss[t] = lost(e)
	ok("bonfire t2 scorch: the dummy at 28 px lost %.1f (tier 1: %.1f)" % [loss[2], loss[1]], loss[2] > loss[1] + 1.0)
	# 2. firebrand
	await clear_world()
	seen.clear()
	var s3 = tower(id, 3, pos)
	var d3 = dummy(pos + Vector2(80, 0))
	await watch(3.6)
	ok("bonfire t3 brand: a log fell (fx fall %s), the dummy at 80 px lost %.1f (a brand is %.1f)" % [saw("fall"), lost(d3), 2.0 * float(s3.data.thorns)], saw("fall") and lost(d3) >= 1.8 * float(s3.data.thorns))
	# 3. feeding flame: the wall mends on what it burns
	var gain := {}
	for t in [3, 4]:
		await clear_world()
		var st4 = tower(id, t, pos)
		st4.hp = st4.max_hp * 0.5
		dummy(pos + Vector2(28, 0))
		dummy(pos + Vector2(28, 10))
		dummy(pos + Vector2(28, -10))
		var h0: float = st4.hp
		await wait(1.6)
		gain[t] = st4.hp - h0
	ok("bonfire t4 feeding: the wall mended %.1f with three burning enemies (tier 3, regrow alone: %.1f)" % [gain[4], gain[3]], gain[4] > gain[3] + 3.0)
	# 4. spreading blaze: the neighbour outside the aura catches fire; the light is wider
	await clear_world()
	var s5 = tower(id, 5, pos)
	var a5 = dummy(pos + Vector2(28, 0))
	var b5 = dummy(pos + Vector2(48, 0))
	await wait(2.6)
	var base_light: float = float(game.scaled(id, 5).light)
	ok("bonfire t5 spread: the dummy at 48 px lost %.1f, light %.0f is 1.4 x %.0f" % [lost(b5), s5.light_radius, base_light], lost(b5) > 1.0 and absf(s5.light_radius - base_light * 1.4) < 1.0)
	# 5. pyre: a firestorm of five strikes
	await clear_world()
	seen.clear()
	var s6 = tower(id, 6, pos)
	var d6 = dummy(pos + Vector2(50, 0))
	dummy(pos + Vector2(0, -28))
	s6._timers["pyre"] = 14.9
	var most := 0
	var tt := 0.0
	while tt < 1.0:
		scan()
		most = maxi(most, fx_count("ring", 22.0))
		await wait(0.03)
		tt += 0.03
	ok("bonfire t6 pyre: %d strike rings at once, flash 80 seen %s, the dummy lost %.1f (a strike is %.1f), burning shown %d" % [most, saw("flash", 80.0), lost(d6), 4.0 * float(s6.data.thorns), s6.vis.get("burning", []).size()], most >= 5 and saw("flash", 80.0) and lost(d6) >= 3.5 * float(s6.data.thorns) and s6.vis.get("burning", []).size() >= 1)
	await clear_world()
	await draws(id, "bonfire")

# ---------------------------------------------------------------- Spiked Sentry
func spiked_sentry() -> void:
	var id := "spiked_sentry"
	var tc = load("res://cards/structure_tiers_c.gd")
	var pos := Vector2(0, 200)
	# 1. caltrop shots: a slow patch of radius 16 where the target stood
	var patches := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, pos)
		dummy(pos + Vector2(0, -40))
		await wait(1.0)
		var n := 0
		for c in world.get_children():
			if script_is(c, "hazard.gd") and absf(float(c.radius) - 16.0) < 0.5:
				n += 1
		patches[t] = n
	ok("spiked sentry t2 caltrops: slow patches %d (tier 1: %d)" % [patches[2], patches[1]], patches[2] >= 1 and patches[1] == 0)
	# 2. spike collar: the turret is frozen and its clock driven by hand
	var hit := {}
	for t in [2, 3]:
		await clear_world()
		var st2 = tower(id, t, pos)
		st2.set_physics_process(false)
		var e = dummy(pos + Vector2(25, 0))
		tc.tick_spiked_sentry(st2, 0.5)
		hit[t] = [lost(e), e.knock_time > 0.0 and e.knock_vel.x > 0.0]
	var dd: float = game.scaled(id, 3).damage
	ok("spiked sentry t3 collar: dummy at 25 px lost %.1f (0.8 x %.1f) and was shoved %s (tier 2: %.1f)" % [hit[3][0], dd, hit[3][1], hit[2][0]], hit[3][0] >= 0.7 * dd and hit[3][1] and hit[2][0] < 0.1)
	# 3. barbed bolts: bleeding and pinned, the next bolt bites a quarter harder
	await clear_world()
	var s4 = tower(id, 4, pos)
	var e4 = dummy(pos + Vector2(0, -50))
	var first_mult: float = tc.shot_spiked_sentry(s4, e4)
	var guard := 0.0
	while s4._shots == 0 and guard < 3.0:
		await wait(0.02)
		guard += 0.02
	s4.set_physics_process(false)
	var h0: float = e4.health
	await wait(1.2)
	ok("spiked sentry t4 barbs: bolt factor %.2f before, %.2f on the bleeding dummy, it bled %.1f after the shot, slow %.2f" % [first_mult, tc.shot_spiked_sentry(s4, e4), h0 - e4.health, e4.slow_mult], first_mult == 1.0 and tc.shot_spiked_sentry(s4, e4) == 1.25 and h0 - e4.health > 0.5 and e4.slow_mult <= 0.51)
	# 4. spike field: three strikes under the group
	await clear_world()
	seen.clear()
	var s5 = tower(id, 5, pos)
	var grp := [dummy(pos + Vector2(0, -60)), dummy(pos + Vector2(14, -55)), dummy(pos + Vector2(-14, -55))]
	s5._timers["field"] = 5.9
	var rings := 0
	var tt := 0.0
	while tt < 1.4:
		scan()
		rings = maxi(rings, fx_count("ring", 14.0))
		await wait(0.03)
		tt += 0.03
	ok("spiked sentry t5 field: %d strike rings of radius 14 at once, the middle dummy lost %.1f (3 strikes of 3 x %.1f)" % [rings, lost(grp[0]), s5.data.damage], rings >= 3 and lost(grp[0]) >= 3.0 * float(s5.data.damage))
	# 5. gatling: after five shots it fires three spikes at a time, twice as fast; the spool runs down when idle
	await clear_world()
	var s6 = tower(id, 6, pos)
	var e6 = dummy(pos + Vector2(0, -60))
	var interval_normal: float = tc.interval_mult(s6)
	var spikes := 0
	var spooled := false
	var tt2 := 0.0
	while tt2 < 4.0:
		spikes = maxi(spikes, count_nodes("projectile.gd"))
		spooled = spooled or tc.interval_mult(s6) <= 0.51
		await wait(0.03)
		tt2 += 0.03
	e6.queue_free()
	await wait(3.0)
	ok("spiked sentry t6 gatling: normal %.1f, spooled %s, %d spikes alive at once, after 3 s idle %.2f (spool %.2f)" % [interval_normal, spooled, spikes, tc.interval_mult(s6), float(s6._tdata.get("spool", 0.0))], interval_normal == 1.0 and spooled and spikes >= 3 and tc.interval_mult(s6) == 1.0)
	await clear_world()
	await draws(id, "spiked sentry")

# ---------------------------------------------------------------- Spiked Wall
func spiked_wall() -> void:
	var id := "spiked_wall"
	var tc = load("res://cards/structure_tiers_c.gd")
	var pos := Vector2(0, 200)
	# 1. spike strip: a dummy in front of the wall but not chewing is hurt and slowed
	var res := {}
	for t in [1, 2]:
		await clear_world()
		var st = tower(id, t, pos)
		var e = dummy(pos + Vector2(0, 33))                       # radius + 15
		await wait(1.2)
		res[t] = [lost(e), e.slow_mult]
	ok("spiked wall t2 strip: dummy at radius + 15 lost %.1f, slow %.2f (tier 1: %.1f, %.2f)" % [res[2][0], res[2][1], res[1][0], res[1][1]], res[2][0] > res[1][0] + 0.5 and res[2][1] <= 0.71 and res[1][1] > 0.9)
	# 2. spear thrust: three spears, a hit of thorns x 2 and a shove
	await clear_world()
	seen.clear()
	var s3 = tower(id, 3, pos)
	s3.set_physics_process(false)
	var e3 = dummy(pos + Vector2(0, 40))
	tc.tick_spiked_wall(s3, 2.0)
	await watch(0.3)
	var th: float = s3.data.thorns
	ok("spiked wall t3 thrust: lines of width 3 seen %s, the dummy lost %.1f (thorns x 2 = %.1f, plus a strip tick) and was pushed %s" % [saw("line", -1.0, 3.0), lost(e3), th * 2.0, e3.knock_time > 0.0], saw("line", -1.0, 3.0) and lost(e3) >= th * 2.0 * 0.9 and e3.knock_time > 0.0)
	# 3. impaler: about 30% of the gnaws impale
	await clear_world()
	var s4 = tower(id, 4, pos)
	s4.set_physics_process(false)
	var stuns := 0
	for i in 60:
		var e4 = dummy(pos + Vector2(0, 25))
		tc.on_gnaw_spiked_wall(s4, e4)
		if e4.slow_mult <= 0.0 and e4.slow_time > 0.0:
			stuns += 1
		e4.queue_free()
	ok("spiked wall t4 impaler: %d of 60 gnaws impaled (expect about 18)" % stuns, stuns >= 6 and stuns <= 32)
	# 4. spike volley: five spikes in a fan
	await clear_world()
	var s5 = tower(id, 5, pos)
	var e5 = dummy(pos + Vector2(0, 100))
	s5._timers["volley"] = 2.95
	var most := 0
	var tt := 0.0
	while tt < 0.5:
		most = maxi(most, count_nodes("projectile.gd"))
		await wait(0.02)
		tt += 0.02
	ok("spiked wall t5 volley: %d spikes in the air at once" % most, most >= 5)
	# 5. porcupine: a ring of spikes at each threshold, the thorns double below half
	await clear_world()
	var s6 = tower(id, 6, pos)
	s6.set_physics_process(true)
	var base: float = s6.data.thorns
	await wait(0.2)
	s6.hp = 0.7 * s6.max_hp
	await wait(0.2)
	var ring1 := count_nodes("projectile.gd")
	s6.hp = 0.45 * s6.max_hp
	await wait(0.2)
	var ring2 := count_nodes("projectile.gd") - ring1
	var doubled: float = s6.data.thorns
	s6.hp = 0.7 * s6.max_hp
	await wait(0.2)
	ok("spiked wall t6 porcupine: %d spikes at 70%%, %d more at 45%% with thorns %.1f (base %.1f), back to %.1f when mended" % [ring1, ring2, doubled, base, s6.data.thorns], ring1 >= 16 and ring2 >= 16 and absf(doubled - base * 2.0) < 0.01 and absf(s6.data.thorns - base) < 0.01)
	await clear_world()
	await draws(id, "spiked wall")
