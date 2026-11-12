extends RefCounted
## Rapier tiers (docs/weapon_tiers/rapier.md): 2 Flicker, 3 Riposte Rhythm, 4 Afterimage, 5 Duelist's Dance, 6 Final Lunge.
## Rare: a rhythm weapon. The third thrust, the chain of three, the phantom that repeats your move.
## The old weapon (t2/rapier.gd) leaves `_st.big` / `_st.n` (what the last thrust was) and calls the `fleche` and `stab` hooks.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const STEEL := Color(1.0, 0.92, 0.92)
const ROSE := Color(1.0, 0.60, 0.65)
const GOLD := Color(1.0, 0.90, 0.50)
const WHITE := Color(1.0, 1.0, 1.0)
const RAP_WAVE_MULT := 0.6
const RAP_PHANTOM_T := 0.6
const RAP_PHANTOM_MULT := 1.0
const RAP_FLURRY_EVERY := 4
const RAP_FLURRY_HITS := 3
const RAP_FLURRY_DMG := 1.0
const RAP_LUNGE := 110.0
const RAP_FINALE_MULT := 2.0
const RAP_FINISHER_EVERY := 6
const NAMES := ["", "Rapier", "Flicker", "Riposte Rhythm", "Afterimage", "Duelist's Dance", "Final Lunge"]

static func palette() -> Array:
	return [ROSE, GOLD, WHITE]

static func equip(w) -> void:
	w._st = {"thrusts": 0, "big": false, "n": 0, "ult_id": 0, "thrust_ms": -1000}

## The aura draws a thin white after-line behind the tip while thrusting (`state` 1).
static func tick(w, _delta: float) -> void:
	if w.tier >= 2 and w._aura != null and is_instance_valid(w._aura):
		w._aura.state = 1.0 if Time.get_ticks_msec() - int(w._st.get("thrust_ms", -1000)) < 200 else 0.0

static func aura(a, c) -> void:
	if a.state > 0.5:
		var d: Vector2 = a.aim.rotated(a.swing)
		var tip: Vector2 = d * (a.reach + 14.0)
		c.draw_line(tip, tip - d * 8.0, Color(1, 1, 1, 0.9), 2.0)
		c.draw_line(tip - d * 8.0, tip - d * 16.0, Color(ROSE, 0.5), 1.0)

# ---- attack ----
static func attack(w) -> void:
	w._st.thrusts = int(w._st.thrusts) + 1
	w._st.thrust_ms = Time.get_ticks_msec()
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("cut", o + dir * 46.0, WHITE, {"radius": 8.0, "spin": 0.0, "life": 0.2, "col2": ROSE})
	var big: bool = w._st.get("big", false)
	if w.tier >= 3:
		if int(w._st.get("n", 0)) == 2 and !big:                 # the 2nd thrust of the rhythm throws a thin wave
			WeaponProjectile.shoot(w.game_world(), o + dir * 18.0, dir, 300.0, WeaponTiers.H(w) * RAP_WAVE_MULT, ROSE, 0.25, 2, 60.0, {"style": "lance", "size": 0.8})
		if big:                                                  # the big thrust: a star, and the cold is shaken off
			w.fx("star", o + dir * 40.0, GOLD, {"radius": 14.0, "count": 4, "spin": 1.0, "life": 0.3})
			w.fx("flash", o + dir * 30.0, WHITE, {"radius": 10.0, "life": 0.2})
			if w.player.speed_mult < 1.0 and w.player.speed_mult > 0.0:
				w.player.speed_mult = 1.0
	if w.tier >= 6 and int(w._st.thrusts) % RAP_FINISHER_EVERY == 0:
		_finisher(w, o, dir)

## Tier 6: every 6th thrust pierces through the first enemy (you end 20 px beyond it) for +0.5 H.
static func _finisher(w, o: Vector2, dir: Vector2) -> void:
	var first = null
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, 46.0, 9.0):
		if first == null or e.global_position.distance_to(o) < first.global_position.distance_to(o):
			first = e
	if first == null:
		return
	var through: float = first.global_position.distance_to(o) + 20.0
	w.fx("cut", first.global_position, WHITE, {"radius": 18.0, "spin": 0.0, "life": 0.3, "col2": ROSE})
	w.fx("streak", o, ROSE, {"dir": dir, "length": through, "width": 5.0, "life": 0.2, "col2": WHITE})
	WeaponUtil.hit(first, WeaponTiers.H(w) * 0.5, o, 0.0)
	w.player.blink(dir * minf(through, 60.0))

# ---- Fleche: the rose streak, the mark, the double third stab, the afterimage ----
static func fleche(w, e, n: int, from: Vector2) -> void:
	if w.tier < 2 or !Kit.alive(e):
		return
	var at: Vector2 = e.global_position
	w.fx("streak", from, ROSE, {"dir": (at - from).normalized(), "length": from.distance_to(at), "width": 5.0, "life": 0.25, "col2": WHITE})
	WeaponUtil.expose(e, 2.0)
	if n >= 3:                                                    # the third stab of a chain is a double
		w.fx("flash", at, ROSE, {"radius": 14.0, "life": 0.25})
		WeaponUtil.hit(e, 2.0, from, 60.0, 0.0, "", false, true)
	if w.tier >= 4:
		w.fx("orbit", from, ROSE, {"radius": 6.0, "count": 1, "spin": 5.0, "shape": "blade", "life": RAP_PHANTOM_T})
		_phantom(w, e, from)

