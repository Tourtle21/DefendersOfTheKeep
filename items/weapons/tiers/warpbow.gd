extends RefCounted
## Warp Bow tiers (docs/weapon_tiers/warpbow.md), Mythic: 2 Rift Gate, 3 Echo Arrow, 4 Gate Chain, 5 Rift Barrage, 6 Rift Storm.
## THE SYSTEM: Rift Gates. The anchor of Warp Arrow is an oval gate; an arrow of yours that flies through a gate is copied, the copies
## come out of your hand (tier 3) or out of every other gate (tier 4+). Gates are published to the aura (`data`) so every machine draws them.
## Gate logic lives here: t2/warpbow.gd hands its right click to `use_ability(w)` when this module exists (Stormcaller Bow keeps the old one).

const RIFT := Color(0.65, 0.50, 1.0)
const GATE := Color(0.92, 0.88, 1.0)
const ARROW := Color(0.85, 0.75, 1.0)
const VOID := Color(0.15, 0.10, 0.30)
const WB_GATE_SECS := 6.0
const WB_BACK_SECS := 2.0
const WB_ECHO_MULT := 0.6
const WB_ECHO_DELAY := 0.15
const WB_GATES_MAX := 3
const WB_CHAIN_MULT := 0.4
const WB_CHAIN_WINDOW := 2.5
const WB_BARRAGE_ARROWS := 3
const WB_BARRAGE_MULT := 0.6
const WB_FINISHER_EVERY := 5
const WB_STORM_SECS := 10.0
const WB_STORM_GATES := 6
const WB_STORM_R := 90.0
const WB_STORM_SHOT := 1.5
const WB_STORM_COPY := 0.4
const WB_FINAL_ARROWS := 4
const WB_FINAL_MULT := 0.5
const WB_PROJ_CAP := 40
const WB_GATE_R := 18.0
const NAMES := ["", "Warp Bow", "Rift Gate", "Echo Arrow", "Gate Chain", "Rift Barrage", "Rift Storm"]
const K_ANCHOR := 0
const K_BACK := 1
const K_PHASE := 2
const K_TARGET := 3
const K_VOLLEY := 4

static func palette() -> Array:
	return [RIFT, ARROW, GATE]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func equip(w) -> void:
	w._st = {"gates": [], "pending": false, "chain_until": 0.0, "placed": 0, "shots": 0, "last_shot_ms": -1000, "storm_until": 0.0,
		"storm_id": 0, "storm_next": 0.0, "storm_rr": 0, "storm_warp_cd": 0.0, "rift_flag": -10.0, "rift_arrow": null, "dash_from": Vector2.ZERO, "pub": {}}

static func H(w) -> float:
	return WeaponTiers.H(w)

# ---------- gates ----------

static func storm_on(w) -> bool:
	return float(w._st.get("storm_until", 0.0)) > _now()

## World positions of the six Rift Storm gates (a ring round the player that turns slowly; the aura draws the same ring from its own age).
static func ring(w) -> Array:
	var out := []
	var ph: float = float(w._aura._age) * 0.4 if w._aura != null and is_instance_valid(w._aura) else 0.0
	for k in WB_STORM_GATES:
		out.append(w.player.global_position + Vector2.from_angle(ph + float(k) * TAU / float(WB_STORM_GATES)) * WB_STORM_R)
	return out

## Every gate arrows can pass through (plain gates only: the storm ring copies shots through `attack` instead).
static func gate_positions(w) -> Array:
	var out := []
	for g in w._st.gates:
		out.append(g.pos)
	return out

static func add_gate(w, pos: Vector2, secs: float, kind: int) -> void:
	var gs: Array = w._st.gates
	var plain := 0
	for g in gs:
		if int(g.kind) != K_BACK:
			plain += 1
	gs.append({"pos": pos, "until": _now() + secs, "kind": kind})
	if kind == K_ANCHOR:
		w._anchor = pos
	while gs.size() > WB_GATES_MAX + 2:           # chain gates, a return gate and a phase gate at most
		gs.pop_front()
	w.fx("ring", pos, RIFT, {"radius": 14.0, "life": 0.3})
	w.fx("burst", pos, GATE, {"radius": 9.0, "life": 0.25})

