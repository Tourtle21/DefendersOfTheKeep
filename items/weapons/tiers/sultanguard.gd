extends RefCounted
## Sultan's Guard tiers (docs/weapon_tiers/sultanguard.md): 2 Mirrored Wave, 3 Desert Shield, 4 Oasis Mirage, 5 Sandwall, 6 Sultan's Judgment.
## Epic: a counter weapon with a sand theme: each tier gives a mirage, a wall or a bigger counter. Dispatch is by weapon_id: the Scimitar's module does not run here.
## The old weapon (t2/sultanguard.gd) sends six crescents at tier 2+, widens the window at tier 3 and calls the `parry` hook; `_st.parried` says whether the window was used.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const BRASS := Color(0.95, 0.80, 0.45)
const SHIELD := Color(0.50, 0.65, 0.95)
const SAND := Color(0.92, 0.75, 0.40)
const RUBY := Color(0.80, 0.20, 0.20)
const SG_CRESCENTS := 6
const SG_REFLECT_R := 70.0
const SG_WINDOW := 0.55
const SG_MIRAGE_SECS := 3.0
const SG_MIRAGE_TICK := 0.5
const SG_MIRAGE_MULT := 0.4
const SG_DEVIL_SECS := 4.0
const SG_DEVIL_MULT := 0.3
const SG_BLADES := 8
const SG_FINISHER_EVERY := 6
const SG_DANCE_EVERY := 3
const NAMES := ["", "Sultan's Guard", "Mirrored Wave", "Desert Shield", "Oasis Mirage", "Sandwall", "Sultan's Judgment"]

static func palette() -> Array:
	return [BRASS, RUBY, SAND]

static func equip(w) -> void:
	w._st = {"slashes": 0, "ult_id": 0, "window_until": 0.0, "wall_until": 0.0, "mirages": 0, "parried": false, "slash_ms": -1000}

## `state` = the parry window is open (the small shield on the guard glows); the sand wall eats enemy shots during the cyclone.
static func tick(w, _delta: float) -> void:
	if w.tier < 2:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if w._aura != null and is_instance_valid(w._aura):
		w._aura.state = 1.0 if now < float(w._st.get("window_until", 0.0)) else 0.0
	if w.tier >= 5 and now < float(w._st.get("wall_until", 0.0)):
		for sh in w.get_tree().get_nodes_in_group("enemy_shot"):
			if Kit.alive(sh) and sh.global_position.distance_to(w.player.global_position) <= 50.0:
				w.fx("burst", sh.global_position, SAND, {"radius": 8.0, "life": 0.2})
				sh.queue_free()

static func aura(a, c) -> void:
	var d: Vector2 = a.aim.rotated(a.swing)
	var p: Vector2 = d * (a.reach - 3.0) + d.orthogonal() * 5.0         # the small round shield fused to the guard
	c.draw_circle(p, 3.2, Color(SHIELD, 0.85 if a.state < 0.5 else 1.0))
	c.draw_arc(p, 3.2, 0.0, TAU, 12, Color(BRASS, 0.95), 1.0)
	if a.state > 0.5:
		c.draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, Color(SHIELD, 0.7), 1.5)

## Bleeding enemies show sand motes.
static func on_hit(w, e, _dmg: float) -> void:
	if w.tier >= 2 and Kit.alive(e) and !WeaponTiers.marked(e, "sandmotes"):
		WeaponTiers.mark(e, "sandmotes", 0.5)
		w.fx("motes", e.global_position, SAND, {"radius": 8.0, "count": 3, "rise": 10.0, "life": 0.5})

# ---- attack: the double swing with a shield bash, the free riposte wave ----
static func attack(w) -> void:
	var now := Time.get_ticks_msec()
	if now - int(w._st.get("slash_ms", -1000)) < 120:
		return
	w._st.slash_ms = now
	w._st.slashes = int(w._st.slashes) + 1
	if w.tier < 3:
		return
	var n: int = w._st.slashes
	if w.tier >= 3 and n % SG_DANCE_EVERY == 0:
		_dance(w)
	if w.tier >= 6 and n % SG_FINISHER_EVERY == 0:
		var o: Vector2 = w.player.global_position
		for s in [-0.15, 0.15]:                                 # a free Riposte Wave: two crescents forward
			var d: Vector2 = w.aim.rotated(s)
			WeaponProjectile.shoot(w.game_world(), o + d * 12.0, d, 260.0, WeaponTiers.H(w), BRASS, 0.5, 3, 100.0, {"bleed_ticks": 4, "bleed_dmg": 1.0, "style": "crescent", "size": 1.2})

## Tier 3: every 3rd slash is a double swing, and the shield bashes the other flank.
static func _dance(w) -> void:
	if !await WeaponTiers.pause(w, 0.12):
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var h := WeaponTiers.H(w)
	w.fx("arc", o, BRASS, {"radius": 30.0, "dir": dir, "half_angle": 1.2, "life": 0.16})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 30.0, 70.0):
		WeaponUtil.hit(e, h * 0.6, o, 60.0)
		WeaponUtil.bleed(w.get_tree(), e, 3, 0.7)
	w.fx("slash", o, SHIELD, {"radius": 28.0, "dir": dir.rotated(0.5), "half_angle": 1.0, "thick": 5.0, "life": 0.22, "col2": BRASS})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir.rotated(0.5), 28.0, 55.0):
		WeaponUtil.hit(e, h * 0.6, o, 240.0, 0.0, "", true, true)
		WeaponUtil.stun(e, 0.4)

# ---- ability: Mirrored Wave reflects shots; the whiff raises a veil; the parry leaves a mirage ----
static func ability(w) -> void:
	w._st.window_until = Time.get_ticks_msec() / 1000.0 + (SG_WINDOW if w.tier >= 3 else 0.4)
	if w.tier >= 3:
		_veil(w)

