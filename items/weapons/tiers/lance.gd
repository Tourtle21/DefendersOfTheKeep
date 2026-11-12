extends RefCounted
## Siege Lance tiers (docs/weapon_tiers/lance.md): 2 Shock Cone, 3 Long Lance, 4 Spikefall, 5 Reverb, 6 Dive Bomb.
## Uncommon: it merges two Common ideas (Spear tip, Hammer charge) and adds one layer per tier, still one clear blast at a time.
## The old weapon (t2/lance.gd) reads `_st.long` / `_st.full` in attack(), leaves `_st.ratio` and calls the `release` hook when a ram has ended.
## Dragoon Pike (tiers/dragoonpike.gd) calls the public helpers of this file with its own numbers.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const GOLD := Color(1.0, 0.90, 0.50)
const RAM := Color(1.0, 0.80, 0.20)
const SHOCK := Color(1.0, 0.98, 0.85)
const SHAFT := Color(0.70, 0.45, 0.25)
const LANCE_CONE_R := 56.0
const LANCE_CONE_HALF := 0.6
const LANCE_CONE_MULT := 0.8
const LANCE_LONG_EVERY := 3
const LANCE_LONG_LEN := 70.0
const LANCE_SPIKES := 3
const LANCE_SPIKE_MULT := 0.8
const LANCE_REVERB := [0.4, 0.8]
const LANCE_REVERB_R := 70.0
const LANCE_REVERB_MULT := 0.5
const LANCE_RADIAL := 6
const LANCE_STUN := 2.0
const LANCE_FINISHER_EVERY := 6
const NAMES := ["", "Siege Lance", "Shock Cone", "Long Lance", "Spikefall", "Reverb", "Dive Bomb"]

static func palette() -> Array:
	return [GOLD, RAM, SHOCK]

static func equip(w) -> void:
	w._st = {"impales": 0, "long": false, "full": false, "ratio": 0.0, "ult_id": 0, "hop_until": 0.0}

## The aura: the tip heats from gold to white while charging (`state` = charge 0..1), a shadow stays under you during the vault (`state2`).
static func tick(w, _delta: float) -> void:
	if w.tier < 2 or w._aura == null or !is_instance_valid(w._aura):
		return
	w._aura.state = clampf(w._charge / w.MAX_CHARGE, 0.0, 1.0) if w._charging else 0.0
	w._aura.state2 = 1.0 if Time.get_ticks_msec() / 1000.0 < float(w._st.get("hop_until", 0.0)) else 0.0

static func aura(a, c) -> void:
	var d: Vector2 = a.aim.rotated(a.swing)
	if a.state > 0.01:
		var tip: Vector2 = d * (a.reach + 9.0)
		c.draw_circle(tip, 2.5 + 3.0 * a.state, Color(GOLD.lerp(SHOCK, a.state), 0.35 + 0.4 * a.state))
		c.draw_circle(tip, 1.2 + 1.2 * a.state, Color(SHOCK, 0.9))
	if a.state2 > 0.5:
		c.draw_circle(Vector2(0, 7), 6.0, Color(0, 0, 0, 0.0))
		c.draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.35))
		c.draw_circle(Vector2.ZERO, 8.0, Color(0, 0, 0, 0.35))
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---- attack ----
static func pre_attack(w) -> void:
	w._st.long = false
	w._st.full = false
	if w.tier < 3:
		return
	w._st.impales = int(w._st.impales) + 1
	var n: int = w._st.impales
	w._st.long = n % LANCE_LONG_EVERY == 0
	w._st.full = w.tier >= 6 and n % LANCE_FINISHER_EVERY == 0

static func attack(w) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var long: bool = w._st.get("long", false)
	var length := LANCE_LONG_LEN if long else 52.0
	var tip_from := 48.0 if long else 34.0
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, length, 10.0):
		if (e.global_position - o).dot(dir) >= tip_from or w._st.get("full", false):
			w.fx("burst", e.global_position, GOLD, {"radius": 10.0, "life": 0.2})
	if long:
		w.fx("streak", o, GOLD, {"dir": dir, "length": length, "width": 5.0, "life": 0.2, "col2": SHOCK})
		w.fx("star", o + dir * length, RAM, {"radius": 9.0, "count": 4, "spin": 1.0, "life": 0.3})
	if w._st.get("full", false):
		var h := WeaponTiers.H(w)
		w.fx("cone", o, RAM, {"radius": 60.0, "dir": dir, "half_angle": 0.7, "life": 0.25, "col2": SHOCK})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 60.0, rad_to_deg(0.7)):
			WeaponUtil.hit(e, h * 0.8, o, 120.0, 0.0, "", true, true)

