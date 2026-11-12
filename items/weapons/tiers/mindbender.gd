extends RefCounted
## Mindbender tiers (docs/weapon_tiers/mindbender.md), LEGENDARY: 2 Thralls, 3 Banner, 4 Puppeteer, 5 Lieutenants, 6 Sovereign.
## THE SYSTEM: Will, an army. Every bolt that lands adds a Will stack (`wt_will`, 3 at most, 4 s); the third makes the enemy a THRALL for a few
## seconds (a boss is only dazed). Converts are tracked by the meta `wt_owner` (the player's instance id) and the higher tiers act on the army as a
## whole: banners to rally to, a command, lieutenants, spreading conversion, a war cry, honour guards, a thought storm and a rebellion.
## Enemy fields used: charm(time, power, blast), charm_power, charm_blast, rally_point (all exist). Nothing here hurts a player.
## Hook functions never suspend (they run through callv): waits live in helper coroutines.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const MIND := Color(0.55, 0.90, 1.0)
const VIOLET := Color(0.55, 0.40, 0.95)
const GOLD := Color(1.0, 0.85, 0.40)
const WHITE := Color(0.95, 0.98, 1.0)
const ROSE := Color(1.0, 0.50, 0.70)
const MB_WILL_MAX := 3
const MB_WILL_SECS := 4.0
const MB_THRALL_SECS := [0, 5, 5, 8, 8, 8]
const MB_POWER := [1.0, 1.3, 1.3, 1.3, 1.3, 1.3]
const MB_BANNER_SECS := 12.0
const MB_COMMAND_WINDOW := 3.0
const MB_SURGE := 2.0
const MB_SURGE_SECS := 3.0
const MB_LIEUTENANTS := 3
const MB_LIEUT_POWER := 2.5
const MB_LIEUT_HEALTH_CAP := 400.0
const MB_SPREAD_MAX := 12
const MB_SPREAD_R := 60.0
const MB_ARMY_CAP := 40
const MB_GUARDS := 5
const MB_SOVEREIGN_SECS := 15.0
const MB_STORM_EVERY := 2.0
const MB_STORM_BOLTS := 8
const MB_STORM_MULT := 0.6
const MB_REBELLION_BLAST := 1.0
const MB_WARCRY_EVERY := 5.0
const MB_FINISHER_EVERY := 6
const NAMES := ["", "Mindbender", "Thralls", "Banner", "Puppeteer", "Lieutenants", "Sovereign"]

static func palette() -> Array:
	return [MIND, VIOLET, WHITE]

static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func H(w) -> float:
	return WeaponTiers.H(w)

static func equip(w) -> void:
	w._st = {"shots": 0, "blast_pending": false, "banners": [], "gates": [], "command_until": 0.0, "ult_id": 0, "mark_next": 0.0, "army_next": 0.0,
		"spread_until": 0.0, "spread_left": 0, "spread_next": 0.0, "warcry_until": 0.0, "warcry_next": 0.0, "storm_until": 0.0, "storm_next": 0.0, "storm_c": Vector2.ZERO,
		"cmd_target": Vector2.INF, "pub": "", "dash_from": Vector2.ZERO, "thrall_n": 0}

# ---------- army ----------

static func _alive(e) -> bool:
	return is_instance_valid(e) and !e.is_queued_for_deletion()

static func convertible(e) -> bool:
	return _alive(e) and e.has_method("charm") and !e.is_in_group("boss")

static func is_conv(e) -> bool:
	return _alive(e) and e.get("charm_time") != null and e.charm_time > 0.0

static func army(w) -> Array:
	var out := []
	var pid: int = w.player.get_instance_id()
	for e in w.get_tree().get_nodes_in_group("enemy"):
		if is_conv(e) and e.has_meta("wt_owner") and int(e.get_meta("wt_owner")) == pid:
			out.append(e)
	return out