static func _remove(w, g) -> void:
	w._st.gates.erase(g)

static func nearest_gate(w, p: Vector2, kinds := []):
	var best = null
	var bd := 1.0e9
	for g in w._st.gates:
		if !kinds.is_empty() and !(int(g.kind) in kinds):
			continue
		var d: float = g.pos.distance_to(p)
		if d < bd:
			bd = d
			best = g
	return best

## Right click of the Warp Bow, replacing the old anchor: plant a gate / chain more / warp / warp back.
static func use_ability(w) -> void:
	var st: Dictionary = w._st
	var now := _now()
	var cur: Vector2 = w.player.aim_point()
	if storm_on(w):                                   # Rift Storm: warp to the ring gate nearest the cursor and fire a fan from it
		if now < float(st.storm_warp_cd):
			return
		var best: Vector2 = ring(w)[0]
		for p in ring(w):
			if p.distance_to(cur) < best.distance_to(cur):
				best = p
		st.storm_warp_cd = now + 1.0
		_warp_to(w, best)
		var dir: Vector2 = (cur - w.player.global_position).normalized() if cur.distance_to(w.player.global_position) > 2.0 else w.aim
		for i in 5:
			_shoot(w, w.player.global_position + dir.rotated((i - 2) * 0.17) * 8.0, dir.rotated((i - 2) * 0.17), 330.0, H(w) * WB_FINAL_MULT, 2, 0.8)
		return
	var back = nearest_gate(w, w.player.global_position, [K_BACK])
	var anchors := 0
	for g in st.gates:
		if int(g.kind) == K_ANCHOR:
			anchors += 1
	if st.pending and anchors > 0:
		# Gate Chain (tier 4): a quick second or third click plants another gate; clicking on a gate (or a fourth click) warps to it
		var on_gate = nearest_gate(w, cur, [K_ANCHOR])
		var aiming: bool = on_gate != null and on_gate.pos.distance_to(cur) <= 22.0
		if w.tier >= 4 and now < float(st.chain_until) and anchors < WB_GATES_MAX and !aiming:
			_plant(w)
			return
		var dest = on_gate if w.tier >= 4 and on_gate != null and aiming else _newest(w, K_ANCHOR)
		if dest == null:
			dest = _newest(w, K_ANCHOR)
		_warp_gate(w, dest)
		return
	if back != null and w.tier >= 2:                   # Rift Gate: the gate left behind takes you back
		_warp_gate(w, back)
		return
	if w._ability_cd > 0.0:
		return
	_plant(w)

static func _newest(w, kind: int):
	var r = null
	for g in w._st.gates:
		if int(g.kind) == kind:
			r = g
	return r

static func _plant(w) -> void:
	var st: Dictionary = w._st
	var now := _now()
	var dist: float = minf(150.0, (w.player.aim_point() - w.player.global_position).length())
	var land: Vector2 = w.player.global_position + w.aim * dist
	WeaponProjectile.shoot(w.game_world(), w.player.global_position + w.aim * 8.0, w.aim, 300.0, 0.5, Color(0.7, 0.5, 1.0), dist / 300.0, 0, 20.0, {"owner_id": w.player.get_instance_id(), "gated": true})
	add_gate(w, land, WB_GATE_SECS, K_ANCHOR)
	st.pending = true
	st.placed = int(st.placed) + 1 if now < float(st.chain_until) else 1
	st.chain_until = now + WB_CHAIN_WINDOW
	Sfx.play("cast", 0.05, 1.2)

