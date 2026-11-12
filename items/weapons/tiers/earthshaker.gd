extends RefCounted
## Earthshaker tiers (docs/weapon_tiers/earthshaker.md), Mythic, fusion tier 3: 3 Fault Lines, 4 Tremor, 5 Tectonic Shift, 6 World Shaker.
## THE SYSTEM: Fault Lines. Every eruption of the Triple Fissure, the Burrow and the Cataclysm, and every third swing, leaves a FAULT: a dark
## glowing crack that slows enemies (a `Hazard`, kind slow, harmless to players, 14 alive at most, the oldest goes first). The finisher and the
## ultimate trigger an AFTERSHOCK: every fault erupts (r 16, 0.5 H) and is spent. Hooks run after the old Quake Pick verbs of t3/earthshaker.gd.
## Hook functions never suspend themselves (they are called through callv): waits live in the helper coroutines below.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const BED := Color(0.55, 0.40, 0.25)
const GLOW := Color(1.0, 0.60, 0.20)
const DUST := Color(0.88, 0.76, 0.55)
const DEEP := Color(0.20, 0.12, 0.08)
const BREAK := ["stone", "stick"]
const ES_FAULT_MAX := 14
const ES_FAULT_SECS := 8.0
const ES_FAULT_SLOW := 0.7
const ES_AFTERSHOCK_MULT := 0.5
const ES_TREMOR_MULT := 0.4
const ES_RETURN_MULT := 0.4
const ES_SHIFT_PULL := 180.0
const ES_SHIFT_N := 12
const ES_SHAKER_SECS := 8.0
const ES_SHAKER_STEP := 0.5
const ES_PILLAR_EVERY := 2.0
const ES_PILLAR_MULT := 1.0
const ES_FINALE_MULT := 2.0
const ES_FINISHER_EVERY := 6
const ES_SPIKE_EVERY := 3
const NAMES := ["", "Earthshaker", "", "Fault Lines", "Tremor", "Tectonic Shift", "World Shaker"]

static func palette() -> Array:
	return [BED, GLOW, DUST]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func H(w) -> float:
	return WeaponTiers.H(w)

static func equip(w) -> void:
	w._st = {"swings": 0, "last_ms": -1000, "faults": [], "ult_id": 0, "shaker_until": 0.0, "step_next": 0.0, "auto_next": 0.0, "pillar_next": 0.0}

# ---------- faults ----------

static func _live(w) -> Array:
	var f: Array = w._st.faults
	for i in range(f.size() - 1, -1, -1):
		if !is_instance_valid(f[i].node) or f[i].node.is_queued_for_deletion():
			f.remove_at(i)
	return f

static func fault_count(w) -> int:
	return _live(w).size()

static func add_fault(w, pos: Vector2) -> void:
	var f: Array = _live(w)
	while f.size() >= ES_FAULT_MAX:
		var old = f.pop_front()
		if is_instance_valid(old.node):
			old.node.queue_free()
	var h := Hazard.new()
	h.kind = "slow"
	h.radius = 12.0
	h.color = Color(0.30, 0.20, 0.10, 0.6)
	h.factor = ES_FAULT_SLOW
	h.lifetime = ES_FAULT_SECS
	h.position = pos
	w.game_world().add_child(h)
	f.append({"pos": pos, "node": h, "last": -10.0})
	w.fx("crack", pos, GLOW, {"radius": 11.0, "count": 3, "life": 0.8})

static func _fault_later(w, pos: Vector2, delay: float) -> void:
	if !await WeaponTiers.pause(w, delay):
		return
	add_fault(w, pos)

## Aftershock: the faults within `radius` of `center` erupt (r 16, 0.25 s warning, 0.5 H). `consume`: they are spent; World Shaker only refreshes them.
static func aftershock(w, center: Vector2, radius: float, consume := true) -> int:
	var n := 0
	var now := _now()
	for f in _live(w).duplicate():
		if f.pos.distance_to(center) > radius:
			continue
		if !consume and now - float(f.last) < 2.0:
			continue
		n += 1
		f.last = now
		w.ground_strike(f.pos, 16.0, 0.25, H(w) * ES_AFTERSHOCK_MULT, 160.0, GLOW, 0.0, BREAK)
		w.fx("crack", f.pos, GLOW, {"radius": 16.0, "count": 3, "life": 0.5})
		if consume:
			if is_instance_valid(f.node):
				f.node.queue_free()
			w._st.faults.erase(f)
	return n

# ---------- attack ----------

static func attack(w) -> void:
	var st: Dictionary = w._st
	var ms := Time.get_ticks_msec()
	if ms - int(st.last_ms) < 250:
		return
	st.last_ms = ms
	st.swings = int(st.swings) + 1
	_swing(w, int(st.swings))

