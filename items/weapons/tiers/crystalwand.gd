extends RefCounted
## Crystal Wand tiers (docs/weapon_tiers/crystalwand.md), Ancient: 2 Prism Shards, 3 Resonance, 4 Crystal Familiar, 5 Geode Garden, 6 Crystal Ascension.
## THE SYSTEM: Crystal Lattice. Every hit of the wand (shards, ring and rain strikes, the dash strikes) embeds a CRYSTAL in the enemy
## (`wt_crystal` = {n, until}, 4 at most, 6 s; drawn as small diamonds round it). From tier 3 the fourth crystal SHATTERS the enemy:
## a burst of 1.2 H and every neighbour within 40 px gains two crystals, so a pack goes off one after another.
## The Prismatic Staff reuses add_crystal / shatter / mark_fx from here with its own constants.
## Hook functions never suspend (they are called through callv): waits live in the helper coroutines.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const AMETHYST := Color(0.80, 0.60, 1.0)
const LIGHT := Color(0.90, 0.75, 1.0)
const WHITE := Color(0.97, 0.93, 1.0)
const DEEP := Color(0.35, 0.20, 0.60)
const CW_SHARDS := 5
const CW_SHARDS_RHYTHM := 7
const CW_CRYSTAL_MAX := 4
const CW_CRYSTAL_SECS := 6.0
const CW_SHATTER_MULT := 1.2
const CW_SHATTER_R := 30.0
const CW_SHATTER_CHAIN := 2
const CW_FAM_MAX := [0, 0, 0, 1, 2, 3]
const CW_FAM_MULT := 0.5
const CW_GEODES := 8
const CW_GEODE_TICK := 0.8
const CW_GEODE_MULT := 0.3
const CW_ASCEND_SECS := 12.0
const CW_BEAM_EVERY := 3.0
const CW_BEAM_MULT := 1.0
const CW_FINISHER_EVERY := 6
const CW_PROJ_CAP := 40
const NAMES := ["", "Crystal Wand", "Prism Shards", "Resonance", "Crystal Familiar", "Geode Garden", "Crystal Ascension"]

static func palette() -> Array:
	return [AMETHYST, LIGHT, WHITE]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func H(w) -> float:
	return WeaponTiers.H(w)

static func hue(i: int) -> Color:
	return Color.from_hsv(fposmod(float(i) * 0.137, 1.0), 0.45, 1.0)

static func equip(w) -> void:
	w._st = {"fans": 0, "fan_times": [], "ult_id": 0, "asc_until": 0.0, "fam_next": 0.0, "wave_next": 0.0, "beam_next": 0.0, "mark_next": 0.0, "geodes": [],
		"geo_until": 0.0, "geo_next": 0.0, "pillar_next": 0.0, "mirror": Vector2.ZERO, "mirror_until": 0.0, "pub": "", "last_ms": -1000, "fam_n": 0}

static func famn(w) -> int:
	return int(CW_FAM_MAX[clampi(w.tier - 1, 0, 5)])

static func ascended(w) -> bool:
	return float(w._st.get("asc_until", 0.0)) > _now()

# ---------- Crystal Lattice (shared with the Prismatic Staff) ----------

static func crystals(e) -> int:
	if !is_instance_valid(e) or !e.has_meta("wt_crystal"):
		return 0
	var m: Dictionary = e.get_meta("wt_crystal")
	if float(m.until) < _now():
		return 0
	return int(m.n)

static func set_crystals(e, n: int) -> void:
	if is_instance_valid(e):
		e.set_meta("wt_crystal", {"n": clampi(n, 0, CW_CRYSTAL_MAX), "until": _now() + CW_CRYSTAL_SECS, "t": Time.get_ticks_msec()})

## Embeds `n` crystals. From tier 3 reaching four shatters the enemy. `direct`: a hit of the wand (a volley that lands in one frame embeds once).
static func add_crystal(w, e, n: int, direct := false) -> void:
	if !is_instance_valid(e) or e.is_queued_for_deletion():
		return
	if direct and e.has_meta("wt_crystal"):
		var m: Dictionary = e.get_meta("wt_crystal")
		if Time.get_ticks_msec() - int(m.get("t", 0)) < 90 and float(m.until) > _now():
			return
	var total: int = crystals(e) + n
	if total >= CW_CRYSTAL_MAX and w.tier >= 3 and !_cooling(e):
		set_crystals(e, 0)
		shatter(w, e)
		return
	set_crystals(e, total)

