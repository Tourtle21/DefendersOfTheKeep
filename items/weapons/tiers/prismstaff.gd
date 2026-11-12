extends RefCounted
## Prismatic Staff tiers (docs/weapon_tiers/prismstaff.md), Legendary band, fusion tier 2: 2 Spectrum, 3 Refraction, 4 Lens Array, 5 Rainbow Barrage, 6 White Light.
## THE SYSTEM: Spectrum. Every shard, beam and strike carries one of six hues (red burns, orange shoves, yellow exposes, green poisons, blue chills,
## violet arcs). Marked enemies bend a shard or beam into a new beam (Refraction); lenses repeat the fan; the ultimate ends in white light.
## The Crystal Lattice (marks, shatter) is the Crystal Wand's: this module calls crystalwand.gd for it.
## Hook functions never suspend (they are called through callv): waits live in the helper coroutines.

const Wand := preload("res://items/weapons/tiers/crystalwand.gd")
const GLASS := Color(0.90, 0.95, 1.0)
const WHITE := Color(1.0, 0.97, 1.0)
const HUES := [0.0, 0.08, 0.16, 0.33, 0.58, 0.75]
const PS_HUES := 6
const PS_LINES := 6
const PS_LINE_MAX_HITS := 2
const PS_FOCUS_MULT := 1.0
const PS_REFRACT_MULT := 0.6
const PS_REFRACT_R := 80.0
const PS_LENS_MULT := 0.35
const PS_LENSES := [0, 0, 0, 2, 2, 4]
const PS_BARRAGE_MULT := 1.0
const PS_WHITE_SECS := 10.0
const PS_SWEEP_EVERY := 1.5
const PS_SWEEP_MULT := 0.5
const PS_LENS_TICK_MULT := 0.1
const PS_HEAL_PER_SEC := 0.01
const PS_FINALE_MULT := 3.0
const PS_FINISHER_EVERY := 6
const PS_PROJ_CAP := 40
const NAMES := ["", "Prismatic Staff", "Spectrum", "Refraction", "Lens Array", "Rainbow Barrage", "White Light"]

static func hue_col(i: int) -> Color:
	return Color.from_hsv(float(HUES[((i % PS_HUES) + PS_HUES) % PS_HUES]), 0.75, 1.0)

static func palette() -> Array:
	return [hue_col(5), hue_col(1), WHITE]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func H(w) -> float:
	return WeaponTiers.H(w)

static func equip(w) -> void:
	w._st = {"hue": 0, "fans": 0, "ult_id": 0, "wl_until": 0.0, "lens_next": 0.0, "sweep_next": 0.0, "mark_next": 0.0, "heal_next": 0.0, "healed": 0,
		"prism": Vector2.ZERO, "prism_until": 0.0, "pub": "", "last_ms": -1000, "dash_from": Vector2.ZERO}

static func lens_n(w) -> int:
	return int(PS_LENSES[clampi(w.tier - 1, 0, 5)])

static func white(w) -> bool:
	return float(w._st.get("wl_until", 0.0)) > _now()

## Where lens i of n floats: beside you (white light: orbiting at 40 px). Host and clients compute the same from aim and the aura's age.
static func lens_pos(origin: Vector2, aim: Vector2, i: int, n: int, age: float, wl: bool) -> Vector2:
	if wl:
		return origin + Vector2.from_angle(age * 2.0 + float(i) * TAU / float(maxi(n, 1))) * 40.0
	var side := 1.0 if i % 2 == 0 else -1.0
	return origin + aim.rotated(side * 1.9) * (20.0 + 6.0 * float(i / 2)) + Vector2(0, 1.5 * sin(age * 2.0 + float(i)))

static func _lenses(w) -> Array:
	var out := []
	var n := lens_n(w)
	var age: float = float(w._aura._age) if w._aura != null and is_instance_valid(w._aura) else 0.0
	for i in n:
		out.append(lens_pos(w.player.global_position, w.aim, i, n, age, white(w)))
	return out

# ---------- the six statuses ----------

