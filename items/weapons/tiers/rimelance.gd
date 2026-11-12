extends RefCounted
## Rimelance tiers (docs/weapon_tiers/rimelance.md): 2 Icicle, 3 Frostbite, 4 Winter's Edge, 5 Permafrost, 6 Glacier.
## Epic: the Frost Glaive's chill system with the spear's tip: stacks (frostbite), a boomerang glaive, a frozen field and a glacier.
## Dispatch is by weapon_id: the Frost Glaive's own module does not run for the Rimelance (it inherits the glaive's old script only).

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const ICE := Color(0.70, 0.90, 1.0)
const STEEL := Color(0.90, 0.96, 1.0)
const DEEP := Color(0.30, 0.55, 0.90)
const FROST := Color(0.95, 1.0, 1.0)
const RL_SHARDS := 6
const RL_SHARD_MULT := 0.4
const RL_FROSTBITE_MAX := 3
const RL_FROSTBITE_T := 3.0
const RL_FROST_FREEZE := 1.0
const RL_SPIKES := 2
const RL_RETURN_MULT := 0.6
const RL_RIBBON_N := 4
const RL_PERMA_SECS := 6.0
const RL_PERMA_ICICLES := 8
const RL_FINALE_R := 130.0
const RL_FINALE_MULT := 1.5
const RL_FINISHER_EVERY := 6
const NAMES := ["", "Rimelance", "Icicle", "Frostbite", "Winter's Edge", "Permafrost", "Glacier"]

static func palette() -> Array:
	return [ICE, DEEP, FROST]

static func equip(w) -> void:
	w._st = {"thrusts": 0, "ult_id": 0, "mist": 0.0, "ult_o": Vector2.ZERO}

## A cold mist round the head: a few white motes every 0.6 s.
static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	w._st.mist = float(w._st.get("mist", 0.0)) + delta
	if float(w._st.mist) >= 0.6:
		w._st.mist = 0.0
		w.fx("motes", w.player.global_position + w.aim * (w.reach + 6.0), FROST, {"radius": 7.0, "count": 3, "rise": 10.0, "life": 0.6})

# ---- attack: icicles in the tip hits, frostbite, the glacier beam ----
static func attack(w) -> void:
	w._st.thrusts = int(w._st.thrusts) + 1
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, 52.0, 9.0):
		if (e.global_position - o).dot(dir) >= 32.0:
			w.fx("shards", e.global_position, ICE, {"radius": 12.0, "count": 4, "life": 0.25})
			w.fx("cut", e.global_position, DEEP, {"radius": 6.0, "spin": 0.4, "life": 0.25, "col2": FROST})
	if w.tier >= 6 and int(w._st.thrusts) % RL_FINISHER_EVERY == 0:
		_beam(w, o, dir)

static func _beam(w, o: Vector2, dir: Vector2) -> void:
	var h := WeaponTiers.H(w)
	w.fx("beam", o, ICE, {"dir": dir, "length": 90.0, "width": 6.0, "life": 0.3, "col2": FROST})
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, dir, 90.0, 8.0):
		WeaponUtil.hit(e, h * 0.6, o, 60.0, 0.0, "", true, true)
	for k in 3:
		w.ground_strike(o + dir * (30.0 + 25.0 * float(k)), 12.0, 0.35 + 0.05 * float(k), h * 0.3, 80.0, ICE, 0.2)

## Frostbite (tier 3): a tip thrust adds a stack for 3 s; the third freezes the enemy and shatters it.
static func on_hit(w, e, _dmg: float) -> void:
	if w.tier < 3 or !Kit.alive(e) or w.verb() != "attack":
		return
	var o: Vector2 = w.player.global_position
	if (e.global_position - o).dot(w.aim) < 32.0:
		return
	var n := 1
	if WeaponTiers.marked(e, "frostbite"):
		n = int(e.get_meta("wt_frostbite_n", 0)) + 1
	e.set_meta("wt_frostbite_n", n)
	WeaponTiers.mark(e, "frostbite", RL_FROSTBITE_T)
	if n < RL_FROSTBITE_MAX:
		return
	e.set_meta("wt_frostbite_n", 0)
	e.set_meta("wt_frostbite", 0.0)
	_freeze(w, e, o)

## One frame later: the old thrust chills the enemy right after the hit, and the freeze must come last.
static func _freeze(w, e, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.02) or !Kit.alive(e):
		return
	WeaponUtil.stun(e, RL_FROST_FREEZE)
	w.fx("cut", e.global_position, FROST, {"radius": 14.0, "spin": 0.0, "life": 0.3, "col2": DEEP})
	w.fx("shards", e.global_position, ICE, {"radius": 26.0, "count": 8, "life": 0.35})
	WeaponUtil.hit(e, WeaponTiers.H(w), o, 0.0, 0.0, "", true, true)
	Sfx.play("hit", 0.1)

