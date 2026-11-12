extends RefCounted
## Magma Maul tiers (docs/weapon_tiers/magmamaul.md): 2 Cooling Crust, 3 Heat Surge, 4 Molten Core, 5 Meltdown, 6 Eruption Titan.
## Mythic: a SYSTEM with a rhythm. HEAT builds (swing +12, Magma Slam +40, Leap Burn +25, a kill +5, decays 8/s after 3 s), then at 100 the weapon goes MOLTEN
## for 6 s and every verb doubles. The loudest weapon of its band, but you control when. The player is the effect, not the ground.
## Heat lives in `_st.heat` and reaches clients as the aura's `state` (0..100) and `state2` (1 = molten).
## Burn patches hurt players, so nothing here makes a NEW one: every new ground piece is a fx, a strike or a `slow` patch.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const MAGMA := Color(1.0, 0.38, 0.08)
const MOLTEN := Color(1.0, 0.60, 0.20)
const HOT := Color(1.0, 0.92, 0.60)
const OBSIDIAN := Color(0.20, 0.10, 0.10)
const MM_HEAT_SWING := 12.0
const MM_HEAT_SLAM := 40.0
const MM_HEAT_LEAP := 25.0
const MM_HEAT_KILL := 5.0
const MM_DECAY := 8.0
const MM_DECAY_DELAY := 3.0
const MM_MOLTEN_SECS := 6.0
const MM_MOLTEN_CD := 12.0
const MM_SLAP_EVERY := 3
const MM_MOLTEN_MULT := 1.4
const MM_GEYSER_MULT := 0.5
const MM_BOMB_EVERY := 1.0
const MM_TITAN_SECS := 8.0
const MM_FINALE_MULT := 2.0
const MM_FINISHER_EVERY := 5
const MM_LIGHT_BONUS := [0, 10, 20, 30, 40, 60]
const NAMES := ["", "", "Cooling Crust", "Heat Surge", "Molten Core", "Meltdown", "Eruption Titan"]

static func palette() -> Array:
	return [MAGMA, HOT, MOLTEN]

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func equip(w) -> void:
	w._st = {"heat": 0.0, "last_gain": -100.0, "molten_until": 0.0, "molten_cd_until": 0.0, "titan_until": 0.0, "swings": 0, "mswings": 0,
		"ult_id": 0, "ember": 0.0, "bomb": 0.0}
	WeaponTiers.light_bonus(w, MM_LIGHT_BONUS)

static func is_molten(w) -> bool:
	return now() < float(w._st.get("molten_until", 0.0)) or now() < float(w._st.get("titan_until", 0.0))

static func is_titan(w) -> bool:
	return now() < float(w._st.get("titan_until", 0.0))

## Adds heat; at 100 (tier 4+) the weapon goes molten, at most once every 12 s.
static func gain(w, n: float) -> void:
	if w.tier < 2 or is_molten(w):
		return
	w._st.heat = minf(100.0, float(w._st.heat) + n)
	w._st.last_gain = now()
	if w.tier >= 4 and float(w._st.heat) >= 100.0 and now() >= float(w._st.molten_cd_until):
		go_molten(w, MM_MOLTEN_SECS)

static func go_molten(w, secs: float) -> void:
	w._st.molten_until = now() + secs
	w._st.molten_cd_until = now() + MM_MOLTEN_CD
	w._st.heat = 100.0
	var o: Vector2 = w.player.global_position
	w.fx("flash", o + w.aim * (w.reach + 6.0), HOT, {"radius": 22.0, "life": 0.3})
	w.fx("burst", o + w.aim * (w.reach + 6.0), MAGMA, {"radius": 16.0, "life": 0.3})
	Sfx.play("cast", 0.05, 0.7)

