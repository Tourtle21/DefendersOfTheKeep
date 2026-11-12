extends RefCounted
## Worldbreaker tiers (docs/weapon_tiers/worldbreaker.md), Ancient, fusion tier 4: 4 Tectonic Plate, 5 Continental Drift, 6 Worldbreaker.
## THE SYSTEM: Tectonic Plates. The Juggernaut's plates (each blocked hit, `_stored`, 10 at most) and the Earthshaker's faults (slow patches that an
## Aftershock detonates) braided: a released Fortress turns plates into faults, every verb leaves faults, the ultimate remaps the arena.
## The Plate helpers come from tiers/juggernaut.gd and the Fault helpers from tiers/earthshaker.gd (both work on w._st, which this module fills
## with the same keys). Colossus and World Shaker are NOT inherited: the titan below is this weapon's own transformation.
## Hook functions never suspend (they run through callv): waits live in helper coroutines.

const Jug := preload("res://items/weapons/tiers/juggernaut.gd")
const Earth := preload("res://items/weapons/tiers/earthshaker.gd")
const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const BED := Color(0.65, 0.45, 0.25)
const LAVA := Color(1.0, 0.60, 0.20)
const STEEL := Color(0.80, 0.85, 1.0)
const GOLD := Color(1.0, 0.85, 0.40)
const WBK_FAULT_MAX := 14
const WBK_THIRD_R := 150.0
const WBK_THIRD_N := 16
const WBK_THIRD_MULT := 0.6
const WBK_PLATE_MULT := 0.6
const WBK_DRIFT_PULL := 200.0
const WBK_DRIFT_SECS := 3.0
const WBK_TITAN_SECS := 12.0
const WBK_TITAN_SCALE := 1.4
const WBK_BOULDER_EVERY := 2.0
const WBK_BOULDER_MULT := 1.0
const WBK_BREAK_R := 160.0
const WBK_BREAK_MULT := 2.0
const WBK_FINISHER_EVERY := 6
const WBK_SLAM_EVERY := 3
const NAMES := ["", "Worldbreaker", "", "", "Tectonic Plate", "Continental Drift", "Worldbreaker"]

static func palette() -> Array:
	return [BED, LAVA, GOLD]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func H(w) -> float:
	return WeaponTiers.H(w)

static func equip(w) -> void:
	w._st = {"swings": 0, "last_ms": -1000, "ext": 0.0, "faults": [], "ult_id": 0, "titan_until": 0.0, "step_next": 0.0, "auto_next": 0.0, "boulder_next": 0.0,
		"salvo_next": 0.0, "pub": "", "shaker_until": 0.0, "pillar_next": 0.0}

static func titan(w) -> bool:
	return float(w._st.get("titan_until", 0.0)) > _now()

# ---------- Fortress: blocks, bash, release ----------

static func on_block(w, from: Vector2) -> void:
	Jug.on_block(w, from)

static func bash(w) -> void:
	Jug.bash(w)

## After the old release (called by t2/juggernaut.gd release_ability, `n` plates were stored): plates become faults, the rings leave faults, then the
## Aftershock; Drift contracts the rings; Worldbreak adds the third ring and fires the plates.
static func braced_release(w, n: int) -> void:
	w._st.ext = 0.0
	var o: Vector2 = w.player.global_position
	w.fx("ring", o, GOLD, {"radius": 30.0 + 8.0 * float(n), "life": 0.4})
	for i in n:                                                  # each stored plate leaves a fault ring segment
		var a: float = float(i) * TAU / float(maxi(n, 1))
		Earth.add_fault(w, o + Vector2.from_angle(a) * 44.0)
	for i in 12:
		if i % 2 == 0:
			Earth.add_fault(w, o + Vector2.from_angle(float(i) * TAU / 12.0) * 62.0)
	if n >= 8:
		w.fx("cone", o, GOLD, {"radius": 100.0, "dir": w.aim, "half_angle": 0.7, "life": 0.35, "col2": STEEL})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, 100.0, 40.0):
			WeaponUtil.hit(e, H(w) * 0.18, o, 420.0, 0.0, "", true)
	_aftershock_later(w, o)
	if w.tier >= 5:
		_drift_ring(w, o)
	if w.tier >= 6:
		_third_ring(w, o, n)