static func hue_status(w, e, i: int) -> void:
	if !is_instance_valid(e) or e.is_queued_for_deletion():
		return
	var tree: SceneTree = w.get_tree()
	var at: Vector2 = e.global_position
	w.fx("burst", at, hue_col(i), {"radius": 8.0, "life": 0.2})
	match ((i % PS_HUES) + PS_HUES) % PS_HUES:
		0:
			WeaponUtil.bleed(tree, e, 3, H(w) * 0.15)
		1:
			if e.has_method("push"):
				e.push((at - w.player.global_position).normalized() * (140.0 * (0.4 if e.is_in_group("boss") else 1.0)), 0.15)
		2:
			WeaponUtil.expose(e, 2.0)
		3:
			WeaponUtil.bleed(tree, e, 4, H(w) * 0.1)
		4:
			if e.has_method("apply_slow"):
				e.apply_slow(0.5, 1.5)
		5:
			var o = WeaponUtil.nearest(tree, at, 55.0, [e])
			if o != null:
				w.fx("bolt", at, hue_col(5), {"dir": (o.global_position - at).normalized(), "length": at.distance_to(o.global_position), "width": 1.2, "life": 0.18})
				WeaponUtil.hit(o, H(w) * 0.5, at, 20.0, 0.0, "", true, true)

static func all_statuses(w, e) -> void:
	for i in PS_HUES:
		hue_status(w, e, i)

## Extras of a shard so that its hit carries its hue's status (the projectile applies them itself).
static func _hue_extra(w, i: int) -> Dictionary:
	var h: float = H(w)
	var ex := {}
	match ((i % PS_HUES) + PS_HUES) % PS_HUES:
		0:
			ex = {"bleed_ticks": 3, "bleed_dmg": h * 0.15}
		2:
			ex = {"expose_secs": 2.0}
		3:
			ex = {"bleed_ticks": 4, "bleed_dmg": h * 0.1}
		4:
			ex = {"slow_mult": 0.5, "slow_secs": 1.5}
		5:
			ex = {"chain": 1}
	return ex

static func pre_attack(w) -> void:
	w._st.hue = (int(w._st.hue) + 1) % PS_HUES
	w._st.fans = int(w._st.fans) + 1

## Called by t2/prismstaff.gd for every shard of the fan: its colour and extras.
static func shard_extra(w, i: int):
	var hi: int = int(w._st.hue) + i
	var ex := {"style": "shard", "trail": 3, "glow": 0.25, "owner_id": w.player.get_instance_id(), "on_hit_fx": "burst"}
	ex.merge(_hue_extra(w, hi))
	var knock := 140.0 if hi % PS_HUES == 1 else 60.0
	return {"col": hue_col(hi), "extra": ex, "knock": knock}

# ---------- attack hooks: lenses, white light, the finisher ----------

static func attack(w) -> void:
	var st: Dictionary = w._st
	var ms := Time.get_ticks_msec()
	if ms - int(st.last_ms) < 200:
		return
	st.last_ms = ms
	var o: Vector2 = w.player.global_position
	w.fx("burst", o + w.aim * 12.0, hue_col(int(st.hue)), {"radius": 8.0, "life": 0.2})
	if w.tier >= 4:                                         # lenses repeat the fan from their own places at 35%
		var lp: Array = _lenses(w)
		for p in lp:
			w.fx("flash", p, GLASS, {"radius": 6.0, "life": 0.2})
			for k in 5:
				if WeaponProjectile.alive(w.get_tree()) >= PS_PROJ_CAP:
					break
				var d: Vector2 = w.aim.rotated(float(k - 2) * 0.1)
				var hi: int = int(st.hue) + k
				var ex := {"style": "shard", "trail": 2, "glow": 0.2, "owner_id": w.player.get_instance_id(), "gated": true}
				ex.merge(_hue_extra(w, hi))
				WeaponProjectile.shoot(w.game_world(), p + d * 6.0, d, 310.0, H(w) / 5.0 * PS_LENS_MULT, hue_col(hi), 0.7, 1, 40.0, ex)
	if white(w):                                            # White Light: a fan of six hues at once, 40% each
		for k in 6:
			var d2: Vector2 = w.aim.rotated(float(k - 2.5) * 0.12)
			_beam(w, o, d2, 120.0, 4.0, k, H(w) * 0.4, {}, 9, true)
	if w.tier >= 6 and int(st.fans) % PS_FINISHER_EVERY == 0:
		_lance(w, o, w.aim)

