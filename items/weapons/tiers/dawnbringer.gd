extends RefCounted
## Dawnbringer tiers (docs/weapon_tiers/dawnbringer.md), LEGENDARY: 2 First Light, 3 Halo, 4 Sunrise, 5 High Noon, 6 Dawn of Days.
## THE SYSTEM: Radiance (0 to 100, aura `state`): hits +2, kills +6, Daybreak +30, Sun Dash +10; it fades 6 a second after 4 s. At 100 the blade is ZENITH
## for 8 s (once per 15 s): every slash is a sun wave and the ability costs half the cooldown. Everything here is light: nothing hurts a player,
## every effect is a WeaponFx, a net projectile, a LightSource or a heal Hazard. Hook functions never suspend (they run through callv).

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const SUN := Color(1.0, 0.92, 0.55)
const GOLD := Color(1.0, 0.78, 0.25)
const CORE := Color(1.0, 0.99, 0.90)
const ROSE := Color(1.0, 0.60, 0.45)
const HALO := Color(1.0, 0.95, 0.70)
const DB_RAD_HIT := 2
const DB_RAD_KILL := 6
const DB_RAD_DECAY := 6.0
const DB_ZENITH_SECS := 8.0
const DB_ZENITH_CD := 15.0
const DB_RAY_EVERY := 3
const DB_WAVE_EVERY := 3
const DB_WAVE_MULT := 1.0
const DB_SUNS := [0, 0, 3, 5, 8, 12]
const DB_SUN_MULT := 0.3
const DB_SUN_TICK := 0.6
const DB_NOON_MULT := 2.0
const DB_NOON_SECS := 8.0
const DB_NOON_EVERY := 0.5
const DB_NOON_BEAM := 0.8
const DB_SUNSPEARS := 6
const DB_DAWN_SECS := 15.0
const DB_CORONA_R := 60.0
const DB_CORONA_MULT := 0.15
const DB_COLUMNS := 5
const DB_COLUMN_MULT := 1.5
const DB_FINALE_MULT := 3.0
const DB_HEAL_FRAC := 0.4
const DB_FINISHER_EVERY := 6
const DB_LIGHT_BONUS := [0, 20, 40, 60, 80, 120]
const DB_PROJ_CAP := 40
const NAMES := ["", "Dawnbringer", "First Light", "Halo", "Sunrise", "High Noon", "Dawn of Days"]

static func palette() -> Array:
	return [SUN, GOLD, CORE]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func H(w) -> float:
	return WeaponTiers.H(w)

static func equip(w) -> void:
	w._st = {"rad": 0.0, "last_gain": -10.0, "zenith_until": 0.0, "zenith_cd": 0.0, "locked": false, "swings": 0, "last_ms": -1000, "watch": [], "lights": [],
		"day": {}, "rays_until": 0.0, "rays_c": Vector2.ZERO, "rays_next": 0.0, "noon_until": 0.0, "noon_c": Vector2.ZERO, "noon_next": 0.0, "ult_id": 0,
		"corona_next": 0.0, "pub": "", "heal_total": 0.0, "heal_t0": 0.0, "day_next": 0.0, "sigil_next": 0.0, "dawn_until": 0.0, "dawn_next": 0.0}

static func rad(w) -> float:
	return float(w._st.rad)

static func zenith(w) -> bool:
	return float(w._st.zenith_until) > _now() or bool(w._st.locked)

static func suns(w) -> int:
	return int(DB_SUNS[clampi(w.tier - 1, 0, 5)])

static func add_rad(w, n: float) -> void:
	var st: Dictionary = w._st
	st.last_gain = _now()
	if bool(st.locked):
		st.rad = 100.0
		return
	st.rad = minf(100.0, float(st.rad) + n)
	if float(st.rad) >= 100.0 and _now() >= float(st.zenith_cd) and float(st.zenith_until) <= _now():
		st.zenith_until = _now() + DB_ZENITH_SECS
		st.zenith_cd = _now() + DB_ZENITH_CD
		w.fx("flash", w.player.global_position, CORE, {"radius": 40.0, "life": 0.4})
		w.fx("star", w.player.global_position, GOLD, {"radius": 24.0, "count": 8, "spin": 1.0, "life": 0.5})
		Sfx.play("unlock", 0.05)

