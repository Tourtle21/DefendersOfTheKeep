extends RefCounted
## Witch Staff tiers (docs/weapon_tiers/witchstaff.md): 2 Hex Mark, 3 Pox, 4 Cauldron, 5 Coven, 6 Witch Queen.
## Ancient: HEX AND ROT together. A hexed enemy (meta "hexed_until", 8 s) takes +20% from everything (Game.mark_mult) and, when it dies, the curse JUMPS to two
## neighbours. Rot (meta "wt_rot", the Bog Staff's stacks, +10% poison per stack through WeaponUtil.rot_mult, max 5, no bursts here) rides along on every hit.
## Minions: a cauldron, three witch spirits, a toad swarm. Hex runes are WeaponFx stars; witches and ravens are drawn by the WeaponAura from `data`.
## The old script (t2/witchstaff.gd) reads `_st.extra` / `_st.pierce` for the bolt and makes six pustules at tier 3+. Nothing here hurts players.

const Kit := preload("res://items/weapons/tiers/wt_kit.gd")
const GREEN := Color(0.55, 0.90, 0.35)
const PURPLE := Color(0.60, 0.30, 0.75)
const BREW := Color(0.35, 0.70, 0.30)
const BONE := Color(0.92, 0.90, 0.80)
const WS_HEX_SECS := 8.0
const WS_HEX_JUMP := 2
const WS_HEX_JUMP_R := 70.0
const WS_POX_MULT := 0.8
const WS_CAULDRON_SECS := 8.0
const WS_CAULDRON_EVERY := 1.0
const WS_CAULDRON_MULT := 0.6
const WS_WITCHES := 3
const WS_WITCH_SECS := 8.0
const WS_QUEEN_SECS := 12.0
const WS_QUEEN_R := 150.0
const WS_QUEEN_TICK := 0.25
const WS_TOADS := 5
const WS_TOAD_CAP := 24
const WS_WRATH_MULT := 2.0
const WS_FINISHER_EVERY := 6
const WS_LIGHT_BONUS := [0, 0, 5, 10, 15, 20, 30]
const NAMES := ["", "", "Hex Mark", "Pox", "Cauldron", "Coven", "Witch Queen"]

static func palette() -> Array:
	return [GREEN, PURPLE, BONE]

static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

static func equip(w) -> void:
	w._st = {"bolts": 0, "streak_id": 0, "streak": 0, "ult_id": 0, "extra": {}, "pierce": 1, "witch_next": false, "nova_next": false, "watch": {},
		"runes": 0.0, "rotfx": 0.0, "witch_until": 0.0, "witch_ph": 0.0, "witch_fire": [0.0, 0.4, 0.8], "queen_until": 0.0, "queen_t": 0.0,
		"cauldrons": 0, "walk": 0.0}
	WeaponTiers.light_bonus(w, WS_LIGHT_BONUS)

static func queen(w) -> bool:
	return now() < float(w._st.get("queen_until", 0.0))

# ---- Hex and Rot ----
static func hexed(e) -> bool:
	return Kit.alive(e) and e.has_meta("hexed_until") and float(e.get_meta("hexed_until")) > now()

static func hex(w, e, secs := WS_HEX_SECS) -> void:
	if !Kit.alive(e):
		return
	e.set_meta("hexed_until", now() + secs)
	WeaponTiers.mark(e, "hex", secs)
	if !w._st.watch.has(e.get_instance_id()):
		w._st.watch[e.get_instance_id()] = [e, e.global_position]

static func rot_stacks(e) -> int:
	if !Kit.alive(e) or !e.has_meta("wt_rot"):
		return 0
	var r = e.get_meta("wt_rot")
	return int(r.get("n", 0)) if (r is Dictionary and float(r.get("until", 0.0)) > now()) else 0

static func rot_add(e, n: int) -> void:
	if Kit.alive(e):
		e.set_meta("wt_rot", {"n": mini(5, rot_stacks(e) + n), "until": now() + 6.0})