## One beam: the fx, the hits (at most `maxhits` per enemy in `counts`), a hue status per hit, crystals for the lattice.
static func _beam(w, o: Vector2, d: Vector2, length: float, width: float, hue: int, dmg: float, counts: Dictionary, maxhits := 2, quiet := true, status := true, marks := 1) -> void:
	w.fx("beam", o, hue_col(hue), {"dir": d, "length": length, "width": width, "life": 0.35, "col2": WHITE})
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, d, length, width + 2.0):
		var c: int = int(counts.get(e, 0))
		if c >= maxhits:
			continue
		counts[e] = c + 1
		WeaponUtil.hit(e, dmg, o, 60.0, 0.0, "", true, quiet)
		if status:
			hue_status(w, e, hue)
		if marks > 0 and w.tier >= 2:
			Wand.add_crystal(w, e, marks)

## White-light lance of the finisher: 150 long, 1.0 H, all six statuses, four crystals.
static func _lance(w, o: Vector2, d: Vector2) -> void:
	w.fx("beam", o, WHITE, {"dir": d, "length": 150.0, "width": 14.0, "life": 0.45, "col2": WHITE})
	for i in 6:
		w.fx("beam", o, hue_col(i), {"dir": d.rotated((float(i) - 2.5) * 0.03), "length": 150.0, "width": 4.0, "life": 0.4, "col2": WHITE})
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, d, 150.0, 14.0):
		WeaponUtil.hit(e, H(w) * 1.0, o, 80.0, 0.0, "", true, true)
		all_statuses(w, e)
		Wand.add_crystal(w, e, 4)
	w.player.shake(3.0, 0.2)
	Sfx.play("big_hit", 0.1, 1.3)

# ---------- ability: Prism Beam ----------

## Replaces the old three lines (called from t2/prismstaff.gd `ability`): six hued lines, at most two hits on an enemy per cast.
static func beams(w) -> void:
	var o: Vector2 = w.player.global_position
	var aim: Vector2 = w.aim
	var counts := {}
	var offs := [-0.5, -0.3, -0.1, 0.1, 0.3, 0.5]
	var stunned := {}
	w.player.shake(3.0, 0.2)
	for k in PS_LINES:
		var d: Vector2 = aim.rotated(float(offs[k]))
		w.fx("beam", o, hue_col(k), {"dir": d, "length": 150.0, "width": 6.0, "life": 0.4, "col2": WHITE})
		for e in WeaponUtil.enemies_in_line(w.get_tree(), o, d, 150.0, 10.0):
			var c: int = int(counts.get(e, 0))
			if c >= PS_LINE_MAX_HITS:
				continue
			counts[e] = c + 1
			WeaponUtil.hit(e, 4.0 * H(w) / 7.33, o, 120.0)
			if !stunned.has(e):
				stunned[e] = true
				WeaponUtil.stun(e, 0.8)
			hue_status(w, e, k)
		for j in 2:                                          # two strikes per line, a hued flash each
			var sp: Vector2 = o + d * (50.0 + 60.0 * float(j))
			w.ground_strike(sp, 16.0, 0.3 + 0.08 * float(j), 2.5 * H(w) / 7.33, 100.0, hue_col(k), 0.3)
			w.fx("flash", sp, hue_col(k), {"radius": 10.0, "life": 0.35})
	if w.tier >= 3:                                         # Lens Beam: the lines cross 70 px ahead
		_focus(w, o + aim * 70.0)
	if w.tier >= 4:
		_lens_beams(w, aim)