static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	var t := now()
	var heat: float = float(w._st.heat)
	if t < float(w._st.titan_until):
		heat = 100.0
	elif t < float(w._st.molten_until):
		heat = 100.0 * (float(w._st.molten_until) - t) / MM_MOLTEN_SECS            # the heat drains to 0 over the 6 s
	elif t - float(w._st.last_gain) > MM_DECAY_DELAY:
		heat = maxf(0.0, heat - MM_DECAY * delta)
	w._st.heat = heat
	if w._aura != null and is_instance_valid(w._aura):
		w._aura.state = float(int(heat))
		w._aura.state2 = 1.0 if is_molten(w) else 0.0
	# the whole sprite shimmers toward white-hot (tier 3+ above heat 60), fully white-hot while molten at tier 6
	if w.tier >= 3:
		var k := clampf((heat - 60.0) / 40.0, 0.0, 1.0)
		if w.tier >= 6 and is_molten(w):
			k = 1.0
		w.modulate = Color(1, 1, 1).lerp(Color(1.9, 1.5, 1.1), k)
	# embers drip from the head, two motes every 0.5 s
	w._st.ember = float(w._st.ember) + delta
	if float(w._st.ember) >= 0.5:
		w._st.ember = 0.0
		w.fx("motes", w.player.global_position + w.aim * (w.reach + 6.0), MOLTEN, {"radius": 5.0, "count": 2, "rise": -8.0, "life": 0.5})
	# Eruption Titan: a lava bomb on a random enemy every second
	if is_titan(w) and t - float(w._st.bomb) >= MM_BOMB_EVERY:
		w._st.bomb = t
		_bomb(w)

static func _bomb(w) -> void:
	var o: Vector2 = w.player.global_position
	var e = null
	var pool := WeaponUtil.random_enemies(w.get_tree(), o, 110.0, 1)
	if !pool.is_empty():
		e = pool[0]
	if e == null:
		return
	var at: Vector2 = e.global_position
	w.fx("fall", at, MAGMA, {"radius": 5.0, "height": 90.0, "rise": 0.0, "core": HOT, "life": 0.4})
	w._claim()
	w.ground_strike(at, 24.0, 0.4, WeaponTiers.H(w), 200.0, MAGMA)

static func aura(a, c) -> void:
	var d: Vector2 = a.aim.rotated(a.swing)
	var head: Vector2 = d * a.reach
	var heat: float = a.state / 100.0
	var n := d.orthogonal()
	for k in 4:                                                    # four seam lines in the head, brighter with heat
		var off := (float(k) - 1.5) * 2.4
		c.draw_line(head + n * off - d * 3.0, head + n * off + d * 3.0, Color(MAGMA.lerp(HOT, heat), 0.15 + 0.85 * heat), 1.0)
	if a.state2 > 0.5:                                             # molten: a ring of cracks round the head
		for k in 10:
			var an: float = float(k) * TAU / 10.0 + a._age * 0.5
			c.draw_line(head + Vector2.from_angle(an) * 6.0, head + Vector2.from_angle(an) * (9.0 + 3.0 * WeaponAura.jit(k, 2.0)), Color(HOT, 0.9), 1.0)

## A kill adds heat (a hit that leaves the enemy at no health).
static func on_hit(w, e, _dmg: float) -> void:
	if w.tier >= 2 and is_instance_valid(e) and float(e.health) <= 0.0:
		gain(w, MM_HEAT_KILL)

# ---- attack: chips, the lava slap, the molten swing, the finisher ----
static func attack(w) -> void:
	w._st.swings = int(w._st.swings) + 1
	if w.tier < 2:
		return
	var slap: bool = w.tier >= 3 and int(w._st.swings) % MM_SLAP_EVERY == 0
	gain(w, MM_HEAT_SWING + (MM_HEAT_SWING if slap else 0.0))
	var molten := is_molten(w)
	var fin := false
	if molten:
		w._st.mswings = int(w._st.mswings) + 1
		fin = w.tier >= 6 and int(w._st.mswings) % MM_FINISHER_EVERY == 0
	_after_swing(w, slap, molten, fin)