## Every hit rots; the third bolt in a row at one target hexes it; a witch-bolt leaves a slow patch; the sixth bolt is a curse nova.
static func on_hit(w, e, _dmg: float) -> void:
	if !is_instance_valid(e):
		return
	if float(e.health) <= 0.0:
		return
	rot_add(e, 1)
	var id: int = e.get_instance_id()
	if int(w._st.streak_id) == id:
		w._st.streak = int(w._st.streak) + 1
	else:
		w._st.streak_id = id
		w._st.streak = 1
	if int(w._st.streak) >= 3 and !hexed(e):
		hex(w, e)
		w.fx("star", e.global_position + Vector2(0, -10), PURPLE, {"radius": 7.0, "count": 5, "spin": 1.0, "life": 0.5})
	if w.verb() != "attack":
		return
	if w._st.witch_next:
		w._st.witch_next = false
		WeaponUtil.patch(w.game_world(), e.global_position, "slow", 18.0, Color(0.35, 0.70, 0.30, 0.5), 4.0, 0.5)
	if w._st.nova_next:
		w._st.nova_next = false
		_nova(w, e.global_position)

static func _nova(w, at: Vector2) -> void:
	w.fx("ripple", at, PURPLE, {"radius": 80.0, "rings": 2, "life": 0.5})
	for o in WeaponUtil.enemies_in_circle(w.get_tree(), at, 80.0):
		hex(w, o)
		WeaponUtil.hit(o, WeaponTiers.H(w) * 0.5, at, 0.0, 0.0, "", true, true)

# ---- attack ----
static func pre_attack(w) -> void:
	w._st.bolts = int(w._st.bolts) + 1
	var n: int = w._st.bolts
	w._st.extra = {}
	w._st.pierce = 1
	if w.tier >= 4 and n % 4 == 0:                                    # a witch-bolt: big, piercing, chaining
		w._st.extra = {"size": 1.8, "chain": 2}
		w._st.pierce = 3
		w._st.witch_next = true
	if w.tier >= 6 and n % WS_FINISHER_EVERY == 0:
		w._st.nova_next = true

# ---- every frame: death watch, runes, rot bubbles, witches, the Queen ----
static func tick(w, delta: float) -> void:
	if w.tier < 2:
		return
	var t := now()
	w._st.walk = float(w._st.walk) + delta
	var scan: bool = float(w._st.walk) >= 0.1
	if scan:
		w._st.walk = 0.0
		_watch(w)
	w._st.runes = float(w._st.runes) + delta
	if float(w._st.runes) >= 0.5:
		w._st.runes = 0.0
		var shown := 0
		for id in w._st.watch:
			var e = w._st.watch[id][0]
			if shown < 8 and hexed(e):
				shown += 1
				w.fx("star", e.global_position + Vector2(0, -12), PURPLE, {"radius": 7.0, "count": 5, "spin": 1.0, "life": 0.5})
	w._st.rotfx = float(w._st.rotfx) + delta
	if float(w._st.rotfx) >= 0.6:
		w._st.rotfx = 0.0
		var rs := 0
		for e in w.get_tree().get_nodes_in_group("enemy"):
			if rs >= 5:
				break
			var n := rot_stacks(e)
			if n > 0 and e.global_position.distance_to(w.player.global_position) < 240.0:
				rs += 1
				w.fx("motes", e.global_position + Vector2(0, -10), BREW, {"radius": 4.0, "count": n, "rise": 8.0, "life": 0.5})
	if t < float(w._st.witch_until):
		_witches(w, delta, t)
	elif w._aura != null and is_instance_valid(w._aura) and w.tier >= 6:
		w._aura.data = {"w": 0, "ph": t, "q": 1 if queen(w) else 0}
	elif w._aura != null and is_instance_valid(w._aura):
		w._aura.data = {"w": 0, "ph": t, "q": 0}
	if queen(w) and scan:
		_queen_tick(w, t)

## The death watch: remember where every hexed enemy stands; when one is gone the curse jumps from that spot.
static func _watch(w) -> void:
	var w_list: Dictionary = w._st.watch
	var gone := []
	for id in w_list:
		var e = w_list[id][0]
		if is_instance_valid(e) and !e.is_queued_for_deletion() and float(e.health) > 0.0:
			if hexed(e):
				w_list[id][1] = e.global_position
			else:
				gone.append([id, false])
		else:
			gone.append([id, true])
	for g in gone:
		var pos: Vector2 = w_list[g[0]][1]
		w_list.erase(g[0])
		if g[1]:
			_died(w, pos)

