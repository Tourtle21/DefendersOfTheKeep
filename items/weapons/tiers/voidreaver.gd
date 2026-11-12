extends RefCounted
## Voidreaver tiers (docs/weapon_tiers/voidreaver.md), LEGENDARY: 2 Hunger, 3 Gravity, 4 Singularity, 5 Black Sun, 6 Oblivion.
## THE SYSTEM: Hunger and Gravity. ESSENCE (0 to 100, aura `state`): every cut +3, kills +8, rift pulls +2; at 100 the blade is in ECLIPSE for 8 s
## (once per 15 s): every hit pulls, the heal doubles. Gravity: pulls, wells and SINGULARITIES (`_st.holes`, drawn from the aura's `data`) that
## drag enemies in and crush the ones at their centre. Enemies that are pulled are marked void for 1.5 s and take 10% more from your hits.
## Nothing here hurts a player. Hook functions never suspend (they run through callv): waits live in helper coroutines.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const VOID := Color(0.60, 0.30, 1.0)
const DEEP := Color(0.35, 0.15, 0.65)
const ABYSS := Color(0.08, 0.03, 0.15)
const WHITE := Color(0.90, 0.85, 1.0)
const RIM := Color(0.85, 0.55, 1.0)
const VR_ESS_HIT := 3
const VR_ESS_KILL := 8
const VR_ESS_DECAY := 5.0
const VR_ECLIPSE_SECS := 8.0
const VR_ECLIPSE_CD := 15.0
const VR_HEAL_CAP := 4.0
const VR_HEAL_CAP_ECLIPSE := 6.0
const VR_GRAVITY_EVERY := 3
const VR_GRAVITY_MULT := 0.8
const VR_WELL_SECS := 3.0
const VR_HOLE_SECS := [0, 0, 0, 6, 6, 10]
const VR_HOLE_PULL_R := 100.0
const VR_HOLE_CRUSH_R := 18.0
const VR_HOLE_CRUSH_MULT := 0.25
const VR_HOLES_MAX := 5
const VR_BLACKSUN_SECS := 2.0
const VR_ERASE := 0.15
const VR_ERASE_ULT := 0.20
const VR_OBLIVION_SECS := 14.0
const VR_FINALE_MULT := 3.0
const VR_ULT_HEAL := 0.10
const VR_FINISHER_EVERY := 6
const VR_PROJ_CAP := 40
const NAMES := ["", "Voidreaver", "Hunger", "Gravity", "Singularity", "Black Sun", "Oblivion"]

static func palette() -> Array:
	return [VOID, RIM, WHITE]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func H(w) -> float:
	return WeaponTiers.H(w)

static func equip(w) -> void:
	w._st = {"ess": 0.0, "last_gain": -10.0, "ecl_until": 0.0, "ecl_cd": 0.0, "locked": false, "swings": 0, "last_ms": -1000, "watch": [], "holes": [], "ult_id": 0,
		"hole_next": 0.0, "bs": 0.0, "bs_until": 0.0, "bs_next": 0.0, "bs_pos": Vector2.ZERO, "well_until": 0.0, "well_c": Vector2.ZERO, "well_next": 0.0,
		"orbit_until": 0.0, "pub": "", "last_attack": -10.0, "spear_next": 0.0, "sigil_next": 0.0, "dash_from": Vector2.ZERO, "drink_next": 0.0, "drink_until": 0.0}

static func ess(w) -> float:
	return float(w._st.ess)

static func eclipse(w) -> bool:
	return float(w._st.ecl_until) > _now() or bool(w._st.locked)

static func add_ess(w, n: float) -> void:
	var st: Dictionary = w._st
	st.last_gain = _now()
	if bool(st.locked):
		st.ess = 100.0
		return
	st.ess = minf(100.0, float(st.ess) + n)
	if float(st.ess) >= 100.0 and _now() >= float(st.ecl_cd) and float(st.ecl_until) <= _now() and w.tier >= 5:
		st.ecl_until = _now() + VR_ECLIPSE_SECS
		st.ecl_cd = _now() + VR_ECLIPSE_CD
		w.fx("shock", w.player.global_position, VOID, {"radius": 40.0, "thick": 5.0, "life": 0.5, "col2": RIM})
		Sfx.play("boss_roar", 0.05, 0.6)