## Converts an enemy for the weapon (power, healing and the heartbreak blast by tier); false when it cannot be (boss, already ours, army full).
static func conv(w, e, secs: float, power_mult := 1.0, blast := 0.0) -> bool:
	if !convertible(e) or is_conv(e):
		return false
	if army(w).size() >= MB_ARMY_CAP:
		return false
	var pw: float = float(MB_POWER[clampi(w.tier - 1, 0, 5)]) * power_mult
	var bl := blast
	if w.tier >= 6 and bl <= 0.0:
		bl = H(w) * 0.5 * WeaponUtil.power
	e.charm(secs, pw, bl)
	e.set_meta("wt_owner", w.player.get_instance_id())
	e.set_meta("wt_base_power", pw)
	if w.tier >= 2:
		e.health = e.max_health
	return true

# ---------- Will ----------

static func will_of(e) -> int:
	if !is_instance_valid(e) or !e.has_meta("wt_will"):
		return 0
	var m: Dictionary = e.get_meta("wt_will")
	return int(m.n) if float(m.until) > _now() else 0

static func add_will(w, e, n: int) -> void:
	if !_alive(e) or is_conv(e):
		return
	var total: int = will_of(e) + n
	if total >= MB_WILL_MAX:
		e.remove_meta("wt_will")
		if convertible(e):
			var secs: float = float(MB_THRALL_SECS[clampi(w.tier - 1, 0, 5)])
			if conv(w, e, secs):
				w.fx("flash", e.global_position, MIND, {"radius": 14.0, "life": 0.3})
				w.fx("ripple", e.global_position, MIND, {"radius": 24.0, "rings": 2, "life": 0.4})
				if w.tier >= 3:
					_banner_at(w, e.global_position, 5.0, true)
				return
		elif e.has_method("apply_slow"):
			e.apply_slow(0.8, 1.0)                              # a boss is only dazed
			w.fx("burst", e.global_position, VIOLET, {"radius": 10.0, "life": 0.25})
		return
	e.set_meta("wt_will", {"n": total, "until": _now() + MB_WILL_SECS})

# ---------- attack ----------

## Called from mindbender.gd attack(): extras of the bolt, null at tier 1.
static func bolt_extra(w):
	if w.tier < 2:
		return null
	var st: Dictionary = w._st
	st.shots = int(st.shots) + 1
	if w.tier >= 6 and int(st.shots) % MB_FINISHER_EVERY == 0:
		st.blast_pending = true
	return {"style": "orb", "size": 1.2, "wobble": 2.0, "trail": 4, "glow": 0.2, "owner_id": w.player.get_instance_id()}

static func on_hit(w, e: Node, dmg: float) -> void:
	if w.tier < 2 or !_alive(e):
		return
	add_will(w, e, 1)
	if w.tier >= 4:                                             # Puppeteer: the bolt chains to two more, each adding Will
		var done: Array = [e]
		var cur = e
		for i in 2:
			var nxt = null
			for o in w.get_tree().get_nodes_in_group("enemy"):
				if _alive(o) and !is_conv(o) and !(o in done) and o.global_position.distance_to(cur.global_position) <= 55.0:
					if nxt == null or o.global_position.distance_to(cur.global_position) < nxt.global_position.distance_to(cur.global_position):
						nxt = o
			if nxt == null:
				break
			Kit.bolt(w, cur.global_position, nxt.global_position, MIND)
			WeaponUtil.hit(nxt, dmg * 0.6, cur.global_position, 20.0, 0.0, "", true, true)
			add_will(w, nxt, 1)
			done.append(nxt)
			cur = nxt
	if w.tier >= 6 and bool(w._st.blast_pending) and _alive(e):   # Sovereign: a mind blast, the target is converted outright
		w._st.blast_pending = false
		var at: Vector2 = e.global_position
		w.fx("ripple", at, MIND, {"radius": 60.0, "rings": 2, "life": 0.5})
		for o2 in WeaponUtil.enemies_in_circle(w.get_tree(), at, 60.0):
			if o2 != e and !is_conv(o2):
				WeaponUtil.hit(o2, H(w) * 0.5, at, 40.0, 0.0, "", true, true)
				add_will(w, o2, 1)
		if conv(w, e, float(MB_THRALL_SECS[5])):
			w.fx("flash", at, MIND, {"radius": 16.0, "life": 0.3})