static func _focus(w, at: Vector2) -> void:
	w.fx("flash", at, WHITE, {"radius": 16.0, "life": 0.4})
	w.fx("star", at, WHITE, {"radius": 14.0, "count": 6, "spin": 1.0, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 16.0):
		WeaponUtil.hit(e, H(w) * PS_FOCUS_MULT, at, 80.0, 0.0, "", true)
		all_statuses(w, e)

static func _lens_beams(w, aim: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.2):
		return
	var i := 0
	for p in _lenses(w):
		_beam(w, p, aim, 90.0, 5.0, i * 2 + 1, H(w) * 0.6, {}, 1, false)
		i += 1

# ---------- refraction (on_hit) ----------

static func on_hit(w, e: Node, dmg: float) -> void:
	if !is_instance_valid(e):
		return
	if w.tier >= 3 and Wand.crystals(e) > 0 and !(e.has_meta("wt_refract") and float(e.get_meta("wt_refract")) > _now()):
		e.set_meta("wt_refract", _now() + 0.4)
		var o = WeaponUtil.nearest(w.get_tree(), e.global_position, PS_REFRACT_R, [e])
		if o != null:
			var a: Vector2 = e.global_position
			var b: Vector2 = o.global_position
			w.fx("beam", a, hue_col(int(a.x)), {"dir": (b - a).normalized(), "length": a.distance_to(b), "width": 3.0, "life": 0.3, "col2": WHITE})
			w.fx("flash", b, GLASS, {"radius": 8.0, "life": 0.25})
			WeaponUtil.hit(o, dmg * PS_REFRACT_MULT, a, 20.0, 0.0, "", true, true)
	Wand.add_crystal(w, e, 1, true)

# ---------- dash: Refract Prism ----------

static func pre_dash(w) -> void:
	w._st.dash_from = w.player.global_position

static func dash(w) -> void:
	if w.tier < 4:
		return
	var from: Vector2 = w._st.dash_from
	for i in 6:
		w.fx("streak", from, hue_col(i), {"dir": w.aim.rotated((float(i) - 2.5) * 0.04), "length": 50.0, "width": 3.0, "life": 0.25, "col2": WHITE})
	w._st.prism = from
	w._st.prism_until = _now() + 2.5

# ---------- tick ----------

static func tick(w, _delta: float) -> void:
	var st: Dictionary = w._st
	var now := _now()
	_publish(w)
	if now >= float(st.mark_next):
		st.mark_next = now + 0.5
		Wand.mark_fx(w)
	var tree: SceneTree = w.get_tree()
	if float(st.prism_until) > now:                         # the prism splits a shot that passes it into three
		var pid: int = w.player.get_instance_id()
		for n in tree.get_nodes_in_group("net"):
			if n is WeaponProjectile and n.owner_id == pid and !n.gated and n.global_position.distance_to(st.prism) <= 24.0:
				n.gated = true
				w.fx("star", st.prism, WHITE, {"radius": 8.0, "count": 4, "spin": 1.0, "life": 0.25})
				for s in [-0.35, 0.35]:
					if WeaponProjectile.alive(tree) < PS_PROJ_CAP:
						var d: Vector2 = n.vel.normalized().rotated(s)
						WeaponProjectile.shoot(w.game_world(), st.prism + d * 6.0, d, n.vel.length(), n.damage * 0.4, n.color, 0.7, n.pierce, 40.0, {"style": "shard", "trail": 2, "owner_id": pid, "gated": true})
	if white(w):
		if now >= float(st.lens_next):
			st.lens_next = now + 0.5
			var k := 0
			for p in _lenses(w):
				var tgt = WeaponUtil.nearest(tree, p, 150.0)
				if tgt != null:
					var d2: Vector2 = (tgt.global_position - p).normalized()
					w.fx("beam", p, hue_col(k), {"dir": d2, "length": p.distance_to(tgt.global_position), "width": 2.0, "life": 0.25, "col2": WHITE})
					WeaponUtil.hit(tgt, H(w) * PS_LENS_TICK_MULT, p, 0.0, 0.0, "", true, true)
					hue_status(w, tgt, k)
					Wand.add_crystal(w, tgt, 1)
				k += 1
		if now >= float(st.sweep_next):
			st.sweep_next = now + PS_SWEEP_EVERY
			_sweep(w)
		if now >= float(st.heal_next) and int(st.healed) < int(PS_WHITE_SECS):
			st.heal_next = now + 1.0
			st.healed = int(st.healed) + 1
			w.player.heal(PS_HEAL_PER_SEC * 228.0 * Game.hp_scale())

## The white lance sweeps all the way round in 0.6 s; each enemy is hit once per sweep.
static func _sweep(w) -> void:
	var o: Vector2 = w.player.global_position
	var base: float = w.aim.angle()
	var hit := {}
	for k in 12:
		var d := Vector2.from_angle(base + float(k) * TAU / 12.0)
		w.fx("beam", o, WHITE, {"dir": d, "length": 130.0, "width": 4.0, "life": 0.25, "col2": hue_col(k)})
		o = w.player.global_position
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, d, 130.0, 16.0):
			if !hit.has(e):
				hit[e] = true
				WeaponUtil.hit(e, H(w) * PS_SWEEP_MULT, o, 40.0, 0.0, "", true, true)
				Wand.add_crystal(w, e, 1)
		if !await WeaponTiers.pause(w, 0.05):
			return