static func _aftershock_later(w, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.0):
		return
	Earth.aftershock(w, o, 120.0)
	w.player.shake(2.0, 0.15)

## Drift Ring: 0.6 s after the rings land they contract: 12 + 8 strikes re-erupt from the outside in and pull the crowd toward you.
static func _drift_ring(w, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.0 + 0.6):
		return
	var h: float = H(w) * 0.4
	for k in 8:
		var p: Vector2 = o + Vector2.from_angle(float(7 - k) * TAU / 8.0 + 0.4) * 112.0
		w.ground_strike(p, 26.0, 0.12, h, 0.0, BED, 0.0)
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 30.0):
			Kit.pull(e, o, 160.0, 0.3)
		if k % 2 == 0 and !await WeaponTiers.pause(w, 0.05):
			return
	for k in 12:
		var p2: Vector2 = o + Vector2.from_angle(float(11 - k) * TAU / 12.0) * 62.0
		w.ground_strike(p2, 24.0, 0.12, h, 0.0, BED, 0.0)
		for e2 in WeaponUtil.enemies_in_circle(w.get_tree(), p2, 28.0):
			Kit.pull(e2, o, 160.0, 0.3)
		if k % 3 == 0 and !await WeaponTiers.pause(w, 0.05):
			return
	w.fx("vortex", o, BED, {"radius": 110.0, "count": 3, "spin": 2.0, "inward": true, "life": 0.5})

## Worldbreak: a third ring of 16 strikes at 150 px (sigil telegraph) and the plates fly outward.
static func _third_ring(w, o: Vector2, n: int) -> void:
	w.fx("sigil", o, LAVA, {"radius": WBK_THIRD_R, "count": 16, "spin": 1.5, "life": 0.5, "col2": GOLD})
	for i in n:                                                  # one plate-shard per stored plate, pierce 2
		var d := Vector2.from_angle(float(i) * TAU / float(maxi(n, 1)))
		if WeaponProjectile.alive(w.get_tree()) < 40:
			WeaponProjectile.shoot(w.game_world(), o + d * 20.0, d, 240.0, H(w) * WBK_PLATE_MULT, GOLD, 0.7, 2, 60.0, {"style": "shard", "glow": 0.3, "owner_id": w.player.get_instance_id(), "size": 1.2})
	w._stored = 0
	if !await WeaponTiers.pause(w, 0.5):
		return
	for i in WBK_THIRD_N:
		var p: Vector2 = o + Vector2.from_angle(float(i) * TAU / float(WBK_THIRD_N) + 0.2) * WBK_THIRD_R
		w.ground_strike(p, 28.0, 0.1 + 0.02 * float(i), H(w) * WBK_THIRD_MULT, 200.0, LAVA, 0.4, ["stone", "stick"])
	w.player.shake(4.0, 0.3)

# ---------- attack ----------

static func attack(w) -> void:
	if w._braced:
		return
	var st: Dictionary = w._st
	var ms := Time.get_ticks_msec()
	if ms - int(st.last_ms) < 250:
		return
	st.last_ms = ms
	st.swings = int(st.swings) + 1
	_swing(w, int(st.swings))

