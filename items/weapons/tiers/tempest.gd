extends RefCounted
## Tempest Lash tiers (docs/weapon_tiers/tempest.md): 2 Static, 3 Overcharge, 4 Ball Lightning, 5 Thunderhead, 6 Stormlord.
## Mythic: CHARGE AND DETONATE made visible and strategic. Charges (host metas "charge") are drawn for every enemy by charge motes that go through WeaponFx,
## so LAN clients see them too. Thunderclap is the payoff; a full 5-charge enemy is OVERLOADED and arcs on its own; the ultimate hangs a thundercloud
## and turns you into the storm. The old weapon (t2/tempest.gd) calls the `overload` and `detonate` hooks and makes the bolts of tiers 2+.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const BOLT := Color(0.70, 0.85, 1.0)
const CORE := Color(1.0, 1.0, 1.0)
const VIOLET := Color(0.50, 0.45, 0.95)
const COPPER := Color(0.85, 0.60, 0.30)
const TL_OVERLOAD := 5
const TL_OVERLOAD_RESET := 2
const TL_SPLASH_R := 30.0
const TL_BALL_EVERY := 4
const TL_BALL_TICKS := 3
const TL_BALL_MULT := 0.4
const TL_CLOUD_SECS := 6.0
const TL_CLOUD_TICK := 0.5
const TL_CLOUD_MULT := 1.0
const TL_LORD_SECS := 8.0
const TL_WEB_R := 70.0
const TL_MEGA_R := 160.0
const TL_FINISHER_EVERY := 6
const NAMES := ["", "", "Static", "Overcharge", "Ball Lightning", "Thunderhead", "Stormlord"]

static func palette() -> Array:
	return [BOLT, VIOLET, CORE]

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func equip(w) -> void:
	w._st = {"attacks": 0, "ult_id": 0, "motes": 0.0, "lord_until": 0.0, "web": 0.0, "strike": 0.0, "balls": 0, "cascade": 0}

static func lord(w) -> bool:
	return now() < float(w._st.get("lord_until", 0.0))

static func charge_of(e) -> int:
	return int(e.get_meta("charge", 0)) if Kit.alive(e) else 0

# ---- every frame: charge motes for clients, Stormlord's rules ----
static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	var t := now()
	w._st.motes = float(w._st.motes) + delta
	if float(w._st.motes) >= 0.4:
		w._st.motes = 0.0
		var shown := 0
		for e in w.get_tree().get_nodes_in_group("enemy"):
			if shown >= 8:
				break
			var n := charge_of(e)
			if n > 0 and e.global_position.distance_to(w.player.global_position) < 260.0:
				shown += 1
				w.fx("motes", e.global_position + Vector2(0, -14), BOLT, {"radius": 4.0, "count": n, "rise": 8.0, "life": 0.4})
	if lord(w):
		if w._ability_cd > 1.0:                                       # Stormlord: Thunderclap is nearly free
			w._ability_cd = 1.0
		if t - float(w._st.web) >= 0.5:
			w._st.web = t
			_web(w)
		if t - float(w._st.strike) >= 0.7:
			w._st.strike = t
			_overloaded_strikes(w)

## Two mini sparks crackle round the head every 0.8 s (the aura draws them from its own clock, the same on every machine).
static func aura(a, c) -> void:
	var d: Vector2 = a.aim.rotated(a.swing)
	var head: Vector2 = d * a.reach
	var since := fposmod(a._age, 0.8)
	if since < 0.18:
		var sd: int = int(floor(a._age / 0.8))
		for k in 2:
			var base: float = WeaponAura.jit(sd * 2 + k, 3.0) * TAU
			var p0: Vector2 = head + Vector2.from_angle(base) * 3.0
			var pts := PackedVector2Array([p0])
			for i in range(1, 4):
				pts.append(p0 + Vector2.from_angle(base + (WeaponAura.jit(sd + k * 7 + i, 5.0) - 0.5) * 1.6) * float(i) * 3.0)
			c.draw_polyline(pts, Color(BOLT, 0.8), 1.0)
			c.draw_polyline(pts, Color(CORE, 0.9), 0.5)

# ---- attack: jagged chains (old weapon), balls, the forked bolt ----
static func attack(w) -> void:
	w._st.attacks = int(w._st.attacks) + 1
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var first = null
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, 75.0, 28.0):
		if first == null or e.global_position.distance_to(o) < first.global_position.distance_to(o):
			first = e
	var n: int = w._st.attacks
	if w.tier >= 4 and n % TL_BALL_EVERY == 0:
		_launch_ball(w, o, w.aim)
	if first != null and w.tier >= 6 and (lord(w) or n % TL_FINISHER_EVERY == 0):
		_fork(w, first)

