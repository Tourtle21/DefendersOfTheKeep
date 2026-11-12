extends RefCounted
## Sword tiers (docs/weapon_tiers/sword.md): 2 Gale, 3 Crescent, 4 Riposte Step, 5 Bladestorm, 6 Last Cut. Common: one clean white shape at a time.
## The Sword is a Tool: its animation hitbox does the basic damage, the riders here time themselves against it (hit about 0.12 s after the click).

const STEEL := Color(0.80, 0.86, 0.95)
const EDGE := Color(0.95, 0.98, 1.0)
const WIND := Color(0.7, 0.85, 1.0)
const CRESCENT_EVERY := 3
const CRESCENT_R := 38.0
const GALE_GROW := [1.0, 1.15, 1.3]
const GALE_PUSH := 300.0
const RETURN_DELAY := 0.14
const BLADE_PULSES := [4, 8, 12, 16]
const FINALE_MULT := 2.5
const FINALE_R := 60.0
const NAMES := ["", "Sword", "Gale", "Crescent", "Riposte Step", "Bladestorm", "Last Cut"]

static func palette() -> Array:
	return [STEEL, WIND, Color(1, 1, 1)]

static func equip(w) -> void:
	w._st = {"swings": 0, "last_ms": -1000, "shine_until": 0.0, "ult_id": 0}

## The shimmer after each swing (tier 2+): the sprite flares towards the edge colour for 0.15 s.
static func tick(w, _delta: float) -> void:
	if w.tier < 2:
		return
	var left: float = float(w._st.get("shine_until", 0.0)) - Time.get_ticks_msec() / 1000.0
	var k := clampf(left / 0.15, 0.0, 1.0)
	w.modulate = Color(1, 1, 1).lerp(Color(1.5, 1.55, 1.65), k)

static func attack(w) -> void:
	var now := Time.get_ticks_msec()
	if now - int(w._st.get("last_ms", -1000)) < 250:        # a held click restarts the animation: count one swing
		return
	w._st.last_ms = now
	w._st.swings = int(w._st.get("swings", 0)) + 1
	w._st.shine_until = now / 1000.0 + 0.15
	if w.tier < 2:
		return
	_swing_riders(w, w.tier >= 3 and int(w._st.swings) % CRESCENT_EVERY == 0)

static func _swing_riders(w, crescent: bool) -> void:
	if await WeaponTiers.pause(w, 0.12):
		var o: Vector2 = w.player.global_position
		var dir: Vector2 = w.aim
		var n := 0
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 26.0 * w.area(), 60.0):
			if n >= 3:
				break
			n += 1
			w.fx("burst", e.global_position, EDGE, {"radius": 8.0, "life": 0.2})
		if crescent:
			var r: float = CRESCENT_R * w.area()
			w.fx("slash", o, EDGE, {"radius": r, "dir": dir, "half_angle": deg_to_rad(65.0), "thick": 7.0, "life": 0.25, "col2": Color(1, 1, 1)})
			w.fx("shards", o + dir * r * 0.7, WIND, {"radius": 22.0, "count": 4, "life": 0.3})
			for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, r, 65.0):
				WeaponUtil.hit(e, WeaponTiers.H(w), o, 120.0)
			Sfx.play("hit", 0.1)

## Tier 2 Gale: the three pulses of Whirlwind grow. Returning null keeps the plain ring.
static func whirl_scale(w, i: int):
	if w.tier < 2:
		return null
	return GALE_GROW[clampi(i, 0, 2)]

static func whirl_pulse(w, i: int, pos: Vector2, r: float) -> void:
	if w.tier < 2:
		return
	w.fx("slash", pos, EDGE, {"radius": r, "dir": Vector2.from_angle(float(i) * 2.1), "half_angle": PI, "thick": 6.0, "life": 0.25, "col2": Color(1, 1, 1)})
	if i == 2:
		w.fx("ring", pos, WIND, {"radius": r, "life": 0.2})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), pos, r):
			if is_instance_valid(e):
				e.push((e.global_position - pos).normalized() * GALE_PUSH, 0.15)
				if e.has_method("apply_slow"):
					e.apply_slow(0.5, 1.0)

static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, WIND, {"dir": dir, "length": 50.0, "width": 5.0, "life": 0.25, "col2": EDGE})
	_return_cut(w, dir)

static func _return_cut(w, dir: Vector2) -> void:
	# Riposte Step: after the arrival slash a return cut sweeps the other way and pulls what it hits towards you
	if await WeaponTiers.pause(w, 0.16 + RETURN_DELAY):
		var pos: Vector2 = w.player.global_position
		w.fx("slash", pos, EDGE, {"radius": 28.0, "dir": -dir, "half_angle": 1.13, "thick": 6.0, "life": 0.2, "col2": Color(1, 1, 1)})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), pos, -dir, 28.0, 65.0):
			WeaponUtil.hit(e, WeaponTiers.H(w), pos, 0.0)
			if is_instance_valid(e):
				e.push((pos - e.global_position).normalized() * 160.0, 0.12)

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var my: int = w._st.ult_id
	var o: Vector2 = w.player.global_position
	var r: float = 44.0 * w.area()
	w.fx("sigil", o, WIND, {"radius": r, "count": 6, "spin": 1.5, "life": 0.25, "col2": EDGE})
	if w.tier < 5:
		return
	for k in BLADE_PULSES.size():
		var idx: int = BLADE_PULSES[k]
		_blades(w, my, idx, (idx - 1) * 0.15)
	for k in 4:
		_orbit(w, my, k * 0.6)
	if w.tier >= 6:
		_finale(w, my)

static func _orbit(w, my: int, delay: float) -> void:
	if await WeaponTiers.pause(w, delay + 0.001):
		if int(w._st.ult_id) != my:
			return
		w.fx("orbit", w.player.global_position, EDGE, {"radius": 40.0 * w.area(), "count": 4, "spin": 8.0, "shape": "blade", "life": 0.7})

static func _blades(w, my: int, idx: int, delay: float) -> void:
	if await WeaponTiers.pause(w, delay + 0.001):
		if int(w._st.ult_id) != my:
			return
		var o: Vector2 = w.player.global_position
		var a := float(idx) * 0.7
		for s in 2:
			var d := Vector2.from_angle(a + float(s) * PI)
			WeaponProjectile.shoot(w.game_world(), o + d * 8.0, d, 240.0, WeaponTiers.H(w) * 0.5, EDGE, 0.3, 1, 60.0, {"style": "blade", "size": 0.8})

## FINALE Last Cut: 0.2 s after the last pulse an X-cut and a shock ring land.
static func _finale(w, my: int) -> void:
	if await WeaponTiers.pause(w, 15 * 0.15 + 0.2):
		if int(w._st.ult_id) != my:
			return
		var o: Vector2 = w.player.global_position
		var r: float = FINALE_R * w.area()
		w.fx("cut", o, EDGE, {"radius": 40.0 * w.area(), "spin": 0.0, "life": 0.35})
		w.fx("shock", o, WIND, {"radius": r, "thick": 6.0, "life": 0.4, "col2": EDGE})
		w.fx("flash", o, EDGE, {"radius": 26.0, "life": 0.3})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, r):
			WeaponUtil.hit(e, WeaponTiers.H(w) * FINALE_MULT, o, 300.0, 0.0, "", true)
		w.player.shake(4.5, 0.3)
		Sfx.play("big_hit", 0.05)