static func _died(w, pos: Vector2) -> void:
	w._claim()
	var done := 0
	for o in Kit.nearest_n(w.get_tree(), pos, WS_HEX_JUMP_R, 8):
		if done >= WS_HEX_JUMP:
			break
		if hexed(o):
			continue
		done += 1
		hex(w, o)
		Kit.bolt(w, pos, o.global_position, PURPLE, 1.5, 0.25)
		w.fx("star", o.global_position + Vector2(0, -10), PURPLE, {"radius": 7.0, "count": 5, "spin": 1.0, "life": 0.5})
	if w.tier >= 3:                                                    # Pox: the corpse bursts into a cloud
		w.fx("burst", pos, BREW, {"radius": 22.0, "life": 0.3})
		w.fx("motes", pos, GREEN, {"radius": 28.0, "count": 8, "rise": 12.0, "life": 0.6})
		for o in WeaponUtil.enemies_in_circle(w.get_tree(), pos, 34.0):
			WeaponUtil.hit(o, WeaponTiers.H(w) * WS_POX_MULT, pos, 0.0, 0.0, "", true, true)
			rot_add(o, 2)
	if queen(w):
		_toads(w, pos)

static func _toads(w, pos: Vector2) -> void:
	var pid: int = w.player.get_instance_id()
	var alive_n := 0
	for n in w.get_tree().get_nodes_in_group("net"):
		if n is WeaponProjectile and n.owner_id == pid and n.style == "glob" and n.size < 1.1:
			alive_n += 1
	for k in WS_TOADS:
		if alive_n + k >= WS_TOAD_CAP:
			return
		var d := Vector2.from_angle(float(k) * TAU / float(WS_TOADS) + pos.x)
		WeaponProjectile.shoot(w.game_world(), pos + d * 5.0, d, 120.0, WeaponTiers.H(w) * 0.5, GREEN, 0.6, 0, 40.0, {"style": "glob", "size": 1.0, "homing": 2.0, "burst_r": 18.0, "owner_id": pid})

# ---- ability: Hex ----
static func ability(w) -> void:
	var c: Vector2 = w.cursor_target(120.0)
	w.fx("sigil", c, PURPLE, {"radius": 70.0, "count": 5, "spin": 1.5, "life": 0.5, "col2": BONE})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), c, 70.0):
		hex(w, e)
		rot_add(e, 1)
		w.fx("star", e.global_position + Vector2(0, -10), PURPLE, {"radius": 7.0, "count": 5, "spin": 1.0, "life": 0.5})
	var n := 6 if w.tier >= 3 else 4
	if w.tier >= 3:
		for i in n:
			_pustule(w, c + Vector2.from_angle(float(i) * TAU / float(n) + 0.4) * 52.0, 0.52 + float(i) * 0.1)
	if w.tier >= 4:
		_cauldron(w, c, int(w._st.ult_id))

static func _pustule(w, at: Vector2, delay: float) -> void:
	if !await WeaponTiers.pause(w, delay):
		return
	WeaponUtil.patch(w.game_world(), at, "slow", 18.0, Color(0.35, 0.70, 0.30, 0.5), 4.0, 0.5)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), at, 24.0):
		hex(w, e)

## Tier 4: a cauldron bubbles at the hex spot for 8 s and spits a homing glob at the nearest enemy every second.
static func _cauldron(w, c: Vector2, _my: int) -> void:
	if int(w._st.cauldrons) >= 2:
		return
	w._st.cauldrons = int(w._st.cauldrons) + 1
	var t := 0.0
	var pid: int = w.player.get_instance_id()
	while t < WS_CAULDRON_SECS:
		w.fx("sigil", c, GREEN, {"radius": 20.0, "count": 4, "spin": 2.0, "life": 0.45, "col2": BONE})
		w.fx("motes", c, BREW, {"radius": 10.0, "count": 8, "rise": 18.0, "life": 0.5})
		if !await WeaponTiers.pause(w, 0.4):
			return
		t += 0.4
		if fposmod(t, WS_CAULDRON_EVERY) < 0.4 and t >= 0.4:
			var e = WeaponUtil.nearest(w.get_tree(), c, 110.0)
			if e != null:
				var d: Vector2 = (e.global_position - c).normalized()
				hex(w, e)
				WeaponProjectile.shoot(w.game_world(), c + d * 6.0, d, 170.0, WeaponTiers.H(w) * WS_CAULDRON_MULT, GREEN, 1.0, 0, 40.0, {"style": "glob", "size": 1.4, "homing": 1.5, "burst_r": 22.0, "owner_id": pid, "trail": 3})
	w._st.cauldrons = maxi(0, int(w._st.cauldrons) - 1)

