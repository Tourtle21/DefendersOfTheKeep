extends RefCounted
## Knight's Blade tiers (docs/weapon_tiers/knightblade.md): 2 Oathkeeper, 3 Crescent Third, 4 Counter-Thrust, 5 Knight's Vow, 6 Judgment Day.
## Epic: a duellist's rhythm turned into a ritual. White and gold, formal and readable: crests, spectral swords, a giant sword.
## The old weapon (t2/knightblade.gd) leaves `_st.big` (the last strike was big) and calls the `riposte` and `vow` hooks.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const WHITE := Color(0.92, 0.96, 1.0)
const GOLD := Color(1.0, 0.90, 0.50)
const STEEL := Color(0.55, 0.70, 0.95)
const CREST := Color(0.85, 0.20, 0.20)
const KB_RIPOSTE_WINDOW := 0.7
const KB_WHIFF := 3.5
const KB_COUNTER_MULT := 1.5
const KB_CRESCENT_MULT := 1.0
const KB_VOW_R := 70.0
const KB_SWORDS := 3
const KB_SWORD_SECS := 3.0
const KB_FINALE_MULT := 2.0
const KB_FINISHER_EVERY := 9
const NAMES := ["", "Knight's Blade", "Oathkeeper", "Crescent Third", "Counter-Thrust", "Knight's Vow", "Judgment Day"]
## 3 swords spin at TAU/3 per 0.4 s, so every re-spawned orbit fx starts exactly where the last one ended.
const SWORD_SPIN := 5.2359878

static func palette() -> Array:
	return [WHITE, GOLD, WHITE]

static func equip(w) -> void:
	w._st = {"hits": 0, "big": false, "big_left": 0, "ult_id": 0, "window_until": 0.0, "swords_until": 0.0}

## The aura draws the combo pips next to the hilt (`state` = strikes so far, 0 to 2) and a rim ring while the riposte window is open (`state2`).
static func tick(w, _delta: float) -> void:
	if w.tier < 2 or w._aura == null or !is_instance_valid(w._aura):
		return
	var now := Time.get_ticks_msec() / 1000.0
	w._aura.state = float(w._combo) if now <= w._combo_until else 0.0
	w._aura.state2 = 1.0 if now < float(w._st.get("window_until", 0.0)) else 0.0
	if w.tier >= 5 and now < float(w._st.get("swords_until", 0.0)):
		_swords(w, now)

static func aura(a, c) -> void:
	var d: Vector2 = a.aim.rotated(a.swing)
	var n := d.orthogonal()
	for i in 3:                                                    # three pips beside the hilt
		var on: bool = float(i) < a.state
		c.draw_circle(d * (a.reach - 5.0) + n * (float(i) - 1.0) * 3.0 + n * 5.0, 1.0, Color(GOLD, 0.95) if on else Color(WHITE, 0.25))
	if a.state2 > 0.5:
		c.draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 1.5)

# ---- attack: the third strike throws a slash, a crescent; the 9th combo hit a pillar and a downstrike ----
static func attack(w) -> void:
	w._st.hits = int(w._st.hits) + 1
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	if w._st.get("big", false):
		w.fx("slash", o, GOLD, {"radius": 40.0, "dir": dir, "half_angle": 1.2, "thick": 5.0, "life": 0.25, "col2": WHITE})
		w.fx("shards", o + dir * 30.0, WHITE, {"radius": 18.0, "count": 4, "life": 0.3})
		if w.tier >= 3:
			WeaponProjectile.shoot(w.game_world(), o + dir * 22.0, dir, 260.0, WeaponTiers.H(w) * KB_CRESCENT_MULT, GOLD, 0.4, 3, 100.0, {"style": "crescent", "size": 1.3})
	if w.tier >= 6 and int(w._st.hits) % KB_FINISHER_EVERY == 0:
		_finisher(w, o, dir)

static func _finisher(w, o: Vector2, dir: Vector2) -> void:
	var t = WeaponUtil.nearest(w.get_tree(), o + dir * 24.0, 40.0)
	if t == null:
		return
	var at: Vector2 = t.global_position
	w.fx("pillar", at + Vector2(0, 8), GOLD, {"height": 60.0, "width": 12.0, "life": 0.45})
	WeaponUtil.hit(t, WeaponTiers.H(w), o, 0.0, 0.0, "", true)
	if await WeaponTiers.pause(w, 0.5) and Kit.alive(t):
		w.fx("cut", t.global_position, WHITE, {"radius": 18.0, "spin": 0.0, "life": 0.3, "col2": GOLD})
		WeaponUtil.hit(t, WeaponTiers.H(w) * 0.5, o, 0.0, 0.0, "", true, true)

# ---- riposte ----
static func ability(w) -> void:
	w._st.window_until = Time.get_ticks_msec() / 1000.0 + float(w.parry_window)

## A successful riposte: shield, a shove round the attacker, a star and (tier 4) the counter-thrust back the way you came.
static func riposte(w, from_pos: Vector2, dir: Vector2) -> void:
	w._st.window_until = 0.0
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	w.player.shield_time = maxf(w.player.shield_time, 0.5)
	w.fx("star", from_pos, GOLD, {"radius": 16.0, "count": 5, "spin": 1.0, "life": 0.35})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), from_pos, 40.0):
		Kit.shove(e, from_pos, 150.0, 0.15)
	if w.tier >= 4:
		var attacker = WeaponUtil.nearest(w.get_tree(), from_pos, 24.0)
		if attacker != null:
			WeaponUtil.expose(attacker, 3.0)
		w.fx("streak", o, GOLD, {"dir": dir, "length": minf(70.0, o.distance_to(from_pos) + 20.0), "width": 8.0, "life": 0.25, "col2": WHITE})
		_counter(w, dir)