static func _publish(w) -> void:
	var a = w._aura
	if a == null or !is_instance_valid(a):
		return
	var d := {"lens": lens_n(w), "wl": white(w)}
	var key := str(d)
	if w._st.pub != key:
		w._st.pub = key
		a.data = d

# ---------- ultimate: Geode Storm and nova -> Rainbow Barrage -> White Light ----------

static func ultimate(w) -> void:
	var st: Dictionary = w._st
	st.ult_id = int(st.ult_id) + 1
	var my: int = st.ult_id
	var c: Vector2 = w.cursor_target(110.0)
	w.fx("sigil", w.player.global_position, hue_col(int(st.hue)), {"radius": 150.0, "count": 6, "spin": 1.5, "life": 0.3, "col2": WHITE})
	for i in 6:
		w.fx("ring", w.player.global_position + Vector2.from_angle(float(i) * TAU / 6.0) * 60.0, hue_col(i), {"radius": 12.0, "life": 0.3})
	if w.tier >= 5:
		_barrage(w, c, my)

static func _barrage(w, c: Vector2, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 3.9):
		return
	if int(st.ult_id) != my:
		return
	w.fx("ripple", c, WHITE, {"radius": 140.0, "rings": 3, "life": 0.8})
	var base := 0.4
	for k in 6:
		var d := Vector2.from_angle(base + float(k) * PI / 3.0)
		var a: Vector2 = c - d * 70.0
		w.fx("beam", a, hue_col(k), {"dir": d, "length": 140.0, "width": 10.0, "life": 0.5, "col2": WHITE})
		for e in WeaponUtil.enemies_in_line(w.get_tree(), a, d, 140.0, 8.0):
			WeaponUtil.hit(e, H(w) * PS_BARRAGE_MULT, a, 40.0, 0.0, "", true, true)
			hue_status(w, e, k)
			Wand.add_crystal(w, e, 1)
		var lp: Array = _lenses(w)
		if k < lp.size():                                    # the lenses fire the barrage again
			var p: Vector2 = lp[k]
			var dd: Vector2 = (c - p).normalized()
			w.fx("beam", p, hue_col(k + 3), {"dir": dd, "length": p.distance_to(c), "width": 4.0, "life": 0.4, "col2": WHITE})
			for e2 in WeaponUtil.enemies_in_line(w.get_tree(), p, dd, p.distance_to(c), 6.0):
				WeaponUtil.hit(e2, H(w) * 0.6, p, 0.0, 0.0, "", true, true)
		w.player.shake(2.0, 0.1)
		if !await WeaponTiers.pause(w, 0.2):
			return
	Sfx.play("ultimate", 0.02, 1.2)
	if w.tier >= 6:
		_white_light(w, my)