static func _ready_cd(e, key: String, secs: float) -> bool:
	var k := "wt_" + key
	var now := _now()
	if e.has_meta(k) and float(e.get_meta(k)) > now:
		return false
	e.set_meta(k, now + secs)
	return true

static func _void_mark(e, secs := 1.5) -> void:
	if is_instance_valid(e) and !e.is_in_group("boss"):
		e.set_meta("wt_void", _now() + secs)

static func _marked(e) -> bool:
	return is_instance_valid(e) and e.has_meta("wt_void") and float(e.get_meta("wt_void")) > _now()

static func _pull(e, to: Vector2, speed: float, secs: float) -> void:
	Kit.pull(e, to, speed, secs)
	_void_mark(e)

# ---------- hits, kills, healing ----------

## The heal of a swing (t2... called from voidreaver.gd): min(cap, 1.2 per enemy cut), doubled in eclipse. Null at tier 1.
static func heal_plan(w, cut: int, _dealt: float):
	if w.tier < 2:
		return null
	var h := 1.2 * float(cut) * (2.0 if eclipse(w) else 1.0)
	return minf(h, VR_HEAL_CAP_ECLIPSE if eclipse(w) else VR_HEAL_CAP)

static func on_hit(w, e: Node, dmg: float) -> void:
	if w.tier < 2 or !is_instance_valid(e):
		return
	if w.verb() == "attack":
		add_ess(w, VR_ESS_HIT)
		w._st.last_attack = _now()
	if _marked(e):                                            # pulled enemies take 10% more
		WeaponUtil.hit(e, dmg * 0.1, e.global_position, 0.0, 0.0, "", true, true)
	if eclipse(w) and w.verb() == "attack":                  # Black Sun: every hit of an eclipse swing pulls
		_pull(e, w.player.global_position, 120.0, 0.2)
	var wl: Array = w._st.watch
	for x in wl:
		if x.e == e:
			x.t = _now()
			x.by_attack = w.verb() == "attack"
			return
	if wl.size() < 40:
		wl.append({"e": e, "pos": e.global_position, "t": _now(), "by_attack": w.verb() == "attack"})

static func _kills(w) -> void:
	var wl: Array = w._st.watch
	var now := _now()
	for i in range(wl.size() - 1, -1, -1):
		var x = wl[i]
		if is_instance_valid(x.e) and !x.e.is_queued_for_deletion():
			x.pos = x.e.global_position
			if now - float(x.t) > 6.0:
				wl.remove_at(i)
			continue
		wl.remove_at(i)
		if now - float(x.t) < 3.0:
			add_ess(w, VR_ESS_KILL)
			if w.tier >= 4 and bool(x.by_attack) and now - float(x.t) < 0.8:
				_micro(w, x.pos)
			if w.tier >= 6 and _in_hole(w, x.pos):          # Oblivion Rift: what dies in a singularity bursts
				_burst(w, x.pos)

static func _in_hole(w, p: Vector2) -> bool:
	for h in w._st.holes:
		if h.pos.distance_to(p) <= float(h.pull_r):
			return true
	return false

static func _burst(w, p: Vector2) -> void:
	w.fx("burst", p, VOID, {"radius": 30.0, "life": 0.3})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 30.0):
		if _ready_cd(e, "vburst", 5.0):
			WeaponUtil.hit(e, H(w) * 0.5, p, 80.0, 0.0, "", true, true)

# ---------- singularities ----------

## A hole: pull_r drags enemies in, crush_r at its centre hurts them (crush_mult * H every `every` seconds).
static func add_hole(w, pos: Vector2, secs: float, pull_r: float, pull: float, crush_r: float, crush_mult: float, every: float, kind: String) -> void:
	var holes: Array = w._st.holes
	while holes.size() >= VR_HOLES_MAX:
		holes.pop_front()
	holes.append({"pos": pos, "until": _now() + secs, "pull_r": pull_r, "pull": pull, "crush_r": crush_r, "crush_mult": crush_mult, "every": every, "last": 0.0, "kind": kind})
	w.fx("vortex", pos, VOID, {"radius": minf(pull_r, 60.0), "count": 3, "spin": 2.0, "inward": true, "life": 0.6})