static func _swing(w, n: int) -> void:
	if !await WeaponTiers.pause(w, 0.18):
		return
	var o: Vector2 = w.player.global_position
	var d: Vector2 = w.aim
	w.fx("shards", o + d * 24.0, DUST, {"radius": 20.0, "count": 5, "life": 0.3})
	if w.tier >= 4:                                     # Tremor: a ripple runs forward, two extra hits
		w.fx("crack", o + d * 10.0, BED, {"radius": 40.0, "count": 3, "life": 0.5})
		for r in [30.0, 48.0]:
			w.ground_strike(o + d * r, 14.0, 0.15, H(w) * ES_TREMOR_MULT, 100.0, BED, 0.0, BREAK)
	if w.tier >= 6 and n % ES_FINISHER_EVERY == 0:      # World Shaker finisher: an aftershock and a forward shock
		aftershock(w, o, 9999.0)
		var at: Vector2 = o + d * 30.0
		w.fx("shock", at, GLOW, {"radius": 50.0, "thick": 6.0, "life": 0.35, "col2": DUST})
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 50.0):
			WeaponUtil.hit(e, H(w) * 0.8, o, 260.0, 0.0, "", true)
		w.player.shake(3.0, 0.2)
		Sfx.play("thump", 0.1)
	elif n % ES_SPIKE_EVERY == 0:                        # Fault Lines: every third swing a stone spike erupts ahead and leaves a fault
		var sp: Vector2 = o + d * 40.0
		w.fx("crack", sp, GLOW, {"radius": 14.0, "count": 4, "life": 0.5})
		w.ground_strike(sp, 14.0, 0.3, H(w), 220.0, BED, 0.0, BREAK)
		_fault_later(w, sp, 0.3)

# ---------- ability: Triple Fissure ----------

static func ability(w) -> void:
	var o: Vector2 = w.player.global_position
	var aim: Vector2 = w.aim
	for off in [-0.35, 0.0, 0.35]:
		var d: Vector2 = aim.rotated(off)
		var side: Vector2 = d.orthogonal()
		for i in 5:
			var c: Vector2 = o + d * (22.0 + 18.0 * float(i))
			_fault_later(w, c, 0.4 + 0.1 * float(i))
			w.fx("crack", c, GLOW, {"radius": 20.0, "count": 3, "life": 0.6 + 0.1 * float(i)})
			if i == 1 or i == 3:                         # Branching: strikes 2 and 4 of each line fork
				for s in [-1.0, 1.0]:
					var fp: Vector2 = c + side * 24.0 * s
					w.ground_strike(fp, 12.0, 0.45 + 0.1 * float(i), H(w) * ES_TREMOR_MULT, 120.0, BED, 0.0, BREAK)
	if w.tier >= 4:
		_return_wave(w, o, aim)

## Tremor: 0.7 s after the last eruption a second wave runs back along each line, shoving along it.
static func _return_wave(w, o: Vector2, aim: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.8 + 0.7):
		return
	var h := H(w) * ES_RETURN_MULT
	for i in range(4, -1, -1):
		for off in [-0.35, 0.0, 0.35]:
			var d: Vector2 = aim.rotated(off)
			var c: Vector2 = o + d * (22.0 + 18.0 * float(i))
			w.fx("crack", c, GLOW, {"radius": 18.0, "count": 3, "life": 0.5})
			w.fx("ring", c, BED, {"radius": 18.0, "life": 0.25})
			for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 18.0):
				WeaponUtil.hit(e, h, c, 0.0, 0.0, "", true)
				if is_instance_valid(e) and e.has_method("push"):
					e.push(d * 160.0, 0.15)
		if !await WeaponTiers.pause(w, 0.07):
			return
	Sfx.play("thump", 0.1)

# ---------- dash: Burrow ----------

static func dash(w) -> void:
	var o: Vector2 = w.player.global_position
	var d: Vector2 = w.aim
	for k in 3:                                          # Fault Burrow: a trail of three faults (and small eruptions) along the path
		var p: Vector2 = o + d * (20.0 * float(k + 1))
		_fault_later(w, p, 0.1 + 0.05 * float(k))
		w.ground_strike(p, 14.0, 0.3 + 0.05 * float(k), H(w) * 0.5, 120.0, BED, 0.0, BREAK)
	if w.tier >= 4:
		w.fx("streak", o, DEEP, {"dir": d, "length": 70.0, "width": 10.0, "life": 0.3, "col2": GLOW})
		_arrival(w)

static func _arrival(w) -> void:
	if !await WeaponTiers.pause(w, 0.22):
		return
	var p: Vector2 = w.player.global_position
	w.fx("shock", p, GLOW, {"radius": 40.0, "thick": 5.0, "life": 0.3, "col2": DUST})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), p, 40.0):
		WeaponUtil.hit(e, H(w), p, 160.0, 0.8, "", true)
	aftershock(w, p, 60.0)                               # arriving erupts the faults close by
	w.player.shake(3.0, 0.2)

# ---------- tick: World Shaker ----------

