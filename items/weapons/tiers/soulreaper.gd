extends RefCounted
## Soulreaper tiers (docs/weapon_tiers/soulreaper.md): 3 Soul Harvest (entry), 4 Reaping Hook, 5 Soul Tide, 6 Grim Reaper.
## Ancient: SOULS are the currency. An enemy that dies within 60 px of you, from one of your hits, or while exposed by you releases a soul that flies to you
## (cap 4/6/8/12 by tier). Souls orbit you and are SPENT: by the swing (tier 4: a homing wisp), by the Grapple (a hook chain), by the Soul Tide; the Grim Reaper's finale
## detonates them all. Souls, ghost reapers and the scythe are drawn by the WeaponAura from `data` {s, ph, rp, sy}. The Fangs' Barbed Chain and the Spellblade's Spirit Blades
## are NOT inherited: souls replace them. The old script (t3/soulreaper.gd) throws the crescent wave; `_st.grapple` is left by the Fangs' old grapple.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const SOUL := Color(0.70, 0.45, 1.0)
const GHOST := Color(0.80, 0.95, 1.0)
const STEEL := Color(0.80, 0.85, 1.0)
const VOID := Color(0.15, 0.08, 0.25)
const SR_SOUL_CAP := [0, 0, 4, 6, 8, 12]
const SR_BOLT_COST := 1
const SR_BOLT_MULT := 0.5
const SR_HOOK_COST := 3
const SR_HOOK_JUMPS := 3
const SR_HOOK_MULT := 0.8
const SR_TIDE_MULT := 0.8
const SR_REAPERS := 2
const SR_REAPER_SECS := 6.0
const SR_REAPER_MULT := 0.6
const SR_EXECUTE := 0.20
const SR_EXECUTE_ULT := 0.25
const SR_REAP_SECS := 12.0
const SR_SCYTHE_EVERY := 1.5
const SR_SCYTHE_R := 90.0
const SR_SCYTHE_MULT := 1.0
const SR_FINALE_PER_SOUL := 0.2
const SR_FINISHER_EVERY := 6
const NAMES := ["", "", "", "Soul Harvest", "Reaping Hook", "Soul Tide", "Grim Reaper"]

static func palette() -> Array:
	return [SOUL, GHOST, STEEL]

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func equip(w) -> void:
	w._st = {"souls": 0, "swings": 0, "ult_id": 0, "watch": {}, "scan": 0.0, "ph": 0.0, "reapers_until": 0.0, "reaper_t": [0.0, 0.5], "scythe_until": 0.0,
		"scythe_t": 0.0, "exec_t": 0.0, "hunt": [], "second": false, "grapple": null, "hooks": 0}

static func cap(w) -> int:
	return int(SR_SOUL_CAP[clampi(w.tier - 1, 0, 5)])

static func souls(w) -> int:
	return int(w._st.get("souls", 0))

## One soul (or n) from a death at `pos`: a wisp flies to you.
static func add_soul(w, pos: Vector2, n := 1) -> void:
	var c := cap(w)
	if c <= 0:
		return
	w._st.souls = mini(c, souls(w) + n)
	w.fx("motes", pos, SOUL, {"radius": 8.0, "count": 6, "rise": 10.0, "life": 0.4})
	Kit.line(w, pos, w.player.global_position, GHOST, 1.5, 0.25)

static func spend(w, n: int) -> bool:
	if souls(w) < n:
		return false
	w._st.souls = souls(w) - n
	return true

static func reapers(w) -> bool:
	return now() < float(w._st.get("reapers_until", 0.0))

static func scythe(w) -> bool:
	return now() < float(w._st.get("scythe_until", 0.0))

## Remember who our hits touched, so that their death is credited (quiet hits are credited by distance).
static func on_hit(w, e, _dmg: float) -> void:
	if is_instance_valid(e):
		e.set_meta("wt_soul", now() + 0.8)

