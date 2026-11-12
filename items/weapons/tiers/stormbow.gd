extends RefCounted
## Stormcaller Bow tiers (docs/weapon_tiers/stormbow.md), Ancient, fusion tier 3: 3 Charged Gates, 4 Storm Gate, 5 Thunderhead, 6 Tempest Archer.
## THE SYSTEM: Charged Gates. The Warp Bow's Rift Gates (placed by Storm Warp, tiers/warpbow.gd does the placing, echoing and the ring of six) fused with the
## Tempest's charge (the meta `charge`, 5 at most, shown as motes): arrows that hit leave charges, gates are live (they shock what crosses them), and
## ARRIVING at a gate detonates every charge within 100 px. This module delegates the gate logic to warpbow.gd (w._st carries the same keys).
## Hook functions never suspend (they run through callv): waits live in helper coroutines.

const Wb := preload("res://items/weapons/tiers/warpbow.gd")
const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const STORM := Color(0.70, 0.85, 1.0)
const WHITE := Color(1.0, 1.0, 1.0)
const CLOUD := Color(0.35, 0.35, 0.60)
const RIFT := Color(0.65, 0.50, 1.0)
const SB2_JUMP_MULT := 0.5
const SB2_DETONATE_R := 100.0
const SB2_DETONATE_MULT := 1.0
const SB2_STATIC_T := 1.0
const SB2_LINE_MULT := 0.4
const SB2_LINE_TICK := 0.5
const SB2_CLOUD_SECS := 6.0
const SB2_CLOUD_EVERY := 0.5
const SB2_CLOUD_MULT := 1.0
const SB2_FINISHER_EVERY := 5
const SB2_ARCHER_SECS := 12.0
const SB2_BOLT_EVERY := 0.5
const SB2_BOLT_MULT := 0.8
const SB2_JUDGE_MULT := 2.5
const NAMES := ["", "", "", "Charged Gates", "Storm Gate", "Thunderhead", "Tempest Archer"]

static func palette() -> Array:
	return [STORM, WHITE, RIFT]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func H(w) -> float:
	return WeaponTiers.H(w)

static func equip(w) -> void:
	Wb.equip(w)
	w._st.merge({"line_next": 0.0, "static_pos": Vector2.ZERO, "static_at": 0.0, "ult_id": 0, "cloud_until": 0.0, "cloud_next": 0.0, "cloud_sigil": 0.0, "cloud_c": Vector2.ZERO,
		"cloud_gate": 0.0, "archer_until": 0.0, "bolt_next": 0.0, "dash_from": Vector2.ZERO, "fin_next": 0}, true)

static func archer(w) -> bool:
	return float(w._st.get("archer_until", 0.0)) > _now()

# ---------- charges ----------

static func charges(e) -> int:
	return int(e.get_meta("charge", 0)) if is_instance_valid(e) else 0

static func add_charge(e, n := 1) -> void:
	if is_instance_valid(e) and !e.is_queued_for_deletion():
		e.set_meta("charge", mini(5, charges(e) + n))

## Every charge within `r` of `at` goes off: 1.0 H each (quiet), a bolt from above on each.
static func detonate(w, at: Vector2, r: float, mult := SB2_DETONATE_MULT) -> int:
	var n := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, r):
		var c := charges(e)
		if c > 0:
			n += c
			e.remove_meta("charge")
			w.fx("bolt", e.global_position + Vector2(0, -50), STORM, {"dir": Vector2(0, 1), "length": 50.0, "width": 2.0, "life": 0.3})
			WeaponUtil.hit(e, H(w) * mult * float(c), e.global_position, 20.0, 0.0, "", true, true)
	return n

static func on_hit(w, e: Node, dmg: float) -> void:
	if !is_instance_valid(e):
		return
	add_charge(e, 1)
	if dmg >= H(w) * 0.98:                                       # a full draw: one jump of 0.5 H to the nearest enemy within 55 px
		var o = WeaponUtil.nearest(w.get_tree(), e.global_position, 55.0, [e])
		if o != null:
			Kit.bolt(w, e.global_position, o.global_position, STORM)
			WeaponUtil.hit(o, H(w) * SB2_JUMP_MULT, e.global_position, 20.0, 0.0, "", true, true)

# ---------- delegated to the Warp Bow module ----------

static func use_ability(w) -> void:
	Wb.use_ability(w)