static func shaker(w) -> bool:
	return float(w._st.get("shaker_until", 0.0)) > _now()

static func tick(w, _delta: float) -> void:
	if !shaker(w):
		return
	var st: Dictionary = w._st
	var now := _now()
	if now >= float(st.step_next) and w.player.velocity.length() > 8.0:
		st.step_next = now + ES_SHAKER_STEP
		add_fault(w, w.player.global_position)
	if now >= float(st.auto_next):
		st.auto_next = now + 1.0
		aftershock(w, w.player.global_position, 120.0, false)
	if now >= float(st.pillar_next):
		st.pillar_next = now + ES_PILLAR_EVERY
		var c: Vector2 = w.cursor_target(110.0)
		w.fx("pillar", c, GLOW, {"height": 90.0, "width": 24.0, "life": 0.6})
		w.ground_strike(c, 34.0, 0.5, H(w) * ES_PILLAR_MULT, 200.0, GLOW, 0.6, BREAK)
		w.player.shake(2.0, 0.15)

# ---------- ultimate: Cataclysm -> Tectonic Shift -> World Shaker ----------

static func ultimate(w) -> void:
	var st: Dictionary = w._st
	st.ult_id = int(st.ult_id) + 1
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, GLOW, {"radius": 90.0, "count": 12, "spin": 1.5, "life": 0.3, "col2": DUST})
	for ring in 3:                                       # each strike of the old rings leaves a fault
		for i in 6:
			_fault_later(w, o + Vector2.from_angle(float(i) * TAU / 6.0 + float(ring) * 0.5) * (30.0 + 30.0 * float(ring)), 0.3 + float(ring) * 0.35)
	if w.tier >= 5:
		_shift(w, int(st.ult_id))

static func _shift(w, my: int) -> void:
	var st: Dictionary = w._st
	if !await WeaponTiers.pause(w, 1.6):
		return
	if int(st.ult_id) != my:
		return
	var o: Vector2 = w.player.global_position
	w.fx("crack", o, GLOW, {"radius": 110.0, "count": ES_SHIFT_N, "life": 1.8})
	w.fx("motes", o, DUST, {"radius": 100.0, "count": 16, "rise": 20.0, "life": 1.2})
	w.player.shake(3.0, 0.3)
	Sfx.play("thump", 0.05, 0.8)
	for k in 4:                                          # the ground drags the crowd in
		for e in WeaponUtil.enemies_in_circle(w.get_tree(), w.player.global_position, 110.0):
			Kit.pull(e, w.player.global_position, ES_SHIFT_PULL, 0.4)
		w.fx("vortex", w.player.global_position, BED, {"radius": 100.0, "count": 4, "spin": 2.0, "inward": true, "life": 0.4})
		if !await WeaponTiers.pause(w, 0.4):
			return
	if int(st.ult_id) != my:
		return
	o = w.player.global_position
	aftershock(w, o, 9999.0)                             # every fault erupts, then a ring of twelve
	for i in ES_SHIFT_N:
		w.ground_strike(o + Vector2.from_angle(float(i) * TAU / float(ES_SHIFT_N)) * 110.0, 20.0, 0.45, H(w) * 0.5, 180.0, GLOW, 0.4, BREAK)
	if w.tier >= 6:
		_shaker(w, my)

static func _shaker(w, my: int) -> void:
	var st: Dictionary = w._st
	st.shaker_until = _now() + ES_SHAKER_SECS
	st.step_next = 0.0
	st.auto_next = _now() + 0.5
	st.pillar_next = _now() + 0.8
	w.fx("shock", w.player.global_position, GLOW, {"radius": 60.0, "thick": 7.0, "life": 0.5, "col2": DUST})
	w.player.shake(5.0, 0.3)
	if !await WeaponTiers.pause(w, ES_SHAKER_SECS):
		return
	if int(st.ult_id) != my:
		return
	st.shaker_until = 0.0
	var o: Vector2 = w.player.global_position
	w.fx("sigil", o, GLOW, {"radius": 100.0, "count": 12, "spin": 2.0, "life": 0.5, "col2": DUST})
	if !await WeaponTiers.pause(w, 0.5):
		return
	o = w.player.global_position
	w.fx("flash", o, DUST, {"radius": 100.0, "life": 0.45})
	w.fx("shock", o, GLOW, {"radius": 120.0, "thick": 10.0, "life": 0.55, "col2": DUST})
	w.fx("crack", o, DEEP, {"radius": 120.0, "count": 16, "life": 1.0})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 120.0):
		WeaponUtil.hit(e, H(w) * ES_FINALE_MULT, o, 440.0, 0.0, "", true)
		WeaponUtil.stun(e, 1.2)
	WeaponUtil.hit_breakables(w.get_tree(), o, 120.0, BREAK)
	w.player.shake(7.0, 0.5)
	Sfx.play("thump", 0.02)
	Sfx.play("ultimate", 0.02, 0.8)