static func _cooling(e) -> bool:
	return e.has_meta("wt_crystal_cd") and float(e.get_meta("wt_crystal_cd")) > _now()

## The shatter: a burst, 1.2 H round the enemy (quiet), two crystals for every neighbour within 40 px (they may shatter in turn, a beat later).
static func shatter(w, e, mult := CW_SHATTER_MULT, r := CW_SHATTER_R) -> void:
	if !is_instance_valid(e):
		return
	e.set_meta("wt_crystal_cd", _now() + 1.2)
	var at: Vector2 = e.global_position
	w.fx("burst", at, LIGHT, {"radius": r, "life": 0.3})
	w.fx("shards", at, hue(int(at.x)), {"radius": r * 0.8, "count": 5, "life": 0.3})
	var near: Array = WeaponUtil.enemies_in_circle(w.get_tree(), at, r)
	for o in near:
		WeaponUtil.hit(o, H(w) * mult, at, 80.0, 0.0, "", true, true)
	Sfx.play("hit", 0.1, 1.4)
	_chain(w, e, at)

static func _chain(w, from, at: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.15):
		return
	for o in WeaponUtil.enemies_in_circle(w.get_tree(), at, 40.0):
		if o != from and is_instance_valid(o):
			w.fx("bolt", at, AMETHYST, {"dir": (o.global_position - at).normalized(), "length": at.distance_to(o.global_position), "width": 1.0, "life": 0.15})
			add_crystal(w, o, CW_SHATTER_CHAIN)

## A hit of the wand embeds a crystal (tier 2+).
static func on_hit(w, e: Node, _dmg: float) -> void:
	if w.tier >= 2:
		add_crystal(w, e, 1, true)

## Drawn every 0.5 s: n small diamonds round each marked enemy (8 enemies at most).
static func mark_fx(w) -> void:
	var seen := 0
	for e in w.get_tree().get_nodes_in_group("enemy"):
		if seen >= 8:
			break
		var n := crystals(e)
		if n > 0 and is_instance_valid(e):
			seen += 1
			w.fx("orbit", e.global_position, hue(e.get_instance_id() % 7), {"radius": 7.0, "count": n, "spin": 2.0, "shape": "shard", "life": 0.55})

# ---------- attack ----------

## Called by t1x/crystalwand.gd `attack` (tier 2+): the plan of this fan, or null for the plain three shards.
static func shard_plan(w):
	if w.tier < 2:
		return null
	var st: Dictionary = w._st
	var now := _now()
	var times: Array = st.fan_times
	times.append(now)
	while times.size() > 0 and now - float(times[0]) > 1.2:
		times.pop_front()
	st.fans = int(st.fans) + 1
	var n := CW_SHARDS
	var step := 0.1
	if w.tier >= 3 and times.size() >= 3:                 # a perfect rhythm: the third fan within 1.2 s is a wide cone
		n = CW_SHARDS_RHYTHM
		step = 0.15
		times.clear()
		w.fx("cone", w.player.global_position, AMETHYST, {"radius": 60.0, "dir": w.aim, "half_angle": 0.45, "life": 0.25, "col2": WHITE})
	var extra := {"style": "shard", "trail": 3, "owner_id": w.player.get_instance_id(), "on_hit_fx": "burst", "glow": 0.2}
	if ascended(w) and WeaponProjectile.alive(w.get_tree()) < 28:
		extra["split"] = 3
	return {"n": n, "step": step, "extra": extra, "hue": int(st.fans)}

static func attack(w) -> void:
	var st: Dictionary = w._st
	var ms := Time.get_ticks_msec()
	if ms - int(st.last_ms) < 200:
		return
	st.last_ms = ms
	if w.tier < 2:
		return
	var o: Vector2 = w.player.global_position
	w.fx("burst", o + w.aim * 12.0, hue(int(st.fans)), {"radius": 8.0, "life": 0.2})
	var fam := famn(w)
	for i in fam:                                         # each familiar fires a mirror shard
		var p: Vector2 = _fam_pos(w, i, fam)
		var d: Vector2 = w.aim
		_shard(w, p, d, H(w) * CW_FAM_MULT, 280.0, 1.0)
	if w.tier >= 6 and int(st.fans) % CW_FINISHER_EVERY == 0:
		_prism_beam(w, o, w.aim)