static func _white_light(w, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 0.1):
		return
	if int(st.ult_id) != my:
		return
	var now := _now()
	st.wl_until = now + PS_WHITE_SECS
	st.lens_next = now + 0.3
	st.sweep_next = now + 0.8
	st.heal_next = now + 1.0
	st.healed = 0
	w.fx("shock", w.player.global_position, WHITE, {"radius": 70.0, "thick": 6.0, "life": 0.5, "col2": WHITE})
	w.fx("star", w.player.global_position, WHITE, {"radius": 30.0, "count": 6, "spin": 2.0, "life": 0.6})
	w.player.shake(5.0, 0.3)
	Sfx.play("chest", 0.05)
	if !await WeaponTiers.pause(w, PS_WHITE_SECS):
		return
	if int(st.ult_id) != my:
		return
	st.wl_until = 0.0
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, WHITE, {"radius": 120.0, "count": 6, "spin": 2.0, "life": 0.6, "col2": hue_col(1)})
	if !await WeaponTiers.pause(w, 0.6):
		return
	_the_white_light(w)

## FINALE: a column of white light; everything within 140 px takes 3.0 H with all six statuses and every crystal shatters.
static func _the_white_light(w) -> void:
	var o: Vector2 = w.player.global_position
	w.fx("flash", o, WHITE, {"radius": 120.0, "life": 0.5})
	w.fx("pillar", o, WHITE, {"height": 220.0, "width": 60.0, "life": 0.7})
	w.fx("ripple", o, hue_col(4), {"radius": 170.0, "rings": 4, "life": 0.9})
	w.fx("star", o, WHITE, {"radius": 150.0, "count": 12, "spin": 1.0, "life": 0.7})
	w.fx("shards", o, hue_col(2), {"radius": 170.0, "count": 36, "life": 0.7})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 140.0):
		WeaponUtil.hit(e, H(w) * PS_FINALE_MULT, o, 120.0, 0.0, "", true)
		all_statuses(w, e)
	for e2 in w.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e2) and Wand.crystals(e2) > 0 and e2.global_position.distance_to(o) <= 200.0:
			Wand.set_crystals(e2, 0)
			e2.remove_meta("wt_crystal_cd")
			Wand.shatter(w, e2)
	w.player.shake(9.0, 0.6)
	Sfx.play("ultimate", 0.02)
	Sfx.play("chest", 0.05)
	Sfx.play("unlock", 0.05)

# ---------- aura: the facet ring, the lenses, the white pillar ----------

static func aura(a, c) -> void:
	var d: Dictionary = a.data
	var head: Vector2 = a.aim.rotated(a.swing) * a.reach
	for i in 6:                                              # six hue dots round the gem, two turns a second
		var ang: float = a._age * 2.0 * TAU * 0.5 + float(i) * TAU / 6.0
		c.draw_circle(head + Vector2.from_angle(ang) * 4.5, 0.9, Color(hue_col(i), 0.9))
	var n: int = int(d.get("lens", 0))
	var wl: bool = d.get("wl", false)
	for i in n:
		var p: Vector2 = lens_pos(Vector2.ZERO, a.aim, i, n, a._age, wl)
		var pts := PackedVector2Array([p + Vector2(0, -4), p + Vector2(3.6, 2.4), p + Vector2(-3.6, 2.4)])
		c.draw_colored_polygon(pts, Color(hue_col(i), 0.55))
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), WHITE, 0.9)
	if wl:
		for k in 12:
			var an: float = a._age * 1.2 + float(k) * TAU / 12.0
			c.draw_circle(Vector2.from_angle(an) * 26.0, 1.1, Color(hue_col(k), 0.9))
		c.draw_line(head, head + Vector2(0, -30), Color(WHITE, 0.7), 2.0)
		c.draw_circle(head, 5.0, Color(WHITE, 0.3))
	elif a.tier >= 6:                                         # the halo: six coloured arcs
		for k in 6:
			var s: float = a._age * 0.6 + float(k) * TAU / 6.0
			c.draw_arc(head, a.reach + 12.0, s, s + 0.6, 6, Color(hue_col(k), 0.8), 1.5)
