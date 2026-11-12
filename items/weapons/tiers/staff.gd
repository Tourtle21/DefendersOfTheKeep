extends RefCounted
## Staff tiers (docs/weapon_tiers/staff.md): 2 Echoing Bolt, 3 Rune Circle, 4 Rift Twins, 5 Arcane Comets, 6 Cosmos.
## Epic: it begins to change the ground; from tier 4 each verb combines two effects (blast and bridge, rift and rift, storm and comets).
## The bolt's own parameters (orb, burst, big bolt, chain, nova) are set in staff.gd attack(); this module adds the rest.

const ARCANE := Color(0.60, 0.45, 1.0)
const BRIGHT := Color(0.78, 0.65, 1.0)
const CORE := Color(0.95, 0.90, 1.0)
const FIRE := Color(1.0, 0.55, 0.20)
const RUNE_SECS := 3.0
const TWIN_MULT := 2.2 / 4.8
const COMETS := 3
const STARS := 5
const LIGHT_BONUS := [0.0, 0.0, 10.0, 20.0, 30.0, 40.0]
const NAMES := ["", "Staff", "Echoing Bolt", "Rune Circle", "Rift Twins", "Arcane Comets", "Cosmos"]

static func palette() -> Array:
	return [ARCANE, BRIGHT, CORE]

static func equip(w) -> void:
	w._st = {"bolts": 0, "ult_id": 0}
	WeaponTiers.light_bonus(w, LIGHT_BONUS)

## Tier 2+ Arcane Burst: the echoes are runes; tier 3 the main blast leaves a rune circle; tier 4 a twin blast across you.
static func ability(w) -> void:
	if w.tier < 2:
		return
	var c: Vector2 = w.cursor_target(100.0)
	for i in 5:
		w.fx("sigil", c + Vector2.from_angle(float(i) * TAU / 5.0 + 0.5) * 38.0, BRIGHT, {"radius": 18.0, "count": 4, "spin": 2.0, "life": 0.7 + float(i) * 0.1, "col2": CORE})
	if w.tier >= 3:
		_rune_circle(w, c)
	if w.tier >= 4:
		_twin(w, c)

static func _rune_circle(w, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.5):
		return
	var t := 0.0
	var pulses := 0
	while t < RUNE_SECS:
		w.fx("sigil", c, ARCANE, {"radius": 30.0, "count": 6, "spin": 1.0, "life": 0.55, "col2": CORE})
		if fposmod(t + 0.01, 1.0) < 0.1 and t > 0.1:
			pulses += 1
			for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 30.0):
				WeaponUtil.hit(e, WeaponTiers.H(w) * 0.5, c, 60.0, 0.0, "", true, true)
		if !await WeaponTiers.pause(w, 0.5):
			return
		t += 0.5
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 30.0):       # the third pulse, as the circle closes
		WeaponUtil.hit(e, WeaponTiers.H(w) * 0.5, c, 60.0, 0.0, "", true, true)

## Tier 4 Rift Twins (ability): a second burst where the cursor is mirrored through you, joined by lightning.
static func _twin(w, c: Vector2) -> void:
	var o: Vector2 = w.player.global_position
	var m: Vector2 = o - (c - o).limit_length(100.0)
	w.ground_strike(m, 24.0, 0.7, WeaponTiers.H(w) * TWIN_MULT, 120.0, ARCANE, 0.0)
	if !await WeaponTiers.pause(w, 0.7):
		return
	var dir: Vector2 = (c - m).normalized()
	var len: float = c.distance_to(m)
	w.fx("bolt", m, BRIGHT, {"dir": dir, "length": len, "width": 2.0, "life": 0.3})
	for e in WeaponUtil.enemies_in_line(w.get_tree(), m, dir, len, 8.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * 0.5, m, 0.0, 0.0, "", true, true)

## Tier 4 Rift Twins (blink): a second rift where you arrive.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var at: Vector2 = w.player.global_position
	w.fx("ring", at, BRIGHT, {"radius": 26.0, "life": 1.4})
	_rift(w, at)

static func _rift(w, at: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.4):
		return
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 26.0 + 8.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * 0.7, at, 120.0, 0.0, "", true)
		if is_instance_valid(e) and e.has_method("apply_slow"):
			e.apply_slow(0.4, 1.0)
	w.fx("ring", at, CORE, {"radius": 32.0, "life": 0.3})

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var my: int = w._st.ult_id
	var c: Vector2 = w.cursor_target(110.0)
	w._st.storm_c = c
	w.fx("sigil", c, ARCANE, {"radius": 80.0, "count": 8, "spin": 1.2, "life": 0.3, "col2": CORE})
	if w.tier >= 5:
		_comets(w, my, c)
	if w.tier >= 6:
		_cosmos(w, my, c)

