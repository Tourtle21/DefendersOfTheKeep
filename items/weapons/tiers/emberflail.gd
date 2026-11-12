extends RefCounted
## Ember Flail tiers (docs/weapon_tiers/emberflail.md): 2 Spitfire, 3 Burning Orbit, 4 Lava Whip, 5 Caldera, 6 Volcano.
## Epic: the ground changes. Burn patches hurt PLAYERS, so everything new here is a hit, a `slow` patch or a visual; only the old patches burn.
## (The Magma Maul extends this weapon's script but has its own module.)

const MAGMA := Color(1.0, 0.40, 0.10)
const LAVA := Color(1.0, 0.55, 0.20)
const EMBER := Color(1.0, 0.82, 0.30)
const CHAR := Color(0.25, 0.10, 0.06)
const SPARK_MULT := 0.3
const ORBIT_EVERY := 3
const ORBIT_SECS := 2.0
const ORBIT_MULT := 0.3
const TONGUES := 3
const TONGUE_STRIKES := 6
const CALDERA_SECS := 6.0
const CALDERA_R := 85.0
const VOLCANO_MULT := 2.5
const BOMBS := 10
const BOMB_MULT := 1.0
const FINISHER_EVERY := 6
const LIGHT_BONUS := [0.0, 10.0, 20.0, 30.0, 40.0, 60.0]
const NAMES := ["", "Ember Flail", "Spitfire", "Burning Orbit", "Lava Whip", "Caldera", "Volcano"]

static func palette() -> Array:
	return [MAGMA, LAVA, EMBER]

static func equip(w) -> void:
	w._st = {"swings": 0, "orbit_until": 0.0, "orbit_hit": 0.0, "orbit_fx": 0.0, "ult_id": 0}
	WeaponTiers.light_bonus(w, LIGHT_BONUS)

## The Burning Orbit: the ball spins around you for two seconds and hits what it touches every 0.4 s.
static func tick(w, delta: float) -> void:
	if w.tier >= 6 and w._st.has("glow") and is_instance_valid(w._st.glow):
		w._st.glow.texture_scale = float(w._st.glow_scale) * (1.0 + 0.04 * sin(Time.get_ticks_msec() / 1000.0 * 4.0))
	var now := Time.get_ticks_msec() / 1000.0
	if now >= float(w._st.get("orbit_until", 0.0)):
		return
	var o: Vector2 = w.player.global_position
	w._st.orbit_fx = float(w._st.get("orbit_fx", 0.0)) - delta
	if float(w._st.orbit_fx) <= 0.0:
		w._st.orbit_fx = 0.06
		var ball: Vector2 = o + Vector2.from_angle(now * 6.0) * 28.0
		w.fx("star", ball, LAVA, {"radius": 5.0, "count": 4, "spin": 3.0, "life": 0.18})
	w._st.orbit_hit = float(w._st.get("orbit_hit", 0.0)) - delta
	if float(w._st.orbit_hit) <= 0.0:
		w._st.orbit_hit = 0.4
		w._claim()
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 28.0 + 12.0):
			if e.global_position.distance_to(o) >= 28.0 - 12.0:
				WeaponUtil.hit(e, WeaponTiers.H(w) * ORBIT_MULT, o, 0.0, 0.0, "", true, true)

static func attack(w) -> void:
	w._st.swings = int(w._st.get("swings", 0)) + 1
	var n: int = int(w._st.swings)
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	for side in [-0.35, 0.35]:
		var d: Vector2 = w.aim.rotated(side)
		WeaponProjectile.shoot(w.game_world(), o + d * 12.0, d, 200.0, WeaponTiers.H(w) * SPARK_MULT, LAVA, 0.35, 0, 30.0, {"style": "orb", "size": 0.8})
	if w.tier >= 3 and n % ORBIT_EVERY == 0:
		w._st.orbit_until = Time.get_ticks_msec() / 1000.0 + ORBIT_SECS
	if w.tier >= 6 and n % FINISHER_EVERY == 0:
		_slam(w)

static func _slam(w) -> void:
	if !await WeaponTiers.pause(w, 0.17):
		return
	var o: Vector2 = w.player.global_position
	var c: Vector2 = o + w.aim * 26.0
	w.fx("shock", c, MAGMA, {"radius": 40.0, "thick": 7.0, "life": 0.4, "col2": EMBER})
	w.fx("crack", c, CHAR, {"radius": 40.0, "count": 6, "life": 0.6})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 40.0):
		WeaponUtil.hit(e, WeaponTiers.H(w), o, 260.0, 0.0, "", true)
	for k in 3:
		var d: Vector2 = w.aim.rotated((float(k) - 1.0) * 0.5)
		WeaponProjectile.shoot(w.game_world(), o + d * 12.0, d, 200.0, WeaponTiers.H(w) * SPARK_MULT, LAVA, 0.35, 0, 30.0, {"style": "orb", "size": 0.8})
	Sfx.play("thump", 0.1)

## Tier 2 Spitfire: the eruption throws a pillar and shards. Tier 4 Lava Whip: three lava tongues crawl out in a spiral.
static func ability(w) -> void:
	if w.tier < 2:
		return
	var c: Vector2 = w.cursor_target(90.0)
	_pillar(w, c)
	if w.tier >= 4:
		for k in TONGUES:
			_tongue(w, c, k)