static func _ready_cd(e, key: String, secs: float) -> bool:
	var k := "wt_" + key
	var now := _now()
	if e.has_meta(k) and float(e.get_meta(k)) > now:
		return false
	e.set_meta(k, now + secs)
	return true

## A light that respects the cap of three alive per player: the oldest goes first.
static func _light(w, pos: Vector2, r: float, secs: float, col: Color) -> void:
	var l: Array = w._st.lights
	for i in range(l.size() - 1, -1, -1):
		if !is_instance_valid(l[i]):
			l.remove_at(i)
	while l.size() >= 3:
		var old = l.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	l.append(LightSource.spawn(w.game_world(), pos, r, secs, col))

static func _heal(w, c: Vector2, r: float, amount: float) -> void:
	for p in w.get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p.global_position.distance_to(c) <= r:
			p.heal(amount)

# ---------- hits and kills ----------

static func on_hit(w, e: Node, _dmg: float) -> void:
	if w.tier < 2 or !is_instance_valid(e):
		return
	add_rad(w, DB_RAD_HIT)
	var wl: Array = w._st.watch
	for x in wl:
		if x.e == e:
			x.t = _now()
			return
	if wl.size() < 40:
		wl.append({"e": e, "pos": e.global_position, "t": _now()})

static func _kills(w) -> void:
	var wl: Array = w._st.watch
	var now := _now()
	for i in range(wl.size() - 1, -1, -1):
		var x = wl[i]
		if is_instance_valid(x.e) and !x.e.is_queued_for_deletion():
			x.pos = x.e.global_position
			if now - float(x.t) > 6.0:
				wl.remove_at(i)
			continue
		wl.remove_at(i)
		if now - float(x.t) < 3.0:
			add_rad(w, DB_RAD_KILL)
			if w.tier >= 4:                                   # a lit enemy dies: a sunspark heals you a little (10 per 10 s at most)
				if now - float(w._st.heal_t0) > 10.0:
					w._st.heal_t0 = now
					w._st.heal_total = 0.0
				if float(w._st.heal_total) < 10.0:
					w._st.heal_total = float(w._st.heal_total) + 1.0
					w.player.heal(1.0)
					w.fx("motes", x.pos, SUN, {"radius": 8.0, "count": 4, "rise": 14.0, "life": 0.5})

# ---------- attack ----------

static func attack(w) -> void:
	var st: Dictionary = w._st
	var ms := Time.get_ticks_msec()
	if ms - int(st.last_ms) < 200:
		return
	st.last_ms = ms
	if w.tier < 2:
		return
	st.swings = int(st.swings) + 1
	var n: int = st.swings
	var o: Vector2 = w.player.global_position
	var d: Vector2 = w.aim
	w.fx("slash", o, GOLD, {"radius": 46.0, "dir": d, "half_angle": 0.7, "thick": 6.0, "life": 0.22, "col2": CORE})
	w.fx("motes", o + d * 30.0, SUN, {"radius": 14.0, "count": 3, "rise": 16.0, "life": 0.5})
	var z: bool = zenith(w)
	if n % DB_RAY_EVERY == 0:                              # First Light: a ray straight ahead
		w.fx("beam", o + d * 8.0, SUN, {"dir": d, "length": 80.0, "width": 4.0, "life": 0.3, "col2": CORE})
		for e in WeaponUtil.enemies_in_line(w.get_tree(), o, d, 80.0, 6.0):
			WeaponUtil.hit(e, H(w) * 0.5, o, 30.0, 0.0, "", true, true)
			Game.light_up(e, 4.0)
	if w.tier >= 3 and (n % DB_WAVE_EVERY == 0 or z):     # Halo: a sun wave; Sunrise: three of them
		_wave(w, o, d)
	if w.tier >= 5 and rad(w) > 50.0:                      # High Noon: a sunbeam through everything
		w.fx("beam", o + d * 8.0, GOLD, {"dir": d, "length": 100.0, "width": 8.0, "life": 0.3, "col2": CORE})
		for e in WeaponUtil.enemies_in_line(w.get_tree(), o, d, 100.0, 8.0):
			WeaponUtil.hit(e, H(w) * 0.8, o, 40.0, 0.0, "", true, true)
			Game.light_up(e, 3.0)
	if w.tier >= 6 and n % DB_FINISHER_EVERY == 0:         # Sun Crown
		_crown(w, o)

