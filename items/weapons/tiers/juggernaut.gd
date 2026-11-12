extends RefCounted
## Juggernaut tiers (docs/weapon_tiers/juggernaut.md), Mythic, fusion tier 3: 3 Siege Plate, 4 Reactive Armour, 5 Siege Engine, 6 Colossus.
## THE SYSTEM: Armour Plates. The hits you block while braced (`_stored`, at most 8) are plates, small gold shields that orbit you (aura `state`).
## Blocking and the tier 4 charge give plates, releasing the Fortress spends them (the more, the bigger), and from tier 4 they are ammunition
## for the reactive shard and the Colossus salvo. Plates never reduce damage taken.
## The Juggernaut's own rows replace the Bulwark's riders: this module does not call tiers/bulwark.gd.

const PLATE := Color(0.62, 0.72, 0.95)
const GOLD := Color(1.0, 0.85, 0.40)
const RIVET := Color(0.95, 0.95, 1.0)
const SHADOW := Color(0.20, 0.25, 0.40)
const JG_SHARD_MULT := 0.4
const JG_CONE_R := 100.0
const JG_CARRY := 60.0
const JG_PULSE_R := [58.0, 66.0, 74.0, 82.0, 90.0, 98.0]
const JG_PULSE_SHARDS := 8
const JG_SHARD_PULSE_MULT := 0.3
const JG_COLOSSUS_SECS := 8.0
const JG_STEP_EVERY := 0.5
const JG_STEP_MULT := 0.4
const JG_FINALE_MULT := 2.5
const JG_PLATE_BONUS := 0.5
const JG_FINISHER_EVERY := 6
const JG_SLAM_EVERY := 3
const JG_PLATES_MAX := 8
const JG_PROJ_CAP := 24
const NAMES := ["", "Juggernaut", "", "Siege Plate", "Reactive Armour", "Siege Engine", "Colossus"]

static func palette() -> Array:
	return [PLATE, GOLD, RIVET]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func H(w) -> float:
	return WeaponTiers.H(w)

static func equip(w) -> void:
	w._st = {"swings": 0, "last_ms": -1000, "ext": 0.0, "ult_id": 0, "fort_until": 0.0, "colossus_until": 0.0, "step_next": 0.0, "salvo_next": 0.0, "pub": ""}

static func colossus(w) -> bool:
	return float(w._st.get("colossus_until", 0.0)) > _now()

static func add_plates(w, n: int) -> void:
	w._stored = mini(JG_PLATES_MAX, int(w._stored) + n)

# ---------- ability: the Fortress ----------

## A hit was blocked while braced (called from juggernaut.gd `_on_absorb` after the old counter-pulse).
static func on_block(w, from: Vector2) -> void:
	var o: Vector2 = w.player.global_position
	# Counterweight: the blow pushes its attacker away
	w.fx("ring", o, GOLD, {"radius": 24.0, "life": 0.25})
	w.fx("star", o, RIVET, {"radius": 10.0, "count": 4, "spin": 1.0, "life": 0.25})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 30.0):
		e.push((e.global_position - o).normalized() * 200.0, 0.15)
	if w.tier < 4:
		return
	# Reactive Armour: a plate-shard flies back at the attacker
	var d: Vector2 = (from - o).normalized() if from.distance_to(o) > 3.0 else w.aim
	_shard(w, o + d * 8.0, d, H(w) * JG_SHARD_MULT, 2.0)

static func _shard(w, pos: Vector2, dir: Vector2, dmg: float, homing: float, speed := 260.0, life := 0.7, pierce := 0) -> void:
	if WeaponProjectile.alive(w.get_tree()) >= 40:
		return
	WeaponProjectile.shoot(w.game_world(), pos, dir, speed, dmg, GOLD, life, pierce, 60.0, {"style": "shard", "homing": homing, "owner_id": w.player.get_instance_id(), "glow": 0.2, "size": 1.1})