static func _swing(w, n: int) -> void:
	if !await WeaponTiers.pause(w, 0.22):
		return
	var o: Vector2 = w.player.global_position
	var d: Vector2 = w.aim
	w.fx("shards", o + d * 22.0, STEEL, {"radius": 26.0, "count": 6, "life": 0.3})
	w.fx("crack", o + d * 10.0, BED, {"radius": 40.0, "count": 3, "life": 0.5})        # the Tremor ripple: two extra hits in a line
	for r in [30.0, 48.0]:
		w.ground_strike(o + d * r, 14.0, 0.15, H(w) * Earth.ES_TREMOR_MULT, 100.0, BED, 0.0, ["stone"])
	if w.tier >= 5:                                              # Drift: the nearest fault slides toward the target; more faults, a wider swing
		var near: int = 0
		var best = null
		var bd := 1.0e9
		for f in Earth._live(w):
			var dist: float = f.pos.distance_to(o)
			if dist <= 60.0:
				near += 1
			if dist < bd and dist > 4.0:
				bd = dist
				best = f
		if best != null and is_instance_valid(best.node):
			var to: Vector2 = o + d * 36.0
			w.fx("crack", best.pos, LAVA, {"radius": 14.0, "count": 3, "life": 0.4})
			best.pos = best.pos.move_toward(to, 18.0)
			best.node.position = best.pos
		var bonus: float = minf(8.0, 1.3 * float(near))
		if bonus > 0.5:
			for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, d, 32.0 + bonus, 60.0):
				if e.global_position.distance_to(o) > 32.0:
					WeaponUtil.hit(e, H(w) * 0.5, o, 200.0, 0.0, "", true, true)
	if titan(w):                                                 # Worldbreaker titan: every swing is a slam
		w.fx("shock", o + d * 18.0, LAVA, {"radius": 50.0, "thick": 6.0, "life": 0.35, "col2": STEEL})
		for e2 in WeaponUtil.enemies_in_circle(w.get_tree(), o + d * 18.0, 50.0):
			WeaponUtil.hit(e2, H(w) * 1.4, o, 220.0, 0.0, "", true)
			WeaponUtil.stun(e2, 0.5)
		w.player.shake(3.0, 0.2)
	elif w.tier >= 6 and n % WBK_FINISHER_EVERY == 0:             # Worldbreak strike
		var at: Vector2 = o + d * 20.0
		w.fx("shock", at, LAVA, {"radius": 60.0, "thick": 7.0, "life": 0.4, "col2": GOLD})
		w.fx("crack", at, BED, {"radius": 60.0, "count": 10, "life": 0.8})
		for e3 in WeaponUtil.enemies_in_circle(w.get_tree(), at, 60.0):
			WeaponUtil.hit(e3, H(w) * 1.5, o, 260.0, 0.0, "", true)
		Earth.aftershock(w, o, 80.0)
		w.player.shake(4.0, 0.25)
		Sfx.play("thump", 0.1)
	elif n % WBK_SLAM_EVERY == 0:                                # Tectonic Slam
		var at2: Vector2 = o + d * 20.0
		w.fx("shock", at2, LAVA, {"radius": 44.0, "thick": 5.0, "life": 0.3, "col2": GOLD})
		w.fx("crack", at2, BED, {"radius": 44.0, "count": 6, "life": 0.6})
		for e4 in WeaponUtil.enemies_in_circle(w.get_tree(), at2, 44.0):
			WeaponUtil.hit(e4, H(w), o, 180.0, 0.0, "", true)
			WeaponUtil.stun(e4, 0.8)
		Earth.add_fault(w, at2)
		w.player.shake(3.0, 0.2)
		Sfx.play("thump", 0.1)

# ---------- dash: Tectonic Charge ----------

static func dash(w) -> void:
	var o: Vector2 = w.player.global_position
	var d: Vector2 = w.aim
	w.fx("streak", o - d * 60.0, BED, {"dir": d, "length": 60.0, "width": 12.0, "life": 0.3, "col2": LAVA})
	for k in 3:
		Earth.add_fault(w, o - d * (15.0 * float(k + 1)))
	_arrive(w)