static func _warp_gate(w, g) -> void:
	var st: Dictionary = w._st
	var kind: int = int(g.kind)
	var to: Vector2 = g.pos
	_remove(w, g)
	if kind == K_ANCHOR:
		st.pending = false
		st.placed = 0
		w._ability_cd = w.ability_cooldown
	_warp_to(w, to, kind != K_BACK)

## The warp itself: rings at both ends, a strike on arrival (and from tier 3 at the departure), and a way back for 2 s.
static func _warp_to(w, dest: Vector2, leave_back := true) -> void:
	var from: Vector2 = w.player.global_position
	w.player.blink(dest - from)
	w.fx("ring", from, RIFT, {"radius": 16.0, "life": 0.3})
	w.fx("ring", w.player.global_position, Color(0.8, 0.6, 1.0), {"radius": 26.0, "life": 0.3})
	w.fx("burst", w.player.global_position, GATE, {"radius": 16.0, "life": 0.25})
	w.ground_strike(w.player.global_position, 26.0, 0.05, 3.0, 200.0, RIFT, 0.5)
	if w.tier >= 3:                                    # Echo Gate: the departure point is struck too
		w.ground_strike(from, 26.0, 0.05, 2.0, 160.0, RIFT, 0.3)
	if leave_back and w.tier >= 2:
		add_gate(w, from, WB_BACK_SECS, K_BACK)
	w._on_warped(w.player.global_position)
	w.player.shake(2.0, 0.15)
	Sfx.play("cast", 0.05, 0.7)

# ---------- shooting helpers ----------

static func _shoot(w, pos: Vector2, dir: Vector2, speed: float, dmg: float, pierce: int, life: float, big := false) -> void:
	if WeaponProjectile.alive(w.get_tree()) >= WB_PROJ_CAP:
		return
	var extra := {"owner_id": w.player.get_instance_id(), "gated": true, "trail": 4, "glow": 0.3}
	if big:
		extra["size"] = 1.4
	WeaponProjectile.shoot(w.game_world(), pos, dir, speed, dmg, ARROW, life, pierce, 60.0, extra)

## The damage of the arrow that was just released: the Bow's own rule.
static func _arrow_dmg(w) -> float:
	var ratio: float = minf(1.0, float(w._draw_t) / 0.8)
	return H(w) * (0.33 + 0.67 * ratio)

# ---------- hooks ----------

static func pre_dash(w) -> void:
	w._st.dash_from = w.player.global_position

## Phase Gate (tier 4): the dash leaves a gate at its start, a streak behind.
static func dash(w) -> void:
	if w.tier < 4:
		return
	var from: Vector2 = w._st.dash_from
	w.fx("streak", from, RIFT, {"dir": w.aim, "length": 42.0, "width": 5.0, "life": 0.25, "col2": GATE})
	add_gate(w, from, 2.0, K_PHASE)

## One arrow was released (called from t2/warpbow.gd `release_item`).
static func attack(w) -> void:
	var st: Dictionary = w._st
	var ms := Time.get_ticks_msec()
	if ms - int(st.last_shot_ms) < 120:
		return
	st.last_shot_ms = ms
	st.shots = int(st.shots) + 1
	if w.tier >= 6 and int(st.shots) % WB_FINISHER_EVERY == 0:
		st.rift_flag = _now()
	if storm_on(w):                                    # Rift Storm: the arrow is fired from every gate of the ring, at the cursor
		var dmg := _arrow_dmg(w) * WB_STORM_COPY
		var cur: Vector2 = w.player.aim_point()
		var n := 0
		for p in ring(w):
			var d: Vector2 = (cur - p).normalized()
			if d.length() < 0.5:
				d = w.aim
			_shoot(w, p + d * 6.0, d, 300.0, dmg, 0, 0.9)
			n += 1
		w.fx("burst", w.player.global_position + w.aim * 10.0, GATE, {"radius": 10.0, "life": 0.2})

