extends RefCounted
## Frost Glaive tiers (docs/weapon_tiers/frostglaive.md): 2 Rime, 3 Ice Comb, 4 Ice Rink, 5 Whiteout, 6 Absolute Zero.
## Rare: a control weapon whose payoff is a chain of conditions (chilled, exposed, frozen) that the last tiers cash in.
## (The Rimelance extends this script's weapon but has its own module.)

const ICE := Color(0.70, 0.90, 1.0)
const DEEP := Color(0.35, 0.60, 0.90)
const FROST := Color(0.92, 0.98, 1.0)
const SHARD := Color(0.80, 0.95, 1.0)
const COMB_EVERY := 3
const COMB_MULT := 0.6
const FAN_ANGLE := 0.45
const FAN_SPIKES := [28.0, 52.0]
const RINK_PATCHES := 3
const WHITEOUT_SECS := 4.0
const WHITEOUT_R := 120.0
const FINALE_R := 140.0
const FINALE_MULT := 1.5
const SHATTER_EXPOSED := 1.5
const FINISHER_EVERY := 6
const NAMES := ["", "Frost Glaive", "Rime", "Ice Comb", "Ice Rink", "Whiteout", "Absolute Zero"]

static func palette() -> Array:
	return [ICE, DEEP, FROST]

static func equip(w) -> void:
	w._st = {"cleaves": 0, "mist_t": 0.0, "ult_id": 0}

## Chilled enemies near you show frost motes (every 0.6 s, at most 4).
static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	w._st.mist_t = float(w._st.get("mist_t", 0.0)) - delta
	if float(w._st.mist_t) > 0.0:
		return
	w._st.mist_t = 0.6
	var n := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), w.player.global_position, 120.0):
		if n >= 4:
			break
		if e.get("slow_mult") != null and e.slow_mult < 1.0:
			n += 1
			w.fx("motes", e.global_position + Vector2(0, -6), FROST, {"radius": 5.0, "count": 2, "rise": 6.0, "life": 0.5})

static func attack(w) -> void:
	w._st.cleaves = int(w._st.get("cleaves", 0)) + 1
	var n: int = int(w._st.cleaves)
	var o: Vector2 = w.player.global_position
	if w.tier >= 3 and n % COMB_EVERY == 0:
		w.fx("shards", o + w.aim * 24.0, SHARD, {"radius": 26.0, "count": 6, "life": 0.3})
		for k in 3:
			var d: Vector2 = w.aim.rotated((float(k) - 1.0) * 0.3)
			WeaponProjectile.shoot(w.game_world(), o + d * 12.0, d, 280.0, WeaponTiers.H(w) * COMB_MULT, SHARD, 0.35, 1, 40.0, {"style": "shard", "slow_mult": 0.5, "slow_secs": 1.5})
	if w.tier >= 6 and n % FINISHER_EVERY == 0:
		w.fx("slash", o, FROST, {"radius": 44.0, "dir": w.aim, "half_angle": 1.1, "thick": 8.0, "life": 0.3, "col2": ICE})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, 44.0, 63.0):
			WeaponUtil.hit(e, WeaponTiers.H(w) * 0.6, o, 60.0, 0.0, "", true)
			WeaponUtil.stun(e, 0.8)

## Tier 2 Rime: frost patches along the line and shards from the eruptions. Tier 4 Frozen Fan: a second set of spikes either side.
static func ability(w) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	for i in 6:
		var p: Vector2 = o + dir * (22.0 + float(i) * 18.0)
		_rime_spike(w, p, 0.35 + float(i) * 0.09, i % 2 == 1)
	if w.tier >= 4:
		_fan(w, o, dir)

static func _rime_spike(w, p: Vector2, delay: float, patch: bool) -> void:
	if !await WeaponTiers.pause(w, delay):
		return
	w.fx("shards", p, SHARD, {"radius": 18.0, "count": 4, "life": 0.3})
	if patch:
		WeaponUtil.patch(w.game_world(), p, "slow", 14.0, Color(0.8, 0.95, 1.0, 0.5), 3.0, 0.6)

