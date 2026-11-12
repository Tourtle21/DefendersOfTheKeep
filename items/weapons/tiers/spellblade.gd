extends RefCounted
## Spellblade tiers (docs/weapon_tiers/spellblade.md): 2 Spellweave, 3 Sword Choir, 4 Phantom Edge, 5 Blade Tempest, 6 Sword Saint.
## Mythic: a SYSTEM you build and spend. SPIRIT BLADES (every second wave slash that hits conjures one; max 2/3/4/5/6 by tier) orbit you for good and cut what they touch;
## they are thrown, fired and joined by the storm blades. The ultimate turns you into a Sword Saint with a spectral avatar.
## Everything that orbits is drawn by the WeaponAura from its `data` {ph: storm angle, n: storm blades, r: storm radius, sp: spirit blades, sph: spirit angle, av: avatar}
## so LAN clients see the same blades (the old weapon drew its storm blades only on the host). Starfall extends the old script and may call draw_blades() too.
## The old weapon (t2/spellblade.gd) gives `storm_bonus`, `storm_r`, `hit_gap`, `blades_now()` and calls the `blade_hit` hook.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const BLUE := Color(0.70, 0.80, 1.0)
const VIOLET := Color(0.60, 0.45, 1.0)
const FIRE := Color(1.0, 0.60, 0.25)
const WHITE := Color(0.97, 0.98, 1.0)
const GOLD := Color(1.0, 0.92, 0.6)
const SB_SPIRIT_MAX := [0, 2, 3, 4, 5, 6]
const SB_SPIRIT_MULT := 0.3
const SB_SPIRIT_TICK := 0.6
const SB_STORM_R := 26.0
const SB_STORM_R3 := 40.0
const SB_THROWN_MULT := 0.8
const SB_PHANTOM_EVERY := 4
const SB_CYCLONE_SECS := 2.0
const SB_RING_N := 12
const SB_SAINT_SECS := 10.0
const SB_AVATAR_MULT := 1.0
const SB_FINALE_MULT := 3.0
const SB_FINISHER_EVERY := 6
const SB_LIGHT_BONUS := [0, 5, 10, 15, 20, 30]
const NAMES := ["", "", "Spellweave", "Sword Choir", "Phantom Edge", "Blade Tempest", "Sword Saint"]

static func palette() -> Array:
	return [BLUE, VIOLET, WHITE]

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func equip(w) -> void:
	w._st = {"slashes": 0, "waves": 0, "spirit": 0, "spirit_angle": 0.0, "spirit_hit": {}, "away_until": 0.0, "hit_ms": -1000, "chain": 0,
		"storm_was": false, "storm_t0": 0.0, "sigil": 0.0, "saint_until": 0.0, "ult_id": 0}
	WeaponTiers.light_bonus(w, SB_LIGHT_BONUS)

static func spirit_max(w) -> int:
	return int(SB_SPIRIT_MAX[clampi(w.tier - 1, 0, 5)])

static func saint(w) -> bool:
	return now() < float(w._st.get("saint_until", 0.0))

static func spirit_count(w) -> int:
	return spirit_max(w) if saint(w) else int(w._st.get("spirit", 0))

# ---- every frame: the storm's size, the spirit blades' contact, the data the aura draws ----
static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	var t := now()
	var storm: bool = t < w._storm_until
	if storm:
		if !w._st.storm_was:
			w._st.storm_was = true
			w._st.storm_t0 = t
		if w.tier >= 3:                                                # Sword Choir: the storm swells to r 40
			w.storm_r = lerpf(SB_STORM_R, SB_STORM_R3, clampf((t - float(w._st.storm_t0)) / 0.5, 0.0, 1.0))
			if t - float(w._st.sigil) >= 0.5:
				w._st.sigil = t
				w.fx("sigil", w.player.global_position, VIOLET, {"radius": 30.0, "count": 6, "spin": 1.5, "life": 0.5, "col2": WHITE})
	elif w._st.storm_was:
		w._st.storm_was = false
		if w.tier >= 3:
			_throw(w)                                                  # Sword Choir: when the storm ends the blades are thrown
		w.storm_bonus = 0
		w.storm_r = SB_STORM_R
		w.hit_gap = 0.45
	# the spirit blades
	w._st.spirit_angle = float(w._st.spirit_angle) + 3.0 * delta
	var away: bool = t < float(w._st.away_until)
	var sp := 0 if away else spirit_count(w)
	if sp > 0:
		w._claim()
		var o: Vector2 = w.player.global_position
		for i in sp:
			var pos: Vector2 = o + Vector2.from_angle(float(w._st.spirit_angle) + float(i) * TAU / float(sp)) * 17.0
			for e in WeaponUtil.enemies_in_circle(w.get_tree(), pos, 9.0):
				var key: int = e.get_instance_id()
				if t - float(w._st.spirit_hit.get(key, -10.0)) >= SB_SPIRIT_TICK:
					w._st.spirit_hit[key] = t
					WeaponUtil.hit(e, WeaponTiers.H(w) * SB_SPIRIT_MULT, pos, 40.0, 0.0, "", false, true)
		if w._st.spirit_hit.size() > 40:
			w._st.spirit_hit.clear()
	if w._aura != null and is_instance_valid(w._aura):
		w._aura.data = {"ph": w._angle, "n": w.blades_now() if storm else 0, "r": w.storm_r, "sp": sp, "sph": w._st.spirit_angle, "av": 1 if saint(w) else 0}