static func _pillar(w, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.45):
		return
	w.fx("pillar", c, MAGMA, {"height": 60.0, "width": 20.0, "life": 0.5})
	w.fx("shards", c, EMBER, {"radius": 40.0, "count": 8, "life": 0.4})

static func _tongue(w, c: Vector2, k: int) -> void:
	var a0 := float(k) * TAU / float(TONGUES) + 0.5
	for j in TONGUE_STRIKES:
		if !await WeaponTiers.pause(w, 0.45 + 0.12 * float(j) if j == 0 else 0.12):
			return
		var p: Vector2 = c + Vector2.from_angle(a0 + float(j) * 0.35) * (12.0 + float(j) * 10.0)
		if j % 3 == 2:
			w.fx("burst", p, LAVA, {"radius": 10.0, "life": 0.25})
			WeaponUtil.patch(w.game_world(), p, "slow", 12.0, Color(LAVA, 0.4), 3.0, 0.6)
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 12.0):
			WeaponUtil.hit(e, WeaponTiers.H(w) * 0.4, p, 0.0, 0.0, "", true, true)

## Tier 4 Lava Whip (dash): a streak, flame pillars along the four patches and a burn on what you pass.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, MAGMA, {"dir": dir, "length": 60.0, "width": 8.0, "life": 0.35, "col2": EMBER})
	for i in 4:
		w.fx("pillar", o + dir * (12.0 + float(i) * 15.0), LAVA, {"height": 30.0, "width": 10.0, "life": 0.5})
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, 60.0, 14.0):
		WeaponUtil.bleed(w.get_tree(), e, 3, WeaponTiers.H(w) * 0.15)

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var my: int = w._st.ult_id
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, MAGMA, {"radius": 90.0, "count": 12, "spin": 1.5, "life": 0.3, "col2": EMBER})
	if w.tier >= 5:
		_caldera(w, my, o)

## Stage 2 Caldera: the ground inside the ring collapses for six seconds. FINALE Volcano at the end.
static func _caldera(w, my: int, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.2) or int(w._st.ult_id) != my:
		return
	WeaponUtil.patch(w.game_world(), o, "slow", CALDERA_R, Color(MAGMA, 0.3), CALDERA_SECS, 0.6)
	LightSource.spawn(w.game_world(), o, 140.0, CALDERA_SECS, Color(1.0, 0.6, 0.3))
	var t := 0.0
	while t < CALDERA_SECS:
		if fposmod(t + 0.01, 0.8) < 0.1:
			w.fx("vortex", o, LAVA, {"radius": CALDERA_R, "count": 4, "spin": 3.0, "inward": true, "life": 1.0})
		var dmg_tick: bool = fposmod(t + 0.01, 1.0) < 0.1
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, CALDERA_R):
			e.push((o - e.global_position).normalized() * 12.0, 0.25)
			if dmg_tick:
				WeaponUtil.hit(e, WeaponTiers.H(w) * 0.2, o, 0.0, 0.0, "", true, true)
		if !await WeaponTiers.pause(w, 0.25) or int(w._st.ult_id) != my:
			return
		t += 0.25
	if w.tier >= 6:
		_volcano(w, my, o)

static func _volcano(w, my: int, o: Vector2) -> void:
	w.fx("sigil", o, MAGMA, {"radius": 50.0, "count": 8, "spin": 2.0, "life": 0.5, "col2": EMBER})
	if !await WeaponTiers.pause(w, 0.5) or int(w._st.ult_id) != my:
		return
	w.fx("pillar", o, MAGMA, {"height": 140.0, "width": 34.0, "life": 0.7})
	w.fx("flash", o, EMBER, {"radius": 70.0, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 50.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * VOLCANO_MULT, o, 360.0, 1.0, "", true)
	w.player.shake(6.5, 0.5)
	Sfx.play("ultimate", 0.02)
	Sfx.play("thump", 0.05)
	for i in BOMBS:                                                   # lava bombs rain outward from the volcano over 1.5 s
		var p: Vector2 = o + Vector2.from_angle(float(i) * 2.4 + 0.5) * (20.0 + 10.0 * float(i))
		_bomb(w, my, p, 0.15 * float(i))

static func _bomb(w, my: int, p: Vector2, delay: float) -> void:
	if delay > 0.0 and (!await WeaponTiers.pause(w, delay) or int(w._st.ult_id) != my):
		return
	w.fx("fall", p, MAGMA, {"radius": 4.0, "height": 90.0, "rise": 10.0, "life": 0.45, "core": EMBER})
	w.ground_strike(p, 18.0, 0.45, WeaponTiers.H(w) * BOMB_MULT, 140.0, MAGMA)

## The flail ball drips embers.
static func aura(a, c) -> void:
	var head: Vector2 = a.aim.rotated(a.swing) * (a.reach + 2.0)
	for k in 2:
		var u: float = fposmod(a._age / 0.4 + float(k) * 0.5, 1.0)
		c.draw_circle(head + Vector2((float(k) - 0.5) * 3.0, -u * 8.0), 0.9 * (1.0 - u) + 0.3, Color(LAVA if k == 0 else EMBER, 0.9 * (1.0 - u)))