static func _veil(w) -> void:
	if !await WeaponTiers.pause(w, SG_WINDOW + 0.04):
		return
	if !w._st.get("parried", false):
		w.player.shield_time = maxf(w.player.shield_time, 0.4)
		w.fx("motes", w.player.global_position, SAND, {"radius": 14.0, "count": 6, "rise": 14.0, "life": 0.6})

static func parry(w, _from: Vector2) -> void:
	w._st.window_until = 0.0
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	for sh in w.get_tree().get_nodes_in_group("enemy_shot"):          # Mirrored Wave: shots near you are reversed
		if Kit.alive(sh) and sh.global_position.distance_to(o) <= SG_REFLECT_R:
			var back: Vector2 = -sh.vel.normalized()
			WeaponProjectile.shoot(w.game_world(), sh.global_position, back, 180.0, maxf(1.0, float(sh.damage) / 10.0), SAND, 1.0, 0, 40.0)
			w.fx("burst", sh.global_position, SAND, {"radius": 8.0, "life": 0.2})
			sh.queue_free()
	if w.tier >= 4:
		mirage(w, o, SG_MIRAGE_SECS, SG_MIRAGE_TICK, 30.0, SG_MIRAGE_MULT, false)

## A mirage of you stands where you were and cuts what comes near. Never more than two at once.
static func mirage(w, at: Vector2, secs: float, tick_s: float, r: float, mult: float, slow: bool) -> void:
	if int(w._st.mirages) >= 2:
		return
	w._st.mirages = int(w._st.mirages) + 1
	_run_mirage(w, at, secs, tick_s, r, mult, slow)

static func _run_mirage(w, at: Vector2, secs: float, tick_s: float, r: float, mult: float, slow: bool) -> void:
	var t := 0.0
	while t < secs:
		w.fx("orbit", at, SAND, {"radius": 6.0, "count": 1, "spin": 5.0, "shape": "blade", "life": tick_s + 0.1})
		if !await WeaponTiers.pause(w, tick_s):
			return
		t += tick_s
		w.fx("ring", at, SAND, {"radius": r, "life": 0.2})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, r):
			WeaponUtil.hit(e, WeaponTiers.H(w) * mult, at, 0.0, 0.0, "", true, true)
			if Kit.alive(e):
				if slow:
					e.apply_slow(0.6, 0.6)
				else:
					WeaponUtil.bleed(w.get_tree(), e, 2, 0.5)
	w._st.mirages = maxi(0, int(w._st.mirages) - 1)

# ---- dash: Oasis Mirage ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	w.fx("streak", o, SAND, {"dir": w.aim, "length": 50.0, "width": 7.0, "life": 0.25, "col2": BRASS})
	mirage(w, o, 2.5, 0.4, 26.0, SG_MIRAGE_MULT, true)

# ---- ultimate: Sand Cyclone, Sandwall, Sultan's Judgment ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	var o: Vector2 = w.player.global_position
	if w.tier >= 3:
		w.fx("sigil", o, SAND, {"radius": 52.0, "count": 6, "spin": 1.5, "life": 0.25, "col2": BRASS})
	if w.tier >= 5:
		w._st.wall_until = Time.get_ticks_msec() / 1000.0 + 1.6
		_sandwall(w, my)

static func _sandwall(w, my: int) -> void:
	for i in 5:                                                    # the five pulses become sand vortices that widen
		w.fx("vortex", w.player.global_position, SAND, {"radius": 52.0 + 4.5 * float(i), "count": 3, "spin": 2.0, "life": 0.45})
		if !await WeaponTiers.pause(w, 0.3) or int(w._st.ult_id) != my:
			return
	var o: Vector2 = w.player.global_position
	WeaponUtil.patch(w.game_world(), o, "slow", 70.0, Color(0.92, 0.75, 0.40, 0.4), SG_DEVIL_SECS, 0.5)
	if w.tier >= 6:
		_judgment(w, my, o)
	for k in int(SG_DEVIL_SECS):                                   # the dust devil: 0.3 H a second
		if !await WeaponTiers.pause(w, 1.0) or int(w._st.ult_id) != my:
			return
		w.fx("vortex", o, SAND, {"radius": 40.0, "count": 2, "spin": 3.0, "life": 0.9})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 70.0):
			WeaponUtil.hit(e, WeaponTiers.H(w) * SG_DEVIL_MULT, o, 0.0, 0.0, "", true, true)

## FINALE Sultan's Judgment: the cyclone explodes and eight great scimitars spiral out.
static func _judgment(w, my: int, o: Vector2) -> void:
	w.fx("pillar", o, SAND, {"height": 120.0, "width": 30.0, "life": 0.5})
	w.fx("flash", o, BRASS, {"radius": 70.0, "life": 0.35})
	w.fx("shock", o, SAND, {"radius": 80.0, "thick": 6.0, "life": 0.4, "col2": BRASS})
	w.player.shake(6.0, 0.35)
	Sfx.play("big_hit", 0.05)
	Sfx.play("ultimate", 0.05)
	for k in SG_BLADES:
		var d := Vector2.from_angle(float(k) * TAU * 1.25 / float(SG_BLADES))          # one and a quarter turns: a spiral
		WeaponProjectile.shoot(w.game_world(), o + d * 10.0, d, 240.0, WeaponTiers.H(w), BRASS, 0.5, 3, 140.0, {"style": "crescent", "size": 1.6, "bleed_ticks": 3, "bleed_dmg": 1.0})
		if !await WeaponTiers.pause(w, 0.05) or int(w._st.ult_id) != my:
			return