## Called from juggernaut.gd after the old release: `n` plates were stored.
static func braced_release(w, n: int) -> void:
	w._st.ext = 0.0
	w.fx("ring", w.player.global_position, GOLD, {"radius": 30.0 + 8.0 * n, "life": 0.4})
	if w.tier >= 4 and n >= JG_PLATES_MAX:
		var o: Vector2 = w.player.global_position
		w.fx("cone", o, GOLD, {"radius": JG_CONE_R, "dir": w.aim, "half_angle": 0.7, "life": 0.35, "col2": RIVET})
		for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, JG_CONE_R, 40.0):
			WeaponUtil.hit(e, H(w) * 0.18, o, 420.0, 0.0, "", true)
		Sfx.play("thump", 0.1)

## Left click while braced (juggernaut.gd `attack`): a shield bash that keeps the brace up for half a second more (at most 4.5 s in all).
static func bash(w) -> void:
	var st: Dictionary = w._st
	w.swing(0.6, 0.15)
	var o: Vector2 = w.player.global_position
	w.fx("arc", o, GOLD, {"radius": 26.0, "dir": w.aim, "half_angle": 0.9, "life": 0.18})
	w.fx("burst", o + w.aim * 18.0, RIVET, {"radius": 10.0, "life": 0.2})
	for e in WeaponUtil.enemies_in_arc(w.get_tree(), o, w.aim, 26.0, 50.0):
		WeaponUtil.hit(e, H(w) * 0.5, o, 200.0, 0.0, "", true)
	if float(st.ext) < 1.5:
		st.ext = float(st.ext) + 0.5
		w._brace_t = maxf(0.0, float(w._brace_t) - 0.5)
	Sfx.play("hit", 0.1)

# ---------- attack ----------

static func attack(w) -> void:
	_attack(w)                                          # (a hook called through callv must not suspend itself)

static func _attack(w) -> void:
	if w._braced:
		return
	var st: Dictionary = w._st
	var ms := Time.get_ticks_msec()
	if ms - int(st.last_ms) < 250:
		return
	st.last_ms = ms
	st.swings = int(st.swings) + 1
	var n: int = st.swings
	if !await WeaponTiers.pause(w, 0.22):
		return
	var o: Vector2 = w.player.global_position
	w.fx("shards", o + w.aim * 22.0, PLATE, {"radius": 26.0, "count": 6, "life": 0.3})
	if w.tier >= 6 and n % JG_FINISHER_EVERY == 0:      # Colossus finisher: a stomp
		w.fx("shock", o + w.aim * 14.0, GOLD, {"radius": 50.0, "thick": 6.0, "life": 0.35, "col2": RIVET})
		w.fx("crack", o + w.aim * 14.0, GOLD, {"radius": 50.0, "count": 8, "life": 0.7})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), o + w.aim * 14.0, 50.0):
			WeaponUtil.hit(e, H(w) * 1.5, o, 240.0, 0.0, "", true)
			WeaponUtil.stun(e, 1.0)
		w.player.shake(4.0, 0.25)
		Sfx.play("thump", 0.1)
	elif n % JG_SLAM_EVERY == 0:                         # Siege Plate: every third swing is a slam
		var at: Vector2 = o + w.aim * 20.0
		w.fx("shock", at, GOLD, {"radius": 40.0, "thick": 5.0, "life": 0.3, "col2": RIVET})
		w.fx("crack", at, SHADOW, {"radius": 40.0, "count": 6, "life": 0.6})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 40.0):
			WeaponUtil.hit(e, H(w), o, 180.0, 0.0, "", true)
			WeaponUtil.stun(e, 0.8)
		w.player.shake(3.0, 0.2)
		Sfx.play("thump", 0.1)

## Every hit of the weapon while Colossus carries the enemy along.
static func on_hit(w, e: Node, _dmg: float) -> void:
	if colossus(w) and is_instance_valid(e) and e.has_method("push"):
		e.push(w.aim * 200.0, 0.15)

# ---------- dash ----------

static func dash(w) -> void:
	_dash(w)