static func _micro(w, pos: Vector2) -> void:
	var n := 0
	for h in w._st.holes:
		if h.kind == "micro":
			n += 1
	if n >= 2:
		return
	add_hole(w, pos, 1.0, 60.0, 100.0, 18.0, 0.3, 0.5, "micro")

static func _holes_tick(w) -> void:
	var st: Dictionary = w._st
	var now := _now()
	var tree: SceneTree = w.get_tree()
	var holes: Array = st.holes
	# orbiting singularities of the Oblivion follow the player
	if float(st.orbit_until) > now:
		var age: float = float(w._aura._age) if w._aura != null and is_instance_valid(w._aura) else 0.0
		var k := 0
		for h in holes:
			if h.kind == "orbit":
				h.pos = w.player.global_position + Vector2.from_angle(age * 1.2 + float(k) * TAU / 3.0) * 90.0
				k += 1
	for i in range(holes.size() - 1, -1, -1):
		var h = holes[i]
		if float(h.until) <= now:
			holes.remove_at(i)
			continue
		for e in WeaponUtil.enemies_in_circle(tree, h.pos, float(h.pull_r)):
			_pull(e, h.pos, float(h.pull), 0.5)
		if now - float(h.last) >= float(h.every):
			h.last = now
			for e2 in WeaponUtil.enemies_in_circle(tree, h.pos, float(h.crush_r)):
				WeaponUtil.hit(e2, H(w) * float(h.crush_mult), h.pos, 0.0, 0.0, "", true, true)

# ---------- attack ----------

static func attack(w) -> void:
	var st: Dictionary = w._st
	var ms := Time.get_ticks_msec()
	if ms - int(st.last_ms) < 200:
		return
	st.last_ms = ms
	if w.tier < 2:
		return
	st.swings = int(st.swings) + 1
	st.last_attack = _now()
	var n: int = st.swings
	var o: Vector2 = w.player.global_position
	var d: Vector2 = w.aim
	var ecl: bool = eclipse(w)
	var r: float = 64.0 if ecl else 52.0
	w.fx("slash", o, VOID, {"radius": r, "dir": d, "half_angle": 1.0, "thick": 7.0, "life": 0.25, "col2": RIM})
	var centre: Vector2 = o + d * 30.0
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, d, 52.0, 58.0):     # Hunger: the swing draws them in
		if e.global_position.distance_to(centre) > 6.0 and e.has_method("push"):
			e.push((centre - e.global_position).normalized() * 60.0, 0.15)
	if w.tier >= 6 and n % VR_FINISHER_EVERY == 0:
		_oblivion_cut(w, o)
	elif w.tier >= 3 and n % VR_GRAVITY_EVERY == 0:
		w.fx("vortex", centre, VOID, {"radius": 70.0, "count": 4, "spin": 2.0, "inward": true, "life": 0.4})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), centre, 70.0):
			_pull(e, centre, 220.0, 0.25)
			WeaponUtil.hit(e, H(w) * VR_GRAVITY_MULT, centre, 0.0, 0.0, "", true, true)
		Sfx.play("thump", 0.1, 0.6)