static func attack(w) -> void:
	if w.tier >= 2:
		w.fx("burst", w.player.global_position + w.aim * 12.0, MIND, {"radius": 7.0, "life": 0.2})

# ---------- ability: Turncoat ----------

static func ring_r(w):
	if w.tier >= 3:
		return 55.0
	return null

## Called right after Turncoat starts (the old function converts after 0.3 s): the rest of the rider.
static func ability(w) -> void:
	if w.tier < 2:
		return
	var c: Vector2 = w.cursor_target(110.0)
	var r: float = 55.0 if w.tier >= 3 else 45.0
	w.fx("ripple", c, MIND, {"radius": r, "rings": 2, "life": 0.6})
	w.fx("motes", c, MIND, {"radius": r, "count": 10, "rise": 24.0, "life": 0.8})
	_after_ring(w, c, r)

static func _after_ring(w, c: Vector2, r: float) -> void:
	if !await WeaponTiers.pause(w, 0.4):
		return
	var mine: Array = []
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, r + 4.0):
		if is_conv(e):
			mine.append(e)
			e.set_meta("wt_owner", w.player.get_instance_id())
	if w.tier >= 3:
		_banner_at(w, c, MB_BANNER_SECS, false)
		w.fx("sigil", c, MIND, {"radius": 20.0, "count": 3, "spin": 1.0, "life": 0.6, "col2": WHITE})
	if w.tier >= 4:
		w._st.command_until = _now() + MB_COMMAND_WINDOW
	if w.tier >= 5:
		_promote(w)
	if w.tier >= 6:                                             # Sovereign Turncoat: every convert converts one neighbour a second later
		_neighbours(w, mine)

static func _neighbours(w, mine: Array) -> void:
	if !await WeaponTiers.pause(w, 1.0):
		return
	var n := 0
	for e in mine:
		if n >= 6 or !is_conv(e):
			continue
		for o in WeaponUtil.enemies_in_circle(w.get_tree(), e.global_position, 40.0):
			if o != e and convertible(o) and !is_conv(o):
				if conv(w, o, maxf(1.0, float(e.charm_time))):
					n += 1
					Kit.bolt(w, e.global_position, o.global_position, MIND)
					break

## True while the second right click of Puppeteer is open.
static func command_ready(w) -> bool:
	return w.tier >= 4 and float(w._st.command_until) > _now()

static func command(w) -> void:
	var st: Dictionary = w._st
	st.command_until = 0.0
	var tgt: Vector2 = w.player.aim_point()
	var n := 0
	for e in army(w):
		if e.global_position.distance_to(w.player.global_position) <= 220.0:
			n += 1
			e.charm_power = maxf(e.charm_power, MB_SURGE)
			e.set_meta("wt_surge_until", _now() + MB_SURGE_SECS)
			e.rally_point = tgt
	st.cmd_target = tgt
	st.cmd_until = _now() + MB_SURGE_SECS
	w.fx("star", tgt, GOLD, {"radius": 14.0, "count": 6, "spin": 1.0, "life": 0.5})
	w.fx("ripple", tgt, MIND, {"radius": 30.0, "rings": 2, "life": 0.5})
	Sfx.play("boss_roar", 0.05, 1.3)

# ---------- banners ----------

static func _banner_at(w, pos: Vector2, secs: float, quiet: bool) -> void:
	var b: Array = w._st.banners
	while b.size() >= 4:
		b.pop_front()
	b.append({"pos": pos, "until": _now() + secs})
	if !quiet:
		Sfx.play("unlock", 0.05, 0.9)

# ---------- dash: Mind Step ----------

static func pre_dash(w) -> void:
	w._st.dash_from = w.player.global_position