static func _wave(w, o: Vector2, d: Vector2) -> void:
	var fan: Array = [0.0] if w.tier < 4 else [-0.35, 0.0, 0.35]
	if zenith(w) and w.tier >= 4:
		fan = [-0.5, -0.25, 0.0, 0.25, 0.5]
	var mult: float = DB_WAVE_MULT if w.tier < 4 else 0.6
	for a in fan:
		if WeaponProjectile.alive(w.get_tree()) >= DB_PROJ_CAP:
			break
		var dir: Vector2 = d.rotated(float(a))
		WeaponProjectile.shoot(w.game_world(), o + dir * 12.0, dir, 260.0, H(w) * mult, GOLD, 0.5, 5, 60.0, {"style": "crescent", "size": 2.0, "glow": 0.5, "owner_id": w.player.get_instance_id(), "on_hit_fx": "burst"})

static func _crown(w, o: Vector2) -> void:
	w.fx("ripple", o, SUN, {"radius": 80.0, "rings": 2, "life": 0.5})
	for k in 12:
		var d := Vector2.from_angle(float(k) * TAU / 12.0)
		w.fx("beam", o + d * 8.0, SUN, {"dir": d, "length": 72.0, "width": 5.0, "life": 0.35, "col2": CORE})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 80.0):
		WeaponUtil.hit(e, H(w) * 0.5 * 2.0, o, 60.0, 0.0, "", true, true)      # (each enemy meets one beam in the ring: 12 beams of 0.5 H over a crowd)
		Game.light_up(e, 4.0)
	_heal(w, o, 80.0, 5.0)
	Sfx.play("big_hit", 0.1, 1.2)

# ---------- ability: Daybreak ----------

static func ability(w) -> void:
	if w.tier < 2:
		return
	var st: Dictionary = w._st
	var c: Vector2 = w.cursor_target(90.0)
	add_rad(w, 30.0)
	w.fx("ripple", c, SUN, {"radius": 110.0, "rings": 3, "life": 0.8})
	var secs: float = 14.0 if w.tier >= 3 else 6.0
	WeaponUtil.patch(w.game_world(), c, "heal", 60.0, Color(1.0, 0.95, 0.6, 0.22), 6.0)
	st.rays_until = _now() + 3.0
	st.rays_c = c
	st.rays_next = 0.0
	st.day = {"pos": c, "t0": _now(), "until": _now() + secs}
	st.day_next = _now() + 1.0
	st.sigil_next = _now()
	if w.tier >= 3:
		_heal(w, c, 120.0, 15.0)                           # Halo: players heal 60% faster (45 -> 60)
	if w.tier >= 4:
		_dawn_ring(w, c)
	if w.tier >= 5:
		_noon(w, c)
	if w.tier >= 6:
		for p in w.get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.global_position.distance_to(c) <= 120.0:
				p.shield_time = maxf(p.shield_time, 1.0)    # Dawn of Days: one second of cover (never more than that)
	if zenith(w):
		w._ability_cd = w.ability_cooldown * 0.5

## Sunrise: the ring of dawn spreads from 60 to 150 px in 1.5 s, hits each enemy once and lights them for 12 s.
static func _dawn_ring(w, c: Vector2) -> void:
	w.fx("pillar", c, SUN, {"height": 60.0, "width": 20.0, "life": 0.9})
	var hit := {}
	for k in 15:
		var r: float = lerpf(60.0, 150.0, float(k) / 14.0)
		w.fx("shock", c, GOLD, {"radius": r, "thick": 3.0, "life": 0.25, "col2": CORE})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, r):
			if !hit.has(e):
				hit[e] = true
				WeaponUtil.hit(e, H(w) * 0.5 * (1.0 if hit.size() == 1 else 1.0), c, 40.0, 0.0, "", true, true)
				Game.light_up(e, 12.0)
		for p in w.get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.global_position.distance_to(c) <= r and k % 5 == 0:
				w.fx("star", p.global_position, SUN, {"radius": 8.0, "count": 4, "spin": 1.0, "life": 0.4})
		if !await WeaponTiers.pause(w, 0.1):
			return