static func _arrive(w) -> void:
	if !await WeaponTiers.pause(w, 0.26):
		return
	var p: Vector2 = w.player.global_position
	w.fx("shock", p, LAVA, {"radius": 40.0, "thick": 5.0, "life": 0.3, "col2": GOLD})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 40.0):
		WeaponUtil.hit(e, H(w), p, 160.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.0)
	Earth.aftershock(w, p, 60.0)
	w.player.shake(3.0, 0.2)

static func dash_hit(w, e: Node) -> void:
	Jug.dash_hit(w, e)

# ---------- tick ----------

static func tick(w, _delta: float) -> void:
	var st: Dictionary = w._st
	var now := _now()
	var tree: SceneTree = w.get_tree()
	var a = w._aura
	if a != null and is_instance_valid(a):
		a.state = float(w._stored)
		var d := {"titan": titan(w)}
		var key := str(d)
		if st.pub != key:
			st.pub = key
			a.data = d
	if titan(w):
		if !w._braced:
			w.player.speed_mult = 0.9
		w.scale = Vector2(WBK_TITAN_SCALE, WBK_TITAN_SCALE)
		if now >= float(st.step_next) and w.player.velocity.length() > 8.0:
			st.step_next = now + 0.5
			Earth.add_fault(w, w.player.global_position)
		if now >= float(st.auto_next):
			st.auto_next = now + 1.0
			Earth.aftershock(w, w.player.global_position, 130.0, false)
		if now >= float(st.boulder_next):
			st.boulder_next = now + WBK_BOULDER_EVERY
			var c: Vector2 = w.cursor_target(110.0)
			w.fx("fall", c, BED, {"radius": 10.0, "height": 120.0, "rise": 10.0, "life": 0.6, "core": LAVA})
			w.ground_strike(c, 38.0, 0.6, H(w) * WBK_BOULDER_MULT, 220.0, LAVA, 0.8, ["stone", "stick"])
		if now >= float(st.salvo_next):
			st.salvo_next = now + 1.0
			Jug._salvo(w)
	elif w.scale.x > 1.0:
		w.scale = Vector2.ONE
		if !w._braced:
			w.player.speed_mult = 1.0

# ---------- ultimate: Cataclysm Fortress -> Continental Drift -> Titan -> The Breaking ----------

static func ultimate(w) -> void:
	var st: Dictionary = w._st
	st.ult_id = int(st.ult_id) + 1
	var my: int = st.ult_id
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, LAVA, {"radius": 130.0, "count": 12, "spin": 1.5, "life": 0.4, "col2": GOLD})
	_rain_faults(w, o, my)
	if w.tier >= 5:
		_drift(w, my)
	if w.tier >= 6:
		_titan(w, my)

static func _rain_faults(w, o: Vector2, my: int) -> void:
	for k in 8:                                                  # the rain's eruptions leave faults
		if !await WeaponTiers.pause(w, 0.4):
			return
		if int(w._st.ult_id) != my:
			return
		var a: float = float(k) * 2.399
		Earth.add_fault(w, o + Vector2.from_angle(a) * (30.0 + 12.0 * float(k % 8)))

## Continental Drift: after the final quake the whole area slides toward you for 3 s, then every fault erupts and a second quake lands.
static func _drift(w, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 3.9):
		return
	if int(st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("crack", o, LAVA, {"radius": 130.0, "count": 12, "life": 3.0})
	w.fx("vortex", o, BED, {"radius": 130.0, "count": 3, "spin": 2.5, "inward": true, "life": 1.0})
	Sfx.play("thump", 0.05, 0.8)
	var steps := int(WBK_DRIFT_SECS / 0.4)
	for k in steps:
		o = w.player.global_position
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 130.0):
			Kit.pull(e, o, WBK_DRIFT_PULL, 0.4)
		if k % 2 == 0:
			w.fx("vortex", o, BED, {"radius": 120.0, "count": 3, "spin": 2.5, "inward": true, "life": 0.6})
		if !await WeaponTiers.pause(w, 0.4):
			return
		if int(st.ult_id) != my:
			return
	o = w.player.global_position
	Earth.aftershock(w, o, 9999.0)
	w.ground_strike(o, 90.0, 0.4, H(w) * 1.0, 300.0, LAVA, 0.8, ["stone", "stick"])
	w.player.shake(5.0, 0.3)