# ---- dash: Witch Hop ----
static func pre_dash(w) -> void:
	w._st.hop_from = w.player.global_position

static func dash(w) -> void:
	if w.tier < 4:
		return
	var o: Vector2 = w.player.global_position
	var from: Vector2 = w._st.get("hop_from", o - w.aim * 75.0)
	w.fx("streak", from, GREEN, {"dir": w.aim, "length": 75.0, "width": 6.0, "life": 0.25, "col2": BONE})
	for k in 3:
		WeaponUtil.patch(w.game_world(), from.lerp(o, float(k + 1) / 4.0), "slow", 16.0, Color(0.35, 0.70, 0.30, 0.5), 4.0, 0.5)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), from, 40.0):
		hex(w, e)
	w.fx("burst", o, GREEN, {"radius": 30.0, "life": 0.25})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 30.0):
		WeaponUtil.hit(e, WeaponTiers.H(w) * 0.8, o, 40.0, 0.0, "", true, true)

# ---- ultimate: Swamp Swell, Coven, Witch Queen ----
static func pre_ultimate(w) -> void:
	w._st.ult_id = int(w._st.ult_id) + 1

static func ultimate(w) -> void:
	var my: int = w._st.ult_id
	var o: Vector2 = w.player.global_position
	if w.tier >= 3:
		w.fx("sigil", o, PURPLE, {"radius": 125.0, "count": 10, "spin": 1.5, "life": 0.3, "col2": BONE})
	if w.tier >= 5:
		_coven(w, my, o)
	if w.tier >= 6:
		_queen(w, my)

static func _coven(w, my: int, o: Vector2) -> void:
	if !await WeaponTiers.pause(w, 1.0) or int(w._st.ult_id) != my:
		return
	w._st.witch_until = now() + WS_WITCH_SECS
	w._st.witch_fire = [0.2, 0.6, 1.0]
	w.fx("flash", w.player.global_position, PURPLE, {"radius": 24.0, "life": 0.3})
	var c: Vector2 = o
	WeaponUtil.patch(w.game_world(), c, "slow", 150.0, Color(0.35, 0.70, 0.30, 0.35), WS_WITCH_SECS, 0.4)
	var t := 0.0
	while t < WS_WITCH_SECS:
		w.fx("vortex", c, GREEN, {"radius": 150.0, "count": 3, "spin": 2.0, "life": 1.0})
		if !await WeaponTiers.pause(w, 1.0) or int(w._st.ult_id) != my:
			return
		t += 1.0

static func _witches(w, delta: float, t: float) -> void:
	w._st.witch_ph = float(w._st.witch_ph) + 1.5 * delta
	var o: Vector2 = w.player.global_position
	if w._aura != null and is_instance_valid(w._aura):
		w._aura.data = {"w": WS_WITCHES, "ph": w._st.witch_ph, "q": 1 if queen(w) else 0}
	var fire: Array = w._st.witch_fire
	for k in WS_WITCHES:
		fire[k] = float(fire[k]) - delta
		if float(fire[k]) <= 0.0:
			fire[k] = 1.2
			var pos: Vector2 = o + Vector2.from_angle(float(w._st.witch_ph) + float(k) * TAU / float(WS_WITCHES)) * 60.0
			var tgt = null
			for e in Kit.nearest_n(w.get_tree(), pos, 200.0, 12):
				if !hexed(e):
					tgt = e
					break
			if tgt == null:
				tgt = WeaponUtil.nearest(w.get_tree(), pos, 200.0)
			if tgt != null:
				w._claim()
				var d: Vector2 = (tgt.global_position - pos).normalized()
				Kit.bolt(w, pos, tgt.global_position, PURPLE, 1.5, 0.2)
				hex(w, tgt)
				WeaponProjectile.shoot(w.game_world(), pos, d, 200.0, WeaponTiers.H(w) * 0.8, PURPLE, 1.0, 0, 60.0, {"style": "orb", "size": 0.9, "glow": 0.3, "homing": 3.0, "chain": 1, "owner_id": w.player.get_instance_id()})