## Tier 6: five bolts fork from the first victim to five targets within 90 px.
static func _fork(w, first) -> void:
	var at: Vector2 = first.global_position
	var h := WeaponTiers.H(w)
	for e in Kit.nearest_n(w.get_tree(), at, 90.0, 6):
		if e == first:
			continue
		Kit.bolt(w, at, e.global_position, CORE, 1.8, 0.25)
		WeaponUtil.hit(e, h * 0.6, at, 20.0, 0.0, "", true, true)
		w._charge(e, 2)

# ---- charges: overload, the thunderclap splash and balls ----
## A full enemy arcs to two neighbours within 60 px (they take a charge each) and drops back to two charges.
static func overload(w, e) -> void:
	if !Kit.alive(e) or WeaponTiers.marked(e, "overload"):
		return
	WeaponTiers.mark(e, "overload", 0.3)
	e.set_meta("charge", TL_OVERLOAD_RESET)
	var at: Vector2 = e.global_position
	w.fx("flash", at, BOLT, {"radius": 14.0, "life": 0.25})
	var done: Array = [e]
	for i in 2:
		var nb = WeaponUtil.nearest(w.get_tree(), at, 60.0, done)
		if nb == null:
			break
		done.append(nb)
		Kit.bolt(w, at, nb.global_position, CORE, 1.8, 0.25)
		WeaponUtil.hit(nb, WeaponTiers.H(w) * 0.6, at, 20.0, 0.0, "", true, true)
		if int(w._st.cascade) < 3:                                   # overloads chain across the pack, but not forever
			w._st.cascade = int(w._st.cascade) + 1
			w._charge(nb, 1)
			w._st.cascade = int(w._st.cascade) - 1

## Thunderclap detonated `e` (n charges): tier 3 splashes the neighbours, tier 4 leaves a ball where it died.
static func detonate(w, e, n: int, at: Vector2) -> void:
	if w.tier < 3:
		return
	var h := WeaponTiers.H(w)
	var struck := 0
	for o in WeaponUtil.enemies_in_circle(w.get_tree(), at, TL_SPLASH_R):
		if o == e or struck >= 3:
			continue
		struck += 1
		WeaponUtil.hit(o, h * 0.5 * float(n), at, 20.0, 0.0, "", true, true)
	if w.tier >= 4 and (!Kit.alive(e) or float(e.health) <= 0.0) and int(w._st.balls) < 3:
		_static_ball(w, at, 2.0, 0.5)

## A ball of lightning drifts through the pack and zaps everything within 40 px every 0.4 s.
static func _launch_ball(w, o: Vector2, dir: Vector2) -> void:
	if int(w._st.balls) >= 3:
		return
	w._st.balls = int(w._st.balls) + 1
	var h := WeaponTiers.H(w)
	WeaponProjectile.shoot(w.game_world(), o + dir * 14.0, dir, 130.0, h * 0.8, BOLT, 1.6, 99, 20.0, {"style": "orb", "size": 1.6, "glow": 0.4, "trail": 3, "chain": 3})
	var start: Vector2 = o + dir * 14.0
	for k in 4:
		if !await WeaponTiers.pause(w, 0.4):
			return
		var p: Vector2 = start + dir * 130.0 * 0.4 * float(k + 1)
		_zap(w, p)
	w._st.balls = maxi(0, int(w._st.balls) - 1)

static func _zap(w, p: Vector2) -> void:
	w.fx("star", p, CORE, {"radius": 9.0, "count": 4, "spin": 1.0, "life": 0.25})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 40.0):
		Kit.bolt(w, p, e.global_position, BOLT, 1.2, 0.15)
		WeaponUtil.hit(e, WeaponTiers.H(w) * TL_BALL_MULT, p, 0.0, 0.0, "", true, true)
		w._charge(e, 1)

## A ball that stays where it is for `secs` and zaps within 40 px every `tick_s`.
static func _static_ball(w, p: Vector2, secs: float, tick_s: float) -> void:
	w._st.balls = int(w._st.balls) + 1
	var t := 0.0
	while t < secs:
		w.fx("orbit", p, BOLT, {"radius": 5.0, "count": 3, "spin": 8.0, "shape": "star", "life": tick_s + 0.05})
		if !await WeaponTiers.pause(w, tick_s):
			return
		t += tick_s
		_zap(w, p)
	w._st.balls = maxi(0, int(w._st.balls) - 1)

# ---- dash: Ball Lightning Dash ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	w.fx("streak", o, BOLT, {"dir": w.aim, "length": 50.0, "width": 6.0, "life": 0.25, "col2": CORE})
	if int(w._st.balls) < 3:
		_static_ball(w, o, 2.0, 0.5)

# ---- ultimate: Storm, Thunderhead, Stormlord ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	if w.tier >= 3:
		w.fx("sigil", w.player.global_position, VIOLET, {"radius": 100.0, "count": 6, "spin": 1.5, "life": 0.3, "col2": CORE})
	if w.tier >= 5:
		_cloud(w, my)
	if w.tier >= 6:
		_stormlord(w, my)