static func dash(w) -> void:
	if w.tier < 2:
		return
	var o: Vector2 = w._st.get("dash_from", w.player.global_position)
	var d: Vector2 = w.aim
	w.fx("streak", o, MIND, {"dir": d, "length": 60.0, "width": 6.0, "life": 0.3, "col2": WHITE})
	if w.tier >= 4:
		Kit.bolt(w, o, o + d * 60.0, MIND)
		w._st.gates.append({"pos": o, "until": _now() + 2.5})
		while w._st.gates.size() > 2:
			w._st.gates.pop_front()
		w.fx("ring", o, VIOLET, {"radius": 26.0, "life": 0.4})
	_thrall_step(w, o + d * 30.0)

static func _thrall_step(w, mid: Vector2) -> void:
	if !await WeaponTiers.pause(w, 0.05):
		return
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), mid, 34.0):
		if is_conv(e):
			e.set_meta("wt_owner", w.player.get_instance_id())
			e.charm(5.0, 1.0, 0.0)
		elif !convertible(e):
			WeaponUtil.hit(e, H(w) * 1.0, mid, 40.0, 0.0, "", true, true)      # a boss is hit instead

# ---------- tick ----------

static func tick(w, _delta: float) -> void:
	if w.tier < 2:
		return
	var st: Dictionary = w._st
	var now := _now()
	var tree: SceneTree = w.get_tree()
	var pid: int = w.player.get_instance_id()
	if now >= float(st.mark_next):                              # the Will stacks as cyan stars (eight enemies at most)
		st.mark_next = now + 0.5
		var seen := 0
		for e in tree.get_nodes_in_group("enemy"):
			if seen >= 8:
				break
			var n := will_of(e)
			if n > 0:
				seen += 1
				w.fx("star", e.global_position + Vector2(0, -10), MIND, {"radius": 4.0, "count": n + 2, "spin": 1.0, "life": 0.55})
		for b in st.banners:                                    # a banner: a few stars on a short pole
			w.fx("line", b.pos, GOLD, {"dir": Vector2(0, -1), "length": 16.0, "width": 1.5, "life": 0.55})
			w.fx("star", b.pos + Vector2(0, -18), GOLD, {"radius": 5.0, "count": 3, "spin": 1.0, "life": 0.55})
	for i in range(st.banners.size() - 1, -1, -1):
		if float(st.banners[i].until) <= now:
			st.banners.remove_at(i)
	for i in range(st.gates.size() - 1, -1, -1):
		if float(st.gates[i].until) <= now:
			st.gates.remove_at(i)
		else:
			for e2 in WeaponUtil.enemies_in_circle(tree, st.gates[i].pos, 26.0):
				if convertible(e2) and !is_conv(e2):
					if conv(w, e2, 5.0):
						w.fx("flash", e2.global_position, VIOLET, {"radius": 12.0, "life": 0.3})
	if now >= float(st.army_next):
		st.army_next = now + 0.5
		_army_tick(w, now)
	if now < float(st.storm_until) and now >= float(st.storm_next):
		st.storm_next = now + MB_STORM_EVERY
		_thought_storm(w)
	if now < float(st.warcry_until) and now >= float(st.warcry_next):
		st.warcry_next = now + MB_WARCRY_EVERY
		_war_cry(w)
	if now < float(st.spread_until) and now >= float(st.spread_next):
		st.spread_next = now + 0.5
		_spread(w)
	_publish(w, pid)