# ---- every frame: the death watch, the orbit angle, the aura data, ghost reapers, the scythe ----
static func tick(w, delta: float) -> void:
	if w.tier < 3:
		return
	var t := now()
	w._st.ph = float(w._st.ph) + 2.0 * delta
	w._st.scan = float(w._st.scan) + delta
	if float(w._st.scan) >= 0.1:
		w._st.scan = 0.0
		_watch(w, t)
	if reapers(w):
		_reapers(w, delta, t)
	if scythe(w):
		_scythe_tick(w, t)
	if w._aura != null and is_instance_valid(w._aura):
		w._aura.data = {"s": souls(w), "ph": w._st.ph, "rp": SR_REAPERS if reapers(w) else 0, "sy": SR_SCYTHE_R if scythe(w) else 0.0}

static func _watch(w, t: float) -> void:
	var list: Dictionary = w._st.watch
	var o: Vector2 = w.player.global_position
	for e in w.get_tree().get_nodes_in_group("enemy"):
		if Kit.alive(e) and float(e.health) > 0.0 and e.global_position.distance_to(o) <= 200.0:
			var id: int = e.get_instance_id()
			var mine: bool = e.global_position.distance_to(o) <= 60.0 or (e.has_meta("wt_soul") and float(e.get_meta("wt_soul")) > t) or WeaponUtil.is_exposed(e)
			if list.has(id):
				list[id][1] = e.global_position
				list[id][2] = list[id][2] or mine
			else:
				list[id] = [e, e.global_position, mine]
	var gone := []
	for id in list:
		var e = list[id][0]
		if !is_instance_valid(e) or e.is_queued_for_deletion() or float(e.health) <= 0.0:
			gone.append(id)
		elif e.global_position.distance_to(o) > 260.0:
			gone.append(-id)
	for g in gone:
		if g < 0:
			list.erase(-g)
			continue
		var rec: Array = list[g]
		list.erase(g)
		if rec[2]:
			add_soul(w, rec[1])

static func aura(a, c) -> void:
	var d: Dictionary = a.data
	var n: int = int(d.get("s", 0))
	for k in n:                                                       # souls: ghost wisps with a trail, orbiting at r 14
		var ang: float = float(d.get("ph", 0.0)) + float(k) * TAU / float(maxi(n, 1))
		for g in 3:
			c.draw_circle(Vector2.from_angle(ang - 0.16 * float(g)) * 14.0, 1.6 - 0.45 * float(g), Color(GHOST if k % 2 == 0 else SOUL, 0.9 - 0.3 * float(g)))
	var rp: int = int(d.get("rp", 0))
	for k in rp:                                                      # ghost reapers: hooded figures at r 50
		var ang2: float = float(d.get("ph", 0.0)) * 0.6 + float(k) * PI
		var p := Vector2.from_angle(ang2) * 50.0
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(-4, 4), p + Vector2(4, 4)]), Color(VOID, 0.85))
		c.draw_circle(p + Vector2(0, -3), 1.2, Color(GHOST, 0.95))
		c.draw_line(p + Vector2(5, -8), p + Vector2(5, 5), Color(STEEL, 0.9), 1.0)
		c.draw_arc(p + Vector2(8, -8), 3.0, PI, TAU * 0.9, 6, Color(STEEL, 0.9), 1.0)
	var sy: float = float(d.get("sy", 0.0))
	if sy > 0.0:                                                      # the giant spectral scythe sweeps its circle
		var ang3: float = fposmod(a._age / SR_SCYTHE_EVERY, 1.0) * TAU
		var dir := Vector2.from_angle(ang3)
		c.draw_line(dir * 12.0, dir * sy, Color(SOUL, 0.7), 2.0)
		c.draw_arc(Vector2.ZERO, sy, ang3 - 0.9, ang3, 12, Color(GHOST, 0.85), 2.0)
	if a.tier >= 6:                                                   # the hooded phantom behind you
		var b: Vector2 = -a.aim * 15.0
		c.draw_colored_polygon(PackedVector2Array([b + Vector2(0, -9), b + Vector2(-5, 5), b + Vector2(5, 5)]), Color(VOID, 0.5))

# ---- attack ----
static func attack(w) -> void:
	w._st.swings = int(w._st.swings) + 1
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	if w.tier >= 4 and souls(w) >= 3 and spend(w, SR_BOLT_COST):
		WeaponProjectile.shoot(w.game_world(), o + dir * 12.0, dir, 220.0, WeaponTiers.H(w) * SR_BOLT_MULT, GHOST, 1.0, 0, 40.0, {"style": "orb", "size": 0.9, "homing": 2.0, "chain": 1, "owner_id": w.player.get_instance_id()})
	if w.tier >= 6 and int(w._st.swings) % SR_FINISHER_EVERY == 0:
		_reaping_cut(w, o, dir)