## Oblivion cut: a 360 degree void slash; all within 80 px are pulled to you and take 1.0 H; enemies below 15% are erased.
static func _oblivion_cut(w, o: Vector2) -> void:
	w.fx("slash", o, DEEP, {"radius": 80.0, "dir": Vector2.RIGHT, "half_angle": PI, "thick": 8.0, "life": 0.35, "col2": WHITE})
	w.fx("vortex", o, VOID, {"radius": 80.0, "count": 4, "spin": 3.0, "inward": true, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 80.0):
		_pull(e, o, 260.0, 0.25)
		WeaponUtil.hit(e, H(w) * 1.0, o, 0.0, 0.0, "", true, true)
		if Kit.execute(e, VR_ERASE):
			add_ess(w, VR_ESS_KILL)
			w.fx("burst", e.global_position, WHITE, {"radius": 12.0, "life": 0.3})
	w.player.shake(3.0, 0.2)
	Sfx.play("boss_roar", 0.05, 0.7)

# ---------- ability: Rift ----------

static func ability(w) -> void:
	if w.tier < 2:
		return
	var c: Vector2 = w.cursor_target(110.0)
	w.fx("vortex", c, VOID, {"radius": 120.0, "count": 4, "spin": 2.0, "inward": true, "life": 0.8})
	Sfx.play("boss_roar", 0.05, 0.6)
	_rift(w, c, eclipse(w))

static func _rift(w, c: Vector2, ecl: bool) -> void:
	if !await WeaponTiers.pause(w, 0.4):
		return
	var tree: SceneTree = w.get_tree()
	for e in WeaponUtil.enemies_in_circle(tree, c, 120.0):    # (the old pull happens now): essence for every enemy drawn in
		add_ess(w, 2.0)
		_void_mark(e)
	if ecl and w.tier >= 5:                                   # Black Sun Rift: twice the reach
		w.fx("shock", c, VOID, {"radius": 170.0, "thick": 4.0, "life": 0.5, "col2": RIM})
		for e in WeaponUtil.enemies_in_circle(tree, c, 170.0):
			if e.global_position.distance_to(c) > 120.0:
				_pull(e, c, 260.0, 0.4)
	if w.tier >= 3:                                           # Gravity Well: three more seconds of pull
		w._st.well_until = _now() + VR_WELL_SECS
		w._st.well_c = c
		w._st.well_next = _now() + 0.3
	if !await WeaponTiers.pause(w, 0.6):                       # the old collapse lands about now
		return
	var tail := 0.0
	if ecl and w.tier >= 5:
		w.fx("flash", c, WHITE, {"radius": 80.0, "life": 0.4})
		w.fx("shock", c, VOID, {"radius": 100.0, "thick": 8.0, "life": 0.4, "col2": RIM})
		for e in WeaponUtil.enemies_in_circle(tree, c, 100.0):
			WeaponUtil.hit(e, H(w) * 1.0, c, 0.0, 0.0, "", true, true)
		tail = 0.1
	if tail > 0.0 and !await WeaponTiers.pause(w, tail):
		return
	# Hunger: a second collapse 0.6 s later
	if !await WeaponTiers.pause(w, 0.6):
		return
	w.ground_strike(c, 60.0, 0.05, H(w) * 0.6, 0.0, VOID, 0.0)
	w.fx("ripple", c, DEEP, {"radius": 60.0, "rings": 2, "life": 0.4})
	if w.tier >= 4:                                           # Singularity: the collapse leaves a small black hole
		add_hole(w, c, float(VR_HOLE_SECS[clampi(w.tier - 1, 0, 5)]), VR_HOLE_PULL_R, 100.0, VR_HOLE_CRUSH_R, 0.6, 1.0, "rift")

# ---------- dash: Void Step ----------

static func pre_dash(w) -> void:
	w._st.dash_from = w.player.global_position

static func dash(w) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w._st.get("dash_from", w.player.global_position)
	var d: Vector2 = w.aim
	w.fx("streak", o, VOID, {"dir": d, "length": 70.0, "width": 8.0 if w.tier >= 4 else 7.0, "life": 0.3, "col2": RIM})
	WeaponUtil.patch(w.game_world(), o + d * 35.0, "slow", 36.0, Color(0.4, 0.2, 0.7, 0.45), 3.0, 0.4)
	if w.tier >= 4:                                           # Singularity Step: a mini black hole where you left
		add_hole(w, o, 3.0, 60.0, 90.0, 12.0, 0.3, 0.5, "step")
		_arrive(w)

static func _arrive(w) -> void:
	if !await WeaponTiers.pause(w, 0.14):
		return
	w.fx("flash", w.player.global_position, VOID, {"radius": 24.0, "life": 0.3})

static func dash_hit(w, e: Node) -> void:
	if w.tier >= 2:
		_void_mark(e)

# ---------- tick ----------

static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	var st: Dictionary = w._st
	var now := _now()
	var tree: SceneTree = w.get_tree()
	var o: Vector2 = w.player.global_position
	_kills(w)
	if bool(st.locked):
		st.ess = 100.0
	elif float(st.ecl_until) > now:
		st.ess = 100.0 * (float(st.ecl_until) - now) / VR_ECLIPSE_SECS
	elif now - float(st.last_gain) > 3.0:
		st.ess = maxf(0.0, float(st.ess) - VR_ESS_DECAY * delta)
	if now >= float(st.hole_next):
		st.hole_next = now + 0.25
		_holes_tick(w)
	# Gravity Well
	if now < float(st.well_until) and now >= float(st.well_next):
		st.well_next = now + 0.5
		var c: Vector2 = st.well_c
		w.fx("vortex", c, VOID, {"radius": 100.0, "count": 3, "spin": 1.5, "inward": true, "life": 0.5})
		for e in WeaponUtil.enemies_in_circle(tree, c, 120.0):
			_pull(e, c, 80.0, 0.5)
			WeaponUtil.hit(e, H(w) * 0.3, c, 0.0, 0.0, "", true, true)
			add_ess(w, 1.0)
	# Black Sun: holds and crushes
	if now < float(st.bs_until) and now >= float(st.bs_next):
		st.bs_next = now + (0.4 if w.tier >= 6 else 0.5)
		var bp: Vector2 = o
		var br: float = _bs_r(w)
		for e2 in WeaponUtil.enemies_in_circle(tree, bp, br):
			if e2.has_method("apply_slow") and !e2.is_in_group("boss"):
				e2.apply_slow(0.1, 0.6)
			WeaponUtil.hit(e2, H(w) * (0.6 if w.tier >= 6 else 0.5), bp, 0.0, 0.0, "", true, true)
			_void_mark(e2)
		if w.tier >= 6 and now >= float(st.spear_next):
			st.spear_next = now + 1.0
			for k in 6:
				var d := Vector2.from_angle(float(k) * TAU / 6.0 + now)
				if WeaponProjectile.alive(tree) < VR_PROJ_CAP:
					WeaponProjectile.shoot(w.game_world(), bp + d * 12.0, d, 240.0, H(w) * 0.5, VOID, 0.8, 3, 40.0, {"style": "lance", "glow": 0.3, "owner_id": w.player.get_instance_id()})
		if now >= float(st.sigil_next):
			st.sigil_next = now + 1.0
			w.fx("sigil", bp, ABYSS, {"radius": 180.0, "count": 8, "spin": 0.5, "life": 1.0, "col2": DEEP})
		if now < float(st.drink_until) and now >= float(st.drink_next):
			st.drink_next = now + 1.0
			w.player.heal(3.0)
	_publish(w)

static func _bs_r(w) -> float:
	var st: Dictionary = w._st
	if w.tier >= 6:
		return 130.0
	var t: float = 1.0 - (float(st.bs_until) - _now()) / VR_BLACKSUN_SECS
	return lerpf(60.0, 110.0, clampf(t, 0.0, 1.0))

static func _publish(w) -> void:
	var a = w._aura
	if a == null or !is_instance_valid(a):
		return
	var st: Dictionary = w._st
	var hp := []
	var hk := []
	for h in st.holes:
		hp.append(h.pos)
		hk.append(0 if h.kind != "orbit" else 1)
	var bs := 0.0
	if _now() < float(st.bs_until):
		bs = snappedf(_bs_r(w), 5.0)
	var d := {"holes": hp, "kinds": hk, "bs": bs, "ecl": eclipse(w)}
	var key := str(d)
	if st.pub != key:
		st.pub = key
		a.data = d
	a.state = ess(w)

# ---------- ultimate: Event Horizon -> Black Sun -> Oblivion ----------

static func ultimate(w) -> void:
	var st: Dictionary = w._st
	st.ult_id = int(st.ult_id) + 1
	var my: int = st.ult_id
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, VOID, {"radius": 170.0, "count": 8, "spin": 1.5, "life": 0.4, "col2": RIM})
	if w.tier >= 3:
		_vortices(w, my)
	if w.tier >= 5:
		_stage2(w, my)