static func _shard(w, pos: Vector2, dir: Vector2, dmg: float, speed: float, homing: float, split := 0) -> void:
	if WeaponProjectile.alive(w.get_tree()) >= CW_PROJ_CAP:
		return
	var extra := {"style": "shard", "homing": homing, "owner_id": w.player.get_instance_id(), "glow": 0.2, "trail": 2}
	if split > 0:
		extra["split"] = split
	WeaponProjectile.shoot(w.game_world(), pos, dir, speed, dmg, hue(int(pos.x)), 0.7, 0, 60.0, extra)

static func _fam_pos(w, i: int, n: int) -> Vector2:
	var age: float = float(w._aura._age) if w._aura != null and is_instance_valid(w._aura) else 0.0
	return w.player.global_position + Vector2.from_angle(age * 2.0 + float(i) * TAU / float(maxi(n, 1))) * 18.0

## The prism beam of the finisher: 120 px through everything, 0.8 H each, two crystals each.
static func _prism_beam(w, o: Vector2, d: Vector2) -> void:
	w.fx("beam", o + d * 10.0, hue(int(o.x)), {"dir": d, "length": 120.0, "width": 6.0, "life": 0.4, "col2": WHITE})
	for e in WeaponUtil.enemies_in_line(w.get_tree(), o, d, 120.0, 7.0):
		WeaponUtil.hit(e, H(w) * 0.8, o, 60.0, 0.0, "", true, true)
		add_crystal(w, e, 2)
	Sfx.play("big_hit", 0.1, 1.3)

# ---------- ability: Crystal Ring ----------

static func ability(w) -> void:
	var o: Vector2 = w.player.global_position
	w.fx("shards", o, AMETHYST, {"radius": 40.0, "count": 5, "life": 0.4})
	w.fx("ripple", o, LIGHT, {"radius": 74.0, "rings": 2, "life": 0.7})
	for k in 2:                                           # the outer ring grows to twelve strikes
		var a := 0.3 + float(k) * 3.0
		w.ground_strike(o + Vector2.from_angle(a) * 74.0 + Vector2.from_angle(a + 1.0) * 3.0, 20.0, 0.65 + 0.03 * 10.0 + float(k) * 0.03, H(w) * 0.6, 200.0, AMETHYST, 0.3)
	if w.tier >= 3:
		_pull(w, o)
	if w.tier >= 4:
		_fam_ring(w)

static func _pull(w, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.25):
		return
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 90.0):
		Kit.pull(e, o, 120.0, 0.3)
	w.fx("vortex", o, AMETHYST, {"radius": 80.0, "count": 3, "spin": 1.5, "inward": true, "life": 0.35})

static func _fam_ring(w) -> void:
	var n := famn(w)
	for i in n:
		var c: Vector2 = _fam_pos(w, i, n)
		for k in 3:
			w.ground_strike(c + Vector2.from_angle(float(k) * TAU / 3.0 + float(i)) * 24.0, 16.0, 0.4 + 0.05 * float(k), H(w) * 0.4, 100.0, hue(i + k), 0.0)

# ---------- dash: Refract ----------

static func pre_dash(w) -> void:
	w._st.dash_from = w.player.global_position

static func dash(w) -> void:
	if w.tier < 4:
		return
	var from: Vector2 = w._st.get("dash_from", w.player.global_position)
	w.fx("streak", from, AMETHYST, {"dir": w.aim, "length": 55.0, "width": 5.0, "life": 0.25, "col2": WHITE})
	w._st.mirror = from
	w._st.mirror_until = _now() + 2.5

# ---------- tick ----------