## Thrown at the end of the storm: every blade flies out the way it points.
static func _throw(w) -> void:
	var o: Vector2 = w.player.global_position
	var n: int = w.blades_now()
	for i in n:
		var d := Vector2.from_angle(w._angle + float(i) * TAU / float(n))
		WeaponProjectile.shoot(w.game_world(), o + d * w.storm_r, d, 260.0, WeaponTiers.H(w) * SB_THROWN_MULT, BLUE, 0.4, 2, 100.0, {"style": "blade", "size": 1.0, "trail": 3})

# ---- the aura: storm blades, spirit blades, the avatar ----
static func aura(a, c) -> void:
	draw_blades(a, c)

static func draw_blades(a, c) -> void:
	var d: Dictionary = a.data
	if d.is_empty():
		return
	var gold: bool = a.tier >= 6
	var edge := GOLD if gold else WHITE
	var n: int = int(d.get("n", 0))
	for i in n:                                                       # the storm: glowing diamonds, each with a trail of three ghosts
		var ang: float = float(d.get("ph", 0.0)) + float(i) * TAU / float(n)
		for g in range(3, -1, -1):
			_diamond(c, Vector2.from_angle(ang - 0.14 * float(g)) * float(d.get("r", 26.0)), ang - 0.14 * float(g), 1.0, BLUE if g > 0 else WHITE, 0.9 if g == 0 else 0.22 * (4.0 - float(g)) / 3.0, edge)
	var sp: int = int(d.get("sp", 0))
	for i in sp:                                                      # the spirit blades: smaller, violet, closer in
		var ang2: float = float(d.get("sph", 0.0)) + float(i) * TAU / float(sp)
		_diamond(c, Vector2.from_angle(ang2) * 17.0, ang2, 0.75, VIOLET.lightened(0.2), 0.95, edge)
	if int(d.get("av", 0)) == 1:                                      # the Sword Saint's spectral sword hovers behind you
		var back: Vector2 = -a.aim * 22.0 + a.aim.orthogonal() * sin(a._age * 2.0) * 3.0
		var tipv: Vector2 = back + a.aim * 24.0
		var nn: Vector2 = a.aim.orthogonal()
		c.draw_colored_polygon(PackedVector2Array([tipv, back + nn * 4.0 - a.aim * 4.0, back - a.aim * 8.0, back - nn * 4.0 - a.aim * 4.0]), Color(BLUE, 0.35))
		c.draw_line(back - a.aim * 6.0, tipv, Color(WHITE, 0.85), 1.5)
		c.draw_line(back + nn * 5.0, back - nn * 5.0, Color(GOLD, 0.9), 1.5)

static func _diamond(c, p: Vector2, ang: float, k: float, col: Color, alpha: float, edge: Color) -> void:
	var t := Vector2.from_angle(ang + PI / 2.0)
	var r := Vector2.from_angle(ang)
	var pts := PackedVector2Array([p + t * 6.0 * k, p + r * 3.0 * k, p - t * 6.0 * k, p - r * 3.0 * k])
	c.draw_colored_polygon(pts, Color(col, alpha))
	if alpha > 0.5:
		c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(edge, 0.9), 0.8)

# ---- attack ----
static func pre_attack(w) -> void:
	w._st.chain = 2 if w.tier >= 4 and (int(w._st.slashes) + 1) % SB_PHANTOM_EVERY == 0 else 0

## Hits of the sword (the wave and the slash) are what conjure spirit blades.
static func on_hit(w, _e, _dmg: float) -> void:
	if w.verb() == "attack":
		w._st.hit_ms = Time.get_ticks_msec()