## Tier 5: each storm strike is a falling comet (called per strike by Staff.ultimate).
static func rain_point(w, p: Vector2) -> void:
	w.fx("fall", p, ARCANE, {"radius": 4.0, "height": 90.0, "rise": 8.0, "life": 0.45, "core": CORE})
	_afterglow(w, p)

static func _afterglow(w, p: Vector2) -> void:
	if await WeaponTiers.pause(w, 0.45):
		w.fx("burst", p, BRIGHT, {"radius": 14.0, "life": 0.4})

## Stage 2 Comets: three homing orbs rise from the circle after the storm.
static func _comets(w, my: int, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 3.2) or int(w._st.ult_id) != my:
		return
	var best = null
	var best_hp := -1.0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 160.0):
		if float(e.health) > best_hp:
			best_hp = float(e.health)
			best = e
	for i in COMETS:
		var from: Vector2 = c + Vector2.from_angle(float(i) * TAU / float(COMETS) + 0.4) * 30.0
		var dir: Vector2 = (best.global_position - from).normalized() if best != null else Vector2.from_angle(float(i) * TAU / float(COMETS))
		WeaponProjectile.shoot(w.game_world(), from, dir, 180.0, WeaponTiers.H(w) * 2.0, ARCANE, 2.0, 0, 120.0, {"style": "orb", "size": 1.4, "homing": 0.5, "burst_r": 30.0, "trail": 5})
		w.fx("ring", from, BRIGHT, {"radius": 12.0, "life": 0.3})

## FINALE Cosmos: the storm area becomes a night sky; stars fall on enemies, the last one is giant.
static func _cosmos(w, my: int, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 3.5) or int(w._st.ult_id) != my:
		return
	LightSource.spawn(w.game_world(), c, 150.0, 6.0, Color(0.7, 0.6, 1.0))
	w.fx("sigil", c, ARCANE, {"radius": 110.0, "count": 12, "spin": 0.8, "life": 1.0, "col2": CORE})
	var t := 0.0
	var stars := 0
	while t < 6.0:
		if fposmod(t + 0.01, 0.8) < 0.1:
			w.fx("vortex", c, BRIGHT, {"radius": 110.0, "count": 3, "spin": 2.0, "life": 0.8})
		if fposmod(t + 0.01, 1.0) < 0.1:
			for k in 3:
				var sp: Vector2 = c + Vector2.from_angle(float(k) * 2.1 + t * 1.7) * (30.0 + 25.0 * float(k))
				w.fx("star", sp, CORE, {"radius": 6.0, "count": 5, "spin": 1.0, "life": 0.8})
			if stars < STARS:
				stars += 1
				var tgt = WeaponUtil.random_enemies(w.get_tree(), c, 110.0, 1)
				var p: Vector2 = tgt[0].global_position if !tgt.is_empty() else c + Vector2.from_angle(float(stars) * 1.3) * 60.0
				w.fx("fall", p, BRIGHT, {"radius": 4.0, "height": 90.0, "rise": 10.0, "life": 0.45, "core": CORE})
				w.ground_strike(p, 18.0, 0.45, WeaponTiers.H(w), 100.0, BRIGHT)
			elif stars == STARS:
				stars += 1
				w.fx("fall", c, ARCANE, {"radius": 8.0, "height": 130.0, "rise": 0.0, "life": 0.5, "core": CORE})
				w.ground_strike(c, 50.0, 0.5, WeaponTiers.H(w) * 2.0, 200.0, ARCANE, 1.0)
		if !await WeaponTiers.pause(w, 0.2) or int(w._st.ult_id) != my:
			return
		t += 0.2
	w.player.shake(6.0, 0.4)
	Sfx.play("ultimate", 0.02)

## Two rune sparks orbit the head; the gem pulses.
static func aura(a, c) -> void:
	var head: Vector2 = a.aim.rotated(a.swing) * (a.reach + 2.0)
	c.draw_circle(head, 1.8 + 0.6 * sin(a._age * 4.0), Color(BRIGHT, 0.35))
	for k in 2:
		var p: Vector2 = head + Vector2.from_angle(a._age * 3.0 + float(k) * PI) * 6.0
		c.draw_line(p + Vector2(-1.5, 0), p + Vector2(1.5, 0), Color(CORE, 0.9), 1.0)
		c.draw_line(p + Vector2(0, -1.5), p + Vector2(0, 1.5), Color(CORE, 0.9), 1.0)