static func tick(w, _delta: float) -> void:
	var st: Dictionary = w._st
	var now := _now()
	if w.tier < 2:
		return
	_publish(w)
	if now >= float(st.mark_next):
		st.mark_next = now + 0.5
		mark_fx(w)
	var pid: int = w.player.get_instance_id()
	var tree: SceneTree = w.get_tree()
	var mirror_on: bool = float(st.mirror_until) > now
	if mirror_on:                                           # the mirror echoes a shot that passes it (one copy, 50%)
		for n in tree.get_nodes_in_group("net"):
			if n is WeaponProjectile and n.owner_id == pid and !n.gated and n.global_position.distance_to(st.mirror) <= 24.0:
				n.gated = true
				_shard(w, st.mirror, n.vel.normalized(), n.damage * 0.5, n.vel.length(), 0.0)
				w.fx("flash", st.mirror, LIGHT, {"radius": 8.0, "life": 0.2})
	# Geode Garden: geodes pulse, pillars rise
	if now < float(st.geo_until):
		if now >= float(st.geo_next):
			st.geo_next = now + CW_GEODE_TICK
			for g in st.geodes:
				w.fx("ripple", g, hue(int(g.x)), {"radius": 34.0, "rings": 1, "life": 0.5})
				for e in WeaponUtil.enemies_in_circle(tree, g, 34.0):
					WeaponUtil.hit(e, H(w) * CW_GEODE_MULT, g, 0.0, 0.0, "", true, true)
					add_crystal(w, e, 1)
		if now >= float(st.pillar_next):
			st.pillar_next = now + 0.6
			for g in st.geodes:
				w.fx("pillar", g, AMETHYST, {"height": 40.0, "width": 12.0, "life": 0.6})
	# Crystal Ascension
	if ascended(w):
		var n := famn(w)
		if now >= float(st.fam_next):
			st.fam_next = now + 0.45
			var tgt = WeaponUtil.nearest(tree, w.player.global_position, 160.0)
			if tgt != null:
				for i in n:
					var p: Vector2 = _fam_pos(w, i, n)
					_shard(w, p, (tgt.global_position - p).normalized(), H(w) * 0.3, 280.0, 2.0)
		if now >= float(st.wave_next):
			st.wave_next = now + 2.0
			var o: Vector2 = w.player.global_position
			w.fx("ripple", o, AMETHYST, {"radius": 140.0, "rings": 3, "life": 0.7})
			w.fx("star", o, WHITE, {"radius": 24.0, "count": 8, "spin": 1.5, "life": 0.5})
			for e in WeaponUtil.enemies_in_circle(tree, o, 140.0):
				add_crystal(w, e, 2)
		if now >= float(st.beam_next):
			st.beam_next = now + CW_BEAM_EVERY
			_sweep(w)

static func _publish(w) -> void:
	var a = w._aura
	if a == null or !is_instance_valid(a):
		return
	var st: Dictionary = w._st
	var d := {"fam": famn(w), "asc": ascended(w)}
	if float(st.mirror_until) > _now():
		d["mirror"] = st.mirror
	var key := str(d)
	if st.pub != key:
		st.pub = key
		a.data = d

## Prism sweep: six beams at 15 degree steps across a 90 degree arc over 0.6 s.
static func _sweep(w) -> void:
	var o: Vector2 = w.player.global_position
	var base: float = w.aim.angle() - deg_to_rad(45.0)
	for k in 6:
		var d := Vector2.from_angle(base + deg_to_rad(15.0) * float(k))
		w.fx("beam", o, hue(k * 2), {"dir": d, "length": 130.0, "width": 5.0, "life": 0.3, "col2": WHITE})
		for e in WeaponUtil.enemies_in_line(w.get_tree(), o, d, 130.0, 6.0):
			if !e.has_meta("wt_sweep") or float(e.get_meta("wt_sweep")) < _now() - 0.7:
				e.set_meta("wt_sweep", _now())
				WeaponUtil.hit(e, H(w) * CW_BEAM_MULT, o, 40.0, 0.0, "", true, true)
		if !await WeaponTiers.pause(w, 0.1):
			return

# ---------- ultimate: Geode Storm -> Geode Garden -> Crystal Ascension ----------

static func ultimate(w) -> void:
	var st: Dictionary = w._st
	st.ult_id = int(st.ult_id) + 1
	var c: Vector2 = w.cursor_target(110.0)
	w.fx("sigil", c, AMETHYST, {"radius": 105.0, "count": 12, "spin": 1.5, "life": 0.3, "col2": WHITE})
	if w.tier >= 5:
		_garden(w, c, int(st.ult_id))