## High Noon: 1 s after the cast a noon beam falls on the centre, and eight sunspears fly out.
static func _noon(w, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.0):
		return
	w.fx("fall", c, SUN, {"radius": 8.0, "height": 120.0, "rise": 0.0, "life": 0.3, "core": CORE})
	w.fx("pillar", c, SUN, {"height": 160.0, "width": 40.0, "life": 0.6})
	w.ground_strike(c, 40.0, 0.05, H(w) * DB_NOON_MULT, 200.0, GOLD, 0.8)
	for k in 8:
		var d := Vector2.from_angle(float(k) * TAU / 8.0)
		if WeaponProjectile.alive(w.get_tree()) < DB_PROJ_CAP:
			WeaponProjectile.shoot(w.game_world(), c + d * 10.0, d, 220.0, H(w) * 0.6, SUN, 0.5, 2, 60.0, {"style": "lance", "glow": 0.4, "owner_id": w.player.get_instance_id()})
	w.player.shake(3.0, 0.2)
	Sfx.play("big_hit", 0.1)

# ---------- dash: Sun Dash ----------

static func pre_dash(w) -> void:
	w._st.dash_from = w.player.global_position

static func dash(w) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w._st.get("dash_from", w.player.global_position)
	var d: Vector2 = w.aim
	add_rad(w, 10.0)
	w.fx("streak", o, GOLD, {"dir": d, "length": 60.0, "width": 8.0, "life": 0.3, "col2": CORE})
	w.fx("ripple", o + d * 30.0, SUN, {"radius": 30.0, "rings": 2, "life": 0.6})
	_light(w, o + d * 30.0, 80.0, 6.0, SUN)                  # the lit trail stays 6 s
	if w.tier >= 4:
		_wall(w, o, d)

static func dash_hit(w, e: Node) -> void:
	if w.tier >= 2 and is_instance_valid(e):
		Game.light_up(e, 6.0)

## Sunrise Dash: a wall of sun along the path, a flash and a ring of six sunsparks at the arrival.
static func _wall(w, o: Vector2, d: Vector2) -> void:
	for k in 5:
		w.fx("pillar", o + d * (12.0 * float(k + 1)), SUN, {"height": 24.0, "width": 8.0, "life": 1.0})
	for e in Kit.near_segment(w.get_tree(), o, o + d * 60.0, 10.0):
		WeaponUtil.hit(e, H(w) * 0.4, o, 20.0, 0.0, "", true, true)
	if !await WeaponTiers.pause(w, 0.16):
		return
	var p: Vector2 = w.player.global_position
	w.fx("flash", p, CORE, {"radius": 30.0, "life": 0.35})
	for k in 6:
		var dd := Vector2.from_angle(float(k) * TAU / 6.0)
		if WeaponProjectile.alive(w.get_tree()) < DB_PROJ_CAP:
			WeaponProjectile.shoot(w.game_world(), p + dd * 6.0, dd, 200.0, H(w) * 0.4, SUN, 0.3, 0, 40.0, {"style": "orb", "owner_id": w.player.get_instance_id()})

# ---------- tick ----------

