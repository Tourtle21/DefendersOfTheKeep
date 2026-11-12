extends RefCounted
## Bulwark Maul tiers (docs/weapon_tiers/bulwark.md): 2 Counterweight, 3 Fortress Slam, 4 Bulldozer, 5 Citadel Pulse, 6 Titan's Judgment.
## Epic: a stance weapon with consequences. The dome, the stored charges, the fortress that eats shots. The upgrades make the stance proactive.
## The old weapon (t2/bulwark.gd) calls the `absorb`, `bash`, `release` and `fortress` hooks and leaves `_st.released` (charges spent by the last release).

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const STEEL := Color(0.60, 0.75, 1.0)
const GOLD := Color(1.0, 0.85, 0.40)
const WHITE := Color(0.95, 0.97, 1.0)
const IRON := Color(0.45, 0.50, 0.60)
const BM_PUSH := 200.0
const BM_SLAM_EVERY := 3
const BM_BASH_MULT := 0.5
const BM_BASH_EXTEND := 0.5
const BM_BRACE_MAX := 4.5
const BM_CONE_R := 90.0
const BM_CONE_MULT := 1.5
const BM_CARRY := 50.0
const BM_PULSE_R := [52.0, 64.0, 76.0, 88.0]
const BM_FRAGMENTS := 6
const BM_FRAGMENT_MULT := 0.3
const BM_FINALE_R := 90.0
const BM_FINALE_MULT := 2.0
const BM_FINISHER_EVERY := 6
const NAMES := ["", "Bulwark Maul", "Counterweight", "Fortress Slam", "Bulldozer", "Citadel Pulse", "Titan's Judgment"]

static func palette() -> Array:
	return [STEEL, GOLD, WHITE]

static func equip(w) -> void:
	w._st = {"mauls": 0, "released": 0, "ult_id": 0, "fortress_until": 0.0, "pulse_hits": {}}

## The aura draws the half dome while bracing (`state` = stored charges + 1) and the full shield while the fortress stands (`state2`).
static func tick(w, _delta: float) -> void:
	if w.tier < 2 or w._aura == null or !is_instance_valid(w._aura):
		return
	w._aura.state = float(w._stored + 1) if w._braced else 0.0
	var now := Time.get_ticks_msec() / 1000.0
	w._aura.state2 = 1.0 if float(w._st.get("fortress_until", 0.0)) > now else 0.0
	# Citadel Pulse: the fortress eats enemy shots within 40 px
	if w.tier >= 5 and w._aura.state2 > 0.5:
		for sh in w.get_tree().get_nodes_in_group("enemy_shot"):
			if Kit.alive(sh) and sh.global_position.distance_to(w.player.global_position) <= 40.0:
				w.fx("burst", sh.global_position, STEEL, {"radius": 8.0, "life": 0.2})
				sh.queue_free()

static func aura(a, c) -> void:
	if a.state > 0.5:
		var stored := int(a.state) - 1
		var ang: float = a.aim.angle()
		c.draw_arc(Vector2.ZERO, 16.0, ang - 1.3, ang + 1.3, 14, Color(STEEL, 0.75), 1.5)
		c.draw_arc(Vector2.ZERO, 15.0, ang - 1.3, ang + 1.3, 14, Color(STEEL, 0.18), 5.0)
		for i in stored:
			c.draw_circle(Vector2.from_angle(ang - 0.8 + 0.4 * float(i)) * 12.0, 1.1, Color(GOLD, 0.95))
	if a.state2 > 0.5 and a.tier >= 6:
		c.draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, Color(GOLD, 0.35), 1.0)

# ---- attack: shards, the slam every third maul, the double ring finisher ----
static func attack(w) -> void:
	w._st.mauls = int(w._st.mauls) + 1
	if w.tier < 2:
		return
	var n: int = w._st.mauls
	_after_swing(w, w.tier >= 3 and n % BM_SLAM_EVERY == 0, w.tier >= 6 and n % BM_FINISHER_EVERY == 0)