static func _phantom(w, e, from: Vector2) -> void:
	if !await WeaponTiers.pause(w, RAP_PHANTOM_T) or !Kit.alive(e):
		return
	var at: Vector2 = e.global_position
	w.fx("streak", from, ROSE, {"dir": (at - from).normalized(), "length": from.distance_to(at), "width": 4.0, "life": 0.2, "col2": WHITE})
	var mult := RAP_PHANTOM_MULT * (1.5 if WeaponUtil.is_exposed(e) else 1.0)
	WeaponUtil.hit(e, WeaponTiers.H(w) * mult, from, 80.0, 0.0, "", false, true)
	w.fx("cut", at, WHITE, {"radius": 9.0, "spin": 0.4, "life": 0.2, "col2": ROSE})

# ---- dash: Afterimage Evade ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, ROSE, {"dir": dir, "length": 45.0, "width": 5.0, "life": 0.25, "col2": WHITE})
	w.fx("orbit", o, ROSE, {"radius": 6.0, "count": 1, "spin": 5.0, "shape": "blade", "life": 0.5})
	_phantom_thrust(w, o, dir)

static func _phantom_thrust(w, o: Vector2, dir: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.5):
		return
	w.fx("line", o, ROSE, {"dir": dir, "length": 46.0, "width": 3.0, "life": 0.12})
	w.fx("cut", o + dir * 46.0, WHITE, {"radius": 8.0, "spin": 0.0, "life": 0.2, "col2": ROSE})
	var first := true
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, 46.0, 9.0):
		WeaponUtil.hit(e, WeaponTiers.H(w), o, 60.0, 0.0, "", false, !first)
		first = false

# ---- ultimate: every thrust draws, tier 5 slides and flurries, tier 6 ends with the lunge ----
static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1
	if w.tier >= 3:
		w.fx("sigil", w.player.global_position + w.aim * 30.0, ROSE, {"radius": 40.0, "count": 4, "spin": 1.5, "life": 0.25, "col2": WHITE})
	if w.tier >= 6:
		_finale(w, int(w._st.ult_id))

static func stab(w, i: int) -> void:
	if w.tier < 3:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, ROSE, {"dir": dir, "length": 56.0, "width": 4.0, "life": 0.15, "col2": WHITE})
	w.fx("beam", o, ROSE, {"dir": dir, "length": 56.0, "width": 3.0, "life": 0.1, "col2": WHITE})
	if w.tier < 5:
		return
	if i == 1:
		w.fx("orbit", o + dir * 30.0, ROSE, {"radius": 12.0, "count": 6, "spin": 4.0, "shape": "blade", "life": 1.1})
	if (i + 1) % RAP_FLURRY_EVERY == 0:
		_flurry(w, o, dir)
	w.player.dash(dir, 6.0, 0.05)                              # the lunge: a slide of 6 px with every thrust

static func _flurry(w, o: Vector2, dir: Vector2) -> void:
	w.fx("cone", o, ROSE, {"radius": 56.0, "dir": dir, "half_angle": 0.5, "life": 0.2, "col2": WHITE})
	for k in RAP_FLURRY_HITS:
		if !await WeaponTiers.pause(w, 0.05):
			return
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 56.0, rad_to_deg(0.5)):
			WeaponUtil.hit(e, RAP_FLURRY_DMG, o, 30.0, 0.0, "", true, true)
			if k == 0:
				w.fx("burst", e.global_position, WHITE, {"radius": 14.0, "life": 0.2})

## FINALE Final Lunge: 1.3 s after the press, one great lunge along the aim.
static func _finale(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 1.3) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var h := WeaponTiers.H(w)
	w.fx("beam", o, Color(1.0, 0.85, 0.88), {"dir": dir, "length": RAP_LUNGE, "width": 10.0, "life": 0.25, "col2": WHITE})
	w.player.dash(dir, RAP_LUNGE, 0.12)
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, RAP_LUNGE, 12.0):
		WeaponUtil.hit(e, h * RAP_FINALE_MULT, o, 260.0, 0.0, "", true)
	if !await WeaponTiers.pause(w, 0.14):
		return
	var end: Vector2 = w.player.global_position
	w.fx("flash", end, WHITE, {"radius": 40.0, "life": 0.3})
	w.fx("shock", end, ROSE, {"radius": 40.0, "thick": 6.0, "life": 0.35, "col2": WHITE})
	w.player.shake(5.5, 0.3)
	Sfx.play("big_hit", 0.05)
	Sfx.play("ultimate", 0.05)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), end, 40.0):
		WeaponUtil.hit(e, h, end, 0.0, 0.0, "", true)
		WeaponUtil.stun(e, 0.8)