static func _garden(w, c: Vector2, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 2.7):
		return
	if int(st.ult_id) != my:
		return
	var geodes := []
	for i in CW_GEODES:
		var g: Vector2 = c + Vector2.from_angle(float(i) * 2.399 + 0.3) * (28.0 + 9.0 * float(i % 4) * 2.0)
		geodes.append(g)
		w.fx("crack", g, DEEP, {"radius": 16.0, "count": 4, "life": 1.0})
		WeaponUtil.patch(w.game_world(), g, "slow", 16.0, Color(0.5, 0.3, 0.8, 0.45), 6.0, 0.7)
	st.geodes = geodes
	st.geo_until = _now() + 6.0
	st.geo_next = _now() + 0.2
	st.pillar_next = _now()
	w.player.shake(4.0, 0.3)
	Sfx.play("unlock", 0.05)
	if w.tier >= 6:
		_ascend(w, my)

static func _ascend(w, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 0.5):
		return
	if int(st.ult_id) != my:
		return
	var now := _now()
	st.asc_until = now + CW_ASCEND_SECS
	st.fam_next = now
	st.wave_next = now + 1.0
	st.beam_next = now + 1.5
	w.fx("shock", w.player.global_position, AMETHYST, {"radius": 70.0, "thick": 6.0, "life": 0.5, "col2": WHITE})
	w.player.shake(5.0, 0.3)
	Sfx.play("ultimate", 0.02, 1.2)
	if !await WeaponTiers.pause(w, CW_ASCEND_SECS):
		return
	if int(st.ult_id) != my:
		return
	st.asc_until = 0.0
	_shatterstorm(w)

## FINALE: every crystal on every enemy within 160 px shatters at once, and the shatters chain.
static func _shatterstorm(w) -> void:
	var o: Vector2 = w.player.global_position
	w.fx("flash", o, WHITE, {"radius": 80.0, "life": 0.45})
	w.fx("shards", o, hue(1), {"radius": 160.0, "count": 36, "life": 0.6})
	w.fx("pillar", o, AMETHYST, {"height": 160.0, "width": 30.0, "life": 0.7})
	var n := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 160.0):
		if crystals(e) > 0:
			n += 1
			set_crystals(e, 0)
			e.remove_meta("wt_crystal_cd")
			shatter(w, e)
	w.player.shake(8.0, 0.5)
	Sfx.play("ultimate", 0.02, 0.8)

# ---------- aura: familiars, mirror, armour ----------

static func aura(a, c) -> void:
	var d: Dictionary = a.data
	var n: int = int(d.get("fam", 0))
	for i in n:
		var ang: float = a._age * 2.0 + float(i) * TAU / float(maxi(n, 1))
		var p := Vector2.from_angle(ang) * 18.0
		var pts := PackedVector2Array([p + Vector2(0, -3.5), p + Vector2(2.4, 0), p + Vector2(0, 3.5), p + Vector2(-2.4, 0)])
		c.draw_colored_polygon(pts, hue(i * 2))
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), WHITE, 0.8)
		c.draw_circle(p, 5.0, Color(AMETHYST, 0.18))
	if d.has("mirror"):
		var m: Vector2 = c.to_local(d.mirror)
		var pt := PackedVector2Array([m + Vector2(0, -7), m + Vector2(4, 0), m + Vector2(0, 7), m + Vector2(-4, 0)])
		c.draw_colored_polygon(pt, Color(LIGHT, 0.45))
		c.draw_polyline(pt + PackedVector2Array([pt[0]]), WHITE, 1.0)
		c.draw_arc(m, 9.0 + 1.5 * sin(a._age * 5.0), 0.0, TAU, 20, Color(AMETHYST, 0.6), 1.0)
	if d.get("asc", false):
		for k in 8:                                         # crystal armour: eight shards on the body
			var an: float = float(k) * TAU / 8.0 + a._age * 0.8
			var q := Vector2.from_angle(an) * 8.0
			var dd := Vector2.from_angle(an)
			c.draw_colored_polygon(PackedVector2Array([q + dd * 4.0, q + dd.orthogonal() * 1.6, q - dd * 2.0, q - dd.orthogonal() * 1.6]), Color(hue(k), 0.9))
		c.draw_arc(Vector2.ZERO, 12.0, a._age, a._age + 5.0, 24, Color(WHITE, 0.5), 1.0)
