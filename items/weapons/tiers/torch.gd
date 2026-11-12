extends RefCounted
## Hand Torch tiers (docs/weapon_tiers/torch.md): 2 Kindle, 3 Fan of Flame, 4 Blaze Trail, 5 Corona, 6 Noon. Common: one colour (orange), one idea (light and burn).

const FLAME := Color(1.0, 0.55, 0.15)
const HOT := Color(1.0, 0.80, 0.30)
const CORE := Color(1.0, 0.97, 0.85)
const EMBER := Color(0.40, 0.12, 0.05)
const FAN_EVERY := 3
const FAN_R := 44.0
const FAN_MULT := 0.8
const KINDLE_TICKS := 4
const KINDLE_MULT := 0.15
const CORONA_N := 8
const CORONA_R := 80.0
const NOON_R := 120.0
const NOON_MULT := 1.1
const LIGHT_BONUS := [0.0, 0.0, 10.0, 20.0, 30.0, 40.0]
const NAMES := ["", "Hand Torch", "Kindle", "Fan of Flame", "Blaze Trail", "Corona", "Noon"]

static func palette() -> Array:
	return [FLAME, HOT, CORE]

static func equip(w) -> void:
	w._st = {"burns": 0, "base_light": w.light_radius, "ult_id": 0}
	w.light_radius += LIGHT_BONUS[clampi(w.tier - 1, 0, 5)]
	for c in w.get_children():
		if c is GlowLight:
			c.texture_scale = maxf(0.1, w.light_radius * 2.0 / 128.0)
			w._st["glow"] = c
			w._st["glow_scale"] = c.texture_scale

## The torch light pulses by a few percent (the radius the game reads is unchanged).
static func tick(w, _delta: float) -> void:
	if w.tier >= 2 and w._st.has("glow") and is_instance_valid(w._st.glow):
		var k := 0.06 if w.tier < 6 else 0.03
		w._st.glow.texture_scale = float(w._st.glow_scale) * (1.0 + k * sin(Time.get_ticks_msec() / 1000.0 * 5.0))

static func burn(w, e, ticks := KINDLE_TICKS) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		WeaponUtil.bleed(w.get_tree(), e, ticks, WeaponTiers.H(w) * KINDLE_MULT)

static func on_hit(w, e, _dmg: float) -> void:
	if w.tier < 2 or !is_instance_valid(e) or w.verb() != "attack":
		return
	w.fx("motes", e.global_position, FLAME, {"radius": 8.0, "count": 3, "rise": 12.0, "life": 0.4})

static func attack(w) -> void:
	w._st.burns = int(w._st.get("burns", 0)) + 1
	if w.tier >= 3 and int(w._st.burns) % FAN_EVERY == 0:
		var o: Vector2 = w.player.global_position
		w.fx("cone", o, FLAME, {"radius": FAN_R, "dir": w.aim, "half_angle": 0.9, "life": 0.3, "col2": HOT})
		w.fx("shards", o + w.aim * FAN_R * 0.6, HOT, {"radius": 20.0, "count": 4, "life": 0.3})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, FAN_R, rad_to_deg(0.9)):
			WeaponUtil.hit(e, WeaponTiers.H(w) * FAN_MULT, o, 60.0)
			Game.light_up(e, 3.0)

## Tier 2 Kindle: the flare ignites everything it lands on.
static func ability(w) -> void:
	if w.tier < 2:
		return
	_kindle(w, w.cursor_target(110.0))

static func _kindle(w, target: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.4):
		return
	w.fx("flash", target, HOT, {"radius": 55.0, "life": 0.3})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), target, 55.0):
		w.fx("burst", e.global_position, HOT, {"radius": 9.0, "life": 0.25})
		burn(w, e)

## Tier 4 Blaze Trail.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, FLAME, {"dir": dir, "length": 55.0, "width": 6.0, "life": 0.3, "col2": CORE})
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, 55.0, 14.0):
		burn(w, e)
		Game.light_up(e, 3.0)
	_arrive(w)

static func _arrive(w) -> void:
	if !await WeaponTiers.pause(w, 0.16):
		return
	var p: Vector2 = w.player.global_position
	w.fx("flash", p, FLAME, {"radius": 30.0, "life": 0.3})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 30.0):
		WeaponUtil.hit(e, WeaponTiers.H(w), p, 140.0, 0.0, "", true)

static func ultimate(w) -> void:
	w._st.ult_id = int(w._st.get("ult_id", 0)) + 1
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, HOT, {"radius": 80.0, "count": 6, "spin": 1.2, "life": 0.25, "col2": CORE})
	if w.tier >= 5:
		_corona(w, int(w._st.ult_id))

static func _corona(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 1.0) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("ripple", o, FLAME, {"radius": 120.0, "rings": 2, "life": 0.6})
	for i in CORONA_N:
		var p: Vector2 = o + Vector2.from_angle(float(i) * TAU / float(CORONA_N)) * CORONA_R
		_tongue(w, my, p, i)
	if w.tier >= 6:
		_noon(w, my, o)

static func _tongue(w, my: int, p: Vector2, i: int) -> void:
	if !await WeaponTiers.pause(w, 0.05 * float(i)):
		return
	if i % 2 == 0:
		w.fx("ring", p, FLAME, {"radius": 14.0, "life": 0.35})
	if !await WeaponTiers.pause(w, 0.35) or int(w._st.ult_id) != my:
		return
	w.fx("pillar", p, FLAME, {"height": 26.0, "width": 10.0, "life": 0.3})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 14.0):
		WeaponUtil.hit(e, WeaponTiers.H(w), p, 120.0, 0.0, "", true)
		Game.light_up(e, 6.0)
	Sfx.play("whoosh", 0.1)

## FINALE Noon: a blinding flash and a pillar of light, then everything near is struck.
static func _noon(w, my: int, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.9) or int(w._st.ult_id) != my:
		return
	var p: Vector2 = w.player.global_position
	w.fx("flash", p, CORE, {"radius": 140.0, "life": 0.5})
	w.fx("pillar", p, HOT, {"height": 120.0, "width": 28.0, "life": 0.6})
	w.player.shake(4.5, 0.3)
	Sfx.play("ultimate", 0.02)
	if !await WeaponTiers.pause(w, 0.3):
		return
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, NOON_R):
		WeaponUtil.hit(e, WeaponTiers.H(w) * NOON_MULT, p, 220.0, 0.0, "", true)
		Game.light_up(e, 10.0)

## The hand glow: two embers rise from the head every 0.5 s.
static func aura(a, c) -> void:
	var head: Vector2 = a.aim.rotated(a.swing) * (a.reach + 4.0)
	for k in 2:
		var u: float = fposmod(a._age * 2.0 + float(k) * 0.5, 1.0)
		c.draw_circle(head + Vector2((float(k) - 0.5) * 3.0, -u * 9.0), 0.9 * (1.0 - u) + 0.3, Color(FLAME if k == 0 else HOT, 0.9 * (1.0 - u)))