# ---- ability: the ram ends in a shock cone ----
static func release(w) -> void:
	if w.tier < 2:
		return
	var ratio: float = float(w._st.get("ratio", 0.0))
	var end: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var ring_r := 26.0 + 20.0 * ratio
	w.fx("shock", end, RAM, {"radius": ring_r, "thick": 5.0, "life": 0.3, "col2": SHOCK})
	w.fx("cone", end, RAM, {"radius": LANCE_CONE_R, "dir": dir, "half_angle": LANCE_CONE_HALF, "life": 0.3, "col2": SHOCK})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), end, dir, LANCE_CONE_R, rad_to_deg(LANCE_CONE_HALF)):
		if e.global_position.distance_to(end) > ring_r + 4.0:             # the ring already hit what is inside it
			WeaponUtil.hit(e, WeaponTiers.H(w) * LANCE_CONE_MULT, end, 300.0, 0.0, "", true)

# ---- dash: Spikefall ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var land: Vector2 = o + dir * 70.0
	w.fx("streak", o, GOLD, {"dir": dir, "length": 70.0, "width": 6.0, "life": 0.25, "col2": SHOCK})
	w._st.hop_until = Time.get_ticks_msec() / 1000.0 + 0.3
	if w.sprite != null:
		var base: Vector2 = w.sprite.scale
		var tw: Tween = w.create_tween()
		tw.tween_property(w.sprite, "scale", base * 1.3, 0.1)
		tw.tween_property(w.sprite, "scale", base, 0.12)
	spikes(w, land, dir.angle(), LANCE_SPIKE_MULT)

## Three lance spikes erupt in a triangle (side 26) round `land`.
static func spikes(w, land: Vector2, rot: float, mult: float) -> void:
	for k in LANCE_SPIKES:
		var c := land + Vector2.from_angle(rot + float(k) * TAU / 3.0) * 15.0
		w.fx("crack", c, GOLD, {"radius": 12.0, "count": 3, "life": 0.5})
		w.ground_strike(c, 12.0, 0.3, WeaponTiers.H(w) * mult, 180.0, GOLD)

# ---- ultimate: Dragoon Dive ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	var target: Vector2 = w.cursor_target(130.0)
	if w.tier >= 3:
		w.fx("sigil", target, GOLD, {"radius": 50.0, "count": 4, "spin": 1.5, "life": 0.4, "col2": SHOCK})
	if w.tier >= 6:
		w.fx("fall", target, RAM, {"radius": 8.0, "height": 120.0, "rise": 0.0, "core": SHOCK, "life": 0.4})
	if w.tier >= 5:
		_after_crash(w, my, target)

static func _after_crash(w, my: int, target: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.42) or int(w._st.ult_id) != my:
		return
	var h := WeaponTiers.H(w)
	if w.tier >= 6:                                                # FINALE Dive Bomb
		w.fx("flash", target, SHOCK, {"radius": 60.0, "life": 0.3})
		w.fx("pillar", target, RAM, {"height": 100.0, "width": 22.0, "life": 0.45})
		w.fx("shock", target, GOLD, {"radius": 70.0, "thick": 7.0, "life": 0.4, "col2": SHOCK})
		w.player.shake(5.0, 0.3)
		Sfx.play("thump", 0.05)
		Sfx.play("big_hit", 0.05)
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), target, 50.0):
			WeaponUtil.stun(e, LANCE_STUN)
		for k in LANCE_RADIAL:
			var d := Vector2.from_angle(float(k) * TAU / float(LANCE_RADIAL))
			WeaponProjectile.shoot(w.game_world(), target + d * 10.0, d, 280.0, h, RAM, 0.35, 2, 120.0, {"style": "lance", "size": 1.0})
	for t in LANCE_REVERB:                                          # Reverb: two rings after the crash
		w.fx("ripple", target, GOLD, {"radius": LANCE_REVERB_R, "rings": 1, "life": 0.4})
		if !await WeaponTiers.pause(w, 0.4) or int(w._st.ult_id) != my:
			return
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), target, LANCE_REVERB_R):
			WeaponUtil.hit(e, h * LANCE_REVERB_MULT, target, 160.0, 0.0, "", true, true)
			if Kit.alive(e):
				e.apply_slow(0.6, 1.0)