static func _vortices(w, my: int) -> void:
	for i in 8:                                              # each of the eight pulls draws its own vortex
		if int(w._st.ult_id) != my or !WeaponTiers.alive(w):
			return
		w.fx("vortex", w.player.global_position, VOID, {"radius": 170.0, "count": 5, "spin": 2.5, "inward": true, "life": 0.4})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), w.player.global_position, 170.0):
			_void_mark(e)
			add_ess(w, 2.0)
		if !await WeaponTiers.pause(w, 0.42):
			return

static func _stage2(w, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 3.4):
		return
	if int(st.ult_id) != my:
		return
	if w.tier >= 6:
		_oblivion(w, my)
		return
	# Black Sun: the pulled crowd is held in a growing dark disc and crushed
	var now := _now()
	st.bs_until = now + VR_BLACKSUN_SECS
	st.bs_next = now
	st.bs_pos = w.player.global_position
	st.sigil_next = now
	st.drink_until = now + VR_BLACKSUN_SECS
	st.drink_next = now + 0.5
	w.fx("shock", w.player.global_position, ABYSS, {"radius": 110.0, "thick": 8.0, "life": 0.6, "col2": VOID})
	w.player.shake(4.0, 0.3)
	Sfx.play("boss_roar", 0.05, 0.5)