static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	var st: Dictionary = w._st
	var now := _now()
	var tree: SceneTree = w.get_tree()
	var o: Vector2 = w.player.global_position
	_kills(w)
	# radiance: fades after 4 s without a gain; ZENITH drains it over its 8 s
	if bool(st.locked):
		st.rad = 100.0
	elif float(st.zenith_until) > now:
		st.rad = 100.0 * (float(st.zenith_until) - now) / DB_ZENITH_SECS
	elif now - float(st.last_gain) > 4.0:
		st.rad = maxf(0.0, float(st.rad) - DB_RAD_DECAY * delta)
	# Daybreak: three turning rays for 3 s, the circle's sigil and (tier 6) its beam
	if now < float(st.rays_until) and now >= float(st.rays_next):
		st.rays_next = now + 0.25
		var c: Vector2 = st.rays_c
		var ph: float = (3.0 - (float(st.rays_until) - now)) * 1.5
		var burn: bool = _ready_cd(w, "rays", 0.5)
		for k in 3:
			var d := Vector2.from_angle(ph + float(k) * TAU / 3.0)
			w.fx("beam", c, SUN, {"dir": d, "length": 110.0, "width": 6.0, "life": 0.3, "col2": CORE})
			if burn:
				for e in WeaponUtil.enemies_in_line(tree, c, d, 110.0, 8.0):
					if _ready_cd(e, "ray", 0.45):
						WeaponUtil.hit(e, H(w) * 0.25, c, 0.0, 0.0, "", true, true)
	var day: Dictionary = st.day
	if !day.is_empty() and now < float(day.until):
		if w.tier >= 3 and now >= float(st.sigil_next):
			st.sigil_next = now + 1.2
			var r: float = lerpf(110.0, 140.0, minf(1.0, (now - float(day.t0)) / 2.0))
			w.fx("sigil", day.pos, GOLD, {"radius": r * 0.8, "count": 12, "spin": 0.6, "life": 1.3, "col2": CORE})
		if w.tier >= 6 and now >= float(st.day_next):
			st.day_next = now + 1.0
			var tgt = WeaponUtil.nearest(tree, day.pos, 140.0)
			if tgt != null:
				var dd: Vector2 = (tgt.global_position - day.pos).normalized()
				w.fx("beam", day.pos, SUN, {"dir": dd, "length": day.pos.distance_to(tgt.global_position), "width": 3.0, "life": 0.25, "col2": CORE})
				WeaponUtil.hit(tgt, H(w) * 0.5, day.pos, 0.0, 0.0, "", true, true)
	# Halo: the sun orbs burn what they touch
	var n := suns(w)
	if n > 0:
		var age: float = float(w._aura._age) if w._aura != null and is_instance_valid(w._aura) else 0.0
		for i in n:
			var p: Vector2 = o + sun_off(i, n, age)
			for e in WeaponUtil.enemies_in_circle(tree, p, 6.0):
				if _ready_cd(e, "sun", DB_SUN_TICK):
					WeaponUtil.hit(e, H(w) * DB_SUN_MULT, p, 0.0, 0.0, "", true, true)
					Game.light_up(e, 3.0)
	# High Noon: the corona burns what stands close
	if w.tier >= 5 and (rad(w) > 50.0 or zenith(w)) and now >= float(st.corona_next):
		st.corona_next = now + 0.4
		var cr: float = 40.0 if !bool(st.locked) else DB_CORONA_R
		for e in WeaponUtil.enemies_in_circle(tree, o, cr):
			if _ready_cd(e, "corona", 0.8 if !bool(st.locked) else 0.5):
				WeaponUtil.hit(e, H(w) * (0.2 if !bool(st.locked) else DB_CORONA_MULT), o, 0.0, 0.0, "", true, true)
	# the noon sun: a sunbeam on the nearest enemy every 0.5 s
	if now < float(st.noon_until) and now >= float(st.noon_next):
		st.noon_next = now + DB_NOON_EVERY
		var nc: Vector2 = st.noon_c
		var t2 = WeaponUtil.nearest(tree, nc, 170.0)
		if t2 != null:
			var tp: Vector2 = t2.global_position
			w.fx("beam", tp + Vector2(0, -110), SUN, {"dir": Vector2(0, 1), "length": 110.0, "width": 6.0, "life": 0.3, "col2": CORE})
			WeaponUtil.hit(t2, H(w) * DB_NOON_BEAM, tp, 20.0, 0.0, "", true, true)
			Game.light_up(t2, 3.0)
	_publish(w)

static func sun_off(i: int, n: int, age: float) -> Vector2:
	return Vector2.from_angle(age * 1.6 + float(i) * TAU / float(maxi(n, 1))) * 28.0

static func _publish(w) -> void:
	var a = w._aura
	if a == null or !is_instance_valid(a):
		return
	a.state = rad(w)
	var d := {"suns": suns(w), "wings": rad(w) > 50.0 and w.tier >= 4, "zenith": zenith(w), "dawn": float(w._st.dawn_until) > _now()}
	var key := str(d)
	if w._st.pub != key:
		w._st.pub = key
		a.data = d

# ---------- ultimate: Solar Judgment -> High Noon -> Dawn of Days ----------

static func ultimate(w) -> void:
	var st: Dictionary = w._st
	st.ult_id = int(st.ult_id) + 1
	var c: Vector2 = w.cursor_target(120.0)
	w.fx("sigil", c, GOLD, {"radius": 130.0, "count": 16, "spin": 1.0, "life": 0.4, "col2": CORE})
	w.fx("fall", c + Vector2(0, 0), SUN, {"radius": 4.0, "height": 100.0, "rise": 0.0, "life": 0.5, "core": CORE})
	if w.tier >= 5:
		_noon_sun(w, c, int(st.ult_id))

