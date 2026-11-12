extends RefCounted
## Dragoon Pike tiers (docs/weapon_tiers/dragoonpike.md): 3 Wyvern's Fang (entry, carries tiers 2 and 3), 4 Dragonfire, 5 Wyrm Chase, 6 Dragon Descent.
## Epic: it chases. A chain of automatic lunges in place of a single charge, and a three-act dragon ultimate: leap, hunt, descent.
## The Pike extends the Lance's old script; its module borrows the Lance's helpers (long thrust, shock cone, spikes) with Pike numbers.
## The old pike calls the `lunge` hook for every automatic lunge; the Lance's old script calls `release` after a ram and reads `_st.long`.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const Lance := preload("res://items/weapons/tiers/lance.gd")
const GOLD := Color(1.0, 0.82, 0.30)
const SCALE := Color(0.85, 0.25, 0.15)
const FLAME := Color(1.0, 0.55, 0.15)
const STEEL := Color(0.95, 0.95, 1.0)
const DP_LUNGES := [3, 3, 4, 4]
const DP_IGNITE_TICKS := 3
const DP_IGNITE_MULT := 0.2
const DP_CHASE_N := 5
const DP_CHASE_MULT := 1.0
const DP_FINALE_MULT := 1.5
const DP_LANCES := 8
const DP_LANCE_MULT := 1.2
const DP_ROAR_EVERY := 6
const DP_WAVE_MULT := 0.6
const NAMES := ["", "", "", "Wyvern's Fang", "Dragonfire", "Wyrm Chase", "Dragon Descent"]

static func palette() -> Array:
	return [GOLD, SCALE, STEEL]

static func equip(w) -> void:
	w._st = {"impales": 0, "long": false, "full": false, "ratio": 0.0, "ult_id": 0, "hop_until": 0.0, "n": 0, "rhythm_until": 0.0}

static func tick(w, delta: float) -> void:
	Lance.tick(w, delta)

static func aura(a, c) -> void:
	Lance.aura(a, c)

# ---- attack: the fang, the long thrust, the rapier rhythm, the roar ----
static func pre_attack(w) -> void:
	w._st.long = false
	w._st.full = false
	w._st.impales = int(w._st.impales) + 1
	w._st.long = int(w._st.impales) % 3 == 0                # Long Lance on every 3rd thrust

static func attack(w) -> void:
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	Lance.attack(w)
	var length := 70.0 if w._st.get("long", false) else 52.0
	var tip_from := 48.0 if w._st.get("long", false) else 34.0
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, length, 10.0):
		if (e.global_position - o).dot(dir) >= tip_from:
			w.fx("shards", e.global_position, GOLD, {"radius": 14.0, "count": 5, "life": 0.3})
	# the Rapier's rhythm: a thin wave follows the second thrust within 0.55 s of the first
	var now := Time.get_ticks_msec() / 1000.0
	if now > float(w._st.get("rhythm_until", 0.0)):
		w._st.n = 0
	w._st.n = int(w._st.n) + 1
	w._st.rhythm_until = now + 0.55
	if int(w._st.n) == 2:
		WeaponProjectile.shoot(w.game_world(), o + dir * 18.0, dir, 300.0, WeaponTiers.H(w) * DP_WAVE_MULT, GOLD, 0.25, 2, 60.0, {"style": "lance", "size": 0.8})
	if int(w._st.n) >= 3:
		w._st.n = 0
	if w.tier >= 6 and int(w._st.impales) % DP_ROAR_EVERY == 0:
		_roar(w, o, dir)

static func _roar(w, o: Vector2, dir: Vector2) -> void:
	w.fx("cone", o, FLAME, {"radius": 70.0, "dir": dir, "half_angle": 0.6, "life": 0.3, "col2": GOLD})
	Sfx.play("boss_roar", 0.05, 1.2)
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, dir, 70.0, rad_to_deg(0.6)):
		WeaponUtil.hit(e, WeaponTiers.H(w) * 0.8, o, 200.0, 0.0, "", true, true)

# ---- ability: the ram ends in a shock cone, then the lunges ----
static func release(w) -> void:
	Lance.release(w)

## Each automatic lunge: a streak and a cut, the target is marked; from tier 4 it burns and leaves a flame trail.
static func lunge(w, e, from: Vector2) -> void:
	if !Kit.alive(e):
		return
	var at: Vector2 = e.global_position
	w.fx("streak", from, GOLD, {"dir": (at - from).normalized(), "length": from.distance_to(at), "width": 5.0, "life": 0.25, "col2": STEEL})
	w.fx("cut", at, STEEL, {"radius": 12.0, "spin": 0.0, "life": 0.25, "col2": GOLD})
	WeaponUtil.expose(e, 2.0)
	if w.tier >= 4:
		WeaponUtil.bleed(w.get_tree(), e, DP_IGNITE_TICKS, WeaponTiers.H(w) * DP_IGNITE_MULT)
		w.fx("motes", (from + at) * 0.5, FLAME, {"radius": 12.0, "count": 6, "rise": 10.0, "life": 0.5})
		w.fx("burst", at, FLAME, {"radius": 10.0, "life": 0.2})