static func _army_tick(w, now: float) -> void:
	var st: Dictionary = w._st
	var a: Array = army(w)
	var lieut: Array = []
	for e in a:
		if e.has_meta("wt_surge_until") and float(e.get_meta("wt_surge_until")) <= now:
			e.remove_meta("wt_surge_until")
			e.charm_power = float(e.get_meta("wt_base_power", 1.0)) if !e.has_meta("wt_lieut") else MB_LIEUT_POWER
		if e.has_meta("wt_lieut"):
			lieut.append(e)
	if w.tier >= 5:
		_promote(w)
	# where idle converts march: the command, then the nearest lieutenant, then the nearest banner
	for e2 in a:
		if e2.has_meta("wt_surge_until") and st.cmd_target != Vector2.INF and now < float(st.get("cmd_until", 0.0)):
			e2.rally_point = st.cmd_target
			continue
		var p := Vector2.INF
		if !lieut.is_empty() and !e2.has_meta("wt_lieut"):
			var bd := 1.0e9
			for l in lieut:
				var d: float = l.global_position.distance_to(e2.global_position)
				if d < bd:
					bd = d
					p = l.global_position
		elif w.tier >= 3 and !st.banners.is_empty():
			var bd2 := 1.0e9
			for b in st.banners:
				var d2: float = b.pos.distance_to(e2.global_position)
				if d2 < bd2:
					bd2 = d2
					p = b.pos
		if p != Vector2.INF:
			e2.rally_point = p

## Lieutenants: the three toughest converts get double health (at most 400 more), hit 2.5 times as hard and wear a crown.
static func _promote(w) -> void:
	var a: Array = army(w)
	a.sort_custom(func(x, y): return float(x.max_health) > float(y.max_health))
	var n := 0
	for e in a:
		if n >= MB_LIEUTENANTS:
			break
		n += 1
		if !e.has_meta("wt_lieut"):
			e.set_meta("wt_lieut", true)
			var extra: float = minf(float(e.max_health), MB_LIEUT_HEALTH_CAP)
			e.max_health = float(e.max_health) + extra
			e.health = e.max_health
			e.charm_power = MB_LIEUT_POWER
			w.fx("star", e.global_position + Vector2(0, -14), GOLD, {"radius": 9.0, "count": 5, "spin": 1.0, "life": 0.6})
			Sfx.play("unlock", 0.05)
		elif int(Time.get_ticks_msec() / 500) % 2 == 0:
			w.fx("star", e.global_position + Vector2(0, -14), GOLD, {"radius": 8.0, "count": 5, "spin": 0.5, "life": 0.55})

# ---------- stage 2 helpers: spread, war cry, thought storm ----------

static func _spread(w) -> void:
	var st: Dictionary = w._st
	for e in army(w):
		if int(st.spread_left) <= 0:
			return
		for o in WeaponUtil.enemies_in_circle(w.get_tree(), e.global_position, MB_SPREAD_R):
			if convertible(o) and !is_conv(o):
				if conv(w, o, maxf(1.0, float(e.charm_time))):
					st.spread_left = int(st.spread_left) - 1
					Kit.bolt(w, e.global_position, o.global_position, MIND)
					w.fx("burst", o.global_position, MIND, {"radius": 10.0, "life": 0.25})
				break

static func _war_cry(w) -> void:
	var o: Vector2 = w._st.get("storm_c", w.player.global_position)
	if o == Vector2.ZERO:
		o = w.player.global_position
	w.fx("ripple", o, MIND, {"radius": 120.0, "rings": 2, "life": 0.6})
	w.fx("star", o, GOLD, {"radius": 22.0, "count": 8, "spin": 1.0, "life": 0.5})
	Sfx.play("boss_roar", 0.05, 1.3)
	for e in army(w):
		e.charm_power = maxf(e.charm_power, MB_SURGE)
		e.set_meta("wt_surge_until", _now() + 2.0)

static func _thought_storm(w) -> void:
	var c: Vector2 = w._st.storm_c
	var cands: Array = []
	for e in w.get_tree().get_nodes_in_group("enemy"):
		if _alive(e) and !is_conv(e) and e.global_position.distance_to(c) <= 160.0:
			cands.append(e)
	cands.shuffle()
	for i in mini(MB_STORM_BOLTS, cands.size()):
		var e2 = cands[i]
		Kit.bolt(w, c + Vector2(0, -14), e2.global_position, MIND, 2.0, 0.3)
		w.fx("flash", e2.global_position, MIND, {"radius": 8.0, "life": 0.25})
		WeaponUtil.hit(e2, H(w) * MB_STORM_MULT, c, 0.0, 0.0, "", true, true)
		add_will(w, e2, 1)