static func _after_swing(w, slam: bool, finisher: bool) -> void:
	if !await WeaponTiers.pause(w, 0.24):
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("shards", o + dir * 28.0, IRON, {"radius": 14.0, "count": 4, "life": 0.25})
	if slam:
		var at: Vector2 = o + dir * 22.0
		w.fx("shock", at, STEEL, {"radius": 40.0, "thick": 5.0, "life": 0.3, "col2": WHITE})
		w.fx("crack", at, STEEL, {"radius": 40.0, "count": 6, "life": 0.5})
		var h := WeaponTiers.H(w)
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 40.0):
			WeaponUtil.hit(e, h * 0.8, o, 0.0, 0.0, "", true, true)
			WeaponUtil.stun(e, 0.8)
		w.player.shake(3.0, 0.15)
		Sfx.play("thump", 0.1)
	if finisher:
		_double_ring(w, o + dir * 22.0)

static func _double_ring(w, at: Vector2) -> void:
	var h := WeaponTiers.H(w)
	for k in 2:
		var r: float = [34.0, 52.0][k]
		w.fx("shock", at, GOLD, {"radius": r, "thick": 5.0, "life": 0.3, "col2": WHITE})
		w.fx("crack", at, GOLD, {"radius": r, "count": 5, "life": 0.45})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, r):
			WeaponUtil.hit(e, h * 0.5, at, 120.0, 0.0, "", true, true)
		if k == 0 and !await WeaponTiers.pause(w, 0.15):
			return

# ---- brace: counterweight shove, the shield bash, overpressure ----
static func absorb(w, _from: Vector2) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	w.fx("ring", o, STEEL, {"radius": 24.0, "life": 0.25})
	w.fx("star", o, GOLD, {"radius": 12.0, "count": maxi(1, int(w._stored)), "spin": 1.0, "life": 0.3})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 24.0):
		Kit.shove(e, o, BM_PUSH, 0.15)

## Tier 3: a left click while braced is a shield bash. It stores nothing but the brace lasts 0.5 s longer (4.5 s at most).
static func bash(w) -> bool:
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.swing(0.6, 0.12)
	w.fx("arc", o, STEEL, {"radius": 24.0, "dir": dir, "half_angle": 0.9, "life": 0.15})
	w.fx("shards", o + dir * 20.0, WHITE, {"radius": 10.0, "count": 3, "life": 0.2})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 24.0, 55.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * BM_BASH_MULT, o, 200.0, 0.0, "", true, true)
	w.brace_secs = minf(BM_BRACE_MAX, w.brace_secs + BM_BASH_EXTEND)
	w.player.shake(1.5, 0.1)
	return true

static func release(w) -> void:
	var stored: int = int(w._st.get("released", 0))
	w._st.released = 0
	if w.tier < 4 or stored <= 0:
		return
	var o: Vector2 = w.player.global_position
	var r := 30.0 + 8.0 * float(stored)
	w.fx("shock", o, GOLD, {"radius": r, "thick": 6.0, "life": 0.35, "col2": WHITE})
	if stored >= int(w.max_store):                                 # Overpressure: a full brace also fires a cone forward
		var dir: Vector2 = w.aim
		w.fx("cone", o, STEEL, {"radius": BM_CONE_R, "dir": dir, "half_angle": 0.7, "life": 0.3, "col2": WHITE})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, BM_CONE_R, rad_to_deg(0.7)):
			WeaponUtil.hit(e, WeaponTiers.H(w) * BM_CONE_MULT, o, 400.0, 0.0, "", true)
		w.player.shake(4.0, 0.2)

# ---- dash: Bulldozer carries the pack and slams it down ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, STEEL, {"dir": dir, "length": 60.0, "width": 12.0, "life": 0.3, "col2": WHITE})
	for k in 3:
		w.fx("crack", o + dir * (14.0 + 20.0 * float(k)), IRON, {"radius": 14.0, "count": 3, "life": 0.5})
	_carry(w, o, dir)

