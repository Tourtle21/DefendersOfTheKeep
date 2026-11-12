extends RefCounted
## Whip tiers (docs/weapon_tiers/whip.md): 2 Barbed Hook, 3 Double Crack, 4 Grapple Swing, 5 Cyclone Lash, 6 Thunder Crack.
## Rare: a sequence. Line up a hook, pull the pack, crack the exposed ones; the ultimate has a setup (lashes) and a payoff (implosion, then thunder).

const LEATHER := Color(0.63, 0.32, 0.18)
const GOLD := Color(0.88, 0.69, 0.25)
const WHITE := Color(1.0, 0.97, 0.90)
const COPPER := Color(0.80, 0.50, 0.30)
const DOUBLE_EVERY := 3
const DOUBLE_R := 58.0
const ECHO_T := 0.4
const ECHO_MULT := 0.8
const GRAPPLE_RANGE := 90.0
const IMPLODE_R := 90.0
const IMPLODE_MULT := 1.0
const FINALE_MULT := 1.5
const FINISHER_EVERY := 6
const NAMES := ["", "Whip", "Barbed Hook", "Double Crack", "Grapple Swing", "Cyclone Lash", "Thunder Crack"]

static func palette() -> Array:
	return [LEATHER, GOLD, WHITE]

static func equip(w) -> void:
	w._st = {"swings": 0, "double": false, "finisher": false, "ult_id": 0}

static func pre_attack(w) -> void:
	w._st.swings = int(w._st.get("swings", 0)) + 1
	var n: int = int(w._st.swings)
	w._st.double = w.tier >= 3 and n % DOUBLE_EVERY == 0
	w._st.finisher = w.tier >= 6 and n % FINISHER_EVERY == 0

static func attack(w) -> void:
	if w._st.get("finisher", false):
		var o: Vector2 = w.player.global_position
		w.fx("cut", o + w.aim * 70.0, WHITE, {"radius": 12.0, "spin": 0.5, "life": 0.3})
	if w._st.get("double", false):
		_second(w)

## Tier 3 Double Crack: a second, longer crack 0.12 s later.
static func _second(w) -> void:
	if !await WeaponTiers.pause(w, 0.12):
		return
	var o: Vector2 = w.player.global_position
	w.fx("slash", o, WHITE, {"radius": DOUBLE_R, "dir": w.aim, "half_angle": 0.35, "thick": 3.0, "life": 0.2, "col2": GOLD})
	w.fx("flash", o + w.aim * DOUBLE_R, GOLD, {"radius": 12.0, "life": 0.2})
	w._crack(DOUBLE_R, 44.0)

## Tier 2 Barbed Hook (the exposure of the pack is in whip.gd); the target bleeds. Tier 4 Echo Hook: a second snap.
static func ability(w) -> void:
	var h: Dictionary = w._st.get("hook", {})
	w._st.hook = {}
	if w.tier < 2 or h.is_empty():
		return
	var t = h.t
	var o: Vector2 = w.player.global_position
	if is_instance_valid(t):
		WeaponUtil.bleed(w.get_tree(), t, 4, WeaponTiers.H(w) * 0.15)
		w.fx("streak", o, COPPER, {"dir": w.aim, "length": o.distance_to(t.global_position), "width": 3.0, "life": 0.3, "col2": WHITE})
	if w.tier >= 4:
		_echo(w, h.end)

static func _echo(w, at: Vector2) -> void:
	if !await WeaponTiers.pause(w, ECHO_T):
		return
	var p: Vector2 = w.player.global_position + w.aim * 16.0
	w.fx("ripple", p, GOLD, {"radius": 30.0, "rings": 2, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 30.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * ECHO_MULT, p, 0.0, 0.0, "", true)

## Tier 4 Grapple Swing: the rope is drawn to the target, the lashed are slowed.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var g = w._st.get("grapple", null)
	if g != null:
		var o: Vector2 = w.player.global_position
		w.fx("streak", o, COPPER, {"dir": (g - o).normalized(), "length": o.distance_to(g), "width": 4.0, "life": 0.3, "col2": WHITE})
		Sfx.play("whoosh", 0.05, 1.2)

static func dash_hit(w, e) -> void:
	if w.tier >= 4 and is_instance_valid(e) and e.has_method("apply_slow"):
		e.apply_slow(0.5, 1.5)

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var my: int = w._st.ult_id
	w.fx("sigil", w.player.global_position, GOLD, {"radius": 66.0, "count": 6, "spin": 1.5, "life": 0.25, "col2": WHITE})
	if w.tier >= 5:
		_implosion(w, my)

## Stage 2 Implosion: after the lashes everything near is yanked in.
static func _implosion(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 4 * 0.28 + 0.3) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("vortex", o, GOLD, {"radius": IMPLODE_R, "count": 4, "spin": 4.0, "inward": true, "life": 0.5})
	var n := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, IMPLODE_R):
		if n >= 24:
			break
		n += 1
		e.push((o - e.global_position).normalized() * 260.0, 0.3)
		WeaponUtil.hit(e, WeaponTiers.H(w) * IMPLODE_MULT, o, 0.0, 0.0, "", true)
		if is_instance_valid(e):
			WeaponUtil.expose(e, 2.0)
	if w.tier >= 6:
		_thunder(w, my)

## FINALE Thunder Crack: bolts from above on the pack's centre, then a stunning strike (exposed enemies take 30% more).
static func _thunder(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 0.6) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	var sum := Vector2.ZERO
	var cnt := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, IMPLODE_R):
		sum += e.global_position
		cnt += 1
	var c: Vector2 = sum / float(cnt) if cnt > 0 else o
	for i in 3:
		var d := Vector2.from_angle(-PI / 2.0 + (float(i) - 1.0) * 0.9 + 0.2)
		w.fx("bolt", c - d * 80.0, WHITE, {"dir": d, "length": 80.0, "width": 2.0, "radius": float(i) * 7.0, "life": 0.3})
	w.fx("flash", c, WHITE, {"radius": 50.0, "life": 0.4})
	w.fx("ring", c, GOLD, {"radius": 44.0, "life": 0.35})
	if !await WeaponTiers.pause(w, 0.35) or int(w._st.ult_id) != my:
		return
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 44.0):
		var m := FINALE_MULT * (1.3 if WeaponUtil.is_exposed(e) else 1.0)
		WeaponUtil.hit(e, WeaponTiers.H(w) * m, c, 200.0, 0.0, "", true)
		WeaponUtil.stun(e, 0.8)
	w.player.shake(5.5, 0.4)
	Sfx.play("big_hit", 0.05)
	Sfx.play("ultimate", 0.02)

## The rope: a thin wavy line from the hand to the tip.
static func aura(a, c) -> void:
	var d: Vector2 = a.aim.rotated(a.swing)
	var n: Vector2 = d.orthogonal()
	var pts := PackedVector2Array()
	for i in 9:
		var u := float(i) / 8.0
		pts.append(d * (a.reach - 4.0 + 34.0 * u) + n * sin(u * 5.0 + a._age * 3.0 + a.swing * 4.0) * 1.8 * u)
	c.draw_polyline(pts, Color(LEATHER, 0.9), 1.0)
	c.draw_circle(pts[pts.size() - 1], 1.0, Color(GOLD, 0.9))