# ---- dash: Sky Vault ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	var land: Vector2 = o + dir * 110.0
	w.fx("streak", o, GOLD, {"dir": dir, "length": 110.0, "width": 8.0, "life": 0.3, "col2": STEEL})
	w._st.hop_until = Time.get_ticks_msec() / 1000.0 + 0.35
	if w.sprite != null:
		var base: Vector2 = w.sprite.scale
		var tw: Tween = w.create_tween()
		tw.tween_property(w.sprite, "scale", base * 1.3, 0.14)
		tw.tween_property(w.sprite, "scale", base, 0.14)
	_land(w, land, dir)

static func _land(w, land: Vector2, dir: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.3):
		return
	var h := WeaponTiers.H(w)
	w.fx("flash", land, FLAME, {"radius": 36.0, "life": 0.3})
	Lance.spikes(w, land, dir.angle(), 0.8)
	w.fx("cone", land, FLAME, {"radius": 60.0, "dir": dir, "half_angle": 0.6, "life": 0.3, "col2": GOLD})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), land, dir, 60.0, rad_to_deg(0.6)):
		WeaponUtil.hit(e, h * 0.8, land, 100.0, 0.0, "", true, true)
		WeaponUtil.bleed(w.get_tree(), e, DP_IGNITE_TICKS, h * DP_IGNITE_MULT)

# ---- ultimate: Dragon Dive, the Wyrm Chase, Dragon Descent ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	var target: Vector2 = w.cursor_target(130.0)
	w.fx("sigil", target, GOLD, {"radius": 50.0, "count": 4, "spin": 1.5, "life": 0.4, "col2": STEEL})
	w._st.hop_until = Time.get_ticks_msec() / 1000.0 + 0.4
	if w.tier >= 6:
		w.fx("fall", target, FLAME, {"radius": 9.0, "height": 150.0, "rise": 0.0, "core": STEEL, "life": 0.4})
	if w.tier >= 5:
		_chase(w, my, target)

## Tier 5: after the crash the dragon chases: five lunges at the nearest enemies, then back to the crash point.
static func _chase(w, my: int, crash: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.05) or int(w._st.ult_id) != my:
		return
	var h := WeaponTiers.H(w)
	var picked := []
	for i in DP_CHASE_N:
		var o: Vector2 = w.player.global_position
		var e = WeaponUtil.nearest(w.get_tree(), o, 150.0, picked)
		if e == null:
			break
		picked.append(e)
		var to: Vector2 = e.global_position - o
		w.player.dash(to.normalized(), maxf(8.0, to.length() - 12.0), 0.1)
		w.fx("streak", o, FLAME, {"dir": to.normalized(), "length": to.length(), "width": 5.0, "life": 0.25, "col2": STEEL})
		w.fx("motes", o + to * 0.5, FLAME, {"radius": 12.0, "count": 6, "rise": 10.0, "life": 0.5})
		WeaponUtil.hit(e, h * DP_CHASE_MULT, o, 160.0)
		if !await WeaponTiers.pause(w, 0.16) or int(w._st.ult_id) != my:
			return
	var back: Vector2 = crash - w.player.global_position
	if back.length() > 4.0:
		w.player.blink(back.limit_length(200.0))
		w.fx("flash", w.player.global_position, FLAME, {"radius": 18.0, "life": 0.25})
	if w.tier >= 6:
		_descent(w, my, w.player.global_position)

## FINALE Dragon Descent: a sigil, then the great crash with eight spiralling lances.
static func _descent(w, my: int, at: Vector2) -> void:
	w.fx("sigil", at, SCALE, {"radius": 80.0, "count": 8, "spin": 2.0, "life": 0.4, "col2": GOLD})
	if !await WeaponTiers.pause(w, 0.4) or int(w._st.ult_id) != my:
		return
	var h := WeaponTiers.H(w)
	w.fx("flash", at, FLAME, {"radius": 70.0, "life": 0.35})
	w.fx("pillar", at, FLAME, {"height": 130.0, "width": 34.0, "life": 0.5})
	w.fx("shock", at, SCALE, {"radius": 80.0, "thick": 7.0, "life": 0.4, "col2": GOLD})
	WeaponUtil.patch(w.game_world(), at, "slow", 50.0, Color(1.0, 0.5, 0.2, 0.4), 4.0, 0.5)
	w.player.shake(7.0, 0.4)
	Sfx.play("ultimate", 0.05)
	Sfx.play("thump", 0.05)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 80.0):
		WeaponUtil.hit(e, h * DP_FINALE_MULT, at, 200.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.5)
	for k in DP_LANCES:
		var d := Vector2.from_angle(float(k) * TAU * 1.25 / float(DP_LANCES))
		WeaponProjectile.shoot(w.game_world(), at + d * 10.0, d, 280.0, h * DP_LANCE_MULT, FLAME, 0.4, 3, 140.0, {"style": "lance"})
		if !await WeaponTiers.pause(w, 0.04) or int(w._st.ult_id) != my:
			return