## Tier 6 finisher: a reaping cut that executes the nearly dead.
static func _reaping_cut(w, o: Vector2, dir: Vector2) -> void:
	w.fx("slash", o, SOUL, {"radius": 50.0, "dir": dir, "half_angle": 1.0, "thick": 8.0, "life": 0.3, "col2": GHOST})
	var h := WeaponTiers.H(w)
	var first := true
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 50.0, 57.0):
		if first:
			w.fx("cut", e.global_position, GHOST, {"radius": 22.0, "spin": 0.0, "life": 0.3, "col2": SOUL})
			first = false
		var at: Vector2 = e.global_position
		WeaponUtil.hit(e, h, o, 60.0, 0.0, "", true, true)
		if Kit.execute(e, SR_EXECUTE):
			add_soul(w, at, 2)

# ---- ability: Harvest Grapple, Reaping Hook ----
static func ability(w) -> void:
	var t = w._st.get("grapple")
	w._st.grapple = null
	if !Kit.alive(t):
		return
	Kit.tether(w, t, 1.5, SOUL, 2.0)
	_group(w, t)

static func _group(w, t) -> void:
	if !await WeaponTiers.pause(w, 0.26):
		return
	var o: Vector2 = w.player.global_position
	var h := WeaponTiers.H(w)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 55.0):               # the pack the old grapple exposed also bleeds
		WeaponUtil.bleed(w.get_tree(), e, 3, h * 0.15)
	if w.tier >= 4 and Kit.alive(t) and spend(w, SR_HOOK_COST):
		_hook(w, t)

## The hook chain: through 3 more enemies within 60 px of each, exposing them and pulling them toward the chain's end.
static func _hook(w, from) -> void:
	var done: Array = [from]
	var cur = from
	var end: Vector2 = from.global_position
	var h := WeaponTiers.H(w)
	var chain := []
	for i in SR_HOOK_JUMPS:
		var nxt = WeaponUtil.nearest(w.get_tree(), cur.global_position, 60.0, done)
		if nxt == null:
			break
		Kit.bolt(w, cur.global_position, nxt.global_position, SOUL, 2.0, 0.25)
		w.fx("burst", nxt.global_position, GHOST, {"radius": 9.0, "life": 0.2})
		WeaponUtil.hit(nxt, h * SR_HOOK_MULT, cur.global_position, 20.0, 0.0, "", true, true)
		WeaponUtil.expose(nxt, 4.0)
		chain.append(nxt)
		done.append(nxt)
		cur = nxt
		end = nxt.global_position
	for e in chain:
		Kit.pull(e, end, 300.0, 0.2)

# ---- dash: Spectral Chains ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, SOUL, {"dir": dir, "length": 40.0, "width": 7.0, "life": 0.25, "col2": GHOST})
	_chains(w, o, o + dir * 40.0)

static func _chains(w, a: Vector2, b: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.12):
		return
	var h := WeaponTiers.H(w)
	for e in Kit.near_segment(w.get_tree(), a, b, 30.0):
		e.apply_slow(0.2, 1.5)
		Kit.line(w, e.global_position, a.lerp(b, 0.5), SOUL, 2.0, 0.4)
		WeaponUtil.hit(e, h * 0.4, a, 0.0, 0.0, "", true, true)

# ---- ultimate: Reap, Soul Tide, Grim Reaper ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	w.fx("sigil", w.player.global_position, SOUL, {"radius": 100.0, "count": 6, "spin": 1.5, "life": 0.3, "col2": GHOST})
	if w.tier >= 5:
		_tide(w, my)
	if w.tier >= 6:
		_grim(w, my)