static func _dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	w.fx("streak", o - w.aim * 60.0, PLATE, {"dir": w.aim, "length": 60.0, "width": 12.0, "life": 0.3, "col2": GOLD})
	if !await WeaponTiers.pause(w, 0.26):
		return
	var p: Vector2 = w.player.global_position
	w.fx("shock", p, GOLD, {"radius": 40.0, "thick": 5.0, "life": 0.3, "col2": RIVET})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 40.0):
		WeaponUtil.hit(e, H(w), p, 160.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.0)
	w.player.shake(3.0, 0.2)

## Reactive Charge: every enemy rammed is carried 60 px and adds a plate.
static func dash_hit(w, e: Node) -> void:
	if w.tier < 4 or !is_instance_valid(e):
		return
	if e.has_method("push"):
		e.push(w.aim * JG_CARRY / 0.2, 0.2)
	add_plates(w, 1)
	w.fx("burst", e.global_position, GOLD, {"radius": 9.0, "life": 0.2})

# ---------- tick: plates, absorbing shots, Colossus ----------

static func tick(w, _delta: float) -> void:
	var st: Dictionary = w._st
	var now := _now()
	var col := colossus(w)
	var a = w._aura
	if a != null and is_instance_valid(a):
		a.state = float(w._stored)
		var d := {"colossus": col}
		var key := str(d)
		if st.pub != key:
			st.pub = key
			a.data = d
	if w.tier >= 5 and now < float(st.fort_until):     # the fortress swallows enemy shots within 50 px
		var o: Vector2 = w.player.global_position
		for s in w.get_tree().get_nodes_in_group("enemy_shot"):
			if is_instance_valid(s) and !s.is_queued_for_deletion() and s.global_position.distance_to(o) <= 50.0:
				s.queue_free()
				add_plates(w, 1)
				w.fx("burst", s.global_position, GOLD, {"radius": 9.0, "life": 0.2})
	if col:
		if !w._braced:
			w.player.speed_mult = 0.85
		w.scale = Vector2(1.25, 1.25)
		if now >= float(st.step_next) and w.player.velocity.length() > 8.0:
			st.step_next = now + JG_STEP_EVERY
			var p: Vector2 = w.player.global_position
			w.fx("shock", p, GOLD, {"radius": 40.0, "thick": 4.0, "life": 0.3, "col2": RIVET})
			for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 40.0):
				WeaponUtil.hit(e, H(w) * JG_STEP_MULT, p, 160.0, 0.0, "", true, true)
		if now >= float(st.salvo_next):
			st.salvo_next = now + 1.0
			_salvo(w)
	elif w.scale.x > 1.0:
		w.scale = Vector2.ONE
		if !w._braced:
			w.player.speed_mult = 1.0

static func _salvo(w) -> void:
	var n: int = int(w._stored)
	if n <= 0:
		return
	var o: Vector2 = w.player.global_position
	var tgt = WeaponUtil.nearest(w.get_tree(), o, 200.0)
	if tgt == null:
		return
	for i in n:
		var d: Vector2 = (tgt.global_position - o).normalized().rotated((float(i) - float(n - 1) * 0.5) * 0.12)
		_shard(w, o + d * 10.0, d, H(w) * JG_SHARD_MULT, 2.0, 240.0, 0.8)
	w.fx("burst", o, GOLD, {"radius": 14.0, "life": 0.25})

# ---------- ultimate: Unbreakable -> Siege Engine -> Colossus ----------

static func ultimate(w) -> void:
	_ultimate(w)

static func _ultimate(w) -> void:
	var st: Dictionary = w._st
	st.ult_id = int(st.ult_id) + 1
	var my: int = st.ult_id
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, GOLD, {"radius": 60.0, "count": 8, "spin": 1.5, "life": 0.4, "col2": RIVET})
	st.fort_until = _now() + 6.0 + (JG_COLOSSUS_SECS if w.tier >= 6 else 0.0)
	if w.tier < 5:
		return                                           # the plain six pulses run in juggernaut.gd's ultimate
	for i in 6:
		await _siege_pulse(w, my, i)
		if int(st.ult_id) != my:
			return
	if w.tier >= 6:
		await _colossus(w, my)