static func attack(w) -> void:
	w._st.slashes = int(w._st.slashes) + 1
	if w.tier < 2:
		return
	var n: int = w._st.slashes
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var press := Time.get_ticks_msec()
	_conjure(w, press)
	if w.tier >= 3 and n % 3 == 0:
		_choir(w)
	if w.tier >= 4 and n % SB_PHANTOM_EVERY == 0:
		_phantom_swing(w, o, dir)
	if w.tier >= 6 and n % SB_FINISHER_EVERY == 0:
		_volley(w)
	if saint(w):
		for s in [-0.25, 0.25]:                                        # three waves in a fan
			var d: Vector2 = dir.rotated(s)
			WeaponProjectile.shoot(w.game_world(), o + d * 14.0, d, 240.0, WeaponTiers.H(w) * 0.5, BLUE, 0.5, 1, 100.0, {"style": "crescent", "size": 1.0, "trail": 3})
		w.fx("slash", o, WHITE, {"radius": 60.0, "dir": dir, "half_angle": 1.1, "thick": 10.0, "life": 0.3, "col2": GOLD})        # the avatar copies the swing
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 60.0, 65.0):
			WeaponUtil.hit(e, WeaponTiers.H(w) * SB_AVATAR_MULT, o, 120.0, 0.0, "", true, true)

## Every second slash that hit something conjures a spirit blade (up to the tier's limit).
static func _conjure(w, press_ms: int) -> void:
	if !await WeaponTiers.pause(w, 0.4):
		return
	if int(w._st.hit_ms) < press_ms:
		return
	w._st.waves = int(w._st.waves) + 1
	if int(w._st.waves) % 2 == 0 and int(w._st.spirit) < spirit_max(w):
		w._st.spirit = int(w._st.spirit) + 1
		w.fx("star", w.player.global_position, VIOLET, {"radius": 14.0, "count": 4, "spin": 1.0, "life": 0.35})
		Sfx.play("unlock", 0.1, 1.4)

## Sword Choir: every third slash each spirit blade throws a mini wave at the nearest enemy.
static func _choir(w) -> void:
	var o: Vector2 = w.player.global_position
	var sp := spirit_count(w)
	for i in sp:
		var pos: Vector2 = o + Vector2.from_angle(float(w._st.spirit_angle) + float(i) * TAU / float(sp)) * 17.0
		var e = WeaponUtil.nearest(w.get_tree(), pos, 120.0)
		if e == null:
			return
		var d: Vector2 = (e.global_position - pos).normalized()
		WeaponProjectile.shoot(w.game_world(), pos, d, 240.0, WeaponTiers.H(w) * 0.2, VIOLET, 0.5, 0, 40.0, {"style": "blade", "size": 0.7})

## Phantom Edge: a phantom copy of the swing, on the other arc, 0.12 s later.
static func _phantom_swing(w, o: Vector2, dir: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.12):
		return
	var at: Vector2 = w.player.global_position
	w.fx("slash", at, VIOLET, {"radius": 30.0, "dir": dir.rotated(0.35), "half_angle": 1.1, "thick": 6.0, "life": 0.22, "col2": WHITE})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), at, dir, 30.0, 60.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * 0.5, at, 60.0, 0.0, "", true, true)

## Sword Saint finisher: every spirit blade fires at the nearest enemy and is gone for 0.6 s.
static func _volley(w) -> void:
	var o: Vector2 = w.player.global_position
	var sp := spirit_count(w)
	w._st.away_until = now() + 0.6
	for i in sp:
		var pos: Vector2 = o + Vector2.from_angle(float(w._st.spirit_angle) + float(i) * TAU / float(sp)) * 17.0
		var e = WeaponUtil.nearest(w.get_tree(), pos, 140.0)
		if e == null:
			continue
		var d: Vector2 = (e.global_position - pos).normalized()
		WeaponProjectile.shoot(w.game_world(), pos, d, 300.0, WeaponTiers.H(w) * 0.5, GOLD, 0.45, 0, 60.0, {"style": "blade", "size": 0.9, "trail": 3})

# ---- ability: Blade Storm ----
static func ability(w) -> void:
	if w.tier < 2:
		return
	w.storm_bonus = 3 if w.blade_count <= 3 else 0                       # Spellweave: six blades; one enemy is touched less often so that doubling does not double the damage
	w.hit_gap = 0.8 if w.storm_bonus > 0 else 0.45
	if w.tier >= 4:
		_phantom_storm(w, int(w._st.ult_id))

static func blade_hit(w, e) -> void:
	if w.tier >= 2 and Kit.alive(e):
		w.fx("burst", e.global_position, BLUE, {"radius": 8.0, "life": 0.2})