static func _fan(w, o: Vector2, dir: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.5):
		return
	for side in [-FAN_ANGLE, FAN_ANGLE]:
		for dist in FAN_SPIKES:
			var p: Vector2 = o + dir.rotated(side) * dist
			w.fx("crack", p, ICE, {"radius": 14.0, "count": 2, "life": 0.4})
			w.fx("shards", p, SHARD, {"radius": 14.0, "count": 4, "life": 0.3})
			for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 14.0):
				WeaponUtil.hit(e, WeaponTiers.H(w) * 0.37, o, 40.0, 0.0, "", true)
				WeaponUtil.stun(e, 0.4)

## Tier 4 Ice Rink: the dash leaves a frozen trail.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, FROST, {"dir": dir, "length": 90.0, "width": 7.0, "life": 0.35, "col2": ICE})
	for i in RINK_PATCHES:
		WeaponUtil.patch(w.game_world(), o + dir * (22.0 + float(i) * 23.0), "slow", 14.0, Color(0.8, 0.95, 1.0, 0.5), 3.0, 0.4)
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, 90.0, 14.0):
		if e.has_method("apply_slow"):
			e.apply_slow(0.5, 2.5)
		WeaponUtil.expose(e, 2.0)

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var my: int = w._st.ult_id
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, ICE, {"radius": 100.0, "count": 6, "spin": 1.0, "life": 0.25, "col2": FROST})
	if w.tier >= 5:
		_whiteout(w, my, o)

## Stage 2 Whiteout: a blizzard for four seconds after the freeze. FINALE Absolute Zero shatters what is left.
static func _whiteout(w, my: int, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.3) or int(w._st.ult_id) != my:
		return
	var t := 0.0
	var next_vortex := 0.0
	while t < WHITEOUT_SECS:
		if t >= next_vortex:
			next_vortex += 1.0
			w.fx("vortex", o, ICE, {"radius": WHITEOUT_R, "count": 3, "spin": -3.0, "life": 1.0})
			w.fx("motes", o, FROST, {"radius": WHITEOUT_R * 0.8, "count": 14, "rise": -10.0, "life": 0.8})
		var tick_damage: bool = fposmod(t + 0.01, 1.0) < 0.1
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, WHITEOUT_R):
			if e.has_method("apply_slow"):
				e.apply_slow(0.5, 0.6)
			WeaponUtil.expose(e, 1.0)
			if tick_damage:
				WeaponUtil.hit(e, WeaponTiers.H(w) * 0.2, o, 0.0, 0.0, "", true, true)
		if !await WeaponTiers.pause(w, 0.25) or int(w._st.ult_id) != my:
			return
		t += 0.25
	if w.tier >= 6:
		_finale(w, o)

static func _finale(w, o: Vector2) -> void:
	w.fx("shards", o, ICE, {"radius": FINALE_R, "count": 24, "life": 0.6})
	w.fx("flash", o, FROST, {"radius": 60.0, "life": 0.4})
	w.fx("ripple", o, ICE, {"radius": FINALE_R, "rings": 3, "life": 0.7})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, FINALE_R):
		var frozen: bool = WeaponUtil.is_exposed(e) or (e.get("slow_mult") != null and e.slow_mult < 1.0)
		if frozen:
			WeaponUtil.hit(e, WeaponTiers.H(w) * FINALE_MULT * (SHATTER_EXPOSED if WeaponUtil.is_exposed(e) else 1.0), o, 0.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.0)
	w.player.shake(5.5, 0.4)
	Sfx.play("big_hit", 0.05)
	Sfx.play("ultimate", 0.02)

## Frost mist falls from the blade, and a little snowflake star shows at the tip.
static func aura(a, c) -> void:
	var head: Vector2 = a.aim.rotated(a.swing) * (a.reach + 6.0)
	var u: float = fposmod(a._age / 0.6, 1.0)
	c.draw_circle(head + Vector2(0, u * 7.0), 0.9, Color(FROST, 0.8 * (1.0 - u)))
	var since: float = fposmod(a._age + 0.4, 1.6)
	if since < 0.3:
		var s: float = 1.0 - since / 0.3
		for k in 3:
			var d := Vector2.from_angle(float(k) * PI / 3.0) * (3.0 * s + 1.0)
			c.draw_line(head - d, head + d, Color(FROST, s), 1.0)