## Tier 5: after the clap a thundercloud hangs for 6 s and strikes charged enemies.
static func _cloud(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 0.5) or int(w._st.ult_id) != my:
		return
	var c: Vector2 = w.player.global_position
	var h := WeaponTiers.H(w)
	var t := 0.0
	var nextfx := 0.0
	while t < TL_CLOUD_SECS:
		if t >= nextfx:
			nextfx += 0.8
			w.fx("sigil", c, VIOLET, {"radius": 110.0, "count": 6, "spin": 1.0, "life": 0.8, "col2": CORE})
			w.fx("motes", c, BOLT, {"radius": 100.0, "count": 20, "rise": -40.0, "life": 0.8})
		var pool := []
		var anyone := WeaponUtil.enemies_in_circle(w.get_tree(), c, 110.0)
		for e in anyone:
			if charge_of(e) > 0:
				pool.append(e)
		if pool.is_empty():                                           # nothing charged (the clap spent it all): the cloud charges a random enemy itself
			pool = anyone
		if !pool.is_empty():
			var e2 = pool[randi() % pool.size()]
			var at: Vector2 = e2.global_position
			w.fx("bolt", at + Vector2(0, -80), CORE, {"dir": Vector2.DOWN, "length": 80.0, "width": 2.0, "life": 0.25})
			w.ground_strike(at, 14.0, 0.2, h * TL_CLOUD_MULT, 60.0, BOLT)
			w._charge(e2, 1)
		if !await WeaponTiers.pause(w, TL_CLOUD_TICK) or int(w._st.ult_id) != my:
			return
		t += TL_CLOUD_TICK

## FINALE + TRANSFORMATION Stormlord: you are the storm for 8 s, then a mega-clap.
static func _stormlord(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 6.5) or int(w._st.ult_id) != my:
		return
	w._st.lord_until = now() + TL_LORD_SECS
	w.fx("flash", w.player.global_position, VIOLET, {"radius": 30.0, "life": 0.3})
	Sfx.play("ultimate", 0.05)
	if !await WeaponTiers.pause(w, TL_LORD_SECS) or int(w._st.ult_id) != my:
		return
	_mega(w)

## The web: charged enemies within 70 px of each other arc between themselves (0.3 H, quiet), at most six arcs at a time.
static func _web(w) -> void:
	w._claim()
	var charged := []
	for e in w.get_tree().get_nodes_in_group("enemy"):
		if charge_of(e) > 0 and e.global_position.distance_to(w.player.global_position) < 240.0:
			charged.append(e)
	var arcs := 0
	for i in charged.size():
		for j in range(i + 1, charged.size()):
			if arcs >= 6:
				return
			if charged[i].global_position.distance_to(charged[j].global_position) <= TL_WEB_R:
				arcs += 1
				Kit.bolt(w, charged[i].global_position, charged[j].global_position, BOLT, 1.2, 0.3)
				WeaponUtil.hit(charged[j], WeaponTiers.H(w) * 0.3, charged[i].global_position, 0.0, 0.0, "", true, true)

static func _overloaded_strikes(w) -> void:
	w._claim()
	for e in w.get_tree().get_nodes_in_group("enemy"):
		if charge_of(e) >= TL_OVERLOAD and e.global_position.distance_to(w.player.global_position) < 240.0:
			var at: Vector2 = e.global_position
			w.fx("bolt", at + Vector2(0, -80), CORE, {"dir": Vector2.DOWN, "length": 80.0, "width": 2.0, "life": 0.25})
			WeaponUtil.hit(e, WeaponTiers.H(w) * 0.6, at, 20.0, 0.0, "", true, true)

static func _mega(w) -> void:
	var o: Vector2 = w.player.global_position
	w.fx("flash", o, CORE, {"radius": 90.0, "life": 0.4})
	w.fx("ripple", o, BOLT, {"radius": TL_MEGA_R, "rings": 4, "life": 0.7})
	w.fx("pillar", o, VIOLET, {"height": 160.0, "width": 30.0, "life": 0.6})
	w.player.shake(7.0, 0.4)
	Sfx.play("ultimate", 0.05)
	Sfx.play("big_hit", 0.05)
	for e in w.get_tree().get_nodes_in_group("enemy"):
		var n := charge_of(e)
		if n > 0 and e.global_position.distance_to(o) <= TL_MEGA_R:
			var at: Vector2 = e.global_position
			e.remove_meta("charge")
			Kit.bolt(w, o, at, CORE, 2.0, 0.3)
			w.fx("flash", at, BOLT, {"radius": 12.0 + 3.0 * float(n), "life": 0.3})
			WeaponUtil.hit(e, 3.0 * float(n), o, 120.0, 0.0, "", true)