static func _after_swing(w, slap: bool, molten: bool, fin: bool) -> void:
	if !await WeaponTiers.pause(w, 0.24):
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var c: Vector2 = o + dir * 24.0
	var h := WeaponTiers.H(w)
	w.fx("shards", c, OBSIDIAN, {"radius": 14.0, "count": 4, "life": 0.3})
	w.fx("burst", c, MOLTEN, {"radius": 10.0, "life": 0.2})
	if slap:
		w.fx("shock", c, MAGMA, {"radius": 40.0, "thick": 7.0, "life": 0.3, "col2": HOT})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 40.0):
			WeaponUtil.hit(e, h, o, 320.0, 0.0, "", true, true)
		Sfx.play("thump", 0.1)
	if molten:
		_molten_slam(w, c, o, 1.0)
		if is_titan(w):                                              # every swing of the Titan is a double slam
			if await WeaponTiers.pause(w, 0.3):
				_molten_slam(w, c, w.player.global_position, 0.7)
	if fin:
		_fire_stream(w, o, dir)

## The molten swing: a full slam in r 44 (1.4 H; the old swing already did 1.0 H inside r 34).
static func _molten_slam(w, c: Vector2, from: Vector2, mult: float) -> void:
	var h := WeaponTiers.H(w)
	w.fx("shock", c, MAGMA, {"radius": 44.0, "thick": 6.0, "life": 0.3, "col2": HOT})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 44.0):
		var inner: bool = e.global_position.distance_to(c) <= 34.0 + float(e.get("hit_radius") if e.get("hit_radius") != null else 0.0)
		var m: float = (MM_MOLTEN_MULT - 1.0) if (inner and mult >= 1.0) else MM_MOLTEN_MULT
		WeaponUtil.hit(e, h * m * mult, from, 200.0, 0.0, "", true, true)
	w.player.shake(3.0, 0.15)

static func _fire_stream(w, o: Vector2, dir: Vector2) -> void:
	var h := WeaponTiers.H(w)
	w.fx("cone", o, MAGMA, {"radius": 70.0, "dir": dir, "half_angle": 0.6, "life": 0.35, "col2": HOT})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 70.0, rad_to_deg(0.6)):
		WeaponUtil.hit(e, h * 0.8, o, 160.0, 0.0, "", true, true)
	for k in 3:
		var d: Vector2 = dir.rotated(float(k - 1) * 0.3)
		WeaponProjectile.shoot(w.game_world(), o + d * 16.0, d, 170.0, h * 0.6, MAGMA, 0.5, 0, 80.0, {"style": "orb", "size": 1.2, "glow": 0.3, "burst_r": 22.0})

# ---- ability: Magma Slam ----
static func ability(w) -> void:
	if w.tier < 2:
		return
	var c: Vector2 = w.cursor_target(100.0)
	var molten := is_molten(w)
	gain(w, MM_HEAT_SLAM)
	_crust(w, c)
	if molten:
		_second_slam(w, c)