static func _siege_pulse(w, my: int, i: int) -> void:
	if !WeaponTiers.alive(w) or int(w._st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	var r: float = JG_PULSE_R[i]
	w.fx("ring", o, GOLD, {"radius": r, "life": 0.25})
	w.fx("shock", o, PLATE, {"radius": r, "thick": 4.0, "life": 0.3, "col2": RIVET})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, r):
		WeaponUtil.hit(e, 3.0, o, 300.0, 0.6, "", true)
	w.player.shake(1.5, 0.1)
	var rot := float(i) * 0.2
	for k in JG_PULSE_SHARDS:
		var d := Vector2.from_angle(rot + float(k) * TAU / float(JG_PULSE_SHARDS))
		if WeaponProjectile.alive(w.get_tree()) < JG_PROJ_CAP + 12:
			WeaponProjectile.shoot(w.game_world(), o + d * r * 0.8, d, 200.0, H(w) * JG_SHARD_PULSE_MULT, GOLD, 0.3, 1, 60.0, {"style": "shard", "owner_id": w.player.get_instance_id(), "glow": 0.2})
	await WeaponTiers.pause(w, 1.0)

## Colossus (8 s): bigger, slower, a shock at every footstep, plates fire as a salvo each second; then the titanic slam.
static func _colossus(w, my: int) -> void:
	var st: Dictionary = w._st
	st.colossus_until = _now() + JG_COLOSSUS_SECS
	st.step_next = 0.0
	st.salvo_next = _now() + 0.5
	w.fx("shock", w.player.global_position, GOLD, {"radius": 60.0, "thick": 7.0, "life": 0.5, "col2": RIVET})
	w.fx("flash", w.player.global_position, RIVET, {"radius": 28.0, "life": 0.3})
	w.player.shake(5.0, 0.3)
	Sfx.play("thump", 0.05)
	if !await WeaponTiers.pause(w, JG_COLOSSUS_SECS):
		return
	if int(st.ult_id) != my:
		return
	st.colossus_until = 0.0
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, GOLD, {"radius": 90.0, "count": 12, "spin": 2.0, "life": 0.4, "col2": RIVET})
	var plates: int = int(w._stored)
	if !await WeaponTiers.pause(w, 0.4):
		return
	o = w.player.global_position
	w.fx("flash", o, RIVET, {"radius": 90.0, "life": 0.45})
	w.fx("shock", o, GOLD, {"radius": 100.0, "thick": 9.0, "life": 0.5, "col2": RIVET})
	w.fx("crack", o, SHADOW, {"radius": 100.0, "count": 12, "life": 0.9})
	var dmg: float = H(w) * JG_FINALE_MULT + float(plates) * H(w) * JG_PLATE_BONUS
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 100.0):
		WeaponUtil.hit(e, dmg, o, 440.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.2)
	w._stored = 0
	w.player.shake(7.0, 0.5)
	Sfx.play("thump", 0.02)
	Sfx.play("ultimate", 0.02, 0.8)

# ---------- aura: plates round you ----------

static func _plate(c, p: Vector2, ang: float, big: float) -> void:
	var f := Vector2.from_angle(ang)
	var s := f.orthogonal()
	var pts := PackedVector2Array([p + f * 3.0 * big, p + s * 2.4 * big, p - f * 2.6 * big + s * 1.2 * big, p - f * 2.6 * big - s * 1.2 * big, p - s * 2.4 * big])
	c.draw_colored_polygon(pts, Color(GOLD, 0.95))
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(SHADOW, 0.9), 0.8)
	c.draw_circle(p, 0.7 * big, RIVET)

static func aura(a, c) -> void:
	var n: int = int(a.state)
	var big: float = 1.3 if a.data.get("colossus", false) else 1.0
	var rr: float = 15.0 * big
	for i in n:
		var ang: float = a._age * 1.5 + float(i) * TAU / float(maxi(n, 1))
		_plate(c, Vector2.from_angle(ang) * rr, ang, big)
	if a.data.get("colossus", false):
		c.draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(GOLD, 0.35), 2.0)
		c.draw_arc(Vector2.ZERO, 22.0, a._age, a._age + 4.0, 20, Color(RIVET, 0.5), 1.0)