# ---- ability: the spinning glaive shatters, leaves spikes, comes back ----
static func ability(w) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	_land(w, o, dir)

static func _land(w, o: Vector2, dir: Vector2) -> void:
	var land: Vector2 = o + dir * 130.0
	var h := WeaponTiers.H(w)
	if !await WeaponTiers.pause(w, 0.45):
		return
	w.fx("shards", land, ICE, {"radius": 40.0, "count": RL_SHARDS, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), land, 30.0):
		WeaponUtil.hit(e, h * RL_SHARD_MULT, land, 40.0, 0.0, "", true, true)
	if w.tier >= 3:
		var side: Vector2 = dir.orthogonal()
		for s in [-1.0, 1.0]:
			w.fx("cut", land + side * 35.0 * s, ICE, {"radius": 8.0, "spin": 0.0, "life": 0.5, "col2": FROST})
			w.ground_strike(land + side * 35.0 * s, 14.0, 0.4, h, 100.0, ICE, 0.4)
	if w.tier >= 4:
		if !await WeaponTiers.pause(w, 0.5):
			return
		var back: Vector2 = w.player.global_position - land
		if back.length() > 8.0:
			var d := back.normalized()
			WeaponProjectile.shoot(w.game_world(), land, d, back.length() / 0.3, 4.5 * RL_RETURN_MULT, ICE, 0.3, 3, 80.0, {"style": "blade", "size": 1.4, "trail": 5, "slow_mult": 0.5, "slow_secs": 2.5})

# ---- dash: Winter's Edge ----
static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var dir: Vector2 = w.aim
	w.fx("streak", o, ICE, {"dir": dir, "length": 90.0, "width": 8.0, "life": 0.3, "col2": FROST})
	for k in RL_RIBBON_N:
		WeaponUtil.patch(w.game_world(), o + dir * (22.0 * float(k + 1)), "slow", 18.0, Color(0.7, 0.9, 1.0, 0.5), 4.0, 0.4)

static func dash_hit(w, e) -> void:
	if w.tier >= 4 and Kit.alive(e):
		WeaponUtil.expose(e, 3.0)
		e.apply_slow(0.5, 3.0)

# ---- ultimate: Deep Freeze, Permafrost, Glacier ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1
	w._st.ult_o = w.player.global_position

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	var o: Vector2 = w._st.ult_o
	if w.tier >= 3:
		w.fx("sigil", o, ICE, {"radius": 100.0, "count": 6, "spin": 1.5, "life": 0.3, "col2": FROST})
	if w.tier >= 5:
		_permafrost(w, my, o)

static func _permafrost(w, my: int, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.4) or int(w._st.ult_id) != my:
		return
	var h := WeaponTiers.H(w)
	w.fx("vortex", o, ICE, {"radius": 110.0, "count": 3, "spin": 2.0, "life": 1.0})
	WeaponUtil.patch(w.game_world(), o, "slow", 110.0, Color(0.7, 0.9, 1.0, 0.35), RL_PERMA_SECS, 0.4)
	var left := RL_PERMA_ICICLES
	var t := 0.0
	while t < RL_PERMA_SECS - 0.5:
		if !await WeaponTiers.pause(w, 0.8) or int(w._st.ult_id) != my:
			return
		t += 0.8
		if left <= 0:
			continue
		var frozen := []
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 110.0):
			if e.slow_mult < 1.0 or WeaponUtil.is_exposed(e):
				frozen.append(e)
		if frozen.is_empty():
			continue
		var pick = frozen[randi() % frozen.size()]
		left -= 1
		w.fx("cut", pick.global_position, FROST, {"radius": 8.0, "spin": 0.0, "life": 0.4, "col2": DEEP})
		w.ground_strike(pick.global_position, 16.0, 0.35, h * 0.5, 80.0, ICE, 0.3)
	if w.tier >= 6:
		_glacier(w, my, o)

## FINALE Glacier: when the permafrost ends a glacier shatters.
static func _glacier(w, my: int, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.5) or int(w._st.ult_id) != my:
		return
	var h := WeaponTiers.H(w)
	w.fx("flash", o, FROST, {"radius": 70.0, "life": 0.35})
	w.fx("shards", o, ICE, {"radius": RL_FINALE_R, "count": 24, "life": 0.5})
	w.fx("ripple", o, ICE, {"radius": RL_FINALE_R, "rings": 3, "life": 0.6})
	w.player.shake(6.0, 0.35)
	Sfx.play("big_hit", 0.05)
	Sfx.play("ultimate", 0.05)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, RL_FINALE_R):
		var m := RL_FINALE_MULT * (1.5 if (e.slow_mult < 1.0 or WeaponUtil.is_exposed(e)) else 1.0)
		WeaponUtil.hit(e, h * m, o, 0.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.0)