## FINALE + TRANSFORMATION Witch Queen (12 s): everything near is hexed, hexed enemies rot under curse ticks and die in toad swarms; then the Wrath.
static func _queen(w, my: int) -> void:
	if !await WeaponTiers.pause(w, 5.5) or int(w._st.ult_id) != my:
		return
	w._st.queen_until = now() + WS_QUEEN_SECS
	w._st.queen_t = 0.0
	w.fx("flash", w.player.global_position, PURPLE, {"radius": 30.0, "life": 0.3})
	Sfx.play("ultimate", 0.05)
	if !await WeaponTiers.pause(w, WS_QUEEN_SECS) or int(w._st.ult_id) != my:
		return
	_wrath(w)

static func _queen_tick(w, t: float) -> void:
	if t - float(w._st.queen_t) < 1.0:
		return
	w._st.queen_t = t
	w._claim()
	var o: Vector2 = w.player.global_position
	w.fx("ring", o, PURPLE, {"radius": WS_QUEEN_R, "life": 0.4})
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, WS_QUEEN_R):
		if !hexed(e):
			w.fx("star", e.global_position + Vector2(0, -10), PURPLE, {"radius": 7.0, "count": 5, "spin": 1.0, "life": 0.5})
		hex(w, e)
	var ticks := 0
	for id in w._st.watch.keys():
		var e = w._st.watch[id][0]
		if hexed(e) and ticks < 20:
			ticks += 1
			WeaponUtil.hit(e, WeaponTiers.H(w) * WS_QUEEN_TICK, o, 0.0, 0.0, "", true, true)

static func _wrath(w) -> void:
	var o: Vector2 = w.player.global_position
	var h := WeaponTiers.H(w)
	w.fx("flash", o, BONE, {"radius": 85.0, "life": 0.4})
	w.fx("ripple", o, PURPLE, {"radius": 170.0, "rings": 3, "life": 0.7})
	w.fx("pillar", o, PURPLE, {"height": 150.0, "width": 30.0, "life": 0.6})
	w.player.shake(8.0, 0.4)
	Sfx.play("ultimate", 0.05)
	Sfx.play("boss_roar", 0.05, 1.2)
	for e in WeaponUtil.enemies_in_circle(w.get_tree(), o, 170.0):
		if hexed(e):
			WeaponUtil.hit(e, h * (WS_WRATH_MULT + 0.5 * float(rot_stacks(e))), o, 200.0, 0.0, "", true)

# ---- the aura: a violet wisp, the witch spirits, the ravens ----
static func aura(a, c) -> void:
	var d: Vector2 = a.aim.rotated(a.swing)
	var head: Vector2 = d * a.reach
	for k in 3:                                                       # a trailing wisp (violet)
		var an: float = a._age * 2.0 - float(k) * 0.35
		c.draw_circle(head + Vector2.from_angle(an) * 4.0, 1.2 - 0.3 * float(k), Color(PURPLE.lightened(0.3), 0.8 - 0.25 * float(k)))
	var dt: Dictionary = a.data
	var nw: int = int(dt.get("w", 0))
	for k in nw:                                                      # witch spirits at r 60
		var ang: float = float(dt.get("ph", 0.0)) + float(k) * TAU / float(maxi(nw, 1))
		var p := Vector2.from_angle(ang) * 60.0
		for g in 3:
			c.draw_circle(Vector2.from_angle(ang - 0.12 * float(g)) * 60.0, 3.0 - float(g), Color(PURPLE if k % 2 == 0 else GREEN, 0.7 - 0.2 * float(g)))
		c.draw_circle(p + Vector2(0, -4), 2.0, Color(BONE, 0.9))              # the hat-less head
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -9), p + Vector2(-3, -4), p + Vector2(3, -4)]), Color(PURPLE.darkened(0.2), 0.95))
	if a.tier >= 6:                                                   # three ravens circle at r 20
		for k in 3:
			var an2: float = a._age * 1.2 + float(k) * TAU / 3.0
			var rp := Vector2.from_angle(an2) * 20.0 + Vector2(0, -2)
			var tg := Vector2.from_angle(an2 + PI / 2.0)
			c.draw_colored_polygon(PackedVector2Array([rp + tg * 3.0, rp + tg * -2.0 + Vector2(0, -2), rp + tg * -2.0 + Vector2(0, 2)]), Color(0.1, 0.05, 0.15, 0.9))