static func _carry(w, o: Vector2, dir: Vector2) -> void:
	for k in 5:                                                      # what the dash has hit rides along for 50 px
		if !await WeaponTiers.pause(w, 0.05):
			return
		for e in w._dash_hit:
			if Kit.alive(e):
				e.push(dir * (BM_CARRY / 0.25), 0.07)
	var end: Vector2 = w.player.global_position + dir * 8.0
	w.fx("shock", end, STEEL, {"radius": 36.0, "thick": 5.0, "life": 0.3, "col2": WHITE})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), end, 36.0):
		WeaponUtil.hit(e, WeaponTiers.H(w), end, 0.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.0)
	Sfx.play("thump", 0.1)

# ---- ultimate: Quake Fortress ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1
	w._st.fortress_until = Time.get_ticks_msec() / 1000.0 + 4.0
	w._st.pulse_hits = {}

static func ultimate(w) -> void:
	var o: Vector2 = w.player.global_position
	if w.tier >= 3:
		w.fx("sigil", o, STEEL, {"radius": 60.0, "count": 8, "spin": 1.5, "life": 0.3, "col2": WHITE})
	if w.tier >= 6:
		_finale(w, int(w._st.ult_id))

## Tier 5: the four pulses grow and each throws a ring of shards. True: the plain pulses of the old weapon are not wanted.
static func fortress(w) -> bool:
	_pulses(w, int(w._st.ult_id))
	return true

static func _pulses(w, my: int) -> void:
	for i in 4:
		if !WeaponTiers.alive(w) or int(w._st.ult_id) != my:
			return
		var o: Vector2 = w.player.global_position
		var r: float = BM_PULSE_R[i]
		w.fx("shock", o, STEEL, {"radius": r, "thick": 5.0, "life": 0.3, "col2": WHITE})
		w.fx("ripple", o, GOLD, {"radius": r * 0.8, "rings": 2, "life": 0.4})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, r):
			WeaponUtil.hit(e, 2.0, o, 280.0, 0.0, "", true)
			WeaponUtil.stun(e, 0.5)
			if Kit.alive(e):
				var key: int = e.get_instance_id()
				w._st.pulse_hits[key] = int(w._st.pulse_hits.get(key, 0)) + 1
		w.player.shake(3.5, 0.15)
		Sfx.play("gong", 0.1)
		for k in BM_FRAGMENTS:
			if !await WeaponTiers.pause(w, 0.05):
				return
			var a := float(k) * TAU / float(BM_FRAGMENTS) + float(i) * 0.4
			var d := Vector2.from_angle(a)
			WeaponProjectile.shoot(w.game_world(), o + d * 8.0, d, 200.0, WeaponTiers.H(w) * BM_FRAGMENT_MULT, STEEL, 0.3, 0, 40.0, {"style": "shard", "size": 0.9})
		if !await WeaponTiers.pause(w, 0.7):
			return

## FINALE Titan's Judgment: the great slam when the fortress ends.
static func _finale(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 3.6) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, GOLD, {"radius": BM_FINALE_R, "count": 8, "spin": 2.0, "life": 0.4, "col2": WHITE})
	if !await WeaponTiers.pause(w, 0.4) or int(w._st.ult_id) != my:
		return
	o = w.player.global_position
	var h := WeaponTiers.H(w)
	w.fx("flash", o, WHITE, {"radius": BM_FINALE_R, "life": 0.35})
	w.fx("shock", o, GOLD, {"radius": BM_FINALE_R, "thick": 9.0, "life": 0.45, "col2": WHITE})
	w.fx("crack", o, IRON, {"radius": BM_FINALE_R, "count": 12, "life": 0.7})
	w.player.shake(6.5, 0.4)
	Sfx.play("thump", 0.05)
	Sfx.play("big_hit", 0.05)
	Sfx.play("ultimate", 0.05)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, BM_FINALE_R):
		var key: int = e.get_instance_id() if Kit.alive(e) else 0
		var pulses: int = int(w._st.pulse_hits.get(key, 0))
		WeaponUtil.hit(e, h * (BM_FINALE_MULT + 0.5 * float(mini(pulses, 4))), o, 420.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.2)