static func tick(w, _delta: float) -> void:
	var st: Dictionary = w._st
	var now := _now()
	var pid: int = w.player.get_instance_id()
	# gates that ran out; an anchor nobody used costs a 3 s cooldown (as before)
	var gs: Array = st.gates
	for i in range(gs.size() - 1, -1, -1):
		if float(gs[i].until) <= now:
			gs.remove_at(i)
	if st.pending:
		var left := false
		for g in gs:
			if int(g.kind) == K_ANCHOR:
				left = true
		if !left:
			st.pending = false
			st.placed = 0
			w._ability_cd = maxf(w._ability_cd, 3.0)
	# own arrows: tag new ones (violet, trail, glow), echo the ones that fly through a gate
	var tree: SceneTree = w.get_tree()
	var plain: Array = gate_positions(w)
	var projs := 0
	for n in tree.get_nodes_in_group("net"):
		if !(n is WeaponProjectile):
			continue
		projs += 1
		if n.owner_id == 0 and n._age < 0.1 and n.global_position.distance_to(w.player.global_position) < 18.0:
			n.owner_id = pid
			if n.color.is_equal_approx(Color(0.9, 0.8, 0.5)) or n.color.is_equal_approx(Color(0.8, 0.6, 1.0)):
				n.color = ARROW
			n.trail = 4
			n.glow = 0.3
			if float(st.rift_flag) > 0.0 and now - float(st.rift_flag) < 0.4 and n.damage > 1.0:
				st.rift_flag = -10.0
				st.rift_arrow = n
				n.size = 1.4
				n.color = Color(0.95, 0.9, 1.0)
		elif n.owner_id == pid and !n.gated and w.tier >= 3 and !plain.is_empty():
			for gp in plain:
				if n.global_position.distance_to(gp) <= WB_GATE_R:
					_echo(w, n, gp, plain)
					break
	# the rift arrow of the tier 6 finisher opens a gate where it lands
	var ra = st.rift_arrow
	if ra != null:
		if !is_instance_valid(ra):
			st.rift_arrow = null
		elif ra._hit.size() > 0:
			st.rift_arrow = null
			_rift_finisher(w, ra._hit[0].global_position if is_instance_valid(ra._hit[0]) else ra.global_position)
	# Rift Storm: a gate fires at the nearest enemy every 1.5 s
	if storm_on(w) and now >= float(st.storm_next):
		st.storm_next = now + WB_STORM_SHOT
		var rg: Array = ring(w)
		st.storm_rr = (int(st.storm_rr) + 1) % rg.size()
		var src: Vector2 = rg[int(st.storm_rr)]
		var tgt = WeaponUtil.nearest(tree, src, 240.0)
		if tgt != null:
			var d: Vector2 = (tgt.global_position - src).normalized()
			w.fx("flash", src, GATE, {"radius": 10.0, "life": 0.2})
			_shoot(w, src + d * 6.0, d, 380.0, H(w), 3, 0.9, true)
	_publish(w)

static func _echo(w, n, gp: Vector2, plain: Array) -> void:
	n.gated = true
	w.fx("flash", gp, GATE, {"radius": 9.0, "life": 0.25})
	var dir: Vector2 = n.vel.normalized()
	var spd: float = n.vel.length()
	var dmg: float = n.damage
	if w.tier >= 4:
		var others := 0
		for op in plain:
			if op.distance_to(gp) > 4.0:
				others += 1
				_shoot(w, op + dir * 6.0, dir, spd, dmg * WB_CHAIN_MULT, n.pierce, 0.9)
				w.fx("burst", op, RIFT, {"radius": 8.0, "life": 0.2})
		if others > 0:
			return
	_echo_hand(w, dir, spd, dmg * WB_ECHO_MULT, n.pierce)