## Titan (12 s), then THE BREAKING.
static func _titan(w, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 5.0):
		return
	if int(st.ult_id) != my:
		return
	var now := _now()
	st.titan_until = now + WBK_TITAN_SECS
	st.step_next = 0.0
	st.auto_next = now + 0.5
	st.boulder_next = now + 1.0
	st.salvo_next = now + 0.5
	w.fx("shock", w.player.global_position, LAVA, {"radius": 70.0, "thick": 7.0, "life": 0.5, "col2": GOLD})
	w.player.shake(5.0, 0.3)
	Sfx.play("thump", 0.05, 0.7)
	if !await WeaponTiers.pause(w, WBK_TITAN_SECS):
		return
	if int(st.ult_id) != my:
		return
	st.titan_until = 0.0
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, LAVA, {"radius": 150.0, "count": 16, "spin": 2.0, "life": 0.6, "col2": GOLD})
	if !await WeaponTiers.pause(w, 0.6):
		return
	_breaking(w)

static func _breaking(w) -> void:
	var o: Vector2 = w.player.global_position
	w.fx("crack", o, DEEP_CRACK, {"radius": 180.0, "count": 20, "life": 1.2})
	w.fx("shock", o, LAVA, {"radius": 180.0, "thick": 12.0, "life": 0.6, "col2": GOLD})
	w.fx("flash", o, STEEL, {"radius": 110.0, "life": 0.5})
	w.fx("pillar", o, LAVA, {"height": 200.0, "width": 50.0, "life": 0.8})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, WBK_BREAK_R):
		WeaponUtil.hit(e, H(w) * WBK_BREAK_MULT, o, 480.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.5)
	WeaponUtil.hit_breakables(w.get_tree(), o, WBK_BREAK_R, ["stone", "stick"])
	Earth.aftershock(w, o, 9999.0)                               # every fault erupts once more
	for i in 8:                                                  # the arena is left with eight slow patches
		var p: Vector2 = o + Vector2.from_angle(float(i) * TAU / 8.0 + 0.3) * (50.0 + 12.0 * float(i % 3))
		WeaponUtil.patch(w.game_world(), p, "slow", 30.0, Color(0.30, 0.20, 0.10, 0.55), 6.0, 0.6)
	w.player.shake(9.0, 0.6)
	Sfx.play("thump", 0.02)
	Sfx.play("ultimate", 0.02)
	Sfx.play("gong", 0.02)

const DEEP_CRACK := Color(0.20, 0.12, 0.08)

# ---------- aura: plates and the broken-world halo ----------

static func aura(a, c) -> void:
	var n: int = int(a.state)
	var big: float = 1.3 if a.data.get("titan", false) else 1.0
	for i in n:
		var ang: float = a._age * 1.5 + float(i) * TAU / float(maxi(n, 1))
		Jug._plate(c, Vector2.from_angle(ang) * 16.0 * big, ang, big)
	if a.tier >= 6:                                              # stone fragments orbiting with gaps
		for k in 10:
			var an: float = -a._age * 0.5 + float(k) * TAU / 10.0
			if k % 3 == 0:
				continue
			var q := Vector2.from_angle(an) * 26.0 * big
			c.draw_colored_polygon(PackedVector2Array([q + Vector2(-2, -1.5), q + Vector2(2, -1), q + Vector2(1, 2), q + Vector2(-2, 1.5)]), Color(BED, 0.9))
			c.draw_line(q + Vector2(-1, 0), q + Vector2(1, 0), Color(LAVA, 0.9), 0.8)
	if a.data.get("titan", false):
		c.draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 36, Color(LAVA, 0.35), 2.0)