static func _noon_sun(w, c: Vector2, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 3.2):
		return
	if int(st.ult_id) != my:
		return
	st.noon_until = _now() + DB_NOON_SECS
	st.noon_c = c
	st.noon_next = _now()
	_light(w, c, 220.0, DB_NOON_SECS, HALO)
	w.fx("sigil", c, GOLD, {"radius": 140.0, "count": 12, "spin": 0.8, "life": 1.0, "col2": CORE})
	# six sunspears fall on the six strongest enemies near the centre
	var all: Array = WeaponUtil.enemies_in_circle(w.get_tree(), c, 140.0)
	all.sort_custom(func(a, b): return float(a.max_health) > float(b.max_health))
	for i in mini(DB_SUNSPEARS, all.size()):
		var e = all[i]
		if is_instance_valid(e):
			var p: Vector2 = e.global_position
			w.fx("fall", p, SUN, {"radius": 5.0, "height": 120.0, "rise": 10.0, "life": 0.45, "core": CORE})
			w.ground_strike(p, 16.0, 0.4, H(w), 140.0, GOLD, 0.0)
		if !await WeaponTiers.pause(w, 0.08):
			return
	Sfx.play("big_hit", 0.1, 0.8)
	if w.tier >= 6:
		_dawn(w, c, my)

static func _dawn(w, c: Vector2, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, DB_NOON_SECS - 0.5):
		return
	if int(st.ult_id) != my:
		return
	# Beat 1: a white flash across the screen and the one slow-motion beat
	var o: Vector2 = w.player.global_position
	w.fx("flash", o, CORE, {"radius": 160.0, "life": 0.6})
	Game.hit_stop(0.3)
	Sfx.play("gong", 0.02)
	# Beat 2: ZENITH locked on for 15 s
	if !await WeaponTiers.pause(w, 0.3):
		return
	var now := _now()
	st.locked = true
	st.rad = 100.0
	st.zenith_until = now + DB_DAWN_SECS
	st.dawn_until = now + DB_DAWN_SECS
	st.dawn_next = now
	st.corona_next = now
	w.fx("star", o, GOLD, {"radius": 40.0, "count": 12, "spin": 1.5, "life": 0.7})
	w.player.shake(5.0, 0.3)
	# Beat 3: the sunrise (columns of light sweep the screen) ... Beat 4: the sunspears
	if !await WeaponTiers.pause(w, 0.7):
		return
	_sunrise(w, my)
	if !await WeaponTiers.pause(w, 3.0):
		return
	_spears(w)
	# Beat 5: the Dawn
	if !await WeaponTiers.pause(w, DB_DAWN_SECS - 4.0):
		return
	if int(st.ult_id) != my:
		return
	st.locked = false
	st.dawn_until = 0.0
	st.zenith_until = 0.0
	st.rad = 0.0
	o = w.player.global_position
	w.fx("sigil", o, GOLD, {"radius": 150.0, "count": 16, "spin": 2.0, "life": 0.6, "col2": CORE})
	if !await WeaponTiers.pause(w, 0.6):
		return
	_the_dawn(w)

## The sunrise: a disc rises on the far side and five columns of light sweep across the screen over 2.5 s, striking along their path.
static func _sunrise(w, my: int) -> void:
	var st: Dictionary = w._st
	var o: Vector2 = w.player.global_position
	var away: Vector2 = -w.aim
	var side: Vector2 = away.orthogonal()
	w.fx("flash", o + away * 150.0, CORE, {"radius": 70.0, "life": 1.0})
	for step in 6:
		if int(st.ult_id) != my or !WeaponTiers.alive(w):
			return
		o = w.player.global_position
		var u: float = float(step) / 5.0
		for k in DB_COLUMNS:
			var p: Vector2 = o + side * lerpf(-130.0, 130.0, u) + (-away) * (float(k) - 2.0) * 38.0
			w.fx("pillar", p, SUN, {"height": 220.0, "width": 50.0, "life": 0.6})
			w.ground_strike(p, 44.0, 0.3, H(w) * DB_COLUMN_MULT, 120.0, GOLD, 0.6)
		w.player.shake(2.0, 0.15)
		if !await WeaponTiers.pause(w, 0.5):
			return