static func _oblivion(w, my: int) -> void:
	var st: Dictionary = w._st
	var o: Vector2 = w.player.global_position
	# Beat 1: the sound drops, the screen darkens, one slow-motion beat
	Sfx.play("boss_roar", 0.02, 0.5)
	w.fx("sigil", o, ABYSS, {"radius": 200.0, "count": 8, "spin": 0.5, "life": 1.0, "col2": VOID})
	Game.hit_stop(0.3)
	if !await WeaponTiers.pause(w, 0.3):
		return
	# Beat 2: you become the void: eclipse locked, three singularities orbit you
	var now := _now()
	st.locked = true
	st.ess = 100.0
	st.ecl_until = now + VR_OBLIVION_SECS
	st.orbit_until = now + VR_OBLIVION_SECS
	for k in 3:
		add_hole(w, w.player.global_position + Vector2.from_angle(float(k) * TAU / 3.0) * 90.0, VR_OBLIVION_SECS, 110.0, 120.0, VR_HOLE_CRUSH_R, VR_HOLE_CRUSH_MULT, 0.5, "orbit")
	w.player.shake(5.0, 0.3)
	# Beat 3: Event Horizon: everything on screen is dragged to you and held
	if !await WeaponTiers.pause(w, 2.7):
		return
	if int(st.ult_id) != my:
		return
	o = w.player.global_position
	w.fx("vortex", o, VOID, {"radius": 220.0, "count": 6, "spin": 3.0, "inward": true, "life": 0.7})
	w.fx("shock", o, DEEP, {"radius": 220.0, "thick": 6.0, "life": 0.6, "col2": RIM})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 220.0):
		_pull(e, o, 300.0, 0.6)
		WeaponUtil.stun(e, 1.0)
	w.player.shake(4.0, 0.3)
	Sfx.play("boss_roar", 0.02, 0.7)
	# Beat 4: the singularities merge into a black sun that crushes and throws spears
	if !await WeaponTiers.pause(w, 1.0):
		return
	if int(st.ult_id) != my:
		return
	now = _now()
	st.orbit_until = 0.0
	st.holes.clear()
	st.bs_until = now + (VR_OBLIVION_SECS - 4.0)
	st.bs_next = now
	st.spear_next = now
	st.sigil_next = now
	w.fx("flash", w.player.global_position, WHITE, {"radius": 60.0, "life": 0.4})
	# Beat 5: OBLIVION
	if !await WeaponTiers.pause(w, VR_OBLIVION_SECS - 4.0):
		return
	if int(st.ult_id) != my:
		return
	st.locked = false
	st.ecl_until = 0.0
	st.bs_until = 0.0
	o = w.player.global_position
	w.fx("sigil", o, VOID, {"radius": 140.0, "count": 8, "spin": 2.0, "life": 0.7, "col2": WHITE})
	if !await WeaponTiers.pause(w, 0.7):
		return
	_the_oblivion(w)