## Tier 5: after the rain every soul you hold flies out as a homing wisp and two ghost reapers sweep for 6 s.
static func _tide(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 3.5) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("ripple", o, SOUL, {"radius": 100.0, "rings": 2, "life": 0.5})
	var n := mini(souls(w), 8)
	w._st.souls = souls(w) - n
	var h := WeaponTiers.H(w)
	for k in n:
		var d := Vector2.from_angle(float(k) * TAU / float(maxi(n, 1)))
		WeaponProjectile.shoot(w.game_world(), o + d * 12.0, d, 200.0, h * SR_TIDE_MULT, GHOST, 1.2, 1, 60.0, {"style": "orb", "size": 0.9, "homing": 3.0, "owner_id": w.player.get_instance_id()})
	w._st.reapers_until = maxf(float(w._st.reapers_until), now() + SR_REAPER_SECS)

static func _reapers(w, delta: float, t: float) -> void:
	var o: Vector2 = w.player.global_position
	var tm: Array = w._st.reaper_t
	for k in SR_REAPERS:
		tm[k] = float(tm[k]) - delta
		if float(tm[k]) <= 0.0:
			tm[k] = 1.0
			w._claim()
			var ang: float = float(w._st.ph) * 0.6 + float(k) * PI
			var dir := Vector2.from_angle(ang)
			w.fx("slash", o, STEEL, {"radius": 70.0, "dir": dir, "half_angle": 1.05, "thick": 7.0, "life": 0.25, "col2": GHOST})
			for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 70.0, 60.0):
				WeaponUtil.hit(e, WeaponTiers.H(w) * SR_REAPER_MULT, o, 0.0, 0.0, "", true, true)

## FINALE + TRANSFORMATION Grim Reaper (12 s): the scythe, executions, fear; then every soul detonates.
static func _grim(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 4.0) or int(w._st.ult_id) != my:
		return
	w._st.scythe_until = now() + SR_REAP_SECS
	w._st.reapers_until = maxf(float(w._st.reapers_until), now() + SR_REAP_SECS)
	w._st.scythe_t = 0.0
	w.fx("flash", w.player.global_position, SOUL, {"radius": 30.0, "life": 0.3})
	Sfx.play("ultimate", 0.05, 0.8)
	if !await WeaponTiers.pause(w, SR_REAP_SECS) or int(w._st.ult_id) != my:
		return
	_harvest(w)

static func _scythe_tick(w, t: float) -> void:
	var o: Vector2 = w.player.global_position
	if t - float(w._st.scythe_t) >= SR_SCYTHE_EVERY:
		w._st.scythe_t = t
		w._claim()
		w.fx("slash", o, SOUL, {"radius": SR_SCYTHE_R, "dir": Vector2.from_angle(float(w._st.ph)), "half_angle": PI, "thick": 12.0, "life": 0.4, "col2": GHOST})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, SR_SCYTHE_R):
			WeaponUtil.hit(e, WeaponTiers.H(w) * SR_SCYTHE_MULT, o, 0.0, 0.0, "", true, true)
	if t - float(w._st.exec_t) >= 0.25:                               # executions and fear
		w._st.exec_t = t
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 140.0):
			var at: Vector2 = e.global_position
			if Kit.execute(e, SR_EXECUTE_ULT):
				w.fx("cut", at, GHOST, {"radius": 12.0, "spin": 0.0, "life": 0.25, "col2": SOUL})
				add_soul(w, at)
			elif WeaponUtil.is_exposed(e):
				e.apply_slow(0.5, 0.4)

## Reap Harvest: every soul you hold detonates.
static func _harvest(w) -> void:
	var o: Vector2 = w.player.global_position
	var n := mini(souls(w), 12)
	w._st.souls = 0
	var h := WeaponTiers.H(w)
	w.fx("flash", o, GHOST, {"radius": 85.0, "life": 0.4})
	w.fx("ripple", o, SOUL, {"radius": 170.0, "rings": 4, "life": 0.7})
	w.fx("pillar", o, SOUL, {"height": 150.0, "width": 30.0, "life": 0.6})
	w.player.shake(8.0, 0.4)
	Sfx.play("ultimate", 0.05)
	Sfx.play("boss_roar", 0.05, 1.2)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 170.0):
		WeaponUtil.hit(e, h * maxf(1.0, SR_FINALE_PER_SOUL * float(n)), o, 200.0, 0.0, "", true)
		WeaponUtil.stun(e, 0.8)