static func _spears(w) -> void:
	var o: Vector2 = w.player.global_position
	var all: Array = WeaponUtil.enemies_in_circle(w.get_tree(), o, 200.0)
	all.shuffle()
	for i in mini(12, all.size()):
		var e = all[i]
		if is_instance_valid(e):
			var p: Vector2 = e.global_position
			w.fx("fall", p, SUN, {"radius": 5.0, "height": 130.0, "rise": 10.0, "life": 0.45, "core": CORE})
			w.ground_strike(p, 18.0, 0.4, H(w), 140.0, GOLD, 0.0)
			Game.light_up(e, 6.0)

## FINALE: the Dawn. Everything within 150 px takes 3.0 H, is lit and thrown back; allies heal 40%; light for 10 s.
static func _the_dawn(w) -> void:
	var o: Vector2 = w.player.global_position
	w.fx("flash", o, CORE, {"radius": 150.0, "life": 0.6})
	for k in 8:
		w.fx("pillar", o + Vector2.from_angle(float(k) * TAU / 8.0) * 110.0, SUN, {"height": 200.0, "width": 40.0, "life": 0.8})
	w.fx("ripple", o, GOLD, {"radius": 180.0, "rings": 4, "life": 0.9})
	w.fx("star", o, CORE, {"radius": 150.0, "count": 16, "spin": 1.0, "life": 0.8})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 150.0):
		WeaponUtil.hit(e, H(w) * DB_FINALE_MULT, o, 400.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.2)
		Game.light_up(e, 10.0)
	_heal(w, o, 400.0, DB_HEAL_FRAC * 228.0 * Game.hp_scale())
	_light(w, o, 260.0, 10.0, HALO)
	w.player.shake(9.0, 0.6)
	Sfx.play("ultimate", 0.02)
	Sfx.play("gong", 0.02)
	Sfx.play("chest", 0.05)

# ---------- aura: the corona, the suns, the wings, the zenith sun ----------

static func aura(a, c) -> void:
	var d: Dictionary = a.data
	var head: Vector2 = a.aim.rotated(a.swing) * a.reach
	var r: float = a.state
	if r > 4.0:                                              # corona round the blade, rays by radiance
		c.draw_arc(head, 6.0 + r / 10.0, 0.0, TAU, 24, Color(GOLD, 0.35 + r / 250.0), 1.2)
		var rays: int = int(r / 10.0)
		for k in rays:
			var ang: float = a._age * 0.7 + float(k) * TAU / float(maxi(rays, 1))
			c.draw_line(head + Vector2.from_angle(ang) * (6.0 + r / 10.0), head + Vector2.from_angle(ang) * (9.0 + r / 7.0), Color(SUN, 0.8), 1.0)
	var n: int = int(d.get("suns", 0))
	for i in n:
		var p: Vector2 = sun_off(i, n, a._age)
		c.draw_circle(p, 4.0, Color(SUN, 0.25))
		c.draw_circle(p, 2.2, GOLD)
		c.draw_circle(p, 1.0, CORE)
	if d.get("wings", false):
		var back: Vector2 = -a.aim
		var feathers: int = 4 if a.tier >= 6 else 3
		for s in [-1.0, 1.0]:
			for f in feathers:
				var ang2: float = back.angle() + float(s) * (0.7 + 0.28 * float(f))
				var len: float = 14.0 + 3.0 * float(f) + (5.0 if a.tier >= 5 else 0.0)
				c.draw_line(Vector2.from_angle(ang2) * 5.0, Vector2.from_angle(ang2) * len, Color(HALO, 0.8), 2.0)
				c.draw_line(Vector2.from_angle(ang2) * 5.0, Vector2.from_angle(ang2) * len, Color(CORE, 0.9), 0.8)
	if d.get("zenith", false):                               # a small sun floats over your head
		var sp := Vector2(0, -22.0 + 1.5 * sin(a._age * 3.0))
		c.draw_circle(sp, 7.0, Color(GOLD, 0.3))
		c.draw_circle(sp, 4.0, SUN)
		for k in 8:
			var ra: float = a._age + float(k) * TAU / 8.0
			c.draw_line(sp + Vector2.from_angle(ra) * 5.0, sp + Vector2.from_angle(ra) * 9.0, Color(SUN, 0.8), 1.0)
	if a.tier >= 6 and d.get("dawn", false):
		for k in 16:
			var ang3: float = a._age * 0.4 + float(k) * TAU / 16.0
			c.draw_line(Vector2.from_angle(ang3) * 36.0, Vector2.from_angle(ang3) * 44.0, Color(CORE, 0.7), 1.0)