static func pre_dash(w) -> void:
	w._st.dash_from = w.player.global_position

static func dash(w) -> void:
	if w.tier >= 3:                                              # Static Step: a charged spark at the start; 1 s later what is near is charged
		var o: Vector2 = w._st.dash_from
		w.fx("streak", o, STORM, {"dir": w.aim, "length": 42.0, "width": 5.0, "life": 0.25, "col2": WHITE})
		w.fx("orbit", o, STORM, {"radius": 8.0, "count": 4, "spin": 6.0, "shape": "star", "life": 1.5})
		w._st.static_pos = o
		w._st.static_at = _now() + SB2_STATIC_T
	Wb.dash(w)

## Storm Warp arrival: bolts fall in the ring, the charges near the destination go off, and (tier 4) the line between gates shocks what it crosses.
static func warped(w, dest: Vector2) -> void:
	for i in 6:
		var p: Vector2 = dest + Vector2.from_angle(float(i) * TAU / 6.0) * 40.0
		w.fx("bolt", p + Vector2(0, -70), STORM, {"dir": Vector2(0, 1), "length": 70.0, "width": 2.5, "life": 0.35})
	var n := detonate(w, dest, SB2_DETONATE_R)
	if n > 0:
		w.player.shake(3.0, 0.2)
	if w.tier >= 4:
		var from = Wb._newest(w, Wb.K_BACK)
		if from != null:
			for e in Kit.near_segment(w.get_tree(), from.pos, dest, 8.0):
				WeaponUtil.hit(e, H(w) * 0.5, dest, 40.0, 0.0, "", true, true)
				add_charge(e, 1)
			Kit.bolt(w, from.pos, dest, WHITE, 2.0, 0.3)

# ---------- attack ----------

static func attack(w) -> void:
	Wb.attack(w)
	var st: Dictionary = w._st
	st.rift_flag = -10.0                                         # (the Warp Bow's rift arrow is not this weapon's finisher)
	if w.tier >= 6 and int(st.shots) % SB2_FINISHER_EVERY == 0:
		st.fin_next = int(st.shots)
		_lightning_arrow(w)

## Finisher: the arrow that lands forks to five targets within 90 px (0.6 H, +2 charges each).
static func _lightning_arrow(w) -> void:
	if !await WeaponTiers.pause(w, 0.35):
		return
	var tgt = WeaponUtil.nearest(w.get_tree(), w.player.global_position + w.aim * 80.0, 120.0)
	if tgt == null:
		return
	var at: Vector2 = tgt.global_position
	w.fx("flash", at, STORM, {"radius": 20.0, "life": 0.3})
	var hit := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 90.0):
		if hit >= 5:
			break
		hit += 1
		Kit.bolt(w, at, e.global_position, WHITE, 1.5, 0.3)
		WeaponUtil.hit(e, H(w) * 0.6, at, 20.0, 0.0, "", true, true)
		add_charge(e, 2)
	Sfx.play("big_hit", 0.1, 1.4)

# ---------- tick ----------

static func tick(w, delta: float) -> void:
	Wb.tick(w, delta)
	var st: Dictionary = w._st
	var now := _now()
	var tree: SceneTree = w.get_tree()
	var pid: int = w.player.get_instance_id()
	# charge motes over charged enemies, storm-blue arrows, lightning arrows in the Archer window
	if now >= float(st.get("mote_next", 0.0)):
		st.mote_next = now + 0.5
		var shown := 0
		for e in tree.get_nodes_in_group("enemy"):
			if shown >= 8:
				break
			var c := charges(e)
			if c > 0 and e.global_position.distance_to(w.player.global_position) < 260.0:
				shown += 1
				w.fx("star", e.global_position + Vector2(0, -12), STORM, {"radius": 4.0, "count": c + 1, "spin": 1.0, "life": 0.55})
	for n in tree.get_nodes_in_group("net"):
		if n is WeaponProjectile and n.owner_id == pid and n._age < 0.08:
			n.color = STORM if n.pierce < 3 else n.color
			n.glow = 0.4
			n.trail = 5
			if archer(w) and n.chain == 0:
				n.chain = 3
	# Static Step ripens
	if float(st.static_at) > 0.0 and now >= float(st.static_at):
		st.static_at = 0.0
		var sp: Vector2 = st.static_pos
		w.fx("burst", sp, STORM, {"radius": 22.0, "life": 0.3})
		for e2 in WeaponUtil.enemies_in_circle(tree, sp, 30.0):
			WeaponUtil.hit(e2, H(w) * 0.5, sp, 20.0, 0.0, "", true, true)
			add_charge(e2, 1)
	# Storm Gate: a live line between gates
	if w.tier >= 4 and now >= float(st.line_next):
		st.line_next = now + 0.4
		_gate_lines(w, now)
	# Thunderhead
	if now < float(st.cloud_until):
		_cloud(w, now)
	# Tempest Archer: a bolt on a random enemy every 0.5 s
	if archer(w) and now >= float(st.bolt_next):
		st.bolt_next = now + SB2_BOLT_EVERY
		var c: Array = WeaponUtil.random_enemies(tree, w.player.global_position, 140.0, 1)
		if !c.is_empty():
			var e3 = c[0]
			w.fx("bolt", e3.global_position + Vector2(0, -60), STORM, {"dir": Vector2(0, 1), "length": 60.0, "width": 2.5, "life": 0.3})
			WeaponUtil.hit(e3, H(w) * SB2_BOLT_MULT, e3.global_position, 20.0, 0.0, "", true, true)
			add_charge(e3, 1)