static func _echo_hand(w, dir: Vector2, spd: float, dmg: float, pierce: int) -> void:
	if !await WeaponTiers.pause(w, WB_ECHO_DELAY):
		return
	_shoot(w, w.player.global_position + dir * 8.0, dir, spd, dmg, pierce, 1.0)
	w.fx("burst", w.player.global_position + dir * 8.0, RIFT, {"radius": 7.0, "life": 0.2})

## Rift arrow (tier 6, every 5th shot): a 1.5 s gate opens at the target and three arrows burst out in a 120 degree fan.
static func _rift_finisher(w, at: Vector2) -> void:
	add_gate(w, at, 1.5, K_TARGET)
	w.fx("shock", at, RIFT, {"radius": 24.0, "thick": 4.0, "life": 0.3, "col2": GATE})
	var base: float = (at - w.player.global_position).angle()
	for i in 3:
		var d := Vector2.from_angle(base + deg_to_rad(60.0) * float(i - 1))
		_shoot(w, at + d * 6.0, d, 320.0, H(w) * 0.5, 1, 0.7)
	Sfx.play("big_hit", 0.1, 1.3)

static func _publish(w) -> void:
	var a = w._aura
	if a == null or !is_instance_valid(a):
		return
	var g := []
	var k := []
	for x in w._st.gates:
		g.append(x.pos)
		k.append(int(x.kind))
	var d := {"g": g, "k": k, "storm": storm_on(w)}
	if w._st.pub != d:
		w._st.pub = d
		a.data = d
	a.state = minf(1.0, float(w._draw_t) / 0.8) if w._drawing else 0.0

# ---------- ultimate ----------

static func ultimate(w) -> void:
	var st: Dictionary = w._st
	var o: Vector2 = w.player.global_position
	st.storm_id = int(st.storm_id) + 1
	var my: int = st.storm_id
	w.fx("sigil", o + w.aim * 12.0, RIFT, {"radius": 40.0, "count": 6, "spin": 1.5, "life": 0.3, "col2": GATE})   # the volley's own look (Echo Arrow)
	if w.tier < 5:
		return
	_barrage(w, my)
	if w.tier >= 6:
		_storm(w, my)

## Rift Barrage: three arrows from every gate (one is planted at the cursor if there is none), a gate after a gate, 0.3 s apart.
static func _barrage(w, my: int) -> void:
	var st: Dictionary = w._st
	var cur: Vector2 = w.cursor_target(150.0)
	var src: Array = gate_positions(w)
	if src.is_empty():
		add_gate(w, cur, 3.0, K_VOLLEY)
		src = [cur]
	for i in src.size():
		if !await WeaponTiers.pause(w, 0.3):
			return
		if int(st.storm_id) != my:
			return
		var p: Vector2 = src[i]
		w.fx("flash", p, GATE, {"radius": 12.0, "life": 0.25})
		var tgt: Vector2 = w.player.aim_point()
		var base: Vector2 = (tgt - p).normalized()
		if base.length() < 0.5:
			base = w.aim
		for k in WB_BARRAGE_ARROWS:
			var d := base.rotated(float(k - 1) * 0.12)
			_shoot(w, p + d * 6.0, d, 330.0, H(w) * WB_BARRAGE_MULT, 2, 0.9)
		Sfx.play("whoosh", 0.1, 1.4)

## Rift Storm: for 10 s six gates ring you, your shots are fired from all of them, the right click warps, a gate shoots every 1.5 s;
## at the end all gates fire at once.
static func _storm(w, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 1.0):
		return
	if int(st.storm_id) != my:
		return
	st.storm_until = _now() + WB_STORM_SECS
	st.storm_next = _now() + 0.5
	var o: Vector2 = w.player.global_position
	w.fx("shock", o, RIFT, {"radius": WB_STORM_R + 20.0, "thick": 6.0, "life": 0.5, "col2": GATE})
	w.fx("sigil", o, GATE, {"radius": WB_STORM_R, "count": 6, "spin": 2.0, "life": 0.5, "col2": RIFT})
	w.player.shake(6.0, 0.4)
	Sfx.play("ultimate", 0.02)
	if !await WeaponTiers.pause(w, WB_STORM_SECS):
		return
	if int(st.storm_id) != my:
		return
	_finale(w)