## Phantom Edge: a phantom of you hosts a storm of three blades at the cursor for 3 s.
static func _phantom_storm(w, my: int) -> void:
	var at: Vector2 = w.cursor_target(100.0)
	var hit := {}
	for k in 6:
		w.fx("orbit", at, VIOLET, {"radius": 26.0, "count": 3, "spin": 6.0, "shape": "blade", "life": 0.55})
		w.fx("ring", at, VIOLET, {"radius": 10.0, "life": 0.5})
		if !await WeaponTiers.pause(w, 0.5):
			return
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 35.0):
			WeaponUtil.hit(e, WeaponTiers.H(w) * SB_SPIRIT_MULT * 1.5, at, 40.0, 0.0, "", true, true)

# ---- dash: Phantom Dash ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, BLUE, {"dir": dir, "length": 55.0, "width": 7.0, "life": 0.25, "col2": WHITE})
	_phantoms(w, o, o + dir * 55.0)

static func _phantoms(w, a: Vector2, b: Vector2) -> void:
	for k in 2:                                                       # two phantom blades follow the path 0.2 s later
		if !await WeaponTiers.pause(w, 0.2):
			return
		w.fx("streak", a, VIOLET, {"dir": (b - a).normalized(), "length": a.distance_to(b), "width": 4.0, "life": 0.2, "col2": WHITE})
		for e in Kit.near_segment(w.get_tree(), a, b, 14.0):
			WeaponUtil.hit(e, WeaponTiers.H(w) * 0.6, a, 40.0, 0.0, "", true, true)

static func dash_hit(w, e) -> void:
	if w.tier >= 4 and Kit.alive(e):
		WeaponUtil.expose(e, 2.5)

# ---- ultimate: Blade Dance, Blade Tempest, Sword Saint ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1
	w.storm_bonus = 0
	w.hit_gap = 0.45

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	if w.tier >= 3:
		w.fx("sigil", w.player.global_position, VIOLET, {"radius": 90.0, "count": 6, "spin": 1.5, "life": 0.3, "col2": WHITE})
	if w.tier >= 5:
		_tempest(w, my)

## Tier 5: after the 5 s the blades merge into a cyclone for 2 s, then twelve blades fly out.
static func _tempest(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 5.0) or int(w._st.ult_id) != my:
		return
	var h := WeaponTiers.H(w)
	w.fx("vortex", w.player.global_position, BLUE, {"radius": 70.0, "count": 6, "spin": 4.0, "life": SB_CYCLONE_SECS})
	w.fx("vortex", w.player.global_position, VIOLET.lightened(0.25), {"radius": 55.0, "count": 4, "spin": -5.0, "life": SB_CYCLONE_SECS})
	for k in int(SB_CYCLONE_SECS / 0.25):
		var o: Vector2 = w.player.global_position
		if k % 2 == 0:
			w.fx("ring", o, BLUE, {"radius": 70.0, "life": 0.25})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 70.0):
			WeaponUtil.hit(e, h * 0.4, o, 0.0, 0.0, "", true, true)
			Kit.pull(e, o, 240.0, 0.25)
		if !await WeaponTiers.pause(w, 0.25) or int(w._st.ult_id) != my:
			return
	var o2: Vector2 = w.player.global_position
	for k in SB_RING_N:
		var d := Vector2.from_angle(float(k) * TAU / float(SB_RING_N))
		WeaponProjectile.shoot(w.game_world(), o2 + d * 12.0, d, 240.0, h * 0.5, BLUE, 0.4, 1, 80.0, {"style": "blade", "size": 0.9})
	Sfx.play("whoosh", 0.1)
	if w.tier >= 6:
		_saint(w, my)

## FINALE + TRANSFORMATION Sword Saint (10 s): an avatar copies your slashes, then crashes down.
static func _saint(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 0.2) or int(w._st.ult_id) != my:
		return
	w._st.saint_until = now() + SB_SAINT_SECS
	w.fx("flash", w.player.global_position, GOLD, {"radius": 30.0, "life": 0.3})
	Sfx.play("ultimate", 0.05)
	if !await WeaponTiers.pause(w, SB_SAINT_SECS) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("flash", o, WHITE, {"radius": 80.0, "life": 0.4})
	w.fx("star", o, GOLD, {"radius": 80.0, "count": 8, "spin": 2.0, "life": 0.5})
	w.fx("ripple", o, BLUE, {"radius": 120.0, "rings": 3, "life": 0.6})
	w.player.shake(7.0, 0.4)
	w._claim()
	w.ground_strike(o, 70.0, 0.5, WeaponTiers.H(w) * SB_FINALE_MULT, 300.0, GOLD, 1.0)