static func _publish(w, _pid: int) -> void:
	var a = w._aura
	if a == null or !is_instance_valid(a):
		return
	var gp := []
	for g in w._st.gates:
		gp.append(g.pos)
	var d := {"gates": gp, "storm": float(w._st.storm_until) > _now()}
	var key := str(d)
	if w._st.pub != key:
		w._st.pub = key
		a.data = d

# ---------- ultimate: Mass Conversion -> Banner -> Lieutenants -> Sovereign ----------

static func ultimate(w) -> void:
	var st: Dictionary = w._st
	st.ult_id = int(st.ult_id) + 1
	var my: int = st.ult_id
	var c: Vector2 = w.cursor_target(100.0)
	if w.tier >= 3:
		w.fx("sigil", c, MIND, {"radius": 120.0, "count": 6, "spin": 1.0, "life": 0.5, "col2": VIOLET})
	if w.tier >= 6:
		_sovereign(w, c, my)
	elif w.tier >= 3:
		_conversion_after(w, c, my)

static func _conversion_after(w, c: Vector2, my: int) -> void:
	if !await WeaponTiers.pause(w, 0.6):
		return
	_banner_at(w, c, 25.0, false)
	w.fx("pillar", c, MIND, {"height": 80.0, "width": 24.0, "life": 0.8})
	if w.tier >= 5:
		var st: Dictionary = w._st
		_promote(w)
		st.storm_c = c
		st.spread_until = _now() + 25.0
		st.spread_left = MB_SPREAD_MAX
		st.spread_next = _now()
		st.warcry_until = _now() + 25.0
		st.warcry_next = _now() + 1.0

## Sovereign: a dome and a slow-motion beat, the conversion of everything in 160 px, honour guards and a huge banner, a thought storm and war cries
## for 15 s, and at the end the rebellion.
static func _sovereign(w, c: Vector2, my: int) -> void:
	var st: Dictionary = w._st
	var o: Vector2 = w.player.global_position
	# Beat 1
	w.fx("sigil", o, MIND, {"radius": 200.0, "count": 8, "spin": 0.8, "life": 0.8, "col2": VIOLET})
	w.fx("flash", o, MIND, {"radius": 120.0, "life": 0.5})
	Sfx.play("gong", 0.02)
	Game.hit_stop(0.3)
	# Beat 2
	if !await WeaponTiers.pause(w, 0.3):
		return
	if int(st.ult_id) != my:
		return
	w.fx("ripple", c, MIND, {"radius": 160.0, "rings": 4, "life": 1.0})
	var n := 0
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 160.0):
		if conv(w, e, 25.0):
			n += 1
	w.player.shake(5.0, 0.3)
	# Beat 3
	if !await WeaponTiers.pause(w, 0.7):
		return
	if int(st.ult_id) != my:
		return
	_banner_at(w, c, 25.0, false)
	w.fx("pillar", c, MIND, {"height": 160.0, "width": 40.0, "life": 1.2})
	_guards(w, c)
	_promote(w)
	# Beat 4
	if !await WeaponTiers.pause(w, 2.0):
		return
	if int(st.ult_id) != my:
		return
	var now := _now()
	st.storm_c = c
	st.storm_until = now + MB_SOVEREIGN_SECS
	st.storm_next = now
	st.warcry_until = now + MB_SOVEREIGN_SECS
	st.warcry_next = now
	st.spread_until = now + MB_SOVEREIGN_SECS
	st.spread_left = MB_SPREAD_MAX
	st.spread_next = now
	Sfx.play("boss_roar", 0.05, 0.9)
	# Beat 5
	if !await WeaponTiers.pause(w, MB_SOVEREIGN_SECS):
		return
	if int(st.ult_id) != my:
		return
	st.storm_until = 0.0
	st.spread_until = 0.0
	st.warcry_until = 0.0
	_rebellion(w, c)