## The crater grows a crust ring and throws six lava shards at the rim.
static func _crust(w, c: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.62):
		return
	var h := WeaponTiers.H(w)
	w.fx("crack", c, MAGMA, {"radius": 50.0, "count": 6, "life": 0.8})
	w.fx("shards", c, MOLTEN, {"radius": 80.0, "count": 6, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 80.0):
		if e.global_position.distance_to(c) > 44.0:
			WeaponUtil.hit(e, h * 0.4, c, 60.0, 0.0, "", true, true)

## Molten: a second strike 0.5 s after the first, 40 px to one side, at 70% (its crater is a slow patch: no new fire on the ground).
static func _second_slam(w, c: Vector2) -> void:
	var side: Vector2 = w.aim.orthogonal() * (40.0 if int(w._st.swings) % 2 == 0 else -40.0)
	var c2: Vector2 = c + side
	w.ground_strike(c2, 44.0, 1.1, 8.0 * 0.7, 320.0, MAGMA, 0.8, ["stone"])
	if await WeaponTiers.pause(w, 1.12):
		WeaponUtil.patch(w.game_world(), c2, "slow", 44.0, Color(0.6, 0.25, 0.1, 0.5), 4.0, 0.5)

# ---- dash: Leap Burn ----
static func dash(w) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var molten := is_molten(w)
	gain(w, MM_HEAT_LEAP)
	if w.tier >= 4:
		w.fx("streak", o, MAGMA, {"dir": dir, "length": 70.0, "width": 10.0, "life": 0.3, "col2": HOT})
		_leap_land(w, o + dir * 70.0, molten)

static func _leap_land(w, land: Vector2, molten: bool) -> void:
	if !await WeaponTiers.pause(w, 0.24):
		return
	w.fx("flash", land, HOT, {"radius": 40.0, "life": 0.3})
	if molten:                                                       # molten: an immediate second leap-slam
		w.ground_strike(land, 30.0, 0.3, 4.0, 240.0, MAGMA, 0.5)

# ---- ultimate: Magma Ring, Meltdown, Eruption Titan ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	var o: Vector2 = w.player.global_position
	if w.tier >= 3:
		w.fx("sigil", o, MAGMA, {"radius": 90.0, "count": 12, "spin": 1.5, "life": 0.3, "col2": HOT})
		_ring_heat(w, my)
	if w.tier >= 5:
		for i in 12:
			_geyser(w, my, o + Vector2.from_angle(float(i) * TAU / 12.0) * 85.0, 0.3 + 0.04 * float(i) + 0.8)
		_meltdown_end(w, my, o)

static func _ring_heat(w, my: int) -> void:
	for k in 2:                                                      # each ring of the ultimate adds heat
		if !await WeaponTiers.pause(w, 0.5) or int(w._st.ult_id) != my:
			return
		gain(w, 30.0)

## Tier 5: 0.8 s after a strike lands it leaves a lava geyser: a pillar and a second strike.
static func _geyser(w, my: int, p: Vector2, at: float) -> void:
	if !await WeaponTiers.pause(w, at) or int(w._st.ult_id) != my:
		return
	w.fx("pillar", p + Vector2(0, 6), MAGMA, {"height": 70.0, "width": 16.0, "life": 0.5})
	w.ground_strike(p, 22.0, 0.1, WeaponTiers.H(w) * MM_GEYSER_MULT, 160.0, MOLTEN)

static func _meltdown_end(w, my: int, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.7) or int(w._st.ult_id) != my:
		return
	w.fx("flash", o, HOT, {"radius": 85.0, "life": 0.4})
	w.player.shake(4.0, 0.3)
	if w.tier >= 6:
		_titan(w, my)
	else:
		go_molten(w, MM_MOLTEN_SECS)                                 # Meltdown: the ring ends with you molten

## FINALE + TRANSFORMATION Eruption Titan: 8 s as the volcano, then a great eruption.
static func _titan(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 0.7) or int(w._st.ult_id) != my:         # (press + 2.4 s)
		return
	w._st.titan_until = now() + MM_TITAN_SECS
	w._st.heat = 100.0
	w.fx("flash", w.player.global_position, HOT, {"radius": 30.0, "life": 0.3})
	Sfx.play("ultimate", 0.05, 0.8)
	if !await WeaponTiers.pause(w, MM_TITAN_SECS - 0.4) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, MAGMA, {"radius": 90.0, "count": 12, "spin": 2.0, "life": 0.4, "col2": HOT})
	if !await WeaponTiers.pause(w, 0.4) or int(w._st.ult_id) != my:
		return
	o = w.player.global_position
	w.fx("flash", o, HOT, {"radius": 90.0, "life": 0.4})
	w.fx("pillar", o, MAGMA, {"height": 160.0, "width": 40.0, "life": 0.6})
	w.fx("shock", o, MOLTEN, {"radius": 100.0, "thick": 8.0, "life": 0.45, "col2": HOT})
	w.fx("crack", o, OBSIDIAN, {"radius": 100.0, "count": 12, "life": 0.8})
	w.player.shake(7.0, 0.4)
	Sfx.play("ultimate", 0.05)
	Sfx.play("thump", 0.05)
	LightSource.spawn(w.game_world(), o, 190.0, 5.0, Color(1.0, 0.6, 0.25))
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 90.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * MM_FINALE_MULT, o, 420.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.2)