static func _finale(w) -> void:
	var st: Dictionary = w._st
	st.storm_until = 0.0
	var tree: SceneTree = w.get_tree()
	var rg: Array = ring(w)
	var budget: int = maxi(0, WB_PROJ_CAP - WeaponProjectile.alive(tree))
	for p in rg:
		w.fx("flash", p, GATE, {"radius": 30.0, "life": 0.4})
		var tgt = WeaponUtil.nearest(tree, p, 260.0)
		var base: Vector2 = (tgt.global_position - p).normalized() if tgt != null else (p - w.player.global_position).normalized()
		for k in WB_FINAL_ARROWS:
			if budget <= 0:
				break
			budget -= 1
			var d := base.rotated(float(k - 1.5) * 0.14)
			WeaponProjectile.shoot(w.game_world(), p + d * 6.0, d, 340.0, H(w) * WB_FINAL_MULT, ARROW, 0.9, 2, 60.0, {"owner_id": w.player.get_instance_id(), "gated": true, "trail": 4, "glow": 0.3})
	w.fx("ripple", w.player.global_position, RIFT, {"radius": 100.0, "rings": 3, "life": 0.7})
	w.player.shake(6.0, 0.35)
	Sfx.play("ultimate", 0.02, 1.2)

# ---------- aura (every machine draws the gates from `data`) ----------

static func _oval(c, p: Vector2, t: float, col: Color, rx: float, ry: float, tilt := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := float(i) * TAU / 16.0
		pts.append(p + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
	c.draw_colored_polygon(pts, Color(VOID, 0.55 * col.a))
	c.draw_polyline(pts, col, 1.5)
	var sw := Vector2.from_angle(t * 3.0)
	c.draw_circle(p + Vector2(sw.x * rx * 0.55, sw.y * ry * 0.55).rotated(tilt), 1.0, Color(GATE, col.a))
	c.draw_circle(p + Vector2(-sw.x * rx * 0.35, -sw.y * ry * 0.35).rotated(tilt), 0.8, Color(ARROW, col.a * 0.8))

static func aura(a, c) -> void:
	var d: Dictionary = a.data
	var gs: Array = d.get("g", [])
	var ks: Array = d.get("k", [])
	for i in gs.size():
		var kd: int = int(ks[i]) if i < ks.size() else 0
		var col := RIFT if kd != K_BACK else Color(GATE, 0.6)
		_oval(c, c.to_local(gs[i]), a._age + float(i) * 0.3, col, 4.5, 8.0)
	if d.get("storm", false):
		for k in WB_STORM_GATES:
			var ang: float = a._age * 0.4 + float(k) * TAU / float(WB_STORM_GATES)
			_oval(c, Vector2.from_angle(ang) * WB_STORM_R, a._age + float(k), Color(RIFT, 0.95), 7.0, 13.0, ang)
	elif a.tier >= 6:                                  # the halo: six small gates round the hand
		for k in 6:
			var ang2: float = a._age * 0.6 + float(k) * TAU / 6.0
			_oval(c, a.aim.rotated(a.swing) * a.reach + Vector2.from_angle(ang2) * (a.reach + 9.0), a._age + float(k), Color(RIFT, 0.8), 1.6, 3.0, ang2)
	if a.state > 0.99:                                 # the bowstring glows at full draw
		var h: Vector2 = a.aim * (a.reach + 2.0)
		c.draw_line(h + a.aim.orthogonal() * 7.0, h - a.aim.orthogonal() * 7.0, Color(ARROW, 0.9), 1.5)
		c.draw_circle(h, 3.0, Color(RIFT, 0.3))