static func _guards(w, c: Vector2) -> void:
	var card: Dictionary = Game.stats_of(Game.make_entry("guards", 4, ""))
	for i in MB_GUARDS:
		var g := Guard.new()
		var p: Vector2 = c + Vector2.from_angle(float(i) * TAU / float(MB_GUARDS)) * 18.0
		g.setup(card, p)
		w.game_world().add_child(g)
		w.fx("ring", p, GOLD, {"radius": 12.0, "life": 0.4})

## FINALE: every convert within 200 px bursts in a rose heart (1.0 H on the unconverted within 40 px); the survivors stay converted.
static func _rebellion(w, c: Vector2) -> void:
	var o: Vector2 = w.player.global_position
	w.fx("ripple", c, MIND, {"radius": 200.0, "rings": 3, "life": 0.9})
	w.fx("ripple", c, ROSE, {"radius": 160.0, "rings": 3, "life": 0.9})
	var shown := 0
	for e in army(w):
		if e.global_position.distance_to(c) > 200.0 and e.global_position.distance_to(o) > 200.0:
			continue
		var p: Vector2 = e.global_position
		if shown < 12:
			shown += 1
			w.fx("flash", p, ROSE, {"radius": 30.0, "life": 0.4})
		for t in WeaponUtil.enemies_in_circle(w.get_tree(), p, 40.0):
			if !is_conv(t):
				WeaponUtil.hit(t, H(w) * MB_REBELLION_BLAST, p, 80.0, 0.0, "", true, true)
	w.player.shake(8.0, 0.5)
	Sfx.play("ultimate", 0.02)
	Sfx.play("boss_roar", 0.05, 0.8)

# ---------- aura: the eye ----------

static func aura(a, c) -> void:
	var d: Dictionary = a.data
	var head: Vector2 = a.aim.rotated(a.swing) * a.reach
	var up: Vector2 = Vector2(0, -3)
	var e0: Vector2 = head + up
	c.draw_arc(e0, 3.0, PI + 0.4, TAU - 0.4, 8, Color(MIND, 0.9), 1.0)
	c.draw_arc(e0, 3.0, 0.4, PI - 0.4, 8, Color(MIND, 0.9), 1.0)
	c.draw_circle(e0 + a.aim * 0.8, 1.2, VIOLET)                    # the pupil follows the aim
	for i in 4:                                                     # cyan wisps rise from the eye
		var ph: float = fposmod(a._age * 0.9 + float(i) * 0.25, 1.0)
		c.draw_circle(e0 + Vector2(float(i - 2) * 2.0 + 1.0, -ph * 10.0), 0.9 * (1.0 - ph), Color(MIND, 0.7 * (1.0 - ph)))
	if a.tier >= 5:                                                 # a second, fainter eye opens above the first
		var e1: Vector2 = e0 + Vector2(0, -7)
		c.draw_arc(e1, 2.2, PI + 0.4, TAU - 0.4, 6, Color(MIND, 0.5), 1.0)
		c.draw_circle(e1 + a.aim * 0.6, 0.9, Color(VIOLET, 0.6))
	if a.tier >= 6:                                                 # eight eyes round the halo open in turn
		for k in 8:
			var ang: float = float(k) * TAU / 8.0 + a._age * 0.4
			var p: Vector2 = head + Vector2.from_angle(ang) * (a.reach + 9.0)
			var open: float = 0.5 + 0.5 * sin(a._age * 2.0 + float(k))
			c.draw_circle(p, 0.6 + 1.0 * open, Color(MIND, 0.8))
	for g in d.get("gates", []):                                    # the Thrall Gate
		var gp: Vector2 = c.to_local(g)
		c.draw_arc(gp, 8.0, 0.0, TAU, 20, Color(VIOLET, 0.9), 1.5)
		c.draw_arc(gp, 5.0, a._age * 3.0, a._age * 3.0 + 3.5, 12, Color(MIND, 0.8), 1.0)