static func _gate_lines(w, now: float) -> void:
	var st: Dictionary = w._st
	var pts := []
	for g in st.gates:
		if int(g.kind) == Wb.K_ANCHOR:
			pts.append(g.pos)
	if pts.size() < 2:
		return
	var segs := []
	for i in pts.size() - 1:
		segs.append([pts[i], pts[i + 1]])
	if pts.size() >= 3:
		segs.append([pts[pts.size() - 1], pts[0]])                 # three gates: the triangle is live
	var tick_dmg: bool = now - float(st.get("line_dmg", 0.0)) >= SB2_LINE_TICK - 0.01
	if tick_dmg:
		st.line_dmg = now
	for s in segs:
		Kit.bolt(w, s[0], s[1], STORM, 1.5, 0.35)
		if tick_dmg:
			for e in Kit.near_segment(w.get_tree(), s[0], s[1], 6.0):
				WeaponUtil.hit(e, H(w) * SB2_LINE_MULT, s[0], 0.0, 0.0, "", true, true)
				add_charge(e, 1)

static func _cloud(w, now: float) -> void:
	var st: Dictionary = w._st
	var c: Vector2 = st.cloud_c
	var tree: SceneTree = w.get_tree()
	if now >= float(st.cloud_sigil):
		st.cloud_sigil = now + 0.8
		w.fx("sigil", c, CLOUD, {"radius": 120.0, "count": 10, "spin": 0.8, "life": 0.9, "col2": STORM})
		w.fx("motes", c, STORM, {"radius": 110.0, "count": 12, "rise": -20.0, "life": 0.7})
	if now >= float(st.cloud_next):
		st.cloud_next = now + SB2_CLOUD_EVERY
		var pool := []
		for e in WeaponUtil.enemies_in_circle(tree, c, 120.0):
			if charges(e) > 0:
				pool.append(e)
		if !pool.is_empty():
			var e2 = pool[randi() % pool.size()]
			var p: Vector2 = e2.global_position
			w.fx("bolt", p + Vector2(0, -70), STORM, {"dir": Vector2(0, 1), "length": 70.0, "width": 3.0, "life": 0.3})
			w.ground_strike(p, 14.0, 0.05, H(w) * SB2_CLOUD_MULT, 80.0, STORM, 0.0)
			add_charge(e2, 1)
	if now >= float(st.cloud_gate):                               # gates in the area fire a piercing arrow at the nearest charged enemy
		st.cloud_gate = now + 1.5
		for g in st.gates:
			if g.pos.distance_to(c) > 140.0:
				continue
			var best = null
			var bd := 1.0e9
			for e3 in WeaponUtil.enemies_in_circle(tree, g.pos, 200.0):
				if charges(e3) > 0 and e3.global_position.distance_to(g.pos) < bd:
					bd = e3.global_position.distance_to(g.pos)
					best = e3
			if best != null and WeaponProjectile.alive(tree) < 40:
				var d: Vector2 = (best.global_position - g.pos).normalized()
				WeaponProjectile.shoot(w.game_world(), g.pos + d * 6.0, d, 340.0, H(w) * 0.8, STORM, 0.8, 2, 40.0, {"style": "arrow", "glow": 0.4, "trail": 5, "owner_id": w.player.get_instance_id(), "gated": true})