static func _counter(w, dir: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.24):
		return
	var at: Vector2 = w.player.global_position
	w.fx("slash", at, WHITE, {"radius": 50.0, "dir": -dir, "half_angle": 1.3, "thick": 6.0, "life": 0.25, "col2": GOLD})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 50.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * KB_COUNTER_MULT, at, 160.0, 0.0, "", true)

# ---- dash: Vanguard Dash ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	w.fx("streak", o, WHITE, {"dir": w.aim, "length": 60.0, "width": 7.0, "life": 0.25, "col2": GOLD})
	_arrival(w, w.aim)

static func _arrival(w, dir: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.2):
		return
	var at: Vector2 = w.player.global_position
	w.fx("slash", at, GOLD, {"radius": 40.0, "dir": dir, "half_angle": 1.2, "thick": 6.0, "life": 0.25, "col2": WHITE})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), at, dir, 40.0, 70.0):
		WeaponUtil.hit(e, 1.0, at, 120.0, 0.0, "", true, true)         # the old 2.5 and this 1.0: 3.5 in all

# ---- ultimate: Judgment ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var o: Vector2 = w.player.global_position
	if w.tier >= 3:
		w.fx("sigil", o, GOLD, {"radius": 70.0, "count": 3, "spin": 1.5, "life": 0.3, "col2": WHITE})
	if w.tier >= 6:
		_finale(w, int(w._st.ult_id))

## Tier 5: the three pulses are three great arcs in a rotating fan, and three spectral swords circle you for 3 s.
static func vow(w) -> bool:
	_arcs(w, int(w._st.ult_id))
	w._st.swords_until = Time.get_ticks_msec() / 1000.0 + KB_SWORD_SECS
	w._st.sword_t0 = Time.get_ticks_msec() / 1000.0
	w._st.sword_cut = 0.0
	return true

static func _arcs(w, my: int) -> void:
	for i in 3:
		if !WeaponTiers.alive(w) or int(w._st.ult_id) != my:
			return
		var o: Vector2 = w.player.global_position
		var dir: Vector2 = w.aim.rotated(TAU / 3.0 * float(i))
		w.fx("cone", o, GOLD, {"radius": KB_VOW_R, "dir": dir, "half_angle": 1.05, "life": 0.35, "col2": WHITE})
		w.fx("slash", o, WHITE, {"radius": KB_VOW_R * 0.9, "dir": dir, "half_angle": 1.0, "thick": 8.0, "life": 0.3, "col2": GOLD})
		var struck := {}                                         # the old pulse (everything within 56 px) plus the arc's longer reach, each enemy once
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 56.0) + WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, KB_VOW_R, 60.0):
			if struck.has(e):
				continue
			struck[e] = true
			WeaponUtil.hit(e, 6.0, o, 300.0, 0.0, "", true)
			WeaponUtil.stun(e, 0.3)
		w.player.shake(2.5, 0.12)
		Sfx.play("gong", 0.1)
		if !await WeaponTiers.pause(w, 0.3):
			return

## Called every frame while the swords last: the orbit fx is re-spawned every 0.4 s, and each sword cuts what it touches every 0.5 s.
static func _swords(w, now: float) -> void:
	var t0: float = float(w._st.get("sword_t0", now))
	if now - float(w._st.get("sword_fx", -1.0)) >= 0.4:
		w._st.sword_fx = now
		w.fx("orbit", w.player.global_position, GOLD, {"radius": 26.0, "count": KB_SWORDS, "spin": SWORD_SPIN, "shape": "blade", "life": 0.45})
	if now - float(w._st.get("sword_cut", 0.0)) >= 0.5:
		w._st.sword_cut = now
		w._claim()
		var o: Vector2 = w.player.global_position
		var phase := fposmod(now - float(w._st.get("sword_fx", t0)), 0.4) * SWORD_SPIN
		var hit := {}
		for k in KB_SWORDS:
			var p := o + Vector2.from_angle(phase + float(k) * TAU / float(KB_SWORDS)) * 26.0
			for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 20.0):
				if !hit.has(e):
					hit[e] = true
					WeaponUtil.hit(e, WeaponTiers.H(w) * 0.5, p, 0.0, 0.0, "", true, true)

## FINALE Judgment Day: 1.2 s after the press a giant sword falls on you.
static func _finale(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 1.2) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("fall", o, GOLD, {"radius": 8.0, "height": 140.0, "rise": 0.0, "core": WHITE, "life": 0.5})
	w.fx("sigil", o, GOLD, {"radius": 80.0, "count": 8, "spin": 2.0, "life": 0.5, "col2": WHITE})
	if !await WeaponTiers.pause(w, 0.5) or int(w._st.ult_id) != my:
		return
	o = w.player.global_position
	w.fx("pillar", o, GOLD, {"height": 120.0, "width": 30.0, "life": 0.5})
	w.fx("flash", o, WHITE, {"radius": 80.0, "life": 0.35})
	w.fx("ripple", o, GOLD, {"radius": 100.0, "rings": 3, "life": 0.6})
	w.player.shield_time = maxf(w.player.shield_time, 0.6)
	w.player.shake(6.0, 0.35)
	Sfx.play("ultimate", 0.05)
	Sfx.play("thump", 0.05)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 80.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * KB_FINALE_MULT, o, 380.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.2)