## FINALE: the black sun collapses; everything within 140 px takes 3.0 H, the weak are erased, and you drink.
static func _the_oblivion(w) -> void:
	var o: Vector2 = w.player.global_position
	w.fx("flash", o, WHITE, {"radius": 140.0, "life": 0.5})
	w.fx("shock", o, VOID, {"radius": 180.0, "thick": 12.0, "life": 0.6, "col2": RIM})
	w.fx("vortex", o, VOID, {"radius": 180.0, "count": 5, "spin": 3.0, "inward": false, "life": 0.7})
	w.fx("ripple", o, DEEP, {"radius": 220.0, "rings": 4, "life": 0.9})
	w.fx("pillar", o, ABYSS, {"height": 200.0, "width": 50.0, "life": 0.7})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 140.0):
		WeaponUtil.hit(e, H(w) * VR_FINALE_MULT, o, 100.0, 0.0, "", true)
		if Kit.execute(e, VR_ERASE_ULT):
			w.fx("burst", e.global_position, WHITE, {"radius": 12.0, "life": 0.3})
	w._st.holes.clear()
	w.player.heal(VR_ULT_HEAL * 228.0 * Game.hp_scale())
	w.player.shake(9.0, 0.6)
	Sfx.play("ultimate", 0.02)
	Sfx.play("boss_roar", 0.02, 0.8)
	Sfx.play("gong", 0.02)

# ---------- aura: mist, holes, black sun, eclipse halo ----------

static func aura(a, c) -> void:
	var d: Dictionary = a.data
	var head: Vector2 = a.aim.rotated(a.swing) * a.reach
	for i in 3:                                               # dark mist wisps rising off the blade
		var ph: float = fposmod(a._age * 0.8 + float(i) / 3.0, 1.0)
		c.draw_circle(head + Vector2(float(i - 1) * 3.0, -ph * 12.0), 1.6 * (1.0 - ph), Color(DEEP, 0.6 * (1.0 - ph)))
	if d.get("ecl", false):                                    # eclipse: a black halo behind the blade with a thin bright rim
		c.draw_circle(head - a.aim * 3.0, 9.0, Color(ABYSS, 0.7))
		c.draw_arc(head - a.aim * 3.0, 9.0, a.aim.angle() + 1.2, a.aim.angle() + 5.1, 20, Color(WHITE, 0.9), 1.2)
	var hs: Array = d.get("holes", [])
	var ks: Array = d.get("kinds", [])
	for i in hs.size():
		var p: Vector2 = c.to_local(hs[i])
		var rr := 12.0 if int(ks[i]) == 0 else 11.0
		c.draw_circle(p, rr + 3.0, Color(VOID, 0.2))
		c.draw_circle(p, rr, ABYSS)
		c.draw_arc(p, rr, a._age * 2.0, a._age * 2.0 + 4.5, 18, Color(RIM, 0.9), 1.5)
		c.draw_arc(p, rr * 0.55, -a._age * 3.0, -a._age * 3.0 + 3.0, 12, Color(VOID, 0.8), 1.0)
	var bs: float = float(d.get("bs", 0.0))
	if bs > 0.0:
		c.draw_circle(Vector2.ZERO, bs, Color(ABYSS, 0.55))
		c.draw_arc(Vector2.ZERO, bs, 0.0, TAU, 48, Color(RIM, 0.9), 2.0)
		c.draw_arc(Vector2.ZERO, bs * 0.7, a._age, a._age + 4.0, 24, Color(VOID, 0.8), 1.5)
	if a.tier >= 6 and !d.get("ecl", false):                  # the halo: a dark disc with a bright rim behind you
		c.draw_circle(Vector2.ZERO, 18.0, Color(ABYSS, 0.35))
		c.draw_arc(Vector2.ZERO, 18.0, a._age * 0.5, a._age * 0.5 + 5.0, 20, Color(RIM, 0.6), 1.0)