# ---------- ultimate: Thunder Volley -> Thunderhead -> Tempest Archer -> the Judgement ----------

static func ultimate(w) -> void:
	var st: Dictionary = w._st
	st.ult_id = int(st.ult_id) + 1
	var my: int = st.ult_id
	var c: Vector2 = w.cursor_target(130.0)
	w.fx("sigil", w.player.global_position + w.aim * 12.0, STORM, {"radius": 40.0, "count": 6, "spin": 1.5, "life": 0.3, "col2": WHITE})
	if w.tier >= 5:
		_stage2(w, c, my)

static func _stage2(w, c: Vector2, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 4.4):
		return
	if int(st.ult_id) != my:
		return
	var now := _now()
	st.cloud_until = now + SB2_CLOUD_SECS
	st.cloud_c = c
	st.cloud_next = now
	st.cloud_sigil = now
	st.cloud_gate = now + 0.5
	w.player.shake(4.0, 0.3)
	Sfx.play("ultimate", 0.02, 1.1)
	if w.tier >= 6:
		_archer(w, c, my)

static func _archer(w, c: Vector2, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 0.6):                          # (5.0 s after the press)
		return
	if int(st.ult_id) != my:
		return
	var now := _now()
	st.archer_until = now + SB2_ARCHER_SECS
	st.storm_until = now + SB2_ARCHER_SECS                         # the ring of six gates copies every arrow at 40%
	st.storm_next = now + 0.5
	st.bolt_next = now
	w.fx("shock", w.player.global_position, STORM, {"radius": 110.0, "thick": 6.0, "life": 0.5, "col2": WHITE})
	w.player.shake(5.0, 0.3)
	if !await WeaponTiers.pause(w, SB2_ARCHER_SECS):
		return
	if int(st.ult_id) != my:
		return
	st.archer_until = 0.0
	st.storm_until = 0.0
	w.fx("sigil", c, STORM, {"radius": 90.0, "count": 8, "spin": 2.0, "life": 0.5, "col2": WHITE})
	if !await WeaponTiers.pause(w, 0.5):
		return
	_judgement(w, c)

## FINALE: one colossal bolt on the cursor, 2.5 H within 90 px with a stun, and every charge within 160 px goes off.
static func _judgement(w, c: Vector2) -> void:
	w.fx("bolt", c + Vector2(0, -160), WHITE, {"dir": Vector2(0, 1), "length": 160.0, "width": 14.0, "life": 0.5})
	w.fx("flash", c, STORM, {"radius": 90.0, "life": 0.5})
	w.fx("pillar", c, STORM, {"height": 170.0, "width": 40.0, "life": 0.7})
	w.fx("ripple", c, STORM, {"radius": 140.0, "rings": 4, "life": 0.9})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 90.0):
		WeaponUtil.hit(e, H(w) * SB2_JUDGE_MULT, c, 120.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.2)
	detonate(w, c, 160.0)
	w.player.shake(8.0, 0.5)
	Sfx.play("ultimate", 0.02)
	Sfx.play("big_hit", 0.05)

# ---------- aura: the Warp Bow's gates, now crackling, and the lightning crown ----------

static func aura(a, c) -> void:
	Wb.aura(a, c)
	var d: Dictionary = a.data
	for g in d.get("g", []):                                       # crackling edges: a short jagged bolt on every gate
		var p: Vector2 = c.to_local(g)
		var since := fposmod(a._age, 0.4)
		if since < 0.15:
			var sd: int = int(floor(a._age / 0.4))
			var base: float = WeaponAura.jit(sd + int(g.x), 3.0) * TAU
			var pts := PackedVector2Array([p + Vector2(0, -9)])
			for i in range(1, 4):
				pts.append(p + Vector2(0, -9) + Vector2.from_angle(base) * float(i) * 3.0)
			c.draw_polyline(pts, Color(WHITE, 0.9), 1.0)
	if a.tier >= 6:                                                # a faint lightning crown above the head
		for k in 5:
			var x: float = float(k - 2) * 3.0
			var top: float = -17.0 - (3.0 if k % 2 == 0 else 0.0)
			c.draw_line(Vector2(x, -14.0), Vector2(x + 1.0, top), Color(STORM, 0.55), 1.0)
